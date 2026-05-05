###############################################################################
# LOCAL COMPOSE
###############################################################################

AIRFLOW_DAG_ID ?= dbt_warehouse_schedule
ARGO_APP_MANIFEST ?= ./cicd/argocd/$(K8S_ENV).yaml
COMPOSE_LOG_TAIL ?= 200
DBZ_CONNECT_STATUS_URL ?= http://localhost:8083/connectors/dbz-mysql-mdm/status
DOCKER_COMPOSE ?= docker compose
HELM_CHART ?= ./cicd/charts
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
HELM_TIMEOUT ?= 15m
HELM_VALUES ?= ./cicd/k8s/helm/values/values-$(K8S_ENV).yaml
IMAGE_TAG ?= 0.1.0
K8S_CONNECT_URL ?= http://localhost:8083
K8S_ENV ?= dev
K8S_NAMESPACE ?= gndp-$(K8S_ENV)
K8S_RELEASE ?= gndp-$(K8S_ENV)
KAFKA_BOOTSTRAP_SERVER ?= kafka-3:19094
KAFKA_CONSOLE_CONSUMER ?= /usr/bin/kafka-console-consumer
KAFKA_CONSUMER_CONTAINER ?= kafka-3
KAFKA_CONSUMER_TIMEOUT_MS ?= 15000
KIND_CLUSTER ?= gndp-dev
KUBECTL ?= kubectl
KUBECTL_ARGOCD ?= $(KUBECTL) -n argocd
KUBECTL_NS ?= $(KUBECTL) -n $(K8S_NAMESPACE)
MDM_SOURCE_IMAGE_REPOSITORY ?= pos-mdm-source
MDM_SOURCE_IMAGE_TAG ?= 0.1.0
MDM_TOPICS ?= mdm_customer mdm_product
OPENMETADATA_INGEST_CONTAINER ?= openmetadata-ingestion
OPENMETADATA_PROFILE ?= --profile openmetadata
OPENMETADATA_STATUS_SERVICES ?= openmetadata-server openmetadata-ingestion
OPENMETADATA_UP_SERVICES ?= openmetadata-db openmetadata-search openmetadata-server openmetadata-ingestion
OPENMETADATA_WORKFLOW_BASE ?= /opt/openmetadata/metadata/workflows
SCHEMA_INIT_IMAGE_REPOSITORY ?= schema-init
SCHEMA_INIT_IMAGE_TAG ?= latest
TRINO_SMOKE_URL ?= http://localhost:8086/v1/info
UI_PORT_FORWARDS ?= \
	airflow=18080:8080 \
	trino=18081:8080 \
	conduktor=18082:8080 \
	grafana=3000:3000 \
	prometheus=9090:9090 \
	openmetadata=8585:8585 \
	minio=9001:9001

define kafka_consume_topic
	$(DOCKER_COMPOSE) exec $(KAFKA_CONSUMER_CONTAINER) $(KAFKA_CONSOLE_CONSUMER) --bootstrap-server $(KAFKA_BOOTSTRAP_SERVER) --topic $(1) --max-messages 3 --timeout-ms $(KAFKA_CONSUMER_TIMEOUT_MS)
endef

define kafka_consume_topic_from_beginning
	$(DOCKER_COMPOSE) exec $(KAFKA_CONSUMER_CONTAINER) $(KAFKA_CONSOLE_CONSUMER) --bootstrap-server $(KAFKA_BOOTSTRAP_SERVER) --topic $(1) --from-beginning --max-messages 1 --timeout-ms $(KAFKA_CONSUMER_TIMEOUT_MS)
endef

define compose_logs
	$(DOCKER_COMPOSE) logs --tail=$(COMPOSE_LOG_TAIL) $(1)
endef

define compose_exec
	$(DOCKER_COMPOSE) exec $(1) $(2)
endef

define compose_exec_t
	$(DOCKER_COMPOSE) exec -T $(1) $(2)
endef

define openmetadata_ingest
	$(DOCKER_COMPOSE) $(OPENMETADATA_PROFILE) exec -T $(OPENMETADATA_INGEST_CONTAINER) metadata ingest -c $(OPENMETADATA_WORKFLOW_BASE)/$(1)_ingestion.yaml
endef

define k8s_register_connector
	bash ./cicd/scripts/register-$(1)-connectors.sh --k8s $(K8S_NAMESPACE) $(K8S_RELEASE)-vision-$(1)-connect --url $(K8S_CONNECT_URL)
endef

.PHONY: help compose-up compose-down compose-clean mdm-status mdm-topics-check mdm-flow-check \
	dbt-run airflow-logs airflow-trigger-dbt-dag ops-status verify-dbt-relations trino-smoke \
	dbt-logs openmetadata-up openmetadata-status \
	openmetadata-prepare-dbt-artifacts openmetadata-ingest-trino openmetadata-ingest-postgres \
	openmetadata-ingest-dbt openmetadata-ingest-airflow openmetadata-ingest-kafka \
	local-procedure-up local-procedure-check metadata-procedure-run \
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
	$(call compose_exec,dbz-connect,curl -fsS $(DBZ_CONNECT_STATUS_URL) | cat)

# Consume sample messages from curated MDM topics
mdm-topics-check:
	@for topic in $(MDM_TOPICS); do \
		echo "[mdm-topics-check] topic=$$topic recent-window"; \
		out="$$( $(call kafka_consume_topic,$$topic) 2>/dev/null || true )"; \
		if [ -n "$$out" ]; then \
			echo "$$out"; \
			echo "[mdm-topics-check] PASS topic=$$topic source=recent-window"; \
			continue; \
		fi; \
		echo "[mdm-topics-check] topic=$$topic fallback=from-beginning"; \
		out="$$( $(call kafka_consume_topic_from_beginning,$$topic) 2>/dev/null || true )"; \
		if [ -n "$$out" ]; then \
			echo "$$out"; \
			echo "[mdm-topics-check] PASS topic=$$topic source=from-beginning"; \
		else \
			echo "[mdm-topics-check] WARN topic=$$topic no messages observed"; \
		fi; \
	done

# Run complete MDM event-flow validation
mdm-flow-check: mdm-status mdm-topics-check


###############################################################################
# METADATA OPS
###############################################################################

# Compose analytics helpers
dbt-run:
	$(DOCKER_COMPOSE) run --rm dbt

# Compose log helpers
dbt-logs:
	$(call compose_logs,dbt)

# Tail Airflow logs for quick DAG troubleshooting
airflow-logs:
	$(call compose_logs,airflow)

# Airflow operational helper
airflow-trigger-dbt-dag:
	$(call compose_exec,airflow,airflow dags trigger $(AIRFLOW_DAG_ID))

# Quick compose-side status snapshot
ops-status:
	$(DOCKER_COMPOSE) ps

# Warehouse relation health check
verify-dbt-relations:
	$(DOCKER_COMPOSE) exec -T snowflake-mimic psql -U analytics -d analytics -c "SELECT schemaname, count(*) AS relation_count FROM pg_catalog.pg_tables WHERE schemaname IN ('landing','bronze','silver','gold') GROUP BY schemaname ORDER BY schemaname;"

# Validate Trino coordinator endpoint
trino-smoke:
	curl -fsS $(TRINO_SMOKE_URL) | cat

# OpenMetadata lifecycle
openmetadata-up:
	$(DOCKER_COMPOSE) $(OPENMETADATA_PROFILE) up -d $(OPENMETADATA_UP_SERVICES)

# Check OpenMetadata stack status
openmetadata-status:
	$(DOCKER_COMPOSE) $(OPENMETADATA_PROFILE) ps $(OPENMETADATA_STATUS_SERVICES)

# dbt artifacts for metadata ingestion
openmetadata-prepare-dbt-artifacts:
	$(DOCKER_COMPOSE) run --rm dbt dbt deps
	$(DOCKER_COMPOSE) run --rm dbt dbt parse

# OpenMetadata ingestion workflows
openmetadata-ingest-trino:
	$(call openmetadata_ingest,trino)

# Run OpenMetadata Postgres ingestion workflow
openmetadata-ingest-postgres:
	$(call openmetadata_ingest,postgres)

# Run OpenMetadata dbt ingestion workflow
openmetadata-ingest-dbt:
	$(call openmetadata_ingest,dbt)

# Run OpenMetadata Airflow ingestion workflow
openmetadata-ingest-airflow:
	$(call openmetadata_ingest,airflow)

# Run OpenMetadata Kafka ingestion workflow
openmetadata-ingest-kafka:
	$(call openmetadata_ingest,kafka)

# Local compose workflow: start stack then validate core MDM + Trino checks
local-procedure-up: compose-up mdm-flow-check trino-smoke

# Local compose quick health checks only
local-procedure-check: mdm-status trino-smoke verify-dbt-relations

# Metadata workflow: bring up OpenMetadata and run all ingestion jobs
metadata-procedure-run: openmetadata-up openmetadata-status openmetadata-prepare-dbt-artifacts \
	openmetadata-ingest-trino openmetadata-ingest-postgres openmetadata-ingest-dbt \
	openmetadata-ingest-airflow openmetadata-ingest-kafka


###############################################################################
# K8S OPS
###############################################################################

# kind bootstrap
k8s-kind-bootstrap:
	@if kind get clusters | grep -qx "$(KIND_CLUSTER)"; then \
		echo "kind cluster '$(KIND_CLUSTER)' already exists, skipping bootstrap"; \
	else \
		CLUSTER_NAME=$(KIND_CLUSTER) ./cicd/k8s/kind/bootstrap-kind.sh; \
	fi

# Build/load runtime images into kind
k8s-build-images:
	CLUSTER_NAME=$(KIND_CLUSTER) \
	MDM_SOURCE_IMAGE=$(MDM_SOURCE_IMAGE_REPOSITORY):$(MDM_SOURCE_IMAGE_TAG) \
	SCHEMA_INIT_IMAGE=$(SCHEMA_INIT_IMAGE_REPOSITORY):$(SCHEMA_INIT_IMAGE_TAG) \
	./cicd/scripts/build-images.sh

# Helm dependency management
helm-deps:
	./cicd/k8s/helm/scripts/helm-deps.sh

# Helm template preview
helm-template:
	helm template $(K8S_RELEASE) $(HELM_CHART) -n $(K8S_NAMESPACE) -f $(HELM_VALUES)

# Helm install/upgrade
helm-up: helm-deps
	-$(KUBECTL_NS) delete job $(HELM_RESET_JOBS) --ignore-not-found
	helm upgrade --install $(K8S_RELEASE) $(HELM_CHART) -n $(K8S_NAMESPACE) --create-namespace -f $(HELM_VALUES) --timeout $(HELM_TIMEOUT) \
		$(HELM_SET_ARGS)

# Dev reboot helper (helm + status)
helm-reboot-dev:
	$(MAKE) K8S_ENV=dev helm-up
	$(MAKE) K8S_ENV=dev k8s-status

# Dev health snapshot
helm-health-dev:
	$(MAKE) K8S_ENV=dev k8s-status

# Dev Iceberg JDBC metastore migration helper
helm-metastore-migrate-dev:
	$(KUBECTL) -n gndp-dev exec deploy/gndp-dev-vision-snowflake-mimic -- psql -U analytics -d analytics -c "CREATE TABLE IF NOT EXISTS public.iceberg_tables (catalog_name text NOT NULL, table_namespace text NOT NULL, table_name text NOT NULL, metadata_location text NOT NULL, previous_metadata_location text, PRIMARY KEY (catalog_name, table_namespace, table_name));"
	$(KUBECTL) -n gndp-dev exec deploy/gndp-dev-vision-snowflake-mimic -- psql -U analytics -d analytics -c "CREATE TABLE IF NOT EXISTS public.iceberg_namespace_properties (catalog_name text NOT NULL, namespace text NOT NULL, property_key text NOT NULL, property_value text, PRIMARY KEY (catalog_name, namespace, property_key));"
	$(KUBECTL) -n gndp-dev rollout restart deployment/gndp-dev-vision-trino deployment/gndp-dev-vision-iceberg-writer

# Helm teardown
helm-down:
	-helm uninstall $(K8S_RELEASE) -n $(K8S_NAMESPACE)
	-$(KUBECTL) delete namespace $(K8S_NAMESPACE) --ignore-not-found

# Full k8s cleanup
k8s-cleanup:
	-$(MAKE) helm-down
	-kind delete cluster --name $(KIND_CLUSTER)

# Argo CD apply
k8s-argocd-apply:
	$(KUBECTL) apply -f $(ARGO_APP_MANIFEST)
	$(KUBECTL_ARGOCD) get application $(K8S_RELEASE)

# Namespace health snapshot
k8s-status:
	$(KUBECTL_NS) get pods
	$(KUBECTL_NS) get jobs

# Connector registration helpers
k8s-register-dbz:
	$(call k8s_register_connector,dbz)

# Register MDM connectors in the in-cluster MDM Connect deployment
k8s-register-mdm:
	$(call k8s_register_connector,mdm)

# Register ODS connectors in the in-cluster ODS Connect deployment
k8s-register-ods:
	$(call k8s_register_connector,ods)

# Register all connector sets
k8s-register-connectors: k8s-register-dbz k8s-register-mdm k8s-register-ods

# UI port-forwards (Ctrl+C to stop)
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

# Routine B up
k8s-routine-up: k8s-kind-bootstrap k8s-build-images helm-up k8s-status

# Routine B down
k8s-routine-down: k8s-cleanup
