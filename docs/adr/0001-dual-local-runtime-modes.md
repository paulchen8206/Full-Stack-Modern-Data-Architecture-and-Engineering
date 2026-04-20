# ADR-0001: Local Runtime Strategy with Compose and kind+Helm+Argo CD

- Status: Accepted
- Date: 2026-04-18

## Purpose

This section defines the purpose of this document.
Record the decision to support both Compose and kind plus Helm plus Argo CD as first-class local runtime modes.

## Commands

This section defines the primary commands for this document.
Primary commands related to this decision:

- `make routine-a-ops`
- `make routine-b`
- `make routine-b-ops`
- Shared targets: `make help`, `make validate`

## Validation

This section defines the primary validation approach for this document.
Validate this decision by confirming both routines remain operational and documented with matched day-2 workflows.
Use `make help` to verify target discoverability and `make validate` to confirm baseline build/render checks pass.

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
If one routine drifts from the other in behavior or docs, resolve command and runbook parity before adding new routine-specific logic.

## References

This section defines the primary cross-references for this document.

- [../runbook.md](../runbook.md)
- [../../README.md](../../README.md)

## Context

The project needs a fast inner loop for local development and a Kubernetes/GitOps loop that mirrors production-style operations.

A single runtime mode cannot optimize both developer speed and deployment parity.

## Decision

Support two first-class local runtime modes:

- Routine A: Docker Compose for fast local iteration
- Routine B: kind + Helm + Argo CD for Kubernetes and GitOps simulation

Both modes are treated as supported paths, with matched day-2 operation targets.

## Consequences

- Positive:
  - Faster feature iteration in Compose
  - Better deployment parity testing in kind/Argo CD
  - Lower friction for onboarding teams with different workflow needs
- Trade-offs:
  - Duplicate operational surface area
  - Ongoing requirement to keep docs and commands aligned across both routines

## Alternatives considered

- Compose only: rejected because it does not validate cluster/GitOps behavior
- Kubernetes only: rejected because local development loop becomes slower for frequent code changes

## Detailed References

- ../runbook.md
- ../../README.md
