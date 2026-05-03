#!/usr/bin/env bash

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SELF_DIR/lib/common.sh"
init_script_env

require_commands docker kind

CLUSTER_NAME="${CLUSTER_NAME:-gndp-dev}"

IMAGE_SPECS=(
	"AIRFLOW_IMAGE|pos-airflow:0.1.0|platform-services/airflow"
	"DBT_IMAGE|pos-dbt:0.1.0|analytics/dbt"
	"DBZ_CONNECT_IMAGE|pos-dbz-connect:0.1.0|kafka-connect/dbz-connect"
	"ICEBERG_WRITER_IMAGE|pos-iceberg-writer:0.1.0|process-apps/iceberg-writer"
	"MDM_CDC_CURATE_IMAGE|pos-mdm-cdc-curate:0.1.0|process-apps/mdm-cdc-curate"
	"MDM_CONNECT_IMAGE|pos-mdm-connect:0.1.0|kafka-connect/mdm-connect"
	"MDM_SOURCE_IMAGE|pos-mdm-source:0.1.0|source-apps/mdm-source"
	"MDM_RDS_PG_IMAGE|pos-mdm-rds-pg:0.1.0|process-apps/mdm-rds-pg"
	"ODS_CONNECT_IMAGE|pos-ods-connect:0.1.0|kafka-connect/ods-connect"
	"PROCESSOR_IMAGE|pos-processor:0.1.0|process-apps/ods-processor"
	"PRODUCER_IMAGE|pos-producer:0.1.0|source-apps/ods-source"
	"SCHEMA_INIT_IMAGE|pos-schema-init:latest|.|platform-services/schemas/Dockerfile"
)

IMAGES=()

for spec in "${IMAGE_SPECS[@]}"; do
	IFS='|' read -r env_name default_image context_rel dockerfile_rel <<< "$spec"
	image="$default_image"
	if [[ -n "${!env_name-}" ]]; then
		image="${!env_name}"
	fi

	context="$ROOT_DIR/$context_rel"
	if [[ -n "${dockerfile_rel:-}" ]]; then
		dockerfile="$ROOT_DIR/$dockerfile_rel"
		log_info "Building image=$image context=$context dockerfile=$dockerfile"
		docker build -t "$image" -f "$dockerfile" "$context"
	else
		log_info "Building image=$image context=$context"
		docker build -t "$image" "$context"
	fi
	IMAGES+=("$image")
done

for image in "${IMAGES[@]}"; do
	log_info "Loading image=$image cluster=$CLUSTER_NAME"
	kind load docker-image --name "$CLUSTER_NAME" "$image"
done

log_info "Completed image load cluster=$CLUSTER_NAME total_images=${#IMAGES[@]}"