# Retrieve AWS Account ID
data "aws_caller_identity" "current" {}

# Retrieve AWS Region
data "aws_region" "current" {}

data "aws_acm_certificate" "default" {
  domain   = "*.${var.root_domain}"
  statuses = ["ISSUED"]
}

data "aws_route53_zone" "main" {
  name         = "${var.root_domain}"
  private_zone = false
}

# Ubuntu 24.04LTS AMI for the ap-southeast-1 region
data "aws_ami" "ubuntu_2404" {
  most_recent = true
  owners = ["099720109477"] # Canonical

  filter {
    name   = "image-id"
    values = ["ami-02c7683e4ca3ebf58"]
  }
}
