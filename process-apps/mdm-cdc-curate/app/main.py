import json
import os
from typing import Any

from kafka import KafkaConsumer, KafkaProducer


TOPIC_MAP = {
    "mdm_mysql.mdm.customer360": "mdm_customer",
    "mdm_mysql.mdm.product_master": "mdm_product",
    "mdm_mysql.mdm.mdm_date": "mdm_date",
}

JDBC_TOPIC_SUFFIX = os.getenv("MDM_JDBC_TOPIC_SUFFIX", "_jdbc")

# Static Connect JSON schemas for schemaful JDBC topics.
JDBC_SCHEMAS: dict[str, dict[str, Any]] = {
    "mdm_customer": {
        "name": "mdm.customer.record",
        "fields": [
            {"field": "customer_id", "type": "string", "optional": False},
            {"field": "customer_name", "type": "string", "optional": True},
            {"field": "customer_email", "type": "string", "optional": True},
            {"field": "customer_segment", "type": "string", "optional": True},
            {"field": "currency", "type": "string", "optional": True},
            {"field": "first_order_timestamp", "type": "string", "optional": True},
            {"field": "last_order_timestamp", "type": "string", "optional": True},
            {"field": "projected_order_count", "type": "int32", "optional": True},
            {"field": "projected_total_spent", "type": "float32", "optional": True},
            {"field": "projection_updated_at", "type": "string", "optional": True},
            {"field": "updated_at", "type": "string", "optional": True},
            {"field": "operation", "type": "string", "optional": True},
            {"field": "source_ts_ms", "type": "int64", "optional": True},
        ],
    },
    "mdm_product": {
        "name": "mdm.product.record",
        "fields": [
            {"field": "product_id", "type": "string", "optional": False},
            {"field": "product_name", "type": "string", "optional": True},
            {"field": "currency", "type": "string", "optional": True},
            {"field": "first_seen_at", "type": "string", "optional": True},
            {"field": "last_seen_at", "type": "string", "optional": True},
            {"field": "orders_count", "type": "int32", "optional": True},
            {"field": "units_sold", "type": "int32", "optional": True},
            {"field": "avg_unit_price", "type": "float32", "optional": True},
            {"field": "updated_at", "type": "string", "optional": True},
            {"field": "operation", "type": "string", "optional": True},
            {"field": "source_ts_ms", "type": "int64", "optional": True},
        ],
    },
    "mdm_date": {
        "name": "mdm.date.record",
        "fields": [
            {"field": "date_key", "type": "int32", "optional": False},
            {"field": "full_date", "type": "string", "optional": True},
            {"field": "day_of_month", "type": "int32", "optional": True},
            {"field": "day_of_week", "type": "int32", "optional": True},
            {"field": "day_name", "type": "string", "optional": True},
            {"field": "week_of_year", "type": "int32", "optional": True},
            {"field": "month_of_year", "type": "int32", "optional": True},
            {"field": "month_name", "type": "string", "optional": True},
            {"field": "quarter_of_year", "type": "int32", "optional": True},
            {"field": "year_number", "type": "int32", "optional": True},
            {"field": "is_weekend", "type": "boolean", "optional": True},
            {"field": "created_at", "type": "string", "optional": True},
            {"field": "updated_at", "type": "string", "optional": True},
            {"field": "operation", "type": "string", "optional": True},
            {"field": "source_ts_ms", "type": "int64", "optional": True},
        ],
    },
}


def decode_json(raw: bytes | None) -> Any:
    if raw is None:
        return None
    return json.loads(raw.decode("utf-8"))


def build_payload(topic: str, value: dict[str, Any]) -> dict[str, Any] | None:
    # Debezium JSON converter may wrap event data in {"schema":..., "payload":...}.
    if "payload" in value and isinstance(value.get("payload"), dict):
        value = value["payload"]

    op = value.get("op")
    if op == "d":
        row = value.get("before")
    else:
        row = value.get("after")

    if row is None:
        # Tombstones and malformed records are dropped to keep downstream topics clean.
        return None

    return {
        "entity": "customer" if topic.endswith("customer360") else "product" if topic.endswith("product_master") else "date",
        "operation": op,
        "sourceTsMs": value.get("ts_ms"),
        "data": row,
    }


def cast_value(field_type: str, raw: Any) -> Any:
    if raw is None:
        return None
    if field_type in {"string"}:
        return str(raw)
    if field_type in {"int32", "int64"}:
        if isinstance(raw, bool):
            return int(raw)
        return int(raw)
    if field_type in {"float32", "float64"}:
        return float(raw)
    if field_type == "boolean":
        if isinstance(raw, bool):
            return raw
        if isinstance(raw, str):
            return raw.lower() in {"1", "true", "yes", "y"}
        return bool(raw)
    return raw


def build_schemaful_payload(target_topic: str, payload: dict[str, Any]) -> dict[str, Any]:
    # JDBC sink expects Kafka Connect schema+payload envelope for reliable type mapping.
    schema_spec = JDBC_SCHEMAS[target_topic]
    row = payload.get("data", {})

    record: dict[str, Any] = {}
    for field in schema_spec["fields"]:
        field_name = field["field"]
        if field_name == "operation":
            raw_value = payload.get("operation")
        elif field_name == "source_ts_ms":
            raw_value = payload.get("sourceTsMs")
        else:
            raw_value = row.get(field_name)
        record[field_name] = cast_value(field["type"], raw_value)

    return {
        "schema": {
            "type": "struct",
            "name": schema_spec["name"],
            "optional": False,
            "fields": schema_spec["fields"],
        },
        "payload": record,
    }


def main() -> None:
    bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092").split(",")
    consumer_group = os.getenv("MDM_CDC_GROUP_ID", "mdm-cdc-publisher")

    consumer = KafkaConsumer(
        *TOPIC_MAP.keys(),
        bootstrap_servers=bootstrap_servers,
        group_id=consumer_group,
        auto_offset_reset=os.getenv("CDC_CONSUMER_OFFSET_RESET", "earliest"),
        enable_auto_commit=True,
        value_deserializer=decode_json,
        key_deserializer=lambda k: k.decode("utf-8") if k else None,
    )

    producer = KafkaProducer(
        bootstrap_servers=bootstrap_servers,
        value_serializer=lambda payload: json.dumps(payload).encode("utf-8"),
        key_serializer=lambda key: key.encode("utf-8") if key else None,
        acks="all",
        linger_ms=20,
    )

    print("mdm cdc producer started", flush=True)

    for msg in consumer:
        if msg.value is None:
            continue

        target_topic = TOPIC_MAP.get(msg.topic)
        if target_topic is None:
            continue

        payload = build_payload(msg.topic, msg.value)
        if payload is None:
            continue

        if target_topic not in JDBC_SCHEMAS:
            continue

        key = str(msg.key) if msg.key else None
        producer.send(target_topic, key=key, value=payload)
        schemaful_topic = f"{target_topic}{JDBC_TOPIC_SUFFIX}"
        # Publish both a lightweight JSON topic and a schemaful companion topic so
        # stream consumers and JDBC sinks can coexist without converter mismatch.
        producer.send(schemaful_topic, key=key, value=build_schemaful_payload(target_topic, payload))
        producer.flush()
        print(
            f"forwarded cdc event from {msg.topic} to {target_topic} and {schemaful_topic}",
            flush=True,
        )


if __name__ == "__main__":
    main()
