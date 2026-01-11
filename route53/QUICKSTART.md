# Quick Start: Automated DNS for EKS

## Step 1: Run Setup (One-Time, 5 minutes)

```bash
cd route53
./setup-hosted-zone.sh
```

**Output:**
```
✅ Hosted Zone Created!
Zone ID: Z1234567890ABC

=== IMPORTANT: Update these nameservers at Porkbun ===
ns-123.awsdns-12.com
ns-456.awsdns-34.net
ns-789.awsdns-56.org
ns-012.awsdns-78.co.uk
```

## Step 2: Update Porkbun (One-Time, 2 minutes)

1. Go to https://porkbun.com/account/domainsSpeedy
2. Click on `codeseeker.dev`
3. Scroll to "nameservers"
4. Click "Edit"
5. Replace the 4 Porkbun nameservers with the 4 AWS nameservers above
6. Save

**Wait 5-10 minutes for propagation.**

## Step 3: Verify Setup (One-Time)

```bash
# Check nameservers (should show AWS)
dig codeseeker.dev NS

# Should see:
# codeseeker.dev.  172800  IN  NS  ns-123.awsdns-12.com.
# codeseeker.dev.  172800  IN  NS  ns-456.awsdns-34.net.
# ... etc
```

## Step 4: Deploy EKS (Automatic DNS!)

```bash
cd ../eks
./deploy-eks.sh
```

**What happens:**
1. Cluster deploys
2. NLB is created
3. Script automatically updates DNS
4. After 60 seconds: `http://api.codeseeker.dev/health` works!

**Output:**
```
=== LoadBalancer URL ===
abc123-xyz789.elb.us-east-1.amazonaws.com

=== Updating DNS ===
Domain: api.codeseeker.dev
Target: abc123-xyz789.elb.us-east-1.amazonaws.com

✅ DNS propagated successfully!

Your service is now available at:
  http://api.codeseeker.dev/health
```

## Testing

```bash
# Wait 60 seconds after deployment, then:
curl http://api.codeseeker.dev/health

# Should return:
# {
#   "status": "ok",
#   "timestamp": "2026-01-10T...",
#   "cpu_percent": 2.5,
#   "memory_mb": 167.45,
#   "memory_percent": 15.2
# }
```

## Daily Workflow

**From now on, just:**

```bash
# Teardown old cluster
./eks/teardown-eks.sh

# Deploy new cluster (DNS auto-updates!)
./eks/deploy-eks.sh

# Access at same URL
curl http://api.codeseeker.dev/health
```

**No manual DNS updates needed!** 🎉

## Update k6 Tests

Update your load test to use the domain:

```javascript
// k6/maxrequests.js
export default function () {
  const res = http.get('http://api.codeseeker.dev/health');
  // ...
}
```

Now your load tests work even after redeployment!

## Cost

- Route 53 Hosted Zone: **$0.50/month**
- DNS Queries: **~$0.01/month** (negligible for testing)
- **Total: $0.51/month**

Worth it to save 10 minutes per deployment! ✅
