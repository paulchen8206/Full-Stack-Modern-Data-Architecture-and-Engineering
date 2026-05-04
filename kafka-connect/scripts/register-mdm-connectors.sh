#!/bin/sh

set -eu
(set -o pipefail >/dev/null 2>&1) && set -o pipefail

CONNECT_URL="${CONNECT_URL:-http://mdm-connect:8083}"
CONNECTORS_DIR="${CONNECTORS_DIR:-/connectors}"
CONNECTOR_FILES="${CONNECTOR_FILES:-s3-mdm-customer.json,s3-mdm-product.json,s3-mdm-date.json,jdbc-mdm-warehouse.json}"
CONNECT_WAIT_SECONDS="${CONNECT_WAIT_SECONDS:-180}"
CONNECT_WAIT_INTERVAL_SEC="${CONNECT_WAIT_INTERVAL_SEC:-2}"
CONNECT_REGISTER_RETRIES="${CONNECT_REGISTER_RETRIES:-5}"
CONNECT_REGISTER_RETRY_DELAY_SEC="${CONNECT_REGISTER_RETRY_DELAY_SEC:-3}"

if ! command -v curl >/dev/null 2>&1; then
	echo "curl command not found"
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	echo "jq command not found"
	exit 1
fi

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

	if [ $((attempt % 10)) -eq 0 ]; then
		echo "Still waiting for Kafka Connect (${elapsed}s elapsed)..."
	fi

	sleep "$CONNECT_WAIT_INTERVAL_SEC"
done
echo "Kafka Connect is reachable at $CONNECT_URL"

OLD_IFS="$IFS"
IFS=','
set -- $CONNECTOR_FILES
IFS="$OLD_IFS"

for file_name in "$@"; do
	config="$CONNECTORS_DIR/$file_name"
	if [ ! -f "$config" ]; then
		echo "Skipping missing connector config: $config"
		continue
	fi

	name=$(jq -r '.name // empty' "$config")
	if [ -z "$name" ]; then
		echo "Skipping connector config without name: $config"
		continue
	fi

	payload=$(jq -c '.config' "$config")

	echo "Registering connector: $name"

	attempt=1
	while [ "$attempt" -le "$CONNECT_REGISTER_RETRIES" ]; do
		tmp_body="/tmp/${name}-register-response.json"
		http_code=$(curl -sS -o "$tmp_body" -w "%{http_code}" \
			-X PUT -H "Content-Type: application/json" \
			--data "$payload" \
			"$CONNECT_URL/connectors/$name/config" || true)

		if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
			echo "Connector registered: $name (HTTP $http_code)"
			break
		fi

		echo "Connector registration failed for $name (attempt $attempt/$CONNECT_REGISTER_RETRIES, HTTP $http_code)"
		[ -f "$tmp_body" ] && cat "$tmp_body"

		if [ "$attempt" -eq "$CONNECT_REGISTER_RETRIES" ]; then
			echo "Giving up registering connector: $name"
			exit 1
		fi

		attempt=$((attempt + 1))
		sleep "$CONNECT_REGISTER_RETRY_DELAY_SEC"
	done
done
