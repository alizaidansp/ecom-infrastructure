
#  fix logs and vital env var
resource "aws_ecs_task_definition" "frontend" {
  family                   = "frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name  = "frontend"
    image = "183631301567.dkr.ecr.eu-west-1.amazonaws.com/lamp-frontend:latest", # Full ECR URI
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]

    healthCheck = {
      command = [
        "CMD-SHELL",
        "curl -f http://localhost:3000 || exit 1"
      ],
      interval    = 15, # More frequent than ALB's 30s
      timeout     = 5,
      retries     = 3,
      startPeriod = 30 # Startup grace period
    },

    secrets = [
      {
        name      = "VITE_API_URL",
        valueFrom = "${aws_secretsmanager_secret.frontend_url.arn}:frontend_url::"
      }
    ],
    logConfiguration = {
      # application-level logs
      logDriver = "awslogs",
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend_logs.name,
        "awslogs-region"        = var.region,
        "awslogs-stream-prefix" = "frontend",
        "awslogs-create-group"  = "true"
      }
    }
  }])
}

resource "aws_ecs_service" "frontend" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id # Instead of [aws_subnet.private.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = "frontend"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_target_group.frontend_tg,
    aws_lb_listener_rule.frontend_rule,
    aws_ecs_service.backend,
    aws_db_proxy.rds_proxy
  ]

  enable_execute_command = true

  # Added deployment circuit breaker for rollback of failed deployments without intervention
  deployment_controller {
    type = "ECS"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Health check grace period (for slow starters)
  health_check_grace_period_seconds = 60




  # Enable Container Insights
  tags = {
    "ecs:enable-container-insights" = "true"
  }



}