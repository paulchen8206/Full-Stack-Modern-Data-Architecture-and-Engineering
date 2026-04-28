#!/bin/bash
set -euo pipefail

CONNECT_URL="http://connect:8083"
CONNECTORS_DIR="/connectors"

for config in "$CONNECTORS_DIR"/*.json; do
  if [ -f "$config" ]; then
    name=$(jq -r .name "$config")
    echo "Registering connector: $name"
    curl -s -X PUT -H "Content-Type: application/json" \
      --data-binary "@$config" \
      "$CONNECT_URL/connectors/$name/config"
  fi
done
