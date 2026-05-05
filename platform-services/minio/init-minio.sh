#!/usr/bin/env sh

set -eu

MC_HOST_ALIAS="local"
MINIO_ENDPOINT="http://minio:9000"
MINIO_ACCESS_KEY="${MINIO_ROOT_USER:-minio123}"
MINIO_SECRET_KEY="${MINIO_ROOT_PASSWORD:-minio123}"
WAREHOUSE_BUCKET="${WAREHOUSE_BUCKET:-warehouse}"

until mc alias set "${MC_HOST_ALIAS}" "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" >/dev/null 2>&1; do
  echo "Waiting for MinIO to accept connections..."
  sleep 2
done

mc mb --ignore-existing "${MC_HOST_ALIAS}/${WAREHOUSE_BUCKET}"
mc anonymous set private "${MC_HOST_ALIAS}/${WAREHOUSE_BUCKET}" >/dev/null 2>&1 || true

echo "MinIO warehouse bucket ready: ${WAREHOUSE_BUCKET}"
