variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "pub1" {
  description = "Public Subnet 1 ID"
  type        = string
}

variable "pub2" {
  description = "Public Subnet 2 ID"
  type        = string
}

variable "allow_all_sg_id" {
  description = "Security Group ID that allows all access"
  type        = string
}

variable "root_domain" {
  description = "Root domain for the application"
  type        = string
  default     = "demo.tapofthink.com"
}
