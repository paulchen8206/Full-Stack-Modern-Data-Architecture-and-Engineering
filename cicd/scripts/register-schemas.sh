#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SELF_DIR/lib/common.sh"
source "$SELF_DIR/lib/registration.sh"
init_script_env

# Schema Registry URL (override with env var if needed)
SCHEMA_REGISTRY_URL="${SCHEMA_REGISTRY_URL:-http://gndp-dev-vision-schema-registry:8081}"
# Schemas directory (relative to project root by default)
SCHEMAS_DIR="${SCHEMAS_DIR:-$ROOT_DIR/platform-services/schemas/avro}"
SCHEMA_REGISTRY_WAIT="${SCHEMA_REGISTRY_WAIT:-false}"
SCHEMA_REGISTRY_WAIT_INTERVAL_SEC="${SCHEMA_REGISTRY_WAIT_INTERVAL_SEC:-2}"
SCHEMA_REGISTRY_WAIT_MAX_ATTEMPTS="${SCHEMA_REGISTRY_WAIT_MAX_ATTEMPTS:-0}"

require_commands jq curl

if [[ "$SCHEMA_REGISTRY_WAIT" == "true" ]]; then
  log_info "Waiting for schema registry url=$SCHEMA_REGISTRY_URL"
  attempts=0
  until curl -fsS "$SCHEMA_REGISTRY_URL/subjects" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ "$SCHEMA_REGISTRY_WAIT_MAX_ATTEMPTS" -gt 0 && "$attempts" -ge "$SCHEMA_REGISTRY_WAIT_MAX_ATTEMPTS" ]]; then
      log_error "Schema registry wait timed out attempts=$attempts url=$SCHEMA_REGISTRY_URL"
      exit 1
    fi
    sleep "$SCHEMA_REGISTRY_WAIT_INTERVAL_SEC"
  done
  log_info "Schema registry is ready url=$SCHEMA_REGISTRY_URL"
fi

if [[ ! -d "$SCHEMAS_DIR" ]]; then
  log_error "Schemas directory does not exist: $SCHEMAS_DIR"
  exit 1
fi

schema_files=("$SCHEMAS_DIR"/*.avsc)
if [[ ${#schema_files[@]} -eq 0 ]]; then
  log_warn "No .avsc files found dir=$SCHEMAS_DIR"
  exit 0
fi

log_info "Starting schema registration dir=$SCHEMAS_DIR count=${#schema_files[@]} url=$SCHEMA_REGISTRY_URL"
failures=0

for avsc_file in "${schema_files[@]}"; do
  subject=$(schema_subject_from_file "$avsc_file")
  log_info "Registering schema subject=$subject file=$avsc_file"

  if http_code=$(register_schema_file "$SCHEMA_REGISTRY_URL" "$subject" "$avsc_file"); then
    log_info "Schema registered subject=$subject http_code=$http_code"
  else
    log_error "Schema registration failed subject=$subject http_code=$http_code"
    failures=$((failures + 1))
  fi
done

if [[ $failures -gt 0 ]]; then
  log_error "Schema registration completed failures=$failures"
  exit 1
fi

log_info "Completed schema registration failures=0"
