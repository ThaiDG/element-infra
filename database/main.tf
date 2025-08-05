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

  skip_final_snapshot       = var.workspace == "prod" ? false : true
  final_snapshot_identifier = var.workspace == "prod" ? "${var.workspace}-aurora-postgres-cluster" : null

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  serverlessv2_scaling_configuration {
    min_capacity             = 0
    max_capacity             = 4
    seconds_until_auto_pause = 300
  }

  availability_zones = data.aws_availability_zones.available.names
}

resource "aws_rds_cluster_instance" "aurora_pg_instance" {
  identifier          = "${var.workspace}-aurora-pg-instance"
  cluster_identifier  = aws_rds_cluster.aurora_pg.id
  engine              = aws_rds_cluster.aurora_pg.engine
  engine_version      = aws_rds_cluster.aurora_pg.engine_version
  instance_class      = "db.serverless" # Required for Serverless v2
  publicly_accessible = false

  tags = {
    Name = "${var.workspace}-aurora-pg-instance"
  }
}

resource "aws_route53_record" "aurora_pg_dns" {
  zone_id = data.aws_route53_zone.main.id
  name    = "postgres.${var.root_domain}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_rds_cluster.aurora_pg.endpoint]
}
