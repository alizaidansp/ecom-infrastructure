
resource "aws_ecs_task_definition" "backend" {
  family                   = "backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn


  container_definitions = jsonencode([{
    name      = "backend"
    image     = "183631301567.dkr.ecr.eu-west-1.amazonaws.com/lamp-backend:latest"
    essential = true
    environment = [
      { name = "DB_HOST", value = aws_db_proxy.rds_proxy.endpoint },
      # { name = "ALB_DNS", value = "${aws_lb.app_alb.dns_name}" } # ✅ Pass ALB DNS dynamically

    ],
    secrets = [
      {
        name      = "DB_USER",
        valueFrom = "${aws_secretsmanager_secret.rds_secret.arn}:username::"
      },
      {
        name      = "DB_PASSWORD",
        valueFrom = "${aws_secretsmanager_secret.rds_secret.arn}:password::"
      },
      {
        name      = "DB_NAME",
        valueFrom = "${aws_secretsmanager_secret.rds_secret.arn}:db_name::"
      },
      {
        name      = "JWT_SECRET",
        valueFrom = "${aws_secretsmanager_secret.jwt_secret.arn}:jwt_secret::"
      },
      {
        name      = "FRONTEND_URL",
        valueFrom = "${aws_secretsmanager_secret.frontend_url.arn}:frontend_url::"
      }
    ],

    logConfiguration = {
      # application level logs
      logDriver = "awslogs",
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend_logs.name,
        "awslogs-region"        = var.region,
        "awslogs-stream-prefix" = "backend",
        "awslogs-create-group"  = "true"
      }
    }
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }],

    healthCheck = {
      command = [
        "CMD-SHELL",
        "curl -f http://localhost:80/api/v1/health || exit 1"
      ],
      interval    = 10, # More frequent than ALB
      timeout     = 5,
      retries     = 3,
      startPeriod = 30 # Give container time to start
    }

  }])
}



resource "aws_ecs_service" "backend" {
  name            = "backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id # Instead of [aws_subnet.private.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "backend"
    container_port   = 80
  }

  # Ensure migrations run first
  depends_on = [
    aws_db_proxy.rds_proxy,
    aws_lb_target_group.backend_tg,
    aws_lb_listener_rule.backend_rule,
    aws_ecs_service.run_migrations, # Wait for migrations

  ]

  enable_execute_command = true
  # 
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