#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-edw-dev}"
AIRFLOW_IMAGE="${AIRFLOW_IMAGE:-pos-airflow:0.1.0}"
DBT_IMAGE="${DBT_IMAGE:-pos-dbt:0.1.0}"
DBZ_CONNECT_IMAGE="${DBZ_CONNECT_IMAGE:-pos-dbz-connect:0.1.0}"
ICEBERG_WRITER_IMAGE="${ICEBERG_WRITER_IMAGE:-pos-iceberg-writer:0.1.0}"
MDM_CDC_CURATE_IMAGE="${MDM_CDC_CURATE_IMAGE:-pos-mdm-cdc-curate:0.1.0}"
MDM_CONNECT_IMAGE="${MDM_CONNECT_IMAGE:-pos-mdm-connect:0.1.0}"
MDM_SOURCE_IMAGE="${MDM_SOURCE_IMAGE:-pos-mdm-source:0.1.0}"
MDM_RDS_PG_IMAGE="${MDM_RDS_PG_IMAGE:-pos-mdm-pyspark-sync:0.1.0}"
ODS_CONNECT_IMAGE="${ODS_CONNECT_IMAGE:-pos-ods-connect:0.1.0}"
PROCESSOR_IMAGE="${PROCESSOR_IMAGE:-pos-processor:0.1.0}"
PRODUCER_IMAGE="${PRODUCER_IMAGE:-pos-producer:0.1.0}"
SCHEMA_INIT_IMAGE="${SCHEMA_INIT_IMAGE:-schema-init:latest}"


docker build -t "${AIRFLOW_IMAGE}" ./platform-services/airflow
docker build -t "${DBT_IMAGE}" ./analytics/dbt
docker build -t "${DBZ_CONNECT_IMAGE}" ./kafka-connect/dbz-connect
docker build -t "${ICEBERG_WRITER_IMAGE}" ./process-apps/iceberg-writer
docker build -t "${MDM_CDC_CURATE_IMAGE}" ./process-apps/mdm-cdc-curate
docker build -t "${MDM_CONNECT_IMAGE}" ./kafka-connect/mdm-connect
docker build -t "${MDM_SOURCE_IMAGE}" ./source-apps/mdm-source
docker build -t "${MDM_RDS_PG_IMAGE}" ./process-apps/mdm-rds-pg
docker build -t "${ODS_CONNECT_IMAGE}" ./kafka-connect/ods-connect
docker build -t "${PROCESSOR_IMAGE}" ./process-apps/ods-processor
docker build -t "${PRODUCER_IMAGE}" ./source-apps/ods-source
docker build -t "${SCHEMA_INIT_IMAGE}" ./platform-services/schemas


kind load docker-image --name "${CLUSTER_NAME}" "${AIRFLOW_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${DBT_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${DBZ_CONNECT_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${ICEBERG_WRITER_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${MDM_CDC_CURATE_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${MDM_CONNECT_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${MDM_SOURCE_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${MDM_RDS_PG_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${ODS_CONNECT_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${PROCESSOR_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${PRODUCER_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${SCHEMA_INIT_IMAGE}"


echo "Images loaded into kind cluster '${CLUSTER_NAME}'"