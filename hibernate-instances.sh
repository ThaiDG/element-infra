#!/bin/bash

PREFIX=$1
REGION="ap-southeast-1"

if [ -z "$PREFIX" ]; then
  echo "Usage: $0 <prefix>"
  echo "Example: $0 dev-"
  exit 1
fi

echo "Searching for instances with Name starting with '$PREFIX' in region $REGION..."

INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=${PREFIX}*" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

if [ -z "$INSTANCE_IDS" ]; then
  echo "No running instances found with prefix '$PREFIX'."
  exit 0
fi

echo "Found instances: $INSTANCE_IDS"
echo "Attempting to hibernate..."

aws ec2 stop-instances \
  --region "$REGION" \
  --instance-ids $INSTANCE_IDS \
  --hibernate

echo "Hibernate command issued."
