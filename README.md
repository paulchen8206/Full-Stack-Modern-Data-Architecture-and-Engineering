# Full Stack Modern Data Architecture and Engineering

This repository demonstrates a modern data platform that combines realtime processing, lakehouse storage, ELT modeling, and GitOps delivery.

It supports two local operating modes:

- Docker Compose for fast development loops.
- kind plus Helm plus Argo CD for Kubernetes and GitOps workflow simulation.

## Purpose

This section defines the purpose of this document.
Provide a single project entrypoint for architecture, operations, and migration guidance.

## Commands

This section defines the primary commands for this document.
Use the Quick Start command blocks in this file for Routine A (Compose) and Routine B (kind plus Helm plus Argo CD).

## Validation

This section defines the primary validation approach for this document.
Use the Data Validation and Validation Snapshot sections in this file to confirm expected runtime behavior.

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
Use the troubleshooting guidance in this file first, then use the runbook for routine-specific operational diagnostics.

## References

This section defines the primary cross-references for this document.

- [docs/architecture.md](docs/architecture.md)
- [docs/runbook.md](docs/runbook.md)
- [docs/adr/README.md](docs/adr/README.md)

## What This Project Demonstrates

- Kafka as a realtime event backbone.
- Flink stream processing embedded in a Java Spring Boot service.
- CDC-driven MDM integration with MySQL + Debezium.
- MinIO-backed lakehouse object storage, with Trino added as the query engine path for Iceberg-compatible tables.
- Warehouse-style analytics on Postgres for local development, with portable patterns for Redshift, Snowflake, BigQuery, and Databricks.
- dbt ELT with medallion layers (landing -> bronze -> silver -> gold).
- Airflow orchestration for scheduled model refresh.
- Docker/Kubernetes runtime and Helm/Argo CD automation.

## Lakehouse/Warehouse Target Options

This repository runs locally on Postgres + MinIO by default, but the same architecture pattern can be implemented on:

- Amazon Redshift
- Snowflake
- Google BigQuery
- Databricks

MinIO migration note:

- MinIO is used as a local S3-compatible object store.
- Cloud counterparts are Amazon S3 (AWS), Google Cloud Storage (GCP), and Azure Data Lake Storage Gen2 (Azure).

Portability guidance:

- Keep Kafka topic contracts and medallion model intent unchanged.
- Use environment-specific dbt profiles and adapter packages per target platform.
- Replace sink connectors and storage integrations to match the selected warehouse/lakehouse stack.
- Preserve dimensional model semantics (conformed dimensions and facts) across platforms.

Current implementation note:

- The current MinIO connector path writes raw JSON objects through the Kafka Connect S3 sink.
- Trino is now added as the query engine foundation, and this repository now includes a Trino-managed bootstrap path that materializes real Iceberg tables on MinIO from the Postgres `landing` layer.
- A direct Kafka-to-Iceberg writer service is also included and writes realtime topics into Iceberg tables through Trino.

### Concrete Migration Matrix (Quick Reference)

| Target | Connector change | dbt adapter | Key config changes |
| --- | --- | --- | --- |
| Redshift | Use Redshift sink pattern (direct connector or S3 staging + COPY) | `dbt-redshift` | Redshift endpoint/db/schema plus IAM/COPY settings |
| Snowflake | Use Snowflake Kafka Connector | `dbt-snowflake` | Account/role/warehouse/database/schema and auth method |
| BigQuery | Use BigQuery Sink connector | `dbt-bigquery` | Project/dataset/location and service account auth |
| Databricks | Use Delta sink pattern for Databricks tables | `dbt-databricks` | SQL warehouse host/http_path/token and catalog/schema |

Object storage counterpart by cloud:

- AWS: Amazon S3
- GCP: Google Cloud Storage
- Azure: Azure Data Lake Storage Gen2

For full migration detail and workflow, see [docs/architecture.md](docs/architecture.md).

### Fast Links to New Migration Sections

- Sample .env onboarding blocks per platform: [docs/architecture.md - 3.3 Sample Environment Variable Blocks (.env Style)](docs/architecture.md#33-sample-environment-variable-blocks-env-style)
- Cloud Kubernetes migration candidates (AWS/GCP/Azure): [docs/architecture.md - 8.3 Cloud Kubernetes Migration Candidates](docs/architecture.md#83-cloud-kubernetes-migration-candidates)

## End-to-End Flow (High Level)

1. Python producer publishes composite sales events to raw_sales_orders.
2. Java/Flink processor consumes and fans out into sales_order, sales_order_line_item, and customer_sales topics.
3. Kafka Connect sinks these topics to raw JSON objects on MinIO and Postgres landing tables.
4. MDM writer updates MySQL customer and product master records.
5. Debezium captures MDM CDC; CDC publisher emits curated mdm_customer and mdm_product topics.
6. PySpark sync moves MDM tables into Postgres landing.
7. dbt builds bronze, silver, and gold analytics models.
8. Trino can bootstrap and query real Iceberg tables on MinIO from the Postgres `landing` layer.
9. `iceberg-writer` can write Kafka topics directly into Iceberg tables through Trino without using the Postgres bridge.
10. Airflow schedules recurring dbt runs.

## Documentation Map

- Architecture reference: [docs/architecture.md](docs/architecture.md)
- Operations runbook: [docs/runbook.md](docs/runbook.md)
- Architecture Decision Records (ADR): [docs/adr/README.md](docs/adr/README.md)

## Repository Layout

- `producer`: Python Kafka producer for composite sales orders.
- `mdm-writer`: Python app that inserts and updates MySQL MDM master data.
- `mdm-cdc-producer`: Python app that consumes Debezium CDC topics and publishes `mdm_customer` and `mdm_product`.
- `mdm-pyspark-sync`: PySpark app that continuously syncs MySQL MDM tables into Postgres landing tables.
- `processor`: Spring Boot application that launches the Flink topology.
- `charts/realtime-app`: Helm chart for producer, processor, Kafka UI, MinIO, Postgres, Kafka Connect, dbt bootstrap, Airflow, and optional Kafka.
- `trino`: Trino query engine configuration for MinIO-backed Iceberg-compatible lakehouse access.
- `iceberg-writer`: Python service that consumes Kafka topics and writes directly to Iceberg tables through Trino.
- `environments`: Helm values for `dev`, `qa`, and `prd`.
- `argocd`: Argo CD Application manifests.
- `connect`: Kafka Connect image and connector configurations (object-storage + JDBC sinks).
- `analytics/dbt`: dbt project for bronze, silver, and gold models in Postgres.
- `analytics/sql`: Database bootstrap SQL (landing plus MDM landing tables in Postgres).
- `mdm/sql`: MySQL bootstrap SQL for MDM `customer360` and `product_master` tables.
- `airflow`: Apache Airflow image and DAGs for scheduled dbt orchestration.
- `scripts`: Local bootstrap and image build helpers.
- `docs/runbook.md`: Day-2 operations procedures for Compose and Argo CD workflows.
- `docs/architecture.md`: Architecture diagrams and modern data engineering framework/patterns.

## Quick Start

### Option A: Docker Compose

Use one of these local startup paths depending on what you need.

Start the full Routine A bootstrap (bring up stack and create topics):

```bash
make routine-a
```

Start only the Compose stack (without topic bootstrap):

```bash
make up
```

Start the full stack directly with the script wrapper (equivalent service scope to `make up`):

```bash
./scripts/compose-up.sh
```

Start only the core streaming path for a faster inner loop:

```bash
./scripts/compose-up.sh -d --build kafka topic-init kafka-ui producer processor
```

Validate topic flow:

```bash
./scripts/list-topics.sh
./scripts/consume-topic.sh raw_sales_orders 3
./scripts/check-pipeline-topics.sh
```

Start lakehouse and warehouse layer:

```bash
make lakehouse-up
```

If you bypass `make`, use `./scripts/compose-up.sh ...` instead of raw `docker compose up ...` so the Postgres-backed Iceberg JDBC metastore upgrade is enforced automatically before Trino and `iceberg-writer` continue.

Run dbt manually:

```bash
make dbt-run
```

Start Airflow:

```bash
make airflow-up
```

Run unified day-2 operations:

```bash
make routine-a-ops
```

Show all available targets and run a local validation bundle:

```bash
make help
make validate
```

Operational helpers:

- `make kafka-ui-up`
- `make dbt-stop`
- `make mdm-up`
- `make mdm-topics-check`
- `make airflow-dbt-reboot`
- `make ops-status`

Key local endpoints:

- Kafka is exposed on `localhost:9094`
- Kafka UI is exposed on `http://localhost:8080`
- MinIO API: `http://localhost:9000`
- MinIO Console: `http://localhost:9001`
- Kafka Connect REST: `http://localhost:8083`
- Trino coordinator: `http://localhost:8086`
- Debezium Connect REST (MDM): `http://localhost:8085`
- Airflow UI: `http://localhost:8084`
- Postgres: `localhost:5432` (user/password/db: `analytics`)
- MySQL MDM: `localhost:3306` (root password: `mdmroot`, db: `mdm`)

Quick Trino health check:

```bash
make trino-smoke
```

Bootstrap real Iceberg demo tables on MinIO:

```bash
make trino-seed-demo
make trino-bootstrap-lakehouse
make trino-rebuild-lakehouse
make trino-sync-lakehouse
make trino-sample-queries
make iceberg-streaming-smoke
```

Local Airflow credentials:

- Username: `admin`
- Password: `admin`

Expected container behavior:

- `topic-init`, `minio-init`, and `connect-init` are one-shot init containers and normally end in `Exited (0)`.
- `dbt` is also a one-shot service and normally ends in `Exited (0)` after `dbt run` completes.
- A finished `dbt` container does not mean bronze, silver, or gold data is missing.
- Trino may start successfully even when no Iceberg tables exist yet; that is expected until the MinIO sink path is upgraded to true Iceberg metadata management.

### Option B: kind + Helm + Argo CD

Use this flow to run the dev environment on kind while building images locally with Docker.

Bootstrap local cluster (Docker-like one command):

```bash
make routine-b
```

Bootstrap local cluster via Argo CD app:

```bash
make routine-b-argocd
```

Stop local cluster workloads:

```bash
make routine-b-down
```

Run unified day-2 operations (Docker-path parity):

```bash
make routine-b-ops
```

Recommended command order (matches the runbook):

1. Create kind cluster and install Argo CD:

   ```bash
   ./scripts/bootstrap-kind.sh
   ```

2. Build and load local images into kind:

   ```bash
   ./scripts/build-images.sh
   ```

3. Apply Argo CD application:

   ```bash
   kubectl apply -f argocd/dev.yaml
   ```

   If the Argo CD UI does not show `realtime-dev`, re-apply and validate:

   ```bash
   kubectl apply -f argocd/dev.yaml
   kubectl -n argocd get application realtime-dev
   ```

4. Validate app and workloads:

   ```bash
   kubectl -n argocd get pods
   kubectl -n argocd get applications
   kubectl -n realtime-dev get pods
   ```

   If Argo CD shows `SYNC STATUS: Unknown` with a `ComparisonError` about repository access,
   register Git credentials in Argo CD for the configured source repo in `argocd/dev.yaml`.
   You can still validate local chart changes immediately with direct Helm commands:

   ```bash
   make helm-reboot-dev
   make helm-health-dev
   ```

5. Run unified day-2 operations:

   ```bash
   make routine-b-ops
   ```

6. Validate processor pipeline logs:

   ```bash
   kubectl -n realtime-dev get pods
   kubectl -n realtime-dev logs deploy/realtime-dev-realtime-app-processor --tail=100
   ```

7. Validate dbt and Airflow logs:

   ```bash
   kubectl -n realtime-dev get pods
   kubectl -n realtime-dev logs job/realtime-dev-realtime-app-dbt --tail=100
   kubectl -n realtime-dev logs deploy/realtime-dev-realtime-app-airflow --tail=100
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-airflow 8084:8080
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-minio 9001:9001
   ```

8. Port-forward local access (same UI order as runbook):

   ```bash
   kubectl -n argocd port-forward svc/argocd-server 8443:443
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-kafka-ui 8082:8080
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-grafana 3001:3000
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-airflow 8084:8080
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-minio 9001:9001
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-trino 8086:8080
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-postgres 5433:5432
   ```

   - Argo CD URL: `https://localhost:8443`
   - Argo CD username: `admin`
   - Argo CD password command:

   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode; echo
   ```

   - Kafka UI URL: `http://localhost:8082`
   - Grafana URL: `http://localhost:3001`
   - Airflow URL: `http://localhost:8084` (user/password: `admin` / `admin`)
   - MinIO Console URL: `http://localhost:9001` (user: `minio`, password: `minio123`)
   - Trino coordinator URL: `http://localhost:8086`
   - Postgres: host `127.0.0.1`, port `5433`, user `analytics`, password `analytics`, db `analytics`

Dev environment behavior:

- Uses in-cluster Kafka from the Helm dependency (`kafka.enabled=true` in `environments/dev/values.yaml`).
- Uses locally built producer, processor, Kafka Connect, dbt, and Airflow images already loaded into kind (`imagePullPolicy: Never`).
- Deploys MinIO, Trino, Postgres, Kafka Connect, a one-shot dbt bootstrap Job, and Airflow in the same Helm release.
- Argo CD tracks `https://github.com/paulchen8206/Kafka-Flink-with-Helm-and-Argo-CD.git` on branch `main` and syncs `charts/realtime-app` with `environments/dev/values.yaml`.

## Environment Strategy

- `dev`: Local kind deployment with in-cluster Kafka from the Helm dependency.
- `qa`: GitOps deployment against a shared Kafka bootstrap service and registry-hosted images.
- `prd`: Same logical topology as `qa` with higher replica counts and faster Flink checkpoints.

## Configuration

### Producer

- `KAFKA_BOOTSTRAP_SERVERS`: Kafka bootstrap servers.
- `RAW_TOPIC`: Source topic name. Default is `raw_sales_orders`.
- `PRODUCER_INTERVAL_MS`: Publish interval in milliseconds.

### Processor

- `KAFKA_BOOTSTRAP_SERVERS`: Kafka bootstrap servers.
- `APP_RAW_SALES_ORDERS_TOPIC`: Source topic.
- `APP_SALES_ORDER_TOPIC`: Sink topic for order headers.
- `APP_SALES_ORDER_LINE_ITEM_TOPIC`: Sink topic for order line items.
- `APP_CUSTOMER_SALES_TOPIC`: Sink topic for per-customer aggregates.
- `APP_CONSUMER_GROUP_ID`: Kafka consumer group.
- `APP_CHECKPOINT_INTERVAL_MS`: Flink checkpoint interval.

### Kafka Connect and Lakehouse Layer

- `connect` service runs S3 sink connectors for `sales_order`, `sales_order_line_item`, and `customer_sales` into MinIO object storage.
- `connect` service also runs a JDBC sink connector for the same topics into Postgres `landing` schema.
- Connector registration happens automatically in `connect-init` in Compose and via a Kubernetes Job in the Helm release.

### Trino Query Engine

- `trino` exposes a SQL query engine endpoint for MinIO-backed Iceberg-compatible data.
- Local Compose endpoint: `http://localhost:8086`
- Kubernetes endpoint: port-forward `svc/realtime-dev-realtime-app-trino 8086:8080`
- The repository includes a repeatable SQL runner: `python3 scripts/trino_query.py --server http://localhost:8086 --file <sql-file>`
- The repository also includes a shell helper for ad hoc SQL without calling Python directly: `./scripts/trino-sql.sh "SHOW TABLES FROM lakehouse.streaming"`
- `make trino-shell` opens the Trino CLI inside the Compose service, or runs a SQL file when `SQL_FILE=<path>` is provided
- Real Iceberg tables can be materialized immediately from Postgres landing data with `make trino-bootstrap-lakehouse`
- All demo Iceberg tables can be dropped and recreated with `make trino-rebuild-lakehouse`
- Incremental refresh from Postgres landing is available with `make trino-sync-lakehouse`
- Demo seed tables can be created with `make trino-seed-demo`
- End-to-end verification for the direct writer path is available with `make iceberg-streaming-smoke`
- Kubernetes-side verification through a temporary Trino port-forward is available with `make iceberg-streaming-smoke-dev`
- The Kafka Connect MinIO path still writes raw JSON files, but a direct Kafka-to-Iceberg path is also available through `iceberg-writer`.

Example Trino workflow:

```sql
SHOW CATALOGS;
SHOW SCHEMAS FROM lakehouse;
SHOW TABLES FROM lakehouse.demo;
```

Example current Trino-managed Iceberg workflow:

```sql
CREATE SCHEMA IF NOT EXISTS lakehouse.demo
WITH (location = 's3://warehouse/iceberg/demo');

CREATE TABLE IF NOT EXISTS lakehouse.demo.sample_orders (
   order_id VARCHAR,
   customer_id VARCHAR,
   order_total DOUBLE,
   order_ts TIMESTAMP
)
WITH (
   format = 'PARQUET',
   location = 's3://warehouse/iceberg/demo/sample_orders'
);

SELECT * FROM lakehouse.demo.sample_orders LIMIT 10;
```

### Direct Kafka-to-Iceberg Writer

- `iceberg-writer` consumes `sales_order`, `sales_order_line_item`, and `customer_sales` directly from Kafka.
- It batches records topic by topic before issuing Trino `MERGE` statements.
- It also uses a timed flush so low-volume topics are written even before a batch fills.
- It creates and maintains Iceberg tables in `lakehouse.streaming` through Trino.
- This removes the Postgres bridge for the realtime lakehouse path, while keeping Postgres available for dbt and warehouse modeling.

### MDM CDC Layer

- `mysql-mdm` stores MDM entities:
  - `mdm.customer360` aligned to customer dimension semantics.
  - `mdm.product_master` aligned to product dimension semantics.
- `mdm-writer` continuously inserts and updates those master records.
- `mdm-connect` runs Debezium MySQL source connector (`debezium-mysql-mdm`).
- Debezium raw CDC topics:
  - `mdm_mysql.mdm.customer360`
  - `mdm_mysql.mdm.product_master`
- `mdm-cdc-producer` consumes raw CDC and republishes curated MDM topics:
  - `mdm_customer`
  - `mdm_product`
- `mdm-pyspark-sync` periodically reads MySQL MDM source tables and writes them into Postgres `landing.mdm_customer360`, `landing.mdm_product_master`, and `landing.mdm_date`.

### dbt and Warehouse Layer

- dbt project location: `analytics/dbt`
- The dbt model structure is portable to Redshift, Snowflake, BigQuery, and Databricks by switching adapter/profile configuration.
- Source schema: `landing`
- Bronze schema: `bronze` (views)
- Silver schema: `silver` (tables)
- Gold schema: `gold` (tables)
- `analytics/dbt/macros/generate_schema_name.sql` disables dbt's default `target_schema + custom_schema` concatenation, so models materialize directly in `bronze`, `silver`, and `gold`.
- In the Helm path, the same macro must be mounted into the dbt runtime (`/dbt/macros/generate_schema_name.sql`) from the warehouse ConfigMap; otherwise dbt may recreate `public_bronze`, `public_silver`, and `public_gold`.
- Main gold model: `gold_customer_sales_summary`

### Airflow Scheduling Layer

- Airflow DAG location: `airflow/dags/dbt_warehouse_schedule.py`
- DAG ID: `dbt_warehouse_schedule`
- Schedule: every 5 minutes
- The DAG runs `dbt deps` and `dbt run` against the same local Postgres warehouse used by the manual `dbt` service
- In the dev Helm path, Airflow runs inside the same release and serves its UI through the `realtime-dev-realtime-app-airflow` service

## Data Validation

Run these checks after startup to validate each pipeline layer.

Validate Kafka topic fan-out:

```bash
./scripts/check-pipeline-topics.sh
```

Validate landing, bronze, silver, and gold row counts in Postgres:

```bash
make verify-warehouse
```

List dbt-created relations and materializations:

```bash
make verify-dbt-relations
```

If you need to rerun dbt manually:

```bash
make dbt-run
```

If you want to trigger the scheduled Airflow DAG immediately:

```bash
make airflow-trigger-dbt-dag
```

`make dbt-run` uses `docker compose run --rm dbt`, so Compose may briefly wait on dependencies before the dbt command starts.

## Validation Snapshot (2026-04-18)

The following checks were validated against the current workspace and local dev cluster state.

Static validation:

- `docker compose config` rendered successfully.
- `helm dependency build charts/realtime-app` completed successfully.
- `helm template realtime-dev charts/realtime-app -f environments/dev/values.yaml` rendered successfully.

Runtime validation (Routine B cluster):

- `kubectl -n argocd get application realtime-dev` reported `SYNC=Synced`, `HEALTH=Healthy`.
- `make routine-b-ops` completed successfully end-to-end.
- `make airflow-dbt-check-dev` confirmed dbt job success (`PASS=11 WARN=0 ERROR=0`).
- `make mdm-topics-check-dev` consumed records from `mdm_customer` and `mdm_product`.
- `make iceberg-streaming-smoke-dev` passed with non-zero row counts in `lakehouse.streaming` tables.

Important GitOps note:

- If Argo CD owns the release, treat Git as source of truth and sync through Argo CD after committing chart changes.
- If the app is missing in Argo CD UI, re-apply `argocd/dev.yaml` and validate with `kubectl -n argocd get application realtime-dev`.

## Build Commands

Build the Java processor jar:

```bash
cd processor
mvn -DskipTests package
```

Run the producer directly:

```bash
cd producer
uv sync
uv run producer
```

## Notes

- `qa` and `prd` values assume Kafka already exists and is reachable at the configured bootstrap service address.
- The Flink job is embedded in the Spring Boot process for a simple local and GitOps deployment model.
