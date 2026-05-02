## 🚀 Quick Start: Unified Docker Routine (Routine A)

All local development, validation, and troubleshooting flows are now consolidated under unified scripts and Make targets. **Deprecated scripts will print a warning and exit.**
### Start the Full Stack (Routine A)

```bash
make routine-a         # Brings up the stack and creates topics
Or, to start only the Compose stack (no topic bootstrap):

```bash
make up
Or, use the script wrapper (enforces metastore upgrade):

```bash
./scripts/compose-up.sh
### Validate and Operate

```bash
make routine-a-ops     # Unified day-2 operations
### Common Operations

| Command | Purpose |
| --- | --- |
### Endpoints

| Service | Endpoint |
| --- | --- |
### Container Behavior

- One-shot init containers (`topic-init`, `minio-init`, `ods-connect-init`) and `dbt` will exit with code 0 after completion.
- Trino may start successfully even if no Iceberg tables exist yet (expected until MinIO sink path is upgraded).
### Troubleshooting FAQ

- **Port already in use?** Run `docker compose down -v` before restarting.
- **Volumes not resetting?** Use `docker compose down -v` to clear all volumes.
---

# Kafka Topic Management (Unified)

All topic management is now handled by a single script:
```sh
./platform-services/kafka/kafka-topics.sh <create|list|consume|check-pipeline> [options]
## Routine A: Unified Stack Startup & Operations

Routine A is the primary workflow for starting, validating, and operating the full GenAI-Enabled Data Platform stack in local development. All procedures are consolidated for simplicity and reliability.

### Brief Introduction

Routine A brings up all core services (Kafka, Schema Registry, Connect, MinIO, Trino, dbt, etc.), creates required topics, and prepares the environment for development and testing. It also provides unified scripts for day-2 operations and troubleshooting.

### Procedures

1. **Start the Full Stack:**
  ```sh
  make routine-a
  # or, to start only the Compose stack (no topic bootstrap):
  make up
  # or, with metastore upgrade enforcement:
  ./scripts/compose-up.sh
  ```

2. **Validate and Operate:**
  ```sh
  make routine-a-ops
  ```

3. **Kafka Topic Management:**
  ```sh
  ./platform-services/kafka/kafka-topics.sh <create|list|consume|check-pipeline> [options]
  # Examples:
  ./platform-services/kafka/kafka-topics.sh create
  ./platform-services/kafka/kafka-topics.sh list
  ./platform-services/kafka/kafka-topics.sh consume sales_order 10
  ./platform-services/kafka/kafka-topics.sh check-pipeline --count 2
  ```

4. **Connector Registration:**
  ```sh
  ./cicd/scripts/consolidated-register-connector.sh --config <config.json> --name <connector-name> [--url <connect-url>] [--k8s <namespace> <deployment>]
  # Example:
  ./cicd/scripts/consolidated-register-connector.sh --config connector-configs/my-connector.json --name my-connector --url http://localhost:8083
  ```

5. **Smoke Test Iceberg/Trino:**
  ```sh
  ./trino/scripts/check-iceberg-streaming-unified.sh
  # Or for Kubernetes:
  ./trino/scripts/check-iceberg-streaming-unified.sh --k8s --namespace <ns> --deployment <deploy>
  ```

### Important Points

- All deprecated scripts will print a warning and exit. Use only the unified scripts above.
- One-shot init containers (`topic-init`, `minio-init`, `ods-connect-init`, `dbt`) will exit with code 0 after completion.
- Trino may start successfully even if no Iceberg tables exist yet (expected until MinIO sink path is upgraded).
- If you see "port already in use" or volumes not resetting, run:
  ```sh
  docker compose down -v
  ```
- For troubleshooting, always check container logs and use the provided scripts for validation.

---
**Executive summary:** Lifecycle-first reference architecture for
GenAI-enabled data engineering on AWS (MSK/Kafka + Debezium + Schema
Registry, Flink, Databricks, Snowflake + dbt, Prometheus/Grafana). GenAI
accelerates delivery and operations by reducing pipeline lead time
(template/code generation), lowering incident volume and MTTR (alert
correlation and PR-based remediation), improving governed self-service
(NL-to-SQL grounded on dbt semantics), and strengthening audit readiness
(policy/evidence drafting with separation of duties).

- **Faster delivery:** generate pipeline/dbt scaffolding, tests, and
  documentation to reduce lead time from request → PR.

- **Higher reliability:** reduce incidents and MTTR via alert
  summarization, signal correlation, and PR-based remediation
  suggestions.

- **Safer self-service analytics:** improve NL-to-SQL accuracy by
  grounding on dbt semantic metrics, with read-only and cost guardrails.

- **Stronger governance:** draft policies, access-review packets, and
  audit narratives with separation of duties and full logging.

- **Cost control:** recommend Snowflake/query optimizations and
  right-sizing actions based on metadata and usage signals.

This guide defines an enterprise-grade, GenAI-enabled data platform
architecture aligned to the following stack: **AWS** as cloud
foundation, **Kafka CDC streaming** as the real-time backbone,
**Starburst (Trino)** for ingestion/federation, **Databricks** for batch
and near real-time processing, **Snowflake** for transformation and
lakehouse-style serving, and **Prometheus/Grafana** (managed on AWS) for
observability. It provides concrete reference implementations (example
configurations, patterns, and runbooks) that teams can adapt to their
environments.

- **Audience:** data engineers, platform engineers, architects,
  analytics engineers, SRE/operations, and security/governance
  stakeholders.

- **Primary outcomes:** faster pipeline delivery, safer self-service
  analytics, lower MTTR, and audit-ready GenAI adoption.

- **Non-goals:** vendor marketing comparison, training foundation models
  from scratch, or fully autonomous production changes without human
  approval.

<a id="architecture-and-navigation"></a>

## <span style="color: #0B7285;">2. Architecture & Navigation</span>

This section summarizes how the platform is composed, how the two
reference pipelines (OAP-1 and PP-1) flow through the stack, and where
governance and GenAI controls apply across environments.

<a id="pipeline-index-internal-links"></a>

### <span style="color: #1D4ED8;">2.1 Pipeline Index (Internal Links)</span>

**OAP-1 — Operational analytics:** Kafka (Debezium CDC) → Apache Flink →
Kafka Connect (ECS) → **Operational Data Store** (e.g., AWS Aurora)\
**LHP-1 — Lakehousing processing:** Kafka (Debezium CDC) → Databricks
(Bronze/Silver on S3) → publish to Snowflake → dbt → CURATED

<a id="target-stack-baseline"></a>

### <span style="color: #1D4ED8;">2.2 Target Stack (Baseline)</span>

| **Layer**                            | **Technology**                                       | **Responsibility**                                                    |
| ------------------------------------ | ---------------------------------------------------- | --------------------------------------------------------------------- |
| Cloud foundation                     | AWS (VPC, IAM, S3, KMS, CloudWatch, Secrets Manager) | Networking, identity, encryption, storage, logging, platform controls |
| CDC streaming backbone               | MSK Kafka + Debezium + Confluent Schema Registry     | Durable CDC/event distribution, replay, schema contracts              |
| Federation / query mesh              | Starburst Enterprise (Trino)                         | Federated SQL access and exploration across sources                   |
| Operational stream processing        | Apache Flink                                         | Low-latency enrichment/aggregation/state materialization              |
| Batch + near real-time processing    | Databricks on AWS                                    | Bronze/Silver processing, CDC merges, backfills                       |
| Transform + semantic model + serving | Snowflake + dbt                                      | Curated marts, semantic layer metrics, governed consumption           |
| Observability                        | Amazon Managed Prometheus + Amazon Managed Grafana   | Metrics, dashboards, alerting, SLOs                                   |

<a id="end-to-end-architecture-data-plane-control-plane-genai-plane"></a>

### <span style="color: #1D4ED8;">2.3 End-to-End Architecture (Data Plane / Control Plane / GenAI Plane)</span>

**Data plane:** sources → CDC/event capture → Kafka topics →
**operational analytics pipeline** (Kafka → **Apache Flink** →
Operational Data Store) **\[See: OAP-1\]** and **lakehousing processing
pipeline** (Kafka → Databricks → Delta Bronze/Silver) **\[See: LHP-1\]**
→ Snowflake transformations/modeling → consumption (BI, apps, ML).\
**Control plane:** identity and policies (IAM/RBAC), schema/contract
governance, lineage/metadata, CI/CD, and observability
(metrics/logs/traces).\
**GenAI plane:** copilots/agents grounded on metadata, runbooks, and
execution history to accelerate engineering while enforcing safety
guardrails (read-only by default; PR-based writes).

- **Kafka is the system of record for change streams** (replayable,
  partitioned, schema-governed).

- **Starburst (Trino) provides federation and rapid SQL access** across
  Kafka and other sources for exploration and integration.

- **Flink powers operational stream processing** for low-latency
  enrichment/aggregations prior to Snowflake serving.

- **Databricks executes lakehousing processing** (Spark batch +
  Structured Streaming) with durable Delta on S3.

- **Snowflake + dbt standardize modeling and semantics** for governed
  consumption and metric consistency.

<a id="lifecycle-operating-model"></a>

## <span style="color: #0B7285;">3. Lifecycle Operating Model (GenAI Across the Data Engineering Lifecycle)</span>

<a id="usage-of-genai-on-lifecycle-model"></a>

### <span style="color: #1D4ED8;">3.1 Usage of GenAI on lifecycle model</span>

**How to use this guide:** start with the lifecycle model to understand
where GenAI applies, then use Sections 4–10 for the stack-specific
reference implementations and operational practices per stage.

<a id="lifecycle-stage-map-genai-at-each-stage"></a>

### <span style="color: #1D4ED8;">3.2 Lifecycle stage map (GenAI at Each Stage)</span>

**GenAI benefits (Plan & Design):** faster requirements-to-architecture
drafts, better contract quality, and clearer backlogs—while keeping
decisions reviewable through PR-based approvals.

| **Lifecycle stage** | **What GenAI does (grounded on)**                                                               | **Guardrails**                           | **Outputs**                 |
| ------------------- | ----------------------------------------------------------------------------------------------- | ---------------------------------------- | --------------------------- |
| Plan & design       | Drafts ADRs, contracts, and backlog items (OAP-1/LHP-1 standards, glossary)                     | Human approval; approved templates       | ADRs, data contracts, plans |
| Ingest (CDC)        | Generates Debezium/Connect configs; schema impact checks (Schema Registry, topic/ACL standards) | No secrets; compatibility gates; PR-only | Connector PRs, runbooks     |
| Process             | Scaffolds Flink/Databricks; tuning hypotheses (job history, lag/backpressure)                   | CI tests; bounded reads; review          | PRs with code + tests       |
| Transform & model   | Generates dbt models/tests/docs; cost-aware SQL (dbt artifacts, Snowflake metadata)             | Lint/policy checks; reviewers            | dbt PRs, semantic updates   |
| Serve & consume     | Governed NL→SQL + metric Q&A (dbt semantic layer, verified queries)                             | Read-only; cost limits; logging          | Validated SQL, insights     |
| Observe & govern    | Summarizes incidents; drafts PR fixes/policies (metrics, runbooks, deploy/PR history)           | Allowlisted tools; approvals; audit logs | Tickets, PRs, updates       |

<a id="ingest-kafka-cdc-contracts-connectors"></a>

## <span style="color: #0B7285;">4. Ingest (Kafka CDC, Contracts, Connectors)</span>

**GenAI benefits (Ingest):**

- Faster onboarding of new CDC sources by generating Debezium/Kafka
  Connect templates that conform to topic, ACL, and Schema Registry
  standards.

- Reduced schema-related incidents via automated compatibility impact
  analysis (producer → consumers) and PR-ready contract updates.

- Lower operational toil through auto-generated runbooks for
  replay/backfill and connector recovery (with human approvals).

**Recommended topic convention** (example):
_\<domain\>.\<system\>.\<object\>.\<event_type\>_\
Examples: _orders.db.customer.cdc_, _inventory.sap.material.cdc_,
_web.clickstream.event_\
**Key rules:** one topic per table/object for CDC; partitions by
business key for scale; use Schema Registry for value schemas; enforce
backward compatibility for evolving schemas.

<a id="debezium-confluent-schema-registry-reference-standard"></a>

### <span style="color: #1D4ED8;">4.1 Debezium + Confluent Schema Registry (Reference Standard)</span>

**Debezium topic convention:** default Debezium topics often follow
_\<serverName\>.\<db\>.\<schema\>.\<table\>_. If you adopt a
domain-based convention, document a deterministic mapping between the
two (and keep it stable) to avoid breaking consumers.\
**Event envelope:** Debezium typically emits an envelope with _before_,
_after_, _op_ (c/u/d/r), and _source_ metadata (including database
position such as LSN/SCN depending on the source). Downstream merges
should use (key + source position + event time) for dedupe where
possible.

- **Subject naming:** pick one strategy (TopicNameStrategy or
  RecordNameStrategy) and standardize it across producers/consumers;
  treat topic name changes as breaking changes.

- **Compatibility mode:** start with BACKWARD or BACKWARD_TRANSITIVE for
  CDC value schemas to support additive evolution.

- **Evolution rules (practical):** additive fields with defaults are
  safe; renames are breaking (add + deprecate); type changes are usually
  breaking; keep key schema stable.

- **Deletes:** decide whether you rely on explicit delete events,
  tombstones, or both; document how downstream interprets op=d vs
  tombstones.

```json
{
  "name": "debezium-postgres-crm",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "tasks.max": "1",
    "database.hostname": "<host>",
    "database.port": "5432",
    "database.user": "<user>",
    "database.password": "<password>",
    "database.dbname": "crm",
    "topic.prefix": "crm",
    "schema.include.list": "public",
    "table.include.list": "public.customer,public.orders",
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "<schema-registry-url>",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "<schema-registry-url>",
    "include.schema.changes": "false"
  }
}
```

```json
{
  "before": { "...": "..." },
  "after": { "...": "..." },
  "op": "c|u|d|r",
  "ts_ms": 1713900000000,
  "source": {
    "db": "crm",
    "schema": "public",
    "table": "customer",
    "lsn": 123456789
  }
}
```

- **Retention:** size replay windows to your backfill SLA (commonly 3–14
  days). For long-term replay, land immutable raw events to S3.

- **Compaction:** use log compaction only for key-based state topics;
  avoid compaction for audit/event topics where historical sequence
  matters.

- **Idempotency:** downstream consumers must support replays (dedupe via
  primary key + event timestamp/LSN).

<a id="process-flink-databricks-starburst"></a>

## <span style="color: #0B7285;">5. Process (Flink, Databricks, Starburst)</span>

**GenAI benefits (Process):**

- Accelerated development for Flink and Databricks jobs through code
  scaffolding, state/TTL recommendations, and test generation aligned to
  your standards.

- Improved performance and stability via automated hypothesis generation
  from lag/backpressure metrics and job history, producing PR-based
  tuning proposals.

- Faster troubleshooting by summarizing failures across components (MSK,
  Flink, Databricks, Starburst) and correlating them with schema and
  deployment changes.

<a id="starburst-trino-federation-exploration"></a>
5.1 Starburst (Trino) (Federation / Exploration)

**Use cases:** interactive exploration of Kafka topics, joining
streaming CDC with warehouse/lake datasets, and lightweight ingestion
acceleration where SQL federation is preferred.

```properties
# etc/catalog/kafka.properties (example)
connector.name=kafka
kafka.nodes=broker1:9092,broker2:9092
kafka.default-schema=cdc

# For Debezium + Confluent Schema Registry (typical):
# - Avro payloads are decoded using Schema Registry subjects
# - Versioned table description files map topic fields to columns
# - Treat schema changes as contract changes; re-validate mappings on each new schema version
```

-- Example (Aurora PostgreSQL): inspect recent CDC-applied rows in the ODS

```sql
SELECT
  customer_id,
  email,
  updated_at
FROM ods_customer
WHERE updated_at >= NOW() - INTERVAL '10 minutes'
ORDER BY updated_at DESC
LIMIT 100;
```

- **Always bound live-topic queries:** use a time window + LIMIT to
  avoid unbounded scans and inconsistent results.

- **Avoid self-joins:** retention/segment drops can cause non-repeatable
  reads.

- **Schema governance matters:** enforce compatibility in Schema
  Registry; keep topic-to-table mapping versioned.

<a id="apache-flink-for-operational-analytics-reference-pattern"></a>
5.2 Apache Flink for Operational Analytics (Reference Pattern)

**Purpose:** Apache Flink provides the low-latency stream processing
layer for OAP-1—enrichment, filtering, aggregations, and entity state
materialization—before data lands in Snowflake for governed serving and
dbt-based modeling.

- **Sources:** consume Debezium CDC topics from MSK; deserialize with
  Schema Registry (Avro) and enforce compatibility gates.

- **State:** use keyed state for rollups and dedupe (key + source
  position/ts); set state TTL to business semantics.

- **Consistency:** prefer exactly-once where supported; otherwise use
  idempotent writes and downstream MERGE semantics.

- **Sinks to Snowflake:** standardize on (a) Flink → Kafka
  “ready-for-snowflake” topics → Connect (ECS), or (b) Flink → S3
  micro-batches → Snowflake RAW (append-only).

- **Operations:** configure checkpoints/savepoints; monitor lag,
  checkpoint duration, backpressure, and restarts in Grafana.

<a id="databricks-lakehousing-processing-bronzesilver"></a>
5.3 Databricks (Lakehousing Processing — Bronze/Silver)

**Principle:** land raw CDC/events as immutable Bronze (append-only),
then build Silver as current-state tables using deterministic merges
(SCD1/SCD2) with strong idempotency. Persist checkpoints to S3 and treat
reprocessing as a first-class workflow.

<a id="kafka-to-bronze-delta-using-structured-streaming"></a>

#### <span style="color: #7C3AED;">5.3.1 Kafka → Bronze (Delta) using Structured Streaming</span>

```python
from pyspark.sql.functions import col, current_timestamp

bootstrap = "broker1:9092,broker2:9092"
topic = "orders.db.customer.cdc"

raw = (
  spark.readStream.format("kafka")
  .option("kafka.bootstrap.servers", bootstrap)
  .option("subscribe", topic)
  .option("startingOffsets", "latest")
  .load()
)

# For Debezium + Confluent Schema Registry, CDC events are commonly Avro.
# Decode Avro using Schema Registry (implementation depends on your Spark library approach).
decoded = decode_confluent_avro(raw.select(col("value")))

# After decoding, select Debezium envelope fields and add ingestion metadata.
cdc = decoded.withColumn("_ingest_ts", current_timestamp())

(
  cdc.writeStream.format("delta")
  .option("checkpointLocation", "s3://<bucket>/checkpoints/bronze/customer_cdc/")
  .outputMode("append")
  .table("bronze.customer_cdc")
)
```

**Implementation note:** standardize one supported Avro decoding
approach in Spark (including Schema Registry auth), and treat decoder
upgrades as a controlled platform change. Log schema IDs/versions per
microbatch to simplify incident triage and replay.

<a id="bronze-to-silver-current-state-using-cdc-merge"></a>

#### <span style="color: #7C3AED;">5.3.2 Bronze → Silver (Current State) using CDC MERGE</span>

```python
from delta.tables import DeltaTable
from pyspark.sql.functions import col

def upsert_to_silver(microbatch_df, batch_id):
  # Keep the latest event per key in this microbatch.
  dedup = (
    microbatch_df.where(col("op").isin("c", "u", "d"))
    .selectExpr("key.customer_id as customer_id", "op", "ts_ms", "after.*")
    .dropDuplicates(["customer_id", "ts_ms"])
  )

  silver = DeltaTable.forName(spark, "silver.customer")
  (
    silver.alias("t")
    .merge(dedup.alias("s"), "t.customer_id = s.customer_id")
    .whenMatchedUpdateAll(condition="s.op in ('c','u')")
    .whenMatchedDelete(condition="s.op = 'd'")
    .whenNotMatchedInsertAll(condition="s.op in ('c','u')")
    .execute()
  )

(
  spark.readStream.table("bronze.customer_cdc")
  .writeStream.foreachBatch(upsert_to_silver)
  .option("checkpointLocation", "s3://<bucket>/checkpoints/silver/customer/")
  .start()
)
```

- **Schema evolution:** enforce additive-only changes in CDC topics;
  route breaking changes to a new topic version and migrate consumers
  explicitly.

- **Exactly-once:** Kafka + Spark are effectively exactly-once at the
  sink with checkpointing and idempotent merge logic; design for replay.

- **Backfills:** implement “reprocess from offset/time” runbooks; keep
  checkpoint paths stable per pipeline and environment.

<a id="transform-model-snowflake-dbt"></a>

## <span style="color: #0B7285;">6. Transform & Model (Snowflake + dbt)</span>

**Section 6 at a glance:** ingest CDC into RAW (6.1), run Connect on ECS
with MSK SASL/SCRAM (6.1.1–6.1.3), merge RAW→CURATED (6.2), then model
and publish semantics in dbt (6.2.1).

**GenAI benefits (Transform & Model):**

- Shorter delivery cycles for curated marts by generating dbt models,
  tests, and documentation with consistent patterns and naming.

- Lower cost and fewer regressions through query refactoring suggestions
  grounded in Snowflake metadata and (redacted) query history.

- Stronger semantic consistency by drafting metric definitions and
  validating them against existing dbt semantic layer contracts.

**Primary patterns:** (1) Kafka → Snowflake for low-latency operational
analytics and serving, and (2) Databricks → Snowflake for curated,
batch/near-real-time loads. **All transformation modeling and the
semantic layer are standardized in dbt on Snowflake** (tests, exposures,
and governed metrics), keeping business logic versioned and reviewable.

<a id="kafka-to-operational-data-store-oap-1-ingestion-via-kafka-connector"></a>

### <span style="color: #1D4ED8;">6.1 Kafka → Operational Data Store (OAP-1 Ingestion via Kafka Connector)</span>

**Operational analytics pipeline (internal link: OAP-1):** this path
prioritizes low-latency delivery of CDC events into an **Operational
Data Store** (e.g., AWS Aurora) for operational serving and near
real-time application access.

```jsonc
{
  "name": "aurora-customer-cdc",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
    "tasks.max": "2",
    "topics": "orders.db.customer.cdc",
    "connection.url": "jdbc:postgresql://<aurora-endpoint>:5432/<db>",
    "connection.user": "<user>",
    "connection.password": "<password>",
    "insert.mode": "upsert",
    "pk.mode": "record_key",
    "pk.fields": "customer_id",
    "table.name.format": "ods_customer",
    "auto.create": "false",
    "auto.evolve": "false",
    // Auth/network omitted on purpose
  },
}
```

<a id="kafka-connect-on-aws-ecs-msk-saslscram"></a>

#### <span style="color: #7C3AED;">6.1.1 Kafka Connect on AWS ECS (MSK SASL/SCRAM)</span>

- **Runtime:** run Kafka Connect as an ECS service using an image that
  includes the Snowflake connector and Confluent Avro converters.

- **Scaling:** scale tasks and connector tasks.max; align CPU/memory to
  topic throughput and Snowflake ingest capacity.

- **Networking:** private subnets; egress to MSK brokers and Schema
  Registry; restrict inbound to the Connect REST API (admin CIDR or
  internal load balancer).

- **Secrets:** store Snowflake and Schema Registry credentials in
  Secrets Manager; inject via ECS task secrets.

- **State:** use Kafka internal topics for Connect config/offset/status;
  set replication/retention appropriately.

- **Auth (MSK standard):** TLS + SASL/SCRAM (SASL_SSL), with JAAS
  assembled at runtime from injected secrets; enforce topic ACLs.

- **Observability:** export JMX metrics to Prometheus and dashboard
  restarts, error rates, and throughput in Grafana.

<a id="msk-connectivity-and-auth-patterns"></a>
6.1.2 MSK Connectivity and Auth Patterns

Use the following patterns to standardize how ECS-based Kafka Connect
reaches MSK securely across environments.

| **Option**                  | **When to use**              | **ECS implementation notes**                                                           |
| --------------------------- | ---------------------------- | -------------------------------------------------------------------------------------- |
| TLS (encryption in transit) | Always (baseline for MSK).   | Provide CA bundle/truststore; validate broker certs; keep JVM TLS settings consistent. |
| SASL/SCRAM                  | Standard for this reference. | Secrets Manager for creds; inject via ECS task secrets; assemble JAAS at runtime.      |
| IAM authentication          | Not used here.               | Requires IAM auth library and consistent IAM policy/ACL model.                         |

```properties
# Kafka Connect worker properties (illustrative; placeholders)
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512

# sasl.jaas.config should be assembled from Secrets Manager values at runtime.
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required 
username="..." 
password="...";
```

<a id="saslscram-setup-summary"></a>

#### <span style="color: #7C3AED;">6.1.3 SASL/SCRAM Setup Summary (MSK + ECS Kafka Connect)</span>

- **MSK listeners:** enable TLS and expose a TLS listener (commonly
  9094). Confirm ECS tasks can resolve broker DNS and reach broker ENIs
  from private subnets.

- **SCRAM credentials:** create a SCRAM user in MSK and store the
  username/password in AWS Secrets Manager (separate secret per
  environment).

- **ECS task injection:** inject SCRAM secret values into the container
  via ECS task secrets; do not hardcode credentials.

- **Worker config:** set security.protocol=SASL_SSL and
  sasl.mechanism=SCRAM-SHA-512; assemble sasl.jaas.config at runtime;
  ensure truststore includes the MSK TLS chain.

- **Kafka ACLs:** grant least-privilege to CDC topics and Connect
  internal topics (config/offset/status), including create/read/write as
  needed.

- **Validation:** verify worker start, create a test connector, and
  monitor lag, task failures, and error logs in Grafana.

**Schema Registry connectivity:** keep Schema Registry reachable from
ECS tasks over private networking where possible. If hosted outside the
VPC, use private connectivity (private endpoints, VPN, or peering) and
avoid public routing. Ensure the container trusts the Registry TLS
certificate chain and rotate certificates on a schedule.

- **Truststore drift:** reaches Schema Registry but fails TLS validation
  after certificate rotation.

- **Subject strategy mismatch:** producer/consumer subject naming
  differs, breaking deserialization.

- **Hidden public path:** registry traffic routes over the public
  internet instead of private connectivity.

<a id="ods-to-curated-cdc-merge-dbt-modeling"></a>
6.2 ODS → CURATED (CDC Merge + dbt Modeling)

Treat the **Operational Data Store** as the current-state operational
serving layer (upserted from CDC). Build **CURATED** analytics tables in
Snowflake using deterministic transformations in dbt, and publish
governed metrics from the dbt semantic layer.

-- Example (Aurora PostgreSQL): upsert CDC into an ODS table

```sql
INSERT INTO ods_customer (customer_id, email, name, updated_at)
VALUES (:customer_id, :email, :name, NOW())
ON CONFLICT (customer_id)
DO UPDATE
SET
  email = EXCLUDED.email,
  name = EXCLUDED.name,
  updated_at = NOW();
```

<a id="dbt-on-snowflake-modeling-semantic-layer"></a>

#### <span style="color: #7C3AED;">6.2.1 dbt on Snowflake: Modeling + Semantic Layer</span>

**Recommended dbt structure** (example): _models/staging_ (RAW
normalization), _models/intermediate_ (business joins), _models/marts_
(domain data products), plus _tests_, _macros_, and _exposures_ for
downstream contracts. Enforce PR-based review for all model changes and
require dbt tests to pass before deployment.

Example semantic definitions (illustrative) to anchor NL-to-SQL and
metric consistency:

```yaml
# Example (illustrative): schema.yml-style metrics/semantic definitions
models:
  - name: fct_orders
    description: "Order fact table for analytics."
    columns:
      - name: order_id
        tests: [unique, not_null]
      - name: order_total
        tests: [not_null]

metrics:
  - name: gross_revenue
    label: Gross Revenue
    model: ref('fct_orders')
    description: Sum of order_total for completed orders
    calculation_method: sum
    expression: order_total
    timestamp: order_completed_ts
    filters:
      - field: order_status
        operator: "="
        value: "COMPLETED"
```

<a id="lakehouse-strategy-on-aws-s3-open-table-formats"></a>

### <span style="color: #1D4ED8;">6.3 Lakehouse Strategy on AWS (S3 + Open Table Formats)</span>

- **Default:** keep Databricks Bronze/Silver in Delta on S3; publish
  Gold/serving datasets to Snowflake for consumption and workload
  isolation.

- **Use Iceberg on Snowflake:** when you need open-table
  interoperability and Snowflake governance over S3-backed tables.

- **Keep one writer per table:** avoid concurrent write conflicts across
  engines; treat interoperability as an explicit product decision.

- **Governance:** centralize classification, masking, and access control
  in Snowflake for serving layers; keep raw S3 zones locked down.

<a id="serve-consume-semantic-layer-governed-analytics"></a>

## <span style="color: #0B7285;">7. Serve & Consume (Semantic Layer, Governed Analytics)</span>

**GenAI benefits (Serve & Consume):**

- Higher self-service success rate by translating questions into SQL
  grounded on dbt semantic metrics and approved definitions.

- Reduced analyst/engineer interruption via instant metric explanations
  (lineage-aware “what changed and why”) with citations to governed
  artifacts.

- Safer access by enforcing read-only queries, cost limits, and policy
  checks while still delivering fast answers.

Standardize consumption on **dbt semantic metrics** and curated marts to
enable reliable self-service. GenAI is applied here as a **governed
NL→SQL assistant** grounded on approved metric definitions, glossary
terms, and verified query patterns, with read-only enforcement and cost
controls.

<a id="observe-operate-prometheusgrafana-runbooks"></a>

## <span style="color: #0B7285;">8. Observe & Operate (Prometheus/Grafana, Runbooks)</span>

**GenAI benefits (Observe & Operate):**

- Reduced MTTD/MTTR by summarizing alerts, proposing likely root causes,
  and correlating signals across Kafka/Flink/Databricks/Snowflake.

- Fewer repeat incidents by auto-drafting postmortems and updating
  runbooks based on incident timelines and remediation outcomes.

- Lower on-call load by filtering noise, grouping related alerts, and
  guiding responders through validated checklists.

**Baseline:** standardize metric ingestion into **Amazon Managed Service
for Prometheus** and visualize in **Amazon Managed Grafana**. Pipeline
health becomes a product SLO with alerting tied to on-call runbooks.

<a id="key-observability-signals-by-component"></a>

### <span style="color: #1D4ED8;">8.1 Key Observability Signals (by Component)</span>

| **Component**        | **Key signals**                                                                   | **Why it matters**                                |
| -------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------- |
| Kafka / CDC          | consumer lag, under-replicated partitions, broker disk, rates, connector failures | Durability risk; drives freshness SLAs            |
| Starburst            | query latency, queue time, worker saturation, spills, connector errors            | Prevents cascading incidents                      |
| Databricks pipelines | batch duration, input rate, state growth, failures, utilization, checkpoint age   | Freshness and cost control                        |
| Snowflake            | credit burn, queueing, query failures, ingestion errors, lag                      | Serving reliability and cost regression detection |

```promql
# Example PromQL (names will vary by exporters)

# Alert: consumer lag too high for 10 minutes
max_over_time(kafka_consumergroup_lag{consumergroup="dbx-customer-cdc"}[10m]) > 50000

# Alert: Kafka Connect task failures
increase(kafka_connect_connector_task_failed_total[5m]) > 0
```

<a id="operational-runbooks-minimum-set"></a>

### <span style="color: #1D4ED8;">8.2 Operational Runbooks (Minimum Set)</span>

| **Symptom**                                       | **Likely causes**                                                                                           | **First actions**                                                                                                                                             | **Escalate when**                                                              |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Kafka consumer lag growing                        | Downstream backpressure, schema drift, compute saturation, connector failures                               | Check broker health; verify consumer group; inspect recent deploys; scale consumers; confirm schema compatibility                                             | Lag breaches SLA for \> N minutes or data loss indicators appear               |
| Databricks stream failing repeatedly              | Bad record, schema change, checkpoint issue, S3 permissions, out-of-memory                                  | Inspect exception; validate schema; confirm checkpoint path/IAM; quarantine bad records                                                                       | Checkpoint corruption suspected or widespread impact                           |
| ODS ingestion errors from Kafka (Aurora)          | Connector JDBC auth/privileges, target table mismatch, connectivity/VPC routing, bad records, schema change | Check connector task logs; validate Aurora connectivity and security groups; validate DB user grants; confirm table schema; quarantine/handle invalid records | Operational SLA breach imminent or CDC lag/backlog approaches retention window |
| Schema compatibility violation / connector paused | Incompatible schema, subject mismatch, consumer expects old schema, registry auth issue                     | Review compatibility error; rollback or publish compatible schema; validate then resume                                                                       | Multiple domains impacted or backlog near retention                            |

<a id="govern-secure-security-governance-cicd"></a>

## <span style="color: #0B7285;">9. Govern & Secure (Security, Governance, CI/CD)</span>

**GenAI benefits (Govern & Secure):**

- Faster, more consistent governance by drafting policy-as-code, access
  review packets, and masking recommendations from existing standards
  and metadata.

- Improved audit readiness through automated evidence narratives (what
  changed, who approved, what tests ran) without exposing sensitive
  data.

- Reduced risk by enforcing separation of duties and keeping GenAI
  actions constrained to PRs/tickets with full logging.

<!-- -->

- **AWS baseline:** private networking where possible (VPC endpoints),
  encryption with KMS, least-privilege IAM roles per workload,
  centralized audit logging.

- **Kafka security (MSK):** enforce TLS in transit and standardize on
  SASL/SCRAM. For ECS-based Kafka Connect, keep SCRAM credentials in
  Secrets Manager (with rotation), inject them securely, and restrict
  access with topic ACLs and tightly scoped security groups.

- **Databricks:** workspace isolation by environment, service principals
  for automation, cluster policies, and Unity Catalog for table-level
  permissions and lineage.

- **Snowflake:** role-based access control, masking policies for
  sensitive columns, network policies, and query/audit logging.

- **CI/CD:** PR-based promotion DEV→QA→STG→PRD; automated tests (data
  tests + query linting); deployment via infrastructure-as-code and
  platform-native bundle tooling.

<a id="adoption-roadmap-and-kpis"></a>

## <span style="color: #0B7285;">10. Adoption Roadmap and KPIs</span>

| **KPI**                    | **Definition**                                        | **Target direction** |
| -------------------------- | ----------------------------------------------------- | -------------------- |
| Freshness SLA              | P95 delay from CDC event time to curated availability | Down                 |
| MTTD / MTTR                | Detect + resolve time for pipeline incidents          | Down                 |
| Pipeline lead time         | Request → merged PR → deployed change                 | Down                 |
| Cost per delivered dataset | Compute + storage + tokens per accepted delivery unit | Down                 |

**Next steps checklist**

- Confirm topic naming and schema compatibility policy and publish as an
  engineering standard.

- Stand up the reference pipelines: **LHP-1 (lakehousing processing)**
  Kafka→Databricks Bronze/Silver and **OAP-1** Kafka→Flink→Kafka Connect
  (ECS)→**Operational Data Store** (e.g., Aurora).

- Stand up Flink job templates for OAP-1 (CDC consume → enrich/aggregate
  → ODS write path) with checkpoints, alerting, and rollback via
  savepoints.

- Roll out dbt in Snowflake with standardized project structure, tests
  in CI, and a governed semantic layer for metrics.

- Implement AMP/AMG dashboards and alerts for lag, failures, cost, and
  freshness.

- Define the GenAI evaluation harness and start with PR-only copilots
  for docs/code before enabling agents.

<a id="conclusion-key-genai-benefits"></a>

## <span style="color: #0B7285;">Conclusion: Key GenAI Benefits</span>

In summary, this reference architecture shows how to apply GenAI safely
across the end-to-end data engineering lifecycle by grounding outputs in
governed artifacts and constraining changes to reviewed workflows
(PRs/tickets). Use the Index to navigate to the stage you are
implementing (Ingest → Process → Transform/Model → Serve → Operate →
Govern) and start with the recommended Next steps checklist to roll out
the patterns incrementally.

<a id="appendix-a-genai-enablement-details"></a>

## <span style="color: #0B7285;">Appendix A. GenAI Enablement Details (Copilots, Agents, Grounding)</span>

**Recommended approach:** implement GenAI as metadata-grounded copilots
and constrained agents. Host the runtime on AWS (private networking) and
interact through allowlisted, audited APIs (read-only by default).

<a id="appendix-a1-build-design-to-code"></a>

### <span style="color: #1D4ED8;">Appendix A.1 Build (Design-to-Code)</span>

- Generate Debezium/Kafka Connect/Flink/Databricks/dbt boilerplate
  aligned to enterprise standards (naming, Schema Registry, MSK
  SASL/SCRAM, CI checks).

- Draft dbt tests, documentation, and semantic metrics from existing SQL
  and examples; propose cost-aware rewrites.

- Produce PRs with diffs, rationale, and rollout steps (no direct
  production writes).

<a id="appendix-a2-run-agentic-operations"></a>

### <span style="color: #1D4ED8;">Appendix A.2 Run (Agentic Operations)</span>

- Summarize alerts/incidents (Kafka lag, Flink backpressure, Connect
  failures, Snowflake ingestion errors) and correlate with deploy
  history and schema changes.

- Propose remediations as tickets and PRs (scaling, checkpoint tuning,
  schema handling) with explicit validation steps.

- Draft postmortems and update runbooks; track MTTD/MTTR improvements
  using Prometheus/Grafana signals.

<a id="appendix-a3-consume-governed-self-service"></a>

### <span style="color: #1D4ED8;">Appendix A.3 Consume (Governed Self-Service)</span>

- Use the dbt semantic layer as the single meaning layer for NL→SQL and
  metric Q&A to reduce ambiguity.

- Enforce read-only queries, cost limits, and validation against
  approved metrics; log prompts/contexts for audit.

<a id="appendix-a4-govern-metadata-policies-audit"></a>

### <span style="color: #1D4ED8;">Appendix A.4 Govern (Metadata, Policies, Audit)</span>

- Generate and update data contracts, ownership, and operational
  runbooks from code and execution history, routed through approvals.

- Assist with access reviews and policy-as-code drafts; enforce
  separation of duties for any privilege changes.

<a id="appendix-a5-grounding-sources-what-to-index"></a>

### <span style="color: #1D4ED8;">Appendix A.5 Grounding Sources (What to Index) — Split View</span>

### <span style="color: #1D4ED8;">Appendix A.5a Engineering context (Design, Build, Model)</span>

| **Context source** | **Index**                  | **Used for**                       |
| ------------------ | -------------------------- | ---------------------------------- |
| dbt artifacts      | manifest, tests, metrics   | Metric grounding, impact analysis  |
| Snowflake metadata | DDL, grants, cost          | Review support, optimization hints |
| Kafka schemas      | subjects, versions, compat | Schema impact analysis             |
| Git/CI             | PRs, tests, releases       | Change correlation, audit          |

### <span style="color: #1D4ED8;">Appendix A.5b Operations context (Run, Observe, Troubleshoot)</span>

| **Context source** | **Index**                   | **Used for**                |
| ------------------ | --------------------------- | --------------------------- |
| Grafana + alerts   | alerts, SLOs, runbooks      | Incident summaries, triage  |
| Prometheus metrics | lag, errors, saturation     | RCA hypotheses, SLOs        |
| Flink runtime      | checkpoints, backpressure   | Safe tuning, upgrades       |
| Databricks runs    | failures, logs, checkpoints | Auto-triage, PR suggestions |
| Kafka Connect      | task restarts, errors       | Ingestion incident response |

<a id="appendix-a6-example-agent-playbook"></a>

### <span style="color: #1D4ED8;">Appendix A.6 Example Agent Playbook: Kafka Lag → Root Cause → PR Fix</span>

1.  **Trigger:** Grafana alert fires (consumer lag exceeds threshold).

2.  **Retrieve context:** topic configuration, recent schema changes,
    relevant consumer jobs, and recent deployments.

3.  **Diagnose:** classify cause (schema drift, downstream backpressure,
    bad batch, infra saturation).

4.  **Propose fix as code:** tune streaming trigger/max offsets, add
    schema handling, or scale compute; generate PR with tests.

5.  **Validate:** run checks and dry runs; enforce policy (no secrets,
    no destructive SQL).

6.  **Human approval:** reviewer approves PR; deployment proceeds via
    CI/CD; agent posts recap and updates runbook.

7.  **Tool allowlists:** read-only access to Snowflake/Databricks/Kafka
    metadata; write actions only through PRs and ticketing.

8.  **Prompt injection defense:** treat logs/docs as untrusted; separate
    instructions from retrieved context; test with adversarial prompts.

9.  **Evaluation suite:** regression tests for incident summaries,
    remediation suggestions, and cost/latency/safety behavior.

- [Routine K8S: Isolated kind + Helm](#routine-k8s-isolated-kind--helm)

## Routine K8S: Isolated kind + Helm

This routine provides a pure Kubernetes + Helm workflow for local development, without building/loading images or using Argo CD. Use this for rapid Helm chart iteration, validation, and smoke testing.

- Bootstrap cluster, Helm chart, and validate:
  ```bash
  make routine-k8s
  ```
- Run day-2 validation and smoke checks:
  ```bash
  make routine-k8s-ops
  ```
- Remove Helm release and delete namespace:
  ```bash
  make routine-k8s-down
  ```

**What it does:**
- Creates kind cluster and installs Argo CD (no app applied)
- Installs Helm chart dependencies, lints, renders, and deploys dev chart
- Runs Helm health snapshot, MDM topic validation, Airflow/dbt check, Trino/Iceberg smoke
- Does NOT build or load images, or apply Argo CD app

**Validation targets included:**
- `make helm-health-dev` – Helm workload health snapshot
- `make mdm-topics-check-dev` – Validate MDM topic flow in k8s
- `make airflow-dbt-check-dev` – Validate Airflow + dbt job state in k8s
- `make trino-smoke-dev` – Trino pod health in k8s
- `make iceberg-streaming-smoke-dev` – Iceberg streaming validation in k8s

**Port-forwarding for UI access:**
- Airflow: `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-airflow 8084:8080`
- MinIO: `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-minio 9001:9001`
- Trino: `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-trino 8086:8080`
- Grafana: `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-grafana 3001:3000`

**Reset/cleanup:**
- Remove Helm release and namespace:
  ```bash
  make routine-k8s-down
  ```

**Troubleshooting:**
- If pods show `ErrImageNeverPull`, images must be built/loaded (see Routine B)
- If `iceberg-writer` is in `CrashLoopBackOff`, run `make helm-metastore-migrate-dev`
- For chart changes, rerun `make routine-k8s` to re-apply

---
