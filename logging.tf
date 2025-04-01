# Service-specific log groups with dynamic naming
resource "aws_cloudwatch_log_group" "backend_logs" {
  name              = "/ecs/${var.environment}/backend"
  retention_in_days = var.log_retention_days
  tags = {
    Service     = "backend"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "frontend_logs" {
  name              = "/ecs/${var.environment}/frontend"
  retention_in_days = var.log_retention_days
  tags = {
    Service     = "frontend"
    Environment = var.environment
  }
}