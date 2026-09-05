#!/bin/bash
set -e
source "$(dirname "$0")/../config/variables.sh"

echo "=== Phase 3: SNS ==="
if [ -z "${ALERT_EMAIL:-}" ]; then
  echo "ALERT_EMAIL is missing. Set it first: export ALERT_EMAIL='your-email@example.com'"
  exit 1
fi
TOPIC_ARN=$(aws sns create-topic --name "$ALERT_TOPIC_NAME" --query TopicArn --output text)
SUBSCRIBED=$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --query "Subscriptions[?Protocol=='email' && Endpoint=='${ALERT_EMAIL}'].Endpoint | [0]" --output text)
if [ -z "$SUBSCRIBED" ] || [ "$SUBSCRIBED" = "None" ]; then
  aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint "$ALERT_EMAIL" >/dev/null
fi
export TOPIC_ARN
echo "TOPIC_ARN: $TOPIC_ARN"
echo "Confirm the SNS email subscription from your inbox."
