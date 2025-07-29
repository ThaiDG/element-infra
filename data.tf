# Retrieve AWS Account ID
data "aws_caller_identity" "current" {}

# Retrieve AWS Region
data "aws_region" "current" {}

data "aws_acm_certificate" "default" {
  domain   = "*.demo.tapofthink.com"
  statuses = ["ISSUED"]
}

data "aws_route53_zone" "main" {
  name         = "demo.tapofthink.com"
  private_zone = false
}

data "aws_launch_template" "default" {
  id = "lt-08edb0a634b69facc"
}
