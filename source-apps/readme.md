# Source Applications

This sub-project contains the upstream source services that generate and own initial data for the platform.

## Overview

The source applications are the starting point of the data pipeline. They publish transactional events and maintain master data that downstream streaming, CDC, lakehouse, and analytics services consume.

## Applications

- sales_order_source
  - Python producer service for sales events
  - Publishes composite sales messages to the raw_sales_orders Kafka topic
  - Drives the realtime stream-processing pipeline

- mdm-source
  - MySQL-based master data source simulator
  - Owns customer360, product_master, and mdm_date tables
  - Serves as the upstream system for Debezium CDC capture

## Project Structure

- sales_order_source/
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
    APP1[sales_order_source]
    APP2[mdm-source MySQL]
  end

  subgraph P[Pipeline]
    K[(Kafka raw topic raw_sales_orders)]
    DBZ[Debezium CDC]
    PROC[sales_order_processor]
    MDMCDC[mdm-cdc-producer]
    SPARK[mdm-pyspark-sync]
    CONNECT[Kafka Connect sinks]
    IWR[iceberg-writer via Trino]
  end

  subgraph T[Targets]
    T1[(Kafka normalized topics)]
    T2[(Kafka curated MDM topics)]
    T3[(Postgres landing)]
    T4[(MinIO raw objects)]
    T5[(Iceberg tables on MinIO)]
    T6[dbt and Airflow analytics]
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

1. sales_order_source produces raw sales events to Kafka.
2. mdm-source stores and updates master data in MySQL.
3. Debezium captures mdm-source table changes and emits CDC topics.
4. Downstream processing applications and connectors transform and land source data into Postgres, MinIO, and Iceberg targets.

## Usage

From repository root, use the standard routine entrypoints:

```bash
make docker-compose-up
make mdm-status
make mdm-topics-check
```

For app-specific behavior and configuration, see each subfolder README.

## Requirements

- Docker Desktop for local runtime
- Kafka and MySQL services available through the platform stack

## References

- ../docker-compose.yml
- ../docs/architecture.md
- ../docs/runbook.md
