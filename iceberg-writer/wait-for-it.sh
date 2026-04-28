#!/usr/bin/env bash
# wait-for-it.sh: Wait until a host:port is available
# Usage: wait-for-it.sh host:port -- command args

host=$(echo "$1" | cut -d: -f1)
port=$(echo "$1" | cut -d: -f2)
shift

for i in {1..60}; do
  nc -z "$host" "$port" && exec "$@"
  echo "Waiting for $host:$port... ($i/60)"
  sleep 1
done

echo "Timeout waiting for $host:$port" >&2
exit 1
