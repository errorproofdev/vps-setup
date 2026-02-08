# Quick Reference - Dynamic SSH Configuration

## One-Line Setup Examples

### Setup VPS with IP address
```bash
SSH_HOST="192.168.1.100" ./scripts/vps-setup.sh
```

### Deploy web server to IP
```bash
SSH_HOST="192.168.1.100" ./scripts/deploy.sh web
```

### Deploy application between servers
```bash
SOURCE_HOST="192.168.1.100" DESTINATION_HOST="192.168.1.101" \
./scripts/deploy-bastion.sh myapp example.com 3000
```

### Use hostnames from SSH config
```bash
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh
SOURCE_HOST="edge-prod" DESTINATION_HOST="node-steelgem" \
./scripts/deploy-bastion.sh myapp example.com 3000
```

## Configuration Methods (Choose One)

### Method 1: Environment Variables
```bash
SSH_HOST="192.168.1.100" SSH_USER="ubuntu" SSH_PORT="22" ./scripts/vps-setup.sh
```

### Method 2: .env File
```bash
cp .env.example .env
# Edit .env
./scripts/vps-setup.sh
```

### Method 3: SSH Config
```bash
# Add to ~/.ssh/config
Host sql-steelgem
    HostName 192.168.1.100
    User ubuntu
    Port 22

# Then use
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh
```

## Common Deployment Scenarios

### Local Setup (on target VPS)
```bash
sudo ./scripts/vps-setup.sh
```

### Remote Setup (from your laptop)
```bash
SSH_HOST="new-vps-ip" ./scripts/vps-setup.sh
```

### Setup Multiple Servers
```bash
for host in 192.168.1.100 192.168.1.101 192.168.1.102; do
  SSH_HOST="$host" ./scripts/deploy.sh web
done
```

### Production Deployment
```bash
# Create .env with all servers
cat > .env << EOF
SOURCE_HOST="192.168.1.100"
DESTINATION_HOST="192.168.1.101"
SSH_SUDOERS=true
INSTALL_TAILSCALE=true
EOF

# Deploy to both servers
SSH_HOST="192.168.1.100" ./scripts/deploy.sh production
SSH_HOST="192.168.1.101" ./scripts/deploy.sh production

# Deploy application
./scripts/deploy-bastion.sh myapp example.com 3000
```

## Troubleshooting

### Test SSH Connection
```bash
SSH_HOST="192.168.1.100" ssh ubuntu@192.168.1.100 "echo OK"
```

### Debug Remote Script Execution
```bash
SSH_HOST="192.168.1.100" ./scripts/vps-setup.sh --help
```

### Check if Server is Ready
```bash
ssh ubuntu@192.168.1.100 "curl -I http://localhost 2>/dev/null | head -1"
```

## Files Created/Modified

| File | Type | Purpose |
|------|------|---------|
| scripts/ssh-config.sh | NEW | SSH connection resolution |
| scripts/vps-setup.sh | MODIFIED | Remote execution support |
| scripts/deploy.sh | MODIFIED | Remote deployment |
| scripts/deploy-bastion.sh | MODIFIED | Dynamic hosts |
| .env.example | UPDATED | Configuration template |
| README.md | UPDATED | Documentation |
| IMPLEMENTATION-SUMMARY.md | NEW | Detailed changes |
| docs/DYNAMIC-SSH-GUIDE.md | NEW | Usage scenarios |

## Documentation

- **README.md** - Full documentation and usage guide
- **.env.example** - Configuration template with all options
- **docs/DYNAMIC-SSH-GUIDE.md** - 7 detailed scenarios with examples
- **IMPLEMENTATION-SUMMARY.md** - Technical implementation details

## Key Features

✅ No hardcoded aliases  
✅ Flexible configuration  
✅ Remote execution support  
✅ Multiple server support  
✅ Backward compatible  
✅ Standard SSH integration  

## Environment Variables Reference

### SSH Configuration
- `SSH_HOST` - Target hostname or IP (enables remote mode)
- `SSH_USER` - SSH username (default: ubuntu)
- `SSH_PORT` - SSH port (default: 22)

### Deployment Configuration
- `SOURCE_HOST` - Source server (default: edge-prod)
- `DESTINATION_HOST` - Destination server (default: node-steelgem)
- `SOURCE_PATH` - Path on source (default: /home/ubuntu/current)
- `DESTINATION_PATH` - Path on destination (default: /var/www/apps)

### VPS Configuration
- `UBUNTU_SUDOERS` - Grant sudoers to app user
- `INSTALL_TAILSCALE` - Install VPN (default: true)
- `INSTALL_NGINX` - Install web server (default: true)
- `TS_HOSTNAME` - Tailscale node name
- `TS_AUTHKEY` - Tailscale authentication key

## Next Steps

1. Read **docs/DYNAMIC-SSH-GUIDE.md** for detailed scenarios
2. Review **.env.example** for all configuration options
3. Run your first remote setup: `SSH_HOST="your-ip" ./scripts/vps-setup.sh`
4. Deploy applications: `./scripts/deploy-bastion.sh myapp example.com 3000`

Enjoy your new alias-free VPS workflow! 🚀
