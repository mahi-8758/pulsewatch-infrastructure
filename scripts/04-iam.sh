#!/bin/bash
set -e
source "$(dirname "$0")/../config/variables.sh"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"
TRUST_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
PERMISSION_POLICY=$(cat <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["dynamodb:GetItem","dynamodb:PutItem","dynamodb:Query","dynamodb:Scan","dynamodb:UpdateItem","dynamodb:DeleteItem","dynamodb:BatchWriteItem"],"Resource":["arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/MonitorTargets","arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/CheckResults","arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/Incidents"]},{"Effect":"Allow","Action":"ses:SendEmail","Resource":"*"},{"Effect":"Allow","Action":"cognito-idp:AdminGetUser","Resource":"arn:aws:cognito-idp:${REGION}:${ACCOUNT_ID}:userpool/*"}]}
EOF
)
if ! aws iam get-role --role-name "$LAMBDA_ROLE_NAME" >/dev/null 2>&1; then
  aws iam create-role --role-name "$LAMBDA_ROLE_NAME" --assume-role-policy-document "$TRUST_POLICY" >/dev/null
fi
aws iam attach-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam put-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-name "$LAMBDA_POLICY_NAME" --policy-document "$PERMISSION_POLICY"
sleep 10
export LAMBDA_ROLE_ARN="$ROLE_ARN"
echo "LAMBDA_ROLE_ARN: $LAMBDA_ROLE_ARN"
