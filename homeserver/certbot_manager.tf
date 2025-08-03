data "template_file" "certbot_init" {
  template = file("${path.module}/scripts/init-certbot.tpl.sh")

  vars = {
    efs_id      = module.efs.efs_id
    nfs_version = "4.1" # Default NFS version
    region      = data.aws_region.current.name
    domain      = "*.${var.root_domain}" # Wildcard domain for certbot
  }
}

module "certbot_manager_lt" {
  source        = "./modules/EC2/LaunchTemplate"
  name_prefix   = "${var.workspace}-certbot-manager-lt"
  image_id      = data.aws_ami.ubuntu_2404.id
  user_data     = data.template_file.certbot_init.rendered
  instance_name = "${var.workspace}-certbot-manager"
  volume_size   = 8
  security_group_ids = [
    module.efs_sg.security_group_id,
    module.ssh_sg.security_group_id
  ]

  tags = {
    UserDataHash = md5(data.template_file.certbot_init.rendered)
  }
}

module "certbot_asg" {
  source               = "./modules/EC2/AutoScalingGroup"
  asg_name             = "${var.workspace}-certbot-manager-asg"
  asg_desired_capacity = 1
  asg_min_size         = var.workspace == "dev" ? 0 : 1 # Set to 0 for dev workspace
  asg_max_size         = 1
  asg_subnet_ids       = [var.pub1] # Ensure this matches the EFS subnet
  launch_template_id   = module.certbot_manager_lt.launch_template_id
  instance_name        = "${var.workspace}-certbot-manager"

  depends_on = [
    module.coturn_tcp_route53_record,
    module.coturn_udp_route53_record
  ]
}
