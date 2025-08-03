#!/bin/bash

PREFIX=$1
MODE=$2
REGION="ap-southeast-1"
TMP_DIR=$(mktemp -d)
ALL_INSTANCE_IDS=""

SERVICES=("synapse" "sygnal" "coturn-tcp" "coturn-udp" "element" "certbot")

if [ -z "$PREFIX" ] || [[ "$MODE" != "hibernate" && "$MODE" != "resume" ]]; then
  echo "Usage: $0 <prefix> <hibernate|resume>"
  exit 1
fi

hibernate_instances() {
  local SERVICE=$1
  local TMP_FILE=$2

  INSTANCE_IDS=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-${SERVICE}*" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

  [ -z "$INSTANCE_IDS" ] && return

  ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS \
    --query "AutoScalingInstances[].AutoScalingGroupName" \
    --output text)

  aws autoscaling enter-standby \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS \
    --auto-scaling-group-name "$ASG_NAME" \
    --should-decrement-desired-capacity

  echo "$INSTANCE_IDS" >> "$TMP_FILE"
}

resume_instances() {
  local SERVICE=$1

  INSTANCE_IDS=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-${SERVICE}*" "Name=instance-state-name,Values=stopped" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

  [ -z "$INSTANCE_IDS" ] && return

  aws ec2 start-instances \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS

  aws ec2 wait instance-running \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS

  ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS \
    --query "AutoScalingInstances[].AutoScalingGroupName" \
    --output text)

  if [ -n "$ASG_NAME" ]; then
    aws autoscaling exit-standby \
      --region "$REGION" \
      --instance-ids $INSTANCE_IDS \
      --auto-scaling-group-name "$ASG_NAME"
  fi

  ALL_INSTANCE_IDS="$ALL_INSTANCE_IDS $INSTANCE_IDS"
}

if [ "$MODE" == "hibernate" ]; then
  echo "🔒 Hibernating all running instances..."
  for SERVICE in "${SERVICES[@]}"; do
    TMP_FILE="${TMP_DIR}/${SERVICE}.txt"
    hibernate_instances "$SERVICE" "$TMP_FILE" &
  done
  wait

  for FILE in "$TMP_DIR"/*.txt; do
    IDS=$(cat "$FILE")
    ALL_INSTANCE_IDS="$ALL_INSTANCE_IDS $IDS"
  done
  rm -rf "$TMP_DIR"

  if [ -n "$ALL_INSTANCE_IDS" ]; then
    aws ec2 stop-instances \
      --region "$REGION" \
      --instance-ids $ALL_INSTANCE_IDS \
      --hibernate
    aws ec2 wait instance-stopped \
      --region "$REGION" \
      --instance-ids $ALL_INSTANCE_IDS
    echo "✅ All instances hibernated."
  else
    echo "⚠️ No instances found to hibernate."
  fi

elif [ "$MODE" == "resume" ]; then
  echo "🔓 Resuming all stopped instances..."
  for SERVICE in "${SERVICES[@]}"; do
    resume_instances "$SERVICE"
  done

  if [ -n "$ALL_INSTANCE_IDS" ]; then
    echo "✅ All instances resumed: $ALL_INSTANCE_IDS"
  else
    echo "⚠️ No instances were resumed."
  fi
fi
