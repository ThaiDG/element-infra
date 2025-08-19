# Create 3 private subnets across AZs
module "private_subnet_1" {
  source            = "./modules/Subnet"
  vpc_id            = aws_vpc.main.id
  subnet_cidr       = "10.0.10.0/24"
  public_subnet     = false
  availability_zone = data.aws_availability_zones.available.names[0]
  subnet_name       = "${var.workspace}-element-private-subnet-${data.aws_availability_zones.available.names[0]}"
}

module "private_subnet_2" {
  source            = "./modules/Subnet"
  vpc_id            = aws_vpc.main.id
  subnet_cidr       = "10.0.20.0/24"
  public_subnet     = false
  availability_zone = data.aws_availability_zones.available.names[1]
  subnet_name       = "${var.workspace}-element-private-subnet-${data.aws_availability_zones.available.names[1]}"
}

module "private_subnet_3" {
  source            = "./modules/Subnet"
  vpc_id            = aws_vpc.main.id
  subnet_cidr       = "10.0.30.0/24"
  public_subnet     = false
  availability_zone = data.aws_availability_zones.available.names[2]
  subnet_name       = "${var.workspace}-element-private-subnet-${data.aws_availability_zones.available.names[2]}"
}

# Private route tables
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.workspace}-element-private-route-table"
  }
}

# Associate private subnets with the private route table
resource "aws_route_table_association" "private_subnets_association" {
  for_each = {
    "subnet-1" = "${module.private_subnet_1.subnet_id}",
    "subnet-2" = "${module.private_subnet_2.subnet_id}",
    "subnet-3" = "${module.private_subnet_3.subnet_id}"
  }
  subnet_id      = each.value
  route_table_id = aws_route_table.private.id
}
