#!/bin/bash
set -euo pipefail


# Wait for Kafka to be ready
until /usr/bin/kafka-topics --bootstrap-server kafka-1:19092 --list >/dev/null 2>&1; do
  echo "Waiting for Kafka to be ready..."
  sleep 2
done

# Create business topics
for topic in raw_sales_orders sales_order sales_order_line_item customer_sales mdm_customer mdm_product mdm_date mdm_customer_jdbc mdm_product_jdbc mdm_date_jdbc connect-iceberg-control; do
  /usr/bin/kafka-topics --bootstrap-server kafka-1:19092 --create --if-not-exists --topic "$topic" --replication-factor 3 --partitions 3 || true
done

for topic in mdm_mysql.mdm.customer360 mdm_mysql.mdm.product_master mdm_mysql.mdm.mdm_date schema-changes.mdm; do
  /usr/bin/kafka-topics --bootstrap-server kafka-1:19092 --create --if-not-exists --topic "$topic" --replication-factor 3 --partitions 3 || true
done

# Create Kafka Connect internal topics with compact policy
# debezium-connect cluster (CDC source)
/usr/bin/kafka-topics --bootstrap-server kafka-1:19092 --create --if-not-exists --topic debezium-connect-configs --replication-factor 3 --partitions 1 --config cleanup.policy=compact || true
/usr/bin/kafka-topics --bootstrap-server kafka-1:19092 --create --if-not-exists --topic debezium-connect-offsets --replication-factor 3 --partitions 3 --config cleanup.policy=compact || true
/usr/bin/kafka-topics --bootstrap-server kafka-1:19092 --create --if-not-exists --topic debezium-connect-status --replication-factor 3 --partitions 3 --config cleanup.policy=compact || true

# connect cluster (sales S3/JDBC sinks)
/usr/bin/kafka-topics --bootstrap-server kafka-1:19092 --create --if-not-exists --topic connect-configs --replication-factor 3 --partitions 1 --config cleanup.policy=compact || true
/usr/bin/kafka-topics --bootstrap-server kafka-1:19092 --create --if-not-exists --topic connect-offsets --replication-factor 3 --partitions 3 --config cleanup.policy=compact || true
/usr/bin/kafka-topics --bootstrap-server kafka-1:19092 --create --if-not-exists --topic connect-status --replication-factor 3 --partitions 3 --config cleanup.policy=compact || true

# mdm-connect cluster (MDM topic sinks)
/usr/bin/kafka-topics --bootstrap-server kafka-1:19092 --create --if-not-exists --topic mdm-connect-configs --replication-factor 3 --partitions 1 --config cleanup.policy=compact || true
/usr/bin/kafka-topics --bootstrap-server kafka-1:19092 --create --if-not-exists --topic mdm-connect-offsets --replication-factor 3 --partitions 3 --config cleanup.policy=compact || true
/usr/bin/kafka-topics --bootstrap-server kafka-1:19092 --create --if-not-exists --topic mdm-connect-status --replication-factor 3 --partitions 3 --config cleanup.policy=compact || true

echo "Kafka topics created."
