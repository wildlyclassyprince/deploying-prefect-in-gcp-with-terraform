# Load Balancer Troubleshooting Guide

## Issue: Cannot Access Prefect UI Through Load Balancer

If you can't access the Prefect UI at `https://production-prefect.domain.com` even though the infrastructure is deployed, follow this guide.

---

## Quick Diagnostics Checklist

Run these commands to diagnose the issue:

### 1. Check Load Balancer IP and DNS
```bash
# Get the load balancer IP from Terraform
cd envs/staging  # or envs/production
terraform output load_balancer_ip

# Verify DNS points to this IP
nslookup production-prefect.domain.com
# OR
dig production-prefect.domain.com

# The IP should match the load balancer IP
```

**Expected:** DNS resolves to the load balancer IP  
**If not:** Contact DevOps to update DNS A record

---

### 2. Check SSL Certificate Status
```bash
# Check if SSL certificate is provisioned and active
gcloud compute ssl-certificates list --filter="name:prefect"

# Look for:
# STATUS: ACTIVE (not PROVISIONING or FAILED)
```

**If PROVISIONING:** Wait 10-60 minutes for Google to provision it  
**If FAILED:** Check that:
- Domain DNS correctly points to load balancer IP
- Domain is accessible from the internet
- Certificate domain matches your actual domain exactly

---

### 3. Check Backend Health
```bash
# Check if backend instance is healthy
gcloud compute backend-services get-health ENVIRONMENT-prefect-server-backend-service --global

# Should show:
# healthStatus:
# - healthState: HEALTHY
```

**If UNHEALTHY:** Check:
- Prefect server is running: `gcloud compute ssh INSTANCE_NAME --command "sudo systemctl status prefect-server"`
- Health check endpoint works: `gcloud compute ssh INSTANCE_NAME --command "curl http://localhost:4200/api/health"`

---

### 4. Check Firewall Rules
```bash
# List all firewall rules affecting port 4200
gcloud compute firewall-rules list --filter="allowed.ports:4200 OR denied.ports:4200" --format="table(name,priority,direction,sourceRanges,allowed,denied,targetTags)"

# Should show:
# 1. allow-load-balancer-backend: priority 1000, ALLOW from 130.211.0.0/22, 35.191.0.0/16, 35.235.240.0/20
# 2. deny-direct-prefect-access: priority 1100, DENY from 0.0.0.0/0
```

**If priorities are wrong:**
- Allow rule MUST have priority < 1100 (preferably 1000)
- Deny rule MUST have priority > allow rule (preferably 1100)
- If wrong: Run `terraform apply` to fix

---

### 5. Test Load Balancer Directly
```bash
# Test HTTP (should redirect to HTTPS)
curl -v http://LOAD_BALANCER_IP

# Test HTTPS (will show certificate warning if using IP instead of domain)
curl -vk https://LOAD_BALANCER_IP

# Test with actual domain
curl -v https://production-prefect.domain.com
```

**Expected:** 
- HTTP redirects to HTTPS (301)
- HTTPS returns Prefect UI HTML or redirects

**If blocked:** Check Cloud Armor logs for denied requests

---

### 6. Check Cloud Armor Logs
```bash
# Check if requests are being blocked by Cloud Armor
gcloud logging read "resource.type=http_load_balancer AND jsonPayload.enforcedSecurityPolicy.outcome=\"DENY\"" \
  --limit=20 \
  --format="table(timestamp,httpRequest.requestUrl,httpRequest.remoteIp,jsonPayload.enforcedSecurityPolicy.configuredAction)"
```

**If seeing denials:** May need to adjust Cloud Armor rules

---

### 7. Check IAP Status (if enabled)
```bash
# Check if IAP is enabled and you're authorized
gcloud iap web get-iam-policy \
  --resource-type=backend-services \
  --service=ENVIRONMENT-prefect-server-backend-service

# Should show your email with role: roles/iap.httpsResourceAccessor
```

**If not listed:** You need to be added to `authorized_users` in terraform.tfvars

---

## Common Issues and Fixes

### Issue 1: "This site can't be reached" / DNS_PROBE_FINISHED_NXDOMAIN
**Cause:** DNS not configured or pointing to wrong IP  
**Fix:**
1. Get LB IP: `terraform output load_balancer_ip`
2. Contact DevOps to create/update DNS A record:
   - Name: `production-prefect` (subdomain)
   - Type: `A`
   - Value: `<LOAD_BALANCER_IP>`

---

### Issue 2: SSL Certificate Shows "Not Secure" or Certificate Error
**Cause:** SSL certificate not provisioned yet or domain mismatch  
**Fix:**
1. Check certificate status: `gcloud compute ssl-certificates list`
2. If PROVISIONING: Wait up to 60 minutes
3. If FAILED: Verify DNS points to correct IP and domain is publicly accessible
4. Check certificate domain matches exactly: Should be `production-prefect.domain.com`

---

### Issue 3: Load Balancer Returns 502 Bad Gateway
**Cause:** Backend instance is unhealthy or Prefect not running  
**Fix:**
```bash
# Check Prefect server status
gcloud compute ssh INSTANCE_NAME --command "sudo systemctl status prefect-server"

# If not running, check logs
gcloud compute ssh INSTANCE_NAME --command "sudo journalctl -u prefect-server -n 50"

# Check if Secret Manager password access is working
gcloud compute ssh INSTANCE_NAME --command "gcloud secrets versions access latest --secret=ENVIRONMENT-prefect-db-password"
```

---

### Issue 4: Load Balancer Returns 403 Forbidden
**Cause:** Cloud Armor blocking legitimate traffic  
**Fix:**
1. Check Cloud Armor logs (see section 6 above)
2. If your IP is being blocked, may need to whitelist it or adjust WAF rules
3. Temporarily disable Cloud Armor to test:
   ```bash
   # Remove security_policy line from backend service in loadbalancer.tf
   # Then: terraform apply
   ```

---

### Issue 5: "You don't have access" (IAP)
**Cause:** Not authorized in IAP  
**Fix:**
1. Add your email to `authorized_users` in `terraform.tfvars`:
   ```hcl
   authorized_users = ["your.email@company.com"]
   ```
2. Run: `terraform apply`
3. Wait 1-2 minutes for IAP to sync

---

### Issue 6: Connection Times Out
**Cause:** Firewall blocking traffic  
**Fix:**
1. Check firewall rule priorities (see section 4)
2. Ensure load balancer backend firewall rule has priority 1000
3. Ensure deny rule has priority 1100
4. Run: `terraform apply` to fix

---

## Step-by-Step Verification After Fix

1. **Apply the fix:**
   ```bash
   cd vm-with-load-balancer-and-iap-auth/envs/staging
   terraform apply
   ```

2. **Wait for SSL certificate (if new deployment):**
   ```bash
   watch -n 30 "gcloud compute ssl-certificates list --filter='name:prefect'"
   # Wait until STATUS = ACTIVE (can take 10-60 minutes)
   ```

3. **Verify backend health:**
   ```bash
   gcloud compute backend-services get-health ENVIRONMENT-prefect-server-backend-service --global
   ```

4. **Test access:**
   ```bash
   curl -v https://production-prefect.domain.com
   # Should return Prefect UI HTML
   ```

5. **Open in browser:**
   ```
   https://production-prefect.domain.com
   ```

---

## Getting Help

If none of these steps work, gather this information before asking for help:

```bash
# 1. Terraform outputs
terraform output

# 2. Backend health
gcloud compute backend-services get-health ENVIRONMENT-prefect-server-backend-service --global

# 3. SSL certificate status
gcloud compute ssl-certificates list --filter="name:prefect"

# 4. Firewall rules
gcloud compute firewall-rules list --filter="network:INSTANCE_NAME-vpc" --format="table(name,priority,sourceRanges,allowed,denied)"

# 5. Recent load balancer errors
gcloud logging read "resource.type=http_load_balancer AND severity>=ERROR" --limit=10

# 6. Prefect server status
gcloud compute ssh INSTANCE_NAME --command "sudo systemctl status prefect-server"
```

Provide all this output when asking for help.
