#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
OUT=results/layer_stats.csv
t() { docker exec -i trino trino --output-format=CSV_UNQUOTED --execute "$1" 2>/dev/null; }

echo "layer,table,rows,files,bytes,mb" > "$OUT"
for pair in \
  "bronze:raw_customer" "bronze:raw_orders" "bronze:raw_lineitem" \
  "silver:dim_customer" "silver:large_orders" "silver:fact_order" \
  "gold:large_volume_customer"; do
  L=${pair%%:*}; TB=${pair##*:}
  ROWS=$(t "SELECT count(*) FROM $L.lakehouse.$TB" | tail -1 | tr -d '\r')
  FB=$(t "SELECT count(*), coalesce(sum(file_size_in_bytes),0) FROM $L.lakehouse.\"$TB\$files\"" | tail -1 | tr -d '\r')
  FILES=${FB%%,*}; BYTES=${FB##*,}
  MB=$(python3 -c "print(f'{${BYTES:-0}/1048576:.2f}')" 2>/dev/null || echo NA)
  echo "$L,$TB,$ROWS,$FILES,$BYTES,$MB" >> "$OUT"
done
column -s, -t < "$OUT"
echo
echo "--- DDL слоёв (формат/партиционирование) ---"
for pair in bronze:raw_customer bronze:raw_orders bronze:raw_lineitem \
            silver:dim_customer silver:large_orders silver:fact_order \
            gold:large_volume_customer; do
  L=${pair%%:*}; TB=${pair##*:}
  docker exec -i trino trino --execute "SHOW CREATE TABLE $L.lakehouse.$TB" 2>/dev/null | tail -n +1
done
