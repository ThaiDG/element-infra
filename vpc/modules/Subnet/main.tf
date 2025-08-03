resource "aws_subnet" "public" {
  vpc_id                              = var.vpc_id
  cidr_block                          = var.subnet_cidr
  map_public_ip_on_launch             = var.public_subnet # Set to true for public subnets
  availability_zone                   = var.availability_zone
  private_dns_hostname_type_on_launch = "resource-name"

  tags = {
    Name = "${var.subnet_name}"
  }
}
