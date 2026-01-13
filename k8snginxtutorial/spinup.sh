#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# kind delete cluster --name devops-lab 2>/dev/null || true
# kind create cluster --name devops-lab --config "$SCRIPT_DIR/kind/kind-config.yaml"
#
# cd "$PROJECT_ROOT"
# docker build -t health-service:local .
# kind load docker-image health-service:local --name devops-lab
#
# kubectl apply -f "$SCRIPT_DIR/ingress-controller.yaml"
# kubectl wait --namespace ingress-nginx \
#   --for=condition=ready pod \
#   --selector=app.kubernetes.io/component=controller \
#   --timeout=90s

echo "=== Installing Metrics Server via Helm ==="
# Metrics Server is required for HPA (Horizontal Pod Autoscaler) to work
# It collects resource metrics (CPU/memory) from kubelets and exposes them via Metrics API
# HPA uses these metrics to make scaling decisions
#
# Special args for kind/local clusters:
#   --kubelet-insecure-tls: Skip TLS verification (kind uses self-signed certs)
#   --kubelet-preferred-address-types: Use InternalIP instead of hostname
# In production (EKS/GKE), you can omit these args for proper TLS
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args[0]="--kubelet-insecure-tls" \
  --set args[1]="--kubelet-preferred-address-types=InternalIP"

echo "Waiting for metrics-server to be ready..."
kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=metrics-server \
  --timeout=90s || {
  echo "⚠️  Metrics-server taking longer than expected, checking status..."
  kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server
}
echo ""

kubectl apply -f "$SCRIPT_DIR/"
kubectl wait --for=condition=ready pod --selector=app=health-service --timeout=60s

kubectl get pods
kubectl get svc
kubectl get ingress
kubectl get hpa

sleep 3
curl http://localhost/health
