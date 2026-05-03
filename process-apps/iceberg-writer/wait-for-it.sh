#!/usr/bin/env bash
# wait-for-it.sh: Wait until a host:port is available
# Usage: wait-for-it.sh host:port -- command args

host=$(echo "$1" | cut -d: -f1)
port=$(echo "$1" | cut -d: -f2)
shift

max_retries="${WAIT_FOR_IT_RETRIES:-180}"

for i in $(seq 1 "$max_retries"); do
  nc -z "$host" "$port" && exec "$@"
  echo "Waiting for $host:$port... ($i/$max_retries)"
  sleep 1
done

echo "Timeout waiting for $host:$port" >&2
exit 1
