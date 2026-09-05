#!/bin/bash
set -e
source "$(dirname "$0")/../config/variables.sh"

echo "=== Phase 8: S3 static website ==="
INFRA_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$(dirname "$INFRA_DIR")/pulsewatch-frontend/dist"
if [ ! -f "$BUILD_DIR/index.html" ]; then
  echo "Frontend build output is missing: $BUILD_DIR/index.html"
  echo "Build pulsewatch-frontend first with: npm run build"
  exit 1
fi
FRONTEND_BUCKET="${PROJECT}-frontend-${ACCOUNT_ID}"
if ! aws s3api head-bucket --bucket "$FRONTEND_BUCKET" >/dev/null 2>&1; then
  aws s3api create-bucket --bucket "$FRONTEND_BUCKET" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION" >/dev/null
fi
aws s3api put-public-access-block --bucket "$FRONTEND_BUCKET" --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false
aws s3api put-bucket-website --bucket "$FRONTEND_BUCKET" --website-configuration '{"IndexDocument":{"Suffix":"index.html"}}'
aws s3api put-bucket-policy --bucket "$FRONTEND_BUCKET" --policy "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"PublicReadForWebsite\",\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::${FRONTEND_BUCKET}/*\"}]}"
aws s3 sync "$BUILD_DIR" "s3://$FRONTEND_BUCKET" --delete
SITE_URL="http://${FRONTEND_BUCKET}.s3-website.${REGION}.amazonaws.com"
export FRONTEND_BUCKET SITE_URL
echo "FRONTEND_BUCKET: $FRONTEND_BUCKET"
echo "SITE_URL: $SITE_URL"
echo "S3 website hosting is HTTP only; CloudFront and HTTPS are intentionally not configured."
