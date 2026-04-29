#!/bin/bash

set -euo pipefail

if [ -f .env ]; then
  source .env
fi

# ── Config ────────────────────────────────────────────────────────────────────
LAMBDA_NAME="${LAMBDA_NAME:?Error: LAMBDA_NAME is not set}"
RETENTION_DAYS=3
LOG_GROUP="/aws/lambda/${LAMBDA_NAME}"
AWS_REGION=$(aws configure get region)
[ -z "${AWS_REGION}" ]     && error "AWS_REGION is empty - run 'aws configure'."

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
error()   { echo "[ERROR] $*" >&2; exit 1; }

# ── Create log group if it doesn't exist ─────────────────────────────────────
info "Checking if log group exists: ${LOG_GROUP}"

if aws logs describe-log-groups \
     --log-group-name-prefix "${LOG_GROUP}" \
     --region "${AWS_REGION}" \
     --query "logGroups[?logGroupName=='${LOG_GROUP}'] | [0]" \
     --output text | grep -q "${LOG_GROUP}"; then
  info "Log group already exists."
else
  info "Log group not found - creating it..."
  aws logs create-log-group \
    --log-group-name "${LOG_GROUP}" \
    --region "${AWS_REGION}"
  success "Log group created."
fi

# ── Set retention policy ──────────────────────────────────────────────────────
info "Setting retention to ${RETENTION_DAYS} days..."

aws logs put-retention-policy \
  --log-group-name "${LOG_GROUP}" \
  --retention-in-days "${RETENTION_DAYS}" \
  --region "${AWS_REGION}"

success "Retention policy set to ${RETENTION_DAYS} days."

# ── Verify ────────────────────────────────────────────────────────────────────
info "Verifying..."

RESULT=$(aws logs describe-log-groups \
  --log-group-name-prefix "${LOG_GROUP}" \
  --region "${AWS_REGION}" \
  --query "logGroups[?logGroupName=='${LOG_GROUP}'].retentionInDays | [0]" \
  --output text)

if [ "${RESULT}" == "${RETENTION_DAYS}" ]; then
  success "Confirmed: '${LOG_GROUP}' retention = ${RESULT} days."
else
  error "Verification failed. Expected ${RETENTION_DAYS}, got '${RESULT}'."
fi