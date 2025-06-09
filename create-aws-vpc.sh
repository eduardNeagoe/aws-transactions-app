#!/bin/bash
export AWS_PAGER=""
set -e

REGION="us-east-1"
AZ="us-east-1a"
VPC_NAME="aws-transactions-app-vpc"

echo "🔵 Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region $REGION \
  --query "Vpc.VpcId" \
  --output text)

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}"
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME
echo "🔵 VPC ID: $VPC_ID"

echo "🔵 Creating public and private subnets..."
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone $AZ \
  --query "Subnet.SubnetId" \
  --output text)

PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone $AZ \
  --query "Subnet.SubnetId" \
  --output text)

aws ec2 create-tags --resources $PUBLIC_SUBNET_ID --tags Key=Name,Value=public-subnet
aws ec2 create-tags --resources $PRIVATE_SUBNET_ID --tags Key=Name,Value=private-subnet

echo "🔵 Creating and attaching Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=aws-transactions-app-igw

echo "🔵 Creating public route table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query "RouteTable.RouteTableId" \
  --output text)

aws ec2 create-tags --resources $ROUTE_TABLE_ID --tags Key=Name,Value=aws-transactions-app-public-route-table

aws ec2 create-route \
  --route-table-id $ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws ec2 associate-route-table \
  --subnet-id $PUBLIC_SUBNET_ID \
  --route-table-id $ROUTE_TABLE_ID

echo "🔵 Creating security groups..."

WEB_SG_ID=$(aws ec2 create-security-group \
  --group-name web-sg \
  --description "Web tier SG" \
  --vpc-id $VPC_ID \
  --query "GroupId" \
  --output text)

aws ec2 authorize-security-group-ingress --group-id $WEB_SG_ID \
  --protocol tcp --port 80  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $WEB_SG_ID \
  --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $WEB_SG_ID \
  --protocol tcp --port 22  --cidr 0.0.0.0/0

APP_SG_ID=$(aws ec2 create-security-group \
  --group-name app-sg \
  --description "App tier SG" \
  --vpc-id $VPC_ID \
  --query "GroupId" \
  --output text)

aws ec2 authorize-security-group-ingress --group-id $APP_SG_ID \
  --protocol tcp --port 3000 --source-group $WEB_SG_ID

DB_SG_ID=$(aws ec2 create-security-group \
  --group-name db-sg \
  --description "Database SG" \
  --vpc-id $VPC_ID \
  --query "GroupId" \
  --output text)

aws ec2 authorize-security-group-ingress --group-id $DB_SG_ID \
  --protocol tcp --port 5432 --source-group $APP_SG_ID

echo ""
echo "🔵 ✅ Setup complete."
echo "🔵 VPC: $VPC_ID"
echo "🔵 Public Subnet: $PUBLIC_SUBNET_ID"
echo "🔵 Private Subnet: $PRIVATE_SUBNET_ID"
echo "🔵 Internet Gateway: $IGW_ID"
echo "🔵 Route Table: $ROUTE_TABLE_ID"
echo "🔵 Web SG: $WEB_SG_ID"
echo "🔵 App SG: $APP_SG_ID"
echo "🔵 DB SG: $DB_SG_ID"
