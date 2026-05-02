#!/bin/bash
set -euo pipefail

SCHEMA_REGISTRY_URL="http://schema-registry:8081"
SCHEMAS_DIR="/avro"

echo "Waiting for Schema Registry at ${SCHEMA_REGISTRY_URL}..."
until curl -fsS "${SCHEMA_REGISTRY_URL}/subjects" >/dev/null; do
  sleep 2
done
echo "Schema Registry is ready."

for avsc_file in "$SCHEMAS_DIR"/*.avsc; do
  if [ -f "$avsc_file" ]; then
    subject=$(basename "$avsc_file" .avsc)
    echo "Registering schema for subject: $subject"
    schema_json=$(jq -c . "$avsc_file" | sed 's/"/\\"/g')
    payload="{\"schema\": \"$schema_json\"}"
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
