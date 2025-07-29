resource "aws_security_group" "security_group" {
  name_prefix = var.security_group_name_prefix
  description = var.security_group_description
  vpc_id      = var.vpc_id

  # ingress {
  #   description = var.ingress_description
  #   from_port   = var.ingress_from_port
  #   to_port     = var.ingress_to_port
  #   protocol    = var.ingress_protocol
  #   cidr_blocks = var.ingress_cidr_blocks
  # }

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description     = "${ingress.value.description}"
      from_port       = "${ingress.value.from_port}"
      to_port         = "${ingress.value.to_port}"
      protocol        = "${ingress.value.protocol}"
      cidr_blocks     = "${ingress.value.cidr_blocks}"
      self            = true
      security_groups = "${ingress.value.security_groups}"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.security_group_name_prefix
  }
}