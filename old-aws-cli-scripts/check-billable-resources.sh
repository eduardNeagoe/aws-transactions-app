#!/bin/bash
set -e
export AWS_PAGER=""

USER_NAME="eduard"
POLICY_NAME="TempReadOnlyForBillingCheck"
REGIONS=("us-west-1" "us-east-1")  # Add more if needed

# Create temporary inline policy
POLICY_DOCUMENT=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "rds:DescribeDBInstances",
        "rds:DescribeDBSnapshots",
        "rds:DescribeDBSubnetGroups",
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "iam:ListInstanceProfiles",
        "iam:ListRoles"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

echo "🔐 Attaching temporary read-only permissions to user '$USER_NAME'..."
aws iam put-user-policy \
  --user-name "$USER_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document "$POLICY_DOCUMENT"

SLEEP_DURATION=20
echo "⏳ Waiting $SLEEP_DURATION seconds for IAM permissions to propagate..."
sleep $SLEEP_DURATION

#echo "⏳ Waiting for IAM policy to propagate..."
#MAX_RETRIES=10
#for i in $(seq 1 $MAX_RETRIES); do
#  if aws ec2 describe-instances --region "${REGIONS[0]}" >/dev/null 2>&1; then
#    echo "✅ Permission confirmed."
#    break
#  fi
#  echo "⌛ Retry $i/$MAX_RETRIES: Waiting 3 seconds..."
#  sleep 3
#done

echo ""
echo "📊 Checking billable resources in all regions..."
for REGION in "${REGIONS[@]}"; do
  echo "=== 🔵 REGION: $REGION 🔵 ==="
  echo ""

  echo "💻 EC2 Instances:"
  aws ec2 describe-instances --region "$REGION" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name]" \
  --output table || true

  echo "🪣 S3 Buckets (global):"
  if [[ "$REGION" == "${REGIONS[0]}" ]]; then
    aws s3api list-buckets --query "Buckets[*].Name" --output table || true
  fi

  echo "🛢️  RDS Instances:"
  aws rds describe-db-instances \
  --region "$REGION" \
  --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]" \
  --output table || true

  echo "🧠 RDS Snapshots:"
  aws rds describe-db-snapshots --region "$REGION" \
  --query "DBSnapshots[*].[DBSnapshotIdentifier,Status]" \
  --output table || true

  # Filter out default VPCs
  echo "🌐 VPCs:"
  aws ec2 describe-vpcs \
    --query "Vpcs[?IsDefault==\`false\`].[VpcId,Tags[?Key=='Name'].Value | [0]]" \
    --output table

  echo "🔐 EC2 IAM Instance Profiles:"
  aws iam list-instance-profiles \
    --query "InstanceProfiles[*].InstanceProfileName" \
    --output table || echo "⚠️  Could not list instance profiles."

  echo "🔐 EC2 IAM Roles:"
  aws iam list-roles \
    --query "Roles[?contains(RoleName, 'ec2')].RoleName" \
    --output table || echo "⚠️  Could not list EC2 roles."

  echo "🔐 Security Groups (non-default):"
  aws ec2 describe-security-groups \
    --query "SecurityGroups[?GroupName!='default'].[GroupId,GroupName]" \
    --output table

      echo ""
done

echo "🧽 Cleaning up temporary permissions..."
aws iam delete-user-policy \
  --user-name "$USER_NAME" \
  --policy-name "$POLICY_NAME"

echo "✅ Billing check complete and temporary read permissions cleaned up."