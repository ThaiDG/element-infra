#!/bin/bash


# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
ASG_PREFIX=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -AsgPrefix|--asg-prefix)
      ASG_PREFIX="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters

if [ -z "$ASG_PREFIX" ]; then
  echo -e "${RED}Error: ASG prefix is required. Usage: $0 -AsgPrefix <prefix>${NC}"
  exit 1
fi

# Read workspace from file or environment
WORKSPACE=""
if [ -f .terraform/environment ]; then
  WORKSPACE=$(cat .terraform/environment)
fi


if [ -z "$WORKSPACE" ]; then
  echo -e "${RED}Error: Could not determine workspace${NC}"
  exit 1
fi


echo -e "${GREEN}Using workspace: $WORKSPACE${NC}"
echo -e "${YELLOW}Finding Auto Scaling Groups with prefix: $ASG_PREFIX${NC}"

# Find ASGs with the specified prefix
ASG_NAMES=$(aws autoscaling describe-auto-scaling-groups --no-cli-pager --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, '${WORKSPACE}-${ASG_PREFIX}')].AutoScalingGroupName" --output text)


if [ -z "$ASG_NAMES" ]; then
  echo -e "${RED}No Auto Scaling Groups found with prefix: ${WORKSPACE}-${ASG_PREFIX}${NC}"
  exit 1
fi

# Start instance refresh for each ASG
echo "Instance refresh initiated for all matching Auto Scaling Groups"

for ASG_NAME in $ASG_NAMES; do
  echo -e "${YELLOW}Starting instance refresh for ASG: $ASG_NAME${NC}"
  aws autoscaling start-instance-refresh --no-cli-pager --auto-scaling-group-name "$ASG_NAME"
done

echo -e "${GREEN}Instance refresh initiated for all matching Auto Scaling Groups${NC}"
