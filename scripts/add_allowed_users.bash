#!/bin/bash

set -euo pipefail

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
error()   { echo "[ERROR] $*" >&2; exit 1; }

# ── Config ────────────────────────────────────────────────────────────────────
LAMBDA_NAME="${LAMBDA_NAME:?Error: LAMBDA_NAME is not set}"
ALLOWED_USERS="${ALLOWED_USERS:?Error: ALLOWED_USERS is not set (e.g. '12345,12346')}"

# ── Store allowed users in SSM ────────────────────────────────────────────────
info "Setting allowed users for '${LAMBDA_NAME}': ${ALLOWED_USERS}"

aws ssm put-parameter \
  --name "/${LAMBDA_NAME}/allowed-users" \
  --value "${ALLOWED_USERS}" \
  --type StringList \
  --overwrite

success "Allowed users stored at '/${LAMBDA_NAME}/allowed-users'."