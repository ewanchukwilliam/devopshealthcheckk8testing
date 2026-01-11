# Health Service Helm Chart

Helm chart for deploying the health-service application with autoscaling and SSL support.

## What's Included

- **Deployment**: Application pods with readiness/liveness probes
- **Service**: LoadBalancer with optional SSL/TLS (AWS NLB)
- **HPA**: Horizontal Pod Autoscaler (1-10 pods, CPU-based)

## Installation

```bash
# Install with default values
helm install health-service ./health-service

# Install with custom image
helm install health-service ./health-service \
  --set image.repository=your-ecr-repo \
  --set image.tag=v1.0.0

# Install without SSL
helm install health-service ./health-service \
  --set service.ssl.enabled=false
```

## Configuration

Key values in `values.yaml`:

### Image
```yaml
image:
  repository: your-ecr-repo
  tag: latest
  pullPolicy: Always
```

### SSL/TLS
```yaml
service:
  ssl:
    enabled: true
    certificateArn: "arn:aws:acm:..."
    policy: "ELBSecurityPolicy-TLS-1-2-2017-01"
```

### Autoscaling
```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### Resources
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "500m"
  limits:
    memory: "512Mi"
    cpu: "1000m"
```

## Upgrade

```bash
# Upgrade with new image tag
helm upgrade health-service ./health-service \
  --set image.tag=v1.1.0

# Upgrade with new SSL certificate
helm upgrade health-service ./health-service \
  --set service.ssl.certificateArn="arn:aws:acm:..."
```

## Uninstall

```bash
helm uninstall health-service
```

## Verify

```bash
# Check deployment
kubectl get deployments health-service

# Check HPA
kubectl get hpa health-service-hpa

# Get LoadBalancer URL
kubectl get svc health-service
```
