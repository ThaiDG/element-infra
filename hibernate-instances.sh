#!/bin/bash

PREFIX=$1
REGION="ap-southeast-1"

if [ -z "$PREFIX" ]; then
  echo "Usage: $0 <prefix>"
  echo "Example: $0 dev"
  exit 1
fi

hibernate_instances() {
  local PREFIX=$1
  local REGION=$2
  local SERVICE=$3

  # Validate input
  if [ -z "$SERVICE" ]; then
    echo "Usage: $0 <prefix> <region> <service>"
    echo "Example: $0 dev ap-southeast-1 synapse"
    exit 1
  fi

  echo "Searching for '$SERVICE' instances with Name starting with '$PREFIX' in region $REGION..."

  # Get the Synapse instances
  INSTANCE_IDS=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-${SERVICE}*" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

  if [ -z "$INSTANCE_IDS" ]; then
    echo "No running instances found with prefix '$PREFIX'."
    exit 0
  fi

  echo "Found '$SERVICE' instances: $INSTANCE_IDS"

  # Get the ASG name for the instances
  echo "Getting ASG name for '$SERVICE' instances..."

  ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS \
    --query "AutoScalingInstances[].AutoScalingGroupName" \
    --output text)

  echo "Found ASG name: $ASG_NAME"

  # Enter standby for instances in ASG
  echo "Entering standby for '$SERVICE' instances in ASG..."

  aws autoscaling enter-standby \
    --instance-ids $INSTANCE_IDS \
    --auto-scaling-group-name "$ASG_NAME" \
    --should-decrement-desired-capacity \
    --region "$REGION"

  echo "Entered standby for $INSTANCE_IDS in $ASG_NAME and set desired capacity to 0"

  echo "Attempting to hibernate..."

  aws ec2 stop-instances \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS \
    --hibernate

  echo "Hibernate command issued."
}

# Call the function with the provided prefix and region
hibernate_instances "$PREFIX" "$REGION" "synapse"
hibernate_instances "$PREFIX" "$REGION" "sygnal"
hibernate_instances "$PREFIX" "$REGION" "coturn-tcp"
hibernate_instances "$PREFIX" "$REGION" "coturn-udp"
hibernate_instances "$PREFIX" "$REGION" "element"
hibernate_instances "$PREFIX" "$REGION" "certbot"
