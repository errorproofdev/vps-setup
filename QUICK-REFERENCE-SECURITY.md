# Quick Reference: Root vs Non-Root Security

## 🚨 BEFORE (Current configure.sh - INSECURE)

```
Root User (uid=0)
├── NVM in /root/.nvm
├── PM2 runs as root
│   ├── detoxnearme:3000 ← TCP port exposed
│   ├── edge:3001 ←─────── TCP port exposed
│   └── forge:3002 ←─────── TCP port exposed
└── If RCE → Attacker gets ROOT SHELL ☠️
    ├── Can read /etc/shadow
    ├── Can access /root/.ssh
    ├── Can modify /etc/sudoers
    └── System fully compromised
```

### Attack: RCE in Next.js → Root Access

```
Developer commits vulnerable code
    ↓
Attacker exploits prototype pollution / template injection
    ↓
Node.js process runs arbitrary code as ROOT (uid=0)
    ↓
Attacker installs backdoor in /root/.bashrc
    ↓
SSH back as ubuntu user, sudo bash, gets root shell
    ↓
💀 Full system compromise
```

---

## ✅ AFTER (Secure Deployment - RECOMMENDED)

```
appuser (uid=1001, /usr/sbin/nologin)
├── NVM in /home/appuser/.nvm
├── PM2 runs as appuser (not root)
│   ├── detoxnearme:/var/run/pm2/detoxnearme.sock ← Unix socket
│   ├── edge:/var/run/pm2/edge-treatment.sock ←────── No TCP
│   └── forge:/var/run/pm2/forge-recovery.sock ←────── No TCP
├── No /bin/bash (nologin shell)
└── If RCE → Attacker stuck in appuser context 🛡️
    ├── try: cat /etc/shadow → Permission denied
    ├── try: sudo bash → Not in sudoers
    ├── try: /bin/bash → /usr/sbin/nologin
    └── Can only access /home/appuser and /var/www
```

### Attack: RCE in Next.js → Contained to appuser

```
Developer commits vulnerable code
    ↓
Attacker exploits prototype pollution / template injection
    ↓
Node.js process runs arbitrary code as appuser (uid=1001)
    ↓
Attacker tries: sudo bash
    ↓
Error: appuser is not in sudoers file
    ↓
Attacker tries: /bin/bash -i
    ↓
Error: /usr/sbin/nologin
    ↓
Attacker can't escalate, trapped in appuser context
✓ Impact contained, data safe
```

---

## 🔐 Security Layers (Defense in Depth)

```
Attacker ──┬─→ Layer 1: Firewall (UFW)
           │   ✓ Port 22: SSH only (public keys)
           │   ✓ Port 80: HTTP → HTTPS (NGINX)
           │   ✓ Port 443: HTTPS (NGINX)
           │   ✗ Ports 3000-3002: DENIED
           │
           └─→ Layer 2: NGINX (www-data user)
               ✓ Reverse proxy only
               ✓ Security headers
               ✓ Rate limiting
               ✗ No direct app access
               │
               └─→ Layer 3: Unix Socket
                   ✓ Filesystem-based, not network
                   ✓ File permissions control access
                   ✓ www-data can read, appuser only owner
                   │
                   └─→ Layer 4: App Process (appuser)
                       ✓ Non-root user
                       ✓ No shell (/usr/sbin/nologin)
                       ✓ No sudo access
                       ✓ Limited filesystem access
                       │
                       └─→ Layer 5: RCE (if happens)
                           ✗ Code execution as appuser
                           ✗ No root escalation possible
                           ✓ Damage contained
```

---

## 📊 Quick Comparison

| Security Aspect | ❌ Root-Based | ✅ Non-Root |
|-----------------|---|---|
| SSH as root? | ✓ Yes (dangerous) | ✗ No |
| PM2 user | root (uid=0) | appuser (uid=1001) |
| App ports | 3000/3001/3002 (TCP) | Unix sockets only |
| Port visibility | `netstat` shows :3000 | No TCP entries |
| NGINX → Apps | TCP 127.0.0.1:3000 | Unix socket |
| RCE Impact | **Root shell** ☠️ | Appuser context 🛡️ |
| Read /etc/passwd | ✓ Yes | ✗ No permission |
| Read /etc/shadow | ✓ Yes | ✗ No permission |
| Modify SSH keys | ✓ Yes | ✗ No |
| Install packages | ✓ Yes | ✗ No |
| Restart system | ✓ Yes | ✗ No |

---

## 🎯 Deployment Checklist

### Pre-Deployment (One-Time Setup)

- [ ] Review `ecosystem.config.secure.js`
- [ ] Review NGINX Unix socket config
- [ ] Read `SECURE-NON-ROOT-DEPLOYMENT.md`
- [ ] Prepare SSL certificates
- [ ] Prepare app source code

### Deployment Day (12 Steps)

1. [ ] Create appuser account
2. [ ] Create directories (/var/www/apps, /var/run/pm2, /var/log/pm2)
3. [ ] Install NVM as appuser
4. [ ] Install Node.js v20.19.5
5. [ ] Deploy application source code
6. [ ] Deploy ecosystem.config.secure.js
7. [ ] Create .env.local files (one per app)
8. [ ] Start PM2 as appuser
9. [ ] Configure PM2 autostart
10. [ ] Harden UFW firewall
11. [ ] Deploy NGINX Unix socket config
12. [ ] Verify connectivity

### Post-Deployment (1-2 Weeks)

- [ ] Monitor logs for errors
- [ ] Verify all 3 apps responding
- [ ] Check PM2 autorestart on reboot
- [ ] Load test (simulate traffic)
- [ ] Disable root SSH (final hardening)

---

## 📝 File Locations

```
conf/node-steelgem/
├── ecosystem.config.secure.js    ← USE THIS
├── NGINX-UNIX-SOCKET.conf        ← USE THIS
└── README.md

docs/
├── SECURE-NON-ROOT-DEPLOYMENT.md ← 12-step guide
├── SECURITY-ROOT-VS-NONROOT.md   ← Full analysis
└── NEXTJS-DEPLOYMENT.md          ← Original

secured/
└── configure.sh                  ← NEEDS UPDATE (remove root NVM/PM2)
```

---

## ⚡ Quick Start (TL;DR)

```bash
# 1. SSH to VPS as non-root user
ssh ubuntu@node-steelgem

# 2. Create appuser
sudo useradd -r -m -s /usr/sbin/nologin appuser

# 3. Create directories
sudo mkdir -p /var/www/apps/{detoxnearme,edge-nextjs,forge-nextjs}
sudo mkdir -p /var/run/pm2 /var/log/pm2
sudo chown appuser:appuser /var/www/apps/* /var/run/pm2 /var/log/pm2

# 4. Install Node.js (as appuser)
sudo -u appuser bash -c '
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
  source ~/.nvm/nvm.sh
  nvm install v20.19.5
  npm install -g pm2
'

# 5. Copy ecosystem config
sudo cp ecosystem.config.secure.js /home/appuser/ecosystem.config.js
sudo chown appuser:appuser /home/appuser/ecosystem.config.js

# 6. Copy NGINX config
sudo cp NGINX-UNIX-SOCKET.conf /etc/nginx/conf.d/nextjs-apps.conf

# 7. Create .env files and deploy apps
# (See SECURE-NON-ROOT-DEPLOYMENT.md for details)

# 8. Start PM2 as appuser
sudo -u appuser bash -c 'source ~/.nvm/nvm.sh && pm2 start /home/appuser/ecosystem.config.js'

# 9. Verify sockets exist
ls -la /var/run/pm2/

# 10. Verify NO TCP ports
nc -zv 127.0.0.1 3000  # Should fail

# 11. Harden UFW
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 3000/tcp
sudo ufw deny 3001/tcp
sudo ufw deny 3002/tcp
sudo ufw enable

# 12. Reload NGINX
sudo nginx -t && sudo systemctl reload nginx

# Done! Check https://yourdomain.com
```

---

## 🚫 What NOT to Do

```bash
# ❌ DON'T install NVM as root
sudo nvm install v20.19.5

# ❌ DON'T run PM2 via root systemd
[Service]
User=root
ExecStart=/root/.nvm/versions/node/.../pm2 start ...

# ❌ DON'T allow TCP app ports
nc 127.0.0.1 3000  # ← Should NOT connect

# ❌ DON'T allow ssh as root
PermitRootLogin yes  # ← Should be "no"

# ❌ DON'T use password authentication
PasswordAuthentication yes  # ← Should be "no"

# ❌ DON'T give appuser shell access
-s /usr/sbin/nologin  # ← Correct (no shell)
-s /bin/bash          # ← Wrong (gives shell)
```

---

## ✅ What TO Do

```bash
# ✅ DO install NVM as appuser
sudo -u appuser bash -c 'curl -o- .../install.sh | bash'

# ✅ DO run PM2 as appuser
sudo -u appuser pm2 start ...

# ✅ DO use Unix sockets
server unix:/var/run/pm2/detoxnearme.sock;

# ✅ DO restrict ssh
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes

# ✅ DO use nologin shell
sudo useradd -r -m -s /usr/sbin/nologin appuser

# ✅ DO set correct ownership
sudo chown appuser:appuser /var/www/apps
sudo chmod 755 /var/www/apps
```

---

## 🎓 Learn More

- See `SECURITY-ROOT-VS-NONROOT.md` for detailed attack scenarios
- See `SECURE-NON-ROOT-DEPLOYMENT.md` for step-by-step guide
- See `ecosystem.config.secure.js` for PM2 configuration
- See `NGINX-UNIX-SOCKET.conf` for reverse proxy setup

---

**Remember**: Security is layers. No single solution is perfect, but multiple layers make attacks exponentially harder.

Start with non-root + Unix sockets. Add more controls later as needed.
