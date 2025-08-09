resource "aws_ec2_client_vpn_endpoint" "clientvpn" {
  description            = "Client VPN for ${var.workspace} environment. Authentication with tapofthink.com Google Workspace"
  server_certificate_arn = data.aws_acm_certificate.client_vpn.arn
  authentication_options {
    type                           = "federated-authentication"
    saml_provider_arn              = "arn:aws:iam::767828741221:saml-provider/Google_Workspace"
    self_service_saml_provider_arn = "arn:aws:iam::767828741221:saml-provider/Google_Workspace"
  }

  connection_log_options {
    enabled              = true
    cloudwatch_log_group = aws_cloudwatch_log_group.client_vpn_log_group.name
  }

  client_cidr_block  = "10.10.0.0/16"
  dns_servers        = ["8.8.8.8", "8.8.4.4"]
  transport_protocol = "udp"
  vpn_port           = 1194
  split_tunnel       = true
  vpc_id             = aws_vpc.main.id
  security_group_ids = [aws_security_group.client_vpn_sg.id]
  tags = {
    Name = "${var.workspace}-client-vpn"
  }
}

resource "aws_security_group" "client_vpn_sg" {
  name        = "${var.workspace}-client_vpn_sg"
  description = "Allow all access when connecting to the VPN"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Client VPN can access any resources within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["${aws_vpc.main.cidr_block}"]
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "client_vpn_log_group" {
  name_prefix       = "${var.workspace}-client-vpn-audit"
  retention_in_days = 30
}

resource "aws_ec2_client_vpn_network_association" "private_subnet_1" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.clientvpn.id
  subnet_id              = module.private_subnet_1.subnet_id
}

resource "aws_ec2_client_vpn_network_association" "private_subnet_2" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.clientvpn.id
  subnet_id              = module.private_subnet_2.subnet_id
}

resource "aws_ec2_client_vpn_network_association" "private_subnet_3" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.clientvpn.id
  subnet_id              = module.private_subnet_3.subnet_id
}
# Each association will create a route to the VPC CIDR, so we have to allow it access
resource "aws_ec2_client_vpn_authorization_rule" "allow_vpc_access" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.clientvpn.id
  target_network_cidr    = aws_vpc.main.cidr_block
  authorize_all_groups   = true
}
