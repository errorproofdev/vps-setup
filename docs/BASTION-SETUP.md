# 🏰 Bastion Deployment Architecture

**Updated**: January 29, 2026

## Architecture Overview

Your **local machine acts as the bastion/orchestrator**, not node-steelgem:

```
Your Local Machine (Bastion)
    ├─ SSH to edge-prod
    │  └─ Pull code via tar/rsync
    │
    ├─ SCP to node-steelgem  
    │  └─ Push code
    │
    └─ SSH to node-steelgem
       └─ Trigger: npm build → PM2 → NGINX
```

**Benefits:**

- ✅ No inter-server SSH needed
- ✅ Simple security (only local→servers)
- ✅ Full control from one place
- ✅ Easy to monitor/debug
- ✅ Better audit trail

---

## Setup Complete

### Files Created

1. **scripts/deploy-bastion.sh** - Orchestration script (runs on your local machine)
2. **docs/SERVER-CONTEXT.md** - Updated with bastion flow

### What You Have

```
/Users/josephvore/CODE/vps-setup/
├── scripts/
│   ├── deploy-bastion.sh     ← Orchestrator script
│   ├── services.sh           ← Service modules
│   └── scripts/vps-setup.sh  ← Base system setup
├── conf/                     ← SSL certificates
└── docs/                     ← Documentation
```

---

## Usage (From Your Local Machine)

### Phase 1: One-Time Setup (Already Done?)

```bash
# Check if scripts/vps-setup.sh has run on node-steelgem
ssh node-steelgem "test -f /etc/nginx/nginx.conf && echo 'scripts/vps-setup.sh completed' || echo 'Need to run scripts/vps-setup.sh'"

# If needed:
ssh node-steelgem "cd /root/vps-setup && sudo ./scripts/vps-setup.sh"
ssh node-steelgem "cd /root/vps-setup && sudo ./scripts/services.sh nvm"
ssh node-steelgem "cd /root/vps-setup && sudo ./scripts/services.sh nvm"
```

### Phase 2: Deploy Apps (Using Bastion Script)

```bash
# From your local machine (in vps-setup directory):
cd /Users/josephvore/CODE/vps-setup

# Deploy Edge Treatment
./scripts/deploy-bastion.sh edge_nextjs theedgetreatment.com 3000

# Deploy The Forge
./scripts/deploy-bastion.sh forge_nextjs theforgerecovery.com 3001

# Deploy Detox Near Me
./scripts/deploy-bastion.sh detoxnearme detoxnearme.com 3002
```

---

## What deploy-bastion.sh Does

1. **Validates connectivity** to both edge-prod and node-steelgem
2. **Pulls from source** - Tars code on edge-prod, SCPs to local machine
3. **Creates app directory** on node-steelgem
4. **Pushes to destination** - SCPs code and extracts
5. **Builds and starts** - Runs npm ci → npm build → PM2 start
6. **Verifies** - Tests port connectivity and shows status

---

## Example Output

```
[2026-01-29 14:30:45] Starting bastion deployment orchestration
[2026-01-29 14:30:45] App: edge_nextjs | Domain: theedgetreatment.com | Port: 3000
[2026-01-29 14:30:45] Step 1/6: Verifying server connectivity...
[2026-01-29 14:30:46] ✓ Connected to edge-prod
[2026-01-29 14:30:47] ✓ Connected to node-steelgem
[2026-01-29 14:30:47] Step 2/6: Pulling code from edge-prod...
[2026-01-29 14:31:05] ✓ Code pulled from edge-prod
[2026-01-29 14:31:05] Step 3/6: Verifying app contents...
[2026-01-29 14:31:05] ✓ App archive is valid
[2026-01-29 14:31:05] Step 4/6: Creating app directory on node-steelgem...
[2026-01-29 14:31:06] ✓ Directory created
[2026-01-29 14:31:06] Pushing code to node-steelgem...
[2026-01-29 14:31:25] ✓ Code pushed and extracted on node-steelgem
[2026-01-29 14:31:25] Step 5/6: Building and starting app on node-steelgem...
[2026-01-29 14:31:45] ✓ Build and start complete on node-steelgem
[2026-01-29 14:31:50] Step 6/6: Verifying deployment...
[2026-01-29 14:31:51] ✓ Application is responding on port 3000

[2026-01-29 14:31:51] ✓ Deployment Complete!
[2026-01-29 14:31:51] App:      edge_nextjs
[2026-01-29 14:31:51] Location: node-steelgem:/var/www/apps/edge_nextjs
[2026-01-29 14:31:51] Port:     3000
[2026-01-29 14:31:51] URL:      https://www.theedgetreatment.com
```

---

## Comparison: Old vs New

### ❌ OLD APPROACH

- node-steelgem had to SSH into edge-prod
- node-steelgem needed SSH config + keys for edge-prod
- More complex inter-server communication
- Harder to troubleshoot

### ✅ NEW BASTION APPROACH

- Local machine orchestrates everything
- node-steelgem only receives commands from local machine
- Simpler SSH surface (local → servers only)
- Full visibility from your laptop
- Better for security and audit trails

---

## Next Steps

### Option A: Use New deploy-bastion.sh Script

```bash
# From local machine
cd /Users/josephvore/CODE/vps-setup
./scripts/deploy-bastion.sh edge_nextjs theedgetreatment.com 3000
```

### Option B: Keep Using services.sh on node-steelgem

You can still use the original approach - `scripts/services.sh` on the VPS still works:

```bash
ssh node-steelgem
cd /root/vps-setup
sudo ./scripts/services.sh edge-migrate
```

(But this would require edge-prod SSH config on node-steelgem)

---

## SSH Configuration (All You Need)

**~/.ssh/config** (on your local machine):

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

**That's it!** No inter-server SSH needed.

---

## Troubleshooting

### "Cannot connect to edge-prod"

```bash
# Test connection
ssh edge-prod "echo Connected"

# Check SSH config
cat ~/.ssh/config | grep -A5 edge-prod

# Check key permissions
ls -la ~/.ssh/your-key.pem
# Should be: -rw-------
```

### "Cannot connect to node-steelgem"

```bash
# Test connection
ssh node-steelgem "echo Connected"

# Verify files are there
ssh node-steelgem "ls -la /root/vps-setup/*.sh"
```

### "Build failed on node-steelgem"

```bash
# Check logs
ssh node-steelgem "pm2 logs edge_nextjs --lines 100"

# Check manually
ssh node-steelgem "cd /var/www/apps/edge_nextjs && npm run build"
```

---

## Files Reference

| File | Purpose | Location |
|------|---------|----------|
| **scripts/deploy-bastion.sh** | Orchestrator script | Your local machine |
| **scripts/services.sh** | VPS setup/deployment | node-steelgem:/root/vps-setup/ |
| **scripts/vps-setup.sh** | Base system setup | node-steelgem:/root/vps-setup/ |
| **docs/SERVER-CONTEXT.md** | Architecture docs | This repo |

---

## Summary

Your local machine is now the **orchestration hub**:

- ✅ Pulls from edge-prod (source)
- ✅ Pushes to node-steelgem (destination)
- ✅ Triggers builds and deploys
- ✅ Monitors status

**No inter-server SSH needed!** 🎉
