# Architecture Decision Records (ADR)

This directory contains the canonical architecture decisions for this repository.

## Purpose

The ADR set records why key technical decisions were made, what was selected, and which alternatives were rejected.

## Status Legend

- Proposed: candidate decision, not yet adopted
- Accepted: approved and in active use
- Superseded: replaced by a newer ADR
- Deprecated: retained for history but no longer recommended

## ADR Set

- [ADR-0001: Dual Local Runtime Strategy (Compose and kind plus Helm plus Argo CD)](0001-dual-local-runtime-modes.md) - Accepted
- [ADR-0002: GitOps Delivery with Argo CD and Local Helm Validation Escape Hatch](0002-gitops-with-helm-escape-hatch.md) - Accepted
- [ADR-0003: CDC-Driven MDM Master Data Propagation](0003-cdc-driven-mdm-master-data-propagation.md) - Accepted
- [ADR-0004: Trino Lakehouse Query Path on MinIO](0004-trino-lakehouse-query-path-on-minio.md) - Accepted
- [ADR-0005: Medallion ELT Modeling with dbt](0005-medallion-elt-with-dbt.md) - Accepted
- [ADR-0006: Airflow-Scheduled dbt Orchestration](0006-airflow-scheduled-dbt-orchestration.md) - Accepted
- [ADR-0007: Platform Observability Stack with Prometheus, Grafana, and Blackbox Exporter](0007-observability-stack-prometheus-grafana-blackbox.md) - Accepted
- [ADR-0008: Unified DBeaver and Trino Query Surface](0008-unified-dbeaver-trino-query-surface.md) - Accepted
- [ADR-0009: Unified Metadata Catalog with OpenMetadata](0009-openmetadata-unified-metadata-catalog.md) - Proposed
- [ADR-0010: Unified Day-2 Operations Interface Through Make Targets](0010-unified-day2-operations-make-targets.md) - Accepted

## Standard ADR Structure

Each ADR in this directory follows the same title-level organization:

1. Summary
2. Context
3. Decision
4. Operational References
5. Validation
6. Consequences
7. Alternatives Considered
8. References

## Maintenance Rules

- Keep decisions implementation-aligned with [../readme.md](../readme.md), [../architecture.md](../architecture.md), [../runbook.md](../runbook.md), and [../../Makefile](../../Makefile).
- If runtime commands change, update affected ADRs in the same pull request.
- Keep ADR language decision-oriented and avoid turning ADRs into runbooks.

## Related Docs

- [../readme.md](../readme.md)
- [../architecture.md](../architecture.md)
- [../runbook.md](../runbook.md)
