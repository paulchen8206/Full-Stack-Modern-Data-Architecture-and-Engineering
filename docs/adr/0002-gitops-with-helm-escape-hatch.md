# ADR-0002: GitOps Delivery with Argo CD and Local Helm Validation Escape Hatch

- Status: Accepted
- Date: 2026-04-18

## 1. Summary

Argo CD is the reconciliation authority for Kubernetes runtime state, with an explicit local Helm validation escape hatch for rapid chart debugging.

## 2. Context

Pure GitOps flows are reproducible but can slow iterative chart debugging. Pure local Helm flows are faster but can introduce source-of-truth drift.

The platform needs both:

- Git-defined desired state
- practical local chart iteration before commit

## 3. Decision

Use Argo CD as the default delivery mechanism for environment state. Allow direct local Helm rendering and validation only as a temporary debugging path.

Any local Helm-only change must be committed and reconciled through Argo CD.

## 4. Operational References

Primary GitOps path:

- kubectl apply -f cicd/argocd/dev.yaml
- kubectl -n argocd get application realtime-dev

Local validation path:

- helm dependency build cicd/charts/realtime-app
- helm template realtime-dev cicd/charts/realtime-app -f cicd/k8s/helm/values/values-dev.yaml

## 5. Validation

Validation is successful when:

- Argo CD application status is healthy and synced
- rendered Helm manifests are valid for the selected values file
- runtime workloads in namespace realtime-dev are healthy

## 6. Consequences

Positive outcomes:

- reproducible desired-state deployment model
- faster local troubleshooting for chart logic

Trade-offs:

- temporary drift risk when using local Helm path
- additional process discipline required to converge back to GitOps

## 7. Alternatives Considered

- Argo CD only with no local Helm path: rejected due to slow debug loops
- local Helm only with no Argo CD: rejected due to weaker reconciliation guarantees

## 8. References

- [../runbook.md](../runbook.md)
- [../../cicd/argocd/dev.yaml](../../cicd/argocd/dev.yaml)
- [../../cicd/charts/realtime-app](../../cicd/charts/realtime-app)
