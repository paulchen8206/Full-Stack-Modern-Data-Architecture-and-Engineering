# CI/CD and GitOps

This sub-project contains deployment and promotion assets for local Kubernetes simulation and cloud-oriented GitOps workflows.

## Overview

The `cicd` folder is the delivery control plane for this repository. It includes:

- Argo CD Application manifests per environment (`dev`, `qa`, `prd`)
- Helm chart templates for the platform runtime
- Environment-specific values files
- Local cluster bootstrap scripts for kind
- Helper scripts for image build and connector/schema registration

## Folder Structure

- `argocd/`
  - `dev.yaml`
  - `qa.yaml`
  - `prd.yaml`
- `charts/`
  - `Chart.yaml`
  - `values.yaml`
  - `templates/`
  - `charts/`
- `k8s/helm/`
  - `values/values-dev.yaml`
  - `values/values-qa.yaml`
  - `values/values-prd.yaml`
  - `scripts/helm-deps.sh`
- `k8s/kind/`
  - `bootstrap-kind.sh`
- `scripts/`
  - `build-images.sh`
  - `register-connectors-core.sh` (internal)
  - `register-dbz-connectors.sh`
  - `register-mdm-connectors.sh`
  - `register-ods-connectors.sh`
  - `register-schemas.sh`
  - `lib/common.sh`
  - `lib/registration.sh`

### Script Canonical Paths

- Use purpose-specific wrappers for 3 Kafka Connect runtimes:
  `./cicd/scripts/register-dbz-connectors.sh`,
  `./cicd/scripts/register-mdm-connectors.sh`,
  `./cicd/scripts/register-ods-connectors.sh`.
- `./cicd/scripts/register-connectors-core.sh` is an internal shared engine used by those wrappers.
- Use `./cicd/scripts/register-schemas.sh` for script-driven registration flows (for example CI jobs and manual script runs).
- The Docker Compose `schema-init` image uses `./platform-services/schemas/scripts/register-schemas.sh`, which is container-local and optimized for bootstrap execution inside the schema-init image.

### Connector Env Knobs

The connector registration wrappers and core script support these runtime knobs:

- `CONNECT_WAIT_SECONDS`: Max seconds to wait for Kafka Connect readiness (`/connector-plugins`) before failing. `0` disables wait (default).
- `CONNECT_WAIT_INTERVAL_SEC`: Poll interval (seconds) while waiting for Kafka Connect. Default `2`.
- `CONNECT_UPSERT_RETRIES`: Number of upsert attempts per connector (`PUT`/`POST`). Default `5`.
- `CONNECT_UPSERT_RETRY_DELAY_SEC`: Delay (seconds) between upsert retries. Default `3`.
- `ODS_DELETE_LEGACY_CONNECTOR`: When `true`, ODS scope removes legacy `jdbc-sales-warehouse` before registering split ODS connectors. Default `true`.

## Deployment Model

1. Build and publish/load images for runtime services.
2. Render and deploy the Helm chart (`charts`) with environment values.
3. Reconcile desired state through Argo CD Application manifests.
4. Validate workloads and runtime health with runbook checks.

## Left-To-Right GitOps Pipeline

```mermaid
flowchart LR
  subgraph S[Source of Truth]
    GIT[Git Repository]
    CHART[Helm Chart Templates]
    VALUES[Environment Values: Dev, QA, PRD]
    APP[Argo CD Application Manifests]
  end

  subgraph P[Delivery Pipeline]
    BUILD[Build + Publish Images]
    RENDER[Helm Render]
    ARGO[Argo CD reconcile]
    APPLY[Apply Resources to Cluster]
  end

  subgraph T[Runtime Targets]
    DEV[gndp-dev Namespace]
    QA[QA Namespace / Cluster]
    PRD[PRD Namespace / Cluster]
  end

  GIT --> BUILD
  GIT --> CHART
  GIT --> VALUES
  GIT --> APP
  CHART --> RENDER
  VALUES --> RENDER
  APP --> ARGO
  RENDER --> ARGO
  ARGO --> APPLY
  APPLY --> DEV
  APPLY --> QA
  APPLY --> PRD
```

## Usage

Use the script and kubectl entrypoints for local GitOps operation:

```bash
./cicd/k8s/kind/bootstrap-kind.sh
./cicd/scripts/build-images.sh
kubectl apply -f cicd/argocd/dev.yaml
kubectl -n argocd get application gndp-dev
```

For direct Argo CD app reconciliation:

```bash
kubectl apply -f cicd/argocd/dev.yaml
kubectl -n argocd get application gndp-dev
```

For chart-level validation, use Helm directly with the chart and values files in this folder.

## Notes

- Keep environment differences in values files, not in templates.
- Treat Git as source of truth when Argo CD is enabled.
- Use runbook validation steps before promoting from `dev` to `qa` and `prd`.

## References

- `../docs/runbook.md`
- `../docs/architecture.md`
- `../readme.md`
