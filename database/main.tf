resource "aws_security_group" "rds_sg" {
  name        = "${var.workspace}-aurora-postgres-access"
  description = "Allow inbound access to PostgreSQL from EC2"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.workspace}-aurora-postgres-access"
  }
}

# Create RDS subnet group for Aurora PostgreSQL
resource "aws_db_subnet_group" "aurora_pg_subnet_group" {
  name       = "${var.workspace}-aurora-pg-subnet-group"
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}

resource "aws_rds_cluster" "aurora_pg" {
  cluster_identifier   = "${var.workspace}-aurora-postgres-cluster"
  engine               = "aurora-postgresql"
  engine_mode          = "provisioned"
  engine_version       = "17"
  database_name        = "postgres"
  master_username      = data.aws_ssm_parameter.db_username.value
  master_password      = data.aws_ssm_parameter.db_password.value
  storage_encrypted    = true
  db_subnet_group_name = aws_db_subnet_group.aurora_pg_subnet_group.name

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.workspace}-aurora-postgres-cluster"

  performance_insights_enabled = false
  backup_retention_period      = 7
  preferred_backup_window      = "17:00-18:00"         # 00:00-01:00 GMT+7 (next day)
  preferred_maintenance_window = "Sat:18:30-Sat:20:00" # Sun 01:30-03:00 GMT+7
  apply_immediately            = true

  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Using all AZs for high availability
  availability_zones = data.aws_availability_zones.available.names
}

resource "aws_rds_cluster_instance" "aurora_pg_instance" {
  identifier                 = "${var.workspace}-aurora-pg-instance"
  cluster_identifier         = aws_rds_cluster.aurora_pg.id
  engine                     = aws_rds_cluster.aurora_pg.engine
  engine_version             = aws_rds_cluster.aurora_pg.engine_version
  instance_class             = "db.t4g.medium"
  publicly_accessible        = false
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.workspace}-aurora-pg-instance"
  }
}

# resource "aws_db_proxy" "aurora_pg_proxy" {
#   name                   = "${var.workspace}-aurora-pg-proxy"
#   engine_family          = "POSTGRESQL"
#   role_arn               = aws_iam_role.rds_proxy_role.arn
#   vpc_subnet_ids         = data.terraform_remote_state.vpc.outputs.private_subnet_ids
#   vpc_security_group_ids = [aws_security_group.rds_sg.id]
#   require_tls            = false

#   auth {
#     auth_scheme = "SECRETS"
#     secret_arn  = aws_secretsmanager_secret.db_credentials.arn
#     iam_auth    = "DISABLED"
#   }

#   tags = {
#     Name = "${var.workspace}-aurora-pg-proxy"
#   }
# }

# resource "aws_db_proxy_default_target_group" "aurora_pg_proxy_tg" {
#   db_proxy_name = aws_db_proxy.aurora_pg_proxy.name
# }

# resource "aws_db_proxy_target" "aurora_pg_proxy_target" {
#   db_proxy_name         = aws_db_proxy.aurora_pg_proxy.name
#   target_group_name     = aws_db_proxy_default_target_group.aurora_pg_proxy_tg.name
#   db_cluster_identifier = aws_rds_cluster.aurora_pg.id
# }

# resource "aws_iam_role" "rds_proxy_role" {
#   name = "${var.workspace}-rds-proxy-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Service = "rds.amazonaws.com"
#       }
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_policy" "rds_proxy_custom_policy" {
#   name        = "${var.workspace}-rds-proxy-custom-policy"
#   description = "Custom policy for RDS Proxy service role"

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "secretsmanager:GetSecretValue",
#           "secretsmanager:DescribeSecret",
#           "secretsmanager:ListSecretVersionIds"
#         ],
#         Resource = "${aws_secretsmanager_secret.db_credentials.arn}"
#       },
#       {
#         Effect = "Allow",
#         Action = [
#           "kms:Decrypt"
#         ],
#         Resource = "*" # You can scope this to your KMS key if needed
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "rds_proxy_policy" {
#   role       = aws_iam_role.rds_proxy_role.name
#   policy_arn = aws_iam_policy.rds_proxy_custom_policy.arn
# }

# resource "aws_secretsmanager_secret" "db_credentials" {
#   name = "${var.workspace}-aurora-db-credentials"
# }

# resource "aws_secretsmanager_secret_version" "db_credentials_version" {
#   secret_id = aws_secretsmanager_secret.db_credentials.id
#   secret_string = jsonencode({
#     username = "${data.aws_ssm_parameter.db_username.value}"
#     password = "${data.aws_ssm_parameter.db_password.value}"
#   })
# }

resource "aws_route53_record" "aurora_pg_dns" {
  zone_id = data.aws_route53_zone.main.id
  name    = "postgres.${var.root_domain}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_rds_cluster.aurora_pg.endpoint]
}
