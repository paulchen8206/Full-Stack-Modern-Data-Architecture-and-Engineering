#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

SCRIPT_NAME="$(basename "$0")"
RUN_ID="local-$(date +%Y%m%dT%H%M%S)-$$"

log_info() { printf 'INFO|%s|run_id=%s|%s\n' "$SCRIPT_NAME" "$RUN_ID" "$*"; }
log_warn() { printf 'WARN|%s|run_id=%s|%s\n' "$SCRIPT_NAME" "$RUN_ID" "$*"; }
log_error() { printf 'ERROR|%s|run_id=%s|%s\n' "$SCRIPT_NAME" "$RUN_ID" "$*" >&2; }

require_commands() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_error "Required command not found: $cmd"
      exit 1
    fi
  done
}

wait_for_registry() {
  local attempts=0
  if [[ "$SCHEMA_REGISTRY_WAIT" != "true" ]]; then
    return 0
  fi

  log_info "Waiting for schema registry url=$SCHEMA_REGISTRY_URL"
  until curl -fsS "$SCHEMA_REGISTRY_URL/subjects" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ "$SCHEMA_REGISTRY_WAIT_MAX_ATTEMPTS" -gt 0 && "$attempts" -ge "$SCHEMA_REGISTRY_WAIT_MAX_ATTEMPTS" ]]; then
      log_error "Schema registry wait timed out attempts=$attempts url=$SCHEMA_REGISTRY_URL"
      exit 1
    fi
    sleep "$SCHEMA_REGISTRY_WAIT_INTERVAL_SEC"
  done

  log_info "Schema registry is ready url=$SCHEMA_REGISTRY_URL"
}

subject_from_path() {
  local avsc_file="$1"
  basename "$avsc_file" .avsc
}

register_schema() {
  local subject="$1"
  local avsc_file="$2"
  local subject_name
  local schema_json
  local payload
  local response_file
  local response_body
  local http_code

  subject_name="${subject}${SCHEMA_SUBJECT_SUFFIX}"
  schema_json="$(jq -c . "$avsc_file")"
  payload="$(jq -nc --arg schema "$schema_json" --arg schemaType "AVRO" '{schema: $schema, schemaType: $schemaType}')"

  response_file="$(mktemp)"
  http_code="$(curl -sS -o "$response_file" -w '%{http_code}' -X POST \
    -H 'Content-Type: application/vnd.schemaregistry.v1+json' \
    --data "$payload" \
    "$SCHEMA_REGISTRY_URL/subjects/${subject_name}/versions")"

  response_body="$(tr '\n' ' ' <"$response_file" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  rm -f "$response_file"

  if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
    log_info "Schema registered subject=$subject_name http_code=$http_code"
    return 0
  fi

  if [[ -n "$response_body" ]]; then
    log_error "Schema registration failed subject=$subject_name http_code=$http_code detail=$response_body"
  else
    log_error "Schema registration failed subject=$subject_name http_code=$http_code"
  fi
  return 1
}

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SCHEMAS_DIR="$(cd "$SELF_DIR/../avro" >/dev/null 2>&1 && pwd)"

SCHEMA_REGISTRY_URL="${SCHEMA_REGISTRY_URL:-http://schema-registry:8081}"
SCHEMAS_DIR="${SCHEMAS_DIR:-$DEFAULT_SCHEMAS_DIR}"
SCHEMA_SUBJECT_SUFFIX="${SCHEMA_SUBJECT_SUFFIX:--value}"
SCHEMA_REGISTRY_WAIT="${SCHEMA_REGISTRY_WAIT:-true}"
SCHEMA_REGISTRY_WAIT_INTERVAL_SEC="${SCHEMA_REGISTRY_WAIT_INTERVAL_SEC:-2}"
SCHEMA_REGISTRY_WAIT_MAX_ATTEMPTS="${SCHEMA_REGISTRY_WAIT_MAX_ATTEMPTS:-0}"

require_commands jq curl sort mktemp tr sed

if [[ ! -d "$SCHEMAS_DIR" ]]; then
  log_error "Schemas directory does not exist: $SCHEMAS_DIR"
  exit 1
fi

wait_for_registry

schema_files=()
while IFS= read -r schema_file; do
  schema_files+=("$schema_file")
done < <(find "$SCHEMAS_DIR" -maxdepth 1 -type f -name '*.avsc' | sort)
if [[ ${#schema_files[@]} -eq 0 ]]; then
  log_warn "No .avsc files found dir=$SCHEMAS_DIR"
  exit 0
fi

log_info "Starting schema registration dir=$SCHEMAS_DIR count=${#schema_files[@]} url=$SCHEMA_REGISTRY_URL"

failures=0
for avsc_file in "${schema_files[@]}"; do
  subject="$(subject_from_path "$avsc_file")"
  log_info "Registering schema subject=$subject file=$avsc_file"
  if ! register_schema "$subject" "$avsc_file"; then
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -gt 0 ]]; then
  log_error "Schema registration completed failures=$failures"
  exit 1
fi

log_info "Completed schema registration failures=0"
