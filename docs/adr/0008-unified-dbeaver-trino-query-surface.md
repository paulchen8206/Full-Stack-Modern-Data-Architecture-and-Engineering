# ADR-0008: Unified DBeaver and Trino Query Surface for Lakehouse and Warehouse Data

- Status: Accepted
- Date: 2026-04-20

## Purpose

This section defines the purpose of this document.
Consolidate a single analyst-facing SQL entrypoint by using DBeaver with Trino to query diversified datasets (Iceberg, Parquet-backed lakehouse tables, and Postgres warehouse schemas), while aligning with ADR-0004.

## Commands

This section defines the primary commands for this document.
Primary commands related to this decision:

- `make trino-smoke`
- `./scripts/trino-sql.sh "SHOW CATALOGS"`
- `./scripts/trino-sql.sh "SHOW SCHEMAS FROM lakehouse"`
- `./scripts/trino-sql.sh "SHOW SCHEMAS FROM warehouse"`
- `./scripts/trino-sql.sh "SELECT * FROM lakehouse.streaming.customer_sales LIMIT 10"`
- `./scripts/trino-sql.sh "SELECT * FROM warehouse.landing.customer_sales LIMIT 10"`
- Shared targets: `make help`, `make validate`

## Validation

This section defines the primary validation approach for this document.
Validate this decision by confirming one Trino endpoint can query all intended catalogs and dataset types.

Validation checks:

- Trino health passes (`make trino-smoke`)
- `SHOW CATALOGS` includes `lakehouse` and `warehouse`
- Iceberg queries succeed in `lakehouse.*`
- Postgres warehouse queries succeed in `warehouse.*`
- Parquet-backed lakehouse tables are queryable via Trino in the Iceberg catalog path

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
If DBeaver connects but datasets are missing, first verify Trino catalogs from the shell using `SHOW CATALOGS`.
If lakehouse tables are missing, run bootstrap/sync workflows from ADR-0004 (`make trino-bootstrap-lakehouse`, `make trino-sync-lakehouse`, `make iceberg-streaming-smoke`).
If an additional Postgres catalog is needed (for example `warehouse2`), add `trino/etc/catalog/<catalog>.properties`, restart Trino, and re-check catalogs.

## References

This section defines the primary cross-references for this document.

- [0004-trino-lakehouse-query-path-on-minio.md](0004-trino-lakehouse-query-path-on-minio.md)
- [../runbook.md](../runbook.md)
- [../../README.md](../../README.md)
- [../../trino/etc/catalog/lakehouse.properties](../../trino/etc/catalog/lakehouse.properties)
- [../../trino/etc/catalog/warehouse.properties](../../trino/etc/catalog/warehouse.properties)

## Context

Before this decision, users often switched between multiple clients and connection styles to inspect warehouse and lakehouse data.

That fragmented workflow increased onboarding time and made cross-domain analysis harder:

- Iceberg and warehouse data were mentally separated by tooling
- Query validation often required shell scripts first and GUI exploration second
- Optional extra catalogs (for example, an additional Postgres catalog) were not consistently treated as part of one SQL surface

ADR-0004 already established Trino as the Iceberg query path. The remaining gap was a consistent user-facing query client pattern for diversified datasets.

## Decision

Adopt DBeaver as the unified SQL client, with Trino as the single query endpoint for local analytics exploration.

Key design choices:

- Keep Trino as the consolidation layer (consistent with ADR-0004)
- Use one DBeaver Trino connection to `localhost:8086`
- Query lakehouse and warehouse datasets through catalogs rather than separate client connections
- Treat Parquet-backed data as part of the Trino lakehouse path (Iceberg table storage format is PARQUET)
- Preserve CLI parity via `scripts/trino-sql.sh` for repeatable automation and troubleshooting

DBeaver connection baseline:

- Driver: Trino
- Host: `localhost`
- Port: `8086`
- Catalog: `lakehouse` (default; switch catalog per query as needed)
- Schema: `streaming` (default example)
- Authentication: none for local profile unless environment policy changes

## Consequences

- Positive:
  - One SQL client entrypoint for cross-catalog analysis
  - Lower onboarding complexity for analysts and engineers
  - Better consistency between UI-driven and scripted validation paths
  - Clear extension model for additional catalogs (including optional second Postgres catalogs)
- Trade-offs:
  - DBeaver behavior now depends on Trino catalog health rather than direct database connectivity
  - Query performance troubleshooting must consider Trino execution plans and connector behavior
  - Teams must maintain catalog naming conventions to avoid confusion in multi-catalog workspaces

## Alternatives considered

- Separate DBeaver connections per source (direct Postgres plus separate lakehouse tooling): rejected because it fragments query workflows and weakens governance through a single SQL layer
- Trino CLI only (`./scripts/trino-sql.sh`) without GUI standardization: rejected because exploratory analytics and schema browsing are slower for many users
- Direct object-store inspection for Parquet files: rejected because it bypasses SQL governance and does not provide consistent relational semantics

## Detailed References

- `docs/adr/0004-trino-lakehouse-query-path-on-minio.md` — baseline decision for Trino-centered Iceberg path
- `trino/etc/catalog/lakehouse.properties` — Iceberg catalog and PARQUET table format configuration
- `trino/etc/catalog/warehouse.properties` — Postgres warehouse catalog configuration
- `docs/runbook.md` — catalog onboarding and optional second-catalog workflow
- `scripts/trino-sql.sh` — script-based query path used for validation and troubleshooting
