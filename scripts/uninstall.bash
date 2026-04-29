#!/bin/bash

set -euo pipefail

if [ -f .env ]; then
  source .env
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
skip()    { echo "[SKIP]  $*"; }
error()   { echo "[ERROR] $*" >&2; exit 1; }

# ── Config ────────────────────────────────────────────────────────────────────
LAMBDA_NAME="${LAMBDA_NAME:?Error: LAMBDA_NAME is not set}"

# ── Verify AWS credentials ────────────────────────────────────────────────────
info "Verifying AWS credentials..."

aws sts get-caller-identity > /dev/null 2>&1 \
  || error "Not logged in to AWS CLI. Run 'aws configure' or set credentials."

AWS_REGION=$(aws configure get region)
[ -z "${AWS_REGION}" ] && error "AWS_REGION is empty - run 'aws configure'."

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
[ -z "${AWS_ACCOUNT_ID}" ] && error "Could not determine AWS_ACCOUNT_ID."

success "AWS account ${AWS_ACCOUNT_ID} / region ${AWS_REGION}."

# ── Confirm ───────────────────────────────────────────────────────────────────
echo ""
echo "  This will permanently delete all resources for: ${LAMBDA_NAME}"
echo ""
echo "    - Lambda function"
echo "    - API Gateway"
echo "    - IAM role + policies"
echo "    - SSM parameters"
echo "    - CloudWatch log group"
echo ""
read -r -p "  Are you sure? [y/N] " CONFIRM
echo ""
[[ "${CONFIRM}" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }

ROLE_NAME="${LAMBDA_NAME}-role"

# ── API Gateway ───────────────────────────────────────────────────────────────
info "Looking up API Gateway '${LAMBDA_NAME}-api'..."

API_ID=$(aws apigatewayv2 get-apis \
  --query "Items[?Name=='${LAMBDA_NAME}-api'].ApiId" \
  --output text)

if [ -n "${API_ID}" ]; then
  aws apigatewayv2 delete-api --api-id "${API_ID}"
  success "API Gateway '${LAMBDA_NAME}-api' (${API_ID}) deleted."
else
  skip "API Gateway '${LAMBDA_NAME}-api' not found."
fi

# ── Lambda ────────────────────────────────────────────────────────────────────
info "Deleting Lambda function '${LAMBDA_NAME}'..."

if aws lambda get-function --function-name "${LAMBDA_NAME}" &>/dev/null; then
  aws lambda delete-function --function-name "${LAMBDA_NAME}"
  success "Lambda '${LAMBDA_NAME}' deleted."
else
  skip "Lambda '${LAMBDA_NAME}' not found."
fi

# ── IAM Role ──────────────────────────────────────────────────────────────────
info "Deleting IAM role '${ROLE_NAME}'..."

if aws iam get-role --role-name "${ROLE_NAME}" &>/dev/null; then

  info "Detaching managed policies..."
  aws iam detach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  aws iam detach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess

  info "Deleting inline policy '${LAMBDA_NAME}-self-invoke'..."
  aws iam delete-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-name "${LAMBDA_NAME}-self-invoke"

  aws iam delete-role --role-name "${ROLE_NAME}"
  success "IAM role '${ROLE_NAME}' deleted."
else
  skip "IAM role '${ROLE_NAME}' not found."
fi

# ── SSM Parameters ────────────────────────────────────────────────────────────
info "Deleting SSM parameters..."

for PARAM in "telegram-token" "allowed-users"; do
  PARAM_PATH="/${LAMBDA_NAME}/${PARAM}"
  if aws ssm get-parameter --name "${PARAM_PATH}" &>/dev/null; then
    aws ssm delete-parameter --name "${PARAM_PATH}"
    success "SSM parameter '${PARAM_PATH}' deleted."
  else
    skip "SSM parameter '${PARAM_PATH}' not found."
  fi
done

# ── CloudWatch Log Group ──────────────────────────────────────────────────────
LOG_GROUP="/aws/lambda/${LAMBDA_NAME}"
info "Deleting CloudWatch log group '${LOG_GROUP}'..."

if aws logs describe-log-groups \
     --log-group-name-prefix "${LOG_GROUP}" \
     --query "logGroups[?logGroupName=='${LOG_GROUP}'] | [0]" \
     --output text | grep -q "${LOG_GROUP}"; then
  aws logs delete-log-group --log-group-name "${LOG_GROUP}"
  success "Log group '${LOG_GROUP}' deleted."
else
  skip "Log group '${LOG_GROUP}' not found."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "All resources for '${LAMBDA_NAME}' have been removed."