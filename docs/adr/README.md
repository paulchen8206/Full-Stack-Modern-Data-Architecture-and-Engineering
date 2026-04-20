# Architecture Decision Records (ADR)

This folder tracks durable architecture decisions for the local modern data platform.

## Purpose

This section defines the purpose of this document.
Provide a durable decision log for architecture and operational design choices.

## Commands

This section defines the primary commands for this document.
No runtime commands are executed directly from this index; use linked ADR files and the runbook command sets. Shared target entrypoints are `make help` and `make validate`.

## Validation

This section defines the primary validation approach for this document.
Validate ADR relevance by ensuring referenced workflows and commands remain accurate in README and runbook.
Use `make help` to verify target discoverability and `make validate` to confirm baseline build/render checks pass.

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
When behavior and documentation diverge, review related ADRs first to determine intended design constraints.

## References

This section defines the primary cross-references for this document.

- [../architecture.md](../architecture.md)
- [../runbook.md](../runbook.md)
- [../../README.md](../../README.md)

Status values:

- Proposed: under discussion, not yet adopted
- Accepted: approved and currently used
- Superseded: replaced by a newer ADR
- Deprecated: still present for context, no longer recommended

## ADR Index

- [ADR-0001: Dual Local Runtime Modes (Compose and kind+Helm+Argo CD)](0001-dual-local-runtime-modes.md) - Accepted
- [ADR-0002: GitOps Reconciliation via Argo CD with Local Helm Escape Hatch](0002-gitops-with-helm-escape-hatch.md) - Accepted
- [ADR-0003: Trino-Centered Iceberg Query Path on MinIO](0003-trino-iceberg-query-path.md) - Accepted
- [ADR-0004: CDC-Based MDM Enrichment Flow](0004-cdc-based-mdm-enrichment-flow.md) - Accepted
- [ADR-0005: Unified Day-2 Operations Through Make Targets](0005-unified-day2-operations-make-targets.md) - Accepted
- [ADR-0006: Medallion Architecture with dbt for ELT Transformations](0006-medallion-architecture-with-dbt.md) - Accepted
- [ADR-0007: Airflow for Orchestration](0007-airflow-for-orchestration.md) - Accepted

## ADR Template

Use this structure for future decisions:

1. Title
2. Status
3. Date
4. Purpose
5. Commands
6. Validation
7. Troubleshooting
8. References
9. Context
10. Decision
11. Consequences
12. Alternatives considered
13. Detailed References
