#!/usr/bin/env bash

run_scope_wrapper() {
  local scope="$1"
  local connect_url="$2"
  local canonical_script="$3"
  shift 3

  if [[ ! -f "$canonical_script" ]]; then
    log_error "Canonical script not found: $canonical_script"
    exit 1
  fi

  log_info "Delegating to canonical script scope=$scope url=$connect_url"
  exec bash "$canonical_script" --scope "$scope" --url "$connect_url" "$@"
}
