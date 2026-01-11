# EKS Deployment - Fully Helm-Based

Complete EKS cluster deployment using Helm for all infrastructure and application components.

## What This Deploys

Everything via Helm:

1. **EKS Cluster** (via eksctl)
2. **Metrics Server** (EKS add-on for HPA)
3. **Cluster Autoscaler** (Helm chart - scales nodes 1-6)
4. **NGINX Ingress Controller** (Helm chart - scales pods 2-10)
5. **Health Service Application** (Helm chart - scales pods 1-10)

Replaces 660+ lines of manual YAML with Helm charts.

## Autoscaling Configuration

### Cluster Level (Nodes)
- Min: 1 node
- Max: 6 nodes
- Instance type: t3.small

### NGINX Controller (Pods)
- Min: 2 replicas
- Max: 10 replicas
- Target: 70% CPU

### Health Service (Pods)
- Min: 1 replica
- Max: 10 replicas
- Target: 70% CPU

## Prerequisites

- AWS CLI configured
- Docker installed
- eksctl installed
- kubectl installed
- Helm 3.x installed
- AWS credentials with EKS permissions

## Deployment

### Complete Stack Deployment

```bash
# Set required environment variables
export AWS_ACCOUNT_ID=your-account-id
export AWS_DEFAULT_REGION=us-east-1

# Deploy everything
./deploy-nginx.sh
```

This script:
1. Builds and pushes Docker image to ECR
2. Creates EKS cluster
3. Installs metrics server
4. Installs cluster autoscaler (Helm)
5. Installs NGINX ingress controller (Helm)
6. Deploys health-service application (Helm)
7. Configures Route53 DNS (if configured)

### For kind/Local Cluster

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f values-local.yaml
```

Uses NodePort (30080/30443) instead of LoadBalancer.

## Upgrade Components

### Upgrade NGINX
```bash
helm repo update
helm upgrade nginx-ingress ingress-nginx/ingress-nginx -n ingress-nginx
```

### Upgrade Application
```bash
# Build and push new image
docker build -t health-service:v2 .
docker tag health-service:v2 $ECR_REPO:v2
docker push $ECR_REPO:v2

# Upgrade Helm release
helm upgrade health-service ./health-service --set image.tag=v2
```

### Upgrade Cluster Autoscaler
```bash
helm upgrade cluster-autoscaler autoscaler/cluster-autoscaler -n kube-system
```

## Cleanup

### Automated Teardown

```bash
./teardown.sh
```

This script:
1. Uninstalls all Helm releases (health-service, nginx-ingress, cluster-autoscaler)
2. Waits for LoadBalancers to deprovision
3. Removes metrics-server add-on
4. Deletes the EKS cluster

### Manual Cleanup (if needed)

```bash
# Uninstall applications
helm uninstall health-service
helm uninstall nginx-ingress -n ingress-nginx
helm uninstall cluster-autoscaler -n kube-system

# Delete cluster
eksctl delete cluster -f eks-cluster.yaml
```

### Optional Additional Cleanup

```bash
# Delete ECR repository
aws ecr delete-repository --repository-name health-service --force --region us-east-1

# Clean up Route53 (if configured)
cd ../route53 && ./cleanup-hosted-zone.sh
```

## Verify Deployment

```bash
# Check all pods
kubectl get pods --all-namespaces

# Check HPAs
kubectl get hpa

# Check nodes
kubectl get nodes

# Get LoadBalancer URLs
kubectl get svc

# Test application
curl http://<loadbalancer-url>/health
```

## Customization

All components are configurable via Helm values:

```bash
# View NGINX options
helm show values ingress-nginx/ingress-nginx

# View autoscaler options
helm show values autoscaler/cluster-autoscaler

# Edit application config
vi health-service/values.yaml
```
