#!/bin/bash
set -euo pipefail

BOOTSTRAP_SERVER="kafka-1:19092"
TOPIC_BIN="/usr/bin/kafka-topics"
DEFAULT_PARTITIONS="3"
DEFAULT_REPLICATION_FACTOR="3"

BUSINESS_TOPICS=(
  raw_sales_orders
  sales_order
  sales_order_line_item
  customer_sales
  mdm_customer
  mdm_product
  mdm_date
  mdm_customer_jdbc
  mdm_product_jdbc
  mdm_date_jdbc
  connect-iceberg-control
)

CDC_TOPICS=(
  mdm_mysql.mdm.customer360
  mdm_mysql.mdm.product_master
  mdm_mysql.mdm.mdm_date
  schema-changes.mdm
)

# format: <topic>:<partitions>
COMPACT_TOPICS=(
  dbz-connect-configs:1
  dbz-connect-offsets:3
  dbz-connect-status:3
  connect-configs:1
  connect-offsets:3
  connect-status:3
  mdm-connect-configs:1
  mdm-connect-offsets:3
  mdm-connect-status:3
)

create_topic() {
  local topic="$1"
  local partitions="${2:-$DEFAULT_PARTITIONS}"

  "$TOPIC_BIN" --bootstrap-server "$BOOTSTRAP_SERVER" --create --if-not-exists \
    --topic "$topic" --replication-factor "$DEFAULT_REPLICATION_FACTOR" --partitions "$partitions" || true
}

create_compact_topic() {
  local topic="$1"
  local partitions="$2"

  "$TOPIC_BIN" --bootstrap-server "$BOOTSTRAP_SERVER" --create --if-not-exists \
    --topic "$topic" --replication-factor "$DEFAULT_REPLICATION_FACTOR" --partitions "$partitions" \
    --config cleanup.policy=compact || true
}


# Wait for Kafka to be ready
until "$TOPIC_BIN" --bootstrap-server "$BOOTSTRAP_SERVER" --list >/dev/null 2>&1; do
  echo "Waiting for Kafka to be ready..."
  sleep 2
done

# Create business topics
for topic in "${BUSINESS_TOPICS[@]}"; do
  create_topic "$topic"
done

for topic in "${CDC_TOPICS[@]}"; do
  create_topic "$topic"
done

# Create Kafka Connect internal topics with compact policy
for spec in "${COMPACT_TOPICS[@]}"; do
  topic="${spec%%:*}"
  partitions="${spec#*:}"
  create_compact_topic "$topic" "$partitions"
done

echo "Kafka topics created."
