#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Uninstalling Helm Releases ==="

# Uninstall health-service application
echo "Removing health-service..."
helm uninstall health-service 2>/dev/null || echo "health-service not found, skipping"

# Uninstall NGINX ingress controller
echo "Removing nginx-ingress..."
helm uninstall nginx-ingress --namespace ingress-nginx 2>/dev/null || echo "nginx-ingress not found, skipping"

# Uninstall cert-manager
echo "Removing cert-manager..."
helm uninstall cert-manager --namespace cert-manager 2>/dev/null || echo "cert-manager not found, skipping"

# Uninstall cluster autoscaler
echo "Removing cluster-autoscaler..."
helm uninstall cluster-autoscaler --namespace kube-system 2>/dev/null || echo "cluster-autoscaler not found, skipping"

echo ""
echo "=== Waiting for LoadBalancers to be cleaned up ==="
# Give AWS time to deprovision LoadBalancers (prevents stuck deletion)
sleep 30

echo ""
echo "=== Cleaning Up Metrics Server ==="
# Delete EKS managed add-on
eksctl delete addon --cluster health-service-cluster-v2 --name metrics-server --region us-east-1 || true

echo ""
echo "=== Deleting EKS Cluster ==="
eksctl delete cluster -f "$SCRIPT_DIR/eks-cluster.yaml" --disable-nodegroup-eviction

echo ""
echo "✅ Cluster and all Helm releases deleted successfully!"
echo ""
echo "Optional cleanup:"
echo "  - ECR repository: aws ecr delete-repository --repository-name health-service --force"
echo "  - Route53 records: cd $PROJECT_ROOT/route53 && ./cleanup-hosted-zone.sh"
