#!/bin/bash
set -e
export AWS_PAGER=""

GROUP_NAME="eduards-group"
USER_NAME="eduard"

# TODO: Important:
#   The IAM user 'eduard' must already have permissions to manage IAM resources
#   for this script to succeed (creating groups, attaching policies).
#   So I granted 'eduard' the IAMFullAccess policy manually using the AWS Console.
#   Why? Because using the root user with AWS CLI is strongly discouraged by AWS
#   for security reasons.


echo "🔵 Creating IAM group (if not exists)..."
aws iam create-group --group-name "$GROUP_NAME" 2>/dev/null || echo "ℹ️ Group already exists."

echo "🔵 Attaching policies..."
aws iam attach-group-policy --group-name "$GROUP_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-group-policy --group-name "$GROUP_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam attach-group-policy --group-name "$GROUP_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

aws iam attach-group-policy --group-name "$GROUP_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess

echo "🔵 Adding user '$USER_NAME' to group '$GROUP_NAME'..."
aws iam add-user-to-group --user-name "$USER_NAME" --group-name "$GROUP_NAME" 2>/dev/null || echo "ℹ️ User already in group."

echo "✅ Done."