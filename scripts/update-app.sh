#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/environments/prod"

# Get ECR URL from Terraform
cd "$TERRAFORM_DIR"
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

echo "=== Updating Application ==="
echo "ECR: $ECR_REPO_URL"
echo ""

# Login to ECR
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "${ECR_REPO_URL%%/*}"

# Build and push
cd "$PROJECT_ROOT"
echo "Building image..."
docker build -t health-service:local .

echo "Pushing to ECR..."
docker tag health-service:local "$ECR_REPO_URL:latest"
docker push "$ECR_REPO_URL:latest"

# Restart deployment to pull new image
echo "Restarting deployment..."
kubectl rollout restart deployment/health-service
kubectl rollout status deployment/health-service --timeout=120s

echo ""
echo "=== Update Complete ==="
