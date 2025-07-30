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

variable "root_domain" {
  description = "Root domain for the application"
  type        = string
}

variable "workspace" {
  description = "The current Terraform workspace"
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^(demo|dev|staging|prod)$", var.workspace))
    error_message = "Workspace must be one of: demo, dev, staging, prod."
  }
}
