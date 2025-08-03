output "subnet_id" {
  description = "The ID of the subnet created"
  value       = aws_subnet.public.id
}
