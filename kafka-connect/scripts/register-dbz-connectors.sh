#!/bin/sh

set -eu
(set -o pipefail >/dev/null 2>&1) && set -o pipefail

CONNECT_URL="${CONNECT_URL:-http://dbz-connect:8083}"
CONNECTORS_DIR="/connectors"
CONNECTOR_FILES="dbz-mysql-mdm.json"
CONNECT_WAIT_SECONDS="${CONNECT_WAIT_SECONDS:-180}"

echo "Waiting for Kafka Connect at $CONNECT_URL ..."
start_ts=$(date +%s)
attempt=0
until curl -sS -f --connect-timeout 2 "$CONNECT_URL/connector-plugins" >/dev/null 2>&1; do
  now_ts=$(date +%s)
  elapsed=$((now_ts - start_ts))
  attempt=$((attempt + 1))

  if [ "$elapsed" -ge "$CONNECT_WAIT_SECONDS" ]; then
    echo "Timed out after ${CONNECT_WAIT_SECONDS}s waiting for Kafka Connect at $CONNECT_URL"
    exit 1
  fi

  # Keep wait logs readable; avoid printing every transient DNS/connect error.
  if [ $((attempt % 10)) -eq 0 ]; then
    echo "Still waiting for Kafka Connect (${elapsed}s elapsed)..."
  fi

  sleep 2
done
echo "Kafka Connect is reachable at $CONNECT_URL"

OLD_IFS="$IFS"
IFS=','
set -- $CONNECTOR_FILES
IFS="$OLD_IFS"

for file_name in "$@"; do
  config="$CONNECTORS_DIR/$file_name"
  if [ -f "$config" ]; then
    name=$(jq -r .name "$config")
    payload=$(jq -c .config "$config")
    echo "Registering connector: $name"

    attempt=1
    max_attempts=5
    while [ "$attempt" -le "$max_attempts" ]; do
      tmp_body="/tmp/${name}-register-response.json"
      http_code=$(curl -sS -o "$tmp_body" -w "%{http_code}" \
        -X PUT -H "Content-Type: application/json" \
        --data "$payload" \
        "$CONNECT_URL/connectors/$name/config" || true)

      if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "Connector registered: $name (HTTP $http_code)"
        break
      fi

      echo "Connector registration failed for $name (attempt $attempt/$max_attempts, HTTP $http_code)"
      [ -f "$tmp_body" ] && cat "$tmp_body"

      if [ "$attempt" -eq "$max_attempts" ]; then
        echo "Giving up registering connector: $name"
        exit 1
      fi

      attempt=$((attempt + 1))
      sleep 3
    done
  fi
done
