resource "aws_instance" "ec2_instance" {
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = var.security_group_ids

  launch_template {
    id      = var.launch_template_id
    version = "$Latest"
  }

  tags = {
    Name = var.ec2_name
  }
}
