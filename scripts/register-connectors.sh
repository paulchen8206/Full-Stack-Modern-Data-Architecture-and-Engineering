#!/usr/bin/env bash
# register-connectors.sh
# Registers all connector configs in connect/connector-configs/ using the consolidated script.

set -euo pipefail

CONNECT_URL="http://localhost:8083"
CONFIG_DIR="$(dirname "$0")/../connect/connector-configs"
SCRIPT_DIR="$(dirname "$0")"
REGISTER_SCRIPT="$SCRIPT_DIR/consolidated-register-connector.sh"

if [[ ! -x "$REGISTER_SCRIPT" ]]; then
  echo "ERROR: $REGISTER_SCRIPT not found or not executable" >&2
  exit 1
fi

for config in "$CONFIG_DIR"/*.json; do
  name=$(jq -r '.name // .config["name"] // empty' "$config")
  if [[ -z "$name" ]]; then
    name=$(basename "$config" .json)
  fi
  echo "Registering connector: $name ($config)"
  "$REGISTER_SCRIPT" --config "$config" --name "$name" --url "$CONNECT_URL"
done
