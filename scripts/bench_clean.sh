#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker exec -i trino trino --output-format=CSV_UNQUOTED \
  --execute "SELECT table_name FROM bronze.information_schema.tables
             WHERE table_schema = 'lakehouse' AND table_name LIKE 'bench\_%' ESCAPE '\'" 2>/dev/null \
| tr -d '\r' | while read -r TB; do
    [ -z "$TB" ] && continue
    echo "удаляю bronze.lakehouse.$TB"
    docker exec -i trino trino --execute "DROP TABLE IF EXISTS bronze.lakehouse.$TB" >/dev/null 2>&1
  done
echo "осталось в Bronze:"
docker exec trino trino --execute "SHOW TABLES FROM bronze.lakehouse" 2>/dev/null
