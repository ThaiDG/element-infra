# data "template_file" "mas_init" {
#   template = file("${path.module}/scripts/mas_server_setup.tpl.sh")

#   vars = {
#     aws_account_id = "${data.aws_caller_identity.current.account_id}"
#     aws_region     = "${data.aws_region.current.region}"
#     mas_dns        = "${module.mas_route53_record.record_dns_name}"
#     synapse_dns    = "${module.synapse_route53_record.record_dns_name}"
#     postgres_dns   = "${module.postgres_route53_record.record_dns_name}"
#   }
# }

# module "mas_lt" {
#   source        = "./modules/EC2/LaunchTemplate"
#   name_prefix   = "${var.workspace}-mas-server-lt-"
#   image_id      = data.aws_ami.ubuntu_2404.id
#   instance_type = "t3.medium"
#   user_data     = data.template_file.mas_init.rendered
#   instance_name = "${var.workspace}-mas-server"
#   volume_size   = 30
#   security_group_ids = [
#     module.mas_sg.security_group_id,
#     module.ssh_sg.security_group_id,
#   ]

#   tags = {
#     UserDataHash = md5(data.template_file.mas_init.rendered)
#   }
# }

# resource "aws_lb" "mas_alb" {
#   name_prefix                = "mas-"
#   load_balancer_type         = "application"
#   preserve_host_header       = true
#   enable_xff_client_port     = true
#   xff_header_processing_mode = "preserve"
#   subnets                    = data.terraform_remote_state.vpc.outputs.public_subnet_ids
#   security_groups = [
#     module.mas_alb_sg.security_group_id,
#   ]
# }

# # Routing to HTTPS for MAS server
# module "mas_target" {
#   source                             = "./modules/EC2/LoadBalancing"
#   load_balancer_arn                  = aws_lb.mas_alb.arn
#   target_group_port                  = 8080
#   target_group_protocol              = "HTTP"
#   target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
#   target_group_health_check_enabled  = true
#   target_group_health_check_path     = "/health"
#   target_group_health_check_port     = "8081"
#   target_group_health_check_protocol = "HTTP"
#   listener_port                      = 443
#   listener_protocol                  = "HTTPS"
#   certificate_arn                    = data.aws_acm_certificate.default.arn
# }

# # Routing the Prometheus port
# module "mas_prometheus_target" {
#   source                            = "./modules/EC2/LoadBalancing"
#   load_balancer_arn                 = aws_lb.mas_alb.arn
#   target_group_port                 = 9090
#   target_group_protocol             = "HTTP"
#   target_group_vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
#   target_group_health_check_enabled = true
#   target_group_health_check_path    = "/-/healthy"
#   target_group_health_check_port    = "9090"
#   listener_port                     = 9090
#   listener_protocol                 = "HTTPS"
#   certificate_arn                   = data.aws_acm_certificate.default.arn
# }

# module "mas_asg" {
#   source                = "./modules/EC2/AutoScalingGroup"
#   asg_name              = "${var.workspace}-mas-server-asg-"
#   asg_desired_capacity  = 1
#   asg_min_size          = var.workspace == "dev" ? 0 : 1 # Set to 0 for dev workspace
#   asg_max_size          = 2
#   asg_subnet_ids        = data.terraform_remote_state.vpc.outputs.public_subnet_ids
#   launch_template_id    = module.mas_lt.launch_template_id
#   instance_name         = "${var.workspace}-mas"
#   workspace             = var.workspace
#   asg_health_check_type = "EC2"
#   asg_target_group_arns = [
#     module.mas_target.target_group_arn,
#   ]
# }
