#!/bin/bash
set -e
source "$(dirname "$0")/../config/variables.sh"

echo "=== Phase 5: Lambda ==="
INFRA_DIR=$(cd "$(dirname "$0")/.." && pwd)
BACKEND_DIR="$(dirname "$INFRA_DIR")/pulsewatch-backend"
CHECKER_DIR="$BACKEND_DIR/lambda/checker"
API_DIR="$BACKEND_DIR/lambda/api"
NODE_MODULES_DIR="$BACKEND_DIR/node_modules"
if [ ! -f "$CHECKER_DIR/checker.js" ]; then
  echo "Expected checker handler is missing: $CHECKER_DIR/checker.js"
  exit 1
fi
if [ ! -f "$API_DIR/api.js" ]; then
  echo "Expected API handler is missing: $API_DIR/api.js"
  exit 1
fi
if [ ! -d "$NODE_MODULES_DIR" ]; then
  echo "Backend dependencies are missing: $NODE_MODULES_DIR"
  echo "Run npm install in pulsewatch-backend, then rerun this phase."
  exit 1
fi
if [ ! -f "$BACKEND_DIR/package.json" ]; then
  echo "Expected package file is missing: $BACKEND_DIR/package.json"
  exit 1
fi
if ! command -v zip >/dev/null 2>&1 && ! command -v powershell.exe >/dev/null 2>&1; then
  echo "Neither zip nor PowerShell was found. PowerShell is required when zip is unavailable."
  exit 1
fi
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"
TOPIC_ARN=$(aws sns create-topic --name "$ALERT_TOPIC_NAME" --query TopicArn --output text)
BUILD_DIR="$INFRA_DIR/build"
CHECKER_BUILD_DIR="$BUILD_DIR/checker"
API_BUILD_DIR="$BUILD_DIR/api"
CHECKER_ZIP="$BUILD_DIR/${CHECKER_FUNCTION_NAME}.zip"
API_ZIP="$BUILD_DIR/${API_FUNCTION_NAME}.zip"
rm -rf "$CHECKER_BUILD_DIR" "$API_BUILD_DIR" "$CHECKER_ZIP" "$API_ZIP"
mkdir -p "$CHECKER_BUILD_DIR" "$API_BUILD_DIR"
trap 'rm -rf "$CHECKER_BUILD_DIR" "$API_BUILD_DIR"' EXIT

package_lambda() {
  local source_dir="$1" handler_file="$2" package_dir="$3" zip_file="$4"
  cp "$source_dir/$handler_file" "$package_dir/$handler_file"
  cp -R "$NODE_MODULES_DIR" "$package_dir/node_modules"
  cp "$BACKEND_DIR/package.json" "$package_dir/package.json"
  if [ -f "$BACKEND_DIR/package-lock.json" ]; then
    cp "$BACKEND_DIR/package-lock.json" "$package_dir/package-lock.json"
  fi
  if command -v zip >/dev/null 2>&1; then
    (cd "$package_dir" && zip -qr "$zip_file" .)
  else
    local package_dir_windows zip_file_windows
    package_dir_windows=$(cygpath -w "$package_dir")
    zip_file_windows=$(cygpath -w "$zip_file")
    PULSEWATCH_PACKAGE_DIR="$package_dir_windows" \
      PULSEWATCH_ZIP_FILE="$zip_file_windows" \
      powershell.exe -NoProfile -NonInteractive -Command \
      '$source = $env:PULSEWATCH_PACKAGE_DIR; $destination = $env:PULSEWATCH_ZIP_FILE; $entries = Get-ChildItem -LiteralPath $source -Force | Select-Object -ExpandProperty FullName; Compress-Archive -Path $entries -DestinationPath $destination -Force'
  fi
  echo "Created package: $zip_file"
}

package_lambda "$CHECKER_DIR" checker.js "$CHECKER_BUILD_DIR" "$CHECKER_ZIP"
package_lambda "$API_DIR" api.js "$API_BUILD_DIR" "$API_ZIP"

zip_file_uri() {
  local zip_file="$1"
  if command -v cygpath >/dev/null 2>&1; then
    printf 'fileb://%s' "$(cygpath -w "$zip_file" | sed 's#\\#/#g')"
  else
    printf 'fileb://%s' "$zip_file"
  fi
}

deploy_lambda() {
  local name="$1" zip_file="$2" handler="$3" timeout="$4" variables="$5"
  local zip_file_uri_value
  zip_file_uri_value=$(zip_file_uri "$zip_file")
  if aws lambda get-function --function-name "$name" >/dev/null 2>&1; then
    aws lambda update-function-code --function-name "$name" --zip-file "$zip_file_uri_value" >/dev/null
    aws lambda update-function-configuration --function-name "$name" --handler "$handler" --timeout "$timeout" --environment "Variables={$variables}" >/dev/null
  else
    aws lambda create-function --function-name "$name" --runtime nodejs20.x --role "$ROLE_ARN" --handler "$handler" --timeout "$timeout" --zip-file "$zip_file_uri_value" --environment "Variables={$variables}" >/dev/null
  fi
  aws lambda wait function-active --function-name "$name"
  aws lambda get-function --function-name "$name" --query 'Configuration.FunctionArn' --output text
}
CHECKER_ARN=$(deploy_lambda "$CHECKER_FUNCTION_NAME" "$CHECKER_ZIP" checker.handler 30 "TARGETS_TABLE=MonitorTargets,RESULTS_TABLE=CheckResults,INCIDENTS_TABLE=Incidents,SNS_TOPIC_ARN=$TOPIC_ARN")
API_LAMBDA_ARN=$(deploy_lambda "$API_FUNCTION_NAME" "$API_ZIP" api.handler 15 "TARGETS_TABLE=MonitorTargets,RESULTS_TABLE=CheckResults,INCIDENTS_TABLE=Incidents")
export CHECKER_ARN API_LAMBDA_ARN
echo "CHECKER_ARN: $CHECKER_ARN"
echo "API_LAMBDA_ARN: $API_LAMBDA_ARN"
