#!/bin/bash
set -e
export AWS_PAGER=""

echo "🔁 Starting full AWS project setup..."

echo ""
echo "🔐 [0/4] Creating IAM group and attaching permissions..."
bash ./create-iam-group.sh

echo ""
echo "📦 [1/4] Creating S3 bucket and uploading frontend/backend builds..."
bash ./create-aws-bucket-and-copy-builds.sh

echo ""
echo "🌐 [2/4] Creating VPC, subnets, route table, and security groups..."
bash ./create-aws-vpc.sh

echo ""
echo "🛢️  [3/4] Creating RDS PostgreSQL instance in private subnet..."
bash ./create-aws-rds.sh

echo ""
echo "✅ All AWS resources created successfully."