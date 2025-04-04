# outputs.tf
output "frontend_url" {
  value = "http://${aws_lb.app_alb.dns_name}"
}

output "backend_health" {
  value = "http://${aws_lb.app_alb.dns_name}/api/v1/health"
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

# If you also need the full URL (including protocol)
output "alb_url" {
  description = "The full URL of the Application Load Balancer"
  value       = "http://${aws_lb.app_alb.dns_name}"
}