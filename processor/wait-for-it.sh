#!/usr/bin/env bash
# wait-for-it.sh: Wait until a TCP host:port is available
# Usage: wait-for-it.sh host:port [--timeout=seconds] [--strict] -- command args


host=$(echo $1 | cut -d: -f1)
port=$(echo $1 | cut -d: -f2)
shift

# Skip any --* options (e.g., --timeout=60) before the command
while [[ "$1" == --* ]]; do
  shift
done

while ! nc -z $host $port; do
  echo "Waiting for $host:$port..."
  sleep 2
done

echo "$host:$port is available. Starting application."
exec "$@"
