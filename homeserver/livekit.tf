# LIVEKIT SERVER - DISABLED (Element Classic mobile app doesn't support widgets)
# Keeping this configuration for future use when Element Call support is needed

# locals {
#   livekit_server = base64gzip(templatefile("${path.module}/scripts/livekit_server_setup.tpl.sh", {
#     redis_endpoint = aws_elasticache_serverless_cache.livekit.endpoint[0].address
#     redis_port     = aws_elasticache_serverless_cache.livekit.endpoint[0].port
#     root_domain    = var.root_domain
#     synapse_dns    = module.synapse_route53_record.record_dns_name
#     region         = data.aws_region.current.region
#   }))
# }

# module "livekit_lt" {
#   source        = "./modules/EC2/LaunchTemplate"
#   name_prefix   = "${var.workspace}-livekit-server-lt"
#   image_id      = data.aws_ami.ubuntu_2404.id
#   instance_type = "t3.medium"
#   user_data     = local.livekit_server
#   instance_name = "${var.workspace}-livekit-server"
#   volume_size   = 30
#   security_group_ids = [
#     module.livekit_sg.security_group_id,
#     aws_security_group.valkey.id,
#     module.ssh_sg.security_group_id,
#   ]

#   tags = {
#     UserDataHash = md5(local.livekit_server)
#   }
# }

# resource "aws_lb" "livekit_alb" {
#   name_prefix                = "lkcall"
#   load_balancer_type         = "network"
#   preserve_host_header       = true
#   enable_xff_client_port     = true
#   xff_header_processing_mode = "preserve"
#   subnets                    = data.terraform_remote_state.vpc.outputs.public_subnet_ids
#   security_groups = [
#     module.livekit_alb_sg.security_group_id,
#     module.synapse_sg.security_group_id, # Allow traffic from Synapse security group
#   ]
# }

# module "livekit_https_target" {
#   source                             = "./modules/EC2/LoadBalancing"
#   load_balancer_arn                  = aws_lb.livekit_alb.arn
#   target_group_port                  = 80
#   target_group_protocol              = "TCP"
#   target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
#   target_group_health_check_enabled  = true
#   target_group_health_check_port     = "80"
#   target_group_health_check_protocol = "TCP"
#   listener_port                      = 443
#   listener_protocol                  = "TLS"
#   certificate_arn                    = data.aws_acm_certificate.default.arn
# }

# module "livekit_http_target" {
#   source                             = "./modules/EC2/LoadBalancing"
#   load_balancer_arn                  = aws_lb.livekit_alb.arn
#   target_group_port                  = 80
#   target_group_protocol              = "TCP"
#   target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
#   target_group_health_check_enabled  = true
#   target_group_health_check_port     = "80"
#   target_group_health_check_protocol = "TCP"
#   listener_port                      = 80
#   listener_protocol                  = "TCP"
#   certificate_arn                    = ""
# }

# module "livekit_turn_target" {
#   source                             = "./modules/EC2/LoadBalancing"
#   load_balancer_arn                  = aws_lb.livekit_alb.arn
#   target_group_port                  = 5349
#   target_group_protocol              = "TCP"
#   target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
#   target_group_health_check_enabled  = true
#   target_group_health_check_port     = "5349"
#   target_group_health_check_protocol = "TCP"
#   listener_port                      = 5349
#   listener_protocol                  = "TCP"
#   certificate_arn                    = ""
# }

# module "livekit_turn_udp_target" {
#   source                             = "./modules/EC2/LoadBalancing"
#   load_balancer_arn                  = aws_lb.livekit_alb.arn
#   target_group_port                  = 3478
#   target_group_protocol              = "UDP"
#   target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
#   target_group_health_check_enabled  = true
#   target_group_health_check_port     = "7881"
#   target_group_health_check_protocol = "TCP"
#   listener_port                      = 3478
#   listener_protocol                  = "UDP"
#   certificate_arn                    = ""
# }

# module "livekit_prometheus_target" {
#   source                             = "./modules/EC2/LoadBalancing"
#   load_balancer_arn                  = aws_lb.livekit_alb.arn
#   target_group_port                  = 9090
#   target_group_protocol              = "TCP"
#   target_group_vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
#   target_group_health_check_enabled  = true
#   target_group_health_check_port     = "9090"
#   target_group_health_check_protocol = "TCP"
#   listener_port                      = 9090
#   listener_protocol                  = "TLS"
#   certificate_arn                    = data.aws_acm_certificate.default.arn
# }

# module "livekit_asg" {
#   source                = "./modules/EC2/AutoScalingGroup"
#   asg_name              = "${var.workspace}-livekit-server-asg"
#   asg_desired_capacity  = 1
#   asg_min_size          = var.workspace == "dev" ? 0 : 1 # Set to 0 for dev workspace
#   asg_max_size          = 3
#   asg_subnet_ids        = data.terraform_remote_state.vpc.outputs.public_subnet_ids
#   launch_template_id    = module.livekit_lt.launch_template_id
#   instance_name         = "${var.workspace}-livekit-server"
#   workspace             = var.workspace
#   asg_health_check_type = "ELB"
#   asg_target_group_arns = [
#     module.livekit_http_target.target_group_arn,
#     module.livekit_https_target.target_group_arn,
#     module.livekit_turn_target.target_group_arn,
#     module.livekit_turn_udp_target.target_group_arn,
#     module.livekit_prometheus_target.target_group_arn,
#   ]
# }

