# Debug & Operations Guide

Quick reference for common tasks and debugging.

## Update Application

```bash
# Build and push new image
docker build -t health-service:v2 .
docker tag health-service:v2 $ECR_REPO:v2
docker push $ECR_REPO:v2

# Upgrade Helm release
helm upgrade health-service ./health-service --set image.tag=v2

# Force pod restart (if image tag unchanged)
kubectl rollout restart deployment health-service
```

## Check Status

```bash
# All resources
kubectl get pods,svc,hpa,ingress

# Pod details
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Why pod is pending
kubectl describe pod <pod-name> | grep -A 10 Events

# Node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"
```

## SSL/HTTPS Debugging

```bash
# Check certificate status
kubectl get certificate
kubectl describe certificate health-service-tls

# cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50

# Test HTTPS (verbose)
curl -v https://api.codeseeker.dev/health

# Check Let's Encrypt challenges
kubectl get challenges
```

## Autoscaling

```bash
# Check HPA status
kubectl get hpa
kubectl describe hpa health-service-hpa

# Check cluster autoscaler logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler --tail=50

# Check metrics server
kubectl top nodes
kubectl top pods
```

## NGINX Ingress

```bash
# Get LoadBalancer URL
kubectl get svc nginx-ingress-ingress-nginx-controller -n ingress-nginx

# NGINX controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50

# Check ingress routing
kubectl get ingress
kubectl describe ingress health-service
```

## Helm Operations

```bash
# List releases
helm list --all-namespaces

# Upgrade with new values
helm upgrade <release> <chart> --set key=value

# Rollback
helm rollback <release> <revision>

# Show values
helm get values <release>

# Uninstall
helm uninstall <release> -n <namespace>
```

## DNS/Route53

```bash
# Update DNS manually
source route53/.env.route53
route53/update-dns.sh api <loadbalancer-hostname>

# Check current DNS
dig api.codeseeker.dev
nslookup api.codeseeker.dev
```

## Quick Fixes

```bash
# Pod stuck pending → Check node capacity and autoscaler logs
kubectl describe pod <pod> | grep -A 10 Events
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler --tail=20

# HTTPS not working → Check certificate
kubectl get certificate
kubectl describe certificate health-service-tls

# Uneven load distribution → Verify using NGINX ingress, not direct LoadBalancer
kubectl get svc health-service  # Should be ClusterIP, not LoadBalancer
kubectl get ingress  # Should exist and route traffic

# Can't pull image → Check ECR permissions
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

## Cleanup

```bash
# Delete specific resources
kubectl delete pod <pod-name>
kubectl delete deployment <deployment-name>

# Full teardown
./teardown.sh
```
