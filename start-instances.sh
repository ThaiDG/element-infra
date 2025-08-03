#!/bin/bash

PREFIX=$1
REGION="ap-southeast-1"
ALL_INSTANCE_IDS=""

if [ -z "$PREFIX" ]; then
  echo "Usage: $0 <prefix>"
  echo "Example: $0 dev"
  exit 1
fi

resume_instances() {
  local PREFIX=$1
  local REGION=$2
  local SERVICE=$3

  echo "Searching for '$SERVICE' instances with Name starting with '$PREFIX' and in 'stopped' state..."

  INSTANCE_IDS=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-${SERVICE}*" "Name=instance-state-name,Values=stopped" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

  if [ -z "$INSTANCE_IDS" ]; then
    echo "No stopped instances found for service '$SERVICE'."
    return
  fi

  echo "Found stopped '$SERVICE' instances: $INSTANCE_IDS"

  # Start instances
  aws ec2 start-instances \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS

  echo "Started instances: $INSTANCE_IDS"

  # Wait for instances to enter 'running' state
  aws ec2 wait instance-running \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS

  echo "'$SERVICE' instances are now running."

  # Rejoin ASG
  ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS \
    --query "AutoScalingInstances[].AutoScalingGroupName" \
    --output text)

  if [ -n "$ASG_NAME" ]; then
    aws autoscaling exit-standby \
      --instance-ids $INSTANCE_IDS \
      --auto-scaling-group-name "$ASG_NAME" \
      --region "$REGION"

    echo "Exited standby for $INSTANCE_IDS in ASG: $ASG_NAME"
  else
    echo "ASG name not found for $INSTANCE_IDS. Skipping exit-standby."
  fi

  ALL_INSTANCE_IDS="$ALL_INSTANCE_IDS $INSTANCE_IDS"
}

# Resume services one by one
SERVICES=("synapse" "sygnal" "coturn-tcp" "coturn-udp" "element" "certbot")
for SERVICE in "${SERVICES[@]}"; do
  resume_instances "$PREFIX" "$REGION" "$SERVICE"
done

if [ -n "$ALL_INSTANCE_IDS" ]; then
  echo "✅ All instances resumed: $ALL_INSTANCE_IDS"
else
  echo "⚠️ No instances were resumed."
fi
