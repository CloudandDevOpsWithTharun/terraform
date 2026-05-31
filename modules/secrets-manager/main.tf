resource "random_password" "db" {

  length = 24

  special = true
}

resource "aws_secretsmanager_secret" "this" {

  name = var.secret_name

  kms_key_id = var.kms_key_arn

  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "this" {

  secret_id = aws_secretsmanager_secret.this.id

  secret_string = jsonencode({

    username = var.username

    password = random_password.db.result

    dbname = var.db_name
  })
}