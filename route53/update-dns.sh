#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load zone ID from setup
if [ ! -f "$SCRIPT_DIR/.env.route53" ]; then
  echo "Error: .env.route53 not found. Run setup-hosted-zone.sh first"
  exit 1
fi

source "$SCRIPT_DIR/.env.route53"

# Get subdomain from args or use default
SUBDOMAIN="${1:-api}"
FULL_DOMAIN="$SUBDOMAIN.$DOMAIN"

# Get NLB hostname from argument or kubectl
if [ -n "$2" ]; then
  NLB_HOSTNAME="$2"
else
  echo "Getting NLB hostname from kubectl..."
  NLB_HOSTNAME=$(kubectl get svc health-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

  if [ -z "$NLB_HOSTNAME" ]; then
    echo "Error: Could not get NLB hostname. Is the service deployed?"
    exit 1
  fi
fi

echo "=== Updating DNS Record ==="
echo "Domain: $FULL_DOMAIN"
echo "Target: $NLB_HOSTNAME"
echo ""

# Create change batch JSON
CHANGE_BATCH=$(cat <<EOF
{
  "Comment": "Update DNS for EKS deployment",
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "$FULL_DOMAIN",
      "Type": "CNAME",
      "TTL": 60,
      "ResourceRecords": [{"Value": "$NLB_HOSTNAME"}]
    }
  }]
}
EOF
)

# Update DNS
CHANGE_ID=$(aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch "$CHANGE_BATCH" \
  --query 'ChangeInfo.Id' \
  --output text)

echo "✅ DNS update submitted (Change ID: $CHANGE_ID)"
echo ""
echo "Waiting for change to propagate..."

# Wait for change to complete (usually < 60 seconds)
aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"

echo ""
echo "✅ DNS propagated successfully!"
echo ""
echo "Your service is now available at:"
echo "  http://$FULL_DOMAIN/health"
echo ""
echo "Test with: curl http://$FULL_DOMAIN/health"
