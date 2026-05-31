resource "aws_db_subnet_group" "this" {
  name = "${var.name}-subnet-group"

  subnet_ids = var.private_subnet_ids

  tags = var.tags
}

resource "aws_security_group" "rds" {
  name   = "${var.name}-rds-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_db_instance" "this" {

  identifier = var.name

  engine         = "postgres"
  engine_version = "16"

  instance_class = var.instance_class

  allocated_storage     = 100
  max_allocated_storage = 500

  storage_type = "gp3"

  multi_az = true

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  username = var.master_username

  manage_master_user_password = true

  db_subnet_group_name = aws_db_subnet_group.this.name

  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  publicly_accessible = false

  backup_retention_period = 14
  backup_window           = "03:00-04:00"

  maintenance_window = "sun:04:00-sun:05:00"

  deletion_protection = true

  performance_insights_enabled = false

  enabled_cloudwatch_logs_exports = [
    "postgresql"
  ]

  skip_final_snapshot = false
  final_snapshot_identifier = "${var.name}-final-snapshot"

  apply_immediately = false

  tags = var.tags
}