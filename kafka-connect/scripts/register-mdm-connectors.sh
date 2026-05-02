#!/bin/sh

set -eu
(set -o pipefail >/dev/null 2>&1) && set -o pipefail

CONNECT_URL="${CONNECT_URL:-http://mdm-connect:8083}"
CONNECTORS_DIR="/connectors"
CONNECTOR_FILES="s3-mdm-customer.json,s3-mdm-product.json,s3-mdm-date.json,jdbc-mdm-warehouse.json"

echo "Waiting for Kafka Connect at $CONNECT_URL ..."
until curl -fsS "$CONNECT_URL/connector-plugins" >/dev/null; do
  sleep 2
done

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
