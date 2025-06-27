#!/bin/bash
set -e
export AWS_PAGER=""

REGION="us-west-1"
export AWS_DEFAULT_REGION=$REGION
DB_SUBNET_GROUP_NAME="aws-transactions-app-db-subnet-group"
DB_INSTANCE_ID="aws-transactions-app-db-instance-id"
DB_NAME="AwsTransactionsAppDb"
DB_USERNAME="eduard_rds_user"
DB_PASSWORD="eduard_rds_pass"  # replace this securely

echo "🔎 Fetching VPC and subnet IDs..."

PRIVATE_SUBNET_ID_1=$(aws ec2 describe-subnets \
  --filters Name=tag:Name,Values=aws-transactions-app-private-subnet-1 \
  --query "Subnets[0].SubnetId" \
  --output text)

PRIVATE_SUBNET_ID_2=$(aws ec2 describe-subnets \
  --filters Name=tag:Name,Values=aws-transactions-app-private-subnet-2 \
  --query "Subnets[0].SubnetId" \
  --output text)

DB_SG_ID=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=db-sg \
  --query "SecurityGroups[0].GroupId" \
  --output text)

# === DB Subnet Group ===
echo "🔍 Checking if DB subnet group '$DB_SUBNET_GROUP_NAME' exists..."
if aws rds describe-db-subnet-groups \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
  > /dev/null 2>&1; then
  echo "✅ DB subnet group already exists."
else
  echo "🔵 Creating DB subnet group..."
  aws rds create-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --db-subnet-group-description "Private subnets for RDS" \
    --subnet-ids "$PRIVATE_SUBNET_ID_1" "$PRIVATE_SUBNET_ID_2" \
    --region "$REGION"
fi

# === DB Instance ===
echo "🔍 Checking if RDS instance '$DB_INSTANCE_ID' exists..."
if aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$REGION" \
  > /dev/null 2>&1; then
  echo "✅ RDS instance already exists. Skipping creation."
else
  echo "🔵 Creating PostgreSQL RDS instance..."
  aws rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --allocated-storage 20 \
    --no-publicly-accessible \
    --vpc-security-group-ids "$DB_SG_ID" \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --master-username "$DB_USERNAME" \
    --master-user-password "$DB_PASSWORD" \
    --db-name "$DB_NAME" \
    --backup-retention-period 0 \
    --region "$REGION"

  echo "⏳ Waiting for RDS instance to become available..."
  aws rds wait db-instance-available \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --region "$REGION"
fi

# === DB Endpoint ===
DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$REGION" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)

echo "✅ RDS setup complete."
echo "🔗 Endpoint: $DB_ENDPOINT"