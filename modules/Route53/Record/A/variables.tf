variable "zone_id" {
  description = "The Route 53 zone ID where the A record will be created"
  type        = string
}

variable "record_name" {
  description = "The DNS record name for the A record"
  type        = string
}

variable "aws_lb_dns_name" {
  description = "The DNS name of the AWS Load Balancer"
  type        = string
}

variable "aws_lb_zone_id" {
  description = "The zone ID of the AWS Load Balancer"
  type        = string
}
