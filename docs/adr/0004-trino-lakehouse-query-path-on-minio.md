# ADR-0004: Trino Lakehouse Query Path on MinIO

- Status: Accepted
- Date: 2026-04-18

## Purpose

This section defines the purpose of this document.
Record the decision to center the local lakehouse query path on Trino with Iceberg-compatible tables on MinIO.

## Commands

This section defines the primary commands for this document.
Primary commands related to this decision:

- `make trino-smoke`
- `make trino-bootstrap-lakehouse`
- `make trino-rebuild-lakehouse`
- `make iceberg-streaming-smoke`
- Shared targets: `make help`, `make validate`

## Validation

This section defines the primary validation approach for this document.
Validate this decision by confirming Trino health and by verifying non-zero row counts in streaming Iceberg tables.
Use `make help` to verify target discoverability and `make validate` to confirm baseline build/render checks pass.

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
If query, metastore, or writer behavior fails, use Trino and Iceberg smoke checks before changing model or connector logic.

## References

This section defines the primary cross-references for this document.

- [../architecture.md](../architecture.md)
- [../../README.md](../../README.md)

## Context

The platform needs a local lakehouse query layer with open-table-format semantics while staying compatible with MinIO for development.

## Decision

Use Trino as the query engine and operational entry point for Iceberg-compatible tables on MinIO.

Adopt two complementary data paths:

- Bridge path: materialize Iceberg tables from Postgres `landing` data
- Streaming path: write Kafka topics directly to Iceberg through `iceberg-writer`

## Consequences

- Positive:
  - SQL-accessible lakehouse layer during local development
  - Supports both bootstrap and streaming ingestion patterns
  - Keeps future cloud migration options open
- Trade-offs:
  - Additional operational complexity for metastore/schema compatibility
  - Requires robust smoke checks to catch catalog/topic drift early

## Alternatives considered

- Postgres warehouse only: rejected because it does not demonstrate lakehouse query behavior
- Object storage sink without query layer: rejected because it limits validation and analytics usage

## Detailed References

- ../architecture.md
- ../../README.md
