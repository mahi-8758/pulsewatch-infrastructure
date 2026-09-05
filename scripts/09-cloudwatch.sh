#!/bin/bash
set -e
source "$(dirname "$0")/../config/variables.sh"

echo "=== Phase 9: CloudWatch ==="
TOPIC_ARN=$(aws sns create-topic --name "$ALERT_TOPIC_NAME" --query TopicArn --output text)
aws cloudwatch put-metric-alarm --alarm-name "$ALARM_NAME" --alarm-description "PulseWatch checker Lambda errors" --namespace AWS/Lambda --metric-name Errors --dimensions Name=FunctionName,Value="$CHECKER_FUNCTION_NAME" --period 300 --evaluation-periods 1 --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold --statistic Sum --alarm-actions "$TOPIC_ARN"
echo "Alarm: $ALARM_NAME"
