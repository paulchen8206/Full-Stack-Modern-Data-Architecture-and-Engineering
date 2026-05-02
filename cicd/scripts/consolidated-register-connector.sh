#!/usr/bin/env bash
# consolidated-register-connector.sh
# Usage:
#   ./cicd/scripts/consolidated-register-connector.sh --config <config.json> [--name <connector-name>] [--url <connect-url>] [--k8s <namespace> <deployment>]
#   If --k8s is provided, will exec into k8s deployment, otherwise uses curl locally.

set -euo pipefail

NAME=""
CONFIG=""
CONNECT_URL="http://localhost:8083"
K8S_MODE=0
K8S_NAMESPACE=""
K8S_DEPLOYMENT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --config)
      CONFIG="$2"; shift 2;;
    --name)
      NAME="$2"; shift 2;;
    --url)
      CONNECT_URL="$2"; shift 2;;
    --k8s)
      K8S_MODE=1; K8S_NAMESPACE="$2"; K8S_DEPLOYMENT="$3"; shift 3;;
    *)
      echo "Unknown argument: $1"; exit 1;;
  esac
done

if [[ -z "$CONFIG" ]]; then
  echo "--config <config.json> is required"; exit 1
fi

if [[ -z "$NAME" ]]; then
  NAME=$(jq -r '.name // .config["name"] // empty' "$CONFIG")
  if [[ -z "$NAME" ]]; then
    echo "--name not provided and not found in config file"; exit 1
  fi
fi

if ! jq empty "$CONFIG" 2>/dev/null; then
  echo "ERROR: Invalid JSON in $CONFIG."; exit 1
fi

register_connector() {
  if curl -sf "$CONNECT_URL/connectors/$NAME" >/dev/null; then
    curl -sf -X PUT \
      -H "Content-Type: application/json" \
      --data "@${CONFIG}" \
      "$CONNECT_URL/connectors/$NAME/config" >/dev/null
    echo "Updated connector $NAME"
  else
    curl -sf -X POST \
      -H "Content-Type: application/json" \
      --data "{\"name\":\"$NAME\",\"config\":$(cat "$CONFIG")}" \
      "$CONNECT_URL/connectors" >/dev/null
    echo "Created connector $NAME"
  fi
}

register_connector_k8s() {
  if kubectl exec -n "$K8S_NAMESPACE" deploy/"$K8S_DEPLOYMENT" -- curl -sf http://localhost:8083/connectors/"$NAME" >/dev/null; then
    kubectl exec -n "$K8S_NAMESPACE" deploy/"$K8S_DEPLOYMENT" -- curl -sf -X PUT \
      -H "Content-Type: application/json" \
      --data "@${CONFIG}" \
      http://localhost:8083/connectors/"$NAME"/config >/dev/null
    echo "[k8s] Updated connector $NAME"
  else
    kubectl exec -n "$K8S_NAMESPACE" deploy/"$K8S_DEPLOYMENT" -- curl -sf -X POST \
      -H "Content-Type: application/json" \
      --data "{\"name\":\"$NAME\",\"config\":$(cat "$CONFIG")}" \
      http://localhost:8083/connectors >/dev/null
    echo "[k8s] Created connector $NAME"
  fi
}

if [[ $K8S_MODE -eq 1 ]]; then
  register_connector_k8s
else
  register_connector
fi
