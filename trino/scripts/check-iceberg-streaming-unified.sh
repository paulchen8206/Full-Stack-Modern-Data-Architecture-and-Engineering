#!/usr/bin/env sh
# check-iceberg-streaming-unified.sh: Unified Iceberg/Trino smoke test for local and k8s
# Usage:
#   ./trino/scripts/check-iceberg-streaming-unified.sh [--k8s] [--namespace ns] [--deployment deploy] [--local-port 8086] [--remote-port 8080]

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

K8S_MODE=0
K8S_NAMESPACE="realtime-dev"
TRINO_DEPLOYMENT="realtime-dev-realtime-app-trino"
LOCAL_TRINO_PORT=8086
TRINO_REMOTE_PORT=8080

while [[ $# -gt 0 ]]; do
  case $1 in
    --k8s) K8S_MODE=1; shift;;
    --namespace) K8S_NAMESPACE="$2"; shift 2;;
    --deployment) TRINO_DEPLOYMENT="$2"; shift 2;;
    --local-port) LOCAL_TRINO_PORT="$2"; shift 2;;
    --remote-port) TRINO_REMOTE_PORT="$2"; shift 2;;
    *) echo "Unknown argument: $1"; exit 1;;
  esac
done

if [[ $K8S_MODE -eq 1 ]]; then
  port_forward_log="$(mktemp)"
  cleanup() {
    if [ -n "${port_forward_pid:-}" ]; then
      kill "$port_forward_pid" >/dev/null 2>&1 || true
      wait "$port_forward_pid" 2>/dev/null || true
    fi
    rm -f "$port_forward_log"
  }
  trap cleanup EXIT INT TERM

  kubectl -n "$K8S_NAMESPACE" rollout status "deployment/$TRINO_DEPLOYMENT" --timeout=300s >/dev/null
  kubectl -n "$K8S_NAMESPACE" port-forward "deployment/$TRINO_DEPLOYMENT" "$LOCAL_TRINO_PORT:$TRINO_REMOTE_PORT" >"$port_forward_log" 2>&1 &
  port_forward_pid=$!

  attempt=1
  while [ "$attempt" -le 20 ]; do
    if curl -fsS "http://localhost:${LOCAL_TRINO_PORT}/v1/info" >/dev/null 2>&1; then
      TRINO_URL="http://localhost:${LOCAL_TRINO_PORT}" "$0"
      exit 0
    fi
    sleep 1
    attempt=$((attempt + 1))
  done

  cat "$port_forward_log" >&2
  echo "Failed to establish Trino port-forward for Kubernetes smoke test." >&2
  exit 1
fi

TRINO_URL="${TRINO_URL:-http://localhost:${LOCAL_TRINO_PORT}}"
SMOKE_MAX_ATTEMPTS="${SMOKE_MAX_ATTEMPTS:-20}"
SMOKE_SLEEP_SECONDS="${SMOKE_SLEEP_SECONDS:-3}"

curl -fsS "$TRINO_URL/v1/info" >/dev/null

query_count() {
  table_name="$1"
  python3 "${SCRIPT_DIR}/trino_query.py" \
    --server "$TRINO_URL" \
    --output json \
    --sql "SELECT count(*) AS row_count FROM lakehouse.streaming.${table_name}" \
  | python3 -c 'import json,sys; payload=json.load(sys.stdin); print(payload["data"][0][0] if payload.get("data") else 0)'
}

attempt=1
while [ "$attempt" -le "$SMOKE_MAX_ATTEMPTS" ]; do
  sales_order_count="$(query_count sales_order)"
  sales_order_line_item_count="$(query_count sales_order_line_item)"
  customer_sales_count="$(query_count customer_sales)"

  echo "attempt ${attempt}/${SMOKE_MAX_ATTEMPTS}: sales_order=${sales_order_count} sales_order_line_item=${sales_order_line_item_count} customer_sales=${customer_sales_count}"

  if [ "$sales_order_count" -gt 0 ] && [ "$sales_order_line_item_count" -gt 0 ] && [ "$customer_sales_count" -gt 0 ]; then
    echo "Iceberg streaming smoke test passed."
    exit 0
  fi

  attempt=$((attempt + 1))
  sleep "$SMOKE_SLEEP_SECONDS"
done

echo "Iceberg streaming smoke test failed: one or more tables remained empty." >&2
exit 1
