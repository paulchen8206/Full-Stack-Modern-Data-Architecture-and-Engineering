#!/usr/bin/env bash
# register-connectors-core.sh
# Internal core for connector registration workflows.
# Use scope-specific entrypoints:
#   ./cicd/scripts/register-dbz-connectors.sh
#   ./cicd/scripts/register-mdm-connectors.sh
#   ./cicd/scripts/register-ods-connectors.sh

set -euo pipefail
shopt -s nullglob

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SELF_DIR/lib/common.sh"
source "$SELF_DIR/lib/registration.sh"
init_script_env

NAME=""
CONFIG=""
CONNECT_URL="http://localhost:8083"
CONNECT_SCOPE="${CONNECT_SCOPE:-debezium}"
K8S_MODE=0
K8S_NAMESPACE=""
K8S_DEPLOYMENT=""
MODE="local"
MODE_PREFIX="mode=local "
CONNECT_WAIT_SECONDS="${CONNECT_WAIT_SECONDS:-0}"
CONNECT_WAIT_INTERVAL_SEC="${CONNECT_WAIT_INTERVAL_SEC:-2}"
CONNECT_UPSERT_RETRIES="${CONNECT_UPSERT_RETRIES:-5}"
CONNECT_UPSERT_RETRY_DELAY_SEC="${CONNECT_UPSERT_RETRY_DELAY_SEC:-3}"
ODS_DELETE_LEGACY_CONNECTOR="${ODS_DELETE_LEGACY_CONNECTOR:-true}"

usage() {
  log_error "Usage (single): $0 --config <config.json> [--name <connector-name>] [--url <connect-url>] [--k8s <namespace> <deployment>]"
  log_error "Usage (batch):  $0 --scope <debezium|mdm|ods|all> [--url <connect-url>] [--k8s <namespace> <deployment>]"
}

set_mode_context() {
  if [[ $K8S_MODE -eq 1 ]]; then
    MODE="k8s"
    MODE_PREFIX="mode=k8s "
  else
    MODE="local"
    MODE_PREFIX="mode=local "
  fi
}

ensure_connect_ready() {
  if [[ "$CONNECT_WAIT_SECONDS" -le 0 ]]; then
    return 0
  fi

  log_info "Waiting for Kafka Connect ${MODE_PREFIX}url=$CONNECT_URL timeout_s=$CONNECT_WAIT_SECONDS"
  if wait_for_connect_ready "$MODE" "$CONNECT_URL" "$K8S_NAMESPACE" "$K8S_DEPLOYMENT" "$CONNECT_WAIT_SECONDS" "$CONNECT_WAIT_INTERVAL_SEC"; then
    log_info "Kafka Connect is ready ${MODE_PREFIX}url=$CONNECT_URL"
  else
    log_error "Timed out waiting for Kafka Connect ${MODE_PREFIX}url=$CONNECT_URL timeout_s=$CONNECT_WAIT_SECONDS"
    exit 1
  fi
}

cleanup_legacy_ods_connector() {
  if [[ "$ODS_DELETE_LEGACY_CONNECTOR" != "true" ]]; then
    return 0
  fi

  local legacy_connector="jdbc-sales-warehouse"
  if delete_connector_if_exists "$MODE" "$CONNECT_URL" "$legacy_connector" "$K8S_NAMESPACE" "$K8S_DEPLOYMENT"; then
    log_info "Deleted legacy connector ${MODE_PREFIX}name=$legacy_connector"
  fi
}

register_single() {
  local config="$1"
  local name="$2"

  if [[ ! -f "$config" ]]; then
    log_error "Config file not found: $config"
    exit 1
  fi

  if [[ -z "$name" ]]; then
    name=$(connector_name_from_config "$config")
    if [[ -z "$name" ]]; then
      log_error "--name not provided and not found in config file"
      exit 1
    fi
  fi

  if ! jq empty "$config" 2>/dev/null; then
    log_error "Invalid JSON in $config"
    exit 1
  fi

  local connector_config
  local create_payload

  connector_config=$(connector_config_from_file "$config")
  create_payload=$(connector_create_payload "$name" "$connector_config")

  log_info "Starting connector registration ${MODE_PREFIX}name=$name url=$CONNECT_URL config=$config"

  local action
  action=$(upsert_connector "$name" "$connector_config" "$create_payload" "$CONNECT_URL" "$MODE" "$K8S_NAMESPACE" "$K8S_DEPLOYMENT" "$CONNECT_UPSERT_RETRIES" "$CONNECT_UPSERT_RETRY_DELAY_SEC")
  if [[ "$action" == "updated" ]]; then
    log_info "Connector updated ${MODE_PREFIX}name=$name"
  else
    log_info "Connector created ${MODE_PREFIX}name=$name"
  fi
}

register_batch() {
  local -a config_dirs

  case "$CONNECT_SCOPE" in
    debezium)
      config_dirs=("$ROOT_DIR/kafka-connect/dbz-connect/connector-configs")
      ;;
    mdm)
      config_dirs=("$ROOT_DIR/kafka-connect/mdm-connect/connector-configs")
      ;;
    ods)
      config_dirs=("$ROOT_DIR/kafka-connect/ods-connect/connector-configs")
      ;;
    all)
      config_dirs=(
        "$ROOT_DIR/kafka-connect/dbz-connect/connector-configs"
        "$ROOT_DIR/kafka-connect/mdm-connect/connector-configs"
        "$ROOT_DIR/kafka-connect/ods-connect/connector-configs"
      )
      ;;
    *)
      log_error "CONNECT_SCOPE must be one of: debezium, mdm, ods, all"
      exit 1
      ;;
  esac

  log_info "Starting connector batch registration scope=$CONNECT_SCOPE url=$CONNECT_URL"

  if [[ "$CONNECT_SCOPE" == "ods" || "$CONNECT_SCOPE" == "all" ]]; then
    cleanup_legacy_ods_connector
  fi

  local config_dir
  for config_dir in "${config_dirs[@]}"; do
    local -a configs
    configs=("$config_dir"/*.json)
    if [[ ${#configs[@]} -eq 0 ]]; then
      log_warn "No connector configs found dir=$config_dir"
      continue
    fi

    log_info "Processing connector configs dir=$config_dir count=${#configs[@]}"

    local config
    for config in "${configs[@]}"; do
      log_info "Registering connector config=$config"
      register_single "$config" ""
    done
  done

  log_info "Completed connector batch registration scope=$CONNECT_SCOPE"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --config)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      CONFIG="$2"
      shift 2
      ;;
    --name)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      NAME="$2"
      shift 2
      ;;
    --url)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      CONNECT_URL="$2"
      shift 2
      ;;
    --scope)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      CONNECT_SCOPE="$2"
      shift 2
      ;;
    --k8s)
      [[ $# -ge 3 ]] || { usage; exit 1; }
      K8S_MODE=1
      K8S_NAMESPACE="$2"
      K8S_DEPLOYMENT="$3"
      shift 3
      ;;
    *)
      log_error "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

require_commands jq curl

if [[ $K8S_MODE -eq 1 ]] && ! command -v kubectl >/dev/null 2>&1; then
  log_error "Required command not found: kubectl"
  exit 1
fi

set_mode_context
ensure_connect_ready

if [[ -n "$CONFIG" ]]; then
  register_single "$CONFIG" "$NAME"
else
  register_batch
fi
