###############################################################################
# DOCKER-RELATED TARGETS ONLY
###############################################################################

.PHONY: docker-build docker-compose-up docker-compose-down docker-clean images mdm-status mdm-topics-check mdm-flow-check

# Build all Docker images
docker-build:
	docker build -t realtime-sales-producer:0.1.0 ./producer
	docker build -t realtime-sales-processor:0.1.0 ./processor
	docker build -t realtime-sales-connect:0.1.0 ./ods-connect
	docker build -t realtime-sales-dbt:0.1.0 ./analytics/dbt
	docker build -t realtime-sales-airflow:0.1.0 ./airflow
	docker build -t realtime-sales-mdm-writer:0.1.0 ./mdm-writer
	docker build -t realtime-sales-mdm-cdc-producer:0.1.0 ./mdm-cdc-producer
	docker build -t realtime-sales-mdm-pyspark-sync:0.1.0 ./mdm-pyspark-sync
	docker build -t realtime-sales-iceberg-writer:0.1.0 ./iceberg-writer

# Start all services using Docker Compose
docker-compose-up:
	docker compose up -d

# Stop all services using Docker Compose
docker-compose-down:
	docker compose down

# Remove stopped containers, dangling images, and unused volumes
docker-clean:
	docker compose down -v --remove-orphans
	docker system prune -f

# Build and load all images (alias for docker-build)
images: docker-build

# Show health for MDM CDC pipeline services and Debezium connector status
mdm-status:
	docker compose ps mdm_source mdm-writer mdm-connect mdm-connect-init mdm-cdc-producer
	@echo ""
	@echo "Debezium connector status (expects RUNNING):"
	docker compose exec mdm-connect curl -fsS http://localhost:8083/connectors/debezium-mysql-mdm/status | cat

# Consume sample messages from curated MDM topics
mdm-topics-check:
	docker compose exec kafka /usr/bin/kafka-console-consumer --bootstrap-server kafka:9092 --topic mdm_customer --max-messages 3 --timeout-ms 15000
	docker compose exec kafka /usr/bin/kafka-console-consumer --bootstrap-server kafka:9092 --topic mdm_product --max-messages 3 --timeout-ms 15000

# Run complete MDM event-flow validation
mdm-flow-check: mdm-status mdm-topics-check
