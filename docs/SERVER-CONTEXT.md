# Migration Server Context

**Last Updated**: January 29, 2026

## 📍 Two Servers in Play

### 1️⃣ SOURCE SERVER (Current Production)

```
SSH Alias: edge-prod
Role: Current EC2 with running applications
Apps Location: /home/ubuntu/current/

Applications:
- www.theedgetreatment.com (Edge Treatment)
- theforgerecovery.com (The Forge Recovery)
- detoxnearme.com (Detox Near Me)
```

**Command to connect:**

```bash
ssh edge-prod
```

---

### 2️⃣ DESTINATION SERVER (New VPS)

```
SSH Alias: node-steelgem
Role: New Ubuntu 24.04 VPS (4-core)
Target Location: /var/www/apps/

Applications will be deployed to:
- /var/www/apps/edge_nextjs/ (port 3000)
- /var/www/apps/forge_nextjs/ (port 3001)
- /var/www/apps/detoxnearme/ (port 3002)
```

**Command to connect:**

```bash
ssh root@node-steelgem
```

---

## 🔄 Migration Flow (Bastion Pattern)

```
Your Local Machine (Bastion/Orchestrator)
    ├─ Pull from edge-prod (/home/ubuntu/current/)
    │   └─ via: ssh edge-prod
    │
    ├─ Push to node-steelgem (/var/www/apps/)
    │   └─ via: scp/rsync to node-steelgem
    │
    └─ Execute on node-steelgem
        └─ npm ci → npm build → PM2 → NGINX config
        └─ via: ssh node-steelgem "sudo ./scripts/services.sh ..."
```

**Benefits:**

- ✅ Local machine (bastion) orchestrates everything
- ✅ No need for node-steelgem → edge-prod SSH access
- ✅ Simpler security posture
- ✅ Better control over deployment process
- ✅ Easy to see what's happening from one place

---

## 📋 Server Setup Checklist

### On node-steelgem (Destination)

- [ ] Transfer vps-setup scripts via scp
- [ ] Run `sudo ./scripts/vps-setup.sh` (base system setup)
- [ ] Run `sudo ./scripts/services.sh nvm` (NVM + Node.js LTS + npm/pm2/yarn)
- [ ] Run `sudo ./scripts/services.sh nvm` (NVM for per-app Node versions)
- [ ] Run `sudo ./scripts/services.sh edge-migrate` (automated deployment)

### From edge-prod (Source)

- [ ] Verify apps are running at /home/ubuntu/current
- [ ] Verify .env.local files exist
- [ ] Verify .nvmrc files exist in each app directory

---

## 🔑 SSH Configuration (Bastion Approach)

### Your Local Machine Only Needs

**~/.ssh/config on your local machine:**

```
Host edge-prod
    HostName <edge-ec2-ip>
    User ubuntu
    IdentityFile ~/.ssh/your-key.pem

Host node-steelgem
    HostName <new-vps-ip>
    User root
    IdentityFile ~/.ssh/your-key.pem
```

**Test both connections:**

```bash
ssh edge-prod "echo Edge prod OK"
ssh node-steelgem "echo Node steelgem OK"
```

### node-steelgem Does NOT Need edge-prod Config

Since your local machine acts as the bastion, node-steelgem only needs to listen for commands from your local machine. No inter-server SSH required!

---

## 🚀 Deployment Workflow (From Local Machine)

### Phase 1: Setup node-steelgem (One-time)

```bash
# From local machine:
scp -r /Users/josephvore/CODE/vps-setup/* node-steelgem:/root/vps-setup/

# Then SSH and setup
ssh node-steelgem
cd /root/vps-setup
chmod +x scripts/*.sh
sudo ./scripts/vps-setup.sh
sudo ./scripts/services.sh nvm
sudo ./scripts/services.sh nvm
```

### Phase 2: Deploy Apps (From Local Machine)

```bash
# From local machine, pull code from edge-prod
ssh edge-prod "cd /home/ubuntu/current && tar czf /tmp/app.tar.gz ."
scp edge-prod:/tmp/app.tar.gz /tmp/app.tar.gz

# Push to node-steelgem and deploy
scp /tmp/app.tar.gz node-steelgem:/tmp/app.tar.gz
ssh node-steelgem "cd /var/www/apps && tar xzf /tmp/app.tar.gz -C edge_nextjs/"

# Then trigger build/PM2 on node-steelgem
ssh node-steelgem "cd /var/www/apps/edge_nextjs && npm ci --production && npm run build && pm2 start ecosystem.config.js"
```

### Phase 3: Simple Wrapper Script (Optional)

Instead of manual commands, you could create `deploy-local.sh` on your local machine:

```bash
#!/bin/bash
# Local bastion orchestrator script
# - Pulls from edge-prod
# - Pushes to node-steelgem  
# - Triggers remote build/deployment
```

---

## 📝 Notes

- **<www.theedgetreatment.com>** is the primary focus (edge_nextjs on port 3000)
- Other apps follow the same deployment pattern
- All SSL certificates are Cloudflare origin certs (valid 2023-2038)
- PM2 runs in fork mode (1 instance per app, 1GB memory limit)
