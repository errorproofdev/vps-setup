# Security Analysis: Root vs. Non-Root Deployment

**Status**: Critical security review
**Date**: February 26, 2026
**Impact**: Prevents Remote Code Execution (RCE) privilege escalation

---

## ❌ What's Wrong with Current configure.sh

The current `secured/configure.sh` (sections 16-18) violates fundamental security principles:

### Problem 1: Everything Runs as ROOT

```bash
# Section 16: NVM installed in root's home
export NVM_DIR="/root/.nvm"
nvm install "$NODE_VERSION"
# Result: NVM owned by root, all Node processes inherit root context
```

**Attack Scenario**:

```
Attacker finds RCE in Next.js app (e.g., template injection, prototype pollution)
    ↓
Exploits vulnerability to execute code
    ↓
Code runs as ROOT (not appuser)
    ↓
Has access to /root/.nvm, /etc/ssh, /root/.ssh
    ↓
Can steal SSH keys, install backdoors, compromise entire system
```

### Problem 2: PM2 Runs as systemd root Service

```bash
# Section 18: systemd service runs as root
[Service]
User=root  # ← PROBLEM: All PM2 processes inherit root privileges
WorkingDirectory=/root
ExecStart=/root/.nvm/versions/node/v20.19.5/bin/pm2 start ...
```

**Impact**:

- If one app crashes with RCE, attacker has **root shell**
- Can modify `/etc/passwd`, `/etc/sudoers`
- Can read database credentials from `/etc/` files
- Can access SSH private keys

### Problem 3: Apps Listen on TCP Ports (Exposed)

```bash
# Three apps listening on localhost TCP ports
pm2 start npm --name "detoxnearme" -- run start  # Listens on port 3000
pm2 start npm --name "edge" -- run start         # Listens on port 3001
pm2 start npm --name "forge" -- run start        # Listens on port 3002
```

**Risks**:

```
Attacker on same VPS (container escape, other guest VM)
    ↓
Connects directly to 127.0.0.1:3000 (no NGINX involved)
    ↓
Bypasses NGINX security headers, rate limiting
    ↓
Hits raw Node.js app with potential vulnerabilities
```

### Problem 4: All Apps Share Same UID

```
app1.com (port 3000)  ↓
app2.com (port 3001)  → All run as uid=0 (root)
app3.com (port 3002)  ↑

If app1 is compromised:
  - Can access app2's .env.local (database credentials)
  - Can kill/restart app3
  - Can extract app3's API keys
```

### Problem 5: No UFW Port Restrictions

```bash
# Current UFW only allows 22/80/443
ufw allow 80/tcp
ufw allow 443/tcp

# But apps LISTEN on 3000-3002 internally
# An attacker with internal access (container escape, etc) can:
ss -tlnp | grep 3000-3002  # See exposed ports
nc localhost 3000         # Connect directly
```

---

## ✅ Correct Approach: Non-Root with Unix Sockets

### Solution 1: Dedicated App User (Non-Root, No Shell)

```bash
# Create isolated user with no login shell
sudo useradd -r -m -s /usr/sbin/nologin appuser

# RCE consequences:
# - attacker gets appuser shell (but /usr/sbin/nologin blocks it anyway)
# - can't run sudo without password
# - can't install packages
# - can't modify system files
# - limited utilities available
```

**Attack Scenario (Mitigated)**:

```
Attacker exploits RCE in Next.js app
    ↓
Code runs as appuser (not root)
    ↓
try: $ sudo bash  → DENIED (not in sudoers)
try: $ cat /etc/shadow → DENIED (no read permission)
try: $ rm -rf /  → Can't delete system files outside /home/appuser
    ↓
Impact CONTAINED to appuser's context
```

### Solution 2: Unix Sockets (No Network Exposure)

```bash
# Before (BAD):
# Upstream uses TCP port
upstream detoxnearme {
    server 127.0.0.1:3000;  # ← Can be accessed via network
    keepalive 64;
}

# After (GOOD):
# Upstream uses Unix socket
upstream detoxnearme {
    server unix:/var/run/pm2/detoxnearme.sock;  # ← Filesystem only
    keepalive 64;
}
```

**Security Benefits**:

```
TCP Port 3000 (BAD):
  - Accessible from any process on system
  - Shows up in netstat output: LISTENING on 127.0.0.1:3000
  - Can be port-scanned, potential buffer overflow in Node.js code

Unix Socket (GOOD):
  - Only accessible via filesystem permissions
  - NGINX (www-data user) owns read-access via file permissions
  - Apps don't expose network interfaces at all
  - Port 3000 never opens (no netstat entry for app)
```

### Solution 3: Strict UFW Firewall Rules

```bash
# Only these ports allowed (incoming):
ufw allow 22/tcp     # SSH
ufw allow 80/tcp     # HTTP (NGINX only)
ufw allow 443/tcp    # HTTPS (NGINX only)

# Explicitly DENY app ports (defense in depth):
ufw deny 3000/tcp    # NO DIRECT ACCESS
ufw deny 3001/tcp    # NO DIRECT ACCESS
ufw deny 3002/tcp    # NO DIRECT ACCESS

# Attack attempt:
# Attacker inside VPS tries: curl http://127.0.0.1:3000
#   → BLOCKED by kernel / netstat shows port as CLOSED
```

### Solution 4: Process Isolation (Separate UIDs)

```javascript
// Option A: Single appuser for all apps (current recommendation)
// All 3 apps run as uid=1001 (appuser)
// - Lower overhead
// - Easier management
// - Inter-app attacks still possible (rare)

// Option B: Separate user per app (maximum isolation)
sudo useradd -r -m -s /usr/sbin/nologin app-detoxnearme
sudo useradd -r -m -s /usr/sbin/nologin app-edge
sudo useradd -r -m -s /usr/sbin/nologin app-forge

// Each runs with different uid, sockets have restrictive perms
// - Maximum isolation
// - Higher overhead
// - Can't share npm cache
// - Harder to manage

// RECOMMENDATION: Start with single appuser, upgrade if breached
```

### Solution 5: Disable Root SSH

```bash
# Original (INSECURE):
# /etc/ssh/sshd_config
PermitRootLogin yes        # ← Anyone with SSH key can become root

# After fix:
PermitRootLogin no         # ← Can't SSH as root directly

# Plus:
PasswordAuthentication no  # ← No passwords, only public keys
PubkeyAuthentication yes   # ← Only SSH keys allowed
```

**Attack Impact**:

```
Before:
  - Steal ubuntu's SSH key → SSH into system as ubuntu
  - SSH back in as root → Full system access

After:
  - Steal ubuntu's SSH key → SSH as ubuntu only
  - try: su root → Needs root password (not available)
  - try: sudo bash → Needs sudo access (ubuntu NOT in sudoers by default)
  - Contained to ubuntu user context
```

---

## 📊 Comparison Table

| Aspect | ❌ Root-Based | ✅ Non-Root (Secure) |
|--------|---|---|
| **Process User** | root (uid=0) | appuser (uid=1001) |
| **NVM Location** | /root/.nvm | /home/appuser/.nvm |
| **PM2 Service** | systemd as root | systemd as appuser |
| **App Ports** | localhost:3000-3002 (TCP) | /var/run/pm2/*.sock (Unix) |
| **Network Exposure** | 127.0.0.1:3000 visible to all processes | No TCP ports at all |
| **NGINX Connection** | TCP to localhost:3000 | Unix socket (filesystem) |
| **RCE Impact** | Attacker gets **root shell** | Attacker gets appuser (no shell) |
| **File Access** | Can read /etc/shadow, SSH keys | Limited to /home/appuser, /var/www |
| **SSH Login** | Possible as root | Denied (PermitRootLogin no) |
| **Process Isolation** | All apps = root uid | All apps = appuser uid |
| **UFW Rules** | Only 22/80/443 | 22/80/443 + DENY 3000-3002 |

---

## 🛠️ Migration Path

### Phase 1: Prepare (No Downtime)

```bash
# 1. Create appuser, directories, install Node.js
# 2. Deploy ecosystem.config.secure.js
# 3. Configure NGINX with Unix socket config (but don't enable)
# 4. Update UFW rules (add, don't remove)
```

### Phase 2: Test (Parallel Running)

```bash
# 5. Start PM2 as appuser:
sudo -u appuser pm2 start /home/appuser/ecosystem.config.js

# 6. Switch NGINX upstream to new sockets (test server block first):
# upstream detoxnearme {
#     server unix:/var/run/pm2/detoxnearme.sock;
# }

# 7. Test via curl on test server block
# nginx -t && systemctl reload nginx
```

### Phase 3: Cutover (Minimal Downtime)

```bash
# 8. Switch production server blocks to Unix sockets
# 9. Reload NGINX
# 10. Stop old root PM2 processes:
sudo pm2 kill  # Stop root-based PM2

# 11. Verify apps still running:
curl -I https://detoxnearme.com
```

### Phase 4: Hardening (Post-Migration)

```bash
# 12. Disable root SSH
# 13. Remove root's shell access
# 14. Monitor for any issues (1-2 weeks)
# 15. Document runbook for operations team
```

---

## 🔒 Defense In Depth

| Layer | Security Control | Purpose |
|-------|---|---|
| **1. SSH** | Public keys only, no root | Prevent unauthorized access |
| **2. Firewall (UFW)** | Only 22/80/443 | Block direct app port access |
| **3. Process User** | appuser non-root | Limit RCE privilege escalation |
| **4. Unix Sockets** | Filesystem-based, no TCP | Prevent network access to apps |
| **5. Permissions** | appuser:appuser 644 sockets | Applications can't read each other's sockets |
| **6. Logging** | Centralized PM2 logs | Detect suspicious activity |
| **7. Monitoring** | PM2 health checks | Alert on app crashes/restarts |
| **8. Backups** | Encrypted, offsite (Kopia) | Recovery from ransomware |

---

## 📚 Files Created/Updated

| File | Purpose | Security Impact |
|------|---------|---|
| `ecosystem.config.secure.js` | PM2 config with Unix sockets | Eliminates TCP port exposure |
| `NGINX-UNIX-SOCKET.conf` | NGINX reverse proxy to sockets | Filesystem-based proxying |
| `SECURE-NON-ROOT-DEPLOYMENT.md` | Step-by-step deployment guide | Operational security |
| `secured/configure.sh` | **NEEDS REWRITE** | Remove root-based NVM/PM2 sections |

---

## ✅ Action Items

- [ ] Review `ecosystem.config.secure.js` with security engineer
- [ ] Test in staging environment first (stg-steelgem)
- [ ] Document runbook for operations team
- [ ] Schedule migration (off-peak hours)
- [ ] Have rollback plan (keep old root PM2 config backup)
- [ ] Monitor logs during migration
- [ ] Disable root SSH only after 1-2 weeks of stable operation
- [ ] Update monitoring/alerting for new appuser processes

---

## 🚨 Quick Reference

**Never do:**

```bash
sudo ./scripts/vps-setup.sh     # If it runs sections as root
sudo nvm install v20.19.5       # NVM should be per-user
sudo pm2 start ...              # PM2 should run as appuser
ROOT_USER=true ./deploy.sh      # No environment variable to run as root
```

**Always do:**

```bash
# Become appuser (with shell for setup only)
sudo -u appuser bash -c '. ~/.nvm/nvm.sh && npm install -g pm2'

# Run PM2 as appuser
sudo -u appuser pm2 start /home/appuser/ecosystem.config.js

# Verify appuser ownership
ls -la /var/www/apps/ /var/run/pm2/ /var/log/pm2/

# Check processes run as appuser
ps aux | grep appuser | grep node
```
