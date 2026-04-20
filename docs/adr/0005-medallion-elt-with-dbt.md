# ADR-0005: Medallion ELT Modeling with dbt

- Status: Accepted
- Date: 2026-04-18

## Purpose

This section defines the purpose of this document.
Record the decision to implement a medallion layer architecture (landing → bronze → silver → gold) using dbt as the ELT transformation tool on top of a Postgres-backed warehouse for local development.

## Commands

This section defines the primary commands for this document.
Primary commands related to this decision:

- `make dbt-run`
- `make verify-warehouse`
- `make verify-dbt-relations`
- `make airflow-dbt-reboot`
- `make airflow-dbt-check-dev`
- Shared targets: `make help`, `make validate`

## Validation

This section defines the primary validation approach for this document.
Validate this decision by confirming all four medallion layers contain expected row counts and dbt materializations complete without errors (`PASS=11 WARN=0 ERROR=0`).
Use `make help` to verify target discoverability and `make validate` to confirm baseline build/render checks pass.

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
If bronze, silver, or gold layers are empty while landing has rows, rerun dbt before debugging upstream services. Check schema privileges and macro behavior for `generate_schema_name.sql`.

## References

This section defines the primary cross-references for this document.

- [../architecture.md](../architecture.md)
- [../runbook.md](../runbook.md)
- [../../analytics/dbt/dbt_project.yml](../../analytics/dbt/dbt_project.yml)

## Context

The platform requires a repeatable, environment-portable analytics transformation layer that produces curated dimension tables, fact tables, and aggregated presentation tables from raw landing data.

A single-layer approach would conflate ingestion quality concerns with presentation concerns. A flat SQL script approach would not support incremental development, testing, or adapter portability.

## Decision

Implement a four-layer medallion architecture using dbt:

- **Landing**: raw data loaded by Kafka Connect JDBC sink and PySpark MDM sync; not managed by dbt.
- **Bronze**: dbt staging views aligned to source table contracts (`stg_*` models in `analytics/dbt/models/bronze/`).
- **Silver**: dbt dimension and fact tables with business keys and conformed semantics (`dim_*`, `fact_*` models in `analytics/dbt/models/silver/`).
- **Gold**: dbt aggregated presentation tables for analytics consumption (`gold_*` models in `analytics/dbt/models/gold/`).

Use `analytics/dbt/macros/generate_schema_name.sql` to disable dbt's default `target_schema + custom_schema` concatenation so models materialize directly in `bronze`, `silver`, and `gold` rather than `public_bronze`, etc.

Schedule recurring dbt runs through Airflow (`airflow/dags/dbt_warehouse_schedule.py`, DAG ID `dbt_warehouse_schedule`, every 5 minutes).

## Consequences

- Positive:
  - Clear layer separation makes data quality issues easier to isolate
  - dbt adapter portability supports Redshift, Snowflake, BigQuery, and Databricks without changing model SQL
  - Airflow scheduling decouples refresh cadence from deployment operations
  - Idempotent `dbt run` is safe to re-execute at any time
- Trade-offs:
  - The `generate_schema_name` macro override must be present in every deployment path (Compose and Kubernetes Helm); missing it causes models to materialize in wrong schemas
  - Postgres is a warehouse simulation; full OLAP query performance requires a cloud warehouse adapter

## Alternatives considered

- Single schema with raw plus transformed tables: rejected because it mixes ingestion state with analytics state and prevents independent iteration
- Direct SQL scripts without dbt: rejected because it loses adapter portability, incremental materialization, and test/documentation support
- dbt Cloud: out of scope for local demo; the local runner pattern is kept identical so migration to dbt Cloud is additive only

## Detailed References

- `analytics/dbt/models/bronze/` — staging views
- `analytics/dbt/models/silver/` — dimension and fact tables
- `analytics/dbt/models/gold/` — presentation aggregates
- `analytics/dbt/macros/generate_schema_name.sql` — schema name macro override
- `airflow/dags/dbt_warehouse_schedule.py` — Airflow DAG for scheduled refresh
