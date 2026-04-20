# ADR-0009: Unified Day-2 Operations Interface Through Make Targets

- Status: Accepted
- Date: 2026-04-18

## Purpose

This section defines the purpose of this document.
Record the decision to standardize day-2 operations through Make targets across both local runtime modes.

## Commands

This section defines the primary commands for this document.
Primary commands related to this decision:

- `make routine-a-ops`
- `make routine-b-ops`
- `make trino-smoke`
- `make trino-smoke-dev`
- Shared targets: `make help`, `make validate`

## Validation

This section defines the primary validation approach for this document.
Validate this decision by confirming Make targets execute repeatable status, dataflow, and smoke checks for both routines.
Use `make help` to verify target discoverability and `make validate` to confirm baseline build/render checks pass.

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
If operational behavior drifts, troubleshoot target wrappers and underlying scripts together to keep a single command interface.

## References

This section defines the primary cross-references for this document.

- [../architecture.md](../architecture.md)
- [../runbook.md](../runbook.md)
- [../../Makefile](../../Makefile)

## Context

Operational workflows were historically fragmented across direct Docker, kubectl, and helper scripts. This made routine checks harder to reproduce and increased doc drift.

## Decision

Use Make targets as the normalized operational interface for day-2 checks and maintenance tasks across both local runtime modes.

Key examples:

- Routine A: `make routine-a-ops`
- Routine B: `make routine-b-ops`
- Trino smoke checks: `make trino-smoke` and `make trino-smoke-dev`
- Iceberg streaming checks: `make iceberg-streaming-smoke` and `make iceberg-streaming-smoke-dev`
- Shared discovery/validation checks: `make help` and `make validate`

## Consequences

- Positive:
  - Repeatable operations with less command drift
  - Easier onboarding and runbook consistency
  - Clear architecture-to-operations mapping in documentation
- Trade-offs:
  - Makefile maintenance becomes part of architecture governance
  - Underlying script behavior changes must be reflected in wrapper targets

## Alternatives considered

- Script-only interface: rejected due to discoverability and consistency gaps
- Ad hoc command guidance in docs only: rejected due to low repeatability

## Detailed References

- ../architecture.md
- ../runbook.md
- ../../Makefile
