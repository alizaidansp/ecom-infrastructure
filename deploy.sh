#!/bin/bash
set -eo pipefail

# Initialize
TERRAFORM_DIR=$(pwd)
STAGE_PREFIX="[DEPLOYMENT]"
BACKEND_HEALTH_ENDPOINT="/api/v1/health"

function format_terraform() {
  echo "$STAGE_PREFIX Formatting Terraform files..."
  terraform fmt
}
function validate_terraform() {
  echo "$STAGE_PREFIX Validating Terraform configuration..."
  terraform validate
}

function apply_infrastructure() {
  echo "$STAGE_PREFIX Applying infrastructure..."
  terraform apply -auto-approve
}



function verify_backend() {
  local alb_dns=$(terraform output -raw alb_dns_name)
  echo "$STAGE_PREFIX Verifying backend at $alb_dns$BACKEND_HEALTH_ENDPOINT..."
  
  for i in {1..10}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://$alb_dns$BACKEND_HEALTH_ENDPOINT" || true)
    if [ "$response" -eq 200 ]; then
      echo "$STAGE_PREFIX Backend is healthy!"
      return 0
    fi
    sleep 10
  done
  
  echo "$STAGE_PREFIX Backend verification failed"
  return 1
}

function verify_frontend() {
  local alb_dns=$(terraform output -raw alb_dns_name)
  echo "$STAGE_PREFIX Verifying frontend at http://$alb_dns..."
  
  for i in {1..5}; do
    if curl -s "http://$alb_dns" | grep -q "<title>"; then
      echo "$STAGE_PREFIX Frontend is healthy!"
      return 0
    fi
    sleep 5
  done
  
  echo "$STAGE_PREFIX Frontend verification failed"
  return 1
}


# Main Deployment Flow

format_terraform

validate_terraform

# Phase 1: Apply All Infrastructure
apply_infrastructure



# Phase 2: Backend Services Verification
verify_backend || exit 1

# Phase 3: Frontend Services Verification
verify_frontend || exit 1

# Final Apply to Ensure Everything is Synced
echo "$STAGE_PREFIX Running final Terraform apply..."
terraform apply -auto-approve

echo "$STAGE_PREFIX Deployment completed successfully!"
