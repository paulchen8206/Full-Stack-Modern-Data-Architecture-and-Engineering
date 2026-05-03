###############################################################################
# DOCKER-RELATED TARGETS ONLY
###############################################################################

.PHONY: compose-build compose-up compose-down compose-clean images mdm-status mdm-topics-check mdm-flow-check

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
