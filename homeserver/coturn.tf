resource "aws_lb" "coturn_nlb_tcp" {
  name_prefix        = "co-tcp"
  load_balancer_type = "network"
  subnets            = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  security_groups = [
    module.coturn_nlb_sg.security_group_id,
    module.synapse_sg.security_group_id, # Allow traffic from Synapse security group
  ]
}

resource "aws_lb" "coturn_nlb_udp" {
  name_prefix        = "co-udp"
  load_balancer_type = "network"
  subnets            = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  security_groups = [
    module.coturn_nlb_sg.security_group_id,
    module.synapse_sg.security_group_id, # Allow traffic from Synapse security group
  ]
}

data "template_file" "coturn_tcp_init" {
  template = file("${path.module}/scripts/coturn_server_setup.tpl.sh")

  vars = {
    nlb_dns     = aws_lb.coturn_nlb_tcp.dns_name
    efs_id      = module.efs.efs_id
    nfs_version = "4.1" # Default NFS version
    region      = data.aws_region.current.region
    root_domain = var.root_domain
  }
}

data "template_file" "coturn_udp_init" {
  template = file("${path.module}/scripts/coturn_server_setup.tpl.sh")

  vars = {
    nlb_dns     = aws_lb.coturn_nlb_udp.dns_name
    efs_id      = module.efs.efs_id
    nfs_version = "4.1" # Default NFS version
    region      = data.aws_region.current.region
    root_domain = var.root_domain
  }
}

module "coturn_tcp_lt" {
  source        = "./modules/EC2/LaunchTemplate"
  name_prefix   = "${var.workspace}-coturn-tcp-lt"
  image_id      = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.medium"
  user_data     = data.template_file.coturn_tcp_init.rendered
  instance_name = "${var.workspace}-coturn-tcp"
  volume_size   = 8
  security_group_ids = [
    module.coturn_sg.security_group_id,
    module.ssh_sg.security_group_id
  ]

  tags = {
    UserDataHash = md5(data.template_file.coturn_tcp_init.rendered)
  }
}

module "coturn_udp_lt" {
  source        = "./modules/EC2/LaunchTemplate"
  name_prefix   = "${var.workspace}-coturn-udp-lt"
  image_id      = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.medium"
  user_data     = data.template_file.coturn_udp_init.rendered
  instance_name = "${var.workspace}-coturn-udp"
  volume_size   = 8
  security_group_ids = [
    module.coturn_sg.security_group_id,
    module.ssh_sg.security_group_id
  ]

  tags = {
    UserDataHash = md5(data.template_file.coturn_udp_init.rendered)
  }
}

# Target group for coTURN TCP non-TLS
module "coturn_nlb_3478_tcp" {
  source                             = "./modules/EC2/LoadBalancing"
  load_balancer_arn                  = aws_lb.coturn_nlb_tcp.arn
  target_group_port                  = 3478
  target_group_protocol              = "TCP"
  target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  target_group_health_check_enabled  = true
  target_group_health_check_port     = "3478"
  target_group_health_check_protocol = "TCP"
  listener_port                      = 3478
  listener_protocol                  = "TCP"
  certificate_arn                    = ""
}

# Target group for coTURN TCP TLS
module "coturn_nlb_5349_tcp" {
  source                             = "./modules/EC2/LoadBalancing"
  load_balancer_arn                  = aws_lb.coturn_nlb_tcp.arn
  target_group_port                  = 5349
  target_group_protocol              = "TCP"
  target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  target_group_health_check_enabled  = true
  target_group_health_check_port     = "3478"
  target_group_health_check_protocol = "TCP"
  listener_port                      = 5349
  listener_protocol                  = "TCP"
  certificate_arn                    = ""
}

# Target group for coTURN UDP non-TLS
module "coturn_nlb_3478_udp" {
  source                             = "./modules/EC2/LoadBalancing"
  load_balancer_arn                  = aws_lb.coturn_nlb_udp.arn
  target_group_port                  = 3478
  target_group_protocol              = "UDP"
  target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  target_group_health_check_enabled  = true
  target_group_health_check_port     = "3478"
  target_group_health_check_protocol = "TCP"
  listener_port                      = 3478
  listener_protocol                  = "UDP"
  certificate_arn                    = ""
}

# Routing to Prometheus port
module "sygnal_alb" {
  source                             = "./modules/EC2/LoadBalancing"
  load_balancer_arn                  = aws_lb.sygnal_alb.arn
  target_group_port                  = 9090
  target_group_protocol              = "HTTP"
  target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  target_group_health_check_enabled  = true
  target_group_health_check_path     = "/-/healthy"
  target_group_health_check_port     = "9090"
  target_group_health_check_protocol = "HTTP"
  listener_port                      = 9090
  listener_protocol                  = "HTTPS"
  certificate_arn                    = data.aws_acm_certificate.default.arn
}

# Auto Scaling Groups for coTURN TCP instances
module "coturn_tcp_asg" {
  source                = "./modules/EC2/AutoScalingGroup"
  asg_name              = "${var.workspace}-coturn-tcp-asg"
  asg_desired_capacity  = 1
  asg_min_size          = var.workspace == "dev" ? 0 : 1 # Set to 0 for dev workspace
  asg_max_size          = 2
  asg_subnet_ids        = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  launch_template_id    = module.coturn_tcp_lt.launch_template_id
  instance_name         = "${var.workspace}-coturn-tcp"
  asg_target_group_arns = [module.coturn_nlb_3478_tcp.target_group_arn, module.coturn_nlb_5349_tcp.target_group_arn]
  asg_health_check_type = "ELB"
}
# Auto Scaling Groups for coTURN UDP instances
module "coturn_udp_asg" {
  source                = "./modules/EC2/AutoScalingGroup"
  asg_name              = "${var.workspace}-coturn-udp-asg"
  asg_desired_capacity  = 1
  asg_min_size          = var.workspace == "dev" ? 0 : 1 # Set to 0 for dev workspace
  asg_max_size          = 2
  asg_subnet_ids        = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  launch_template_id    = module.coturn_udp_lt.launch_template_id
  instance_name         = "${var.workspace}-coturn-udp"
  asg_target_group_arns = [module.coturn_nlb_3478_udp.target_group_arn]
  asg_health_check_type = "ELB"
}
