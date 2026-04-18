# ── Variables ─────────────────────────────────────────────────────────────────
CLUSTER_NAME    ?= realtime-dev
PRODUCER_IMAGE  ?= realtime-sales-producer:0.1.0
PROCESSOR_IMAGE ?= realtime-sales-processor:0.1.0
CONNECT_IMAGE   ?= realtime-sales-connect:0.1.0
DBT_IMAGE       ?= realtime-sales-dbt:0.1.0
AIRFLOW_IMAGE   ?= realtime-sales-airflow:0.1.0
ENV             ?= dev
KAFKA_BOOTSTRAP ?= kafka:9092
TOPIC           ?=
MESSAGE_COUNT   ?= 5

# ── Phony targets ─────────────────────────────────────────────────────────────
.PHONY: help validate \
        build \
	routine-a up down topics-create topics-list topics-check consume \
	lakehouse-up lakehouse-down airflow-up airflow-logs airflow-trigger-dbt-dag \
	dbt-run verify-warehouse verify-dbt-relations \
        routine-b docker-build kind-load images kind-bootstrap argocd-apply \
          helm-deps helm-lint helm-render-dev helm-render-qa helm-render-prd helm-render \
	  helm-reboot-dev helm-health-dev

# ── Help ──────────────────────────────────────────────────────────────────────
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*##"} {printf "  %-22s %s\n", $$1, $$2}'

# ── Shared ────────────────────────────────────────────────────────────────────
build: ## [shared]  Build the processor JAR (tests skipped)
	cd processor && mvn -DskipTests package

validate: build helm-lint helm-render ## [shared]  Build + lint + render all envs + compose parse
	docker compose config > /dev/null
	@echo "All validations passed."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Routine A – Docker Compose  (fast local application loop)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
routine-a: up topics-create ## [A]  Full Routine A bootstrap: start stack + create topics

up: ## [A]  Start local docker-compose stack
	docker compose up -d

down: ## [A]  Stop local docker-compose stack
	docker compose down

topics-create: ## [A]  Create Kafka topics (runs topic-init service)  [scripts/create-topics.sh]
	docker compose run --rm topic-init

topics-list: ## [A]  List Kafka topics  [scripts/list-topics.sh]
	KAFKA_BOOTSTRAP_SERVERS="$(KAFKA_BOOTSTRAP)" ./scripts/list-topics.sh

topics-check: ## [A]  Sample messages from every pipeline topic  [scripts/check-pipeline-topics.sh]
	MESSAGE_COUNT="$(MESSAGE_COUNT)" ./scripts/check-pipeline-topics.sh

consume: ## [A]  Consume TOPIC (make consume TOPIC=raw_sales_orders)  [scripts/consume-topic.sh]
	@if [ -z "$(TOPIC)" ]; then echo "Usage: make consume TOPIC=<topic-name>" >&2; exit 1; fi
	KAFKA_BOOTSTRAP_SERVERS="$(KAFKA_BOOTSTRAP)" ./scripts/consume-topic.sh "$(TOPIC)" "$(MESSAGE_COUNT)"

lakehouse-up: ## [A]  Start Kafka Connect + MinIO + Postgres + dbt layer
	docker compose up -d minio minio-init postgres connect connect-init airflow

lakehouse-down: ## [A]  Stop Kafka Connect + MinIO + Postgres + dbt layer
	docker compose stop airflow connect-init connect postgres minio-init minio

airflow-up: ## [A]  Start Apache Airflow for scheduled dbt runs
	docker compose up -d --build airflow

airflow-logs: ## [A]  Tail Apache Airflow logs
	docker compose logs --tail=200 airflow

airflow-trigger-dbt-dag: ## [A]  Trigger the scheduled dbt Airflow DAG manually
	docker compose exec -T airflow airflow dags trigger dbt_warehouse_schedule

dbt-run: ## [A]  Run dbt stage and gold models on Postgres
	docker compose run --rm dbt

verify-warehouse: ## [A]  Show landing, stage, and gold row counts in Postgres
	docker compose exec -T postgres psql -U analytics -d analytics -c "select count(*) as landing_sales_order from landing.sales_order; select count(*) as landing_sales_order_line_item from landing.sales_order_line_item; select count(*) as landing_customer_sales from landing.customer_sales; select count(*) as stage_sales_order from public_stage.stg_sales_order; select count(*) as stage_sales_order_line_item from public_stage.stg_sales_order_line_item; select count(*) as stage_customer_sales from public_stage.stg_customer_sales; select count(*) as gold_customer_sales_summary from public_gold.gold_customer_sales_summary;"

verify-dbt-relations: ## [A]  List dbt-created relations in public_stage and public_gold
	docker compose exec -T postgres psql -U analytics -d analytics -c "select table_schema, table_name, table_type from information_schema.tables where table_schema in ('public_stage', 'public_gold') order by table_schema, table_name;"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Routine B – kind + Helm + Argo CD  (GitOps local cluster loop)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
routine-b: kind-bootstrap images argocd-apply ## [B]  Full Routine B bootstrap: cluster + images + ArgoCD app

docker-build: ## [B]  Build producer + processor Docker images
	docker build -t "$(PRODUCER_IMAGE)"  ./producer
	docker build -t "$(PROCESSOR_IMAGE)" ./processor
	docker build -t "$(CONNECT_IMAGE)" ./connect
	docker build -t "$(DBT_IMAGE)" ./analytics/dbt
	docker build -t "$(AIRFLOW_IMAGE)" ./airflow

kind-load: ## [B]  Load images into the kind cluster
	kind load docker-image --name "$(CLUSTER_NAME)" "$(PRODUCER_IMAGE)"
	kind load docker-image --name "$(CLUSTER_NAME)" "$(PROCESSOR_IMAGE)"
	kind load docker-image --name "$(CLUSTER_NAME)" "$(CONNECT_IMAGE)"
	kind load docker-image --name "$(CLUSTER_NAME)" "$(DBT_IMAGE)"
	kind load docker-image --name "$(CLUSTER_NAME)" "$(AIRFLOW_IMAGE)"

images: docker-build kind-load ## [B]  Build images and load into kind  [scripts/build-images.sh]

kind-bootstrap: ## [B]  Create kind cluster and install Argo CD  [scripts/bootstrap-kind.sh]
	kind create cluster --name "$(CLUSTER_NAME)" --wait 120s
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

argocd-apply: ## [B]  Apply the Argo CD Application manifest for ENV (default: dev)
	kubectl apply -f argocd/$(ENV).yaml

helm-deps: ## [B]  Download / update Helm chart dependencies
	helm dependency build charts/realtime-app

helm-lint: helm-deps ## [B]  Lint the Helm chart
	helm lint charts/realtime-app

helm-render-dev: helm-deps ## [B]  Render Helm templates for dev
	helm template realtime-dev charts/realtime-app -f environments/dev/values.yaml

helm-render-qa: helm-deps ## [B]  Render Helm templates for qa
	helm template realtime-qa  charts/realtime-app -f environments/qa/values.yaml

helm-render-prd: helm-deps ## [B]  Render Helm templates for prd
	helm template realtime-prd charts/realtime-app -f environments/prd/values.yaml

helm-render: helm-render-dev helm-render-qa helm-render-prd ## [B]  Render templates for all environments

helm-reboot-dev: ## [B]  Reboot dev namespace via local Helm chart and values
	helm upgrade --install realtime-dev charts/realtime-app -n realtime-dev --create-namespace -f environments/dev/values.yaml
	$(MAKE) helm-health-dev

helm-health-dev: ## [B]  Show dev Helm workload health snapshot (pods, jobs, dbt bootstrap logs)
	kubectl -n realtime-dev get pods
	kubectl -n realtime-dev get jobs
	kubectl -n realtime-dev logs job/realtime-dev-realtime-app-dbt --tail=60 || true
