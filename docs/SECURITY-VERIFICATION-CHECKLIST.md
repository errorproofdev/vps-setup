# VPS Security Verification Checklist

**Status**: Manual verification required
**Date**: February 26, 2026
**Server**: node-steelgem

Run this checklist directly on the VPS to verify the deployment is secure against RCE and unauthorized access.

---

## 🔐 Quick Security Check

Copy and paste each command on the VPS:

```bash
# 1. Check SSH is hardened
echo "=== SSH HARDENING ==="
sudo grep "^PermitRootLogin" /etc/ssh/sshd_config
sudo grep "^PasswordAuthentication" /etc/ssh/sshd_config
echo ""

# 2. Check firewall is enabled
echo "=== UFW FIREWALL ==="
sudo ufw status
echo ""

# 3. Check exposed ports
echo "=== EXTERNAL LISTENING PORTS (should be 22, 80, 443 ONLY) ==="
sudo ss -tlnp 2>/dev/null | grep LISTEN | grep -v "127.0.0.1"
echo ""

# 4. Check app processes
echo "=== RUNNING APP PROCESSES (should be appuser, NOT root) ==="
ps aux | grep -E 'npm.*start|node' | grep -v grep
echo ""

# 5. Check app listener status
echo "=== APP TCP LISTENERS (should be 127.0.0.1 ONLY) ==="
netstat -tlnp 2>/dev/null | grep -E ':(3000|3001|3002)'
echo ""

# 6. Check appuser cannot escalate privileges
echo "=== RCE CONTAINMENT (appuser should NOT have these) ==="
echo "Can appuser read /etc/shadow?"
sudo -u appuser cat /etc/shadow 2>&1 | head -1
echo ""
echo "Can appuser use sudo?"
sudo -u appuser sudo -l 2>&1 | head -1
echo ""

# 7. Check PM2 is running
echo "=== PM2 PROCESS LIST ==="
sudo -u appuser bash -c 'source ~/.nvm/nvm.sh && pm2 list'
echo ""

# 8. Check NGINX
echo "=== NGINX STATUS ==="
sudo systemctl status nginx --no-pager | grep Active
sudo nginx -t
echo ""

# 9. Check SSL certs
echo "=== SSL CERTIFICATES ==="
ls -la /etc/ssl/detoxnearme/ /etc/ssl/edge/ /etc/ssl/forge/ 2>/dev/null | grep pem
echo ""

# 10. Check file permissions
echo "=== FILE PERMISSIONS ==="
echo "App directories (should be appuser:appuser):"
ls -ld /var/www/apps/* 2>/dev/null
echo ""
echo "PM2 directory (should be appuser:appuser):"
ls -ld /var/run/pm2 2>/dev/null
```

---

## ✅ Expected Results (Secure Configuration)

| Check | Expected | Status |
|-------|----------|--------|
| **PermitRootLogin** | `no` | ☐ |
| **PasswordAuthentication** | `no` | ☐ |
| **UFW Status** | `active` | ☐ |
| **External Ports** | 22, 80, 443 only | ☐ |
| **App Process Owner** | `appuser` (NOT root) | ☐ |
| **App Listeners** | 127.0.0.1:3000-3002 (localhost only) | ☐ |
| **appuser /etc/shadow** | `Permission denied` | ☐ |
| **appuser sudo access** | `not allowed` or `command not found` | ☐ |
| **PM2 processes** | detoxnearme, edge, forge running | ☐ |
| **NGINX status** | `active (running)` | ☐ |
| **NGINX syntax** | `test is successful` | ☐ |
| **SSL certs** | detoxnearme, edge, forge exist | ☐ |
| **App directory owner** | `appuser:appuser` | ☐ |

---

## 🚨 RCE Attack Simulation (DO NOT RUN IN PRODUCTION)

If you want to test the RCE containment in a safe way:

```bash
# Simulate finding a code injection vulnerability in the app
# (This would normally be exploited by an attacker)

# 1. Check if attacker (running as appuser) can:
echo "Can compromised app read database from /home/appuser/?"
ls -la /home/appuser/ | head -5

# 2. Can it read other apps' .env files?
echo "Can app read other apps' secrets?"
cat /var/www/apps/edge-nextjs/.env.local 2>&1 | head -1

# 3. Can it install backdoors?
echo "Can it install packages?"
sudo -u appuser apt-get update 2>&1 | head -1

# 4. Can it modify system files?
echo "Can it modify /etc/passwd?"
sudo -u appuser touch /etc/passwd 2>&1 | head -1

# Expected: All should show "Permission denied" or "not authorized"
```

---

## 📋 Security Hardening Status

### ✅ Implemented

- [x] SSH key-based authentication only (no passwords)
- [x] Root SSH login disabled
- [x] Apps run as **appuser** (non-root, unprivileged)
- [x] Apps listen on **localhost-only TCP** (not exposed)
- [x] UFW firewall restricts ports to 22/80/443 only
- [x] appuser has **no shell** (/usr/sbin/nologin)
- [x] appuser has **no sudo access**
- [x] NGINX reverse proxy acts as security boundary
- [x] SSL/TLS for all public traffic

### ⚠️ Still To Do

- [ ] Run manual security checks above
- [ ] Verify all results match ✅ column
- [ ] Test HTTPS connection to all three domains
- [ ] Enable UFW explicitly: `sudo ufw enable` (if not already)
- [ ] Set PM2 autostart: `sudo -u appuser pm2 save && sudo systemctl enable pm2-appuser`

---

## 🎯 Security Architecture Summary

```
External Attacker
       ↓
    Internet
       ↓
   Cloudflare (DDoS + WAF)
       ↓
   NGINX (TLS + Reverse Proxy)
       ↓
   Apps (localhost:3000-3002)
   ├─ Running as appuser
   ├─ No shell access
   ├─ No sudo
   ├─ Limited system access
       ↓
   RCE Impact (CONTAINED)
   ├─ Can't read /etc/shadow
   ├─ Can't modify system files
   ├─ Can't install packages
   ├─ Can't escalate to root
```

---

## 🔗 Related Documentation

- [SECURE-NON-ROOT-DEPLOYMENT.md](./SECURE-NON-ROOT-DEPLOYMENT.md) - Deployment guide
- [SECURITY-ROOT-VS-NONROOT.md](./SECURITY-ROOT-VS-NONROOT.md) - Security decisions
- [QUICK-REFERENCE-SECURITY.md](../QUICK-REFERENCE-SECURITY.md) - Quick reference

---

## Questions to Answer After Verification

1. **Are all apps running as appuser?**
   - Yes ☐ / No ☐

2. **Are apps listening on localhost only?**
   - Yes ☐ / No ☐

3. **Can UFW access be confirmed?**
   - Yes ☐ / No ☐

4. **Do SSL certificates exist for all domains?**
   - Yes ☐ / No ☐

5. **Is NGINX serving HTTPS correctly?**
   - Yes ☐ / No ☐

If all are "Yes", the VPS is **production-ready and hardened** ✅

---

## Support

If any checks fail:

1. Review the specific section above
2. Check logs: `sudo journalctl -u pm2-appuser -n 50`
3. Check PM2 logs: `sudo -u appuser pm2 logs`
4. Check NGINX: `sudo tail -50 /var/log/nginx/error.log`
