#!/bin/bash
set -e

echo "📦 Installing Node.js, AWS CLI, and unzip..."
curl -sL https://rpm.nodesource.com/setup_16.x | bash -
yum install -y nodejs aws-cli unzip

echo "📁 Changing to EC2 user home directory..."
cd /home/ec2-user || exit

echo "⬇️ Downloading backend app zip from S3..."
aws s3 cp s3://aws-transactions-app-bucket/backend/app.zip .

echo "📂 Unzipping backend app..."
unzip app.zip

echo "🔒 Ensuring permissions for Node.js app..."
chmod +x *.js

echo "🚀 Launching Node.js application..."
nohup node index.js > app.log 2>&1 &

echo "✅ Backend deployment script completed successfully."