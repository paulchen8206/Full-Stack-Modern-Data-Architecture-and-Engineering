# Architecture Reference

This document is the canonical architecture reference for this project. It organizes the platform as a modern data architecture that combines batch and streaming, ELT modeling, lakehouse storage, metadata cataloging, observability, and GitOps deployment automation.

## Purpose

Define the canonical architecture, principles, and technology choices for this platform.

## Commands

Use the architecture-to-operations mapping in this document to choose the correct Make targets and deployment flows.

## Validation

Use the validation-oriented sections and mapped operational checks to confirm architecture behavior in local environments.

## Troubleshooting

Use architecture notes in this document to diagnose design-level issues, then use the runbook for step-by-step remediation.

## References

- [../readme.md](../readme.md)
- [runbook.md](runbook.md)
- [adr/README.md](adr/README.md)

## Documentation Map

- Project entrypoint: [../readme.md](../readme.md)
- Deployment guide (all routines): [deployment.md](deployment.md)
- Operations runbook: [runbook.md](runbook.md)
- Architecture Decision Records (ADR): [adr/README.md](adr/README.md)

## 1. Purpose and Scope

This platform demonstrates how to build a full-stack modern data system with these goals:

- Capture and process real-time events with Kafka and Flink.
- Persist data in a lakehouse pattern using S3-compatible object storage locally, with a path to true Iceberg tables and SQL querying, and in an analytics warehouse pattern (Postgres used to mimic Snowflake-like warehouse behavior).
- Apply ELT transformations with dbt using medallion layers (bronze, silver, gold).
- Incorporate dimensional modeling for analytics consumption.
- Centralize metadata, lineage, and discovery in OpenMetadata as the data catalog surface.
- Provide operational and data-plane observability with Prometheus, Grafana, Blackbox probing, and runbook-driven checks.
- Run services in containers (Docker) and orchestrate on Kubernetes.
- Support polyglot engineering using Java and Python.
- Automate deployment through Helm (release packaging) and Argo CD (GitOps reconciliation).
- Keep the architecture portable so the analytics lakehouse/warehouse target can be Postgres (local demo), Redshift, Snowflake, BigQuery, or Databricks.

Out of scope for this demo:

- Cloud-managed production hardening (fully managed Kafka, managed object storage, enterprise IAM).
- Regulatory controls and enterprise governance implementation details.

## 2. Architectural Principles

- Event-driven first:
  Domain changes are emitted as immutable events to Kafka.
- Separation of concerns:
  Ingestion, stream processing, storage, and transformation are independently deployable components.
- ELT over ETL:
  Raw/landing data is loaded first, then transformed in the warehouse/lakehouse layer with dbt.
- Streaming plus batch unification:
  Streaming outputs are continuously available while batch-style analytics models are refreshed on schedule.
- Declarative operations:
  Helm values and Argo CD manifests drive environment consistency.
- Progressive environment promotion:
  Same topology across dev, qa, and prd with environment overlays.
- Metadata as a product:
  Data assets are discoverable and governed through a shared metadata catalog and lineage model.
- Observability by default:
  Runtime, metadata, and delivery paths expose health and diagnostics.

## 3. Technology Mapping

| Capability | Technology in this project | Role |
| --- | --- | --- |
| Realtime event backbone | Kafka | Durable event transport, fan-out, and replay |
| Realtime stream compute | Flink (embedded in Spring Boot processor) | Event decomposition and transformation |
| Additional compute/sync | PySpark | MDM table synchronization to analytics landing |
| Warehouse simulation | Postgres | Mimics Snowflake-style SQL analytics target for local development |
| Lakehouse storage | MinIO | Local S3-compatible object storage for lakehouse data |
| Query engine | Trino | Interactive SQL layer for Iceberg-compatible tables on MinIO |
| Cloud warehouse/lakehouse targets (optional) | Redshift / Snowflake / BigQuery / Databricks | Production-grade alternatives using the same ELT and dimensional-modeling patterns |
| ELT modeling | dbt | Bronze/silver/gold SQL transformations and dimensional model materialization |
| CDC for master data | Debezium + MySQL | Capture and stream row-level changes |
| Orchestration | Airflow | Scheduled dbt execution |
| Metadata cataloging | OpenMetadata | Unified metadata discovery, lineage, and ingestion control plane |
| Container runtime | Docker / Docker Compose | Local service packaging and fast inner-loop execution |
| Container orchestration | Kubernetes (kind locally) | Cluster-style deployment and parity testing |
| Release packaging | Helm | Templated, versioned deployment definitions |
| GitOps delivery | Argo CD | Continuous reconciliation from Git to cluster |
| Observability | Prometheus + Grafana + Blackbox Exporter | Metrics, dashboards, endpoint probing, and operational diagnostics |
| Programming languages | Java + Python | Java for stream processor, Python for producers/integration/sync services |

MinIO portability note:

- MinIO is the local S3-compatible object storage layer in this project.
- For cloud migration, replace MinIO with Amazon S3 (AWS), Google Cloud Storage (GCP), or Azure Data Lake Storage Gen2 (Azure).

Current state note:

- The current Kafka Connect path writes raw JSON objects to MinIO through the S3 sink connector.
- Trino is added as the query engine foundation, and this repository now includes a Trino-managed path to create real Iceberg tables on MinIO from Postgres landing data.
- This repository also includes a direct Kafka-to-Iceberg writer path that consumes streaming topics and writes Iceberg tables through Trino.

### 3.1 Concrete Migration Matrix (Connectors + dbt + Config)

The table below shows concrete deltas required to migrate from the default local setup (Postgres + MinIO) to each target platform.

| Target platform | Kafka/ingestion connector changes | dbt adapter changes | Core config changes | Notes |
| --- | --- | --- | --- | --- |
| Redshift | Replace JDBC sink to Postgres with either Redshift Sink connector or S3 staging plus COPY pipeline into Redshift | Use `dbt-redshift` and a `target: redshift` profile | Set `host`, `port`, `dbname`, `user`, `password`, `schema`; tune dist/sort keys and COPY IAM permissions | Best for teams already on AWS analytics stack |
| Snowflake | Replace JDBC sink with Snowflake Kafka Connector (Snowpipe Streaming or staged loads) | Use `dbt-snowflake` and a `target: snowflake` profile | Set `account`, `user`, `password` or key-pair auth, `role`, `warehouse`, `database`, `schema` | Keep medallion layers as schemas or databases per environment |
| BigQuery | Replace JDBC sink with BigQuery Sink connector | Use `dbt-bigquery` and a `target: bigquery` profile | Set service account auth, `project`, `dataset`, `location`, `method` (oauth/service-account) | Partition and clustering should be configured for fact models |
| Databricks | Replace JDBC sink with Delta Lake sink pattern (Kafka Connect Delta sink or cloud object sink consumed by Databricks) | Use `dbt-databricks` and a `target: databricks` profile | Set `host`, `http_path`, `token`, `catalog`, `schema`; configure Unity Catalog and cluster/SQL warehouse access | Keep Iceberg/Delta table governance consistent with medallion model intent |

Recommended migration workflow:

1. Keep topic names, event contracts, and dbt model semantics unchanged.
2. Switch connector layer and warehouse credentials by environment values.
3. Switch dbt adapter + profile target and run `dbt deps` and `dbt run` in lower environment.
4. Validate row counts and key dimensions/facts parity before promoting.

Local Trino materialization note:

- In this repository, real Iceberg tables can be created immediately by Trino from the existing Postgres `landing` schema.
- This is a pragmatic local bridge that now coexists with a direct Kafka-to-Iceberg writer path.

### 3.2 Sample dbt Profile Templates by Platform

The snippets below are example `profiles.yml` templates for each target platform. They use environment variables so credentials are not hardcoded.

#### Redshift (`dbt-redshift`)

```yaml
analytics:
  target: redshift
  outputs:
    redshift:
      type: redshift
      host: "{{ env_var('DBT_REDSHIFT_HOST') }}"
      port: 5439
      user: "{{ env_var('DBT_REDSHIFT_USER') }}"
      password: "{{ env_var('DBT_REDSHIFT_PASSWORD') }}"
      dbname: "{{ env_var('DBT_REDSHIFT_DB') }}"
      schema: "{{ env_var('DBT_REDSHIFT_SCHEMA', 'landing') }}"
      threads: 4
      sslmode: prefer
```

#### Snowflake (`dbt-snowflake`)

```yaml
analytics:
  target: snowflake
  outputs:
    snowflake:
      type: snowflake
      account: "{{ env_var('DBT_SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('DBT_SNOWFLAKE_USER') }}"
      password: "{{ env_var('DBT_SNOWFLAKE_PASSWORD') }}"
      role: "{{ env_var('DBT_SNOWFLAKE_ROLE', 'TRANSFORMER') }}"
      warehouse: "{{ env_var('DBT_SNOWFLAKE_WAREHOUSE') }}"
      database: "{{ env_var('DBT_SNOWFLAKE_DATABASE') }}"
      schema: "{{ env_var('DBT_SNOWFLAKE_SCHEMA', 'landing') }}"
      threads: 4
      client_session_keep_alive: false
```

#### BigQuery (`dbt-bigquery`)

```yaml
analytics:
  target: bigquery
  outputs:
    bigquery:
      type: bigquery
      method: service-account
      project: "{{ env_var('DBT_BIGQUERY_PROJECT') }}"
      dataset: "{{ env_var('DBT_BIGQUERY_DATASET', 'landing') }}"
      location: "{{ env_var('DBT_BIGQUERY_LOCATION', 'US') }}"
      keyfile: "{{ env_var('DBT_BIGQUERY_KEYFILE') }}"
      threads: 4
      timeout_seconds: 300
```

#### Databricks (`dbt-databricks`)

```yaml
analytics:
  target: databricks
  outputs:
    databricks:
      type: databricks
      host: "{{ env_var('DBT_DATABRICKS_HOST') }}"
      http_path: "{{ env_var('DBT_DATABRICKS_HTTP_PATH') }}"
      token: "{{ env_var('DBT_DATABRICKS_TOKEN') }}"
      catalog: "{{ env_var('DBT_DATABRICKS_CATALOG', 'main') }}"
      schema: "{{ env_var('DBT_DATABRICKS_SCHEMA', 'landing') }}"
      threads: 4
```

Template usage notes:

1. Keep one profile name (for example `analytics`) across all platforms to avoid changing `dbt_project.yml`.
2. Change only `target` and environment variables per environment (`dev`, `qa`, `prd`).
3. Install the matching adapter package in the dbt runtime image (`dbt-redshift`, `dbt-snowflake`, `dbt-bigquery`, or `dbt-databricks`).
4. Run `dbt debug` before `dbt run` after any platform switch.

### 3.3 Sample Environment Variable Blocks (.env Style)

Use these blocks as onboarding starters. They map directly to the profile templates above.

#### Redshift example

```dotenv
DBT_REDSHIFT_HOST=example-cluster.abc123.us-east-1.redshift.amazonaws.com
DBT_REDSHIFT_USER=analytics_user
DBT_REDSHIFT_PASSWORD=change_me
DBT_REDSHIFT_DB=analytics
DBT_REDSHIFT_SCHEMA=landing
```

#### Snowflake example

```dotenv
DBT_SNOWFLAKE_ACCOUNT=xy12345.us-east-1
DBT_SNOWFLAKE_USER=analytics_user
DBT_SNOWFLAKE_PASSWORD=change_me
DBT_SNOWFLAKE_ROLE=TRANSFORMER
DBT_SNOWFLAKE_WAREHOUSE=COMPUTE_WH
DBT_SNOWFLAKE_DATABASE=ANALYTICS
DBT_SNOWFLAKE_SCHEMA=LANDING
```

#### BigQuery example

```dotenv
DBT_BIGQUERY_PROJECT=my-gcp-project
DBT_BIGQUERY_DATASET=landing
DBT_BIGQUERY_LOCATION=US
DBT_BIGQUERY_KEYFILE=/secrets/gcp-service-account.json
```

#### Databricks example

```dotenv
DBT_DATABRICKS_HOST=dbc-12345678-aaaa.cloud.databricks.com
DBT_DATABRICKS_HTTP_PATH=/sql/1.0/warehouses/abc123def456
DBT_DATABRICKS_TOKEN=change_me
DBT_DATABRICKS_CATALOG=main
DBT_DATABRICKS_SCHEMA=landing
```

Environment variable handling guidelines:

1. Do not commit real secrets to Git.
2. Use secret stores (for example Kubernetes Secrets, cloud secret managers, or CI protected variables).
3. Keep variable names consistent across `dev`, `qa`, and `prd` to simplify deployment automation.
4. Validate connectivity in CI with `dbt debug` before running transformations.

## 4. Logical Architecture Overview

This section describes the core platform components and their interaction boundaries.

Diagram: logical architecture component diagram.

```mermaid
flowchart LR
  subgraph Bootstrap[Compose Bootstrap and Contracts]
    KI["Kafka Init Topics"]
    MI["MinIO Init Bucket"]
    SI["Schema Init Avro Subjects"]
    OI["ODS Connect Init Sink Registration"]
    DI["DBZ Connect Init Source Registration"]
    MCI["MDM Connect Init Sink Registration"]
  end

  subgraph Stream[Realtime Streaming Plane]
    PR["Producer"]
    FL["Processor Spring Boot and Flink"]
    K["Kafka Cluster kafka-1 kafka-2 kafka-3"]
    SR["Schema Registry"]
    PR -->|Raw Sales Orders| K
    K -->|Consume| FL
    FL -->|Sales Order and Sales Order Line Item and Customer Sales| K
    SR -.Schema Contracts.-> FL
  end

  subgraph Connectors[Kafka Connect and CDC Plane]
    ODS["ODS Connect"]
    DBZ["DBZ Connect"]
    MDMK["MDM Connect"]
    MCP["MDM CDC Curate"]
    MDM["MySQL MDM Source"]
    MDM -->|Binlog CDC| DBZ
    DBZ -->|Raw MDM CDC Topics| K
    K -->|Curate CDC| MCP
    MCP -->|MDM Customer and MDM Product| K
    K --> ODS
    K --> MDMK
  end

  subgraph Analytics[Lakehouse and Warehouse Plane]
    IO["MinIO"]
    PG["Postgres Snowflake Mimic"]
    SP["PySpark MDM Sync"]
    TQ["Trino"]
    IW["Iceberg Writer"]
    DBT["dbt Bootstrap Job"]
    AF["Airflow Scheduler"]
    ODS --> PG
    ODS --> IO
    MDMK --> PG
    MDM --> SP
    SP --> PG
    K --> IW
    IW -->|Write via Trino Catalog| TQ
    TQ --> IO
    PG --> DBT
    AF --> DBT
  end

  subgraph Meta[Metadata Plane Optional profile openmetadata]
    OMI["OpenMetadata Ingestion"]
    OM["OpenMetadata Server"]
    OMI --> OM
    TQ -.Metadata and Lineage.-> OMI
    PG -.Metadata and Lineage.-> OMI
    DBT -.Artifacts and Lineage.-> OMI
    AF -.Pipeline Metadata.-> OMI
    K -.Topic Metadata.-> OMI
  end

  subgraph Ops[Observability and Operations]
    PROM["Prometheus"]
    BBX["Blackbox Exporter"]
    GRAF["Grafana"]
    KUI["Kafka UI or Conduktor"]
    BBX --> PROM
    PROM --> GRAF
    K --> KUI
  end

  KI --> K
  MI --> IO
  SI --> SR
  OI --> ODS
  DI --> DBZ
  MCI --> MDMK

  Ops -.Health and Metrics.-> Stream
  Ops -.Health and Metrics.-> Connectors
  Ops -.Health and Metrics.-> Analytics
  Ops -.Health and Metrics.-> Meta
```

## 5. End-to-End Data Flow

This section describes the end-to-end movement of data across runtime, analytics, and metadata planes.

Diagram: end-to-end dataflow diagram.

```mermaid
flowchart LR
  subgraph S[Sources]
    SRC1[Sales Source App Producer]
    SRC2[MDM Source MySQL]
    BOOT1[Kafka Init Topics]
    BOOT2[Schema Init Contracts]
  end

  subgraph P[Pipeline processing]
    K[(Kafka Cluster)]
    SR[Schema Registry]
    PROC[Spring Boot and Flink Processor]
    ODS[ODS Connect Sink Tasks]
    DBZ[DBZ Connect]
    MCP[MDM CDC Curate]
    MDMK[MDM Connect Sink Tasks]
    SP[MDM PySpark Sync]
    IW[Iceberg Writer]
    TR[Trino SQL Write Path]
    DBT[dbt Medallion Build]
    AF[Airflow Schedule Trigger]
  end

  subgraph T[Targets]
    TGT1[(Postgres Landing and Analytics)]
    TGT2[(MinIO Raw Objects)]
    TGT3[(Iceberg Tables on MinIO)]
    TGT4[OpenMetadata Catalog Optional]
    TGT5[Grafana Dashboards]
  end

  BOOT1 --> K
  BOOT2 --> SR
  SRC1 -->|Raw Sales Orders| K
  K --> PROC
  SR -.Schema Lookup.-> PROC
  PROC -->|Sales Order / Sales Order Line Item / Customer Sales| K
  K --> ODS
  ODS --> TGT1
  ODS --> TGT2

  SRC2 --> DBZ
  DBZ -->|Raw CDC Topics| K
  K --> MCP
  MCP -->|MDM Customer / MDM Product| K
  K --> MDMK
  MDMK --> TGT1
  SRC2 --> SP
  SP --> TGT1

  K --> IW
  IW --> TR
  TR --> TGT3

  TGT1 --> DBT
  AF --> DBT

  K -.Topic Metadata.-> TGT4
  TR -.Table Metadata.-> TGT4
  TGT1 -.Warehouse Metadata.-> TGT4
  DBT -.Lineage Metadata.-> TGT4

  OBS[Blackbox Exporter and Prometheus] --> TGT5
```

### 5.1 Realtime Sales Domain Flow

This subsection describes realtime event processing from raw producer events to modeled analytics outputs.

Diagram: Routine A realtime sales dataflow.

```mermaid
flowchart LR
  subgraph S[Source]
    P[Sales Producer]
  end

  subgraph P1[Pipeline]
    K[(Kafka Cluster)]
    F[Spring Boot and Flink Processor]
    SR[Schema Registry]
    ODS[ODS Connect]
    IW[Iceberg Writer]
    T[Trino]
    A[Airflow]
    D[dbt Medallion Models]
  end

  subgraph T1[Targets]
    PG[(Postgres Landing)]
    M[(MinIO Raw Objects)]
    I[(Iceberg Tables on MinIO)]
  end

  P -->|Raw Sales Orders| K
  K -->|Consume| F
  SR -.Avro Contracts.-> F
  F -->|Sales Order / Sales Order Line Item / Customer Sales| K
  K --> ODS
  ODS --> PG
  ODS --> M
  K --> IW
  IW --> T
  T --> I
  PG --> D
  A --> D
```

1. Python producer publishes composite sales events to `raw_sales_orders`.
2. Java/Flink processor consumes raw events and fans out normalized streams:
   - `sales_order`
   - `sales_order_line_item`
   - `customer_sales`
3. Kafka Connect sinks these streams to raw JSON objects in MinIO and to Postgres `landing` schema tables.
4. Trino can materialize and query MinIO-backed Iceberg tables from the Postgres `landing` schema.
5. A direct Kafka-to-Iceberg writer can populate `lakehouse.streaming` tables without the Postgres bridge.
6. dbt models build medallion layers and dimensional outputs in Postgres.

### 5.2 Master Data (MDM) Flow

This subsection describes master data capture, CDC publication, and analytics synchronization.

Diagram: Routine A MDM CDC dataflow.

```mermaid
flowchart LR
  subgraph S2[Source]
    M[(MDM Source MySQL)]
  end

  subgraph P2[Pipeline]
    DBZ[DBZ Connect]
    K[(Kafka Cluster)]
    MCP[MDM CDC Curate]
    MDMK[MDM Connect]
    SP[MDM PySpark Sync]
    DBT[dbt Silver and Gold Joins]
  end

  subgraph T2[Target]
    PG[(Postgres Landing MDM Tables)]
  end

  M -->|Binlog CDC| DBZ
  DBZ -->|Raw MDM CDC Topics| K
  K -->|Curate CDC| MCP
  MCP -->|MDM Customer / MDM Product| K
  K --> MDMK
  MDMK --> PG
  M --> SP
  SP --> PG
  PG --> DBT
```

1. MDM writer upserts `customer360` and `product_master` entities into MySQL.
2. Debezium captures MySQL binlog changes and emits raw CDC topics.
3. CDC publisher normalizes/curates CDC records into analytics-friendly topics (`mdm_customer`, `mdm_product`).
4. PySpark sync job loads MySQL MDM tables into Postgres landing MDM tables.
5. dbt joins transactional and MDM data to build conformed dimensions and facts.

### 5.3 Data Cataloging and Observability Flow

This subsection describes metadata ingestion and observability signal paths used for operational validation.

Diagram: Routine A metadata and observability dataflow.

```mermaid
flowchart LR
  subgraph S3[Source Assets]
    K[(Kafka Cluster)]
    T[Trino]
    PG[(Postgres Analytics)]
    D[dbt Artifacts]
    A[Airflow Metadata]
  end

  subgraph P3[Metadata and Monitoring Pipeline]
    OMI[OpenMetadata Ingestion]
    BBX[Blackbox Exporter]
    PROM[Prometheus]
  end

  subgraph T3[Target Systems]
    OMS[OpenMetadata Server]
    GRAF[Grafana]
  end

  K -.Topic Metadata.-> OMI
  T -.Table Metadata.-> OMI
  PG -.Warehouse Metadata.-> OMI
  D -.Lineage Artifacts.-> OMI
  A -.Pipeline Metadata.-> OMI
  OMI --> OMS

  BBX --> PROM
  PROM --> GRAF
  BBX -.Endpoint Probes.-> K
  BBX -.Endpoint Probes.-> T
  BBX -.Endpoint Probes.-> A
  BBX -.Endpoint Probes.-> OMS
```

1. OpenMetadata ingestion workflows collect metadata from Trino, Postgres, dbt artifacts, Airflow pipelines, and Kafka topics.
2. OpenMetadata stores searchable entities and lineage links for tables, topics, pipelines, and models.
3. Prometheus and Blackbox collect runtime and endpoint health metrics for core services.
4. Grafana provides dashboard views for pipeline/service health, while runbook checks validate ingestion success paths.

## 6. ELT and Medallion Design

This implementation follows ELT with medallion-style layers:

- `landing`:
  Raw ingested tables from Kafka Connect and PySpark sync.
- `bronze`:
  Lightweight standardization and source-aligned staging models.
- `silver`:
  Cleaned, conformed dimensions and facts for trusted analytical use.
- `gold`:
  Business-facing aggregates and summary outputs.

ELT rationale:

- Keep ingestion simple and resilient.
- Centralize transformation logic in version-controlled dbt SQL.
- Support lineage, testing, and repeatable model builds.

## 7. Dimensional Modeling in the Lakehouse/Warehouse

The silver and gold layers implement dimensional analytics patterns:

- Conformed dimensions:
  - `dim_mdm_customer`
  - `dim_mdm_product`
  - `dim_mdm_date`
- Transactional fact table:
  - `fact_sales_order`
- Business presentation table:
  - `gold_customer_sales_summary`

Modeling benefits:

- Simplifies BI query logic.
- Improves join consistency through conformed keys and attributes.
- Supports both operational reporting and higher-level KPI summary views.

## 8. Deployment and Runtime Topology

### 8.1 Local Development Runtime (Docker Compose)

- Primary objective: rapid local feedback loop.
- Includes producer, processor, Kafka, Kafka Connect, MinIO, Trino, MDM services, Postgres, dbt bootstrap job, and Airflow.
- One-shot init jobs (topic init, connector registration, bucket creation, dbt run) support idempotent startup.

Diagram: Routine A Docker Compose runtime topology.

```mermaid
flowchart LR
  subgraph Init[One-Shot Init Jobs]
    KI[Kafka Init]
    MI[MinIO Init]
    SI[Schema Init]
    OI[ODS Connect Init]
    DI[DBZ Connect Init]
    MCI[MDM Connect Init]
    DBTJ[dbt Bootstrap Job]
  end

  subgraph Core[Always-On Compose Services]
    ZK[Zookeeper]
    K1[Kafka 1]
    K2[Kafka 2]
    K3[Kafka 3]
    K[(Kafka Cluster)]
    SR[Schema Registry]
    PR[Producer]
    PROC[Processor]
    ODS[ODS Connect]
    DBZ[DBZ Connect]
    MDMK[MDM Connect]
    MCP[MDM CDC Curate]
    SP[MDM PySpark Sync]
    MDM[(MDM Source MySQL)]
    PG[(Snowflake Mimic Postgres)]
    MINIO[(MinIO)]
    TRINO[Trino]
    IW[Iceberg Writer]
    AF[Airflow]
    PROM[Prometheus]
    BBX[Blackbox Exporter]
    GRAF[Grafana]
    KUI[Kafka UI or Conduktor]
  end

  ZK --> K1
  ZK --> K2
  ZK --> K3
  K1 --> K
  K2 --> K
  K3 --> K

  KI --> K
  SI --> SR
  MI --> MINIO
  OI --> ODS
  DI --> DBZ
  MCI --> MDMK

  PR --> K
  K --> PROC
  PROC --> K
  SR -.Schemas.-> PROC

  K --> ODS
  K --> MDMK
  MDM --> DBZ
  DBZ --> K
  K --> MCP
  MCP --> K

  ODS --> PG
  ODS --> MINIO
  MDMK --> PG
  MDM --> SP
  SP --> PG

  K --> IW
  IW --> TRINO
  TRINO --> MINIO

  DBTJ --> PG
  AF --> DBTJ

  BBX --> PROM
  PROM --> GRAF
  K --> KUI
```

### 8.2 Kubernetes Runtime (kind + Helm + Argo CD)

This subsection describes the Kubernetes implementation model for local GitOps parity.

- Primary objective: GitOps-style deployment parity and environment promotion practice.
- Helm chart templates the full application stack.
- Argo CD continuously syncs desired state from Git.
- Environment values (`dev`, `qa`, `prd`) drive differences such as image references, broker endpoints, and scaling.
- Trino can be enabled as the lakehouse SQL endpoint for MinIO-backed Iceberg-compatible datasets.

Diagram: Kubernetes implementation diagram.

```mermaid
flowchart LR
  subgraph Git[Git Repository]
    CH[Helm Chart and Values]
    APP[Argo CD Application Manifests]
  end

  subgraph Argo[Argo CD Control Plane]
    ARGO[Argo CD Reconciler]
  end

  subgraph K8S[Kind or Kubernetes Cluster]
    subgraph NS[gndp-dev Namespace]
      KAFKA[Kafka]
      CONNECT[Kafka Connect]
      TRINO[Trino]
      POSTGRES[Postgres]
      MINIO[MinIO]
      AIRFLOW[Airflow]
      DBT[dbt Job]
      OPM[OpenMetadata Server]
      OMI[OpenMetadata Ingestion]
      PROM[Prometheus]
      GRAF[Grafana]
      BBX[Blackbox]
    end
  end

  APP --> ARGO
  CH --> ARGO
  ARGO --> K8S
  KAFKA --> CONNECT
  CONNECT --> POSTGRES
  CONNECT --> MINIO
  TRINO --> MINIO
  AIRFLOW --> DBT
  OMI --> OPM
  PROM --> GRAF
  BBX --> PROM
```

### 8.3 Cloud Kubernetes Migration Candidates

The local Kubernetes model (kind + Helm + Argo CD) is designed to migrate cleanly to managed Kubernetes on major clouds.

Object storage mapping principle:

- Keep Iceberg table layout and medallion semantics unchanged, and swap only the object storage endpoint and credentials per cloud.

| Cloud | Kubernetes target | Recommended migration candidates | Notes |
| --- | --- | --- | --- |
| AWS | EKS | Kafka on MSK or Strimzi, object storage on S3, analytics target on Redshift, observability on Amazon Managed Prometheus/Grafana | Best fit when using Redshift and AWS-native IAM/networking |
| GCP | GKE | Kafka on Confluent/GKE deployment, object storage on GCS, analytics target on BigQuery, observability on Cloud Monitoring + Managed Service for Prometheus | Best fit when BigQuery is primary warehouse target |
| Azure | AKS | Kafka on Confluent/AKS deployment, object storage on ADLS Gen2, analytics target on Databricks or Synapse, observability on Azure Monitor managed Prometheus/Grafana | Best fit for Databricks-first lakehouse and Azure enterprise controls |

Cloud migration checklist:

1. Replace local stateful services (Kafka, Postgres, MinIO) with managed equivalents per cloud.
2. Move credentials from local env files to cloud secret managers.
3. Parameterize Helm values per cloud environment and keep Argo CD as reconciliation layer.
4. Re-run migration matrix validation (connector + dbt adapter + parity checks) before production cutover.

### 8.4 Make Target Map (Architecture to Operations)

Use this quick map to connect architecture responsibilities in this document to executable commands in [runbook.md](runbook.md) and [../Makefile](../Makefile).

| Architecture responsibility | Primary routine | Make target(s) |
| --- | --- | --- |
| Build runtime images | Shared | `make compose-build` |
| Bring up local runtime services | Routine A (Docker Compose) | `make compose-up` |
| Stop local runtime services | Routine A (Docker Compose) | `make compose-down` |
| Clean Docker resources | Routine A (Docker Compose) | `make compose-clean` |
| Validate Debezium connector and MDM services | Routine A (Docker Compose) | `make mdm-status` |
| Validate curated MDM topic output | Routine A (Docker Compose) | `make mdm-topics-check` |
| Run end-to-end MDM flow validation | Routine A (Docker Compose) | `make mdm-flow-check` |
| Bootstrap GitOps-style local cluster | Routine B (kind + Helm + Argo CD) | `./cicd/k8s/kind/bootstrap-kind.sh`, `./cicd/scripts/build-images.sh`, `kubectl apply -f cicd/argocd/dev.yaml` |
| Validate cluster health and app rollout | Routine B (kind + Helm + Argo CD) | `kubectl -n argocd get application gndp-dev`, `kubectl -n gndp-dev get pods` |

Cross-reference note:

- Architecture rationale stays in this document.
- Step-by-step operator procedure stays in [runbook.md](runbook.md).
- Command implementation source of truth stays in [../Makefile](../Makefile).

### Docker Compose vs Helm/K8s Service Comparison

The tables below map every service across both runtimes. "Helm dev" reflects `values-dev.yaml` merged over the base `values.yaml`.

#### Core Infrastructure

| Service | Docker Compose | Helm/K8s dev |
|---|---|---|
| Zookeeper | ✅ | ✅ |
| Kafka (3-broker cluster) | ✅ (`kafka-1/2/3`) | ✅ (single `kafka` deployment) |
| Schema Registry | ✅ | ✅ |
| Schema init job | ✅ (`schema-init`) | ✅ (`register-schemas-job`) |
| MinIO | ✅ | ✅ |
| MinIO init | ✅ (`minio-init`) | ✅ (init container) |
| Postgres (snowflake-mimic) | ✅ | ✅ |

#### ODS Pipeline

| Service | Docker Compose | Helm/K8s dev |
|---|---|---|
| ODS source producer | ✅ (`ods-source`) | ✅ (`producer`) |
| ODS stream processor | ✅ (`ods-processor`) | ✅ (`processor`) |
| ODS Kafka Connect | ✅ (`ods-connect` + `ods-connect-init`) | ✅ (`odsConnect`) |

#### MDM / CDC Pipeline

| Service | Docker Compose | Helm/K8s dev |
|---|---|---|
| MDM MySQL source | ✅ (`mdm-source`) | ✅ (`mdm.source`) |
| Debezium Connect | ✅ (`dbz-connect` + `dbz-connect-init`) | ✅ (`dbzConnect`) |
| MDM Connect (JDBC sink) | ✅ (`mdm-connect` + `mdm-connect-init`) | ✅ (part of `mdm`) |
| MDM CDC curate | ✅ (`mdm-cdc-curate`) | ✅ (`mdm.cdcCurate`) |
| MDM RDS PG writer | ✅ (`mdm-rds-pg`) | ✅ (`mdm.rdsPg`) |

#### Lakehouse / Analytics

| Service | Docker Compose | Helm/K8s dev |
|---|---|---|
| Trino | ✅ | ✅ |
| Iceberg writer | ✅ | ✅ |
| dbt | ✅ (one-shot container) | ✅ (Kubernetes Job) |
| Airflow | ✅ | ✅ |

#### Observability

| Service | Docker Compose | Helm/K8s dev |
|---|---|---|
| Prometheus | ✅ | ✅ |
| Grafana | ✅ | ✅ |
| Blackbox exporter | ✅ | ❌ (disabled in dev) |
| Conduktor (Kafka UI) | ✅ (`conduktor` + `conduktor-db`) | ✅ |

#### Compose-only (no Helm equivalent)

| Service | Notes |
|---|---|
| `kafka-init` | One-shot topic creation; Helm uses an init mechanism inside the Kafka deployment |
| `openmetadata-db`, `openmetadata-search`, `openmetadata-server`, `openmetadata-ingestion` | Present in Compose via `--profile openmetadata`; Helm `openmetadata` block exists but is disabled in dev |

#### Key Differences

| Area | Docker Compose | Helm/K8s dev |
|---|---|---|
| Kafka topology | True 3-broker cluster — brokers are `kafka-1:19092`, `kafka-2:19093`, `kafka-3:19094` | Single broker deployment reachable as `kafka:9092` |
| OpenMetadata | Optional via `--profile openmetadata` | Present in chart but `enabled: false` in dev values |
| Blackbox exporter | Always started | Disabled in dev values |
| dbt execution model | Long-running container | Kubernetes Job (exits 0 on completion) |
| Schema history bootstrap (Debezium) | Must use `kafka-1:19092,...` — `kafka:9092` is not resolvable | Uses `kafka:9092` via `kafkaBootstrapServers` value |

## 9. CI/CD and GitOps Design

This section describes Git as source of truth, Argo CD reconciliation, and deployment verification flow.

- Source of truth:
  Git repository stores chart templates, environment values, and Argo CD applications.
- Delivery mechanism:
  Helm packages manifests; Argo CD reconciles cluster state to Git state.
- Promotion strategy:
  `dev -> qa -> prd` by controlled values/manifests progression.
- Operational safety:
  Health checks, logs, and validation scripts are used before promotion.

Diagram: GitOps delivery flowchart.

```mermaid
flowchart TD
  DEV[Engineer Updates Code and Values] --> PR[Pull Request and Review]
  PR --> MERGE[Merge to main]
  MERGE --> REPO[Git Repository State Updated]
  REPO --> ARGO[Argo CD Detects Drift]
  ARGO --> RENDER[Helm Render with Environment Values]
  RENDER --> APPLY[Apply Desired Manifests to Cluster]
  APPLY --> HEALTH[Argo CD Health and Sync Checks]
  HEALTH -->|Healthy| VERIFY[Run Architecture Validation Commands]
  HEALTH -->|Degraded| FIX[Revert Commit or Fix Values]
  VERIFY --> PROMOTE[Promote Same Pattern to QA then PRD]
```

Diagram: tooling validation flowchart.

```mermaid
flowchart LR
  A[Make MDM Flow Check] --> B[Docker Compose Config]
  A --> C[Helm Lint and Render]
  D[Make OpenMetadata Status] --> E[OpenMetadata Health]
  F[Make Ops Status] --> G[Runtime Endpoint Checks]
  H[Kubectl Get App and Pods] --> I[GitOps Runtime Parity Checks]
```

## 10. Non-Functional Considerations

### 10.1 Scalability

- Kafka partitions and consumer groups provide horizontal scaling for event processing.
- Flink topology can scale by task parallelism.
- dbt models can evolve to incremental patterns for larger volumes.

### 10.2 Reliability

- Durable Kafka topics allow replay and recovery.
- CDC stream preserves data-change history from master data source.
- Idempotent bootstrap/init jobs reduce operational fragility.

### 10.3 Observability

- Kafka UI for topic inspection.
- Prometheus/Grafana/Blackbox stack for metrics, dashboards, and endpoint probing in local and Kubernetes modes.
- Loki-backed log aggregation can be enabled in Kubernetes profile where configured.
- OpenMetadata ingestion workflow summaries provide metadata-plane observability for connector health and lineage freshness.
- Runbook-driven checks for pipeline health and model outputs.

### 10.4 Security (Demo vs Production)

Current local setup favors simplicity. Production hardening should include:

- Centralized secret management.
- TLS and authenticated Kafka client/broker traffic.
- Role-based access control for data stores and runtime services.

## 11. Data Cataloging and Observability Design

Data cataloging design:

- OpenMetadata is the metadata control plane for Trino, Postgres, dbt, Airflow, and Kafka.
- Connector workflows are versioned under `platform-services/metadata/openmetadata/workflows` and executed through Make targets.
- dbt lineage is derived from sanitized local artifacts (`manifest.json` and `run_results.json` under the OpenMetadata-compatible target path).
- Catalog validation requires connector test steps to pass (`GetQueries`, `CheckSchemaRegistry`) and workflow success rate to remain healthy.

Observability design:

- Runtime-plane observability: Prometheus scrapes services and Blackbox probes endpoint availability; Grafana provides dashboards.
- Metadata-plane observability: OpenMetadata ingestion summaries and connector test steps expose catalog ingestion health.
- Operational-plane observability: `make ops-status`, `make openmetadata-status`, and ingestion targets provide repeatable health checks.
- Alerting/SLO evolution path: promote current health checks into alert rules for ingestion failures, stale lineage, and endpoint downtime.

## 12. Architecture Decisions Summary

- Postgres is intentionally used as a local warehouse analog to mimic Snowflake-like SQL analytics workflows.
- The same architecture can target Redshift, Snowflake, BigQuery, or Databricks with adapter/profile and sink-integration changes rather than full redesign.
- Kafka plus Flink provides real-time event decomposition and processing.
- MinIO plus Trino now supports both a Trino-managed bridge from Postgres landing and a direct Kafka-to-Iceberg writer path for realtime lakehouse ingestion.
- dbt enforces ELT and medallion layer conventions with version-controlled SQL models.
- PySpark and Debezium integrate master data and CDC into analytical flows.
- Docker/Compose supports local speed; Kubernetes/Helm/Argo CD supports GitOps reproducibility.
- Java and Python are both first-class implementation languages based on service responsibilities.
- OpenMetadata is the unified metadata catalog surface and is a first-class platform component.
- Observability is a cross-cutting concern across runtime, metadata, and delivery operations.

## 13. Future Enhancements

- Enforce Schema Registry compatibility policies for Kafka topic evolution.
- Increase dbt test coverage (uniqueness, referential integrity, freshness).
- Add metadata freshness SLIs/SLOs and alerting for ingestion regressions.
- Externalize secrets and integrate enterprise identity controls.
- Add performance test suites for streaming and transformation workloads.
