#!/usr/bin/env bash

# Initialize common script context variables.
# Must be called from the script after sourcing this file.
init_script_env() {
  local script_path
  script_path="${BASH_SOURCE[1]}"

  SCRIPT_NAME="$(basename "$script_path")"
  SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"
  ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

  init_run_id
}

init_run_id() {
  if [[ -n "${RUN_ID:-}" ]]; then
    LOG_RUN_ID="$RUN_ID"
  elif [[ -n "${CI_JOB_ID:-}" ]]; then
    LOG_RUN_ID="$CI_JOB_ID"
  elif [[ -n "${GITHUB_RUN_ID:-}" ]]; then
    if [[ -n "${GITHUB_RUN_ATTEMPT:-}" ]]; then
      LOG_RUN_ID="${GITHUB_RUN_ID}.${GITHUB_RUN_ATTEMPT}"
    else
      LOG_RUN_ID="$GITHUB_RUN_ID"
    fi
  elif [[ -n "${BUILD_BUILDID:-}" ]]; then
    LOG_RUN_ID="$BUILD_BUILDID"
  elif [[ -n "${CI_PIPELINE_ID:-}" ]]; then
    LOG_RUN_ID="$CI_PIPELINE_ID"
  else
    LOG_RUN_ID="local-$(date +%Y%m%dT%H%M%S)-$$"
  fi

  export RUN_ID="$LOG_RUN_ID"
}

log_info() { printf 'INFO|%s|run_id=%s|%s\n' "$SCRIPT_NAME" "$LOG_RUN_ID" "$*"; }
log_warn() { printf 'WARN|%s|run_id=%s|%s\n' "$SCRIPT_NAME" "$LOG_RUN_ID" "$*"; }
log_error() { printf 'ERROR|%s|run_id=%s|%s\n' "$SCRIPT_NAME" "$LOG_RUN_ID" "$*" >&2; }

require_commands() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_error "Required command not found: $cmd"
      return 1
    fi
  done
}
