#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."

OUT=results/bench.csv
REPEATS=${REPEATS:-3}
COMBOS=${COMBOS:-"PARQUET:NONE PARQUET:SNAPPY PARQUET:GZIP PARQUET:ZSTD PARQUET:LZ4 ORC:NONE ORC:SNAPPY ORC:GZIP ORC:ZSTD ORC:LZ4 AVRO:SNAPPY AVRO:ZSTD"}

t() { docker exec -i trino trino --output-format=CSV_UNQUOTED --execute "$1" 2>/dev/null | tail -1 | tr -d '\r'; }

timed() {
  local tag="$1" sql="$2" out
  out=$(docker exec -i trino trino --output-format=CSV_UNQUOTED --execute "/* $tag */ $sql" 2>&1)
  if [[ $? -ne 0 ]]; then echo "FAIL|$out"; return 1; fi
  local ms
  ms=$(t "SELECT date_diff('millisecond', created, \"end\")
          FROM system.runtime.queries
          WHERE query LIKE '%$tag%' AND state = 'FINISHED'
            AND query NOT LIKE '%runtime.queries%'
          ORDER BY created DESC LIMIT 1" | tr -d '\r')
  echo "${ms:-NA}"
}

echo "format,codec,rows,write_ms,files,bytes,mb,agg1_ms,agg2_ms,status" > "$OUT"

for combo in $COMBOS; do
  FMT=${combo%%:*}; CODEC=${combo##*:}
  TBL="bench_$(echo "${FMT}_${CODEC}" | tr 'A-Z' 'a-z')"
  FQ="bronze.lakehouse.$TBL"
  STAMP=$(date +%s)
  echo "=== $FMT / $CODEC -> $FQ"

  WSQL=$(mktemp)
  cat > "$WSQL" <<EOS
SET SESSION bronze.compression_codec = '$CODEC';
CREATE OR REPLACE TABLE $FQ WITH (format = '$FMT') AS
SELECT /* bench-w-$TBL-$STAMP */
  orderkey, partkey, suppkey, linenumber, quantity, extendedprice, discount,
  tax, returnflag, linestatus, shipdate, commitdate, receiptdate,
  shipinstruct, shipmode, comment
FROM tpch.sf1.lineitem;
EOS
  if ! docker exec -i trino trino < "$WSQL" >/dev/null 2>results/bench-$TBL.err; then
    echo "$FMT,$CODEC,,,,,,,,WRITE_FAILED" >> "$OUT"
    echo "   ! запись упала: $(head -c 200 results/bench-$TBL.err)"
    rm -f "$WSQL"; continue
  fi
  rm -f "$WSQL"
  WRITE_MS=$(t "SELECT date_diff('millisecond', created, \"end\")
      FROM system.runtime.queries
      WHERE query LIKE '%bench-w-$TBL-$STAMP%' AND state = 'FINISHED'
        AND query LIKE '%CREATE OR REPLACE%'
      ORDER BY created DESC LIMIT 1" | tail -1 | tr -d '\r')

  ROWS=$(t "SELECT count(*) FROM $FQ" | tail -1 | tr -d '\r')
  FB=$(t "SELECT count(*), sum(file_size_in_bytes) FROM bronze.lakehouse.\"$TBL\$files\"" | tail -1 | tr -d '\r')
  FILES=${FB%%,*}; BYTES=${FB##*,}
  MB=$(python3 -c "print(f'{$BYTES/1048576:.1f}')" 2>/dev/null || echo NA)

  A1=999999999; A2=999999999
  for i in $(seq 1 "$REPEATS"); do
    r=$(timed "bench-a1-$TBL-$STAMP-$i" "SELECT count(*) FROM (
          SELECT orderkey, sum(quantity) AS q FROM $FQ
          GROUP BY orderkey HAVING sum(quantity) > 300)")
    [[ "$r" =~ ^[0-9]+$ ]] && (( r < A1 )) && A1=$r
    r=$(timed "bench-a2-$TBL-$STAMP-$i" "SELECT sum(extendedprice * (1 - discount)),
          avg(quantity), count(DISTINCT shipmode) FROM $FQ")
    [[ "$r" =~ ^[0-9]+$ ]] && (( r < A2 )) && A2=$r
  done
  (( A1 == 999999999 )) && A1=NA
  (( A2 == 999999999 )) && A2=NA

  echo "$FMT,$CODEC,$ROWS,$WRITE_MS,$FILES,$BYTES,$MB,$A1,$A2,OK" >> "$OUT"
  echo "   rows=$ROWS write=${WRITE_MS}ms size=${MB}MB files=$FILES agg1=${A1}ms agg2=${A2}ms"
done

echo
column -s, -t < "$OUT"
