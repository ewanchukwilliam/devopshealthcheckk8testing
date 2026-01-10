#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
REPO_NAME="health-service"
ACCOUNT_ID=$AWS_ACCOUNT_ID

aws ecr create-repository --repository-name $REPO_NAME --region $REGION 2>/dev/null || true

aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

cd "$PROJECT_ROOT"
docker build -t health-service:local .

ECR_IMAGE="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest"
docker tag health-service:local $ECR_IMAGE
docker push $ECR_IMAGE

echo "ECR Image: $ECR_IMAGE"
