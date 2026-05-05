###############################################################################
# DOCKER + K8S/HELM ROUTINES
###############################################################################

K8S_ENV ?= dev
KIND_CLUSTER ?= gndp-dev
K8S_NAMESPACE ?= gndp-$(K8S_ENV)
K8S_RELEASE ?= gndp-$(K8S_ENV)
IMAGE_TAG ?= 0.1.0
DOCKER_COMPOSE ?= docker compose
DBZ_CONNECT_STATUS_URL ?= http://localhost:8083/connectors/dbz-mysql-mdm/status
KAFKA_CONSUMER_CONTAINER ?= kafka-3
KAFKA_BOOTSTRAP_SERVER ?= kafka-3:19094
KAFKA_CONSOLE_CONSUMER ?= /usr/bin/kafka-console-consumer
TRINO_SMOKE_URL ?= http://localhost:8086/v1/info
AIRFLOW_DAG_ID ?= dbt_warehouse_schedule
OPENMETADATA_PROFILE ?= --profile openmetadata
OPENMETADATA_INGEST_CONTAINER ?= openmetadata-ingestion
OPENMETADATA_WORKFLOW_BASE ?= /opt/openmetadata/metadata/workflows
KUBECTL ?= kubectl
KUBECTL_NS ?= $(KUBECTL) -n $(K8S_NAMESPACE)
KUBECTL_ARGOCD ?= $(KUBECTL) -n argocd
K8S_CONNECT_URL ?= http://localhost:8083
UI_PORT_FORWARDS ?= \
	airflow=18080:8080 \
	trino=18081:8080 \
	conduktor=18082:8080 \
	grafana=3000:3000 \
	prometheus=9090:9090 \
	openmetadata=8585:8585 \
	minio=9001:9001

HELM_CHART ?= ./cicd/charts
HELM_VALUES ?= ./cicd/k8s/helm/values/values-$(K8S_ENV).yaml
ARGO_APP_MANIFEST ?= ./cicd/argocd/$(K8S_ENV).yaml
HELM_TIMEOUT ?= 15m
HELM_RESET_JOBS ?= \
	$(K8S_RELEASE)-vision-dbz-connect-init \
	$(K8S_RELEASE)-vision-mdm-connect-init \
	$(K8S_RELEASE)-vision-ods-connect-init \
	$(K8S_RELEASE)-vision-dbt \
	$(K8S_RELEASE)-vision-register-schemas-job
HELM_SET_ARGS ?= \
	--set mdm.source.image.repository=$(MDM_SOURCE_IMAGE_REPOSITORY) \
	--set mdm.source.image.tag=$(MDM_SOURCE_IMAGE_TAG) \
	--set schemaInit.image.repository=$(SCHEMA_INIT_IMAGE_REPOSITORY) \
	--set schemaInit.image.tag=$(SCHEMA_INIT_IMAGE_TAG)
MDM_SOURCE_IMAGE_REPOSITORY ?= pos-mdm-source
MDM_SOURCE_IMAGE_TAG ?= 0.1.0
SCHEMA_INIT_IMAGE_REPOSITORY ?= schema-init
SCHEMA_INIT_IMAGE_TAG ?= latest

.PHONY: compose-up compose-down compose-clean mdm-status mdm-topics-check mdm-flow-check \
	dbt-run airflow-logs airflow-trigger-dbt-dag ops-status verify-dbt-relations trino-smoke \
	dbt-logs openmetadata-up openmetadata-status \
	openmetadata-prepare-dbt-artifacts openmetadata-ingest-trino openmetadata-ingest-postgres \
	openmetadata-ingest-dbt openmetadata-ingest-airflow openmetadata-ingest-kafka \
	k8s-kind-bootstrap k8s-build-images helm-deps helm-template helm-up helm-down k8s-cleanup k8s-ui-port-forward \
	k8s-argocd-apply k8s-status k8s-register-dbz k8s-register-mdm k8s-register-ods k8s-register-connectors \
	helm-reboot-dev helm-health-dev helm-metastore-migrate-dev \
	k8s-routine-up k8s-routine-down

# Start all services using Docker Compose
compose-up:
	$(DOCKER_COMPOSE) up -d

# Stop all services using Docker Compose
compose-down:
	$(DOCKER_COMPOSE) down

# Remove stopped containers, dangling images, and unused volumes
compose-clean:
	$(DOCKER_COMPOSE) down -v --remove-orphans
	docker system prune -f


# Show health for MDM CDC pipeline services and Debezium connector status
mdm-status:
	$(DOCKER_COMPOSE) ps mdm-source dbz-connect dbz-connect-init mdm-connect mdm-connect-init mdm-cdc-curate
	@echo ""
	@echo "Debezium connector status (expects RUNNING):"
	$(DOCKER_COMPOSE) exec dbz-connect curl -fsS $(DBZ_CONNECT_STATUS_URL) | cat

# Consume sample messages from curated MDM topics
mdm-topics-check:
	$(DOCKER_COMPOSE) exec $(KAFKA_CONSUMER_CONTAINER) $(KAFKA_CONSOLE_CONSUMER) --bootstrap-server $(KAFKA_BOOTSTRAP_SERVER) --topic mdm_customer --max-messages 3 --timeout-ms 15000
	$(DOCKER_COMPOSE) exec $(KAFKA_CONSUMER_CONTAINER) $(KAFKA_CONSOLE_CONSUMER) --bootstrap-server $(KAFKA_BOOTSTRAP_SERVER) --topic mdm_product --max-messages 3 --timeout-ms 15000

# Run complete MDM event-flow validation
mdm-flow-check: mdm-status mdm-topics-check


###############################################################################
# COMPOSE ANALYTICS / TRINO / OPENMETADATA TARGETS
###############################################################################

# Run dbt models once in the compose runtime
dbt-run:
	$(DOCKER_COMPOSE) run --rm dbt

# Tail dbt container logs
dbt-logs:
	$(DOCKER_COMPOSE) logs --tail=200 dbt

# Tail Airflow logs for quick DAG troubleshooting
airflow-logs:
	$(DOCKER_COMPOSE) logs --tail=200 airflow

# Trigger the scheduled dbt DAG manually
airflow-trigger-dbt-dag:
	$(DOCKER_COMPOSE) exec airflow airflow dags trigger $(AIRFLOW_DAG_ID)

# Quick compose-side status snapshot
ops-status:
	$(DOCKER_COMPOSE) ps

# Verify core dbt schemas and relation counts in local warehouse
verify-dbt-relations:
	$(DOCKER_COMPOSE) exec -T snowflake-mimic psql -U analytics -d analytics -c "SELECT schemaname, count(*) AS relation_count FROM pg_catalog.pg_tables WHERE schemaname IN ('landing','bronze','silver','gold') GROUP BY schemaname ORDER BY schemaname;"

# Validate Trino coordinator endpoint
trino-smoke:
	curl -fsS $(TRINO_SMOKE_URL) | cat

# Start OpenMetadata stack via compose profile
openmetadata-up:
	$(DOCKER_COMPOSE) $(OPENMETADATA_PROFILE) up -d openmetadata-db openmetadata-search openmetadata-server openmetadata-ingestion

# Check OpenMetadata stack status
openmetadata-status:
	$(DOCKER_COMPOSE) $(OPENMETADATA_PROFILE) ps openmetadata-server openmetadata-ingestion

# Generate dbt artifacts used by metadata ingestion
openmetadata-prepare-dbt-artifacts:
	$(DOCKER_COMPOSE) run --rm dbt dbt deps
	$(DOCKER_COMPOSE) run --rm dbt dbt parse

# Run OpenMetadata Trino ingestion workflow
openmetadata-ingest-trino:
	$(DOCKER_COMPOSE) $(OPENMETADATA_PROFILE) exec -T $(OPENMETADATA_INGEST_CONTAINER) metadata ingest -c $(OPENMETADATA_WORKFLOW_BASE)/trino_ingestion.yaml

# Run OpenMetadata Postgres ingestion workflow
openmetadata-ingest-postgres:
	$(DOCKER_COMPOSE) $(OPENMETADATA_PROFILE) exec -T $(OPENMETADATA_INGEST_CONTAINER) metadata ingest -c $(OPENMETADATA_WORKFLOW_BASE)/postgres_ingestion.yaml

# Run OpenMetadata dbt ingestion workflow
openmetadata-ingest-dbt:
	$(DOCKER_COMPOSE) $(OPENMETADATA_PROFILE) exec -T $(OPENMETADATA_INGEST_CONTAINER) metadata ingest -c $(OPENMETADATA_WORKFLOW_BASE)/dbt_ingestion.yaml

# Run OpenMetadata Airflow ingestion workflow
openmetadata-ingest-airflow:
	$(DOCKER_COMPOSE) $(OPENMETADATA_PROFILE) exec -T $(OPENMETADATA_INGEST_CONTAINER) metadata ingest -c $(OPENMETADATA_WORKFLOW_BASE)/airflow_ingestion.yaml

# Run OpenMetadata Kafka ingestion workflow
openmetadata-ingest-kafka:
	$(DOCKER_COMPOSE) $(OPENMETADATA_PROFILE) exec -T $(OPENMETADATA_INGEST_CONTAINER) metadata ingest -c $(OPENMETADATA_WORKFLOW_BASE)/kafka_ingestion.yaml


###############################################################################
# K8S + HELM ROUTINE TARGETS
###############################################################################

# Bootstrap kind cluster and Argo CD namespace/control plane
k8s-kind-bootstrap:
	@if kind get clusters | grep -qx "$(KIND_CLUSTER)"; then \
		echo "kind cluster '$(KIND_CLUSTER)' already exists, skipping bootstrap"; \
	else \
		CLUSTER_NAME=$(KIND_CLUSTER) ./cicd/k8s/kind/bootstrap-kind.sh; \
	fi

# Build runtime images and load them into the kind cluster
k8s-build-images:
	CLUSTER_NAME=$(KIND_CLUSTER) \
	MDM_SOURCE_IMAGE=$(MDM_SOURCE_IMAGE_REPOSITORY):$(MDM_SOURCE_IMAGE_TAG) \
	SCHEMA_INIT_IMAGE=$(SCHEMA_INIT_IMAGE_REPOSITORY):$(SCHEMA_INIT_IMAGE_TAG) \
	./cicd/scripts/build-images.sh

# Resolve chart dependencies
helm-deps:
	./cicd/k8s/helm/scripts/helm-deps.sh

# Render templates for quick validation before apply
helm-template:
	helm template $(K8S_RELEASE) $(HELM_CHART) -n $(K8S_NAMESPACE) -f $(HELM_VALUES)

# Install/upgrade platform chart into the selected namespace
helm-up: helm-deps
	-$(KUBECTL_NS) delete job $(HELM_RESET_JOBS) --ignore-not-found
	helm upgrade --install $(K8S_RELEASE) $(HELM_CHART) -n $(K8S_NAMESPACE) --create-namespace -f $(HELM_VALUES) --timeout $(HELM_TIMEOUT) \
		$(HELM_SET_ARGS)

# Reconcile dev namespace from local Helm chart and show status
helm-reboot-dev:
	$(MAKE) K8S_ENV=dev helm-up
	$(MAKE) K8S_ENV=dev k8s-status

# Snapshot dev namespace health only
helm-health-dev:
	$(MAKE) K8S_ENV=dev k8s-status

# Ensure required Iceberg JDBC metastore tables exist in dev Postgres
helm-metastore-migrate-dev:
	$(KUBECTL) -n gndp-dev exec deploy/gndp-dev-vision-snowflake-mimic -- psql -U analytics -d analytics -c "CREATE TABLE IF NOT EXISTS public.iceberg_tables (catalog_name text NOT NULL, table_namespace text NOT NULL, table_name text NOT NULL, metadata_location text NOT NULL, previous_metadata_location text, PRIMARY KEY (catalog_name, table_namespace, table_name));"
	$(KUBECTL) -n gndp-dev exec deploy/gndp-dev-vision-snowflake-mimic -- psql -U analytics -d analytics -c "CREATE TABLE IF NOT EXISTS public.iceberg_namespace_properties (catalog_name text NOT NULL, namespace text NOT NULL, property_key text NOT NULL, property_value text, PRIMARY KEY (catalog_name, namespace, property_key));"
	$(KUBECTL) -n gndp-dev rollout restart deployment/gndp-dev-vision-trino deployment/gndp-dev-vision-iceberg-writer

# Remove platform chart and namespace resources
helm-down:
	-helm uninstall $(K8S_RELEASE) -n $(K8S_NAMESPACE)
	-$(KUBECTL) delete namespace $(K8S_NAMESPACE) --ignore-not-found

# Cleanup Kubernetes runtime: remove app resources and delete kind cluster
k8s-cleanup:
	-$(MAKE) helm-down
	-kind delete cluster --name $(KIND_CLUSTER)

# Apply Argo CD application manifest for the selected environment
k8s-argocd-apply:
	$(KUBECTL) apply -f $(ARGO_APP_MANIFEST)
	$(KUBECTL_ARGOCD) get application $(K8S_RELEASE)

# Snapshot workload health in the selected namespace
k8s-status:
	$(KUBECTL_NS) get pods
	$(KUBECTL_NS) get jobs

# Register Debezium connectors in the in-cluster DBZ Connect deployment
k8s-register-dbz:
	bash ./cicd/scripts/register-dbz-connectors.sh --k8s $(K8S_NAMESPACE) $(K8S_RELEASE)-vision-dbz-connect --url $(K8S_CONNECT_URL)

# Register MDM connectors in the in-cluster MDM Connect deployment
k8s-register-mdm:
	bash ./cicd/scripts/register-mdm-connectors.sh --k8s $(K8S_NAMESPACE) $(K8S_RELEASE)-vision-mdm-connect --url $(K8S_CONNECT_URL)

# Register ODS connectors in the in-cluster ODS Connect deployment
k8s-register-ods:
	bash ./cicd/scripts/register-ods-connectors.sh --k8s $(K8S_NAMESPACE) $(K8S_RELEASE)-vision-ods-connect --url $(K8S_CONNECT_URL)

# Register all connector sets in-cluster
k8s-register-connectors: k8s-register-dbz k8s-register-mdm k8s-register-ods

# Port-forward all enabled UI services in the selected namespace (Ctrl+C to stop)
k8s-ui-port-forward:
	@set -euo pipefail; \
	pids=""; \
	cleanup() { \
		for pid in $$pids; do kill $$pid >/dev/null 2>&1 || true; done; \
	}; \
	trap cleanup EXIT INT TERM; \
	for mapping in $(UI_PORT_FORWARDS); do \
		svc="$${mapping%%=*}"; \
		ports="$${mapping#*=}"; \
		if $(KUBECTL_NS) get svc $$svc >/dev/null 2>&1; then \
			echo "Forwarding $$svc on $$ports"; \
			$(KUBECTL_NS) port-forward svc/$$svc $$ports >/tmp/port-forward-$$svc.log 2>&1 & \
			pids="$$pids $$!"; \
		else \
			echo "Skipping $$svc (service not found in $(K8S_NAMESPACE))"; \
		fi; \
	done; \
	echo "UI forwards are active. Press Ctrl+C to stop all."; \
	wait

# Routine B: kind + image build/load + Helm deploy
k8s-routine-up: k8s-kind-bootstrap k8s-build-images helm-up k8s-status

# Routine B teardown: remove Helm release and namespace
k8s-routine-down: k8s-cleanup
