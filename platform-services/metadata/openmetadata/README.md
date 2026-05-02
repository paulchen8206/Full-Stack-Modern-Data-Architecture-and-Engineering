# OpenMetadata Workflows

This folder contains OpenMetadata ingestion workflow definitions for the local Compose stack.

Workflow files:

- workflows/trino_ingestion.yaml
- workflows/postgres_ingestion.yaml
- workflows/dbt_ingestion.yaml
- workflows/airflow_ingestion.yaml
- workflows/kafka_ingestion.yaml

Quick start:

1. Start services:
   make openmetadata-up
2. Check status:
   make openmetadata-status
3. Run ingestion workflows:
   make openmetadata-ingest-trino
   make openmetadata-ingest-postgres
   make openmetadata-ingest-dbt
   make openmetadata-ingest-airflow
   make openmetadata-ingest-kafka
