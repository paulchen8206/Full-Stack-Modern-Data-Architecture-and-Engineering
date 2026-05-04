#!/usr/bin/env bash

connect_curl() {
  local mode="$1"
  local k8s_namespace="$2"
  local k8s_deployment="$3"
  shift 3

  if [[ "$mode" == "k8s" ]]; then
    kubectl exec -n "$k8s_namespace" deploy/"$k8s_deployment" -- curl -fsS "$@"
  else
    curl -fsS "$@"
  fi
}

wait_for_connect_ready() {
  local mode="$1"
  local connect_url="$2"
  local k8s_namespace="$3"
  local k8s_deployment="$4"
  local wait_seconds="$5"
  local interval_seconds="$6"

  if [[ "$wait_seconds" -le 0 ]]; then
    return 0
  fi

  local start_ts now_ts elapsed
  start_ts=$(date +%s)

  until connect_curl "$mode" "$k8s_namespace" "$k8s_deployment" "$connect_url/connector-plugins" >/dev/null 2>&1; do
    now_ts=$(date +%s)
    elapsed=$((now_ts - start_ts))
    if [[ "$elapsed" -ge "$wait_seconds" ]]; then
      return 1
    fi
    sleep "$interval_seconds"
  done

  return 0
}

delete_connector_if_exists() {
  local mode="$1"
  local connect_url="$2"
  local connector_name="$3"
  local k8s_namespace="$4"
  local k8s_deployment="$5"

  if connect_curl "$mode" "$k8s_namespace" "$k8s_deployment" "$connect_url/connectors/$connector_name" >/dev/null 2>&1; then
    connect_curl "$mode" "$k8s_namespace" "$k8s_deployment" -X DELETE "$connect_url/connectors/$connector_name" >/dev/null
    return 0
  fi

  return 1
}

connector_name_from_config() {
  local config_path="$1"
  jq -r '.name // .config.name // empty' "$config_path"
}

connector_config_from_file() {
  local config_path="$1"
  jq -c '.config // .' "$config_path"
}

connector_create_payload() {
  local connector_name="$1"
  local connector_config="$2"
  jq -cn --arg name "$connector_name" --argjson config "$connector_config" '{name: $name, config: $config}'
}

upsert_connector() {
  local connector_name="$1"
  local connector_config="$2"
  local create_payload="$3"
  local connect_url="$4"
  local mode="$5"
  local k8s_namespace="${6:-}"
  local k8s_deployment="${7:-}"
  local max_attempts="${8:-1}"
  local retry_delay_seconds="${9:-2}"
  local method
  local action
  local attempt

  if [[ "$max_attempts" -lt 1 ]]; then
    max_attempts=1
  fi

  if connect_curl "$mode" "$k8s_namespace" "$k8s_deployment" "$connect_url/connectors/$connector_name" >/dev/null 2>&1; then
    method="PUT"
    action="updated"
  else
    method="POST"
    action="created"
  fi

  attempt=1
  while [[ "$attempt" -le "$max_attempts" ]]; do
    if [[ "$method" == "PUT" ]]; then
      if connect_curl "$mode" "$k8s_namespace" "$k8s_deployment" -X PUT \
        -H "Content-Type: application/json" \
        --data "$connector_config" \
        "$connect_url/connectors/$connector_name/config" >/dev/null; then
        printf '%s\n' "$action"
        return 0
      fi
    else
      if connect_curl "$mode" "$k8s_namespace" "$k8s_deployment" -X POST \
        -H "Content-Type: application/json" \
        --data "$create_payload" \
        "$connect_url/connectors" >/dev/null; then
        printf '%s\n' "$action"
        return 0
      fi
    fi

    if [[ "$attempt" -eq "$max_attempts" ]]; then
      break
    fi

    attempt=$((attempt + 1))
    sleep "$retry_delay_seconds"
  done

  return 1
}

schema_subject_from_file() {
  local avsc_file="$1"
  basename "$avsc_file" .avsc
}

register_schema_file() {
  local schema_registry_url="$1"
  local subject="$2"
  local avsc_file="$3"
  local payload
  local http_code
  local response_file
  local response_body

  REGISTER_SCHEMA_LAST_ERROR=""
  payload=$(jq -c --arg schema "$(jq -c . "$avsc_file")" '{schema: $schema}')
  response_file=$(mktemp)
  http_code=$(curl -sS -o "$response_file" -w "%{http_code}" -X POST \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data "$payload" \
    "$schema_registry_url/subjects/${subject}-value/versions")

  response_body=$(tr '\n' ' ' <"$response_file" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')
  rm -f "$response_file"

  if [[ "$http_code" != "200" && "$http_code" != "201" ]]; then
    REGISTER_SCHEMA_LAST_ERROR="$response_body"
  fi

  printf '%s\n' "$http_code"
  [[ "$http_code" == "200" || "$http_code" == "201" ]]
}
