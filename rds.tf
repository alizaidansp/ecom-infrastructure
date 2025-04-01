# RDS Database Instance (Private Subnet)
resource "aws_db_instance" "rds" {
  identifier             = "my-rds-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "mydatabase"
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name

  # backup config
  backup_retention_period = 7 # Days
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  username = jsondecode(aws_secretsmanager_secret_version.rds_secret_version.secret_string)["username"]
  password = jsondecode(aws_secretsmanager_secret_version.rds_secret_version.secret_string)["password"]
}


# RDS Subnet Group - Uses Private Subnet
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id # Use [*] to get all subnet IDs
}

# RDS Proxy - Sits Between Backend ECS & RDS
resource "aws_db_proxy" "rds_proxy" {
  name                   = "my-rds-proxy"
  role_arn               = aws_iam_role.rds_proxy_role.arn
  engine_family          = "MYSQL"
  vpc_subnet_ids         = aws_subnet.private[*].id
  vpc_security_group_ids = [aws_security_group.rds_proxy_sg.id]

  auth {
    description = "Proxy authentication"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.rds_secret.arn
  }

  depends_on = [
    aws_secretsmanager_secret_version.rds_secret_version,
    aws_db_instance.rds
  ]
}


resource "aws_db_proxy_target" "rds_proxy_target" {
  db_proxy_name          = aws_db_proxy.rds_proxy.name
  target_group_name      = "default"
  db_instance_identifier = aws_db_instance.rds.identifier
}
