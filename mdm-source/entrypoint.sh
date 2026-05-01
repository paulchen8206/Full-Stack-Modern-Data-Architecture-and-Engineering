#!/bin/sh
set -eu

/entrypoint.sh "$@" &
mysql_pid=$!

echo "Starting MDM source data generator with MySQL retry..."

MYSQL_HOST=127.0.0.1 \
MYSQL_PORT=3306 \
MYSQL_USER=root \
MYSQL_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
MYSQL_DATABASE="${MYSQL_DATABASE}" \
MDM_SOURCE_INTERVAL_SEC="${MDM_SOURCE_INTERVAL_SEC}" \
python3 /opt/mdm-source/main.py &

generator_pid=$!

wait "${mysql_pid}"
kill "${generator_pid}" 2>/dev/null || true
