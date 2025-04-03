resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id # Use [*] to get all subnet IDs
}


# target groups, routing alb to specific targets(example ecs tasks)
resource "aws_lb_target_group" "frontend_tg" {
  depends_on  = [aws_lb_listener.http]
  name        = "frontend-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"       # The endpoint the ALB uses to check if the target is healthy ("/" = root of the app).
    interval            = 30        # Time (in seconds) between each health check (default is 30s).
    timeout             = 5         # Time (in seconds) before marking the health check as failed if no response is received.
    healthy_threshold   = 2         # Number of consecutive successful health checks before considering the target healthy.
    unhealthy_threshold = 3         # Number of consecutive failed health checks before considering the target unhealthy.
    matcher             = "200-299" # Accept any 2xx status
  }

}

resource "aws_lb_target_group" "backend_tg" {
  depends_on  = [aws_lb_listener.http]
  name        = "backend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"


  health_check {
    path                = "/api/v1/health"
    interval            = 30        # Time (in seconds) between each health check (default is 30s).
    timeout             = 5         # Time (in seconds) before marking the health check as failed if no response is received.
    healthy_threshold   = 2         # Number of consecutive successful health checks before considering the target healthy.
    unhealthy_threshold = 3         # Number of consecutive failed health checks before considering the target unhealthy.
    matcher             = "200-299" # Accept any 2xx status
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  # so if the listener doesnt get a valid path "/" or "/api/v1/health" from  healthchecks in  the respective target groups
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "backend_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  # Priority in AWS ALB Listener Rules determines the 
  # order in which rules are evaluated.

  condition {
    path_pattern {
      values = ["/api*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

resource "aws_lb_listener_rule" "frontend_rule" {
  listener_arn = aws_lb_listener.http.arn


  priority = 200

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}


