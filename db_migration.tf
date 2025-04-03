resource "aws_ecs_task_definition" "db_migrations" {
  family                   = "db-migrations"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name  = "migrator",
    image = "183631301567.dkr.ecr.eu-west-1.amazonaws.com/lamp-backend:latest"
    command = [
      "sh",
      "-c",
      <<EOF
  echo "Running migrations directly against the database..."
  
  # Loop through all .sql files in the migrations directory and execute them
  for sql_file in /var/www/html/migrations/*.sql; do
    if [ -f "$sql_file" ]; then
      echo "Running migration: $sql_file"
      mysql -h ${aws_db_proxy.rds_proxy.endpoint} -u$DB_USER -p$DB_PASSWORD $DB_NAME < "$sql_file" && \
      echo "Migration completed: $sql_file"
    fi
  done
  
  echo "All migrations complete!"
  EOF
    ]



    environment = [

    ],
    secrets = [
      { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.rds_secret.arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.rds_secret.arn}:password::" },
      {
        name      = "DB_NAME",
        valueFrom = "${aws_secretsmanager_secret.rds_secret.arn}:db_name::"
      },
    ]
    logConfiguration = {
      # application level logs
      logDriver = "awslogs",
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend_logs.name,
        "awslogs-region"        = var.region,
        "awslogs-stream-prefix" = "db",
        "awslogs-create-group"  = "true"
      }
    }
  }])
}

resource "aws_ecs_service" "run_migrations" {
  name            = "DB-migrator"
  cluster         = aws_ecs_cluster.main.name
  task_definition = aws_ecs_task_definition.db_migrations.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs_sg.id]
  }

  depends_on = [
    aws_db_proxy.rds_proxy,
  ]
  enable_execute_command = true

}

# Add output to verify migrations
output "migration_status" {
  value = aws_ecs_service.run_migrations.id
}