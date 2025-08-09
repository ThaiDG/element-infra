resource "aws_lb_target_group" "lb_target_group" {
  port        = var.target_group_port
  protocol    = var.target_group_protocol
  vpc_id      = var.target_group_vpc_id
  target_type = "instance"

  dynamic "health_check" {
    for_each = var.target_group_protocol == "HTTP" ? [1] : []
    content {
      enabled  = var.target_group_health_check_enabled
      protocol = var.target_group_health_check_protocol
      port     = var.target_group_health_check_port
      path     = var.target_group_health_check_path
      matcher  = "200"
    }
  }

  dynamic "health_check" {
    for_each = var.target_group_protocol == "TCP" ? [1] : []
    content {
      enabled  = var.target_group_health_check_enabled
      protocol = var.target_group_health_check_protocol
      port     = var.target_group_health_check_port
    }
  }
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = var.load_balancer_arn
  port              = var.listener_port
  protocol          = var.listener_protocol
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }
}
