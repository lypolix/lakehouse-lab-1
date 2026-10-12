#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

ICEBERG_VER=${ICEBERG_VER:-1.9.1}
docker compose run --rm -T spark /opt/spark/bin/spark-sql \
  --master "local[2]" \
  --conf spark.jars.ivy=/tmp/ivy \
  --driver-memory 1500m \
  --packages "org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:${ICEBERG_VER},org.apache.iceberg:iceberg-aws-bundle:${ICEBERG_VER}" \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.bronze=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.bronze.type=rest \
  --conf spark.sql.catalog.bronze.uri=http://lakekeeper:8181/catalog \
  --conf spark.sql.catalog.bronze.warehouse=bronze \
  --conf spark.sql.catalog.bronze.io-impl=org.apache.iceberg.aws.s3.S3FileIO \
  --conf spark.sql.catalog.bronze.s3.endpoint=http://minio:9000 \
  --conf spark.sql.catalog.bronze.s3.path-style-access=true \
  --conf spark.sql.catalog.bronze.client.region=us-east-1 \
  --conf spark.sql.catalogImplementation=in-memory \
  -f /opt/lab/scripts/spark_bronze.sql
