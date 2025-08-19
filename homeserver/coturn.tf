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

data "template_file" "coturn_init" {
  template = file("${path.module}/scripts/coturn_server_setup.tpl.sh")

  vars = {
    tcp_nlb_dns = aws_lb.coturn_nlb_tcp.dns_name
    udp_nlb_dns = aws_lb.coturn_nlb_udp.dns_name
    region      = data.aws_region.current.region
    root_domain = var.root_domain
  }
}

module "coturn_lt" {
  source        = "./modules/EC2/LaunchTemplate"
  name_prefix   = "${var.workspace}-coturn-lt"
  image_id      = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.medium"
  user_data     = data.template_file.coturn_init.rendered
  instance_name = "${var.workspace}-coturn"
  volume_size   = 16
  security_group_ids = [
    module.coturn_sg.security_group_id,
    module.ssh_sg.security_group_id,
  ]

  tags = {
    UserDataHash = md5(data.template_file.coturn_init.rendered)
  }
}

# Target group for coTURN TCP non-TLS
module "tcp_3478_target" {
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
module "tcp_5349_targer" {
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
module "udp_3478_target" {
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

# Routing to Prometheus port coTURN TCP NLB
module "coturn_tcp_prometheus_target" {
  source                             = "./modules/EC2/LoadBalancing"
  load_balancer_arn                  = aws_lb.coturn_nlb_tcp.arn
  target_group_port                  = 9090
  target_group_protocol              = "TCP"
  target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  target_group_health_check_enabled  = true
  target_group_health_check_port     = "9090"
  target_group_health_check_protocol = "TCP"
  listener_port                      = 9090
  listener_protocol                  = "TLS"
  certificate_arn                    = data.aws_acm_certificate.default.arn
}

# Routing to Prometheus port coTURN UDP NLB
module "coturn_udp_prometheus_target" {
  source                             = "./modules/EC2/LoadBalancing"
  load_balancer_arn                  = aws_lb.coturn_nlb_udp.arn
  target_group_port                  = 9090
  target_group_protocol              = "TCP"
  target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  target_group_health_check_enabled  = true
  target_group_health_check_port     = "9090"
  target_group_health_check_protocol = "TCP"
  listener_port                      = 9090
  listener_protocol                  = "TLS"
  certificate_arn                    = data.aws_acm_certificate.default.arn
}

# Auto Scaling Group for coTURN TCP instances
module "coturn_asg" {
  source                = "./modules/EC2/AutoScalingGroup"
  asg_name              = "${var.workspace}-coturn-asg"
  asg_desired_capacity  = 1
  asg_min_size          = var.workspace == "dev" ? 0 : 1 # Set to 0 for dev workspace
  asg_max_size          = 3
  asg_subnet_ids        = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  launch_template_id    = module.coturn_lt.launch_template_id
  instance_name         = "${var.workspace}-coturn"
  asg_health_check_type = "ELB"
  asg_target_group_arns = [
    module.tcp_3478_target.target_group_arn,
    module.tcp_5349_targer.target_group_arn,
    module.udp_3478_target.target_group_arn,
    module.coturn_tcp_prometheus_target.target_group_arn,
    module.coturn_udp_prometheus_target.target_group_arn,
  ]
}
