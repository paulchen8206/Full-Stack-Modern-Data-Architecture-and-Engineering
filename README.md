# Full Stack Modern Data Architecture and Engineering

This repository demonstrates a modern data platform that combines realtime processing, lakehouse storage, ELT modeling, and GitOps delivery.

It supports two local operating modes:

- Docker Compose for fast development loops.
- kind plus Helm plus Argo CD for Kubernetes and GitOps workflow simulation.

## What This Project Demonstrates

- Kafka as a realtime event backbone.
- Flink stream processing embedded in a Java Spring Boot service.
- CDC-driven MDM integration with MySQL + Debezium.
- Lakehouse sinks using Iceberg on MinIO.
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

Portability guidance:

- Keep Kafka topic contracts and medallion model intent unchanged.
- Use environment-specific dbt profiles and adapter packages per target platform.
- Replace sink connectors and storage integrations to match the selected warehouse/lakehouse stack.
- Preserve dimensional model semantics (conformed dimensions and facts) across platforms.

### Concrete Migration Matrix (Quick Reference)

| Target | Connector change | dbt adapter | Key config changes |
| --- | --- | --- | --- |
| Redshift | Use Redshift sink pattern (direct connector or S3 staging + COPY) | `dbt-redshift` | Redshift endpoint/db/schema plus IAM/COPY settings |
| Snowflake | Use Snowflake Kafka Connector | `dbt-snowflake` | Account/role/warehouse/database/schema and auth method |
| BigQuery | Use BigQuery Sink connector | `dbt-bigquery` | Project/dataset/location and service account auth |
| Databricks | Use Delta sink pattern for Databricks tables | `dbt-databricks` | SQL warehouse host/http_path/token and catalog/schema |

For full migration detail and workflow, see [docs/architecture.md](docs/architecture.md).

### Fast Links to New Migration Sections

- Sample .env onboarding blocks per platform: [docs/architecture.md - 3.3 Sample Environment Variable Blocks (.env Style)](docs/architecture.md#33-sample-environment-variable-blocks-env-style)
- Cloud Kubernetes migration candidates (AWS/GCP/Azure): [docs/architecture.md - 8.3 Cloud Kubernetes Migration Candidates](docs/architecture.md#83-cloud-kubernetes-migration-candidates)

## End-to-End Flow (High Level)

1. Python producer publishes composite sales events to raw_sales_orders.
2. Java/Flink processor consumes and fans out into sales_order, sales_order_line_item, and customer_sales topics.
3. Kafka Connect sinks these topics to Iceberg on MinIO and Postgres landing tables.
4. MDM writer updates MySQL customer and product master records.
5. Debezium captures MDM CDC; CDC publisher emits curated mdm_customer and mdm_product topics.
6. PySpark sync moves MDM tables into Postgres landing.
7. dbt builds bronze, silver, and gold analytics models.
8. Airflow schedules recurring dbt runs.

## Documentation

- Architecture reference: [docs/architecture.md](docs/architecture.md)
- Operations runbook: [docs/runbook.md](docs/runbook.md)

## Repository Layout

- `producer`: Python Kafka producer for composite sales orders.
- `mdm-writer`: Python app that inserts and updates MySQL MDM master data.
- `mdm-cdc-producer`: Python app that consumes Debezium CDC topics and publishes `mdm_customer` and `mdm_product`.
- `mdm-pyspark-sync`: PySpark app that continuously syncs MySQL MDM tables into Postgres landing tables.
- `processor`: Spring Boot application that launches the Flink topology.
- `charts/realtime-app`: Helm chart for producer, processor, Kafka UI, MinIO, Postgres, Kafka Connect, dbt bootstrap, Airflow, and optional Kafka.
- `environments`: Helm values for `dev`, `qa`, and `prd`.
- `argocd`: Argo CD Application manifests.
- `connect`: Kafka Connect image and connector configurations (Iceberg + JDBC sinks).
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

Start the full stack, including Kafka, producer, processor, Kafka Connect, Postgres, MinIO, and the one-shot dbt run:

```bash
docker compose up -d --build
```

Start only the core streaming path for a faster inner loop:

```bash
docker compose up -d --build kafka topic-init kafka-ui producer processor
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

Run dbt manually:

```bash
make dbt-run
```

Start Airflow:

```bash
make airflow-up
```

Key local endpoints:

- Kafka is exposed on `localhost:9094`
- Kafka UI is exposed on `http://localhost:8080`
- MinIO API: `http://localhost:9000`
- MinIO Console: `http://localhost:9001`
- Kafka Connect REST: `http://localhost:8083`
- Debezium Connect REST (MDM): `http://localhost:8085`
- Airflow UI: `http://localhost:8084`
- Postgres: `localhost:5432` (user/password/db: `analytics`)
- MySQL MDM: `localhost:3306` (root password: `mdmroot`, db: `mdm`)

Local Airflow credentials:

- Username: `admin`
- Password: `admin`

Expected container behavior:

- `topic-init`, `minio-init`, and `connect-init` are one-shot init containers and normally end in `Exited (0)`.
- `dbt` is also a one-shot service and normally ends in `Exited (0)` after `dbt run` completes.
- A finished `dbt` container does not mean bronze, silver, or gold data is missing.

### Option B: kind + Helm + Argo CD

Use this flow to run the dev environment on kind while building images locally with Docker.

Docker-equivalent one-command Helm bootstrap:

```bash
make routine-b
```

Argo CD app bootstrap alternative:

```bash
make routine-b-argocd
```

Docker-equivalent one-command Helm stop:

```bash
make routine-b-down
```

Minimal path:

1. Create kind cluster and install Argo CD:

   ```bash
   ./scripts/bootstrap-kind.sh
   ```

2. Build and load local images into kind:

   ```bash
   ./scripts/build-images.sh
   ```

3. Apply Argo CD application (Argo workflow):

   ```bash
   kubectl apply -f argocd/dev.yaml
   ```

4. Verify sync and workloads:

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

5. Validate processor pipeline logs:

   ```bash
   kubectl -n realtime-dev get pods
   kubectl -n realtime-dev logs deploy/realtime-dev-realtime-app-processor --tail=100
   ```

6. Validate dbt and Airflow logs:

   ```bash
   kubectl -n realtime-dev get pods
   kubectl -n realtime-dev logs job/realtime-dev-realtime-app-dbt --tail=100
   kubectl -n realtime-dev logs deploy/realtime-dev-realtime-app-airflow --tail=100
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-airflow 8084:8080
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-minio 9001:9001
   ```

7. Port-forward local access:

   ```bash
   kubectl -n argocd port-forward svc/argocd-server 8443:443
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-kafka-ui 8082:8080
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-minio 9001:9001
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-postgres 5433:5432
   ```

   - Argo CD URL: `https://localhost:8443`
   - Argo CD username: `admin`
   - Argo CD password command:

   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode; echo
   ```

   - Kafka UI URL: `http://localhost:8082`
   - MinIO Console URL: `http://localhost:9001` (user: `minio`, password: `minio123`)
   - Postgres: host `127.0.0.1`, port `5433`, user `analytics`, password `analytics`, db `analytics`

Dev environment behavior:

- Uses in-cluster Kafka from the Helm dependency (`kafka.enabled=true` in `environments/dev/values.yaml`).
- Uses locally built producer, processor, Kafka Connect, dbt, and Airflow images already loaded into kind (`imagePullPolicy: Never`).
- Deploys MinIO, Postgres, Kafka Connect, a one-shot dbt bootstrap Job, and Airflow in the same Helm release.
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

- `connect` service runs:
   - Iceberg sink connectors for `sales_order`, `sales_order_line_item`, and `customer_sales` into MinIO (`warehouse/iceberg`).
   - JDBC sink connector for the same topics into Postgres `landing` schema.
- Connector registration happens automatically in `connect-init` in Compose and via a Kubernetes Job in the Helm release.

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

Verify Kafka topic fan-out:

```bash
./scripts/check-pipeline-topics.sh
```

Verify landing, bronze, silver, and gold row counts in Postgres:

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

The following checks were run against this workspace and local cluster state.

Static validation:

- `docker compose config` rendered successfully.
- `helm dependency build charts/realtime-app` completed successfully.
- `helm template realtime-dev charts/realtime-app -f environments/dev/values.yaml` rendered successfully.

Runtime validation (Routine B cluster):

- Argo CD app status: `realtime-dev` reported `HEALTH=Healthy`, `SYNC=OutOfSync`.
- Core platform pods were `Running` and one-shot bootstrap Jobs were `Completed`.
- dbt Job completed with `PASS=11 WARN=0 ERROR=0`.
- Postgres canonical warehouse schemas were present: `landing`, `bronze`, `silver`, `gold`.
- `public_gold` was also observed in runtime due app drift; clean up and Argo sync are required to keep schema naming deterministic.

Important GitOps note:

- If Argo CD owns the release, local `make helm-reboot-dev` may fail with ownership/immutable-field conflicts.
- In that case, commit chart changes and sync via Argo CD (`kubectl apply -f argocd/dev.yaml` then app sync/refresh) so runtime config matches Git.
- A one-time cleanup may be needed to remove already-created `public_*` schemas; see the runbook troubleshooting section.

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
