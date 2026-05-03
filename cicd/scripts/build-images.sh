#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-realtime-dev}"
PRODUCER_IMAGE="${PRODUCER_IMAGE:-pos-producer:0.1.0}"
PROCESSOR_IMAGE="${PROCESSOR_IMAGE:-pos-processor:0.1.0}"
CONNECT_IMAGE="${CONNECT_IMAGE:-pos-connect:0.1.0}"
DBT_IMAGE="${DBT_IMAGE:-pos-dbt:0.1.0}"
AIRFLOW_IMAGE="${AIRFLOW_IMAGE:-pos-airflow:0.1.0}"
ICEBERG_WRITER_IMAGE="${ICEBERG_WRITER_IMAGE:-pos-iceberg-writer:0.1.0}"
mdm_cdc_curate_IMAGE="${mdm_cdc_curate_IMAGE:-pos-mdm-cdc-curate:0.1.0}"
mdm_rds_pg_IMAGE="${mdm_rds_pg_IMAGE:-pos-mdm-pyspark-sync:0.1.0}"

docker build -t "${PRODUCER_IMAGE}" ./source-apps/ods-source
docker build -t "${PROCESSOR_IMAGE}" ./process-apps/ods-processor
docker build -t "${CONNECT_IMAGE}" ./kafka-connect/ods-connect
docker build -t "${DBT_IMAGE}" ./analytics/dbt
docker build -t "${AIRFLOW_IMAGE}" ./platform-services/airflow
docker build -t "${ICEBERG_WRITER_IMAGE}" ./process-apps/iceberg-writer
docker build -t "${mdm_cdc_curate_IMAGE}" ./process-apps/mdm-cdc-curate
docker build -t "${mdm_rds_pg_IMAGE}" ./process-apps/mdm-rds-pg

kind load docker-image --name "${CLUSTER_NAME}" "${PRODUCER_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${PROCESSOR_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${CONNECT_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${DBT_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${AIRFLOW_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${ICEBERG_WRITER_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${mdm_cdc_curate_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${mdm_rds_pg_IMAGE}"

echo "Images loaded into kind cluster '${CLUSTER_NAME}'"