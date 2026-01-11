# Route 53 DNS Automation

Automates DNS management for EKS deployments so you don't have to manually update DNS every time you get a new NLB URL.

## Overview

**Problem:** Every EKS deployment creates a new NLB with a new hostname.
**Solution:** Automatically update Route 53 DNS to point to the new NLB.

**Cost:** $0.50/month for hosted zone + $0.40/million DNS queries

## One-Time Setup

### Step 1: Create Hosted Zone

```bash
cd route53
./setup-hosted-zone.sh
```

This will:
- Create Route 53 hosted zone for `codeseeker.dev`
- Output 4 AWS nameservers
- Save zone ID to `.env.route53`

### Step 2: Update Nameservers at Porkbun

1. Go to Porkbun dashboard
2. Find `codeseeker.dev` → "nameservers"
3. Replace Porkbun nameservers with AWS nameservers from Step 1
4. Save changes
5. Wait 5-10 minutes for DNS propagation

### Step 3: Verify

```bash
# Should show AWS nameservers
dig codeseeker.dev NS

# Should show AWS nameservers starting with ns-*.awsdns-*.com
```

## Usage

### Automatic (Integrated with deploy script)

The `deploy-eks.sh` script automatically updates DNS after deployment.

```bash
cd eks
./deploy-eks.sh

# DNS is automatically updated to point to new NLB
# Access at: http://api.codeseeker.dev/health
```

### Manual (Update DNS for existing cluster)

```bash
cd route53

# Update api.codeseeker.dev to point to current NLB
./update-dns.sh

# Or specify custom subdomain
./update-dns.sh staging  # Creates staging.codeseeker.dev
./update-dns.sh www      # Creates www.codeseeker.dev

# Or manually specify NLB hostname
./update-dns.sh api abc123.elb.us-east-1.amazonaws.com
```

## Cleanup

When you're done with Route 53:

```bash
cd route53
./cleanup-hosted-zone.sh
```

This will:
- Delete all DNS records
- Delete hosted zone
- Remove `.env.route53`

**Don't forget:** Switch Porkbun nameservers back to Porkbun defaults:
- `curitiba.ns.porkbun.com`
- `fortaleza.ns.porkbun.com`
- `maceio.ns.porkbun.com`
- `salvador.ns.porkbun.com`

## Files

- `setup-hosted-zone.sh` - One-time setup, creates hosted zone
- `update-dns.sh` - Update DNS record (called by deploy script)
- `cleanup-hosted-zone.sh` - Delete everything
- `.env.route53` - Stores zone ID (gitignored)
- `README.md` - This file

## Common Issues

**"Error: .env.route53 not found"**
- Run `./setup-hosted-zone.sh` first

**"Could not get NLB hostname"**
- Make sure EKS cluster is deployed
- Or manually specify: `./update-dns.sh api YOUR-NLB-URL`

**DNS not resolving after update**
- Wait 60 seconds (TTL)
- Check nameservers at Porkbun are set to AWS
- Verify: `dig api.codeseeker.dev`

## How It Works

1. **One-time:** Create Route 53 hosted zone
2. **One-time:** Point Porkbun nameservers to AWS
3. **Every deploy:** Script gets new NLB URL from kubectl
4. **Every deploy:** Script updates Route 53 CNAME record
5. **60 seconds later:** DNS propagates, domain points to new cluster

## Cost Breakdown

- **Hosted zone:** $0.50/month
- **DNS queries:** $0.40/million queries (first 1B queries)
- **Total for learning:** ~$0.50/month (queries are negligible)
