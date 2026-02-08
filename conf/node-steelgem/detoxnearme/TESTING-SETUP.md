# Testing Configuration - dev.detoxnearme.com

**Environment**: Development/Testing
**Domain**: dev.detoxnearme.com
**Purpose**: Testing deployment before production rollout
**Status**: ✅ Active

---

## 🧪 Current Setup

### What's Configured

- **Development Domain**: `dev.detoxnearme.com`
- **Production Domain**: `detoxnearme.com` (DISABLED - not in sites-enabled)
- **Application Port**: 3001 (same app serves both dev and prod)
- **PM2 Process**: `detoxnearme` (fork mode)

### Active NGINX Sites

```
Enabled:
✅ dev.detoxnearme.com.conf      → Testing environment
✅ www.theedgetreatment.com.conf → Other site (port 3000)

Available but Disabled:
⏸️  detoxnearme.com.conf         → Production (ready for activation)
```

---

## 🔗 URLs

### Development (Active)

- ✅ `https://dev.detoxnearme.com` - Testing environment
- ✅ `http://dev.detoxnearme.com` - Redirects to HTTPS

### Production (Disabled)

- ⏸️ `https://detoxnearme.com` - Will activate when ready
- ⏸️ `https://www.detoxnearme.com` - Will redirect to root domain

---

## 🚀 When Ready for Production

### Step 1: Enable Production Site

```bash
# Enable production site
ssh node-steelgem "sudo ln -sf /etc/nginx/sites-available/detoxnearme.com.conf /etc/nginx/sites-enabled/detoxnearme.com.conf"

# Test configuration
ssh node-steelgem "sudo nginx -t"

# Reload NGINX
ssh node-steelgem "sudo systemctl reload nginx"
```

### Step 2: Verify Both Sites Work

```bash
# Test dev
curl -I https://dev.detoxnearme.com

# Test production
curl -I https://detoxnearme.com

# Test www redirect
curl -I https://www.detoxnearme.com
```

### Step 3: Optional - Disable Dev Site

```bash
# If you want to disable dev after production is live
ssh node-steelgem "sudo rm /etc/nginx/sites-enabled/dev.detoxnearme.com.conf"
ssh node-steelgem "sudo systemctl reload nginx"
```

---

## 🔐 SSL Certificate Note

### SSL Stapling Warning (Safe to Ignore)

You'll see this warning:

```
nginx: [warn] "ssl_stapling" ignored, issuer certificate not found for certificate "/etc/ssl/detoxnearme/cert.pem"
```

**Why it happens:**

- OCSP stapling requires the full certificate chain (your cert + intermediate CA)
- Your `cert.pem` only contains the end certificate
- This is a performance optimization, not a security issue

**Impact:**

- ✅ SSL/TLS works perfectly
- ✅ Site is secure
- ⚠️ Slight performance impact (clients check certificate revocation themselves)

**To fix (optional):**
Create a full chain certificate:

```bash
# Concatenate your certificate with the CA's intermediate certificate
cat your-cert.pem intermediate-ca.pem > fullchain.pem

# Update NGINX to use fullchain
ssl_certificate /etc/ssl/detoxnearme/fullchain.pem;
```

### Current SSL Configuration

Both dev and production use the same certificates:

- **Certificate**: `/etc/ssl/detoxnearme/cert.pem`
- **Private Key**: `/etc/ssl/detoxnearme/key.pem`
- **Source**: `conf/node-steelgem/detoxnearme/nginx/`

---

## 📊 Testing Checklist

Before enabling production, verify on dev.detoxnearme.com:

- [ ] Home page loads correctly
- [ ] All static assets load (images, CSS, JS)
- [ ] API routes work (`/api/*`)
- [ ] Search functionality works
- [ ] Forms submit correctly
- [ ] Maps/geolocation features work
- [ ] SSL certificate is valid (check browser)
- [ ] Mobile responsiveness
- [ ] Performance is acceptable
- [ ] No console errors
- [ ] Analytics/tracking works
- [ ] External integrations work (Formspree, Google Maps, etc.)

### Testing Commands

```bash
# Check application logs
ssh node-steelgem "pm2 logs detoxnearme --lines 50"

# Check NGINX logs
ssh node-steelgem "sudo tail -f /var/log/nginx/dev.detoxnearme.com.access.log"
ssh node-steelgem "sudo tail -f /var/log/nginx/dev.detoxnearme.com.error.log"

# Check application health
curl -I https://dev.detoxnearme.com

# Test API endpoint
curl https://dev.detoxnearme.com/api/health

# Check SSL certificate
echo | openssl s_client -connect dev.detoxnearme.com:443 -servername dev.detoxnearme.com 2>/dev/null | openssl x509 -noout -dates
```

---

## 🔄 Rollback Plan

If issues are found:

### Option 1: Fix on Dev

- Keep testing on dev.detoxnearme.com
- Don't enable production yet
- Fix issues and re-test

### Option 2: Disable Everything

```bash
# Stop PM2 process
ssh node-steelgem "pm2 stop detoxnearme"

# Disable dev site
ssh node-steelgem "sudo rm /etc/nginx/sites-enabled/dev.detoxnearme.com.conf"
ssh node-steelgem "sudo systemctl reload nginx"
```

### Option 3: Revert Application

```bash
# If you need to revert code changes
ssh node-steelgem "cd /home/ubuntu/detoxnearme.com/gitlab && git reset --hard [commit-hash]"
ssh node-steelgem "pm2 restart detoxnearme"
```

---

## 📝 Configuration Files

### Development

- **Local**: `conf/node-steelgem/detoxnearme/nginx/dev.detoxnearme.com.conf`
- **Server**: `/etc/nginx/sites-available/dev.detoxnearme.com.conf`
- **Enabled**: `/etc/nginx/sites-enabled/dev.detoxnearme.com.conf` ✅

### Production (Ready but Disabled)

- **Local**: `conf/node-steelgem/detoxnearme/nginx/detoxnearme.com.conf`
- **Server**: `/etc/nginx/sites-available/detoxnearme.com.conf`
- **Enabled**: Not linked (disabled) ⏸️

---

## 🎯 Next Steps

1. **Test thoroughly on dev.detoxnearme.com**
2. **Monitor logs for any issues**
3. **Verify all functionality works**
4. **When satisfied, enable production site**
5. **Monitor production closely after launch**

---

**Environment**: Development/Testing
**Last Updated**: February 8, 2026
**Status**: Ready for testing
