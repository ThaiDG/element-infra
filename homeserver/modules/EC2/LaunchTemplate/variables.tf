variable "name_prefix" {
  description = "Prefix for the launch template name"
  type        = string
}

variable "image_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
  default     = "donggiangthai1998"
}

variable "user_data" {
  description = "User data script for EC2 instance"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with the EC2 instance"
  type        = list(string)
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
  default     = "manual-deployment"
}

variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
}

variable "volume_size" {
  description = "Size of the EBS volume"
  type        = number
  default     = 8
}

variable "tags" {
  description = "Tags to apply to the Launch Template"
  type        = map(string)
  default     = {}
}
