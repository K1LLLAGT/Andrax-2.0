#!/usr/bin/env bash
set -euo pipefail

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ENGINE_DIR/../../termux-backend/config/paths.sh"

WF_ID="$1"; shift || true

WF_RUNNER="$ANDRAX_HOME/bin/andrax-workflow-run.sh"

bash "$WF_RUNNER" "$WF_ID" "$@"
