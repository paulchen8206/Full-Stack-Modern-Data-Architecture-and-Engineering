#!/bin/sh

set -eu

# Resolve chart path from this script location so it works from any caller cwd.
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CHART_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../../../charts" && pwd)"

helm dependency build "$CHART_DIR"
