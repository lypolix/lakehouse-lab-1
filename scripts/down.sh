#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == "--purge" ]]; then
  docker compose down -v
else
  docker compose down
fi
