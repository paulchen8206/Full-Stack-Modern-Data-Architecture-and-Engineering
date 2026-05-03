#!/bin/sh
set -eu

/entrypoint.sh "$@" &
mysql_pid=$!

echo "Starting MDM source data generator with MySQL retry..."

export MYSQL_HOST=127.0.0.1
export MYSQL_PORT=3306
export MYSQL_USER=root
export MYSQL_PASSWORD="${MYSQL_ROOT_PASSWORD}"
export MYSQL_DATABASE="${MYSQL_DATABASE}"
export MDM_SOURCE_INTERVAL_SEC="${MDM_SOURCE_INTERVAL_SEC}"
export MDM_INSERT_NEW_KEY_PROB="${MDM_INSERT_NEW_KEY_PROB:-0.8}"

python3 /opt/mdm-source/main.py &

generator_pid=$!

wait "${mysql_pid}"
kill "${generator_pid}" 2>/dev/null || true
