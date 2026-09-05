#!/bin/bash
set -e
source "$(dirname "$0")/../config/variables.sh"

echo "=== Phase 6: EventBridge ==="
CHECKER_ARN=$(aws lambda get-function --function-name "$CHECKER_FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text)
RULE_ARN=$(aws events put-rule --name "$EVENT_RULE_NAME" --schedule-expression 'rate(5 minutes)' --state ENABLED --query RuleArn --output text)
aws events put-targets --rule "$EVENT_RULE_NAME" --targets '[{"Id":"pulsewatch-checker-target","Arn":"'"$CHECKER_ARN"'"}]' >/dev/null
STATEMENT_ID="${PROJECT}-eventbridge-invoke"
POLICY=$(aws lambda get-policy --function-name "$CHECKER_FUNCTION_NAME" --query "Policy.Statement[?Sid=='${STATEMENT_ID}'].Sid" --output text 2>/dev/null || true)
if [ -z "$POLICY" ] || [ "$POLICY" = "None" ]; then
  aws lambda add-permission --function-name "$CHECKER_FUNCTION_NAME" --statement-id "$STATEMENT_ID" --action lambda:InvokeFunction --principal events.amazonaws.com --source-arn "$RULE_ARN" >/dev/null
fi
export RULE_ARN
echo "RULE_ARN: $RULE_ARN"
