#!/bin/bash
set -e
source "$(dirname "$0")/../config/variables.sh"

echo "=== Phase 2: DynamoDB ==="
create_table() {
  local table_name="$1" definitions="$2" schema="$3"
  if ! aws dynamodb describe-table --table-name "$table_name" >/dev/null 2>&1; then
    aws dynamodb create-table --table-name "$table_name" --billing-mode PAY_PER_REQUEST \
      --attribute-definitions $definitions --key-schema $schema >/dev/null
  else
    echo "$table_name already exists; reusing it."
  fi
  aws dynamodb wait table-exists --table-name "$table_name"
  aws dynamodb describe-table --table-name "$table_name" --query 'Table.[TableName,TableStatus]' --output table
}
create_table MonitorTargets 'AttributeName=targetId,AttributeType=S' 'AttributeName=targetId,KeyType=HASH'
create_table CheckResults 'AttributeName=targetId,AttributeType=S AttributeName=checkedAt,AttributeType=S' 'AttributeName=targetId,KeyType=HASH AttributeName=checkedAt,KeyType=RANGE'
create_table Incidents 'AttributeName=targetId,AttributeType=S AttributeName=startedAt,AttributeType=S' 'AttributeName=targetId,KeyType=HASH AttributeName=startedAt,KeyType=RANGE'
