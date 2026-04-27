#!/bin/bash
set -e
NAMESPACE="realtime-dev"
CONNECT_DEPLOYMENT="realtime-dev-realtime-app-connect"

wait_for_connect() {
  until kubectl exec -n $NAMESPACE deploy/$CONNECT_DEPLOYMENT -- curl -sf http://localhost:8083/connectors >/dev/null; do
    echo "Waiting for Kafka Connect REST API..."
    sleep 3
  done
}


delete_connector_if_exists() {
  name="$1"
  if kubectl exec -n $NAMESPACE deploy/$CONNECT_DEPLOYMENT -- curl -sf http://localhost:8083/connectors/$name >/dev/null; then
    echo "Deleting existing connector: $name"
    kubectl exec -n $NAMESPACE deploy/$CONNECT_DEPLOYMENT -- curl -X DELETE http://localhost:8083/connectors/$name
    sleep 2
  fi
}

register_connector() {
  name="$1"
  config_file="$2"

  # Validate JSON config
  if ! jq empty "$config_file" 2>/dev/null; then
    echo "ERROR: Invalid JSON in $config_file. Skipping $name."
    return 1
  fi

  # Check for required fields
  required_fields=("connector.class" "tasks.max" "topics")
  missing_fields=()
  for field in "${required_fields[@]}"; do
    if ! jq -e ".\"$field\"" "$config_file" >/dev/null; then
      missing_fields+=("$field")
    fi
  done
  if [ ${#missing_fields[@]} -ne 0 ]; then
    echo "ERROR: Missing required fields in $config_file: ${missing_fields[*]}. Skipping $name."
    return 1
  fi

  delete_connector_if_exists "$name"
  echo "Registering $name from $config_file"
  # Create wrapper JSON
  wrapper_file="/tmp/${name}-wrapper.json"
  echo "{\"name\": \"$name\", \"config\": $(cat $config_file) }" > $wrapper_file
  kubectl cp "$wrapper_file" $NAMESPACE/$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}'):/tmp/${name}-wrapper.json
  if ! kubectl exec -n $NAMESPACE deploy/$CONNECT_DEPLOYMENT -- curl -X POST -H "Content-Type: application/json" --data @/tmp/${name}-wrapper.json http://localhost:8083/connectors; then
    echo "ERROR: Failed to register $name. See above for details."
  fi
  rm -f $wrapper_file
}

wait_for_connect


register_connector "iceberg-sales-order" "connect/connector-configs/iceberg-sales-order.json"
register_connector "iceberg-sales-order-line-item" "connect/connector-configs/iceberg-sales-order-line-item.json"
register_connector "iceberg-customer-sales" "connect/connector-configs/iceberg-customer-sales.json"
register_connector "jdbc-sales-warehouse" "connect/connector-configs/jdbc-sales-warehouse.json"
register_connector "debezium-mysql-mdm" "connect/connector-configs/debezium-mysql-mdm.json"

echo "All connectors registered."
