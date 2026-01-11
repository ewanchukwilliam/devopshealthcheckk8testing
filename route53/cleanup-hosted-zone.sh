#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load zone ID
if [ ! -f "$SCRIPT_DIR/.env.route53" ]; then
  echo "Error: .env.route53 not found. Nothing to clean up."
  exit 1
fi

source "$SCRIPT_DIR/.env.route53"

echo "=== Cleaning up Route 53 Hosted Zone ==="
echo "Domain: $DOMAIN"
echo "Zone ID: $HOSTED_ZONE_ID"
echo ""

# List all records (except NS and SOA which can't be deleted)
echo "Deleting DNS records..."
RECORDS=$(aws route53 list-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --query "ResourceRecordSets[?Type != 'NS' && Type != 'SOA']" \
  --output json)

# Delete each record
if [ "$(echo $RECORDS | jq length)" -gt 0 ]; then
  echo $RECORDS | jq -c '.[]' | while read record; do
    NAME=$(echo $record | jq -r '.Name')
    TYPE=$(echo $record | jq -r '.Type')
    echo "Deleting $TYPE record: $NAME"

    CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [{
    "Action": "DELETE",
    "ResourceRecordSet": $record
  }]
}
EOF
)

    aws route53 change-resource-record-sets \
      --hosted-zone-id $HOSTED_ZONE_ID \
      --change-batch "$CHANGE_BATCH" > /dev/null
  done
fi

echo ""
echo "Deleting hosted zone..."
aws route53 delete-hosted-zone --id $HOSTED_ZONE_ID

echo ""
echo "✅ Hosted zone deleted!"
echo ""
echo "Remember to switch your Porkbun nameservers back to:"
echo "  curitiba.ns.porkbun.com"
echo "  fortaleza.ns.porkbun.com"
echo "  maceio.ns.porkbun.com"
echo "  salvador.ns.porkbun.com"

rm "$SCRIPT_DIR/.env.route53"
