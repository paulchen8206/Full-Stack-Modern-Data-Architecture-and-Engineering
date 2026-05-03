###############################################################################
# DOCKER + K8S/HELM ROUTINES
###############################################################################

K8S_ENV ?= dev
KIND_CLUSTER ?= edw-dev
K8S_NAMESPACE ?= edw-$(K8S_ENV)
K8S_RELEASE ?= edw-$(K8S_ENV)

HELM_CHART ?= ./cicd/charts
HELM_VALUES ?= ./cicd/k8s/helm/values/values-$(K8S_ENV).yaml
ARGO_APP_MANIFEST ?= ./cicd/argocd/$(K8S_ENV).yaml
HELM_TIMEOUT ?= 15m
MDM_SOURCE_IMAGE_REPOSITORY ?= pos-mdm-source
MDM_SOURCE_IMAGE_TAG ?= 0.1.0
SCHEMA_INIT_IMAGE_REPOSITORY ?= schema-init
SCHEMA_INIT_IMAGE_TAG ?= latest

.PHONY: compose-build compose-up compose-down compose-clean images mdm-status mdm-topics-check mdm-flow-check \
	k8s-kind-bootstrap k8s-build-images helm-deps helm-template helm-up helm-down \
	k8s-argocd-apply k8s-status k8s-routine-up k8s-routine-down

# Build all Docker images
compose-build:
	docker build -t pos-producer:0.1.0 ./source-apps/ods_source
	docker build -t pos-processor:0.1.0 ./process-apps/ods_processor
	docker build -t pos-connect:0.1.0 ./kafka-connect/ods-connect
	docker build -t pos-dbt:0.1.0 ./analytics/dbt
	docker build -t pos-airflow:0.1.0 ./platform-services/airflow
	docker build -t pos-mdm-cdc-curate:0.1.0 ./process-apps/mdm-cdc-curate
	docker build -t pos-mdm-pyspark-sync:0.1.0 ./process-apps/mdm-pyspark-sync
	docker build -t pos-iceberg-writer:0.1.0 ./process-apps/iceberg-writer

# Start all services using Docker Compose
compose-up:
	docker compose up -d

# Stop all services using Docker Compose
compose-down:
	docker compose down

# Remove stopped containers, dangling images, and unused volumes
compose-clean:
	docker compose down -v --remove-orphans
	docker system prune -f


# Show health for MDM CDC pipeline services and Debezium connector status
mdm-status:
	docker compose ps mdm_source dbz-connect dbz-connect-init mdm-connect mdm-connect-init mdm-cdc-curate
	@echo ""
	@echo "Debezium connector status (expects RUNNING):"
	docker compose exec dbz-connect curl -fsS http://localhost:8083/connectors/dbz-mysql-mdm/status | cat

# Consume sample messages from curated MDM topics
mdm-topics-check:
	docker compose exec kafka-3 /usr/bin/kafka-console-consumer --bootstrap-server kafka-3:19094 --topic mdm_customer --max-messages 3 --timeout-ms 15000
	docker compose exec kafka-3 /usr/bin/kafka-console-consumer --bootstrap-server kafka-3:19094 --topic mdm_product --max-messages 3 --timeout-ms 15000

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
	-kubectl -n $(K8S_NAMESPACE) delete job $(K8S_RELEASE)-vision-dbz-connect-init $(K8S_RELEASE)-vision-mdm-connect-init $(K8S_RELEASE)-vision-ods-connect-init $(K8S_RELEASE)-vision-dbt $(K8S_RELEASE)-vision-register-schemas-job --ignore-not-found
	helm upgrade --install $(K8S_RELEASE) $(HELM_CHART) -n $(K8S_NAMESPACE) --create-namespace -f $(HELM_VALUES) --timeout $(HELM_TIMEOUT) \
		--set mdm.source.image.repository=$(MDM_SOURCE_IMAGE_REPOSITORY) \
		--set mdm.source.image.tag=$(MDM_SOURCE_IMAGE_TAG) \
		--set schemaInit.image.repository=$(SCHEMA_INIT_IMAGE_REPOSITORY) \
		--set schemaInit.image.tag=$(SCHEMA_INIT_IMAGE_TAG)

# Remove platform chart and namespace resources
helm-down:
	-helm uninstall $(K8S_RELEASE) -n $(K8S_NAMESPACE)
	-kubectl delete namespace $(K8S_NAMESPACE) --ignore-not-found

# Apply Argo CD application manifest for the selected environment
k8s-argocd-apply:
	kubectl apply -f $(ARGO_APP_MANIFEST)
	kubectl -n argocd get application $(K8S_RELEASE)

# Snapshot workload health in the selected namespace
k8s-status:
	kubectl -n $(K8S_NAMESPACE) get pods
	kubectl -n $(K8S_NAMESPACE) get jobs

# Routine B: kind + image build/load + Helm deploy
k8s-routine-up: k8s-kind-bootstrap k8s-build-images helm-up k8s-status

# Routine B teardown: remove Helm release and namespace
k8s-routine-down: helm-down
