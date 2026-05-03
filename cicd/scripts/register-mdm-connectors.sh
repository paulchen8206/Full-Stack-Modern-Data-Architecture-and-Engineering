#!/usr/bin/env bash
# register-mdm-connectors.sh
# Purpose-specific wrapper for MDM Kafka Connect registration.

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SELF_DIR/lib/common.sh"
source "$SELF_DIR/lib/connector-scope-wrapper.sh"
init_script_env

CANONICAL_SCRIPT="$SELF_DIR/register-connectors-core.sh"
CONNECT_URL_DEFAULT="${MDM_CONNECT_URL:-${CONNECT_URL:-http://mdm-connect:8083}}"

run_scope_wrapper mdm "$CONNECT_URL_DEFAULT" "$CANONICAL_SCRIPT" "$@"
