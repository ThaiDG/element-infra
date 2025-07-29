module "efs" {
  source                      = "./modules/EFS"
  efs_creation_token          = "${data.aws_caller_identity.current.account_id}-certifications-token-${data.aws_region.current.name}"
  efs_name                    = "demo-efs"
  efs_mount_target_subnet_ids = [var.pub1, var.pub2]  # Ensure this matches the certbot manager subnet and coturn subnets
  efs_security_group_ids      = [module.efs_sg.security_group_id]
}
