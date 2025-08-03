# Retrieve AWS Account ID
data "aws_caller_identity" "current" {}

# Retrieve AWS Region
data "aws_region" "current" {}

# Retrieve all availability zones in the current region
data "aws_availability_zones" "available" {
  state = "available"
}
