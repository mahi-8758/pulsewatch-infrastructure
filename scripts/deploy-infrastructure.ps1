$ErrorActionPreference = "Stop"

Write-Host "=== Deploying PulseWatch Infrastructure & Backend to AWS ==="

# 1. AWS Account Info
$accountInfo = aws sts get-caller-identity --output json | ConvertFrom-Json
$accountId = $accountInfo.Account
$region = "ap-south-1"
$apiName = "pulsewatch-api"
$roleName = "pulsewatch-lambda-role"
$policyName = "pulsewatch-lambda-dynamodb-sns"
$apiLambdaName = "pulsewatch-api"
$targetsTable = "MonitorTargets"
$resultsTable = "CheckResults"
$incidentsTable = "Incidents"

Write-Host "Account ID: $accountId in Region: $region"

# 2. Update IAM Policy
Write-Host "`nUpdating IAM Policy for $roleName..."
$policyRaw = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:BatchWriteItem"
      ],
      "Resource": [
        "arn:aws:dynamodb:${region}:${accountId}:table/${targetsTable}",
        "arn:aws:dynamodb:${region}:${accountId}:table/${resultsTable}",
        "arn:aws:dynamodb:${region}:${accountId}:table/${incidentsTable}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "sns:Publish",
      "Resource": "*"
    }
  ]
}
"@

$tempPolicyFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "pulsewatch_policy.json")
[System.IO.File]::WriteAllText($tempPolicyFile, $policyRaw)
aws iam put-role-policy --role-name $roleName --policy-name $policyName --policy-document "file://$tempPolicyFile"
Remove-Item -Force $tempPolicyFile
Write-Host "IAM Policy updated successfully."

# 3. Package & Deploy Lambda
Write-Host "`nPackaging pulsewatch-api Lambda..."
$infraDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$backendDir = Resolve-Path (Join-Path $infraDir "..\pulsewatch-backend")
$buildDir = Join-Path $infraDir "build\api_package"
$zipFile = Join-Path $infraDir "build\pulsewatch-api.zip"

if (Test-Path $buildDir) { Remove-Item -Recurse -Force $buildDir }
if (Test-Path $zipFile) { Remove-Item -Force $zipFile }

New-Item -ItemType Directory -Path $buildDir | Out-Null
Copy-Item (Join-Path $backendDir "lambda\api\api.js") (Join-Path $buildDir "api.js")
Copy-Item (Join-Path $backendDir "package.json") (Join-Path $buildDir "package.json")

$entries = Get-ChildItem -LiteralPath $buildDir -Force | Select-Object -ExpandProperty FullName
Compress-Archive -Path $entries -DestinationPath $zipFile -Force
Write-Host "Package created: $zipFile"

Write-Host "Deploying pulsewatch-api Lambda to AWS..."
$zipUri = "fileb://" + ($zipFile.Replace("\", "/"))
aws lambda update-function-code --function-name $apiLambdaName --zip-file $zipUri | Out-Null
aws lambda wait function-updated --function-name $apiLambdaName

aws lambda update-function-configuration --function-name $apiLambdaName --environment "Variables={TARGETS_TABLE=$targetsTable,RESULTS_TABLE=$resultsTable,INCIDENTS_TABLE=$incidentsTable}" | Out-Null
aws lambda wait function-updated --function-name $apiLambdaName

$apiLambdaArn = (aws lambda get-function --function-name $apiLambdaName --query 'Configuration.FunctionArn' --output text)
Write-Host "PulseWatch API Lambda deployed: $apiLambdaArn"

# 4. API Gateway Configuration
Write-Host "`nConfiguring API Gateway route DELETE /targets/{targetId}..."
$apiId = (aws apigateway get-rest-apis --query "items[?name=='$apiName'].id | [0]" --output text)
if (-not $apiId -or $apiId -eq "None") {
    throw "API Gateway with name $apiName not found"
}

$rootId = (aws apigateway get-resources --rest-api-id $apiId --query "items[?path=='/'].id | [0]" --output text)
$authorizerId = (aws apigateway get-authorizers --rest-api-id $apiId --query "items[0].id" --output text)
$targetsResourceId = (aws apigateway get-resources --rest-api-id $apiId --query "items[?path=='/targets'].id | [0]" --output text)

# Get or create /targets/{targetId} resource
$targetIdResourceId = (aws apigateway get-resources --rest-api-id $apiId --query "items[?parentId=='$targetsResourceId' && pathPart=='{targetId}'].id | [0]" --output text)
if (-not $targetIdResourceId -or $targetIdResourceId -eq "None") {
    Write-Host "Creating resource /targets/{targetId}..."
    $targetIdResourceId = (aws apigateway create-resource --rest-api-id $apiId --parent-id $targetsResourceId --path-part '{targetId}' --query id --output text)
}

$integrationUri = "arn:aws:apigateway:${region}:lambda:path/2015-03-31/functions/${apiLambdaArn}/invocations"

# Put DELETE method
Write-Host "Configuring DELETE method on /targets/{targetId}..."
try {
    aws apigateway get-method --rest-api-id $apiId --resource-id $targetIdResourceId --http-method DELETE 2>$null | Out-Null
} catch {
    aws apigateway put-method --rest-api-id $apiId --resource-id $targetIdResourceId --http-method DELETE --authorization-type COGNITO_USER_POOLS --authorizer-id $authorizerId | Out-Null
}
aws apigateway put-integration --rest-api-id $apiId --resource-id $targetIdResourceId --http-method DELETE --type AWS_PROXY --integration-http-method POST --uri $integrationUri | Out-Null

# Put OPTIONS method
Write-Host "Configuring OPTIONS preflight on /targets/{targetId}..."
try {
    aws apigateway get-method --rest-api-id $apiId --resource-id $targetIdResourceId --http-method OPTIONS 2>$null | Out-Null
} catch {
    aws apigateway put-method --rest-api-id $apiId --resource-id $targetIdResourceId --http-method OPTIONS --authorization-type NONE | Out-Null
}

$mockTemplates = '{\"application/json\":\"{\\\"statusCode\\\":200}\"}'
aws apigateway put-integration --rest-api-id $apiId --resource-id $targetIdResourceId --http-method OPTIONS --type MOCK --request-templates $mockTemplates | Out-Null

try {
    aws apigateway get-method-response --rest-api-id $apiId --resource-id $targetIdResourceId --http-method OPTIONS --status-code 200 2>$null | Out-Null
} catch {
    $methodRespParams = '{\"method.response.header.Access-Control-Allow-Headers\":false,\"method.response.header.Access-Control-Allow-Methods\":false,\"method.response.header.Access-Control-Allow-Origin\":false}'
    aws apigateway put-method-response --rest-api-id $apiId --resource-id $targetIdResourceId --http-method OPTIONS --status-code 200 --response-parameters $methodRespParams | Out-Null
}

$integRespParams = '{\"method.response.header.Access-Control-Allow-Headers\":\"''Authorization,Content-Type''\",\"method.response.header.Access-Control-Allow-Methods\":\"''GET,POST,DELETE,OPTIONS''\",\"method.response.header.Access-Control-Allow-Origin\":\"''*''\"}'
aws apigateway put-integration-response --rest-api-id $apiId --resource-id $targetIdResourceId --http-method OPTIONS --status-code 200 --response-parameters $integRespParams | Out-Null

# Get or create /targets/{targetId}/check resource
$checkResourceId = (aws apigateway get-resources --rest-api-id $apiId --query "items[?parentId=='$targetIdResourceId' && pathPart=='check'].id | [0]" --output text)
if (-not $checkResourceId -or $checkResourceId -eq "None") {
    Write-Host "Creating resource /targets/{targetId}/check..."
    $checkResourceId = (aws apigateway create-resource --rest-api-id $apiId --parent-id $targetIdResourceId --path-part 'check' --query id --output text)
}

# Put POST method on /targets/{targetId}/check
Write-Host "Configuring POST method on /targets/{targetId}/check..."
try {
    aws apigateway get-method --rest-api-id $apiId --resource-id $checkResourceId --http-method POST 2>$null | Out-Null
} catch {
    aws apigateway put-method --rest-api-id $apiId --resource-id $checkResourceId --http-method POST --authorization-type COGNITO_USER_POOLS --authorizer-id $authorizerId | Out-Null
}
aws apigateway put-integration --rest-api-id $apiId --resource-id $checkResourceId --http-method POST --type AWS_PROXY --integration-http-method POST --uri $integrationUri | Out-Null

# Put OPTIONS method on /targets/{targetId}/check
Write-Host "Configuring OPTIONS preflight on /targets/{targetId}/check..."
try {
    aws apigateway get-method --rest-api-id $apiId --resource-id $checkResourceId --http-method OPTIONS 2>$null | Out-Null
} catch {
    aws apigateway put-method --rest-api-id $apiId --resource-id $checkResourceId --http-method OPTIONS --authorization-type NONE | Out-Null
}
aws apigateway put-integration --rest-api-id $apiId --resource-id $checkResourceId --http-method OPTIONS --type MOCK --request-templates $mockTemplates | Out-Null

try {
    aws apigateway get-method-response --rest-api-id $apiId --resource-id $checkResourceId --http-method OPTIONS --status-code 200 2>$null | Out-Null
} catch {
    aws apigateway put-method-response --rest-api-id $apiId --resource-id $checkResourceId --http-method OPTIONS --status-code 200 --response-parameters $methodRespParams | Out-Null
}
aws apigateway put-integration-response --rest-api-id $apiId --resource-id $checkResourceId --http-method OPTIONS --status-code 200 --response-parameters $integRespParams | Out-Null

# Create Deployment
Write-Host "Creating API Gateway deployment for stage 'prod'..."
$deploymentId = (aws apigateway create-deployment --rest-api-id $apiId --description "Deploy check route" --query id --output text)
aws apigateway update-stage --rest-api-id $apiId --stage-name prod --patch-operations op=replace,path=/deploymentId,value=$deploymentId | Out-Null

Write-Host "`n✅ DEPLOYMENT FINISHED SUCCESSFULLY!"
Write-Host "API Endpoint: https://${apiId}.execute-api.${region}.amazonaws.com/prod/targets/{targetId}/check"
