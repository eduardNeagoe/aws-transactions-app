#!/bin/bash
set -e
export AWS_PAGER=""
REGION="us-west-1"
export AWS_DEFAULT_REGION=$REGION

# === IAM Role Setup for EC2 ===
ROLE_NAME="ec2-aws-transactions-app-role"
PROFILE_NAME="ec2-aws-transactions-app-profile"

echo "🔍 Checking if IAM role '$ROLE_NAME' exists..."
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "🔧 Creating IAM role '$ROLE_NAME'..."

  TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)

  echo "$TRUST_POLICY" > trust-policy.json

  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file://trust-policy.json

  rm trust-policy.json

  echo "🔒 Attaching policies..."
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess
fi

echo "🔍 Checking if instance profile '$PROFILE_NAME' exists..."
if ! aws iam get-instance-profile --instance-profile-name "$PROFILE_NAME" >/dev/null 2>&1; then
  echo "📦 Creating instance profile..."
  aws iam create-instance-profile --instance-profile-name "$PROFILE_NAME"
  echo "⛓️  Adding role to profile..."
  aws iam add-role-to-instance-profile \
    --instance-profile-name "$PROFILE_NAME" \
    --role-name "$ROLE_NAME"
fi

echo "⏳ Waiting for instance profile propagation..."
sleep 10

# === Dynamic Lookups ===
echo "🔍 Fetching dynamic EC2 config..."

AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
            "Name=state,Values=available" \
  --query "Images[*].[ImageId,CreationDate]" \
  --output text | sort -k2 -r | head -n 1 | cut -f1)

INSTANCE_TYPE="t2.micro"

KEY_NAME=$(aws ec2 describe-key-pairs --query "KeyPairs[0].KeyName" --output text)

FRONTEND_SG=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=web-sg \
  --query "SecurityGroups[0].GroupId" --output text)

BACKEND_SG=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=app-sg \
  --query "SecurityGroups[0].GroupId" --output text)

FRONTEND_SUBNET=$(aws ec2 describe-subnets \
  --filters Name=tag:Name,Values=aws-transactions-app-public-subnet \
  --query "Subnets[0].SubnetId" --output text)

BACKEND_SUBNET=$(aws ec2 describe-subnets \
  --filters Name=tag:Name,Values=aws-transactions-app-private-subnet-1 \
  --query "Subnets[0].SubnetId" --output text)

# === EC2 Key Pair Setup ===
KEY_NAME="ec2-transactions-key"
KEY_FILE="ec2-transactions-key.pem"

echo "🔍 Checking if EC2 key pair '$KEY_NAME' exists..."
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
  echo "🔐 Creating EC2 key pair '$KEY_NAME'..."
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --query "KeyMaterial" \
    --output text > "$KEY_FILE"
  chmod 400 "$KEY_FILE"
  echo "✅ Key pair created and saved as $KEY_FILE"
else
  echo "✅ Reusing existing EC2 key pair: $KEY_NAME"
fi

# === Launch Frontend ===
echo "🚀 Launching Frontend EC2 Instance..."
aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$FRONTEND_SG" \
  --subnet-id "$FRONTEND_SUBNET" \
  --iam-instance-profile Name="$PROFILE_NAME" \
  --associate-public-ip-address \
  --user-data file://deploy-frontend-user-data.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=aws-transactions-app-frontend-ec2}]"

# === Launch Backend ===
echo ""
echo "🚀 Launching Backend EC2 Instance..."
aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$BACKEND_SG" \
  --subnet-id "$BACKEND_SUBNET" \
  --iam-instance-profile Name="$PROFILE_NAME" \
  --associate-public-ip-address \
  --user-data file://deploy-backend-user-data.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=aws-transactions-app-backend-ec2}]"

echo ""
echo "✅ Both frontend and backend EC2 instances are launching."