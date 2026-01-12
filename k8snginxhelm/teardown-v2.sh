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

# Clean up cert-manager resources, then uninstall cert-manager
echo "Cleaning up cert-manager custom resources (CRs)..."
kubectl delete certificate --all -A 2>/dev/null || true
kubectl delete certificaterequest --all -A 2>/dev/null || true
kubectl delete order --all -A 2>/dev/null || true
kubectl delete challenge --all -A 2>/dev/null || true
kubectl delete issuer --all -A 2>/dev/null || true
kubectl delete clusterissuer --all -A 2>/dev/null || true

echo "Removing cert-manager Helm release..."
helm uninstall cert-manager --namespace cert-manager 2>/dev/null || echo "cert-manager not found, skipping"

# Optional: remove cert-manager CRDs (good for ephemeral/dev clusters)
echo "Removing cert-manager CRDs (if present)..."
kubectl delete crd certificaterequests.cert-manager.io \
  certificates.cert-manager.io \
  challenges.acme.cert-manager.io \
  orders.acme.cert-manager.io \
  issuers.cert-manager.io \
  clusterissuers.cert-manager.io 2>/dev/null || true

# Uninstall cluster autoscaler
echo "Removing cluster-autoscaler..."
helm uninstall cluster-autoscaler --namespace kube-system 2>/dev/null || echo "cluster-autoscaler not found, skipping"

echo ""
echo "=== Waiting for Kubernetes Services to be deleted ==="
# First check if any LoadBalancer services still exist in Kubernetes
MAX_WAIT=180  # 3 minutes max
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  LB_SERVICES=$(kubectl get svc --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace)/\(.metadata.name)"' | wc -l || echo "999")

  if [ "$LB_SERVICES" -eq 0 ]; then
    echo "✅ All Kubernetes LoadBalancer Services deleted"
    break
  fi

  if [ $ELAPSED -eq 0 ]; then
    echo "Found $LB_SERVICES LoadBalancer Service(s) still deleting..."
  fi

  sleep 10
  ELAPSED=$((ELAPSED + 10))
done

if [ "$LB_SERVICES" -ne 0 ]; then
  echo "⚠️  Services still exist after ${ELAPSED}s, checking AWS resources..."
fi

echo ""
echo "=== Waiting for AWS LoadBalancers to be cleaned up ==="
# Now verify AWS LoadBalancers are actually gone
MAX_WAIT=300  # 5 minutes max
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  # Get VPC ID from cluster
  VPC_ID=$(aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:alpha.eksctl.io/cluster-name,Values=health-service-cluster-v3" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

  if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
    echo "✅ VPC already deleted or not found"
    break
  fi

  # Count LoadBalancers in the VPC
  LB_COUNT=$(aws elbv2 describe-load-balancers --region us-east-1 2>/dev/null | jq -r --arg vpc "$VPC_ID" '.LoadBalancers[] | select(.VpcId==$vpc) | .LoadBalancerArn' | wc -l || echo "999")

  if [ "$LB_COUNT" -eq 0 ]; then
    echo "✅ All AWS LoadBalancers deleted from VPC"
    break
  fi

  if [ $ELAPSED -eq 0 ]; then
    echo "Found $LB_COUNT LoadBalancer(s) in VPC $VPC_ID"
  fi

  echo "⏳ Still deleting $LB_COUNT LoadBalancer(s)... (${ELAPSED}s elapsed)"
  sleep 15
  ELAPSED=$((ELAPSED + 15))
done

if [ "$LB_COUNT" -ne 0 ] && [ "$VPC_ID" != "None" ]; then
  echo "⚠️  Timeout waiting for LoadBalancers. They may still be deleting..."
  echo "    This might cause CloudFormation deletion to fail."
fi

echo ""
echo "=== Cleaning Up Metrics Server ==="
# Delete EKS managed add-on
eksctl delete addon --cluster health-service-cluster-v3 --name metrics-server --region us-east-1 || true

echo ""
echo "=== Deleting EKS Cluster ==="
# Removed --disable-nodegroup-eviction to allow proper cleanup of pods and dependencies
eksctl delete cluster -f "$SCRIPT_DIR/eks-cluster.yaml" --wait

echo ""
echo "✅ Cluster and all Helm releases deleted successfully!"
echo ""
echo "Optional cleanup:"
echo "  - ECR repository: aws ecr delete-repository --repository-name health-service --force"
echo "  - Route53 records: cd $PROJECT_ROOT/route53 && ./cleanup-hosted-zone.sh"

