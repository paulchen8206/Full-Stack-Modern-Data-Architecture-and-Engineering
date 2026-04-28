#!/usr/bin/env bash
# kafka-topics.sh: Unified Kafka topic management script
# Usage:
#   ./scripts/kafka-topics.sh create [--topics topic1,topic2,...]
#   ./scripts/kafka-topics.sh list
#   ./scripts/kafka-topics.sh consume <topic> [message-count]
#   ./scripts/kafka-topics.sh check-pipeline [--topics topic1,topic2,...] [--count N]

set -euo pipefail

BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVERS:-kafka:9094}"
KAFKA_TOPICS_BIN="${KAFKA_TOPICS_BIN:-/opt/kafka/bin/kafka-topics.sh}"
KAFKA_CONSUMER_BIN="${KAFKA_CONSUMER_BIN:-/opt/kafka/bin/kafka-console-consumer.sh}"
DEFAULT_TOPICS=(raw_sales_orders sales_order sales_order_line_item customer_sales mdm_customer mdm_product)

usage() {
  echo "Usage: $0 <create|list|consume|check-pipeline> [options]"
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

COMMAND="$1"; shift

case "$COMMAND" in
  create)
    TOPICS=("${DEFAULT_TOPICS[@]}")
    while [[ $# -gt 0 ]]; do
      case $1 in
        --topics)
          IFS=',' read -ra TOPICS <<< "$2"; shift 2;;
        *)
          echo "Unknown argument: $1"; exit 1;;
      esac
    done
    echo "Waiting for Kafka on ${BOOTSTRAP_SERVER}"
    until "$KAFKA_TOPICS_BIN" --bootstrap-server "$BOOTSTRAP_SERVER" --list >/dev/null 2>&1; do
      sleep 2
    done
    for topic in "${TOPICS[@]}"; do
      "$KAFKA_TOPICS_BIN" \
        --bootstrap-server "$BOOTSTRAP_SERVER" \
        --create \
        --if-not-exists \
        --topic "$topic" \
        --replication-factor 1 \
        --partitions 3
    done
    # Create internal topics (compacted, etc.)
    "$KAFKA_TOPICS_BIN" --bootstrap-server "$BOOTSTRAP_SERVER" --create --if-not-exists --topic connect-configs --replication-factor 1 --partitions 1 --config cleanup.policy=compact
    "$KAFKA_TOPICS_BIN" --bootstrap-server "$BOOTSTRAP_SERVER" --create --if-not-exists --topic connect-offsets --replication-factor 1 --partitions 6 --config cleanup.policy=compact
    "$KAFKA_TOPICS_BIN" --bootstrap-server "$BOOTSTRAP_SERVER" --create --if-not-exists --topic connect-status --replication-factor 1 --partitions 1 --config cleanup.policy=compact
    "$KAFKA_TOPICS_BIN" --bootstrap-server "$BOOTSTRAP_SERVER" --create --if-not-exists --topic connect-iceberg-control --replication-factor 1 --partitions 1
    "$KAFKA_TOPICS_BIN" --bootstrap-server "$BOOTSTRAP_SERVER" --create --if-not-exists --topic mdm-connect-configs --replication-factor 1 --partitions 1 --config cleanup.policy=compact
    "$KAFKA_TOPICS_BIN" --bootstrap-server "$BOOTSTRAP_SERVER" --create --if-not-exists --topic mdm-connect-offsets --replication-factor 1 --partitions 6 --config cleanup.policy=compact
    "$KAFKA_TOPICS_BIN" --bootstrap-server "$BOOTSTRAP_SERVER" --create --if-not-exists --topic mdm-connect-status --replication-factor 1 --partitions 1 --config cleanup.policy=compact
    ;;
  list)
    "$KAFKA_TOPICS_BIN" --bootstrap-server "$BOOTSTRAP_SERVER" --list
    ;;
  consume)
    TOPIC="${1:-}"; shift || true
    MESSAGE_COUNT="${1:-5}"
    TIMEOUT_MS="${TIMEOUT_MS:-15000}"
    if [[ -z "$TOPIC" ]]; then
      echo "usage: $0 consume <topic> [message-count]" >&2
      exit 1
    fi
    "$KAFKA_CONSUMER_BIN" \
      --bootstrap-server "$BOOTSTRAP_SERVER" \
      --topic "$TOPIC" \
      --from-beginning \
      --timeout-ms "$TIMEOUT_MS" \
      --max-messages "$MESSAGE_COUNT"
    ;;
  check-pipeline)
    TOPICS=("${DEFAULT_TOPICS[@]}")
    MESSAGE_COUNT=1
    while [[ $# -gt 0 ]]; do
      case $1 in
        --topics)
          IFS=',' read -ra TOPICS <<< "$2"; shift 2;;
        --count)
          MESSAGE_COUNT="$2"; shift 2;;
        *)
          echo "Unknown argument: $1"; exit 1;;
      esac
    done
    for topic in "${TOPICS[@]}"; do
      echo "===== ${topic} ====="
      "$0" consume "$topic" "$MESSAGE_COUNT"
      echo
    done
    ;;
  *)
    usage
    ;;
esac
