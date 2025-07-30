data "template_file" "sygnal_init" {
  template = file("${path.module}/scripts/sygnal_service_setup.tpl.sh")

  vars = {
    aws_account_id = "${data.aws_caller_identity.current.account_id}"
    aws_region     = "${data.aws_region.current.name}"
  }
}

module "sygnal_lt" {
  source = "./modules/EC2/LaunchTemplate"
  name_prefix   = "${var.workspace}-sygnal-service-lt"
  image_id      = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.medium"
  user_data     = data.template_file.sygnal_init.rendered
  instance_name = "${var.workspace}-sygnal-service"
  volume_size   = 8
  security_group_ids = [
    module.sygnal_sg.security_group_id,
    module.ssh_sg.security_group_id
  ]

  tags = {
    UserDataHash = md5(data.template_file.sygnal_init.rendered)
  }
}

resource "aws_lb" "sygnal_alb" {
  name_prefix                = "sygnal"
  load_balancer_type         = "application"
  preserve_host_header       = true
  enable_xff_client_port     = true
  xff_header_processing_mode = "preserve"
  subnets = [
    var.pub1,
    var.pub2
  ]
  security_groups = [
    module.sygnal_alb_sg.security_group_id
  ]
}

module "sygnal_alb" {
  source                             = "./modules/EC2/LoadBalancing"
  load_balancer_arn                  = aws_lb.sygnal_alb.arn
  target_group_port                  = 5000
  target_group_protocol              = "HTTP"
  target_group_vpc_id                = var.vpc_id
  target_group_health_check_enabled  = true
  target_group_health_check_path     = "/health"
  target_group_health_check_port     = "5000"
  target_group_health_check_protocol = "HTTP"
  listener_port                      = 443
  listener_protocol                  = "HTTPS"
  certificate_arn                    = data.aws_acm_certificate.default.arn
}

module "sygnal_asg" {
  source                = "./modules/EC2/AutoScalingGroup"
  asg_name              = "${var.workspace}-sygnal-service-asg"
  asg_desired_capacity  = 1
  asg_min_size          = 1
  asg_max_size          = 2
  asg_subnet_ids        = [var.pub1, var.pub2]
  launch_template_id    = module.sygnal_lt.launch_template_id
  instance_name         = "${var.workspace}-sygnal-service"
  asg_target_group_arns = [module.sygnal_alb.target_group_arn]
#   asg_health_check_type = "ELB"
}
