#!/bin/sh

set -eu
# pipefail is not supported in every /bin/sh (for example, Alpine ash on some versions).
(set -o pipefail >/dev/null 2>&1) && set -o pipefail

CONNECT_URL="${CONNECT_URL:-http://mdm-connect:8083}"
CONNECTORS_DIR="/connectors"
CONNECTOR_GLOB="${CONNECTOR_GLOB:-debezium-mysql-mdm.json}"
CONNECTOR_FILES="${CONNECTOR_FILES:-}"

echo "Waiting for Kafka Connect at $CONNECT_URL ..."
until curl -fsS "$CONNECT_URL/connector-plugins" >/dev/null; do
  sleep 2
done

register_config() {
  config="$1"
  if [ -f "$config" ]; then
    name=$(jq -r .name "$config")
    payload=$(jq -c .config "$config")
    echo "Registering connector: $name"
    curl -fsS -X PUT -H "Content-Type: application/json" \
      --data "$payload" \
      "$CONNECT_URL/connectors/$name/config"
  fi
}

if [ -n "$CONNECTOR_FILES" ]; then
  OLD_IFS="$IFS"
  IFS=','
  set -- $CONNECTOR_FILES
  IFS="$OLD_IFS"
  for file_name in "$@"; do
    register_config "$CONNECTORS_DIR/$file_name"
  done
else
  for config in "$CONNECTORS_DIR"/$CONNECTOR_GLOB; do
    register_config "$config"
  done
fi
