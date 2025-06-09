#!/bin/bash

# === CONFIG ===
PROJECT_ROOT=$(git rev-parse --show-toplevel)
S3_BUCKET="transactions-bucket-1"
FRONTEND_DIR="$PROJECT_ROOT/application-code/web-tier"
BACKEND_DIR="$PROJECT_ROOT/application-code/app-tier"
FRONTEND_BUILD_DIR="$FRONTEND_DIR/build"
BACKEND_ZIP="$BACKEND_DIR/app.zip"

echo "🔵 Building React frontend..."
cd "$FRONTEND_DIR"
npm install
npm run build

cd "$BACKEND_DIR"
echo "🔵 Removing old node_modules..."
rm -rf node_modules
echo "🔵 Building Node frontend..."
npm install --omit=dev

if [ -f app.zip ]; then
  echo "🔵 Removing old app.zip..."
  rm app.zip
fi
echo "🔵 Zipping backend (excluding tests)..."
zip -r app.zip index.js DbConfig.js TransactionService.js node_modules/ \
  -x "*test*" "*.test.js"

echo "🔵 Uploading React build to S3..."
aws s3 cp "$FRONTEND_BUILD_DIR" s3://$S3_BUCKET/frontend/ --recursive
cd - > /dev/null

echo "🔵 Uploading backend zip to S3..."
aws s3 cp "$BACKEND_ZIP" s3://$S3_BUCKET/backend/app.zip
cd - > /dev/null

echo "✅ Deployment complete."
