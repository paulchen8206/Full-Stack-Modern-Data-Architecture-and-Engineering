# ADR-0002: GitOps Reconciliation via Argo CD with Local Helm Escape Hatch

- Status: Accepted
- Date: 2026-04-18

## Purpose

This section defines the purpose of this document.
Record the decision to use Argo CD as the GitOps reconciler while retaining direct local Helm commands for rapid validation.

## Commands

This section defines the primary commands for this document.
Primary commands related to this decision:

- `kubectl apply -f argocd/dev.yaml`
- `make helm-reboot-dev`
- `make helm-health-dev`
- Shared targets: `make help`, `make validate`

## Validation

This section defines the primary validation approach for this document.
Validate this decision by confirming Argo CD sync health and by verifying local Helm changes can be tested before commit and sync.
Use `make help` to verify target discoverability and `make validate` to confirm baseline build/render checks pass.

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
If GitOps and local Helm behavior diverge, re-align by committing chart changes and reconciling through Argo CD.

## References

This section defines the primary cross-references for this document.

- [../runbook.md](../runbook.md)
- [../../argocd/dev.yaml](../../argocd/dev.yaml)

## Context

Routine B uses Argo CD to reconcile Helm state from Git. During local chart iteration, immediate validation is still needed before committing and syncing via Argo CD.

## Decision

Use Argo CD as the source-of-truth reconciler for Routine B, while keeping direct local Helm commands as an explicit temporary escape hatch for fast validation.

Primary commands:

- `kubectl apply -f argocd/dev.yaml`
- `make helm-reboot-dev`
- `make helm-health-dev`
- Shared targets: `make help`, `make validate`

## Consequences

- Positive:
  - Preserves GitOps discipline for declared environments
  - Keeps local chart debugging fast and practical
- Trade-offs:
  - Risk of temporary drift if local Helm changes are not committed and re-synced through Argo CD
  - Requires explicit runbook guidance on when to use each path

## Alternatives considered

- Argo CD only with no direct Helm path: rejected due to slow local troubleshooting loops
- Helm only with no Argo CD reconciliation: rejected because it weakens GitOps validation and promotion workflow

## Detailed References

- ../runbook.md
- ../../argocd/dev.yaml
