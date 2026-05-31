output "secret_arn" {
  value = aws_secretsmanager_secret.this.arn
}

output "password" {
  value     = random_password.db.result
  sensitive = true
}