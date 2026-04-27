#!/bin/bash
set -e
NAMESPACE="realtime-dev"
CONNECT_DEPLOYMENT="realtime-dev-realtime-app-connect"

# Wait for Connect REST API to be ready
until kubectl exec -n $NAMESPACE deploy/$CONNECT_DEPLOYMENT -- curl -sf http://localhost:8083/; do
  echo "Waiting for Kafka Connect REST API..."
  sleep 5
done

echo "Registering sample FileStreamSource connector..."
kubectl exec -n $NAMESPACE deploy/$CONNECT_DEPLOYMENT -- curl -X POST -H "Content-Type: application/json" \
  --data '{
    "name": "sample-file-source",
    "config": {
      "connector.class": "org.apache.kafka.connect.file.FileStreamSourceConnector",
      "tasks.max": "1",
      "file": "/tmp/sample.txt",
      "topic": "sample-file-topic"
    }
  }' \
  http://localhost:8083/connectors

echo "Connector registered."
