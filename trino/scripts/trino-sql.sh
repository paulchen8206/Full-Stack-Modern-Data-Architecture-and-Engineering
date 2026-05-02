#!/usr/bin/env sh

set -eu

TRINO_SERVER="${TRINO_SERVER:-http://localhost:8080}"
TRINO_CATALOG="${TRINO_CATALOG:-lakehouse}"
TRINO_SCHEMA="${TRINO_SCHEMA:-streaming}"

if [ "$#" -gt 0 ] && [ -f "$1" ]; then
  docker compose exec -T trino trino \
    --server "$TRINO_SERVER" \
    --catalog "$TRINO_CATALOG" \
    --schema "$TRINO_SCHEMA" < "$1"
  exit 0
fi

if [ "$#" -gt 0 ]; then
  docker compose exec -T trino trino \
    --server "$TRINO_SERVER" \
    --catalog "$TRINO_CATALOG" \
    --schema "$TRINO_SCHEMA" \
    --execute "$*"
  exit 0
fi

docker compose exec trino trino \
  --server "$TRINO_SERVER" \
  --catalog "$TRINO_CATALOG" \
  --schema "$TRINO_SCHEMA"
