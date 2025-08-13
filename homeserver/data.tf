# Retrieve AWS Account ID
data "aws_caller_identity" "current" {}

# Retrieve AWS Region
data "aws_region" "current" {}

data "terraform_remote_state" "vpc" {
  backend   = "s3"
  workspace = var.workspace
  config = {
    bucket               = "767828741221-terraform-state-ap-southeast-1"
    key                  = "terraform.tfstate"
    workspace_key_prefix = "vpc"
    region               = "ap-southeast-1"
    dynamodb_table       = "terraform-lock-table"
    encrypt              = true
  }
}

data "terraform_remote_state" "database" {
  backend   = "s3"
  workspace = var.workspace
  config = {
    bucket               = "767828741221-terraform-state-ap-southeast-1"
    key                  = "terraform.tfstate"
    workspace_key_prefix = "database"
    region               = "ap-southeast-1"
    dynamodb_table       = "terraform-lock-table"
    encrypt              = true
  }
}

data "aws_acm_certificate" "default" {
  domain   = "*.${var.root_domain}"
  statuses = ["ISSUED"]
}

data "aws_acm_certificate" "web_cert_tapyoush" {
  domain   = "*.tapyoush.com"
  statuses = ["ISSUED"]
}

data "aws_route53_zone" "tapyoush" {
  name         = "tapyoush.com"
  private_zone = false
}

data "aws_acm_certificate" "web_cert_youshtap" {
  domain   = "*.youshtap.com"
  statuses = ["ISSUED"]
}

data "aws_route53_zone" "youshtap" {
  name         = "youshtap.com"
  private_zone = false
}

data "aws_route53_zone" "main" {
  name         = var.root_domain
  private_zone = false
}

# Ubuntu 24.04LTS AMI for the ap-southeast-1 region
data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "image-id"
    values = ["ami-02c7683e4ca3ebf58"]
  }
}
