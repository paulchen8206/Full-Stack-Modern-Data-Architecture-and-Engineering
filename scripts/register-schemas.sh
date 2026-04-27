#!/usr/bin/env bash
set -euo pipefail

SCHEMA_REGISTRY_URL="http://realtime-dev-realtime-app-schema-registry:8081"
SCHEMAS_DIR="/schemas"

for subject in raw_sales_orders sales_order sales_order_line_item customer_sales mdm_customer mdm_product; do
  if [ -f "${SCHEMAS_DIR}/${subject}.json" ]; then
    echo "Registering schema for $subject..."
    curl -s -o /dev/null -w "%{http_code}\n" -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
      --data @"${SCHEMAS_DIR}/${subject}.json" \
      "${SCHEMA_REGISTRY_URL}/subjects/${subject}-value/versions"
  else
    echo "Schema file not found: ${SCHEMAS_DIR}/${subject}.json"
  fi
done
