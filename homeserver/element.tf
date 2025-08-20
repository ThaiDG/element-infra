data "template_file" "element_init" {
  template = file("${path.module}/scripts/element_web_setup.tpl.sh")

  vars = {
    synapse_dns    = "${module.synapse_route53_record.record_dns_name}"
    tapyoush_dns   = "${module.web_tapyoush_route53_record.record_dns_name}"
    youshtap_dns   = "${module.web_youshtap_route53_record.record_dns_name}"
    aws_account_id = "${data.aws_caller_identity.current.account_id}"
    aws_region     = "${data.aws_region.current.region}"
    web_version    = var.workspace == "prod" ? var.web_release_version : "latest"
  }
}

module "element_lt" {
  source        = "./modules/EC2/LaunchTemplate"
  name_prefix   = "${var.workspace}-element-web-lt"
  image_id      = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.medium"
  user_data     = data.template_file.element_init.rendered
  instance_name = "${var.workspace}-element-web"
  volume_size   = 16
  security_group_ids = [
    module.element_sg.security_group_id,
    module.ssh_sg.security_group_id,
  ]

  tags = {
    UserDataHash = md5(data.template_file.element_init.rendered)
  }
}

resource "aws_lb" "element_alb" {
  name_prefix                = "elemen"
  load_balancer_type         = "application"
  preserve_host_header       = true
  enable_xff_client_port     = true
  xff_header_processing_mode = "preserve"
  subnets                    = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  security_groups = [
    module.element_alb_sg.security_group_id,
  ]
}

# Routing to HTTPS for Element Web
module "web_target" {
  source                             = "./modules/EC2/LoadBalancing"
  load_balancer_arn                  = aws_lb.element_alb.arn
  target_group_port                  = 80
  target_group_protocol              = "HTTP"
  target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  target_group_health_check_enabled  = true
  target_group_health_check_path     = "/config.${module.web_tapyoush_route53_record.record_dns_name}.json"
  target_group_health_check_port     = "80"
  target_group_health_check_protocol = "HTTP"
  listener_port                      = 443
  listener_protocol                  = "HTTPS"
  certificate_arn                    = data.aws_acm_certificate.web_cert_tapyoush.arn
}

# Additional cert for youshtap.com
resource "aws_lb_listener_certificate" "web_additional_cert" {
  listener_arn    = module.web_target.listener_arn
  certificate_arn = data.aws_acm_certificate.web_cert_youshtap.arn
}

# Routing the Prometheus port
module "web_prometheus_target" {
  source                             = "./modules/EC2/LoadBalancing"
  load_balancer_arn                  = aws_lb.element_alb.arn
  target_group_port                  = 9090
  target_group_protocol              = "HTTP"
  target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  target_group_health_check_enabled  = true
  target_group_health_check_path     = "/-/healthy"
  target_group_health_check_port     = "9090"
  target_group_health_check_protocol = "HTTP"
  listener_port                      = 9090
  listener_protocol                  = "HTTPS"
  certificate_arn                    = data.aws_acm_certificate.web_cert_tapyoush.arn
}

# Additional cert for youshtap.com
resource "aws_lb_listener_certificate" "prometheus_additional_cert" {
  listener_arn    = module.web_prometheus_target.listener_arn
  certificate_arn = data.aws_acm_certificate.web_cert_youshtap.arn
}

module "element_asg" {
  source                = "./modules/EC2/AutoScalingGroup"
  asg_name              = "${var.workspace}-element-web-asg"
  asg_desired_capacity  = 1
  asg_min_size          = var.workspace == "dev" ? 0 : 1 # Set to 0 for dev workspace
  asg_max_size          = 2
  asg_subnet_ids        = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  launch_template_id    = module.element_lt.launch_template_id
  instance_name         = "${var.workspace}-element-web"
  workspace             = var.workspace
  asg_health_check_type = "ELB"
  asg_target_group_arns = [
    module.web_target.target_group_arn,
    module.web_prometheus_target.target_group_arn
  ]
}
