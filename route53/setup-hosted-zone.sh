#!/bin/bash
set -e

DOMAIN="codeseeker.dev"

echo "=== Setting up Route 53 Hosted Zone for $DOMAIN ==="

# Check if hosted zone already exists
EXISTING_ZONE=$(aws route53 list-hosted-zones-by-name \
  --dns-name $DOMAIN \
  --query "HostedZones[?Name=='$DOMAIN.'].Id" \
  --output text | head -1)

if [ -n "$EXISTING_ZONE" ]; then
  # Zone exists, use it
  ZONE_ID=$(echo $EXISTING_ZONE | sed 's/\/hostedzone\///')
  echo "✅ Hosted zone already exists!"
  echo "Zone ID: $ZONE_ID"
  echo ""

  # Get existing nameservers
  NAMESERVERS=$(aws route53 get-hosted-zone \
    --id $ZONE_ID \
    --query 'DelegationSet.NameServers' \
    --output json)

  ZONE_OUTPUT=$(jq -n \
    --arg zid "/hostedzone/$ZONE_ID" \
    --argjson ns "$NAMESERVERS" \
    '{ZoneId: $zid, NameServers: $ns}')
else
  # Create new hosted zone
  echo "Creating new hosted zone..."
  ZONE_OUTPUT=$(aws route53 create-hosted-zone \
    --name $DOMAIN \
    --caller-reference $(date +%s) \
    --region us-east-1 \
    --query '{ZoneId:HostedZone.Id,NameServers:DelegationSet.NameServers}' \
    --output json)

  # Extract zone ID (remove /hostedzone/ prefix)
  ZONE_ID=$(echo $ZONE_OUTPUT | jq -r '.ZoneId' | sed 's/\/hostedzone\///')
  echo "✅ Hosted zone created!"
  echo "Zone ID: $ZONE_ID"
  echo ""
fi

# Display nameservers
echo "=== IMPORTANT: Update these nameservers at Porkbun ==="
echo $ZONE_OUTPUT | jq -r '.NameServers[]'
echo ""

# Save zone ID for other scripts
echo "HOSTED_ZONE_ID=$ZONE_ID" > .env.route53
echo "DOMAIN=$DOMAIN" >> .env.route53

echo "Saved zone ID to .env.route53"
echo ""
echo "Next steps:"
echo "1. Go to Porkbun dashboard"
echo "2. Find 'nameservers' section for $DOMAIN"
echo "3. Replace Porkbun nameservers with AWS nameservers above"
echo "4. Wait 5-10 minutes for DNS propagation"
echo "5. Verify with: dig $DOMAIN NS"
