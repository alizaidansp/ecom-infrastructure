# Backend Scaling (CPU/Memory focused)
resource "aws_appautoscaling_target" "backend_scale" {
  max_capacity       = 6 # More conservative
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "backend_scale_cpu" {
  name               = "backend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.backend_scale.resource_id
  scalable_dimension = aws_appautoscaling_target.backend_scale.scalable_dimension
  service_namespace  = aws_appautoscaling_target.backend_scale.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60  # Lower threshold for stability
    scale_in_cooldown  = 300 # Wait 5 mins before scaling in
    scale_out_cooldown = 120 # Wait 2 mins before scaling out

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Frontend Scaling (Request-count focused)
resource "aws_appautoscaling_target" "frontend_scale" {
  max_capacity       = 10 # Can scale more aggressively
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.frontend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "frontend_scale_requests" {
  name               = "frontend-request-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend_scale.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend_scale.scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend_scale.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 500 # Target 500 requests per container
    scale_in_cooldown  = 180
    scale_out_cooldown = 60 # Scale out faster during traffic spikes

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.app_alb.arn_suffix}/${aws_lb_target_group.frontend_tg.arn_suffix}"
    }
  }
}