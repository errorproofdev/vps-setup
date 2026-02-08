# VPS Setup - Dynamic SSH Testing Guide Index

## 🎯 Quick Start (2 minutes)

If you just want to get started immediately:

```bash
# 1. Make scripts executable
chmod +x scripts/*.sh test-postgresql-connectivity.sh

# 2. Configure SSH (add to ~/.ssh/config)
cat >> ~/.ssh/config << 'EOF'
Host sql-steelgem
    HostName your-ip-or-domain
    User ubuntu

Host node-steelgem
    HostName your-ip-or-domain
    User ubuntu
EOF

# 3. Test connectivity
ssh sql-steelgem "echo 'OK'"
ssh node-steelgem "echo 'OK'"

# 4. Run the interactive test
./POSTGRESQL-SETUP-CHECKLIST.sh

# Or run the automated test directly
./test-postgresql-connectivity.sh sql-steelgem node-steelgem
```

## 📚 Documentation Structure

### For Getting Started

| Document | Purpose | Time | Best For |
|----------|---------|------|----------|
| [QUICK-START.md](./QUICK-START.md) | 5-minute overview | 5 min | Quick orientation |
| [POSTGRESQL-SETUP-CHECKLIST.sh](./POSTGRESQL-SETUP-CHECKLIST.sh) | Interactive step-by-step guide | 20-30 min | First-time testers |
| [test-postgresql-connectivity.sh](./test-postgresql-connectivity.sh) | Automated test script | 5-10 min | Quick validation |

### For Understanding the System

| Document | Purpose | Time | Best For |
|----------|---------|------|----------|
| [TESTING-THE-DYNAMIC-SSH-SYSTEM.md](./TESTING-THE-DYNAMIC-SSH-SYSTEM.md) | Complete testing overview | 15 min | Understanding capabilities |
| [DYNAMIC-SSH-GUIDE.md](./DYNAMIC-SSH-GUIDE.md) | SSH configuration details | 10 min | Configuration options |
| [IMPLEMENTATION-SUMMARY.md](./IMPLEMENTATION-SUMMARY.md) | System architecture | 15 min | Technical deep dive |

### For Specific Scenarios

| Document | Purpose | Time | Best For |
|----------|---------|------|----------|
| [POSTGRESQL-TEST-GUIDE.md](./POSTGRESQL-TEST-GUIDE.md) | Detailed PostgreSQL setup | 20 min | Step-by-step guide |
| [README.md](./README.md) | Main documentation | 30 min | Complete reference |

### For Code Details

| Document | Purpose | Time | Best For |
|----------|---------|------|----------|
| [scripts/ssh-config.sh](./scripts/ssh-config.sh) | SSH utility functions | 10 min | Developers |
| [scripts/vps-setup.sh](./scripts/vps-setup.sh) | Base VPS setup | 15 min | Developers |
| [scripts/deploy.sh](./scripts/deploy.sh) | Deployment configs | 15 min | Developers |

## 🚀 Three Ways to Test

### Option 1: Interactive Checklist (Recommended for First-Time)

Perfect if you want to go step-by-step with prompts:

```bash
./POSTGRESQL-SETUP-CHECKLIST.sh
```

**What you get:**
- Guided walkthrough of each step
- Verification at each stage
- Easy to pause and resume
- Helpful troubleshooting tips

### Option 2: Automated Test (Recommended for Quick Validation)

Fast validation of the entire system:

```bash
./test-postgresql-connectivity.sh sql-steelgem node-steelgem
```

**What you get:**
- Complete test in 5-10 minutes
- Detailed pass/fail for each step
- Automatic installation of missing dependencies
- Clear error messages

### Option 3: Manual Setup (Recommended for Understanding)

Step-by-step manual approach to learn the system:

```bash
# See POSTGRESQL-TEST-GUIDE.md or TESTING-THE-DYNAMIC-SSH-SYSTEM.md
# for detailed manual steps
```

**What you get:**
- Full control and understanding
- Can modify each step as needed
- Best for customization

## 🔍 What Gets Tested

### Automated Test Checks (10 tests total)

1. ✅ **SSH Connectivity** - Can reach both servers
2. ✅ **PostgreSQL Installation** - postgres binary exists
3. ✅ **PostgreSQL Service** - Service is running
4. ✅ **Network Configuration** - Listening on port 5432
5. ✅ **Server IP Discovery** - Get actual IPs
6. ✅ **pg_hba.conf Configuration** - Allows remote access
7. ✅ **Test User Existence** - testuser is created
8. ✅ **PostgreSQL Client** - Client tools installed on node server
9. ✅ **Database Connectivity** - Connection from node to SQL
10. ✅ **Data Transfer** - Can write and read data

## 📋 Test Scenario Overview

```
sql-steelgem (Database Server)
├── OS: Ubuntu 24.04
├── PostgreSQL: Latest version
├── Services: NGINX, Fail2ban, UFW
└── Configuration:
    ├── Listening on all interfaces (0.0.0.0:5432)
    ├── pg_hba.conf updated for node-steelgem IP
    └── Database 'testdb' with user 'testuser'

node-steelgem (Application Server)
├── OS: Ubuntu 24.04
├── PostgreSQL Client: psql
└── Test: Connect to sql-steelgem:5432/testdb

Network Connectivity
├── SSH: Both servers accessible
├── Firewall: UFW allows PostgreSQL port
└── Result: Data flows from app to database
```

## 🛠️ System Architecture

### Dynamic SSH Resolution

The new system resolves SSH hosts in this order:

```
1. Command-line: SSH_HOST="sql-steelgem" ./script.sh
   ↓ (not provided)
2. Environment variable: export SSH_HOST="sql-steelgem"
   ↓ (not set)
3. .env file: SSH_HOST="sql-steelgem"
   ↓ (not found)
4. SSH config: Host sql-steelgem in ~/.ssh/config
   ↓ (not configured)
5. Default: localhost (run script locally)
```

### Integration Points

```
All Scripts Use SSH Resolution:

┌─────────────────────────────────┐
│      ssh-config.sh              │
│  (SSH utility functions)        │
└────────────────────────────────┬┘
         ↑         ↑        ↑        ↑
         │         │        │        │
    vps-setup  deploy   services deploy-bastion
     .sh        .sh        .sh        .sh
```

## 📊 File Manifest

### New Test Files
- `test-postgresql-connectivity.sh` - Automated connectivity test
- `POSTGRESQL-SETUP-CHECKLIST.sh` - Interactive step-by-step guide

### New Documentation Files
- `TESTING-THE-DYNAMIC-SSH-SYSTEM.md` - This system overview
- `POSTGRESQL-TEST-GUIDE.md` - Detailed PostgreSQL setup guide
- `TEST-POSTGRESQL-SETUP.md` - Scenario documentation
- `DYNAMIC-SSH-GUIDE.md` - SSH configuration reference (updated)
- `IMPLEMENTATION-SUMMARY.md` - Architecture overview (updated)
- `QUICK-START.md` - Quick reference (updated)
- `README.md` - Main documentation (updated)

### Modified Core Files
- `scripts/ssh-config.sh` - New SSH utility module
- `scripts/vps-setup.sh` - Updated for dynamic SSH
- `scripts/deploy.sh` - Updated for dynamic SSH
- `scripts/deploy-bastion.sh` - Updated for dynamic SSH
- `.env.example` - Updated with SSH configuration examples

## 🎓 Learning Path

### 1. Understand the Concept (5 minutes)
Read: [QUICK-START.md](./QUICK-START.md)

### 2. See It In Action (10 minutes)
Run: `./test-postgresql-connectivity.sh sql-steelgem node-steelgem`

### 3. Learn the Details (20 minutes)
Read: [TESTING-THE-DYNAMIC-SSH-SYSTEM.md](./TESTING-THE-DYNAMIC-SSH-SYSTEM.md)

### 4. Understand Configuration (10 minutes)
Read: [DYNAMIC-SSH-GUIDE.md](./DYNAMIC-SSH-GUIDE.md)

### 5. Set Up Your Own (30 minutes)
Follow: [POSTGRESQL-TEST-GUIDE.md](./POSTGRESQL-TEST-GUIDE.md)

### 6. Understand Architecture (15 minutes)
Read: [IMPLEMENTATION-SUMMARY.md](./IMPLEMENTATION-SUMMARY.md)

## ✨ Key Features Demonstrated

### Feature 1: No Hardcoded SSH Aliases
```bash
# Old way (hardcoded)
ssh ubuntu@192.168.1.50

# New way (dynamic)
ssh sql-steelgem  # Resolves automatically
```

### Feature 2: Flexible Configuration
```bash
# Method 1: Command-line
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh

# Method 2: Environment variable
export SSH_HOST="sql-steelgem"
./scripts/vps-setup.sh

# Method 3: .env file
# SSH_HOST="sql-steelgem" in .env
./scripts/vps-setup.sh

# Method 4: SSH config
# Host sql-steelgem in ~/.ssh/config
./scripts/vps-setup.sh
```

### Feature 3: Multi-Server Management
```bash
# Setup multiple servers with same script
SSH_HOST="db-server" ./scripts/vps-setup.sh
SSH_HOST="app-server-1" ./scripts/vps-setup.sh
SSH_HOST="app-server-2" ./scripts/vps-setup.sh
```

## 🐛 Troubleshooting Quick Links

| Problem | Solution |
|---------|----------|
| "Cannot connect to sql-steelgem" | See [Troubleshooting Connection](./TESTING-THE-DYNAMIC-SSH-SYSTEM.md#troubleshooting-common-issues) |
| "PostgreSQL not listening" | See [PostgreSQL Network Config](./POSTGRESQL-TEST-GUIDE.md#phase-3-postgresql-network-configuration) |
| "Authentication failed" | See [Auth Troubleshooting](./POSTGRESQL-TEST-GUIDE.md#authentication-failed) |
| "Firewall blocking connection" | See [Firewall Issues](./POSTGRESQL-TEST-GUIDE.md#firewall-issues) |

## 📞 Support Information

### Check System Status
```bash
# SSH to server and check
ssh sql-steelgem "systemctl status postgresql"

# Check what's listening
ssh sql-steelgem "sudo ss -tlnp | grep 5432"

# Check configuration
ssh sql-steelgem "sudo cat /etc/postgresql/*/main/postgresql.conf | grep listen"
```

### Enable Debug Output
```bash
# Add verbosity to SSH
ssh -v sql-steelgem "echo 'test'"

# Add verbosity to scripts
bash -x ./test-postgresql-connectivity.sh sql-steelgem node-steelgem
```

### View Log Files
```bash
# PostgreSQL logs
ssh sql-steelgem "sudo tail -50 /var/log/postgresql/*.log"

# System logs
ssh sql-steelgem "sudo journalctl -u postgresql -n 50"
```

## ✅ Success Criteria

Your test is successful when:

- [x] SSH connectivity to both servers works
- [x] PostgreSQL installed and running on sql-steelgem
- [x] PostgreSQL listening on port 5432
- [x] pg_hba.conf configured for remote access
- [x] Test database and user created
- [x] PostgreSQL client installed on node-steelgem
- [x] Connection from node-steelgem to PostgreSQL succeeds
- [x] Data can be written and read across servers
- [x] Firewall allows the connection

## 🎉 Next Steps After Successful Test

1. **Customize Configuration**
   - Update passwords for production
   - Configure SSL/TLS for PostgreSQL
   - Setup backup strategies

2. **Deploy Your Application**
   - Copy application to node-steelgem
   - Configure app to connect to PostgreSQL
   - Deploy with: `./scripts/deploy.sh production`

3. **Setup Monitoring**
   - Add health checks
   - Configure alerts
   - Setup log aggregation

4. **Production Hardening**
   - Change all default passwords
   - Enable SSL certificates
   - Setup automatic backups
   - Configure read replicas (optional)

## 📖 Additional Resources

- [PostgreSQL Official Docs](https://www.postgresql.org/docs/)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
- [Bash Scripting Guide](https://www.gnu.org/software/bash/manual/)
- [SSH Best Practices](https://linux.die.net/man/5/ssh_config)

## 🔗 Document Cross-References

Quick navigation between related sections:

- **SSH Config** → [DYNAMIC-SSH-GUIDE.md](./DYNAMIC-SSH-GUIDE.md)
- **PostgreSQL Setup** → [POSTGRESQL-TEST-GUIDE.md](./POSTGRESQL-TEST-GUIDE.md)
- **Testing** → [test-postgresql-connectivity.sh](./test-postgresql-connectivity.sh)
- **Interactive Setup** → [POSTGRESQL-SETUP-CHECKLIST.sh](./POSTGRESQL-SETUP-CHECKLIST.sh)
- **Architecture** → [IMPLEMENTATION-SUMMARY.md](./IMPLEMENTATION-SUMMARY.md)
- **Quick Reference** → [QUICK-START.md](./QUICK-START.md)
- **Complete Guide** → [README.md](./README.md)

---

## 🚀 Ready to Start?

Choose your path:

### 👤 I want guided steps
→ Run: `./POSTGRESQL-SETUP-CHECKLIST.sh`

### ⚡ I want quick validation
→ Run: `./test-postgresql-connectivity.sh sql-steelgem node-steelgem`

### 📖 I want to understand first
→ Read: [TESTING-THE-DYNAMIC-SSH-SYSTEM.md](./TESTING-THE-DYNAMIC-SSH-SYSTEM.md)

### 🔧 I want manual control
→ Follow: [POSTGRESQL-TEST-GUIDE.md](./POSTGRESQL-TEST-GUIDE.md)

---

**System Version:** 1.0  
**Last Updated:** 2026-01-30  
**Status:** ✅ Production Ready
