# ADR-0009: Unified Metadata Catalog with OpenMetadata Across Trino, dbt, Airflow, and Kafka

- Status: Proposed
- Date: 2026-04-20

## Purpose

This section defines the purpose of this document.
Record the decision to evaluate and adopt OpenMetadata as a unified metadata catalog and lineage surface for the local modern data platform.

## Commands

This section defines the primary commands for this document.
Primary commands related to this decision:

- `make trino-smoke`
- `./scripts/trino-sql.sh "SHOW CATALOGS"`
- `docker compose up -d openmetadata-server openmetadata-ingestion`
- Shared targets: `make help`, `make validate`

## Validation

This section defines the primary validation approach for this document.
Validate this decision by confirming OpenMetadata can ingest metadata and lineage from Trino, Postgres warehouse catalogs, dbt artifacts, Airflow DAGs, and Kafka topics.
Validation is successful when key entities are discoverable in the catalog UI and lineage paths match known architecture flows.

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
If entities do not appear, validate connector credentials and network routing first, then check ingestion workflow logs.
If lineage is incomplete, verify naming consistency across Trino catalogs, dbt relation naming, and Airflow DAG/task metadata.

## References

This section defines the primary cross-references for this document.

- [0004-trino-lakehouse-query-path-on-minio.md](0004-trino-lakehouse-query-path-on-minio.md)
- [0005-medallion-elt-with-dbt.md](0005-medallion-elt-with-dbt.md)
- [0006-airflow-scheduled-dbt-orchestration.md](0006-airflow-scheduled-dbt-orchestration.md)
- [0008-unified-dbeaver-trino-query-surface.md](0008-unified-dbeaver-trino-query-surface.md)
- [../runbook.md](../runbook.md)
- [../openmetadata-deployment-plan.md](../openmetadata-deployment-plan.md)
- [../../docker-compose.yml](../../docker-compose.yml)

## Context

The current platform has strong execution components and query paths but metadata is spread across tool-specific interfaces.

Current state pain points:

- Table and topic discovery is distributed across Trino, dbt artifacts, Kafka UI, and Airflow UI.
- Cross-system lineage requires manual correlation between docs and multiple operational dashboards.
- Ownership, descriptions, and governance tags are not centralized.

The platform already standardized a unified query surface through Trino (ADR-0004 and ADR-0008). A metadata control plane is the next dependency-aligned step for governance and discoverability.

## Decision

Adopt OpenMetadata as the unified metadata catalog layer, integrated incrementally with existing services.

Scope of integration:

- Trino for lakehouse and warehouse metadata discovery
- Postgres warehouse metadata through Trino and direct service ingestion where needed
- dbt metadata and lineage from dbt artifacts
- Airflow pipeline metadata and execution lineage
- Kafka topic metadata for streaming context

Rollout approach:

1. Deploy OpenMetadata server and ingestion runner in Compose.
2. Connect Trino and validate core table discovery.
3. Add dbt and Airflow ingestion for lineage enrichment.
4. Add Kafka ingestion for topic-level visibility.
5. Harden ownership, tags, and glossary conventions.

## Consequences

- Positive:
  - Single discovery surface for datasets, pipelines, and topics
  - Improved lineage visibility from ingestion through transformation and consumption
  - Better onboarding and governance through centralized metadata
- Trade-offs:
  - Additional service and ingestion workflows to operate
  - Requires naming discipline to keep lineage accurate
  - Integration quality depends on connector and artifact availability

## Alternatives considered

- Continue with tool-specific UIs only: rejected due to fragmented discovery and weak cross-system lineage
- Build custom metadata index scripts: rejected due to maintenance overhead and limited feature depth
- SaaS catalog only: deferred for local-first parity and reproducibility reasons

## Detailed References

- `docker-compose.yml` — local service topology where OpenMetadata components are added
- `trino/etc/catalog/` — Trino catalogs used as primary metadata source
- `analytics/dbt/target/manifest.json` and `analytics/dbt/target/run_results.json` — dbt artifact sources for lineage
- `airflow/dags/dbt_warehouse_schedule.py` — Airflow DAG metadata source
- `connect/connector-configs/` — Kafka and connector context for streaming metadata
