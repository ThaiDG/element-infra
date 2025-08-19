# Create 3 public subnets across AZs
module "public_subnet_1" {
  source            = "./modules/Subnet"
  vpc_id            = aws_vpc.main.id
  subnet_cidr       = "10.0.0.0/24"
  public_subnet     = true
  availability_zone = data.aws_availability_zones.available.names[0]
  subnet_name       = "${var.workspace}-element-public-subnet-${data.aws_availability_zones.available.names[0]}"

  depends_on = [aws_internet_gateway.igw]
}

module "public_subnet_2" {
  source            = "./modules/Subnet"
  vpc_id            = aws_vpc.main.id
  subnet_cidr       = "10.0.1.0/24"
  public_subnet     = true
  availability_zone = data.aws_availability_zones.available.names[1]
  subnet_name       = "${var.workspace}-element-public-subnet-${data.aws_availability_zones.available.names[1]}"

  depends_on = [aws_internet_gateway.igw]
}

module "public_subnet_3" {
  source            = "./modules/Subnet"
  vpc_id            = aws_vpc.main.id
  subnet_cidr       = "10.0.2.0/24"
  public_subnet     = true
  availability_zone = data.aws_availability_zones.available.names[2]
  subnet_name       = "${var.workspace}-element-public-subnet-${data.aws_availability_zones.available.names[2]}"

  depends_on = [aws_internet_gateway.igw]
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.workspace}-element-public-route-table"
  }
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public_subnets_association" {
  for_each = {
    "subnet-1" = "${module.public_subnet_1.subnet_id}",
    "subnet-2" = "${module.public_subnet_2.subnet_id}",
    "subnet-3" = "${module.public_subnet_3.subnet_id}"
  }
  subnet_id      = each.value
  route_table_id = aws_route_table.public.id
}
