#!/bin/bash
set -e
export AWS_PAGER=""

# === CONFIG ===
PROJECT_ROOT=$(git rev-parse --show-toplevel)
S3_BUCKET="aws-transactions-app-bucket-1"
REGION="us-east-1"
FRONTEND_DIR="$PROJECT_ROOT/application-code/web-tier"
BACKEND_DIR="$PROJECT_ROOT/application-code/app-tier"
FRONTEND_BUILD_DIR="$FRONTEND_DIR/build"
BACKEND_ZIP="$BACKEND_DIR/app.zip"

# === BUCKET SETUP ===
echo "🔵 Checking if S3 bucket exists..."
if aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
  echo "✅ Bucket $S3_BUCKET already exists."
else
  echo "🔸 Bucket not found. Creating bucket: $S3_BUCKET..."

aws s3api create-bucket \
  --bucket "$S3_BUCKET" \
  --region "$REGION"

  echo "✅ Bucket $S3_BUCKET created."
fi

# === FRONTEND BUILD ===
echo "🔵 Building React frontend..."
cd "$FRONTEND_DIR"
npm install
npm run build

# === BACKEND BUILD ===
cd "$BACKEND_DIR"
echo "🔵 Removing old node_modules..."
rm -rf node_modules

echo "🔵 Installing Node backend deps..."
npm install --omit=dev

if [ -f app.zip ]; then
  echo "🔵 Removing old app.zip..."
  rm app.zip
fi

echo "🔵 Zipping backend (excluding tests)..."
zip -r app.zip index.js DbConfig.js TransactionService.js node_modules/ \
  -x "*test*" "*.test.js"

# === UPLOAD TO S3 ===
echo "🔵 Uploading React build to S3..."
aws s3 cp "$FRONTEND_BUILD_DIR" s3://$S3_BUCKET/frontend/ --recursive

echo "🔵 Uploading backend zip to S3..."
aws s3 cp "$BACKEND_ZIP" s3://$S3_BUCKET/backend/app.zip

echo "✅ Deployment complete."
