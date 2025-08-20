variable "asg_name" {
  description = "Name of the Auto Scaling Group"
  type        = string
}

variable "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_subnet_ids" {
  description = "Subnets for the Auto Scaling Group"
  type        = list(string)
}

variable "asg_target_group_arns" {
  description = "ARNs of the target groups for the Auto Scaling Group"
  type        = list(string)
  default     = []
}

variable "asg_health_check_type" {
  description = "Health check type for the Auto Scaling Group"
  type        = string
  default     = "EC2"
}

variable "launch_template_id" {
  description = "Launch template ID for the Auto Scaling Group"
  type        = string
}

variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
}

variable "workspace" {
  description = "Workspace environment (e.g., prod, dev)"
  type        = string
}
