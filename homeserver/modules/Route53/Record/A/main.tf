resource "aws_route53_record" "record_type_a_dns" {
  zone_id = var.zone_id
  name    = var.record_name
  type    = "A"
  alias {
    name                   = var.aws_lb_dns_name
    zone_id                = var.aws_lb_zone_id
    evaluate_target_health = true
  }
}
