variable "subnet_id" {
  description = "The ID of the subnet where the EC2 instance will be launched"
  type        = string
  default     = ""
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with the EC2 instance"
  type        = list(string)
  default     = []
}

variable "launch_template_id" {
  description = "The ID of the launch template to use for the EC2 instance"
  type        = string
  default     = ""
}

variable "ec2_name" {
  description = "The name tag for the EC2 instance"
  type        = string
  default     = "dev-ec2"
}
