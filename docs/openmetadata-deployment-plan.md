# OpenMetadata Deployment and Connector Plan (Compose Tailored)

## Purpose

This plan defines a practical, incremental OpenMetadata rollout for the current Docker Compose stack.
It is designed to integrate with Trino, Postgres warehouse, dbt, Airflow, and Kafka while minimizing disruption.

## Scope

In scope:

- OpenMetadata service deployment in Routine A (Compose)
- Connector workflows for Trino, Postgres, dbt, Airflow, and Kafka
- Phased rollout and validation gates

Out of scope:

- Production hardening (SSO, TLS, HA, backup policy)
- Kubernetes deployment manifests

## Current Stack Mapping

Existing services relevant to metadata ingestion:

- Trino query endpoint: `http://trino:8080` (host port `8086`)
- Postgres warehouse: `postgres:5432`
- Kafka broker: `kafka:9092`
- Airflow UI/API: `http://airflow:8080` (host port `8084`)
- dbt project path: `analytics/dbt`

## Target OpenMetadata Components (Compose)

Recommended additional services:

- `openmetadata-db`: metadata store (MySQL 8)
- `openmetadata-search`: search index (Elasticsearch 8)
- `openmetadata-server`: OpenMetadata API/UI
- `openmetadata-ingestion`: workflow runner for metadata ingestion

### Compose Service Blueprint (Sample)

Add this as a starting point to `docker-compose.yml` (adjust versions to your policy):

```yaml
  openmetadata-db:
    image: mysql:8.4
    environment:
      MYSQL_ROOT_PASSWORD: openmetadata_root
      MYSQL_DATABASE: openmetadata_db
      MYSQL_USER: openmetadata_user
      MYSQL_PASSWORD: openmetadata_pass
    ports:
      - "3307:3306"
    volumes:
      - openmetadata-db-data:/var/lib/mysql

  openmetadata-search:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.14.3
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - ES_JAVA_OPTS=-Xms1g -Xmx1g
    ports:
      - "9200:9200"
    volumes:
      - openmetadata-es-data:/usr/share/elasticsearch/data

  openmetadata-server:
    image: openmetadata/server:1.5.8
    depends_on:
      - openmetadata-db
      - openmetadata-search
    environment:
      OPENMETADATA_CLUSTER_NAME: local
      SERVER_HOST_API_URL: http://openmetadata-server:8585/api
      DB_DRIVER_CLASS: com.mysql.cj.jdbc.Driver
      DB_SCHEME: mysql
      DB_USE_SSL: "false"
      DB_HOST: openmetadata-db
      DB_PORT: "3306"
      OM_DATABASE: openmetadata_db
      DB_USER: openmetadata_user
      DB_USER_PASSWORD: openmetadata_pass
      ELASTICSEARCH_HOST: openmetadata-search
      ELASTICSEARCH_PORT: "9200"
      ELASTICSEARCH_SCHEME: http
    ports:
      - "8585:8585"

  openmetadata-ingestion:
    image: openmetadata/ingestion:1.5.8
    depends_on:
      - openmetadata-server
    entrypoint: ["/bin/bash", "-lc", "sleep infinity"]
    volumes:
      - ./metadata/openmetadata:/opt/openmetadata/metadata
```

Volumes (sample):

```yaml
volumes:
  openmetadata-db-data:
  openmetadata-es-data:
```

## Connector Workflow Files (Sample YAMLs)

Store workflow YAMLs under `metadata/openmetadata/workflows/`.

### 1) Trino Metadata Ingestion

File: `metadata/openmetadata/workflows/trino_ingestion.yaml`

```yaml
source:
  type: trino
  serviceName: trino-lakehouse
  serviceConnection:
    config:
      type: Trino
      hostPort: trino:8080
      username: analytics
      catalog: lakehouse
  sourceConfig:
    config:
      type: DatabaseMetadata
      includeTables: true
      includeViews: true
      schemaFilterPattern:
        includes:
          - streaming
          - demo

sink:
  type: metadata-rest
  config:
    api_endpoint: http://openmetadata-server:8585/api

airflowConfig:
  endPoint: http://openmetadata-server:8585
  pipelineName: trino_metadata_ingestion
```

### 2) Postgres Warehouse Metadata Ingestion

File: `metadata/openmetadata/workflows/postgres_ingestion.yaml`

```yaml
source:
  type: postgres
  serviceName: postgres-warehouse
  serviceConnection:
    config:
      type: Postgres
      hostPort: postgres:5432
      username: analytics
      password: analytics
      database: analytics
  sourceConfig:
    config:
      type: DatabaseMetadata
      includeTables: true
      schemaFilterPattern:
        includes:
          - landing
          - bronze
          - silver
          - gold

sink:
  type: metadata-rest
  config:
    api_endpoint: http://openmetadata-server:8585/api

airflowConfig:
  endPoint: http://openmetadata-server:8585
  pipelineName: postgres_metadata_ingestion
```

### 3) dbt Metadata and Lineage Ingestion

File: `metadata/openmetadata/workflows/dbt_ingestion.yaml`

```yaml
source:
  type: dbt
  serviceName: dbt-analytics
  serviceConnection:
    config:
      type: Dbt
      dbtConfigSource:
        dbtManifestFilePath: /opt/openmetadata/metadata/analytics/dbt/target/manifest.json
        dbtRunResultsFilePath: /opt/openmetadata/metadata/analytics/dbt/target/run_results.json
  sourceConfig:
    config:
      type: DBT
      dbtUpdateDescriptions: true
      includeTags: true

sink:
  type: metadata-rest
  config:
    api_endpoint: http://openmetadata-server:8585/api

airflowConfig:
  endPoint: http://openmetadata-server:8585
  pipelineName: dbt_lineage_ingestion
```

### 4) Airflow Pipeline Metadata Ingestion

File: `metadata/openmetadata/workflows/airflow_ingestion.yaml`

```yaml
source:
  type: airflow
  serviceName: airflow-orchestration
  serviceConnection:
    config:
      type: Airflow
      hostPort: http://airflow:8080
      username: admin
      password: admin
  sourceConfig:
    config:
      type: PipelineMetadata
      includeLineage: true

sink:
  type: metadata-rest
  config:
    api_endpoint: http://openmetadata-server:8585/api

airflowConfig:
  endPoint: http://openmetadata-server:8585
  pipelineName: airflow_pipeline_ingestion
```

### 5) Kafka Topic Metadata Ingestion

File: `metadata/openmetadata/workflows/kafka_ingestion.yaml`

```yaml
source:
  type: kafka
  serviceName: kafka-streaming
  serviceConnection:
    config:
      type: Kafka
      bootstrapServers: kafka:9092
      schemaRegistryURL: ""
  sourceConfig:
    config:
      type: MessagingMetadata
      topicFilterPattern:
        includes:
          - raw_sales_orders
          - sales_order
          - sales_order_line_item
          - customer_sales
          - mdm_customer
          - mdm_product

sink:
  type: metadata-rest
  config:
    api_endpoint: http://openmetadata-server:8585/api

airflowConfig:
  endPoint: http://openmetadata-server:8585
  pipelineName: kafka_topic_ingestion
```

## Rollout Order and Gates

### Phase 0: Prerequisites

- Confirm stack health: `make routine-a-ops`
- Confirm Trino health: `make trino-smoke`
- Ensure dbt artifacts exist (`manifest.json`, `run_results.json`) by running `make dbt-run`

Gate to continue:

- Routine A services healthy
- Trino query path working

### Phase 1: OpenMetadata Platform Bring-Up

- Add OpenMetadata services to Compose
- Start services:

```bash
docker compose up -d openmetadata-db openmetadata-search openmetadata-server openmetadata-ingestion
```

- Open UI at `http://localhost:8585`

Gate to continue:

- OpenMetadata UI/API reachable
- Search backend healthy

### Phase 2: Foundational Metadata

- Run Trino and Postgres ingestion workflows first
- Verify datasets are discoverable and searchable

Gate to continue:

- `lakehouse` and `warehouse` entities visible
- Key schemas/tables present

### Phase 3: Lineage Enrichment

- Run dbt ingestion
- Run Airflow ingestion
- Validate table-level and pipeline lineage consistency

Gate to continue:

- Lineage visible from landing to bronze/silver/gold
- Airflow DAG metadata visible for `dbt_warehouse_schedule`

### Phase 4: Streaming Metadata

- Run Kafka ingestion
- Validate topic inventory and ownership tagging

Gate to continue:

- Core streaming topics discoverable
- Topic-to-dataset lineage quality acceptable

### Phase 5: Operationalize

- Add scheduled ingestion runs (hourly metadata, daily lineage refresh)
- Define owners and tags for critical assets
- Add runbook section for ingestion troubleshooting

Gate to finish:

- Ingestion schedules stable for one week
- No repeated connector failures

## Example Workflow Execution Commands

From inside `openmetadata-ingestion` container:

```bash
metadata ingest -c /opt/openmetadata/metadata/workflows/trino_ingestion.yaml
metadata ingest -c /opt/openmetadata/metadata/workflows/postgres_ingestion.yaml
metadata ingest -c /opt/openmetadata/metadata/workflows/dbt_ingestion.yaml
metadata ingest -c /opt/openmetadata/metadata/workflows/airflow_ingestion.yaml
metadata ingest -c /opt/openmetadata/metadata/workflows/kafka_ingestion.yaml
```

## Risks and Mitigations

- Risk: connector drift from local auth/network changes
  - Mitigation: keep workflow YAMLs in Git and validate with `docker compose config`
- Risk: weak lineage because of naming inconsistency
  - Mitigation: enforce naming conventions across Trino catalogs, dbt models, and Airflow tasks
- Risk: dbt artifact path mismatch in ingestion container
  - Mitigation: mount `analytics/dbt` into ingestion container read-only and validate before run

## Success Criteria

- One UI for searchable metadata across lakehouse, warehouse, pipelines, and topics
- Working lineage from source ingestion to transformed analytics layers
- Repeatable connector workflows under source control
- Clear ownership and tags on critical datasets and topics
