variable "security_group_name_prefix" {
  description = "The name prefix of the security group"
  type        = string
}

variable "security_group_description" {
  description = "The description of the security group"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "ingress_rules" {
  description = "List of ingress rules for the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    security_groups = optional(list(string), [])
  }))
  default = []
}

# variable "ingress_description" {
#   description = "Description for the ingress rule"
#   type        = string
# }

# variable "ingress_from_port" {
#   description = "Starting port for the ingress rule"
#   type        = number
# }

# variable "ingress_to_port" {
#   description = "Ending port for the ingress rule"
#   type        = number
# }

# variable "ingress_protocol" {
#   description = "Protocol for the ingress rule"
#   type        = string
# }

# variable "ingress_cidr_blocks" {
#   description = "CIDR blocks for the ingress rule"
#   type        = list(string)
#   default     = ["10.0.0.0/16"]   # VPC CIDR block
# }
