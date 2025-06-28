#!/bin/bash
set -e
export AWS_PAGER=""

echo "🔁 Starting full AWS project setup..."

echo ""
echo "🔐 [1/5] Creating IAM group and attaching permissions..."
bash ./create-iam-group.sh

echo ""
echo "📦 [2/5] Creating S3 bucket and uploading frontend/backend builds..."
bash ./create-aws-bucket-and-copy-builds.sh

echo ""
echo "🌐 [3/5] Creating VPC, subnets, route table, and security groups..."
bash ./create-aws-vpc.sh

#TODO re-enable
#echo ""
#echo "🛢️  [4/5] Creating RDS PostgreSQL instance in private subnet..."
#bash ./create-aws-rds.sh

echo ""
echo "🚀️  [5/5] Deploying frontend and backend apps to EC2..."
bash ./deploy-apps.sh

echo ""
echo "✅ All AWS resources created successfully."