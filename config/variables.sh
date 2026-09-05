#!/bin/bash
set -e

REGION="${REGION:-ap-south-1}"
ACCOUNT_ID="${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
PROJECT="${PROJECT:-pulsewatch}"
export REGION ACCOUNT_ID PROJECT

export USER_POOL_NAME="${PROJECT}-users"
export ALERT_TOPIC_NAME="${PROJECT}-alerts"
export LAMBDA_ROLE_NAME="${PROJECT}-lambda-role"
export CHECKER_FUNCTION_NAME="${PROJECT}-checker"
export API_FUNCTION_NAME="${PROJECT}-api"
export EVENT_RULE_NAME="${PROJECT}-schedule"
export API_NAME="${PROJECT}-api"
export ALARM_NAME="${PROJECT}-checker-errors"
export LAMBDA_POLICY_NAME="${PROJECT}-lambda-dynamodb-sns"

echo "Using AWS account ${ACCOUNT_ID} in ${REGION}"
