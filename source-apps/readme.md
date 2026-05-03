# Source Applications

This sub-project contains the upstream source services that generate and own initial data for the platform.

## Overview

The source applications are the starting point of the data pipeline. They publish transactional events and maintain master data that downstream streaming, CDC, lakehouse, and analytics services consume.

## Applications

- ods_source
  - Python producer service for sales events
  - Publishes composite sales messages to the raw_sales_orders Kafka topic
  - Drives the realtime stream-processing pipeline

- mdm-source
  - MySQL-based master data source simulator
  - Owns customer360, product_master, and mdm_date tables
  - Serves as the upstream system for Debezium CDC capture

## Project Structure

- ods_source/
  - app/
  - Dockerfile
  - pyproject.toml
- mdm-source/
  - sql/
  - Dockerfile
  - readme.md

## Dataflow Responsibilities

Diagram: source applications pipeline (left to right).

```mermaid
flowchart LR
  subgraph S[Sources]
    APP1[ODS Source]
    APP2[MDM Source MySQL]
  end

  subgraph P[Pipeline]
    K[(Kafka Raw Topic: raw_sales_orders)]
    DBZ[Debezium CDC]
    PROC[ODS Processor]
    MDMCDC[MDM CDC Curate]
    SPARK[MDM PySpark Sync]
    CONNECT[Kafka Connect sinks]
    IWR[Iceberg Writer via Trino]
  end

  subgraph T[Targets]
    T1[(Kafka normalized topics)]
    T2[(Kafka Curated MDM Topics)]
    T3[(Postgres Landing)]
    T4[(MinIO Raw Objects)]
    T5[(Iceberg Tables on MinIO)]
    T6[dbt and Airflow Analytics]
  end

  APP1 --> K
  K --> PROC
  PROC --> T1
  T1 --> CONNECT
  CONNECT --> T3
  CONNECT --> T4
  T1 --> IWR
  IWR --> T5

  APP2 --> DBZ
  DBZ --> K
  K --> MDMCDC
  MDMCDC --> T2
  T2 --> CONNECT
  APP2 --> SPARK
  SPARK --> T3

  T3 --> T6
  T5 --> T6
```

1. ods_source produces raw sales events to Kafka.
2. mdm-source stores and updates master data in MySQL.
3. Debezium captures mdm-source table changes and emits CDC topics.
4. Downstream processing applications and connectors transform and land source data into Postgres, MinIO, and Iceberg targets.

## Usage

From repository root, use the standard routine entrypoints:

```bash
make compose-up
make mdm-status
make mdm-topics-check
```

For app-specific behavior and configuration, see each subfolder README.

## Requirements

- Docker Desktop for local runtime
- Kafka and MySQL services available through the platform stack

## References

- ../compose.yml
- ../docs/architecture.md
- ../docs/runbook.md
