#!/bin/bash

set -euo pipefail

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
error()   { echo "[ERROR] $*" >&2; exit 1; }

# ── Config ────────────────────────────────────────────────────────────────────
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:?Error: TELEGRAM_BOT_TOKEN is not set}"
LAMBDA_NAME="${LAMBDA_NAME:?Error: LAMBDA_NAME is not set}"

# ── Fetch API Gateway URL ─────────────────────────────────────────────────────
info "Fetching API Gateway endpoint for '${LAMBDA_NAME}-api'..."

AWS_API_GATEWAY=$(aws apigatewayv2 get-apis \
  --query "Items[?Name=='${LAMBDA_NAME}-api'].ApiEndpoint" \
  --output text)

[ -z "${AWS_API_GATEWAY}" ] && error "No API Gateway found for '${LAMBDA_NAME}-api'."

info "API Gateway: ${AWS_API_GATEWAY}"

# ── Register Telegram Webhook ─────────────────────────────────────────────────
info "Setting Telegram webhook..."

RESPONSE=$(curl --silent --show-error \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setWebhook?url=${AWS_API_GATEWAY}")

echo "${RESPONSE}" | grep -q '"ok":true' \
  && success "Webhook registered: ${AWS_API_GATEWAY}" \
  || error "Telegram webhook failed. Response: ${RESPONSE}"

# ── Store Token in SSM ────────────────────────────────────────────────────────
info "Storing Telegram token in SSM Parameter Store..."

aws ssm put-parameter \
  --name "/${LAMBDA_NAME}/telegram-token" \
  --value "${TELEGRAM_BOT_TOKEN}" \
  --type SecureString \
  --overwrite

success "Token stored at '/${LAMBDA_NAME}/telegram-token'."