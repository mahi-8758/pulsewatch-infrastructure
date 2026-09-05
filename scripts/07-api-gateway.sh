#!/bin/bash
set -e
source "$(dirname "$0")/../config/variables.sh"

echo "=== Phase 7: API Gateway ==="
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 60 --query "UserPools[?Name=='${USER_POOL_NAME}'].Id | [0]" --output text)
USER_POOL_ARN=$(aws cognito-idp describe-user-pool --user-pool-id "$USER_POOL_ID" --query 'UserPool.Arn' --output text)
API_LAMBDA_ARN=$(aws lambda get-function --function-name "$API_FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text)
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='${API_NAME}'].id | [0]" --output text)
if [ -z "$API_ID" ] || [ "$API_ID" = "None" ]; then API_ID=$(aws apigateway create-rest-api --name "$API_NAME" --endpoint-configuration types=REGIONAL --query id --output text); fi
ROOT_ID=$(aws apigateway get-resources --rest-api-id "$API_ID" --query "items[?path=='/'].id | [0]" --output text)
AUTHORIZER_ID=$(aws apigateway get-authorizers --rest-api-id "$API_ID" --query "items[?name=='${PROJECT}-cognito'].id | [0]" --output text)
if [ -z "$AUTHORIZER_ID" ] || [ "$AUTHORIZER_ID" = "None" ]; then
  AUTHORIZER_ID=$(aws apigateway create-authorizer --rest-api-id "$API_ID" --name "${PROJECT}-cognito" --type COGNITO_USER_POOLS --provider-arns "$USER_POOL_ARN" --identity-source method.request.header.Authorization --query id --output text)
fi
get_or_create_resource() {
  local parent="$1" path_part="$2" resource_id
  resource_id=$(aws apigateway get-resources --rest-api-id "$API_ID" --query "items[?parentId=='${parent}' && pathPart=='${path_part}'].id | [0]" --output text)
  if [ -z "$resource_id" ] || [ "$resource_id" = "None" ]; then resource_id=$(aws apigateway create-resource --rest-api-id "$API_ID" --parent-id "$parent" --path-part "$path_part" --query id --output text); fi
  echo "$resource_id"
}
TARGETS_ID=$(get_or_create_resource "$ROOT_ID" targets)
TARGETS_TARGET_ID=$(get_or_create_resource "$TARGETS_ID" '{targetId}')
HISTORY_ID=$(get_or_create_resource "$ROOT_ID" history)
HISTORY_TARGET_ID=$(get_or_create_resource "$HISTORY_ID" '{targetId}')
INCIDENTS_ID=$(get_or_create_resource "$ROOT_ID" incidents)
INCIDENTS_TARGET_ID=$(get_or_create_resource "$INCIDENTS_ID" '{targetId}')
INTEGRATION_URI="arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${API_LAMBDA_ARN}/invocations"
put_lambda_method() {
  local resource_id="$1" method="$2"
  if ! aws apigateway get-method --rest-api-id "$API_ID" --resource-id "$resource_id" --http-method "$method" >/dev/null 2>&1; then
    aws apigateway put-method --rest-api-id "$API_ID" --resource-id "$resource_id" --http-method "$method" --authorization-type COGNITO_USER_POOLS --authorizer-id "$AUTHORIZER_ID" >/dev/null
  fi
  aws apigateway put-integration --rest-api-id "$API_ID" --resource-id "$resource_id" --http-method "$method" --type AWS_PROXY --integration-http-method POST --uri "$INTEGRATION_URI" >/dev/null
}
put_lambda_method "$TARGETS_ID" POST
put_lambda_method "$TARGETS_ID" GET
put_lambda_method "$TARGETS_TARGET_ID" DELETE
put_lambda_method "$HISTORY_TARGET_ID" GET
put_lambda_method "$INCIDENTS_TARGET_ID" GET
for resource_id in "$TARGETS_ID" "$TARGETS_TARGET_ID" "$HISTORY_TARGET_ID" "$INCIDENTS_TARGET_ID"; do
  if ! aws apigateway get-method --rest-api-id "$API_ID" --resource-id "$resource_id" --http-method OPTIONS >/dev/null 2>&1; then
    aws apigateway put-method --rest-api-id "$API_ID" --resource-id "$resource_id" --http-method OPTIONS --authorization-type NONE >/dev/null
  fi
  aws apigateway put-integration --rest-api-id "$API_ID" --resource-id "$resource_id" --http-method OPTIONS --type MOCK --request-templates '{"application/json":"{\"statusCode\":200}"}' >/dev/null
  if ! aws apigateway get-method-response --rest-api-id "$API_ID" --resource-id "$resource_id" --http-method OPTIONS --status-code 200 >/dev/null 2>&1; then
    aws apigateway put-method-response --rest-api-id "$API_ID" --resource-id "$resource_id" --http-method OPTIONS --status-code 200 --response-parameters '{"method.response.header.Access-Control-Allow-Headers":false,"method.response.header.Access-Control-Allow-Methods":false,"method.response.header.Access-Control-Allow-Origin":false}' >/dev/null
  fi
  if ! aws apigateway get-integration-response --rest-api-id "$API_ID" --resource-id "$resource_id" --http-method OPTIONS --status-code 200 >/dev/null 2>&1; then
    aws apigateway put-integration-response --rest-api-id "$API_ID" --resource-id "$resource_id" --http-method OPTIONS --status-code 200 --response-parameters '{"method.response.header.Access-Control-Allow-Headers":"'"'Authorization,Content-Type'"'","method.response.header.Access-Control-Allow-Methods":"'"'GET,POST,DELETE,OPTIONS'"'","method.response.header.Access-Control-Allow-Origin":"'"'*'"'"}' >/dev/null
  fi
done
PERMISSION_ID="${PROJECT}-api-gateway-invoke"
POLICY=$(aws lambda get-policy --function-name "$API_FUNCTION_NAME" --query "Policy.Statement[?Sid=='${PERMISSION_ID}'].Sid" --output text 2>/dev/null || true)
if [ -z "$POLICY" ] || [ "$POLICY" = "None" ]; then
  aws lambda add-permission --function-name "$API_FUNCTION_NAME" --statement-id "$PERMISSION_ID" --action lambda:InvokeFunction --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" >/dev/null
fi
DEPLOYMENT_ID=$(aws apigateway create-deployment --rest-api-id "$API_ID" --description "PulseWatch prod deployment" --query id --output text)
if aws apigateway get-stage --rest-api-id "$API_ID" --stage-name prod >/dev/null 2>&1; then
  aws apigateway update-stage --rest-api-id "$API_ID" --stage-name prod --patch-operations op=replace,path=/deploymentId,value="$DEPLOYMENT_ID" >/dev/null
else
  aws apigateway create-stage --rest-api-id "$API_ID" --stage-name prod --deployment-id "$DEPLOYMENT_ID" >/dev/null
fi
API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod"
export API_ID API_URL
echo "API_ID: $API_ID"
echo "API_URL: $API_URL"
