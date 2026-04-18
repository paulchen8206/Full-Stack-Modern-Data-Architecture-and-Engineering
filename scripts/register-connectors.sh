#!/usr/bin/env sh

set -eu

CONNECT_URL="${CONNECT_URL:-http://connect:8083}"

wait_for_connect() {
  until curl -sf "${CONNECT_URL}/connectors" >/dev/null; do
    echo "Waiting for Kafka Connect REST API..."
    sleep 3
  done
}

upsert_connector() {
  name="$1"
  config_file="$2"

  echo "Applying connector ${name} from ${config_file}"

  if curl -sf "${CONNECT_URL}/connectors/${name}" >/dev/null; then
    curl -sf -X PUT \
      -H "Content-Type: application/json" \
      --data "@${config_file}" \
      "${CONNECT_URL}/connectors/${name}/config" >/dev/null
  else
    curl -sf -X POST \
      -H "Content-Type: application/json" \
      --data "{\"name\":\"${name}\",\"config\":$(cat "${config_file}")}" \
      "${CONNECT_URL}/connectors" >/dev/null
  fi
}

upsert_connector_best_effort() {
  name="$1"
  config_file="$2"

  if ! upsert_connector "${name}" "${config_file}"; then
    echo "WARN: skipping connector ${name}; plugin may be unavailable in this image"
  fi
}

wait_for_connect

upsert_connector_best_effort "iceberg-sales-order" "/connector-configs/iceberg-sales-order.json"
upsert_connector_best_effort "iceberg-sales-order-line-item" "/connector-configs/iceberg-sales-order-line-item.json"
upsert_connector_best_effort "iceberg-customer-sales" "/connector-configs/iceberg-customer-sales.json"
upsert_connector "jdbc-sales-warehouse" "/connector-configs/jdbc-sales-warehouse.json"

echo "Kafka Connect connectors are registered."
