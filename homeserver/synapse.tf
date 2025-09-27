
locals {
  synapse_init = base64gzip(templatefile("${path.module}/scripts/synapse_server_setup.tpl.sh", {
    environment      = "${var.workspace}"
    synapse_dns      = "${module.synapse_route53_record.record_dns_name}"
    coturn_tcp_dns   = "${module.coturn_tcp_route53_record.record_dns_name}"
    coturn_udp_dns   = "${module.coturn_udp_route53_record.record_dns_name}"
    tapyoush_dns     = "${module.web_tapyoush_route53_record.record_dns_name}"
    sygnal_dns       = "${module.sygnal_route53_record.record_dns_name}"
    aws_account_id   = "${data.aws_caller_identity.current.account_id}"
    aws_region       = "${data.aws_region.current.region}"
    postgres_dns     = "${data.terraform_remote_state.database.outputs.database_dns}"
    synapse_version  = var.workspace == "prod" ? "${var.synapse_release_version}" : "latest"
    s3_bucket_name   = "${aws_s3_bucket.synapse_storage.id}"
    livekit_dns      = "${module.livekit_route53_record.record_dns_name}"
    livekit_turn_dns = "${module.livekit_turn_route53_record.record_dns_name}"
    sydent_dns       = "${module.sydent_route53_record.record_dns_name}"
    mas_dns          = "mas.dev.tapofthink.com"
    # mas_dns         = module.mas_route53_record.record_dns_name
  }))
}

module "synapse_lt" {
  source        = "./modules/EC2/LaunchTemplate"
  name_prefix   = "${var.workspace}-synapse-web-lt"
  image_id      = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.medium"
  user_data     = local.synapse_init
  instance_name = "${var.workspace}-synapse-web"
  volume_size   = 30
  security_group_ids = [
    module.synapse_sg.security_group_id,
    data.terraform_remote_state.database.outputs.database_sg_id,
    module.ssh_sg.security_group_id,
  ]

  tags = {
    UserDataHash = md5(local.synapse_init)
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

# Main port for nginx reverse proxy
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
  workspace             = var.workspace
  asg_health_check_type = "ELB"
  asg_target_group_arns = [
    module.main_target.target_group_arn,
    module.synapse_prometheus_target.target_group_arn
  ]
}
