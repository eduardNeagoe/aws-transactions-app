#!/bin/bash
set -e
export AWS_PAGER=""

# === CONFIG ===
REGION="us-west-1"
export AWS_DEFAULT_REGION=$REGION
VPC_NAME="aws-transactions-app-vpc"
RDS_INSTANCE_ID="aws-transactions-app-db-instance-id"
RDS_SUBNET_GROUP="aws-transactions-app-db-subnet-group"
S3_BUCKET="aws-transactions-app-bucket"
IAM_GROUP="eduards-group"

echo "🚨 WARNING: This script will delete ALL AWS resources related to this project (except user 'eduard')."
read -p "Are you sure? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "❌ Aborted."
  exit 1
fi

echo ""
echo "🗑️ Deleting RDS instance..."
if aws rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE_ID" >/dev/null 2>&1; then
  aws rds delete-db-instance \
    --db-instance-identifier "$RDS_INSTANCE_ID" \
    --skip-final-snapshot \
    --delete-automated-backups
  echo "⏳ Waiting for RDS instance to be deleted..."
  aws rds wait db-instance-deleted --db-instance-identifier "$RDS_INSTANCE_ID"
else
  echo "ℹ️ RDS instance not found or already deleted."
fi

echo ""
echo "🧹 Deleting DB Subnet Group..."
if aws rds describe-db-subnet-groups --db-subnet-group-name "$RDS_SUBNET_GROUP" >/dev/null 2>&1; then
  aws rds delete-db-subnet-group --db-subnet-group-name "$RDS_SUBNET_GROUP"
else
  echo "ℹ️ Subnet group not found or already deleted."
fi

echo ""
echo "🧹 Emptying and deleting S3 bucket..."
if aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
  aws s3 rm "s3://$S3_BUCKET" --recursive || true
  aws s3api delete-bucket --bucket "$S3_BUCKET"
else
  echo "ℹ️ S3 bucket not found or already deleted."
fi

echo ""
echo "🧨 Terminating EC2 instances by tag..."
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=aws-transactions-app-*-ec2" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)
if [[ -n "$INSTANCE_IDS" && "$INSTANCE_IDS" != "None" ]]; then
  echo "🧨 Found EC2 instances: $INSTANCE_IDS"
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
  echo "⏳ Waiting for EC2 instances to terminate..."
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS
  echo "✅ EC2 instances terminated."
else
  echo "ℹ️ No EC2 instances found with tag Name=aws-transactions-app-*-ec2"
fi

echo ""
echo "🧼 Cleaning up IAM instance profiles..."
PROFILE_NAME="ec2-aws-transactions-app-profile"
if aws iam get-instance-profile --instance-profile-name "$PROFILE_NAME" >/dev/null 2>&1; then
  ROLE_NAMES=$(aws iam get-instance-profile \
    --instance-profile-name "$PROFILE_NAME" \
    --query 'InstanceProfile.Roles[*].RoleName' \
    --output text)

  for ROLE in $ROLE_NAMES; do
    echo "❌ Removing role $ROLE from profile $PROFILE_NAME"
    aws iam remove-role-from-instance-profile \
      --instance-profile-name "$PROFILE_NAME" \
      --role-name "$ROLE"
  done

  echo "🗑️ Deleting instance profile: $PROFILE_NAME"
  aws iam delete-instance-profile --instance-profile-name "$PROFILE_NAME"
else
  echo "ℹ️ Instance profile $PROFILE_NAME not found or already deleted."
fi

for ROLE in $ROLE_NAMES; do
  echo "🔐 Detaching and deleting policies for role $ROLE..."
  ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE" --query "AttachedPolicies[*].PolicyArn" --output text)
  for POLICY_ARN in $ATTACHED_POLICIES; do
    aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$POLICY_ARN"
  done

  echo "🗑️ Deleting role $ROLE..."
  aws iam delete-role --role-name "$ROLE"
done

echo ""
echo "🧼 Cleaning up VPC resources..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" \
  --output text)

if [[ "$VPC_ID" == "None" || -z "$VPC_ID" ]]; then
  echo "ℹ️ VPC not found. Nothing to delete."
else
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters Name=attachment.vpc-id,Values="$VPC_ID" \
    --query "InternetGateways[0].InternetGatewayId" \
    --output text)

  if [[ "$IGW_ID" != "None" && -n "$IGW_ID" ]]; then
    echo "🔌 Detaching and deleting Internet Gateway..."
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"
  fi

  echo "📡 Deleting custom route tables..."
  ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables \
    --filters Name=vpc-id,Values="$VPC_ID" \
    --query "RouteTables[*].RouteTableId" \
    --output text)

  for RT_ID in $ROUTE_TABLE_IDS; do
    aws ec2 delete-route-table --route-table-id "$RT_ID" 2>/dev/null || true
  done

  echo "🌐 Deleting subnets..."
  SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters Name=vpc-id,Values="$VPC_ID" \
    --query "Subnets[*].SubnetId" \
    --output text)

  for SUBNET_ID in $SUBNET_IDS; do
    aws ec2 delete-subnet --subnet-id "$SUBNET_ID"
  done

  echo "🔐 Deleting custom security groups..."
  SG_IDS=$(aws ec2 describe-security-groups \
    --filters Name=vpc-id,Values="$VPC_ID" \
    --query "SecurityGroups[*].GroupId" \
    --output text)

  for SG_ID in $SG_IDS; do
    if [[ "$SG_ID" != *"default"* ]]; then
      aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null || true
    fi
  done

  echo "🧨 Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc --vpc-id "$VPC_ID"
fi

echo ""
echo "🧽 Cleaning up IAM resources (preserving user 'eduard', but removing from group)..."
if aws iam get-group --group-name "$IAM_GROUP" >/dev/null 2>&1; then
  USERS=$(aws iam get-group --group-name "$IAM_GROUP" --query "Users[*].UserName" --output text)
  for USER in $USERS; do
    echo "🧹 Removing user '$USER' from group '$IAM_GROUP'..."
    aws iam remove-user-from-group --user-name "$USER" --group-name "$IAM_GROUP"
  done

  echo "🧹 Detaching policies from group '$IAM_GROUP'..."
  POLICY_ARNS=$(aws iam list-attached-group-policies --group-name "$IAM_GROUP" --query "AttachedPolicies[*].PolicyArn" --output text)
  for POLICY_ARN in $POLICY_ARNS; do
    aws iam detach-group-policy --group-name "$IAM_GROUP" --policy-arn "$POLICY_ARN"
  done

  echo "🧨 Deleting IAM group '$IAM_GROUP'..."
  aws iam delete-group --group-name "$IAM_GROUP"
else
  echo "ℹ️ IAM group '$IAM_GROUP' not found or already deleted."
fi

echo ""
echo "✅ Full cleanup complete."