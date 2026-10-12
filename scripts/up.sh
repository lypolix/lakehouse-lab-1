#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
DC="docker compose"

echo "==> 1/7 MinIO + Postgres"
$DC up -d minio pg

echo "==> 2/7 ждём Postgres"
for i in $(seq 1 60); do
  $DC exec -T pg pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 2
done
$DC exec -T pg pg_isready -U postgres

echo "==> 3/7 ждём MinIO S3 API"
for i in $(seq 1 60); do
  curl -fsS http://localhost:9100/minio/health/live >/dev/null 2>&1 && break
  sleep 2
done
curl -fsS -o /dev/null http://localhost:9100/minio/health/live && echo "minio: live"

echo "==> 4/7 бакеты bronze/silver/gold"
$DC run --rm -T mc /bin/sh -c \
  "mc alias set m http://minio:9000 minioadmin minioadmin >/dev/null && \
   mc mb --ignore-existing m/bronze m/silver m/gold && mc ls m"

echo "==> 5/7 миграции БД Lakekeeper + serve"
$DC run --rm -T lakekeeper migrate
$DC up -d lakekeeper
for i in $(seq 1 60); do
  curl -fsS http://localhost:8181/health >/dev/null 2>&1 && break
  sleep 2
done
curl -fsS http://localhost:8181/health && echo

echo "==> 6/7 bootstrap + 3 warehouse"
curl -sS -o /dev/null -w 'bootstrap: %{http_code}\n' -X POST http://localhost:8181/management/v1/bootstrap \
  -H 'Content-Type: application/json' -d '{"accept-terms-of-use": true}' || true
for L in bronze silver gold; do
  code=$(curl -sS -o /tmp/wh-$L.json -w '%{http_code}' -X POST http://localhost:8181/management/v1/warehouse \
    -H 'Content-Type: application/json' -d "{
      \"warehouse-name\": \"$L\",
      \"project-id\": \"00000000-0000-0000-0000-000000000000\",
      \"storage-profile\": {
        \"type\": \"s3\", \"bucket\": \"$L\", \"key-prefix\": \"\",
        \"endpoint\": \"http://minio:9000\", \"region\": \"us-east-1\",
        \"path-style-access\": true, \"flavor\": \"s3-compat\", \"sts-enabled\": false
      },
      \"storage-credential\": {
        \"type\": \"s3\", \"credential-type\": \"access-key\",
        \"access-key-id\": \"minioadmin\", \"secret-access-key\": \"minioadmin\"
      }
    }")
  echo "warehouse $L: HTTP $code"
done

echo "==> 7/7 Trino"
$DC up -d trino
for i in $(seq 1 90); do
  docker exec trino trino --execute "SELECT 1" >/dev/null 2>&1 && break
  sleep 3
done
docker exec trino trino --execute "SHOW CATALOGS"
echo "==> стек готов: MinIO http://localhost:9101 | Lakekeeper http://localhost:8181/ui/ | Trino http://localhost:8080"
