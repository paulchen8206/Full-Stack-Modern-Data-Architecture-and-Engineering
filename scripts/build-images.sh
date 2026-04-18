#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-realtime-dev}"
PRODUCER_IMAGE="${PRODUCER_IMAGE:-realtime-sales-producer:0.1.0}"
PROCESSOR_IMAGE="${PROCESSOR_IMAGE:-realtime-sales-processor:0.1.0}"
CONNECT_IMAGE="${CONNECT_IMAGE:-realtime-sales-connect:0.1.0}"
DBT_IMAGE="${DBT_IMAGE:-realtime-sales-dbt:0.1.0}"
AIRFLOW_IMAGE="${AIRFLOW_IMAGE:-realtime-sales-airflow:0.1.0}"

docker build -t "${PRODUCER_IMAGE}" ./producer
docker build -t "${PROCESSOR_IMAGE}" ./processor
docker build -t "${CONNECT_IMAGE}" ./connect
docker build -t "${DBT_IMAGE}" ./analytics/dbt
docker build -t "${AIRFLOW_IMAGE}" ./airflow

kind load docker-image --name "${CLUSTER_NAME}" "${PRODUCER_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${PROCESSOR_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${CONNECT_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${DBT_IMAGE}"
kind load docker-image --name "${CLUSTER_NAME}" "${AIRFLOW_IMAGE}"

echo "Images loaded into kind cluster '${CLUSTER_NAME}'"