#!/usr/bin/env bash
set -euo pipefail

# Schema Registry URL (override with env var if needed)
SCHEMA_REGISTRY_URL="${SCHEMA_REGISTRY_URL:-http://realtime-dev-vision-schema-registry:8081}"
# Schemas directory (relative to project root by default)
SCHEMAS_DIR="${SCHEMAS_DIR:-./platform-services/schemas}"

echo "Looking for .avsc files in $SCHEMAS_DIR"
for avsc_file in "$SCHEMAS_DIR"/*.avsc; do
  if [ -f "$avsc_file" ]; then
    subject=$(basename "$avsc_file" .avsc)
    echo "Registering schema for subject: $subject"
    # Prepare the registration payload
    payload=$(jq -c --arg schema "$(jq -c . "$avsc_file")" '{schema: $schema}')
    # Register with Schema Registry
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      -H "Content-Type: application/vnd.schemaregistry.v1+json" \
      --data "$payload" \
      "$SCHEMA_REGISTRY_URL/subjects/${subject}-value/versions")
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
      echo "Successfully registered $subject ($http_code)"
    else
      echo "Failed to register $subject (HTTP $http_code)"
    fi
  fi
done
