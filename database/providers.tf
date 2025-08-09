terraform {
  backend "s3" {
    bucket               = "767828741221-terraform-state-ap-southeast-1"
    key                  = "terraform.tfstate"
    workspace_key_prefix = "database"
    region               = "ap-southeast-1"
    dynamodb_table       = "terraform-lock-table"
    encrypt              = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.0.0"
}

provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Project = "element"
      Owner   = "ThaiDG"
      Env     = "${var.workspace}"
    }
  }
}
