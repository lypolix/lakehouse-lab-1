#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == "-f" ]]; then
  docker exec -i trino trino --ignore-errors < "$2"
else
  docker exec -i trino trino --execute "$1"
fi
