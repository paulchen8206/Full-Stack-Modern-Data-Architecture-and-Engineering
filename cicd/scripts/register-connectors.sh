#!/usr/bin/env bash
# register-connectors.sh
# Registers connector configs using the consolidated script.

set -euo pipefail

CONNECT_URL="http://localhost:8083"
SCRIPT_DIR="$(dirname "$0")"
CONNECT_SCOPE="${CONNECT_SCOPE:-debezium}"

case "$CONNECT_SCOPE" in
  debezium)
    CONFIG_DIRS=("$SCRIPT_DIR/../../kafka-connect/dbz-connect/connector-configs")
    ;;
  mdm)
    CONFIG_DIRS=("$SCRIPT_DIR/../../kafka-connect/mdm-connect/connector-configs")
    ;;
  all)
    CONFIG_DIRS=(
      "$SCRIPT_DIR/../../kafka-connect/dbz-connect/connector-configs"
      "$SCRIPT_DIR/../../kafka-connect/mdm-connect/connector-configs"
    )
    ;;
  *)
    echo "ERROR: CONNECT_SCOPE must be one of: debezium, mdm, all" >&2
    exit 1
    ;;
esac

REGISTER_SCRIPT="$SCRIPT_DIR/consolidated-register-connector.sh"

if [[ ! -x "$REGISTER_SCRIPT" ]]; then
  echo "ERROR: $REGISTER_SCRIPT not found or not executable" >&2
  exit 1
fi

for config_dir in "${CONFIG_DIRS[@]}"; do
  for config in "$config_dir"/*.json; do
    name=$(jq -r '.name // .config["name"] // empty' "$config")
    if [[ -z "$name" ]]; then
      name=$(basename "$config" .json)
    fi
    echo "Registering connector: $name ($config)"
    "$REGISTER_SCRIPT" --config "$config" --name "$name" --url "$CONNECT_URL"
  done
done
