import json
import os
import time
import urllib.error
import urllib.request
from collections.abc import Iterable
from datetime import datetime, timezone
from decimal import Decimal

from confluent_kafka.avro import AvroConsumer


TOPIC_TABLES = {
    "sales_order": "sales_order",
    "sales_order_line_item": "sales_order_line_item",
    "customer_sales": "customer_sales",
}


def chunked(items: list, batch_size: int) -> Iterable[list]:
    for start in range(0, len(items), batch_size):
        yield items[start : start + batch_size]





def trino_request(sql: str, server: str, user: str, catalog: str, schema: str) -> dict:
    request = urllib.request.Request(
        url=f"{server.rstrip('/')}/v1/statement",
        data=sql.encode("utf-8"),
        method="POST",
    )
    request.add_header("X-Trino-User", user)
    request.add_header("X-Trino-Catalog", catalog)
    request.add_header("X-Trino-Schema", schema)
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read().decode("utf-8"))


def execute_trino(sql: str, server: str, user: str, catalog: str, schema: str) -> None:
    result = trino_request(sql, server, user, catalog, schema)
    while True:
        if "error" in result:
            message = result["error"].get("message", "unknown error")
            raise RuntimeError(f"Trino query failed: {message}")
        next_uri = result.get("nextUri")
        if not next_uri:
            return
        with urllib.request.urlopen(next_uri) as response:
            result = json.loads(response.read().decode("utf-8"))


def sql_string(value: str | None) -> str:
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


def sql_decimal(value: str | None) -> str:
    if value is None:
        return "CAST(NULL AS DECIMAL(18,2))"
    # Handle Avro logicalType decimal bytes
    if isinstance(value, bytes):
        # Avro decimal bytes are big-endian signed integers, scale is usually 2
        # For simplicity, convert to int then divide by 100 (scale=2)
        int_value = int.from_bytes(value, byteorder="big", signed=True)
        value = str(Decimal(int_value) / Decimal("100"))
    Decimal(value)
    return f"CAST({sql_string(value)} AS DECIMAL(18,2))"


def sql_int(value) -> str:
    if value is None:
        return "NULL"
    return str(int(value))


def sql_bigint(value) -> str:
    if value is None:
        return "NULL"
    return str(int(value))


def sql_timestamp(epoch_ms) -> str:
    if epoch_ms is None:
        return "CAST(NULL AS TIMESTAMP(3))"
    # Accept both integer epoch ms and ISO8601 string
    if isinstance(epoch_ms, (int, float)) or (isinstance(epoch_ms, str) and epoch_ms.isdigit()):
        timestamp = datetime.fromtimestamp(int(epoch_ms) / 1000, tz=timezone.utc)
    else:
        # Try to parse ISO8601 string
        try:
            timestamp = datetime.fromisoformat(epoch_ms.replace("Z", "+00:00"))
        except Exception:
            return "CAST(NULL AS TIMESTAMP(3))"
    formatted = timestamp.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    return f"TIMESTAMP {sql_string(formatted)}"


def bootstrap_sql(schema: str) -> list[str]:
    base = f"s3://warehouse/iceberg/{schema}"
    return [
        f"CREATE SCHEMA IF NOT EXISTS lakehouse.{schema} WITH (location = '{base}')",
        f"""
        CREATE TABLE IF NOT EXISTS lakehouse.{schema}.sales_order (
          order_id VARCHAR,
          order_timestamp TIMESTAMP(3),
          customer_id VARCHAR,
          customer_name VARCHAR,
          customer_email VARCHAR,
          customer_segment VARCHAR,
          currency VARCHAR,
          order_total DECIMAL(18,2),
          line_item_count INTEGER
        ) WITH (format = 'PARQUET', location = '{base}/sales_order')
        """,
        f"""
        CREATE TABLE IF NOT EXISTS lakehouse.{schema}.sales_order_line_item (
          order_id VARCHAR,
          order_timestamp TIMESTAMP(3),
          customer_id VARCHAR,
          customer_name VARCHAR,
          line_item_id VARCHAR,
          sku VARCHAR,
          product_name VARCHAR,
          quantity INTEGER,
          unit_price DECIMAL(18,2),
          line_total DECIMAL(18,2),
          currency VARCHAR
        ) WITH (format = 'PARQUET', location = '{base}/sales_order_line_item')
        """,
        f"""
        CREATE TABLE IF NOT EXISTS lakehouse.{schema}.customer_sales (
          customer_id VARCHAR,
          customer_name VARCHAR,
          customer_email VARCHAR,
          customer_segment VARCHAR,
          order_count BIGINT,
          total_spent DECIMAL(18,2),
          last_order_id VARCHAR,
          updated_at TIMESTAMP(3),
          currency VARCHAR
        ) WITH (format = 'PARQUET', location = '{base}/customer_sales')
        """,
    ]


def unwrap_payload(message_value: dict) -> dict:
    payload = message_value.get("payload")
    if isinstance(payload, dict):
        return payload
    return message_value


def topic_key(topic: str, payload: dict) -> str | None:
    if topic == "sales_order":
        return payload.get("orderId")
    if topic == "sales_order_line_item":
        return payload.get("lineItemId")
    if topic == "customer_sales":
        return payload.get("customerId")
    raise KeyError(f"Unsupported topic {topic}")


def dedupe_payloads(topic: str, payloads: list[dict]) -> list[dict]:
    # Keep only the latest record per entity key within a flush window so MERGE
    # statements do not thrash on multiple updates for the same key.
    latest_by_key: dict[str, dict] = {}
    for payload in payloads:
        payload_key = topic_key(topic, payload)
        if not payload_key:
            continue
        latest_by_key[payload_key] = payload
    return list(latest_by_key.values())


def values_clause(rows: list[list[str]]) -> str:
    return ",\n        ".join("(" + ", ".join(row) + ")" for row in rows)


def sales_order_rows(payloads: list[dict]) -> list[list[str]]:
    return [
        [
            sql_string(payload.get("orderId")),
            sql_timestamp(payload.get("orderTimestamp")),
            sql_string(payload.get("customerId")),
            sql_string(payload.get("customerName")),
            sql_string(payload.get("customerEmail")),
            sql_string(payload.get("customerSegment")),
            sql_string(payload.get("currency")),
            sql_decimal(payload.get("orderTotal")),
            sql_int(payload.get("lineItemCount")),
        ]
        for payload in payloads
    ]


def merge_sales_order(schema: str, payloads: list[dict]) -> str:
    rows = sales_order_rows(dedupe_payloads("sales_order", payloads))
    return f"""
    MERGE INTO lakehouse.{schema}.sales_order t
    USING (
      VALUES
        {values_clause(rows)}
    ) AS s(
      order_id,
      order_timestamp,
      customer_id,
      customer_name,
      customer_email,
      customer_segment,
      currency,
      order_total,
      line_item_count
    )
    ON t.order_id = s.order_id
    WHEN MATCHED THEN UPDATE SET
      order_timestamp = s.order_timestamp,
      customer_id = s.customer_id,
      customer_name = s.customer_name,
      customer_email = s.customer_email,
      customer_segment = s.customer_segment,
      currency = s.currency,
      order_total = s.order_total,
      line_item_count = s.line_item_count
    WHEN NOT MATCHED THEN INSERT (
      order_id, order_timestamp, customer_id, customer_name, customer_email,
      customer_segment, currency, order_total, line_item_count
    ) VALUES (
      s.order_id, s.order_timestamp, s.customer_id, s.customer_name, s.customer_email,
      s.customer_segment, s.currency, s.order_total, s.line_item_count
    )
    """


def sales_order_line_item_rows(payloads: list[dict]) -> list[list[str]]:
    return [
        [
            sql_string(payload.get("orderId")),
            sql_timestamp(payload.get("orderTimestamp")),
            sql_string(payload.get("customerId")),
            sql_string(payload.get("customerName")),
            sql_string(payload.get("lineItemId")),
            sql_string(payload.get("sku")),
            sql_string(payload.get("productName")),
            sql_int(payload.get("quantity")),
            sql_decimal(payload.get("unitPrice")),
            sql_decimal(payload.get("lineTotal")),
            sql_string(payload.get("currency")),
        ]
        for payload in payloads
    ]


def merge_sales_order_line_item(schema: str, payloads: list[dict]) -> str:
    rows = sales_order_line_item_rows(dedupe_payloads("sales_order_line_item", payloads))
    return f"""
    MERGE INTO lakehouse.{schema}.sales_order_line_item t
    USING (
      VALUES
        {values_clause(rows)}
    ) AS s(
      order_id,
      order_timestamp,
      customer_id,
      customer_name,
      line_item_id,
      sku,
      product_name,
      quantity,
      unit_price,
      line_total,
      currency
    )
    ON t.line_item_id = s.line_item_id
    WHEN MATCHED THEN UPDATE SET
      order_id = s.order_id,
      order_timestamp = s.order_timestamp,
      customer_id = s.customer_id,
      customer_name = s.customer_name,
      sku = s.sku,
      product_name = s.product_name,
      quantity = s.quantity,
      unit_price = s.unit_price,
      line_total = s.line_total,
      currency = s.currency
    WHEN NOT MATCHED THEN INSERT (
      order_id, order_timestamp, customer_id, customer_name, line_item_id,
      sku, product_name, quantity, unit_price, line_total, currency
    ) VALUES (
      s.order_id, s.order_timestamp, s.customer_id, s.customer_name, s.line_item_id,
      s.sku, s.product_name, s.quantity, s.unit_price, s.line_total, s.currency
    )
    """


def customer_sales_rows(payloads: list[dict]) -> list[list[str]]:
    return [
        [
            sql_string(payload.get("customerId")),
            sql_string(payload.get("customerName")),
            sql_string(payload.get("customerEmail")),
            sql_string(payload.get("customerSegment")),
            sql_bigint(payload.get("orderCount")),
            sql_decimal(payload.get("totalSpent")),
            sql_string(payload.get("lastOrderId")),
            sql_timestamp(payload.get("updatedAt")),
            sql_string(payload.get("currency")),
        ]
        for payload in payloads
    ]


def merge_customer_sales(schema: str, payloads: list[dict]) -> str:
    rows = customer_sales_rows(dedupe_payloads("customer_sales", payloads))
    return f"""
    MERGE INTO lakehouse.{schema}.customer_sales t
    USING (
      VALUES
        {values_clause(rows)}
    ) AS s(
      customer_id,
      customer_name,
      customer_email,
      customer_segment,
      order_count,
      total_spent,
      last_order_id,
      updated_at,
      currency
    )
    ON t.customer_id = s.customer_id
    WHEN MATCHED THEN UPDATE SET
      customer_name = s.customer_name,
      customer_email = s.customer_email,
      customer_segment = s.customer_segment,
      order_count = s.order_count,
      total_spent = s.total_spent,
      last_order_id = s.last_order_id,
      updated_at = s.updated_at,
      currency = s.currency
    WHEN NOT MATCHED THEN INSERT (
      customer_id, customer_name, customer_email, customer_segment,
      order_count, total_spent, last_order_id, updated_at, currency
    ) VALUES (
      s.customer_id, s.customer_name, s.customer_email, s.customer_segment,
      s.order_count, s.total_spent, s.last_order_id, s.updated_at, s.currency
    )
    """


def statement_for(topic: str, schema: str, payloads: list[dict]) -> str:
    if topic == "sales_order":
        return merge_sales_order(schema, payloads)
    if topic == "sales_order_line_item":
        return merge_sales_order_line_item(schema, payloads)
    if topic == "customer_sales":
        return merge_customer_sales(schema, payloads)
    raise KeyError(f"Unsupported topic {topic}")


def wait_for_trino(server: str, user: str, catalog: str, schema: str) -> None:
    while True:
        try:
            execute_trino("SHOW CATALOGS", server, user, catalog, schema)
            return
        except Exception as exc:  # noqa: BLE001
            print(f"waiting for trino: {exc}", flush=True)
            time.sleep(3)


def ensure_schema_registry_reachable(schema_registry_url: str) -> None:
    probe_url = f"{schema_registry_url.rstrip('/')}/subjects"
    request = urllib.request.Request(url=probe_url, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            if response.status >= 400:
                raise RuntimeError(
                    f"Schema Registry probe failed with HTTP {response.status} at {probe_url}"
                )
    except urllib.error.URLError as exc:
        hint = ""
        if "localhost" in schema_registry_url:
            hint = " (inside Kubernetes, use the service DNS name like http://schema-registry:8081)"
        raise RuntimeError(
            f"Schema Registry is unreachable at {schema_registry_url}. "
            "Set SCHEMA_REGISTRY_URL to a reachable endpoint" + hint
        ) from exc


def flush_topic_batch(
    topic: str,
    payloads: list[dict],
    schema: str,
    server: str,
    user: str,
    catalog: str,
) -> None:
    if not payloads:
        return
    valid_payloads = [payload for payload in payloads if topic_key(topic, payload)]
    if not valid_payloads:
        print(f"skipped {len(payloads)} {topic} events without merge keys", flush=True)
        return
    # One MERGE per batch provides idempotent upsert semantics in Iceberg tables.
    sql = statement_for(topic, schema, valid_payloads)
    execute_trino(sql, server, user, catalog, schema)
    print(
        f"upserted {len(valid_payloads)} {topic} events into lakehouse.{schema}.{TOPIC_TABLES[topic]}",
        flush=True,
    )


def commit_batch_offsets(consumer: AvroConsumer, batch_messages: list) -> None:
    latest_offsets = {}
    for msg in batch_messages:
        key = (msg.topic(), msg.partition())
        current = latest_offsets.get(key)
        if current is None or msg.offset() > current.offset():
            latest_offsets[key] = msg

    for msg in latest_offsets.values():
        consumer.commit(message=msg, asynchronous=False)


def main() -> None:
    bootstrap_servers_env = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
    print(f"[DEBUG] KAFKA_BOOTSTRAP_SERVERS env: {bootstrap_servers_env}", flush=True)
    group_id = os.getenv("ICEBERG_WRITER_GROUP_ID", "iceberg-writer")
    server = os.getenv("TRINO_URL", "http://trino:8080")
    user = os.getenv("TRINO_USER", "analytics")
    catalog = os.getenv("ICEBERG_CATALOG", "lakehouse")
    schema = os.getenv("ICEBERG_SCHEMA", "streaming")
    topics = os.getenv("ICEBERG_WRITER_TOPICS", "sales_order,sales_order_line_item,customer_sales").split(",")
    batch_size = int(os.getenv("ICEBERG_WRITER_BATCH_SIZE", "50"))
    poll_timeout_ms = int(os.getenv("ICEBERG_WRITER_POLL_TIMEOUT_MS", "1000"))
    flush_interval_ms = int(os.getenv("ICEBERG_WRITER_FLUSH_INTERVAL_MS", "5000"))
    max_poll_records = int(os.getenv("ICEBERG_WRITER_MAX_POLL_RECORDS", str(batch_size * len(topics))))
    schema_registry_url = os.getenv("SCHEMA_REGISTRY_URL", "http://localhost:8081")

    # Block until Trino is query-ready before bootstrap DDL and consumption start.
    wait_for_trino(server, user, catalog, schema)
    for sql in bootstrap_sql(schema):
        execute_trino(sql, server, user, catalog, schema)

    ensure_schema_registry_reachable(schema_registry_url)


    consumer = AvroConsumer({
        'bootstrap.servers': bootstrap_servers_env,
        'group.id': group_id,
        'auto.offset.reset': os.getenv("ICEBERG_WRITER_OFFSET_RESET", "earliest"),
        'enable.auto.commit': False,
        'schema.registry.url': schema_registry_url,
    })
    consumer.subscribe(topics)

    print("iceberg writer started", flush=True)

    # Track per-topic in-memory buffers to flush on size or time thresholds.
    pending_payloads: dict[str, list] = {topic: [] for topic in topics}
    last_flush_at: dict[str, float] = {topic: time.monotonic() for topic in topics}


    while True:
        msg = consumer.poll(timeout=poll_timeout_ms / 1000)
        now = time.monotonic()
        if msg is not None and msg.value() is not None:
            topic = msg.topic()
            if topic not in TOPIC_TABLES:
                continue
            pending_payloads[topic].append((msg, unwrap_payload(msg.value())))

        for topic in topics:
            entries = pending_payloads[topic]
            if not entries:
                continue
            should_flush = len(entries) >= batch_size or (now - last_flush_at[topic]) * 1000 >= flush_interval_ms
            if not should_flush:
                continue

            processed_count = 0
            flush_failed = False
            for entry_batch in chunked(entries, batch_size):
                batch_messages = [message for message, _ in entry_batch]
                batch_payloads = [payload for _, payload in entry_batch]
                try:
                    flush_topic_batch(topic, batch_payloads, schema, server, user, catalog)
                    commit_batch_offsets(consumer, batch_messages)
                    processed_count += len(entry_batch)
                except (RuntimeError, urllib.error.URLError, ValueError) as exc:
                    print(f"failed to write {topic} batch: {exc}", flush=True)
                    time.sleep(2)
                    flush_failed = True
                    break

            if processed_count > 0:
                pending_payloads[topic] = entries[processed_count:]
                last_flush_at[topic] = time.monotonic()

            if flush_failed:
                continue



if __name__ == "__main__":
    main()
