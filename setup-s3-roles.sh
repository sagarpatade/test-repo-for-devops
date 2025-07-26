#!/bin/bash

# Exit on error
set -e

# Bucket name argument
BUCKET_NAME=$1
REGION="ap-northeast-1"  # ‚úÖ Tokyo region

if [ -z "$BUCKET_NAME" ]; then
  echo "‚ùå Error: Please provide a bucket name."
  echo "Usage: $0 <bucket-name>"
  exit 1
fi

echo "Ì¥ß Starting IAM role and S3 setup..."

# Role 1: Read-only S3 role
aws iam create-role --role-name S3ReadOnlyRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }' > /dev/null || echo "‚ÑπÔ∏è Role S3ReadOnlyRole already exists"

aws iam attach-role-policy \
  --role-name S3ReadOnlyRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

echo "‚úÖ Created S3ReadOnlyRole"

# Role 2: Write-only S3 role (no read permission)
aws iam create-role --role-name S3WriteOnlyRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }' > /dev/null || echo "‚ÑπÔ∏è Role S3WriteOnlyRole already exists"

aws iam put-role-policy \
  --role-name S3WriteOnlyRole \
  --policy-name S3WriteOnlyPolicy \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Action\": [\"s3:PutObject\", \"s3:ListBucket\"],
        \"Resource\": [
          \"arn:aws:s3:::$BUCKET_NAME\",
          \"arn:aws:s3:::$BUCKET_NAME/*\"
        ]
      }
    ]
  }"

echo "‚úÖ Created S3WriteOnlyRole with limited access"

# Instance profile creation
aws iam create-instance-profile --instance-profile-name EC2WriteOnlyProfile || echo "‚ÑπÔ∏è Instance profile already exists"
aws iam add-role-to-instance-profile --instance-profile-name EC2WriteOnlyProfile --role-name S3WriteOnlyRole || echo "‚ÑπÔ∏è Role already attached"

echo "‚úÖ Created and attached EC2WriteOnlyProfile"

# Create private S3 bucket in Tokyo region
echo "Ì∫£ Creating private bucket: $BUCKET_NAME in $REGION"

aws s3api create-bucket --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

aws s3api put-bucket-acl --bucket "$BUCKET_NAME" --acl private

echo "‚úÖ S3 bucket $BUCKET_NAME created and secured"

# Lifecycle rule: Delete logs after 7 days
aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET_NAME" \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "DeleteLogsAfter7Days",
        "Filter": {
          "Prefix": ""
        },
        "Status": "Enabled",
        "Expiration": {
          "Days": 7
        }
      }
    ]
  }'

echo "Ì∑π Lifecycle rule applied (delete logs after 7 days)"

echo "Ìæâ All setup completed successfully!"

