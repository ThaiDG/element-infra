variable "root_domain" {
  description = "Root domain for the application"
  type        = string
}

variable "workspace" {
  description = "The current Terraform workspace"
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.workspace))
    error_message = "Workspace must be one of: dev, staging, prod."
  }
}

variable "web_release_version" {
  description = "Yoush Web release version - Production only - Must change before release"
  default     = "latest"
}

variable "synapse_release_version" {
  description = "Synapse release version - Production only - Must change before release"
  default     = "latest"
}
