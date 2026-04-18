# Full Stack Modern Data Architecture and Engineering

This repository implements a realtime sales processing platform that can run in two local modes:

- Docker Compose for fast application development and topic validation.
- kind plus Helm plus Argo CD for a GitOps-like local Kubernetes workflow.

The pipeline shape is:

- The Python producer emits composite order events to `raw_sales_orders`.
- The Java Spring Boot app starts a Flink DataStream job.
- Flink splits and transforms records into `sales_order`, `sales_order_line_item`, and `customer_sales`.
- Kafka Connect sinks processed topics into Iceberg tables on MinIO and mirrors topic data into Postgres landing tables.
- A MySQL-backed MDM service stores `customer360` and `product_master` records.
- Debezium captures MySQL CDC events, and a Python CDC publisher emits curated `mdm_customer` and `mdm_product` Kafka topics.
- dbt builds `bronze`, `silver`, and `gold` models in Postgres as a medallion-style analytics layer.
- Optional observability services in Kubernetes provide Prometheus, Loki, and Grafana.

## End-to-End Tech Components

- Event ingestion: Python producer publishes realtime sales events to Kafka.
- Stream processing: Java Spring Boot service runs an embedded Apache Flink job for fan-out and transformations.
- Messaging backbone: Apache Kafka carries raw, processed, and curated MDM topics.
- CDC and MDM: MySQL stores master data, Debezium captures binlog changes, and Python CDC publisher emits curated MDM streams.
- Lakehouse ingestion: Kafka Connect sinks streams to Iceberg tables on MinIO and to Postgres landing tables.
- Warehouse modeling: dbt transforms `landing` data into `bronze`, `silver`, and `gold` layers.
- Scheduling: Apache Airflow triggers recurring dbt runs.
- Runtime and delivery: Docker Compose supports local routine A, while kind + Helm + Argo CD provide GitOps-style routine B.
- Observability: Kafka UI, Grafana, Prometheus, and Loki support monitoring and troubleshooting.

## Docs Index

- [docs/runbook.md](docs/runbook.md): Hands-on operational guide for local Compose and kind/Helm/Argo CD workflows, including access, validation, troubleshooting, and reset routines.
- [docs/architecture_design.md](docs/architecture_design.md): Canonical architecture reference with project-level, deployment, and end-to-end dataflow diagrams plus modern data platform patterns.

## Architecture Snapshot

- Producer emits composite sales events to `raw_sales_orders`.
- Processor (Spring Boot + Flink) consumes raw events and fans out to `sales_order`, `sales_order_line_item`, and `customer_sales`.
- MDM writer upserts customer and product master records into MySQL.
- Debezium captures MySQL changes and the CDC publisher forwards them to `mdm_customer` and `mdm_product`.
- Kafka Connect sinks processed streams to Iceberg on MinIO and Postgres landing tables.
- dbt models transform landing into bronze, silver, and gold warehouse layers.
- Airflow schedules recurring dbt runs.
- Argo CD reconciles Helm-based Kubernetes deployments; Grafana/Loki/Prometheus provide observability.

Canonical architecture diagrams live in:

- [docs/architecture_design.md](docs/architecture_design.md)

## Operations Runbook

Use the runbook for complete local procedures, including startup, validation, UI access, troubleshooting, and reset:

- [docs/runbook.md](docs/runbook.md)

Use the architecture design doc for the canonical system architecture, deployment components, and modern data platform patterns:

- [docs/architecture_design.md](docs/architecture_design.md)

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
- `docs/architecture_design.md`: Architecture diagrams and modern data engineering framework/patterns.

## Quick Start: Docker Compose

Use one of these local startup paths depending on what you need.

Start the full stack, including Kafka, producer, processor, Kafka Connect, Postgres, MinIO, and the one-shot dbt run:

```bash
docker compose up -d --build
```

Start only the core streaming path for a faster inner loop:

```bash
docker compose up -d --build kafka topic-init kafka-ui producer processor
```

Once the stack is running:

- Kafka is exposed on `localhost:9094`
- Kafka UI is exposed on `http://localhost:8080`
- The producer writes composite order events into `raw_sales_orders`
- The processor fans out records into `sales_order`, `sales_order_line_item`, and `customer_sales`
- The MDM writer upserts master data into MySQL `mdm.customer360` and `mdm.product_master`
- Debezium plus CDC publisher emits `mdm_customer` and `mdm_product`

Inspect the Kafka topics from the running local stack:

```bash
./scripts/list-topics.sh
./scripts/consume-topic.sh raw_sales_orders 3
./scripts/check-pipeline-topics.sh
```

Start the downstream lakehouse + warehouse layer:

```bash
make lakehouse-up
```

Start Airflow only:

```bash
make airflow-up
```

Run dbt transforms (`landing` -> `bronze` -> `silver` -> `gold`) in Postgres:

```bash
make dbt-run
```

Local endpoints for this layer:

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

## Quick Start: kind + Helm + Argo CD

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

1. Create a kind cluster and install Argo CD:

   ```bash
   ./scripts/bootstrap-kind.sh
   ```

2. Build producer, processor, connect, dbt, and airflow images locally and load them into kind:

   ```bash
   ./scripts/build-images.sh
   ```

3. Apply the Argo CD dev application (if using Argo CD path):

   ```bash
   kubectl apply -f argocd/dev.yaml
   ```

4. Wait for Argo CD and the app to sync:

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

5. Verify the Kafka pipeline in the dev namespace:

   ```bash
   kubectl -n realtime-dev get pods
   kubectl -n realtime-dev logs deploy/realtime-dev-realtime-app-processor --tail=100
   ```

6. Verify the warehouse and scheduling layer in the dev namespace:

   ```bash
   kubectl -n realtime-dev get pods
   kubectl -n realtime-dev logs job/realtime-dev-realtime-app-dbt --tail=100
   kubectl -n realtime-dev logs deploy/realtime-dev-realtime-app-airflow --tail=100
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-airflow 8084:8080
   kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-minio 9001:9001
   ```

7. Access local UIs and Postgres when running in kind:

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

Use these checks after the stack is up to verify each layer of the pipeline.

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
