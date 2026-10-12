#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec > >(tee results/time_travel.log) 2>&1

T=silver.lakehouse.dim_customer
q()  { docker exec -i trino trino --execute "$1" 2>/dev/null; }
qv() { docker exec -i trino trino --output-format=CSV_UNQUOTED --execute "$1" 2>/dev/null | tail -1 | tr -d '\r'; }

echo "== 0. Исходное состояние"
echo "строк всего:        $(qv "SELECT count(*) FROM $T")"
echo "строк CORRUPTED:    $(qv "SELECT count(*) FROM $T WHERE name = 'CORRUPTED'")"
GOOD=$(qv "SELECT cast(snapshot_id AS varchar) FROM silver.lakehouse.\"dim_customer\$snapshots\" ORDER BY committed_at DESC LIMIT 1")
echo "последний (хороший) снапшот: $GOOD"

echo
echo "== 1. Авария: портим колонку name во всех строках"
q "UPDATE $T SET name = 'CORRUPTED'"
echo "строк CORRUPTED после аварии: $(qv "SELECT count(*) FROM $T WHERE name = 'CORRUPTED'")"

echo
echo "== 2. Чтение из прошлого (данные не потеряны, видны в старом снапшоте)"
q "SELECT custkey, name FROM $T FOR VERSION AS OF $GOOD ORDER BY custkey LIMIT 5"

echo
echo "== 3. Восстановление: откат таблицы на снапшот $GOOD"
q "CALL silver.system.rollback_to_snapshot('lakehouse', 'dim_customer', $GOOD)"

echo
echo "== 4. Проверка после откатa"
echo "строк всего:       $(qv "SELECT count(*) FROM $T")"
echo "строк CORRUPTED:   $(qv "SELECT count(*) FROM $T WHERE name = 'CORRUPTED'")"
q "SELECT custkey, name FROM $T ORDER BY custkey LIMIT 5"

echo
echo "== 5. История снапшотов: плохой снапшот остаётся в истории,\n       но текущим состоянием таблицы снова стал $GOOD"
q "SELECT snapshot_id, parent_id, operation, committed_at FROM silver.lakehouse.\"dim_customer\$snapshots\" ORDER BY committed_at"
