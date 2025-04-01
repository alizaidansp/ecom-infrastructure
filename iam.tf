# ECS Task Execution Role (for both frontend/backend)
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy" "ecs_service_policy" {
  name = "ecs-service-policy"
  role = aws_iam_role.ecs_execution_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:Describe*",
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_exec" {
  name = "ecs-exec-policy"
  role = aws_iam_role.ecs_execution_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}

# RDS Proxy Role
resource "aws_iam_role" "rds_proxy_role" {
  name = "rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "rds_proxy_secrets" {
  role = aws_iam_role.rds_proxy_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = ["secretsmanager:GetSecretValue"],
      Effect   = "Allow",
      Resource = aws_secretsmanager_secret.rds_secret.arn
    }]
  })
}


resource "aws_iam_role_policy" "ecs_elb_registration" {
  name = "ecs-elb-registration"
  role = aws_iam_role.ecs_execution_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:DescribeTargetGroups"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_secrets_access" {
  name = "ecs-secrets-access"
  role = aws_iam_role.ecs_execution_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Effect   = "Allow",
        Resource = [
          aws_secretsmanager_secret.rds_secret.arn,
          aws_secretsmanager_secret.jwt_secret.arn,
          aws_secretsmanager_secret.frontend_url.arn
        ]
      },
      {
        Action = [
          "kms:Decrypt" # Only needed if using CMK encryption
        ],
        Effect   = "Allow",
        Resource = ["*"] # Restrict to your KMS key ARN if possible
      }
    ]
  })
}


resource "aws_iam_role_policy" "ecr_pull" {
  role   = aws_iam_role.ecs_execution_role.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "ecr:GetAuthorizationToken",  # Required for all ECR operations
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ],
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}