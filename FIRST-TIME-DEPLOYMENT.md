# First-Time VPS Deployment Checklist

> ⚠️ **Note:** the deployment workflow has moved to the `secured/`
> subdirectory.  `secured/configure.sh` and the accompanying files are the
> authoritative, up‑to‑date scripts for new VPSs.  The older helpers in
> `scripts/` are now archived and should not be used except for historical
> reference.

**Status**: For fresh VPS deployment
**Date**: February 26, 2026
**Security Level**: Hardened (non-root apps, Unix sockets)

---

## 📋 Pre-Deployment (Local Machine)

- [ ] Review security documentation
  - [ ] `docs/SECURE-NON-ROOT-DEPLOYMENT.md` (12-step non-root guide)
  - [ ] `docs/SECURITY-ROOT-VS-NONROOT.md` (security analysis)
  - [ ] `QUICK-REFERENCE-SECURITY.md` (visual guide)

- [ ] Prepare VPS access
  - [ ] Have VPS IP/hostname ready
  - [ ] SSH key configured (no password login)
  - [ ] Can SSH as non-root user (e.g., `ubuntu`)
  - [ ] Have sudo access without password prompt

- [ ] Prepare configuration
  - [ ] Create or obtain `vps_config.env` from template
  - [ ] Populate required variables:
    - [ ] `TIMEZONE` (e.g., "America/New_York")
    - [ ] `SLACK_WEBHOOK_URL` (for alerts)
    - [ ] `B2_BUCKET_NAME`, `B2_KEY_ID`, `B2_APPLICATION_KEY` (Backblaze B2 backup)
    - [ ] `KOPIA_REPOSITORY_PASSPHRASE` (backup encryption)

---

## 🚀 Phase 1: System Hardening (Run on VPS)

### Step 1: Copy configure.sh to VPS

```bash
# From local machine
scp secured/configure.sh ubuntu@<VPS_IP>:~/
scp secured/vps_config.env ubuntu@<VPS_IP>:~/
```

### Step 2: Run configure.sh with checkpoints

```bash
# SSH to VPS as non-root user
ssh ubuntu@<VPS_IP>

# Make script executable
chmod +x configure.sh

# Run as root (will pause at checkpoints)
sudo ./configure.sh
```

**The script will pause at these checkpoints:**

#### Checkpoint 1: Pre-Flight Security

- [ ] Review system hardening checklist
- [ ] Confirm you want to proceed
- **Press ENTER to continue**

#### Checkpoint 2: SSH Hardening

- [ ] Verify settings:
  - [ ] `PermitRootLogin no`
  - [ ] `PasswordAuthentication no`
  - [ ] `PubkeyAuthentication yes`
  - [ ] Plus 1 `AllowUsers` entry
- **Press ENTER to continue**

#### Checkpoint 3: UFW Firewall

- [ ] Verify rules:
  - [ ] Port 22 (SSH): ALLOW
  - [ ] Port 80 (HTTP): ALLOW
  - [ ] Port 443 (HTTPS): ALLOW
  - [ ] Other ports: DENY
- **Press ENTER to continue**

#### Checkpoint 4: Fail2Ban

- [ ] Verify intrusion detection:
  - [ ] Fail2Ban is RUNNING
  - [ ] SSH jail configured
  - [ ] Ban times set (1 hour default, 1 day SSH)
- **Press ENTER to continue**

#### Checkpoint 5: NGINX

- [ ] Verify web server:
  - [ ] NGINX is RUNNING
  - [ ] Syntax is valid
  - [ ] Directories created (sites-available, sites-enabled)
- **Press ENTER to continue**

#### Checkpoint 6: Application User & Directories

- [ ] Verify appuser account:
  - [ ] appuser exists with `/usr/sbin/nologin` shell
  - [ ] Application directories created
  - [ ] Directory ownership is `appuser:appuser`
  - [ ] Directories: `/var/www/apps/{detoxnearme,edge-nextjs,forge-nextjs}`
  - [ ] PM2 directories: `/var/run/pm2`, `/var/log/pm2`
- **Press ENTER to continue**

#### Checkpoint 7: Final Security Review

- [ ] Review all security measures:
  - [ ] SSH hardening applied
  - [ ] UFW firewall enabled with correct rules
  - [ ] Fail2Ban running
  - [ ] NGINX running
  - [ ] appuser created with correct permissions
  - [ ] Backup system (Kopia) configured
  - [ ] Slack notifications configured
- **Press ENTER to finish**

### Step 3: Verify Security Measures

```bash
# Still SSH'd into VPS as ubuntu/non-root user
# Copy verification script to VPS first
scp secured/verify-security.sh ubuntu@<VPS_IP>:~/

# Run verification script
sudo ./verify-security.sh
```

**Review output:**

- [ ] All checks PASSED (green ✓)
- [ ] No checks FAILED (red ✗)
- [ ] Warnings noted (yellow ⚠)

**Expected results:**

```
Passed:  40+
Failed:  0
Warnings: 0  (or just informational items)
```

### Step 4: System Reboot

```bash
# Reboot to apply all changes
sudo reboot

# Wait for VPS to come back online
# Then reconnect
ssh ubuntu@<VPS_IP>
```

### Step 5: Post-Reboot Verification

```bash
# Verify key services still running after reboot
sudo systemctl status ssh
sudo systemctl status nginx
sudo systemctl status fail2ban
sudo systemctl status ufw

# Check firewall still configured
sudo ufw status verbose

# Check appuser and directories still exist
id appuser
ls -la /var/www/apps/
ls -la /var/run/pm2
```

---

## 📦 Phase 2: Application Deployment (Non-Root)

⚠️ **DO NOT proceed until Phase 1 is complete and verified.**

### Step 1: Copy deployment files to VPS

```bash
# From local machine
scp conf/node-steelgem/ecosystem.config.secure.js ubuntu@<VPS_IP>:~/
scp conf/node-steelgem/NGINX-UNIX-SOCKET.conf ubuntu@<VPS_IP>:~/
scp -r docs/ ubuntu@<VPS_IP>:~/
```

### Step 2: Install Node.js as appuser

Follow **Step 3** from `docs/SECURE-NON-ROOT-DEPLOYMENT.md`:

```bash
# Install NVM for appuser
sudo -u appuser bash -c '
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
  source ~/.nvm/nvm.sh
  nvm install v20.19.5
  npm install -g pm2
'

# Verify
sudo -u appuser bash -c 'source ~/.nvm/nvm.sh && node --version'
```

### Step 3: Deploy application code

Copy application source code to `/var/www/apps/`:

```bash
# Option A: From local machine
scp -r ~/projects/detoxnearme ubuntu@<VPS_IP>:/tmp/
ssh ubuntu@<VPS_IP> "sudo cp -r /tmp/detoxnearme /var/www/apps/ && sudo chown -R appuser:appuser /var/www/apps/detoxnearme"

# Repeat for edge-nextjs and forge-nextjs
```

Or using git (if available):

```bash
ssh ubuntu@<VPS_IP>
sudo -u appuser bash -c '
  cd /var/www/apps/detoxnearme
  git clone https://github.com/your-org/detoxnearme.git .
  npm ci --production
  npm run build
'
```

### Step 4: Create .env.local files

```bash
ssh ubuntu@<VPS_IP>

# DetoxNearMe
sudo bash -c 'cat > /var/www/apps/detoxnearme/.env.local << EOF
NODE_ENV=production
PORT=/var/run/pm2/detoxnearme.sock
DATABASE_URL=postgresql://detoxnearme_user:SECURE_PASSWORD@sql-steelgem:5432/detoxnearme
NEXT_PUBLIC_API_URL=https://cms.detoxnearme.com
EOF'

sudo chown appuser:appuser /var/www/apps/detoxnearme/.env.local
sudo chmod 600 /var/www/apps/detoxnearme/.env.local

# Repeat for edge-nextjs and forge-nextjs (see SECURE-NON-ROOT-DEPLOYMENT.md for specific env vars)
```

### Step 5: Deploy ecosystem config

```bash
ssh ubuntu@<VPS_IP>

# Copy ecosystem config to appuser's home
sudo cp ~/ecosystem.config.secure.js /home/appuser/ecosystem.config.js
sudo chown appuser:appuser /home/appuser/ecosystem.config.js
sudo chmod 644 /home/appuser/ecosystem.config.js
```

### Step 6: Deploy NGINX config

```bash
ssh ubuntu@<VPS_IP>

# Copy Unix socket NGINX config
sudo cp ~/NGINX-UNIX-SOCKET.conf /etc/nginx/conf.d/nextjs-apps.conf

# Validate
sudo nginx -t

# Reload NGINX
sudo systemctl reload nginx
```

### Step 7: Start PM2 as appuser

```bash
ssh ubuntu@<VPS_IP>

# Start all apps
sudo -u appuser bash -c 'source ~/.nvm/nvm.sh && pm2 start /home/appuser/ecosystem.config.js'

# Verify
sudo -u appuser pm2 list
```

### Step 8: Verify end-to-end connectivity

```bash
ssh ubuntu@<VPS_IP>

# Check Unix sockets exist
ls -la /var/run/pm2/

# Verify NO TCP ports listening (apps use Unix sockets)
netstat -tlnp | grep -E ':3000|:3001|:3002' && echo "✗ FAIL: apps on TCP" || echo "✓ PASS: apps on Unix sockets"

# Test app endpoint
curl -I https://detoxnearme.com

# Check logs
sudo -u appuser pm2 logs detoxnearme --lines 20
```

---

## ✅ Final Verification Checklist

After all installations, verify:

- [ ] SSH hardening applied
  - [ ] `sudo grep '^PermitRootLogin no' /etc/ssh/sshd_config`
  - [ ] `sudo grep '^PasswordAuthentication no' /etc/ssh/sshd_config`

- [ ] UFW firewall configured
  - [ ] `sudo ufw status verbose` shows 22/80/443 allowed
  - [ ] `sudo ufw status verbose` shows 3000-3002 denied

- [ ] Key services running
  - [ ] `systemctl status ssh` → active
  - [ ] `systemctl status nginx` → active
  - [ ] `systemctl status fail2ban` → active
  - [ ] `systemctl status ufw` → active

- [ ] appuser and directories
  - [ ] `id appuser` shows non-root user
  - [ ] `ls -la /var/www/apps/` shows appuser ownership
  - [ ] `ls -la /var/run/pm2` shows appuser ownership

- [ ] Applications
  - [ ] PM2 processes running: `sudo -u appuser pm2 list`
  - [ ] No TCP app ports: `netstat -tlnp | grep -E ':3000|:3001|:3002'` returns nothing
  - [ ] Unix sockets exist: `ls -la /var/run/pm2/*.sock`
  - [ ] NGINX proxies to sockets: `curl -I https://yourdomain.com`

- [ ] Backups
  - [ ] `sudo kopia repository status` shows connected
  - [ ] Kopia cron job configured: `sudo crontab -l | grep kopia-backup`

- [ ] Slack notifications
  - [ ] Test message: `echo "Test" | sudo /usr/local/bin/slack-notify.sh`
  - [ ] Received in Slack channel

---

## 🆘 Troubleshooting

### SSH refuses after hardening

**Problem**: Can't SSH after running configure.sh

**Solution**:

```bash
# If you locked yourself out, go back to VPS console/bastion
# Check SSH config
sudo grep "^PermitRootLogin\|^PasswordAuthentication" /etc/ssh/sshd_config

# Reload from backup if corrupted
sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
sudo systemctl restart ssh
```

### UFW blocking legitimate traffic

**Problem**: Services not responding after UFW enabled

**Solution**:

```bash
# Check current rules
sudo ufw status verbose

# Add missing rule
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

### PM2 apps not starting

**Problem**: `pm2 list` shows no processes

**Solution**:

```bash
# Check appuser can access directories
sudo -u appuser ls -la /var/www/apps/detoxnearme/

# Check .env.local exists and is readable
sudo -u appuser cat /var/www/apps/detoxnearme/.env.local

# Start manually to see errors
sudo -u appuser bash -c 'source ~/.nvm/nvm.sh && cd /var/www/apps/detoxnearme && npm start'

# Check PM2 logs
sudo -u appuser pm2 logs
```

### NGINX returns 502 Bad Gateway

**Problem**: HTTPS returns 502 when accessing app domain

**Solution**:

```bash
# Check if PM2 apps running
sudo -u appuser pm2 list

# Check if Unix socket exists and readable
ls -la /var/run/pm2/detoxnearme.sock

# Check NGINX can read socket
sudo -u www-data test -r /var/run/pm2/detoxnearme.sock && echo "OK" || echo "FAIL"

# Check NGINX error log
sudo tail -20 /var/log/nginx/error.log

# Test locally
curl http://localhost:3000  # Should fail (no TCP)
```

---

## 📞 Support

If issues arise:

1. **Check logs**:

   ```bash
   sudo journalctl -u nginx -n 50
   sudo journalctl -u fail2ban -n 50
   sudo -u appuser pm2 logs
   ```

2. **Verify security checklist**:

   ```bash
   sudo ./verify-security.sh
   ```

3. **Review documentation**:
   - `docs/SECURE-NON-ROOT-DEPLOYMENT.md` - deployment guide
   - `docs/SECURITY-ROOT-VS-NONROOT.md` - security details
   - `docs/QUICK-REFERENCE-SECURITY.md` - quick reference

---

## 🎯 Success Criteria

Deployment is complete when:

✅ All security checkpoints verified
✅ Zero failed security checks
✅ Apps responding on HTTPS
✅ Apps running as appuser (not root)
✅ No TCP port exposure (Unix sockets only)
✅ Backups configured and working
✅ Slack alerts functional
✅ System survives reboot without issues

---

**Date Completed**: ________________
**VPS Hostname**: ________________
**Deployed By**: ________________

Congratulations! Your VPS is now production-ready with enterprise-grade security. 🎉
