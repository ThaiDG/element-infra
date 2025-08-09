# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    "Name" = "${var.workspace}-element-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.workspace}-element-igw"
  }
}

# VPC Interface Endpoints
# This will allow SSM connecting to the EC2 instance in private subnet

# Security group that allow HTTPS outbound
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "${var.workspace}-vpc-endpoint-sg"
  description = "Allow HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids = [
    module.private_subnet_1.subnet_id,
    module.private_subnet_2.subnet_id,
    module.private_subnet_3.subnet_id
  ]
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]

  tags = {
    Name = "${var.workspace}-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids = [
    module.private_subnet_1.subnet_id,
    module.private_subnet_2.subnet_id,
    module.private_subnet_3.subnet_id
  ]
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]

  tags = {
    Name = "${var.workspace}-ec2messages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids = [
    module.private_subnet_1.subnet_id,
    module.private_subnet_2.subnet_id,
    module.private_subnet_3.subnet_id
  ]
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]

  tags = {
    Name = "${var.workspace}-ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ec2"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids = [
    module.private_subnet_1.subnet_id,
    module.private_subnet_2.subnet_id,
    module.private_subnet_3.subnet_id
  ]
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]

  tags = {
    Name = "${var.workspace}-ec2-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.workspace}-s3-endpoint"
  }
}
