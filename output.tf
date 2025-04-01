# outputs.tf
output "frontend_url" {
  value = "http://${aws_lb.app_alb.dns_name}"
}

output "backend_health" {
  value = "http://${aws_lb.app_alb.dns_name}/api/v1/health"
}