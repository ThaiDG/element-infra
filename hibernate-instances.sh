#!/bin/bash

PREFIX=$1
REGION="ap-southeast-1"
TMP_DIR=$(mktemp -d)
ALL_INSTANCE_IDS=""

if [ -z "$PREFIX" ]; then
  echo "Usage: $0 <prefix>"
  echo "Example: $0 dev"
  exit 1
fi

hibernate_instances() {
  local PREFIX=$1
  local REGION=$2
  local SERVICE=$3
  local TMP_FILE=$4

  if [ -z "$SERVICE" ]; then
    echo "Missing service name"
    exit 1
  fi

  echo "Searching for '$SERVICE' instances with Name starting with '$PREFIX'..."

  INSTANCE_IDS=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-${SERVICE}*" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

  if [ -z "$INSTANCE_IDS" ]; then
    echo "No running instances found for service '$SERVICE'."
    return
  fi

  echo "Found '$SERVICE' instances: $INSTANCE_IDS"

  ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS \
    --query "AutoScalingInstances[].AutoScalingGroupName" \
    --output text)

  echo "Found ASG name: $ASG_NAME"

  aws autoscaling enter-standby \
    --instance-ids $INSTANCE_IDS \
    --auto-scaling-group-name "$ASG_NAME" \
    --should-decrement-desired-capacity \
    --region "$REGION"

  echo "Entered standby for $INSTANCE_IDS in ASG: $ASG_NAME"

  # Save to temp file
  echo "$INSTANCE_IDS" >> "$TMP_FILE"
}

# Run all instance discovery in parallel with separate temp files
SERVICES=("synapse" "sygnal" "coturn-tcp" "coturn-udp" "element" "certbot")
for SERVICE in "${SERVICES[@]}"; do
  TMP_FILE="${TMP_DIR}/${SERVICE}.txt"
  hibernate_instances "$PREFIX" "$REGION" "$SERVICE" "$TMP_FILE" &
done

# Wait for all to finish
wait

# Aggregate instance IDs from temp files
for FILE in "$TMP_DIR"/*.txt; do
  IDS=$(cat "$FILE")
  ALL_INSTANCE_IDS="$ALL_INSTANCE_IDS $IDS"
done

# Clean up temp files
rm -rf "$TMP_DIR"

# Hibernate and wait
if [ -n "$ALL_INSTANCE_IDS" ]; then
  echo "Stopping and hibernating instances: $ALL_INSTANCE_IDS"

  aws ec2 stop-instances \
    --region "$REGION" \
    --instance-ids $ALL_INSTANCE_IDS \
    --hibernate

  echo "Waiting for instances to stop..."

  aws ec2 wait instance-stopped \
    --region "$REGION" \
    --instance-ids $ALL_INSTANCE_IDS

  echo "All instances are now stopped and hibernated."
else
  echo "No instances found to hibernate."
fi
