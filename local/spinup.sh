#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

kind delete cluster --name devops-lab 2>/dev/null || true
kind create cluster --name devops-lab --config "$SCRIPT_DIR/kind/kind-config.yaml"

cd "$PROJECT_ROOT"
docker build -t health-service:local .
kind load docker-image health-service:local --name devops-lab

echo "=== Installing Metrics Server via Helm ==="
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install metrics-server metrics-server/metrics-server \
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

# Apply everything except ingress first
kubectl apply -f "$SCRIPT_DIR/deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/deployment-redis.yaml"
kubectl apply -f "$SCRIPT_DIR/service-clusterip.yaml"
kubectl apply -f "$SCRIPT_DIR/service-redis.yaml"
kubectl apply -f "$SCRIPT_DIR/hpa.yaml"
kubectl apply -f "$SCRIPT_DIR/ingress-controller.yaml"

# Wait for ingress controller to be ready before applying ingress
echo "Waiting for ingress controller deployment to roll out..."
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=180s

# Wait for admission webhook jobs to complete
echo "Waiting for admission webhook jobs to complete..."
kubectl wait --namespace ingress-nginx \
  --for=condition=complete job/ingress-nginx-admission-create \
  --timeout=90s || true
kubectl wait --namespace ingress-nginx \
  --for=condition=complete job/ingress-nginx-admission-patch \
  --timeout=90s || true

# Give webhook service time to be fully ready
echo "Waiting for webhook service to be ready..."
sleep 15

# Now apply the ingress
kubectl apply -f "$SCRIPT_DIR/ingress.yaml"

kubectl wait --for=condition=ready pod --selector=app=health-service --timeout=60s

kubectl get pods
kubectl get svc
kubectl get ingress
kubectl get hpa

sleep 3
curl http://localhost/health
