data "template_file" "synapse_init" {
  template = file("${path.module}/scripts/synapse_server_setup.tpl.sh")

  vars = {
    synapse_dns     = "${module.synapse_route53_record.record_dns_name}"
    coturn_tcp_dns  = "${module.coturn_tcp_route53_record.record_dns_name}"
    coturn_udp_dns  = "${module.coturn_udp_route53_record.record_dns_name}"
    tapyoush_dns    = "${module.web_tapyoush_route53_record.record_dns_name}"
    sygnal_dns      = "${module.sygnal_route53_record.record_dns_name}"
    aws_account_id  = "${data.aws_caller_identity.current.account_id}"
    aws_region      = "${data.aws_region.current.region}"
    postgres_dns    = "${data.terraform_remote_state.database.outputs.database_dns}"
    synapse_version = "${var.synapse_release_version}"
    s3_bucket_name  = "${aws_s3_bucket.synapse_storage.id}"
  }
}

module "synapse_lt" {
  source        = "./modules/EC2/LaunchTemplate"
  name_prefix   = "${var.workspace}-synapse-web-lt"
  image_id      = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.medium"
  user_data     = data.template_file.synapse_init.rendered
  instance_name = "${var.workspace}-synapse-web"
  volume_size   = 30
  security_group_ids = [
    module.synapse_sg.security_group_id,
    data.terraform_remote_state.database.outputs.database_sg_id,
    module.ssh_sg.security_group_id,
    data.terraform_remote_state.vpc.outputs.client_vpn_sg_id,
  ]

  tags = {
    UserDataHash = md5(data.template_file.synapse_init.rendered)
  }
}

resource "aws_lb" "synapse_alb" {
  name_prefix                = "synaps"
  load_balancer_type         = "application"
  preserve_host_header       = true
  enable_xff_client_port     = true
  xff_header_processing_mode = "preserve"
  subnets                    = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  security_groups = [
    module.synapse_alb_sg.security_group_id
  ]
}

# Main port for Synapse is 8008
module "main_target" {
  source                            = "./modules/EC2/LoadBalancing"
  load_balancer_arn                 = aws_lb.synapse_alb.arn
  target_group_port                 = 80
  target_group_protocol             = "HTTP"
  target_group_vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
  target_group_health_check_enabled = true
  target_group_health_check_path    = "/health"
  target_group_health_check_port    = "80"
  listener_port                     = 443
  listener_protocol                 = "HTTPS"
  certificate_arn                   = data.aws_acm_certificate.default.arn
}

# Support port 8448 for federation
module "federation_target" {
  source                            = "./modules/EC2/LoadBalancing"
  load_balancer_arn                 = aws_lb.synapse_alb.arn
  target_group_port                 = 8448
  target_group_protocol             = "HTTP"
  target_group_vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
  target_group_health_check_enabled = true
  target_group_health_check_path    = "/health"
  target_group_health_check_port    = "80"
  listener_port                     = 8448
  listener_protocol                 = "HTTPS"
  certificate_arn                   = data.aws_acm_certificate.default.arn
}

# Routing the Prometheus port
module "synapse_prometheus_target" {
  source                            = "./modules/EC2/LoadBalancing"
  load_balancer_arn                 = aws_lb.synapse_alb.arn
  target_group_port                 = 9090
  target_group_protocol             = "HTTP"
  target_group_vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
  target_group_health_check_enabled = true
  target_group_health_check_path    = "/-/healthy"
  target_group_health_check_port    = "9090"
  listener_port                     = 9090
  listener_protocol                 = "HTTPS"
  certificate_arn                   = data.aws_acm_certificate.default.arn
}

module "synapse_asg" {
  source                = "./modules/EC2/AutoScalingGroup"
  asg_name              = "${var.workspace}-synapse-server-asg"
  asg_desired_capacity  = 1
  asg_min_size          = var.workspace == "dev" ? 0 : 1 # Set to 0 for dev workspace
  asg_max_size          = 3
  asg_subnet_ids        = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  launch_template_id    = module.synapse_lt.launch_template_id
  instance_name         = "${var.workspace}-synapse-server"
  asg_health_check_type = "ELB"
  asg_target_group_arns = [
    module.main_target.target_group_arn,
    module.federation_target.target_group_arn,
    module.synapse_prometheus_target.target_group_arn
  ]
}
