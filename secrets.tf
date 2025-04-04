
# DB Secret
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "rds_secret" {
  name                    = "my-rdsSecret"
  description             = "Credentials for RDS database"
  recovery_window_in_days = 0 # Set to 0 for immediate deletion, or 7-30 for retention

}

resource "aws_secretsmanager_secret_version" "rds_secret_version" {
  secret_id = aws_secretsmanager_secret.rds_secret.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_password.result # Using the generated password
    db_name  = "mydatabase"
  })

}
# Then create a separate secret for the host,after instance is up
resource "aws_secretsmanager_secret_version" "rds_host_version" {
  secret_id = aws_secretsmanager_secret.rds_secret.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_password.result
    db_name  = "mydatabase"
    host     = aws_db_instance.rds.address
  })

  depends_on = [aws_db_instance.rds]
}

# Output the secret ARN for reference
output "rds_secret_arn" {
  value       = aws_secretsmanager_secret.rds_secret.arn
  description = "ARN of the RDS secret in AWS Secrets Manager"
  sensitive   = true
}




# JWT Secret
resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "app-jwtSecret"
}

resource "aws_secretsmanager_secret_version" "jwt_secret_version" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    jwt_secret = random_password.jwt.result
  })
}

resource "random_password" "jwt" {
  length  = 64
  special = false
}


# Frontend URL Secret (for backend service)
resource "aws_secretsmanager_secret" "frontend_url" {
  name = "frontendUrl"
}

resource "aws_secretsmanager_secret_version" "frontend_url_version" {
  secret_id = aws_secretsmanager_secret.frontend_url.id
  secret_string = jsonencode({
    frontend_url = "http://${aws_lb.app_alb.dns_name}/api/v1"
  })
}