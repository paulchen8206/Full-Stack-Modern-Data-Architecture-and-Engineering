#!/bin/bash
set -euo pipefail


# Wait for Kafka to be ready
until /usr/bin/kafka-topics --bootstrap-server kafka:9092 --list >/dev/null 2>&1; do
  echo "Waiting for Kafka to be ready..."
  sleep 2
done

# Create topics

for topic in raw_sales_orders sales_order sales_order_line_item customer_sales mdm_customer mdm_product \
  connect-configs connect-offsets connect-status connect-iceberg-control mdm-connect-configs mdm-connect-offsets mdm-connect-status; do
  /usr/bin/kafka-topics --bootstrap-server kafka:9092 --create --if-not-exists --topic "$topic" --replication-factor 1 --partitions 3 || true
done

echo "Kafka topics created."
