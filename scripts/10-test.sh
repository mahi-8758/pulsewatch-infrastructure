#!/bin/bash
set -e
source "$(dirname "$0")/../config/variables.sh"

echo "=== Phase 10: Verification ==="
aws sts get-caller-identity --query '[Account,Arn]' --output table
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 60 --query "UserPools[?Name=='${USER_POOL_NAME}'].Id | [0]" --output text)
aws cognito-idp describe-user-pool --user-pool-id "$USER_POOL_ID" --query 'UserPool.[Id,Status]' --output table
for table in MonitorTargets CheckResults Incidents; do aws dynamodb describe-table --table-name "$table" --query 'Table.[TableName,TableStatus]' --output table; done
TOPIC_ARN="arn:aws:sns:${REGION}:${ACCOUNT_ID}:${ALERT_TOPIC_NAME}"
aws sns get-topic-attributes --topic-arn "$TOPIC_ARN" --query 'Attributes.TopicArn' --output text
aws lambda get-function --function-name "$CHECKER_FUNCTION_NAME" --query 'Configuration.[FunctionName,State]' --output table
aws lambda get-function --function-name "$API_FUNCTION_NAME" --query 'Configuration.[FunctionName,State]' --output table
aws events describe-rule --name "$EVENT_RULE_NAME" --query '[Name,State,Arn]' --output table
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='${API_NAME}'].id | [0]" --output text)
aws apigateway get-rest-api --rest-api-id "$API_ID" --query '[id,name]' --output table
FRONTEND_BUCKET="${PROJECT}-frontend-${ACCOUNT_ID}"
aws s3api head-bucket --bucket "$FRONTEND_BUCKET"
aws cloudwatch describe-alarms --alarm-names "$ALARM_NAME" --query 'MetricAlarms[].[AlarmName,StateValue]' --output table
API_URL="${API_URL:-https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod}"
UNAUTH_STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$API_URL/targets")
if [ "$UNAUTH_STATUS" = "401" ] || [ "$UNAUTH_STATUS" = "403" ]; then
  echo "Unauthenticated API request rejected as expected ($UNAUTH_STATUS)."
else
  echo "Warning: unauthenticated API request returned HTTP $UNAUTH_STATUS (expected 401 or 403)."
fi
if [ -z "${COGNITO_ID_TOKEN:-}" ] && [ -n "${COGNITO_DEMO_PASSWORD:-}" ]; then
  CLIENT_ID=$(aws cognito-idp list-user-pool-clients --user-pool-id "$USER_POOL_ID" --query "UserPoolClients[?ClientName=='${PROJECT}-browser-client'].ClientId | [0]" --output text)
  COGNITO_ID_TOKEN=$(aws cognito-idp initiate-auth --client-id "$CLIENT_ID" --auth-flow USER_PASSWORD_AUTH \
    --auth-parameters "USERNAME=demo@example.com,PASSWORD=${COGNITO_DEMO_PASSWORD}" --query 'AuthenticationResult.IdToken' --output text)
fi
if [ -n "${COGNITO_ID_TOKEN:-}" ]; then
  echo "Authenticated GET /targets:"
  curl -fsS -H "Authorization: $COGNITO_ID_TOKEN" "$API_URL/targets"
  echo
  echo "Authenticated POST /targets example:"
  curl -fsS -X POST -H "Authorization: $COGNITO_ID_TOKEN" -H 'Content-Type: application/json' \
    -d '{"label":"PulseWatch test target","url":"https://example.com"}' "$API_URL/targets"
  echo
fi
if [ "${RUN_CHECKER_TEST:-false}" = "true" ]; then
  RESPONSE_FILE=$(mktemp)
  trap 'rm -f "$RESPONSE_FILE"' EXIT
  aws lambda invoke --function-name "$CHECKER_FUNCTION_NAME" --payload '{}' "$RESPONSE_FILE" >/dev/null
  cat "$RESPONSE_FILE"
  echo "Checker invoked. Inspect CheckResults and CloudWatch Logs for its result."
fi
