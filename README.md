<!-- markdownlint-disable MD022 MD031 MD032 MD046 -->

# VPS Configuration Script

> ⚠️ **Important:** the canonical, up‑to‑date deployment scripts now live in the
> `secured/` directory. All `scripts/*.sh` and other top‑level helpers are
> legacy – they remain in the tree for historical reference but should not be
> used for new deployments. See
> `docs/SECURE-NON-ROOT-DEPLOYMENT.md` for the primary workflow and refer to
> `secured/configure.sh` as the current installer.

A comprehensive setup script for Ubuntu 24.04 VPS instances that configures core infrastructure services with **dynamic SSH support** for both local and remote execution.

## Features

- ✅ **Dynamic SSH** - No hardcoded aliases, supports IP addresses, hostnames, and SSH config entries
- ✅ System updates and security hardening
- ✅ Ubuntu user creation with proper permissions
- ✅ SSH configuration with security settings
- ✅ Tailscale installation and setup
- ✅ UFW firewall configuration (ports 22, 80, 443)
- ✅ NGINX web server installation and basic configuration
- ✅ Fail2ban intrusion prevention
- ✅ Root access maintained

## Requirements

- Ubuntu 24.04 LTS
- Internet connection
- SSH access to target servers (for remote execution)

## Quick Start

### Local Execution (on target VPS)

```bash
# Clone the repo and run the main setup script
git clone https://your-repo/vps-setup.git
cd vps-setup
chmod +x scripts/*.sh
sudo ./scripts/vps-setup.sh
```

### Remote Execution (from local machine)

The easiest way - no sudo needed locally!

> 🔐 **Secure App Deployment**: All application processes are run as a
> non-root `appuser`, listening on localhost-only TCP ports with NGINX
> proxying through Unix sockets. See
> [`docs/SECURE-NON-ROOT-DEPLOYMENT.md`](docs/SECURE-NON-ROOT-DEPLOYMENT.md)
> for the 12-step guide and security rationale.

# Using environment variables
SSH_HOST="192.168.1.100" \
SSH_USER="ubuntu" \
SSH_PORT="22" \
./scripts/vps-setup.sh

# Or with configuration file
cp .env.example .env
# Edit .env with your SSH credentials
./scripts/vps-setup.sh
```

## Dynamic SSH Configuration

Instead of relying on hardcoded SSH aliases like `ssh sql-steelgem`, the scripts now support three flexible configuration methods:

### Method 1: Environment Variables (Simplest)

```bash
# Direct IP address
SSH_HOST="192.168.1.100" \
SSH_USER="ubuntu" \
SSH_PORT="22" \
./scripts/vps-setup.sh

# Or hostname (requires DNS or ~/.ssh/config)
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh
```

## Method 2: Configuration File (.env)

```bash
# Copy the example configuration
cp .env.example .env

# Edit .env with your settings
cat .env
# SSH_HOST="192.168.1.100"
# SSH_USER="ubuntu"
# SSH_PORT="22"

# Run scripts without passing environment variables
./scripts/vps-setup.sh
```

### Method 3: SSH Config File

Configure hosts in `~/.ssh/config`:

```bash
Host sql-steelgem
    HostName 192.168.1.100
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa

Host edge-prod
    HostName 192.168.1.101
    User ubuntu
    Port 2222
    IdentityFile ~/.ssh/id_rsa_edge
```

Then run:

```bash
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh
SSH_HOST="edge-prod" ./scripts/vps-setup.sh
```

## Script Usage Examples

### vps-setup.sh - VPS Configuration

```bash
# Local execution
sudo ./scripts/vps-setup.sh

# Remote execution with IP
SSH_HOST="192.168.1.100" ./scripts/vps-setup.sh

# Remote with custom configuration
SSH_HOST="sql-steelgem" \
UBUNTU_SUDOERS=true \
UBUNTU_SUDOERS_CMDS="/usr/bin/systemctl,/usr/sbin/nginx" \
./scripts/vps-setup.sh

# Remote with Tailscale setup
SSH_HOST="192.168.1.100" \
TAILSCALE_AUTH_KEY="tskey-..." \
TAILSCALE_HOSTNAME="node-steelgem" \
./scripts/vps-setup.sh
```

### deploy.sh - Deployment Configurations

```bash
# Local execution (requires root)
sudo ./scripts/deploy.sh web         # Deploy web server
sudo ./scripts/deploy.sh production  # Deploy production server

# Remote execution (no local root needed!)
SSH_HOST="192.168.1.100" ./scripts/deploy.sh web
SSH_HOST="sql-steelgem" ./scripts/deploy.sh minimal
```

Available configurations:

- `minimal` - Core system only
- `web` - Web server (PHP, SSL)
- `database` - Database server (MySQL, PostgreSQL, Redis)
- `dev` - Development environment
- `production` - Production-ready with monitoring
- `cicd` - CI/CD server
- `full` - Complete stack

### deploy-bastion.sh - Application Deployment

```bash
# Deployment between two servers
SOURCE_HOST="192.168.1.100" \
DESTINATION_HOST="192.168.1.101" \
./scripts/deploy-bastion.sh myapp example.com 3000

# Or with .env configuration
./scripts/deploy-bastion.sh myapp example.com 3000

# With SSH config hostnames
SOURCE_HOST="edge-prod" \
DESTINATION_HOST="node-steelgem" \
./scripts/deploy-bastion.sh myapp example.com 3000
```

## SSH Configuration Priority

When resolving SSH connections, the scripts check in this order:

1. **Command-line arguments** (highest priority)

```bash
SSH_HOST="192.168.1.1" SSH_USER="ubuntu" SSH_PORT="22" ./script.sh
```

1. **.env file**

```bash
# In .env
SSH_HOST="sql-steelgem"
SSH_USER="ubuntu"
```

1. **~/.ssh/config file**

```bash
# ~/.ssh/config entries
Host sql-steelgem
    HostName 192.168.1.100
    User ubuntu
```

1. **Script defaults** (lowest priority)

- User: `ubuntu`
- Port: `22`

## Using SSH Config for Multiple Servers

Create entries in `~/.ssh/config` for all your servers:

```bash
# Production web server
Host web-prod
    HostName 192.168.1.100
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa_prod

# Database server
Host db-prod
    HostName 192.168.1.101
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa_prod

# Development server
Host dev-server
    HostName 192.168.1.102
    User developer
    Port 2222
    IdentityFile ~/.ssh/id_rsa_dev
```

Then run scripts easily:

```bash
# Setup web server
SSH_HOST="web-prod" ./scripts/vps-setup.sh

# Setup database server
SSH_HOST="db-prod" ./scripts/vps-setup.sh

# Deploy to dev
SSH_HOST="dev-server" ./scripts/deploy.sh web
```

## Configuration Variables

### SSH Configuration

| Variable | Default | Description |
| --- | --- | --- |
| SSH_HOST | (empty) | Target hostname or IP (enables remote mode) |
| SSH_USER | ubuntu | SSH username |
| SSH_PORT | 22 | SSH port |
| SSH_DEFAULT_USER | ubuntu | Default user for unspecified hosts |
| SSH_DEFAULT_PORT | 22 | Default port for unspecified hosts |

### VPS Setup Variables

| Variable | Default | Description |
| --- | --- | --- |
| UBUNTU_USER | ubuntu | System user to create |
| UBUNTU_SUDO | false | Grant full sudo privileges |
| UBUNTU_SUDOERS | false | Create sudoers rule for specific commands |
| UBUNTU_SUDOERS_CMDS | systemctl,pm2,nginx,apt-get | Commands allowed via sudo |
| INSTALL_TAILSCALE | true | Install Tailscale VPN |
| INSTALL_NGINX | true | Install NGINX web server |
| ALLOW_PUBLIC_SSH | false | Allow SSH over public internet |
| TAILSCALE_HOSTNAME | node-steelgem | Tailscale node name |
| TAILSCALE_AUTH_KEY | (empty) | Tailscale authentication key |

### Deployment Variables

| Variable | Default | Description |
| --- | --- | --- |
| SOURCE_HOST | edge-prod | Source server for code (deploy-bastion) |
| DESTINATION_HOST | node-steelgem | Destination server (deploy-bastion) |
| SOURCE_PATH | /home/ubuntu/current | Path on source |
| DESTINATION_PATH | /var/www/apps | Path on destination |

## NextJS Application Migration

For migrating Next.js applications from EC2 to this VPS, see [docs/NEXTJS-DEPLOYMENT.md](docs/NEXTJS-DEPLOYMENT.md) for:

- Automated migration functions
- Node.js version management via NVM
- NGINX configuration for reverse proxying
- PM2 process management
- SSL certificate setup (Cloudflare origin certs)
- Testing and troubleshooting

**Quick start for first app migration:**

```bash
# NextJS functions are included in scripts/services.sh
SSH_HOST="sql-steelgem" ./scripts/services.sh nvm              # Install NVM
SSH_HOST="sql-steelgem" ./scripts/services.sh nextjs-nginx     # Optimize NGINX
SSH_HOST="sql-steelgem" ./scripts/services.sh nextjs-ssl       # Install Cloudflare certs
```

## What Gets Installed

### System Packages

- Core utilities (curl, wget, git, vim, htop, etc.)
- Build tools
- Security tools (fail2ban)

### Services

- **SSH**: Hardened configuration with root access maintained
- **UFW**: Firewall allowing ports 22, 80, 443
- **NGINX**: Web server with basic optimization
- **Fail2ban**: Brute force protection
- **Tailscale**: VPN for secure access (optional)

### User Management

- Creates `ubuntu` user (sudo optional via UBUNTU_SUDO)
- Sets up SSH directory structure
- Copies root's SSH keys if present

## Security Features

- Firewall with only necessary ports open
- SSH hardening
- Fail2ban for intrusion prevention
- Regular security updates
- No unnecessary services running

## Post-Setup Steps

1. **Configure Tailscale** (if installed):

```bash
sudo tailscale up
```

1. **Set up SSH keys** for the ubuntu user:

```bash
ssh-copy-id ubuntu@your-server-ip
```

1. **Test services**:

```bash
# Check NGINX
curl http://localhost

# Check firewall status
sudo ufw status

# Check fail2ban
sudo systemctl status fail2ban
```

1. **Configure your applications**:
   - Add your website files to `/var/www/html/`
   - Configure NGINX virtual hosts
   - Install additional services (MySQL, PostgreSQL, etc.)

## File Locations

| Service | Configuration | Logs | Data |
 | --- | ---: | ---: | ---: |
| NGINX | /etc/nginx/ | /var/log/nginx/ | /var/www/html/ |
| SSH | /etc/ssh/sshd_config | /var/log/auth.log | - |
| UFW | /etc/ufw/ | - | - |
| Fail2ban | /etc/fail2ban/ | /var/log/fail2ban.log | - |

## Troubleshooting

### SSH Issues

```bash
# Check SSH status
sudo systemctl status sshd

# View SSH logs
sudo journalctl -u sshd
```

### Firewall Issues

```bash
# Check firewall status
sudo ufw status verbose

# Reset firewall if needed
sudo ufw --force reset
```

### NGINX Issues

```bash
# Test configuration
sudo nginx -t

# Check NGINX status
sudo systemctl status nginx

# View error logs
sudo tail -f /var/log/nginx/error.log
```

## Security Recommendations

1. **Regular Updates**: Keep the system updated
2. **SSH Keys**: Use SSH key authentication instead of passwords
3. **Backups**: Set up regular backups
4. **Monitoring**: Set up monitoring for your services
5. **Least Privilege**: Run services with minimal required permissions

## Customization

### Adding Services

To install additional services, add functions to the script:

```bash
install_mysql() {
    log "Installing MySQL..."
    apt-get install -y mysql-server
    systemctl enable mysql
    systemctl start mysql
    success "MySQL installed successfully"
}

# Add to main() function:
install_mysql
```

### Modifying Firewall Rules

Edit the `configure_firewall()` function to add/remove ports:

```bash
# Allow custom port
ufw allow 8080/tcp comment "Custom Application"

# Allow specific IP
ufw allow from 192.168.1.100 to any port 22
```

## License

This script is provided as-is for educational and production use. Modify as needed for your specific requirements.

## Support

For issues or questions:

1. Check the troubleshooting section
2. Review system logs: `journalctl -f`
3. Test individual services: `systemctl status [service-name]`
