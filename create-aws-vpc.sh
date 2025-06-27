#!/bin/bash
set -e
export AWS_PAGER=""

REGION="us-west-1"
export AWS_DEFAULT_REGION=$REGION
AZ1="us-west-1b"
AZ2="us-west-1c"
VPC_NAME="aws-transactions-app-vpc"

echo "🔍 Checking if VPC '$VPC_NAME' exists..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" \
  --output text)

if [[ "$VPC_ID" == "None" || -z "$VPC_ID" ]]; then
  echo "🔵 Creating new VPC..."
  VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --query "Vpc.VpcId" \
    --output text)

  aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value="$VPC_NAME"
  aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames "{\"Value\":true}"
else
  echo "✅ Reusing VPC: $VPC_ID"
fi

# === Subnet helper function ===
create_subnet() {
  NAME=$1
  CIDR=$2
  AZ=$3

  SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=$NAME" \
    --query "Subnets[0].SubnetId" \
    --output text)

  if [[ "$SUBNET_ID" == "None" || -z "$SUBNET_ID" ]]; then
    echo "🔵 Creating subnet $NAME..."
    SUBNET_ID=$(aws ec2 create-subnet \
      --vpc-id "$VPC_ID" \
      --cidr-block "$CIDR" \
      --availability-zone "$AZ" \
      --query "Subnet.SubnetId" \
      --output text)

    aws ec2 create-tags --resources "$SUBNET_ID" --tags Key=Name,Value="$NAME"
  else
    echo "✅ Reusing subnet $NAME: $SUBNET_ID"
  fi

  echo "$SUBNET_ID"
}

PUBLIC_SUBNET_ID=$(create_subnet "aws-transactions-app-public-subnet" "10.0.1.0/24" "$AZ1")
PRIVATE_SUBNET_ID_1=$(create_subnet "aws-transactions-app-private-subnet-1" "10.0.2.0/24" "$AZ1")
PRIVATE_SUBNET_ID_2=$(create_subnet "aws-transactions-app-private-subnet-2" "10.0.3.0/24" "$AZ2")

if [[ -z "$PRIVATE_SUBNET_ID_1" || -z "$PRIVATE_SUBNET_ID_2" ]]; then
  echo "❌ One or both private subnets failed to create. Exiting."
  exit 1
fi

# === Internet Gateway ===
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" \
  --query "InternetGateways[0].InternetGatewayId" \
  --output text)

if [[ "$IGW_ID" == "None" || -z "$IGW_ID" ]]; then
  echo "🔵 Creating Internet Gateway..."
  IGW_ID=$(aws ec2 create-internet-gateway \
    --query "InternetGateway.InternetGatewayId" \
    --output text)

  aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
  aws ec2 create-tags --resources "$IGW_ID" --tags Key=Name,Value="aws-transactions-app-igw"
else
  echo "✅ Reusing Internet Gateway: $IGW_ID"
fi

# === Route Table ===
ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query "RouteTables[?Routes[?DestinationCidrBlock=='0.0.0.0/0']].RouteTableId" \
  --output text)

if [[ -z "$ROUTE_TABLE_ID" ]]; then
  echo "🔵 Creating public route table..."
  ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --query "RouteTable.RouteTableId" \
    --output text)

  aws ec2 create-route \
    --route-table-id "$ROUTE_TABLE_ID" \
    --destination-cidr-block "0.0.0.0/0" \
    --gateway-id "$IGW_ID"

  aws ec2 associate-route-table \
    --subnet-id "$PUBLIC_SUBNET_ID" \
    --route-table-id "$ROUTE_TABLE_ID"

  aws ec2 create-tags --resources "$ROUTE_TABLE_ID" --tags Key=Name,Value="aws-transactions-app-public-route-table"
else
  echo "✅ Reusing public route table: $ROUTE_TABLE_ID"
fi

# === Security Groups ===
create_sg() {
  NAME=$1
  DESCRIPTION=$2

  SG_ID=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values="$NAME" Name=vpc-id,Values="$VPC_ID" \
    --query "SecurityGroups[0].GroupId" \
    --output text)

  if [[ "$SG_ID" == "None" || -z "$SG_ID" ]]; then
    echo "🔵 Creating security group $NAME..."
    SG_ID=$(aws ec2 create-security-group \
      --group-name "$NAME" \
      --description "$DESCRIPTION" \
      --vpc-id "$VPC_ID" \
      --query "GroupId" \
      --output text)
  else
    echo "✅ Reusing security group $NAME: $SG_ID"
  fi

  echo "$SG_ID"
}

WEB_SG_ID=$(create_sg "web-sg" "Web tier SG")
APP_SG_ID=$(create_sg "app-sg" "App tier SG")
DB_SG_ID=$(create_sg "db-sg" "Database SG")

# === Ingress rules (best effort) ===
echo "🔧 Authorizing ingress rules (if not already present)..."
aws ec2 authorize-security-group-ingress --group-id "$WEB_SG_ID" --protocol tcp --port 80  --cidr 0.0.0.0/0 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "$WEB_SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "$WEB_SG_ID" --protocol tcp --port 22  --cidr 0.0.0.0/0 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "$APP_SG_ID" --protocol tcp --port 3000 --source-group "$WEB_SG_ID" 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "$DB_SG_ID" --protocol tcp --port 5432 --source-group "$APP_SG_ID" 2>/dev/null || true

# === Done ===
echo ""
echo "✅ VPC setup complete."
echo "VPC ID: $VPC_ID"
echo "Public Subnet: $PUBLIC_SUBNET_ID"
echo "Private Subnet 1: $PRIVATE_SUBNET_ID_1"
echo "Private Subnet 2: $PRIVATE_SUBNET_ID_2"
echo "Internet Gateway: $IGW_ID"
echo "Route Table: $ROUTE_TABLE_ID"
echo "Web SG: $WEB_SG_ID"
echo "App SG: $APP_SG_ID"
echo "DB SG: $DB_SG_ID"