variable "efs_creation_token" {
  description = "Creation token for the EFS file system. Must be unique within the AWS account and region."
  type        = string
}

variable "efs_name" {
  description = "Name of the EFS file system"
  type        = string
}

variable "efs_mount_target_subnet_ids" {
  description = "Subnet IDs for the EFS mount targets"
  type        = set(string)
}

variable "efs_security_group_ids" {
  description = "List of security group IDs to associate with the EFS mount target"
  type        = list(string)
}
