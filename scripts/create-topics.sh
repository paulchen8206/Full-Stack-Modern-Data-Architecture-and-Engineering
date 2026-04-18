#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVERS:-kafka:9092}"
TOPICS=(raw_sales_orders sales_order sales_order_line_item customer_sales)
KAFKA_TOPICS_BIN="${KAFKA_TOPICS_BIN:-/opt/kafka/bin/kafka-topics.sh}"
CONNECT_CONFIG_TOPIC="connect-configs"
CONNECT_OFFSET_TOPIC="connect-offsets"
CONNECT_STATUS_TOPIC="connect-status"
ICEBERG_CONTROL_TOPIC="connect-iceberg-control"

echo "Waiting for Kafka on ${BOOTSTRAP_SERVER}"
until "${KAFKA_TOPICS_BIN}" --bootstrap-server "${BOOTSTRAP_SERVER}" --list >/dev/null 2>&1; do
  sleep 2
done

for topic in "${TOPICS[@]}"; do
  "${KAFKA_TOPICS_BIN}" \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --create \
    --if-not-exists \
    --topic "${topic}" \
    --replication-factor 1 \
    --partitions 3
done

"${KAFKA_TOPICS_BIN}" \
  --bootstrap-server "${BOOTSTRAP_SERVER}" \
  --create \
  --if-not-exists \
  --topic "${CONNECT_CONFIG_TOPIC}" \
  --replication-factor 1 \
  --partitions 1 \
  --config cleanup.policy=compact

"${KAFKA_TOPICS_BIN}" \
  --bootstrap-server "${BOOTSTRAP_SERVER}" \
  --create \
  --if-not-exists \
  --topic "${CONNECT_OFFSET_TOPIC}" \
  --replication-factor 1 \
  --partitions 6 \
  --config cleanup.policy=compact

"${KAFKA_TOPICS_BIN}" \
  --bootstrap-server "${BOOTSTRAP_SERVER}" \
  --create \
  --if-not-exists \
  --topic "${CONNECT_STATUS_TOPIC}" \
  --replication-factor 1 \
  --partitions 3 \
  --config cleanup.policy=compact

"${KAFKA_TOPICS_BIN}" \
  --bootstrap-server "${BOOTSTRAP_SERVER}" \
  --create \
  --if-not-exists \
  --topic "${ICEBERG_CONTROL_TOPIC}" \
  --replication-factor 1 \
  --partitions 3

echo "Kafka topics are ready"

