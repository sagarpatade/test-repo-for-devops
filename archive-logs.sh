#!/bin/bash
BUCKET_NAME="my-app-log-bucket-sagar2025"
LOG_FILE="/var/log/cloud-init.log"
TIMESTAMP=$(date '+%Y-%m-%d-%H%M')
FILENAME="cloud-init-${TIMESTAMP}.log"
aws s3 cp "$LOG_FILE" "s3://${BUCKET_NAME}/ec2-logs/${FILENAME}"
