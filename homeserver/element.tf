data "template_file" "element_init" {
  template = file("${path.module}/scripts/element_web_setup.tpl.sh")

  vars = {
    synapse_dns    = "${module.synapse_route53_record.record_dns_name}"
    element_dns    = "${module.element_route53_record.record_dns_name}"
    aws_account_id = "${data.aws_caller_identity.current.account_id}"
    aws_region     = "${data.aws_region.current.name}"
  }
}

module "element_lt" {
  source = "./modules/EC2/LaunchTemplate"
  name_prefix   = "element-web-lt"
  image_id      = data.aws_launch_template.default.image_id
  instance_type = "t3.medium"
  user_data     = data.template_file.element_init.rendered
  instance_name = "element-web"
  volume_size   = 30
  security_group_ids = [
    module.element_sg.security_group_id,
    module.ssh_sg.security_group_id
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
  subnets = [
    var.pub1,
    var.pub2
  ]
  security_groups = [
    module.element_alb_sg.security_group_id,
  ]
}

module "element_alb" {
  source                             = "./modules/EC2/LoadBalancing"
  load_balancer_arn                  = aws_lb.element_alb.arn
  target_group_port                  = 80
  target_group_protocol              = "HTTP"
  target_group_vpc_id                = var.vpc_id
  target_group_health_check_enabled  = true
  target_group_health_check_path     = "/config.json"
  target_group_health_check_port     = "80"
  target_group_health_check_protocol = "HTTP"
  listener_port                      = 443
  listener_protocol                  = "HTTPS"
  certificate_arn                    = data.aws_acm_certificate.default.arn
}

module "element_asg" {
  source                = "./modules/EC2/AutoScalingGroup"
  asg_name              = "element-web-asg"
  asg_desired_capacity  = 1
  asg_min_size          = 1
  asg_max_size          = 2
  asg_subnet_ids        = [var.pub1, var.pub2]
  launch_template_id    = module.element_lt.launch_template_id
  instance_name         = "element-web"
  asg_target_group_arns = [module.element_alb.target_group_arn]
  asg_health_check_type = "ELB"
}
