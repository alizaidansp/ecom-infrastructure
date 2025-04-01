variable "region" {
  default = "eu-west-1"
}

variable "app_name" {
  default = "my-app"
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7 # Recommended values: 7 (dev), 30 (staging), 90 (production)
}

variable "environment" {
  description = "Deployment environment (prod)"
  type        = string
  default     = "prod"
}

