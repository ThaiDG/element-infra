module "efs" {
  source                      = "./modules/EFS"
  efs_creation_token          = "${data.aws_caller_identity.current.account_id}-${var.workspace}-certifications-token-${data.aws_region.current.name}"
  efs_name                    = "${var.workspace}-efs"
  efs_mount_target_subnet_ids = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  efs_security_group_ids      = [module.efs_sg.security_group_id]
}
