#!/bin/bash
set -e
source "$(dirname "$0")/../config/variables.sh"

echo "=== Phase 1: Cognito ==="
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 60 --query "UserPools[?Name=='${USER_POOL_NAME}'].Id | [0]" --output text)
if [ -z "$USER_POOL_ID" ] || [ "$USER_POOL_ID" = "None" ]; then
  USER_POOL_ID=$(aws cognito-idp create-user-pool --pool-name "$USER_POOL_NAME" \
    --username-attributes email --auto-verified-attributes email \
    --policies 'PasswordPolicy={MinimumLength=8,RequireUppercase=true,RequireLowercase=true,RequireNumbers=true,RequireSymbols=true,TemporaryPasswordValidityDays=7}' \
    --query 'UserPool.Id' --output text)
else
  echo "User pool already exists; reusing it."
fi
USER_POOL_ARN=$(aws cognito-idp describe-user-pool --user-pool-id "$USER_POOL_ID" --query 'UserPool.Arn' --output text)
CLIENT_ID=$(aws cognito-idp list-user-pool-clients --user-pool-id "$USER_POOL_ID" --query "UserPoolClients[?ClientName=='${PROJECT}-browser-client'].ClientId | [0]" --output text)
if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" = "None" ]; then
  CLIENT_ID=$(aws cognito-idp create-user-pool-client --user-pool-id "$USER_POOL_ID" \
    --client-name "${PROJECT}-browser-client" --no-generate-secret \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --query 'UserPoolClient.ClientId' --output text)
fi
if [ -z "${COGNITO_DEMO_PASSWORD:-}" ]; then
  echo "COGNITO_DEMO_PASSWORD is required to create demo@example.com."
  echo "Set it in your shell and rerun this phase. No password is stored in this repository."
  exit 1
fi
DEMO_EXISTS=$(aws cognito-idp list-users --user-pool-id "$USER_POOL_ID" --filter 'email = "demo@example.com"' --query 'Users[0].Username' --output text)
if [ -z "$DEMO_EXISTS" ] || [ "$DEMO_EXISTS" = "None" ]; then
  aws cognito-idp admin-create-user --user-pool-id "$USER_POOL_ID" --username demo@example.com \
    --user-attributes Name=email,Value=demo@example.com Name=email_verified,Value=true \
    --temporary-password "$COGNITO_DEMO_PASSWORD" --message-action SUPPRESS >/dev/null
  aws cognito-idp admin-set-user-password --user-pool-id "$USER_POOL_ID" --username demo@example.com \
    --password "$COGNITO_DEMO_PASSWORD" --permanent
fi
export USER_POOL_ID USER_POOL_ARN CLIENT_ID
printf 'User Pool ID: %s\nUser Pool ARN: %s\nClient ID: %s\n' "$USER_POOL_ID" "$USER_POOL_ARN" "$CLIENT_ID"
