#!/bin/sh

set -eu
(set -o pipefail >/dev/null 2>&1) && set -o pipefail

CONNECT_URL="${CONNECT_URL:-http://ods-connect:8083}"
CONNECTORS_DIR="/connectors"
CONNECTOR_FILES="s3-sales-order.json,s3-sales-order-line-item.json,s3-customer-sales.json,jdbc-sales-order-warehouse.json,jdbc-sales-order-line-item-warehouse.json,jdbc-customer-sales-warehouse.json"

echo "Waiting for Kafka Connect at $CONNECT_URL ..."
until curl -fsS "$CONNECT_URL/connector-plugins" >/dev/null; do
  sleep 2
done

# Remove legacy mixed-schema connector to avoid duplicate ingestion once
# split per-topic JDBC connectors are registered.
if curl -fsS "$CONNECT_URL/connectors/jdbc-sales-warehouse" >/dev/null 2>&1; then
  echo "Deleting legacy connector: jdbc-sales-warehouse"
  curl -fsS -X DELETE "$CONNECT_URL/connectors/jdbc-sales-warehouse" >/dev/null
fi

OLD_IFS="$IFS"
IFS=','
set -- $CONNECTOR_FILES
IFS="$OLD_IFS"

for file_name in "$@"; do
  config="$CONNECTORS_DIR/$file_name"
  if [ -f "$config" ]; then
    name=$(jq -r .name "$config")
    payload=$(jq -c .config "$config")
    echo "Registering connector: $name"
    curl -fsS -X PUT -H "Content-Type: application/json" \
      --data "$payload" \
      "$CONNECT_URL/connectors/$name/config"
  fi
done
