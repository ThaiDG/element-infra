variable "workspace" {
  description = "The Terraform workspace to use for the deployment"
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.workspace))
    error_message = "Workspace must be one of: dev, staging, prod."
  }
}

variable "root_domain" {
  description = "The root domain for the infrastructure"
  type        = string
}
