variable "target_group_port" {
  description = "Port for the target group"
  type        = number
}

variable "target_group_protocol" {
  description = "Protocol for the target group"
  type        = string
  default     = "HTTP"
}

variable "target_group_vpc_id" {
  description = "VPC ID for the target group"
  type        = string
}

variable "load_balancer_arn" {
  description = "ARN of the load balancer"
  type        = string
}

variable "listener_port" {
  description = "Port for the listener"
  type        = number
}

variable "listener_protocol" {
  description = "Protocol for the listener"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listener"
  type        = string
  default     = ""
}

variable "target_group_health_check_enabled" {
  description = "Enable health check for the target group"
  type        = bool
  default     = true
}

variable "target_group_health_check_path" {
  description = "Path for the health check"
  type        = string
  default     = "/"
}

variable "target_group_health_check_port" {
  description = "Port for the health check"
  type        = string
  default     = "80"
}

variable "target_group_health_check_protocol" {
  description = "Protocol for the health check"
  type        = string
  default     = "HTTP"
}

# variable "target_instance_id" {
#   description = "ID of the target instance"
#   type        = string
# }
