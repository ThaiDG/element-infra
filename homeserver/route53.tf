module "synapse_route53_record" {
  source          = "./modules/Route53/Record/A"
  zone_id         = data.aws_route53_zone.main.id
  record_name     = "yoush.${var.root_domain}"
  aws_lb_dns_name = aws_lb.synapse_alb.dns_name
  aws_lb_zone_id  = aws_lb.synapse_alb.zone_id
}

module "web_tapyoush_route53_record" {
  source          = "./modules/Route53/Record/A"
  zone_id         = data.aws_route53_zone.tapyoush.id
  record_name     = var.workspace == "prod" ? "tapyoush.com" : "${var.workspace}.tapyoush.com"
  aws_lb_dns_name = aws_lb.element_alb.dns_name
  aws_lb_zone_id  = aws_lb.element_alb.zone_id
}

module "web_youshtap_route53_record" {
  source          = "./modules/Route53/Record/A"
  zone_id         = data.aws_route53_zone.youshtap.id
  record_name     = var.workspace == "prod" ? "youshtap.com" : "${var.workspace}.youshtap.com"
  aws_lb_dns_name = aws_lb.element_alb.dns_name
  aws_lb_zone_id  = aws_lb.element_alb.zone_id
}

module "coturn_tcp_route53_record" {
  source          = "./modules/Route53/Record/A"
  zone_id         = data.aws_route53_zone.main.id
  record_name     = "coturn-tcp.${var.root_domain}"
  aws_lb_dns_name = aws_lb.coturn_nlb_tcp.dns_name
  aws_lb_zone_id  = aws_lb.coturn_nlb_tcp.zone_id
}

module "coturn_udp_route53_record" {
  source          = "./modules/Route53/Record/A"
  zone_id         = data.aws_route53_zone.main.id
  record_name     = "coturn-udp.${var.root_domain}"
  aws_lb_dns_name = aws_lb.coturn_nlb_udp.dns_name
  aws_lb_zone_id  = aws_lb.coturn_nlb_udp.zone_id
}

module "sygnal_route53_record" {
  source          = "./modules/Route53/Record/A"
  zone_id         = data.aws_route53_zone.main.id
  record_name     = "sygnal.${var.root_domain}"
  aws_lb_dns_name = aws_lb.sygnal_alb.dns_name
  aws_lb_zone_id  = aws_lb.sygnal_alb.zone_id
}
