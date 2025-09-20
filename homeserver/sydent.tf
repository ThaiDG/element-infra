locals {
  sydent_init = base64gzip(templatefile("${path.module}/scripts/sydent_server_setup.tpl.sh", {
    aws_region     = "${data.aws_region.current.region}"
    aws_account_id = "${data.aws_caller_identity.current.account_id}"
    s3_bucket_name = "${module.sydent_storage.bucket_name}"
    tapyoush_dns   = "${module.web_tapyoush_route53_record.record_dns_name}"
    sydent_dns     = "${module.sydent_route53_record.record_dns_name}"
    synapse_dns    = "${module.synapse_route53_record.record_dns_name}"
  }))
}

module "sydent_lt" {
  source        = "./modules/EC2/LaunchTemplate"
  name_prefix   = "${var.workspace}-sydent-web-lt"
  image_id      = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.micro"
  user_data     = local.sydent_init
  instance_name = "${var.workspace}-sydent-web"
  volume_size   = 20
  security_group_ids = [
    module.sydent_sg.security_group_id,
    module.ssh_sg.security_group_id
  ]

  tags = {
    UserDataHash = md5(local.sydent_init)
  }
}

resource "aws_lb" "sydent_alb" {
  name_prefix                = "sydent"
  load_balancer_type         = "application"
  preserve_host_header       = true
  enable_xff_client_port     = true
  xff_header_processing_mode = "preserve"
  subnets                    = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  security_groups = [
    module.sydent_alb_sg.security_group_id
  ]
}

# Main port for nginx reverse proxy
module "sydent_main_target" {
  source                            = "./modules/EC2/LoadBalancing"
  load_balancer_arn                 = aws_lb.sydent_alb.arn
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
module "sydent_prometheus_target" {
  source                            = "./modules/EC2/LoadBalancing"
  load_balancer_arn                 = aws_lb.sydent_alb.arn
  target_group_port                 = 9090
  target_group_protocol             = "HTTP"
  target_group_vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
  target_group_health_check_enabled = true
  target_group_health_check_path    = "/metrics"
  target_group_health_check_port    = "9090"
  listener_port                     = 9090
  listener_protocol                 = "HTTPS"
  certificate_arn                   = data.aws_acm_certificate.default.arn
}

module "sydent_asg" {
  source                = "./modules/EC2/AutoScalingGroup"
  asg_name              = "${var.workspace}-sydent-server-asg"
  asg_desired_capacity  = 1
  asg_min_size          = var.workspace == "dev" ? 0 : 1 # Set to 0 for dev workspace
  asg_max_size          = 2
  asg_subnet_ids        = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  launch_template_id    = module.sydent_lt.launch_template_id
  instance_name         = "${var.workspace}-sydent-server"
  workspace             = var.workspace
  asg_health_check_type = "ELB"
  asg_target_group_arns = [
    module.sydent_main_target.target_group_arn,
    module.sydent_prometheus_target.target_group_arn
  ]
}

module "sydent_storage" {
  source        = "./modules/S3"
  bucket_prefix = "${var.workspace}-sydent-storage-"
}
