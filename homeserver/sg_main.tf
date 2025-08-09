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
      description = "Allow traffic ALB routing to Synapse federation port 8448"
      from_port   = 8448
      to_port     = 8448
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
      description = "Allow traffic for Synapse ALB"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # Allow all traffic for Synapse ALB
      security_groups = [
        "${module.element_sg.security_group_id}",     # Allow traffic from Element security group
        "${module.element_alb_sg.security_group_id}", # Allow traffic from Element ALB security group
        "${module.coturn_sg.security_group_id}",      # Allow traffic from Coturn security group
        "${module.coturn_nlb_sg.security_group_id}",  # Allow traffic from Coturn NLB security group
      ]
    },
    {
      description = "Allow traffic for Synapse Federation ALB"
      from_port   = 8448
      to_port     = 8448
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # Allow Federation traffic
      security_groups = [
        "${module.element_sg.security_group_id}",     # Allow traffic from Element security group
        "${module.element_alb_sg.security_group_id}", # Allow traffic from Element ALB security group
        "${module.coturn_sg.security_group_id}",      # Allow traffic from Coturn security group
        "${module.coturn_nlb_sg.security_group_id}",  # Allow traffic from Coturn NLB security group
      ]
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
      cidr_blocks = []
      security_groups = [
        "${module.synapse_sg.security_group_id}" # Allow traffic from Synapse security group
      ]
    }
  ]
}

# ---------------- EFS SECURITY GROUP ----------------
module "efs_sg" {
  source                     = "./modules/EC2/SecurityGroup"
  security_group_name_prefix = "${var.workspace}-efs-security-group"
  security_group_description = "Allow NFS traffic for EFS"
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description = "Allow NFS traffic from VPC CIDR"
      from_port   = 2049
      to_port     = 2049
      protocol    = "tcp"
      cidr_blocks = ["${data.terraform_remote_state.vpc.outputs.vpc_cidr}"] # VPC CIDR block
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
      cidr_blocks = ["0.0.0.0/0"] # Replace with VPN Client endpoint address later
    }
  ]
}
