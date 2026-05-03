###############################################################################
# DOCKER + K8S/HELM ROUTINES
###############################################################################

K8S_ENV ?= dev
KIND_CLUSTER ?= gndp-dev
K8S_NAMESPACE ?= gndp-$(K8S_ENV)
K8S_RELEASE ?= gndp-$(K8S_ENV)
IMAGE_TAG ?= 0.1.0
COMPOSE_BUILD_TARGETS ?= \
	pos-producer=./source-apps/ods-source \
	pos-processor=./process-apps/ods-processor \
	pos-ods-connect=./kafka-connect/ods-connect \
	pos-dbt=./analytics/dbt \
	pos-airflow=./platform-services/airflow \
	pos-mdm-cdc-curate=./process-apps/mdm-cdc-curate \
	pos-mdm-rds-pg=./process-apps/mdm-rds-pg \
	pos-iceberg-writer=./process-apps/iceberg-writer
DOCKER_COMPOSE ?= docker compose
DBZ_CONNECT_STATUS_URL ?= http://localhost:8083/connectors/dbz-mysql-mdm/status
KAFKA_CONSUMER_CONTAINER ?= kafka-3
KAFKA_BOOTSTRAP_SERVER ?= kafka-3:19094
KAFKA_CONSOLE_CONSUMER ?= /usr/bin/kafka-console-consumer
KUBECTL ?= kubectl
KUBECTL_NS ?= $(KUBECTL) -n $(K8S_NAMESPACE)
KUBECTL_ARGOCD ?= $(KUBECTL) -n argocd
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
SCHEMA_INIT_IMAGE_REPOSITORY ?= pos-schema-init
SCHEMA_INIT_IMAGE_TAG ?= latest

.PHONY: compose-build compose-up compose-down compose-clean images mdm-status mdm-topics-check mdm-flow-check \
	k8s-kind-bootstrap k8s-build-images helm-deps helm-template helm-up helm-down k8s-ui-port-forward \
	k8s-argocd-apply k8s-status k8s-routine-up k8s-routine-down

# Build all Docker images
compose-build:
	@for target in $(COMPOSE_BUILD_TARGETS); do \
		image="$${target%%=*}"; \
		context="$${target#*=}"; \
		docker build -t "$${image}:$(IMAGE_TAG)" "$${context}"; \
	done

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
	$(DOCKER_COMPOSE) ps mdm_source dbz-connect dbz-connect-init mdm-connect mdm-connect-init mdm-cdc-curate
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

# Remove platform chart and namespace resources
helm-down:
	-helm uninstall $(K8S_RELEASE) -n $(K8S_NAMESPACE)
	-$(KUBECTL) delete namespace $(K8S_NAMESPACE) --ignore-not-found

# Apply Argo CD application manifest for the selected environment
k8s-argocd-apply:
	$(KUBECTL) apply -f $(ARGO_APP_MANIFEST)
	$(KUBECTL_ARGOCD) get application $(K8S_RELEASE)

# Snapshot workload health in the selected namespace
k8s-status:
	$(KUBECTL_NS) get pods
	$(KUBECTL_NS) get jobs

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
k8s-routine-down: helm-down
