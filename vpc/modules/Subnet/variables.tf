variable "vpc_id" {
  description = "The ID of the VPC where the subnets will be created"
  type        = string
}

variable "subnet_cidr" {
  description = "The CIDR block for the subnet"
  type        = string
}

variable "public_subnet" {
  description = "Set to true for public subnets, false for private subnets"
  type        = bool
  default     = true
}

variable "availability_zone" {
  description = "The availability zone for the subnet"
  type        = string
}

variable "subnet_name" {
  description = "The name to assign to the subnet"
  type        = string
}
