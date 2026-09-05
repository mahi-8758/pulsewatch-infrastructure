#!/bin/bash
set -e
source "$(dirname "$0")/../config/variables.sh"

echo "THIS WILL DELETE PULSEWATCH AWS RESOURCES."
echo "This includes the API, Lambda functions, tables, topic, alarm, bucket contents, IAM role, and user pool."
read -r -p "Type DELETE to continue: " CONFIRMATION
if [ "$CONFIRMATION" != "DELETE" ]; then echo "Teardown cancelled."; exit 0; fi

echo "=== PulseWatch teardown ==="
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='${API_NAME}'].id | [0]" --output text)
if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then aws apigateway delete-rest-api --rest-api-id "$API_ID"; fi
RULE_ARN=$(aws events describe-rule --name "$EVENT_RULE_NAME" --query Arn --output text 2>/dev/null || true)
if [ -n "$RULE_ARN" ] && [ "$RULE_ARN" != "None" ]; then
  aws events remove-targets --rule "$EVENT_RULE_NAME" --ids pulsewatch-checker-target >/dev/null || true
  aws events delete-rule --name "$EVENT_RULE_NAME"
fi
aws lambda delete-function --function-name "$CHECKER_FUNCTION_NAME" 2>/dev/null || true
aws lambda delete-function --function-name "$API_FUNCTION_NAME" 2>/dev/null || true
for table in MonitorTargets CheckResults Incidents; do aws dynamodb delete-table --table-name "$table" 2>/dev/null || true; done
TOPIC_ARN="arn:aws:sns:${REGION}:${ACCOUNT_ID}:${ALERT_TOPIC_NAME}"
aws sns delete-topic --topic-arn "$TOPIC_ARN" 2>/dev/null || true
aws cloudwatch delete-alarms --alarm-names "$ALARM_NAME" 2>/dev/null || true
FRONTEND_BUCKET="${PROJECT}-frontend-${ACCOUNT_ID}"
aws s3 rm "s3://$FRONTEND_BUCKET" --recursive 2>/dev/null || true
aws s3api delete-bucket --bucket "$FRONTEND_BUCKET" --region "$REGION" 2>/dev/null || true
aws iam delete-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-name "$LAMBDA_POLICY_NAME" 2>/dev/null || true
aws iam detach-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
aws iam delete-role --role-name "$LAMBDA_ROLE_NAME" 2>/dev/null || true
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 60 --query "UserPools[?Name=='${USER_POOL_NAME}'].Id | [0]" --output text)
if [ -n "$USER_POOL_ID" ] && [ "$USER_POOL_ID" != "None" ]; then aws cognito-idp delete-user-pool --user-pool-id "$USER_POOL_ID"; fi
echo "PulseWatch resources created by these scripts have been removed where present."
