#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform/environments/prod"

echo "=== Connecting to EKS Cluster ==="

cd "$TERRAFORM_DIR"

# Get cluster info from Terraform state
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null) || {
  echo "Error: Could not get cluster_name from Terraform."
  echo "Make sure you've deployed the cluster first (./spinup-prod.sh)"
  exit 1
}

AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

echo "Cluster: $CLUSTER_NAME"
echo "Region:  $AWS_REGION"
echo ""

# Configure kubectl
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo ""
echo "=== Connected! ==="
echo "Try: kubectl get nodes"
