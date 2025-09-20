# ---------------- SYNAPSE SECURITY GROUPS ----------------
# Security groups for Synapse main and federation services
module "synapse_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-synapse-security-group"
  security_group_description = "Security group for Synapse main services"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description = "Allow traffic ALB routing to Nginx port 80"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.synapse_alb_sg.security_group_id}" # Allow traffic from Synapse's ALB security group
      ]
    },
    {
      description = "Allow traffic ALB routing to Prometheus port 9090"
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.synapse_alb_sg.security_group_id}" # Allow traffic from Synapse's ALB security group
      ]
    }
  ]
}

# Security group for Synapse ALB
module "synapse_alb_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-synapse-alb-security-group"
  security_group_description = "Security group for Synapse ALB"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description     = "Allow traffic for Synapse ALB"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"] # Allow all traffic for Synapse ALB
      security_groups = []
    }
  ]
}

# ---------------- ELEMENT SECURITY GROUPS ----------------
# Security groups for Element client
module "element_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-element-security-group"
  security_group_description = "Security group for Element client"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description = "Allow traffic for Element client"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.element_alb_sg.security_group_id}" # Allow traffic from Element's ALB security group
      ]
    },
    {
      description = "Allow traffic for Prometheus"
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.element_alb_sg.security_group_id}" # Allow traffic from Element's ALB Security Group
      ]
    }
  ]
}

# Security group for Element ALB
module "element_alb_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-element-alb-security-group"
  security_group_description = "Security group for Element ALB"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description = "Allow traffic for Element ALB"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # Allow all traffic for Element ALB
    }
  ]
}

# ---------------- COTURN SECURITY GROUPS ----------------
# Security groups for Coturn services
module "coturn_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-coturn-security-group"
  security_group_description = "Security group for Coturn services"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description = "Allow traffic for Coturn services port 3478 (TCP)"
      from_port   = 3478
      to_port     = 3478
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.coturn_nlb_sg.security_group_id}" # Allow traffic from Coturn NLB security group
      ]
    },
    {
      description = "Allow traffic for Coturn services port 3478 (UDP)"
      from_port   = 3478
      to_port     = 3478
      protocol    = "udp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.coturn_nlb_sg.security_group_id}" # Allow traffic from Coturn NLB security group
      ]
    },
    {
      description = "Allow traffic for Coturn services port 5349 (TCP)"
      from_port   = 5349
      to_port     = 5349
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.coturn_nlb_sg.security_group_id}" # Allow traffic from Coturn NLB security group
      ]
    },
    {
      description = "Allow traffic for Coturn services port 5349 (UDP)"
      from_port   = 5349
      to_port     = 5349
      protocol    = "udp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.coturn_nlb_sg.security_group_id}" # Allow traffic from Coturn NLB security group
      ]
    },
    {
      description = "Allow traffic for Prometheus"
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.coturn_nlb_sg.security_group_id}" # Allow traffic from Coturn NLB security group
      ]
    },
    {
      description = "Allow traffic for Coturn services port 49152-65535 (UDP)"
      from_port   = 49152
      to_port     = 65535
      protocol    = "udp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.coturn_nlb_sg.security_group_id}" # Allow traffic from Coturn NLB security group
      ]
    },
    {
      description = "Allow traffic for Coturn services port 49152-65535 (TCP)"
      from_port   = 49152
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.coturn_nlb_sg.security_group_id}" # Allow traffic from Coturn NLB security group
      ]
    }
  ]
}

# Security group for Coturn NLB
module "coturn_nlb_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-coturn-nlb-tcp-security-group"
  security_group_description = "Security group for Coturn NLB TCP"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description     = "Allow traffic for Coturn NLB TCP port 3478"
      from_port       = 3478
      to_port         = 3478
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"] # Allow all traffic for Coturn NLB
      security_groups = []
    },
    {
      description     = "Allow traffic for Coturn NLB UDP port 3478"
      from_port       = 3478
      to_port         = 3478
      protocol        = "udp"
      cidr_blocks     = ["0.0.0.0/0"] # Allow all traffic for Coturn NLB
      security_groups = []
    },
    {
      description     = "Allow traffic for Coturn NLB TCP port 5349"
      from_port       = 5349
      to_port         = 5349
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"] # Allow all traffic for Coturn NLB
      security_groups = []
    },
    {
      description     = "Allow traffic for Coturn NLB UDP port 5349"
      from_port       = 5349
      to_port         = 5349
      protocol        = "udp"
      cidr_blocks     = ["0.0.0.0/0"] # Allow all traffic for Coturn NLB
      security_groups = []
    },
    {
      description     = "Allow traffic for Coturn NLB UDP port 49152-65535"
      from_port       = 49152
      to_port         = 65535
      protocol        = "udp"
      cidr_blocks     = ["0.0.0.0/0"] # Allow all traffic for Coturn NLB
      security_groups = []
    },
    {
      description     = "Allow traffic for Coturn NLB TCP port 49152-65535"
      from_port       = 49152
      to_port         = 65535
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"] # Allow all traffic for Coturn NLB
      security_groups = []
    }
  ]
}

# ---------------- SYGNAL SECURITY GROUPS ----------------
module "sygnal_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-sygnal-security-group"
  security_group_description = "Security group for Sygnal service"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description = "Allow traffic for Sygnal service port 5000"
      from_port   = 5000
      to_port     = 5000
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.sygnal_alb_sg.security_group_id}" # Allow traffic from Sygnal's ALB security group
      ]
    },
    {
      description = "Allow traffic for Prometheus"
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.sygnal_alb_sg.security_group_id}" # Allow traffic from Sygnal's ALB security group
      ]
    }
  ]
}

module "sygnal_alb_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-sygnal-alb-security-group"
  security_group_description = "Security group for Sygnal ALB"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description = "Allow traffic for Sygnal ALB port 443"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# ---------------- SSH SECURITY GROUP ----------------
module "ssh_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-ssh-security-group"
  security_group_description = "Security group for SSH access"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description = "Allow SSH access from specific IP"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# ---------------- LIVEKIT SECURITY GROUP ----------------
module "livekit_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-livekit-security-group"
  security_group_description = "Security group for LiveKit server"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description     = "Allow traffic for LiveKit server port 80 (HTTP) from internet via NLB (preserves client IP)"
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    },
    {
      description     = "Allow traffic for LiveKit TURN TLS port 5349 (TCP) from internet via NLB (preserves client IP)"
      from_port       = 5349
      to_port         = 5349
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    },
    {
      description     = "Allow traffic for LiveKit ICE TCP fallback"
      from_port       = 7881
      to_port         = 7881
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    },
    {
      description     = "Allow traffic for LiveKit TURN UDP 3478 from internet via NLB (preserves client IP)"
      from_port       = 3478
      to_port         = 3478
      protocol        = "udp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    },
    {
      description     = "Allow traffic for LiveKit server UDP port"
      from_port       = 50000
      to_port         = 60000
      protocol        = "udp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    },
    {
      description = "Allow traffic for Prometheus"
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.livekit_alb_sg.security_group_id}" # Allow traffic from LiveKit's ALB security group
      ]
    }
  ]
}

module "livekit_alb_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-livekit-alb-security-group"
  security_group_description = "Security group for LiveKit ALB"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description = "Allow traffic for LiveKit NLB TCP 80 (HTTP)"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Allow traffic for LiveKit NLB TLS 443 (frontend)"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Allow traffic for LiveKit NLB UDP 3478 (TURN)"
      from_port   = 3478
      to_port     = 3478
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Allow traffic for LiveKit NLB TCP 5349 (TURN TLS)"
      from_port   = 5349
      to_port     = 5349
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# ---------------- SYDENT SECURITY GROUPS ----------------
module "sydent_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-sydent-security-group"
  security_group_description = "Security group for Matrix Identity Server"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description = "Allow traffic for Sydent service port 80"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.sydent_alb_sg.security_group_id}" # Allow traffic from Sydent's ALB security group
      ]
    },
    {
      description = "Allow traffic for Prometheus metrics"
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
      security_groups = [
        "${module.sydent_alb_sg.security_group_id}" # Allow traffic from Sydent's ALB security group
      ]
    }
  ]
}

module "sydent_alb_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-sydent-alb-security-group"
  security_group_description = "Security group for Sydent ALB"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description = "Allow HTTPS traffic for Sydent ALB"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      security_groups = []
    }
  ]
}

# ---------------- MAS SERVER SECURITY GROUP ----------------
# module "mas_sg" {
#   source                     = "./modules/EC2/SecurityGroup"
#   security_group_name_prefix = "${var.workspace}-mas-server-security-group-"
#   security_group_description = "Security group for MAS Server"
#   vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

#   ingress_rules = [
#     {
#       description = "Allow traffic from ALB"
#       from_port   = 0
#       to_port     = 0
#       protocol    = "tcp"
#       cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"]
#     }
#   ]
# }

# module "mas_alb_sg" {
#   source                     = "./modules/EC2/SecurityGroup"
#   security_group_name_prefix = "${var.workspace}-mas-server-alb-security-group-"
#   security_group_description = "Security group for MAS Server ALB"
#   vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

#   ingress_rules = [
#     {
#       description = "Allow traffic for MAS Server ALB port 443"
#       from_port   = 0
#       to_port     = 0
#       protocol    = "tcp"
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#   ]
# }
