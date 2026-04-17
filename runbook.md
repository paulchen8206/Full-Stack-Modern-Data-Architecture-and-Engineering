# Local Development Operations Runbook

This runbook defines two supported local operation routines:

- Routine A: Docker Compose (fast local loop)
- Routine B: kind + Helm + Argo CD (GitOps local cluster loop)

Use only one routine at a time for a clean workflow.

## Operator Cheat Sheet

| Routine | Daily task | Copy-paste command bundle |
| --- | --- | --- |
| Docker Compose | Start full stack | `docker compose up -d --build` |
| Docker Compose | Fast health check | `docker compose ps && ./scripts/check-pipeline-topics.sh` |
| Docker Compose | Tail app logs | `docker compose logs --no-color --since=10m producer processor | tail -n 200` |
| Docker Compose | Rebuild processor only + validate | `docker compose up -d --build processor && docker compose logs --no-color --since=2m processor | tail -n 120 && ./scripts/consume-topic.sh sales_order 1 && ./scripts/consume-topic.sh sales_order_line_item 1 && ./scripts/consume-topic.sh customer_sales 1` |
| Docker Compose | Full clean reset | `docker compose down -v && docker compose up -d --build` |
| kind + Helm + Argo CD | Bootstrap local cluster | `./scripts/bootstrap-kind.sh && ./scripts/build-images.sh && kubectl apply -f argocd/dev.yaml` |
| kind + Helm + Argo CD | Check app + workloads | `kubectl -n argocd get application realtime-dev && kubectl -n realtime-dev get pods` |
| kind + Helm + Argo CD | Open Argo CD UI | `kubectl -n argocd port-forward svc/argocd-server 8443:443` |
| kind + Helm + Argo CD | Open Kafka UI | `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-kafka-ui 8082:8080` |
| kind + Helm + Argo CD | Open Grafana | `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-grafana 3001:3000` |
| kind + Helm + Argo CD | Cluster smoke check | `echo '--- app ---' && kubectl -n argocd get application realtime-dev && echo '--- pods ---' && kubectl -n realtime-dev get pods && echo '--- topics ---' && kubectl -n realtime-dev exec realtime-dev-kafka-controller-0 -- /opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server realtime-dev-kafka:9092 --list` |
| kind + Helm + Argo CD | Recreate app + namespace | `kubectl -n argocd delete application realtime-dev && kubectl delete namespace realtime-dev && kubectl apply -f argocd/dev.yaml` |

## Scope and Goals

- Bring up the full realtime pipeline end-to-end.
- Verify topic fan-out from raw input to derived topics.
- Provide repeatable start, validate, troubleshoot, and reset steps.

## Prerequisites

- Docker Desktop running
- kubectl installed
- kind installed for Routine B
- Access to this repository root directory

## Routine A: Docker Compose

### A1. Start stack

```bash
docker compose up -d --build
```

Expected local endpoints:

- Kafka broker: localhost:9094
- Kafka UI: http://localhost:8080

### A2. Validate containers

```bash
docker compose ps
```

All services should be Up, especially:

- kafka
- topic-init
- producer
- processor
- kafka-ui

### A3. Validate topics and dataflow

```bash
./scripts/list-topics.sh
./scripts/consume-topic.sh raw_sales_orders 1
./scripts/consume-topic.sh sales_order 1
./scripts/consume-topic.sh sales_order_line_item 1
./scripts/consume-topic.sh customer_sales 1
```

Quick full check:

```bash
./scripts/check-pipeline-topics.sh
```

### A4. Observe logs

```bash
docker compose logs --no-color --since=5m producer processor | tail -n 120
```

### A5. Stop and clean

Stop only:

```bash
docker compose down
```

Stop and remove volumes:

```bash
docker compose down -v
```

## Routine B: kind + Helm + Argo CD

### B1. Bootstrap kind and Argo CD

```bash
./scripts/bootstrap-kind.sh
```

Wait until Argo CD pods are Ready:

```bash
kubectl -n argocd get pods
```

### B2. Build and load app images into kind

```bash
./scripts/build-images.sh
```

### B3. Deploy application through Argo CD

```bash
kubectl apply -f argocd/dev.yaml
```

Confirm app appears and is healthy:

```bash
kubectl -n argocd get applications
kubectl -n argocd get application realtime-dev
kubectl -n realtime-dev get pods
```

### B4. Access web UIs

Argo CD:

```bash
kubectl -n argocd port-forward svc/argocd-server 8443:443
```

- URL: https://localhost:8443
- Username: admin
- Password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode; echo
```

Kafka UI:

```bash
kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-kafka-ui 8082:8080
```

- URL: http://localhost:8082

Grafana:

```bash
kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-grafana 3001:3000
```

- URL: http://localhost:3001

### B5. Validate pipeline topics in cluster

```bash
kubectl -n realtime-dev exec realtime-dev-kafka-controller-0 -- \
  /opt/bitnami/kafka/bin/kafka-topics.sh \
  --bootstrap-server realtime-dev-kafka:9092 --list

kubectl -n realtime-dev exec realtime-dev-kafka-controller-0 -- \
  /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server realtime-dev-kafka:9092 \
  --topic raw_sales_orders --partition 0 --offset 0 --max-messages 1 --timeout-ms 15000
```

Repeat the consumer command for:

- sales_order
- sales_order_line_item
- customer_sales

### B6. Resync and full reset

Force refresh app object:

```bash
kubectl apply -f argocd/dev.yaml
```

Delete and recreate app only:

```bash
kubectl -n argocd delete application realtime-dev
kubectl apply -f argocd/dev.yaml
```

Full namespace reset:

```bash
kubectl -n argocd delete application realtime-dev
kubectl delete namespace realtime-dev
kubectl apply -f argocd/dev.yaml
```

## Routine C: QA/PRD GitOps to Cloud Kubernetes (AWS, GCP, Azure)

Use this routine when deploying the same Helm chart through Argo CD to non-local QA/PRD clusters.

### C1. Prerequisites

- Container images for producer and processor are published to a registry reachable by the target cluster.
- QA and PRD values are maintained in `environments/qa/values.yaml` and `environments/prd/values.yaml`.
- Argo CD is installed and reachable in the control cluster.
- Your kubeconfig includes contexts for the QA and PRD target clusters.

### C2. Authenticate and fetch cluster credentials

Pick the cloud command set that matches your provider.

AWS EKS:

```bash
aws eks update-kubeconfig --region <region> --name <qa-cluster-name> --alias qa
aws eks update-kubeconfig --region <region> --name <prd-cluster-name> --alias prd
```

GCP GKE:

```bash
gcloud container clusters get-credentials <qa-cluster-name> --region <region> --project <project-id>
gcloud container clusters get-credentials <prd-cluster-name> --region <region> --project <project-id>
```

Azure AKS:

```bash
az aks get-credentials --resource-group <qa-rg> --name <qa-cluster-name> --context qa --overwrite-existing
az aks get-credentials --resource-group <prd-rg> --name <prd-cluster-name> --context prd --overwrite-existing
```

Verify contexts:

```bash
kubectl config get-contexts
```

### C3. Register external clusters in Argo CD

If Argo CD does not yet manage QA/PRD clusters, add them:

```bash
argocd cluster add <qa-context>
argocd cluster add <prd-context>
argocd cluster list
```

### C4. Point QA/PRD applications at the right destination cluster

`argocd/qa.yaml` and `argocd/prd.yaml` currently target `https://kubernetes.default.svc`.
For multi-cluster deployment, set each `spec.destination.server` to the corresponding QA/PRD cluster API server from `argocd cluster list`.

### C5. Deploy and sync QA first

```bash
kubectl apply -f argocd/qa.yaml
kubectl -n argocd get application realtime-qa
```

Optional force sync with Argo CD CLI:

```bash
argocd app sync realtime-qa
argocd app wait realtime-qa --health --sync --timeout 600
```

Validate QA workload:

```bash
kubectl --context <qa-context> -n realtime-qa get pods
kubectl --context <qa-context> -n realtime-qa get svc
```

### C6. Promote to PRD

After QA validation, apply PRD:

```bash
kubectl apply -f argocd/prd.yaml
kubectl -n argocd get application realtime-prd
```

Optional force sync with Argo CD CLI:

```bash
argocd app sync realtime-prd
argocd app wait realtime-prd --health --sync --timeout 900
```

Validate PRD workload:

```bash
kubectl --context <prd-context> -n realtime-prd get pods
kubectl --context <prd-context> -n realtime-prd get svc
```

### C7. Rollback strategy

- Revert the Git commit that introduced the bad change and push.
- Argo CD will reconcile back to the previous known-good revision.
- For urgent recovery, run:

```bash
argocd app rollback realtime-prd
```

### C8. Cloud routine guardrails

- Promote in order: dev -> qa -> prd.
- Keep `prd` with conservative sync behavior (`prune: false`) unless explicitly approved.
- Use environment-specific image tags; avoid deploying mutable `latest` tags to prd.
- Always validate Kafka reachability and topic health in target namespaces after each promotion.

### C9. Release Approval and Rollback Gates (Checklist)

Audit record: Owner: <name or alias> | Timestamp (UTC): <YYYY-MM-DDTHH:MM:SSZ>

Use this compact gate checklist for each release candidate.

- [ ] Gate 1: Change review approved (owner + reviewer) and target image tags are immutable.
- [ ] Gate 2: QA sync completed and app is Healthy/Synced in Argo CD.
- [ ] Gate 3: QA smoke checks passed (pods ready, topic list valid, sample consume succeeds).
- [ ] Gate 4: Production change window and on-call owner confirmed.
- [ ] Gate 5: PRD sync completed and app is Healthy/Synced in Argo CD.
- [ ] Gate 6: PRD post-deploy checks passed (pods ready, Kafka connectivity, key topic flow).

Rollback decision gates:

- [ ] Rollback trigger A: app Degraded or progression blocked longer than agreed timeout.
- [ ] Rollback trigger B: data correctness issue detected in downstream topics.
- [ ] Rollback trigger C: SLO/SLA regression detected after PRD sync.
- [ ] Rollback action: execute `argocd app rollback realtime-prd`, then validate health and dataflow.

## Troubleshooting Quick Reference

### App missing in Argo CD UI

```bash
kubectl config current-context
kubectl -n argocd get applications
kubectl apply -f argocd/dev.yaml
```

### Port-forward exits immediately

Kill stale listeners and retry:

```bash
lsof -ti tcp:8443 | xargs -r kill
lsof -ti tcp:8082 | xargs -r kill
lsof -ti tcp:3001 | xargs -r kill
```

Then restart the needed port-forward command.

### Kafka UI or Grafana page not loading

Confirm service exists and pods are running:

```bash
kubectl -n realtime-dev get svc
kubectl -n realtime-dev get pods
```

### End-to-end smoke command bundle (cluster)

```bash
echo '--- app status ---' && \
kubectl -n argocd get application realtime-dev && \
echo '--- realtime-dev pods ---' && \
kubectl -n realtime-dev get pods && \
echo '--- topics list ---' && \
kubectl -n realtime-dev exec realtime-dev-kafka-controller-0 -- \
/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server realtime-dev-kafka:9092 --list
```
