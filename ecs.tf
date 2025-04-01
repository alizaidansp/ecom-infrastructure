resource "aws_ecs_cluster" "main" {
  name = "app-cluster"
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/app"
  retention_in_days = 7
}