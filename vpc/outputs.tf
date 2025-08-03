output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value = [
    module.public_subnet_1.subnet_id,
    module.public_subnet_2.subnet_id,
    module.public_subnet_3.subnet_id
  ]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value = [
    module.private_subnet_1.subnet_id,
    module.private_subnet_2.subnet_id,
    module.private_subnet_3.subnet_id
  ]
}
