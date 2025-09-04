#!/bin/zsh
# terraform-deploy.sh
# Equivalent to terraform-deploy.ps1 for MacOS/Linux

set -e

action=""
auto_approve=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -Action)
      action="$2"
      shift 2
      ;;
    -AutoApprove)
      auto_approve="-auto-approve"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$action" ]]; then
  echo "No action specified. Use -Action <init|plan|apply|destroy>" >&2
  exit 1
fi

base_domain="tapofthink.com"
declare -A workspace_domains
workspace_domains=(
  [dev]="dev.$base_domain"
  [staging]="staging.$base_domain"
  [prod]="chat.$base_domain"
)

echo "Running Terraform '$action'"

get_workspace_and_set_env() {
  workspace=$(terraform workspace show | tr -d '\r')
  export TF_VAR_workspace="$workspace"
  root_domain="${workspace_domains[$workspace]}"
  if [[ -z "$root_domain" ]]; then
    echo "Unknown workspace: $workspace" >&2
    exit 1
  fi
  export TF_VAR_root_domain="$root_domain"
}

case "$action" in
  init)
    terraform init \
      -backend=true \
      -input=false \
      -reconfigure
    ;;
  plan)
    get_workspace_and_set_env
    terraform plan
    ;;
  apply)
    get_workspace_and_set_env
    terraform apply $auto_approve
    ;;
  destroy)
    get_workspace_and_set_env
    terraform destroy $auto_approve
    ;;
  *)
    echo "Unknown action: $action" >&2
    exit 1
    ;;
esac

echo "Terraform '$action' completed"
