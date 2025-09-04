#!/bin/zsh
# select-workspace.sh
# Equivalent to select-workspace.ps1 for MacOS/Linux

set -e

# Check if ENV is set
if [[ -z "$ENV" ]]; then
  echo "ENV is not set. Using default workspace: dev."
  read "reply?Would you like to continue? [Y/n]: "
  if [[ -z "$reply" || "$reply" == "Y" || "$reply" == "y" ]]; then
    export ENV="dev"
    echo "Proceeding with workspace: $ENV"
    # Select the workspace
    if ! terraform workspace select "$ENV"; then
      echo "Workspace '$ENV' does not exist."
      read "reply?Would you like to create a new one? [Y/n]: "
      if [[ -z "$reply" || "$reply" == "Y" || "$reply" == "y" ]]; then
        echo "Creating new workspace: $ENV"
        if ! terraform workspace new "$ENV"; then
          echo "Failed to create workspace '$ENV'. Exiting."
          exit 1
        fi
      else
        echo "Aborting workspace creation."
        exit 1
      fi
    fi
    echo "Workspace '$(terraform workspace show)' is now selected."
  else
    echo "Aborting initialization."
    exit 1
  fi
else
  echo "ENV is set to: $ENV"
  echo "Proceeding with workspace: $ENV"
  # Select the workspace
  if ! terraform workspace select "$ENV"; then
    echo "Workspace '$ENV' does not exist."
    read "reply?Would you like to create a new one? [Y/n]: "
    if [[ -z "$reply" || "$reply" == "Y" || "$reply" == "y" ]]; then
      echo "Creating new workspace: $ENV"
      if ! terraform workspace new "$ENV"; then
        echo "Failed to create workspace '$ENV'. Exiting."
        exit 1
      fi
    else
      echo "Aborting workspace creation."
      exit 1
    fi
  fi
  echo "Workspace '$(terraform workspace show)' is now selected."
fi
