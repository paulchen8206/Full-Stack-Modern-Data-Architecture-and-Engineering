# Local Development Operations Runbook

This runbook defines two supported local operation routines:

- Routine A: Docker Compose (fast local loop)
- Routine B: kind + Helm + Argo CD (GitOps local cluster loop)

Use only one routine at a time for a clean workflow.

## Purpose

This section defines the purpose of this document.
Provide repeatable day-2 operational procedures for both local runtime routines.

## Commands

This section defines the primary commands for this document.
Use the Operator Cheat Sheet and routine sections for copy-paste command bundles.

## Validation

This section defines the primary validation approach for this document.
Use the validation checkpoints in Routine A and Routine B to verify service health, dataflow, and analytics outputs.

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
Use the troubleshooting sections in this document as the primary operational diagnostic path.

## References

This section defines the primary cross-references for this document.

- [../README.md](../README.md)
- [architecture.md](architecture.md)
- [adr/README.md](adr/README.md)

Architecture cross-reference:

- For a concise architecture-to-command mapping, see [Make Target Map (Architecture to Operations)](architecture.md#84-make-target-map-architecture-to-operations).

Documentation map:

- Project entrypoint: [../README.md](../README.md)
- Architecture reference: [architecture.md](architecture.md)
- Architecture Decision Records (ADR): [adr/README.md](adr/README.md)

## Credential Quick Sheet

| Component | Routine A (Docker Compose) | Routine B (kind + Helm) | Username | Password / Retrieval |
| --- | --- | --- | --- | --- |
| Argo CD UI | N/A | `https://localhost:8443` (after `kubectl -n argocd port-forward svc/argocd-server 8443:443`) | admin | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 --decode; echo` |
| MinIO Console | `http://localhost:9001` | `http://localhost:9001` (after `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-minio 9001:9001`) | minio | minio123 |
| Postgres | 127.0.0.1:5432 / db `analytics` | 127.0.0.1:5433 / db `analytics` (after `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-postgres 5433:5432`) | analytics | analytics |
| MySQL MDM | 127.0.0.1:3306 / db `mdm` | 127.0.0.1:3307 / db `mdm` (after `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-mysql-mdm 3307:3306`) | root | mdmroot |
| Airflow UI | `http://localhost:8084` | `http://localhost:8084` (after `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-airflow 8084:8080`) | admin | admin |

## Operator Cheat Sheet

| Routine | Daily task | Copy-paste command bundle |
| --- | --- | --- |
| Docker Compose | Bootstrap local routine (stack + topics) | `make routine-a` |
| Docker Compose | Start compose services only | `make up` |
| Docker Compose | Run unified day-2 operations | `make routine-a-ops` |
| Docker Compose | Fast health check | `docker compose ps && ./scripts/check-pipeline-topics.sh` |
| Docker Compose | Tail app logs | `docker compose logs --tail=200 --no-color --since=10m producer processor` |
| Docker Compose | Rebuild processor only + validate | `./scripts/compose-up.sh -d --build processor && docker compose logs --tail=120 --no-color --since=2m processor && ./scripts/consume-topic.sh sales_order 1 && ./scripts/consume-topic.sh sales_order_line_item 1 && ./scripts/consume-topic.sh customer_sales 1` |
| Docker Compose | Validate MDM topic flow | `make mdm-topics-check` |
| Docker Compose | Validate warehouse counts | `make verify-warehouse` |
| Docker Compose | Check Trino health | `make trino-smoke` |
| Docker Compose | Open Trino CLI shell | `make trino-shell` |
| Docker Compose | Seed Trino demo Iceberg table | `make trino-seed-demo` |
| Docker Compose | Bootstrap Iceberg from landing | `make trino-bootstrap-lakehouse` |
| Docker Compose | Rebuild all demo Iceberg tables | `make trino-rebuild-lakehouse` |
| Docker Compose | Incrementally sync Iceberg tables | `make trino-sync-lakehouse` |
| Docker Compose | Run sample Trino queries | `make trino-sample-queries` |
| Docker Compose | Validate streaming Iceberg tables received data | `make iceberg-streaming-smoke` |
| Docker Compose | Re-run dbt models | `make dbt-run` |
| Docker Compose | Start Airflow | `make airflow-up` |
| Docker Compose | Reboot Airflow and run dbt | `make airflow-dbt-reboot` |
| Docker Compose | Stop dbt if running | `make dbt-stop` |
| Docker Compose | Start Kafka UI and validate dbt state | `make kafka-ui-up` |
| Docker Compose | Runtime status snapshot | `make ops-status` |
| Docker Compose | Trigger scheduled dbt DAG | `make airflow-trigger-dbt-dag` |
| Docker Compose | Full clean reset | `docker compose down -v && ./scripts/compose-up.sh` |
| kind + Helm + Argo CD | Bootstrap local cluster (Docker-like one command) | `make routine-b` |
| kind + Helm + Argo CD | Run unified day-2 operations (Docker-path parity) | `make routine-b-ops` |
| kind + Helm + Argo CD | Stop local cluster workloads | `make routine-b-down` |
| kind + Helm + Argo CD | Bootstrap local cluster via Argo CD app | `make routine-b-argocd` |
| kind + Helm + Argo CD | Validate app and workloads | `kubectl -n argocd get application realtime-dev && kubectl -n realtime-dev get pods` |
| kind + Helm + Argo CD | Reboot from local Helm | `make helm-reboot-dev` |
| kind + Helm + Argo CD | Helm health snapshot | `make helm-health-dev` |
| kind + Helm + Argo CD | Runtime status snapshot | `make ops-status-dev` |
| kind + Helm + Argo CD | Validate MDM topic flow | `make mdm-topics-check-dev` |
| kind + Helm + Argo CD | Validate Airflow + dbt state | `make airflow-dbt-check-dev` |
| kind + Helm + Argo CD | Open Argo CD UI | `kubectl -n argocd port-forward svc/argocd-server 8443:443` |
| kind + Helm + Argo CD | Open Kafka UI | `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-kafka-ui 8082:8080` |
| kind + Helm + Argo CD | Open Airflow UI | `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-airflow 8084:8080` |
| kind + Helm + Argo CD | Open MinIO Console | `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-minio 9001:9001` |
| kind + Helm + Argo CD | Check Trino health | `make trino-smoke-dev` |
| kind + Helm + Argo CD | Validate streaming Iceberg tables received data | `make iceberg-streaming-smoke-dev` |
| kind + Helm + Argo CD | Open Postgres | `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-postgres 5433:5432` |
| kind + Helm + Argo CD | Open Grafana | `kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-grafana 3001:3000` |
| kind + Helm + Argo CD | Cluster smoke check | `echo '--- app ---' && kubectl -n argocd get application realtime-dev && echo '--- pods ---' && kubectl -n realtime-dev get pods && echo '--- topics ---' && kubectl -n realtime-dev exec realtime-dev-kafka-controller-0 -- /opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server realtime-dev-kafka:9092 --list` |
| kind + Helm + Argo CD | Recreate app + namespace | `kubectl -n argocd delete application realtime-dev && kubectl delete namespace realtime-dev && kubectl apply -f argocd/dev.yaml` |

## Scope and Goals

- Bring up the full realtime pipeline end-to-end.
- Validate topic fan-out from raw input to derived topics.
- Provide repeatable start, validate, troubleshoot, and reset steps.

## Prerequisites

- Docker Desktop running
- kubectl installed
- kind installed for Routine B
- Access to this repository root directory

## Routine A: Docker Compose

### A1. Start stack

Architecture-to-command map:

- See [Make Target Map (Architecture to Operations)](architecture.md#84-make-target-map-architecture-to-operations) for the rationale-to-target mapping used by this routine.

```bash
make routine-a
```

Run the unified day-2 operations workflow:

```bash
make routine-a-ops
```

Run shared target discovery and validation:

```bash
make help
make validate
```

Use `./scripts/compose-up.sh ...` for raw Compose startup flows instead of `docker compose up ...`. The wrapper applies the Postgres-backed Iceberg JDBC metastore upgrade and restarts Trino and `iceberg-writer` when those services are part of the running stack.

Expected local endpoints:

- Kafka broker: localhost:9094
- Kafka UI: `http://localhost:8080`
- Trino coordinator: `http://localhost:8086`
- Airflow UI: `http://localhost:8084`
- Debezium Connect REST (MDM): `http://localhost:8085`
- MySQL MDM: localhost:3306

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
- mysql-mdm
- mdm-writer
- mdm-connect
- mdm-cdc-producer
- mdm-pyspark-sync

Expected completed containers:

- `topic-init` exits with code 0 after creating topics.
- `minio-init` exits with code 0 after creating the object store bucket.
- `connect-init` exits with code 0 after registering connectors.
- `mdm-connect-init` exits with code 0 after registering the Debezium MySQL source connector.
- `dbt` exits with code 0 after `dbt run` completes.

Those `Exited (0)` states are normal and should not be treated as failures.

### A3. Validate topics and dataflow

```bash
./scripts/list-topics.sh
./scripts/consume-topic.sh raw_sales_orders 1
./scripts/consume-topic.sh sales_order 1
./scripts/consume-topic.sh sales_order_line_item 1
./scripts/consume-topic.sh customer_sales 1
./scripts/consume-topic.sh mdm_customer 1
./scripts/consume-topic.sh mdm_product 1
```

Quick full check:

```bash
./scripts/check-pipeline-topics.sh
```

Warehouse layer check:

```bash
make verify-warehouse
```

Start Airflow for scheduled dbt runs:

```bash
make airflow-up
```

Open `http://localhost:8084` and sign in with `admin` / `admin`.

Inspect the dbt-created relations:

```bash
make verify-dbt-relations
```

Check Trino coordinator health:

```bash
make trino-smoke
```

Open a shell-based Trino CLI or run ad hoc SQL without calling Python directly:

```bash
make trino-shell
./scripts/trino-sql.sh "SHOW TABLES FROM lakehouse.streaming"
```

Bootstrap real Iceberg tables on MinIO through Trino:

```bash
make trino-seed-demo
make trino-bootstrap-lakehouse
make trino-rebuild-lakehouse
make trino-sync-lakehouse
make trino-sample-queries
make iceberg-streaming-smoke
```

Interpretation:

- `bronze.*` objects are dbt staging-aligned views.
- `silver.*` objects are dbt dimension and fact tables.
- `gold.gold_customer_sales_summary` is the presentation table.
- If landing has rows and bronze/silver/gold does not, rerun dbt before debugging upstream services.
- If Trino is healthy but returns no Iceberg tables, run `make trino-seed-demo` or `make trino-bootstrap-lakehouse` to materialize Trino-managed Iceberg tables on MinIO.
- If you want realtime Iceberg ingestion without the Postgres bridge, confirm the `iceberg-writer` service is running and use `make iceberg-streaming-smoke` to verify rows arrived in `lakehouse.streaming`.
- The `iceberg-writer` also flushes partial topic batches on a timer, so low-volume streams should still land in Iceberg without waiting for a full batch.

### A4. Observe logs

```bash
docker compose logs --no-color --since=5m producer processor | tail -n 120
```

dbt logs:

```bash
docker compose logs --tail=200 dbt
```

Kafka Connect logs:

```bash
docker compose logs --tail=200 connect
```

MDM Debezium Connect logs:

```bash
docker compose logs --tail=200 mdm-connect
```

MDM writer + CDC publisher logs:

```bash
docker compose logs --tail=200 mdm-writer mdm-cdc-producer mdm-pyspark-sync
```

Manual dbt rerun:

```bash
make dbt-run
```

Manual Airflow DAG trigger:

```bash
make airflow-trigger-dbt-dag
```

Note: `docker compose run --rm dbt` may appear to pause while Compose waits for `postgres` and `connect-init`. That is dependency startup behavior, not an interactive prompt.

### A5. Stop and clean

Stop only:

```bash
docker compose down
```

Stop and remove volumes:

```bash
docker compose down -v
```

If you use the volume reset, Postgres landing, bronze, silver, and gold data will be recreated from scratch on the next startup.

## Compose Service Roles

- `producer` publishes composite order events to `raw_sales_orders`.
- `processor` runs the Spring Boot application with the embedded Flink topology.
- `connect` loads Kafka Connect sink plugins and exposes the REST API on port 8083.
- `connect-init` registers the JDBC and object-storage sink connectors from `connect/connector-configs`.
- `mysql-mdm` stores `mdm.customer360`, `mdm.product_master`, and `mdm_date` source tables.
- `mdm-writer` upserts customer and product master rows into MySQL.
- `mdm-connect` runs Debezium MySQL source capture and publishes raw CDC topics.
- `mdm-connect-init` registers the Debezium connector from `connect/connector-configs/debezium-mysql-mdm.json`.
- `mdm-cdc-producer` republishes curated `mdm_customer` and `mdm_product` topics.
- `mdm-pyspark-sync` syncs MySQL MDM tables into Postgres landing MDM tables.
- `postgres` stores `landing`, `bronze`, `silver`, and `gold` schemas for analytics queries.
- `dbt` transforms landing data into bronze views, silver tables, and gold tables.
- `airflow` schedules and triggers recurring dbt runs for the warehouse layer.
- `trino` exposes a SQL query endpoint and bootstrap path for real Iceberg tables on MinIO.
- `iceberg-writer` consumes Kafka topics directly and writes them to Iceberg tables through Trino.

## Common Failure Patterns

- No bronze rows with landing rows present:
  Run `make dbt-run`, then recheck `bronze` counts.
- `dbt` shows `Exited (0)` in `docker compose ps -a`:
  This is expected for the one-shot dbt service after a successful run.
- Kafka Connect is healthy but landing rows stay at zero:
  Check `docker compose logs --tail=200 connect` and confirm `connect-init` completed successfully.
- MySQL has rows but MDM landing tables stay at zero:
  Check `docker compose logs --tail=200 mdm-pyspark-sync` and verify Postgres connectivity.
- Debezium MDM connector is not producing raw CDC topics:
  Check `docker compose logs --tail=200 mdm-connect` and ensure `mdm-connect-init` completed successfully.
- Full stack startup feels blocked around dbt:
  Compose may still be waiting for `connect-init` or `postgres` before launching the dbt container.
- Airflow UI starts but no dbt runs appear:
  Check `make airflow-logs` and verify the `dbt_warehouse_schedule` DAG is enabled.

## Routine B: kind + Helm + Argo CD

### B1. Bootstrap kind and Argo CD

```bash
./scripts/bootstrap-kind.sh
```

Wait until Argo CD pods are Ready:

```bash
kubectl -n argocd get pods
```

When the dev stack is deployed, validate Trino with:

```bash
make trino-smoke-dev
kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-trino 8086:8080
curl -fsS http://localhost:8086/v1/info
```

### B2. Build and load app images into kind

```bash
./scripts/build-images.sh
```

Bootstrap local cluster (Docker-like one command):

```bash
make routine-b
```

Stop local cluster workloads:

```bash
make routine-b-down
```

This mirrors the Docker `make routine-a` experience by performing cluster bootstrap, image build/load, and Helm deploy in one flow.

Run unified day-2 operations (Docker-path parity):

```bash
make routine-b-ops
```

This mirrors the Docker `make routine-a-ops` flow with Kubernetes-native checks for status, MDM topics, Airflow/dbt state, and Trino/Iceberg smoke.

### B3. Deploy application through Argo CD

```bash
kubectl apply -f argocd/dev.yaml
```

If the Argo CD UI does not show `realtime-dev`, re-apply and validate:

```bash
kubectl apply -f argocd/dev.yaml
kubectl -n argocd get application realtime-dev
```

If you prefer the direct Helm path instead of Argo CD reconciliation:

```bash
make helm-reboot-dev
```

Validate app and workloads:

```bash
kubectl -n argocd get applications
kubectl -n argocd get application realtime-dev
kubectl -n realtime-dev get pods
```

### B4. Access web UIs

Use the same UI access order as the README Quick Start section.

Argo CD:

```bash
kubectl -n argocd port-forward svc/argocd-server 8443:443
```

- URL: `https://localhost:8443`
- Username: admin
- Password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode; echo
```

Kafka UI:

```bash
kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-kafka-ui 8082:8080
```

- URL: `http://localhost:8082`

Grafana:

```bash
kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-grafana 3001:3000
```

- URL: `http://localhost:3001`

Airflow:

```bash
kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-airflow 8084:8080
```

- URL: `http://localhost:8084`
- Username: `admin`
- Password: `admin`

MinIO:

```bash
kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-minio 9001:9001
```

- URL: `http://localhost:9001`
- Username: `minio`
- Password: `minio123`

Trino:

```bash
kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-trino 8086:8080
```

- URL: `http://localhost:8086`

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
- mdm_customer
- mdm_product

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

Docker-equivalent reset for Helm path:

```bash
kubectl delete namespace realtime-dev --ignore-not-found
make routine-b
```

### B7. Helm Lakehouse and Airflow health checks

Reboot the dev environment from the local Helm chart and values:

```bash
make helm-reboot-dev
```

Run the health snapshot independently:

```bash
make helm-health-dev
```

Expected healthy state:

- Deployments in `Running`: producer, processor, kafka-ui, minio, postgres, connect, airflow, mysql-mdm, mdm-writer, mdm-connect, mdm-cdc-producer, mdm-pyspark-sync, prometheus, loki, grafana.
- One-shot Jobs in `Complete`: `realtime-dev-realtime-app-minio-init`, `realtime-dev-realtime-app-connect-init`, `realtime-dev-realtime-app-mdm-connect-init`, `realtime-dev-realtime-app-dbt`.

Validate MDM topic flow in cluster:

```bash
kubectl -n realtime-dev exec realtime-dev-kafka-controller-0 -- \
  /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server realtime-dev-kafka:9092 \
  --topic mdm_customer --partition 0 --offset 0 --max-messages 1 --timeout-ms 15000

kubectl -n realtime-dev exec realtime-dev-kafka-controller-0 -- \
  /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server realtime-dev-kafka:9092 \
  --topic mdm_product --partition 0 --offset 0 --max-messages 1 --timeout-ms 15000
```

Open warehouse and scheduling UIs:

```bash
kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-airflow 8084:8080
kubectl -n realtime-dev port-forward svc/realtime-dev-realtime-app-minio 9001:9001
```

Argo CD source note:

- Argo CD syncs what is committed in the configured Git repo/branch.
- Local uncommitted chart edits are validated by direct Helm commands (`make helm-reboot-dev`) but are not synced by Argo CD until pushed.
- If app status shows `ComparisonError` and `SYNC STATUS: Unknown` with repository auth errors, add repository credentials to Argo CD for `https://github.com/paulchen8206/Kafka-Flink-with-Helm-and-Argo-CD.git`.
- If app status is `Healthy` but `OutOfSync`, treat Git as source of truth and sync the app before trusting runtime drift-sensitive checks.

## Routine C: QA/PRD GitOps to Cloud Kubernetes (AWS, GCP, Azure)

Use this routine when deploying the same Helm chart through Argo CD to non-local QA/PRD clusters.

### C1. Prerequisites

- Container images for producer, processor, connect, dbt, and airflow are published to a registry reachable by the target cluster.
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

Audit record: Owner: [name or alias] | Timestamp (UTC): [YYYY-MM-DDTHH:MM:SSZ]

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

### Argo CD app shows `ComparisonError` and `SYNC STATUS: Unknown`

This usually means Argo CD cannot fetch the Git source repository.

Check conditions:

```bash
kubectl -n argocd get application realtime-dev -o jsonpath='{range .status.conditions[*]}{.type}{": "}{.message}{"\n"}{end}'
```

If the message includes repository authentication failure, add repo credentials in Argo CD,
then refresh the app:

```bash
kubectl -n argocd annotate application realtime-dev argocd.argoproj.io/refresh=hard --overwrite
```

For immediate local validation while credentials are pending, use:

```bash
make helm-reboot-dev
make helm-health-dev
```

### Warehouse schemas appear as `public_bronze/public_silver/public_gold`

Symptom:

- dbt logs show models materialized in `public_*` schemas.
- Warehouse checks show duplicate schema families (`bronze` and `public_bronze`, etc.).

Root cause:

- dbt schema naming macro is not present in the runtime dbt project mounted by Helm.
- In Argo CD mode, local Helm edits do not take effect until committed and synced.

Detect quickly:

```bash
kubectl -n realtime-dev exec deploy/realtime-dev-realtime-app-postgres -- \
  psql -U analytics -d analytics -c "select schema_name from information_schema.schemata where schema_name like 'public_%' or schema_name in ('landing','bronze','silver','gold') order by 1;"
```

Permanent fix:

1. Ensure the chart mounts `generate_schema_name.sql` under `/dbt/macros` in both dbt Job and Airflow dbt volume items.
2. Commit and push the chart change.
3. Sync the Argo CD app and verify dbt runs materialize into `bronze/silver/gold` only.

One-time cleanup (move objects and drop `public_*` schemas):

```bash
cat <<'SQL' | kubectl -n realtime-dev exec -i deploy/realtime-dev-realtime-app-postgres -- psql -U analytics -d analytics
BEGIN;
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
DO $$
DECLARE
  rec RECORD;
  target_schema text;
  obj_type text;
BEGIN
  FOR rec IN
    SELECT n.nspname AS src_schema, c.relname AS rel_name, c.relkind
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('public_bronze','public_silver','public_gold')
      AND c.relkind IN ('r','v','m','S','f','p')
  LOOP
    target_schema := replace(rec.src_schema, 'public_', '');
    obj_type := CASE rec.relkind
      WHEN 'r' THEN 'TABLE'
      WHEN 'p' THEN 'TABLE'
      WHEN 'v' THEN 'VIEW'
      WHEN 'm' THEN 'MATERIALIZED VIEW'
      WHEN 'S' THEN 'SEQUENCE'
      WHEN 'f' THEN 'FOREIGN TABLE'
    END;
    EXECUTE format('ALTER %s %I.%I SET SCHEMA %I', obj_type, rec.src_schema, rec.rel_name, target_schema);
  END LOOP;
END$$;
DROP SCHEMA IF EXISTS public_bronze CASCADE;
DROP SCHEMA IF EXISTS public_silver CASCADE;
DROP SCHEMA IF EXISTS public_gold CASCADE;
COMMIT;
SQL
```

Post-cleanup verification:

```bash
kubectl -n realtime-dev exec deploy/realtime-dev-realtime-app-postgres -- \
  psql -U analytics -d analytics -c "select schema_name from information_schema.schemata where schema_name like 'public_%' or schema_name in ('landing','bronze','silver','gold') order by 1;"
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
