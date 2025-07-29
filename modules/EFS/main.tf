resource "aws_efs_file_system" "efs" {
  creation_token         = var.efs_creation_token
  performance_mode       = "generalPurpose"
  encrypted              = true

  tags = {
    Name = var.efs_name
  }
}

resource "aws_efs_mount_target" "alpha" {
  for_each        = var.efs_mount_target_subnet_ids
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = each.value
  security_groups = var.efs_security_group_ids
}
