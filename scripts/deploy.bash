#!/bin/bash

set -euo pipefail

if [ -f .env ]; then
  source .env
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
error()   { echo "[ERROR] $*" >&2; exit 1; }

# ── Config ────────────────────────────────────────────────────────────────────
LAMBDA_NAME="${LAMBDA_NAME:?Error: LAMBDA_NAME is not set}"

# ── Verify AWS credentials ────────────────────────────────────────────────────
info "Verifying AWS credentials..."

aws sts get-caller-identity > /dev/null 2>&1 \
  || error "Not logged in to AWS CLI. Run 'aws configure' or set credentials."

AWS_REGION=$(aws configure get region)
[ -z "${AWS_REGION}" ]     && error "AWS_REGION is empty - run 'aws configure'."

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
[ -z "${AWS_ACCOUNT_ID}" ] && error "Could not determine AWS_ACCOUNT_ID."

success "AWS account ${AWS_ACCOUNT_ID} / region ${AWS_REGION}."

# ── IAM Role ──────────────────────────────────────────────────────────────────
ROLE_NAME="${LAMBDA_NAME}-role"
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"

if ! aws iam get-role --role-name "${ROLE_NAME}" &>/dev/null; then
  info "Creating IAM role '${ROLE_NAME}'..."

  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --no-cli-pager \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": { "Service": "lambda.amazonaws.com" },
        "Action": "sts:AssumeRole"
      }]
    }'

  info "Attaching policies..."

  aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess

  aws iam put-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-name "${LAMBDA_NAME}-self-invoke" \
    --policy-document "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [{
        \"Effect\": \"Allow\",
        \"Action\": \"lambda:InvokeFunction\",
        \"Resource\": \"arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${LAMBDA_NAME}\"
      }]
    }"

  info "Waiting 10 seconds for IAM role to propagate..."
  sleep 10

  success "IAM role '${ROLE_NAME}' created and configured."
else
  info "IAM role '${ROLE_NAME}' already exists - skipping."
fi

# ── Lambda ────────────────────────────────────────────────────────────────────
if aws lambda get-function --function-name "${LAMBDA_NAME}" &>/dev/null; then
  info "Lambda '${LAMBDA_NAME}' exists - updating code..."

  aws lambda update-function-code \
    --function-name "${LAMBDA_NAME}" \
    --zip-file fileb://dist/lambda.zip \
    --no-cli-pager

  success "Lambda '${LAMBDA_NAME}' updated."
else
  info "Lambda '${LAMBDA_NAME}' not found - creating..."

  aws lambda create-function \
    --function-name "${LAMBDA_NAME}" \
    --runtime python3.12 \
    --zip-file fileb://dist/lambda.zip \
    --handler my_lambda.bot.handler \
    --role "${ROLE_ARN}" \
    --no-cli-pager

  info "Creating API Gateway..."

  aws apigatewayv2 create-api \
    --name "${LAMBDA_NAME}-api" \
    --protocol-type HTTP \
    --target "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${LAMBDA_NAME}"

  info "Granting API Gateway permission to invoke Lambda..."

  aws lambda add-permission \
    --function-name "${LAMBDA_NAME}" \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com

  success "Lambda '${LAMBDA_NAME}' created with API Gateway."
fi