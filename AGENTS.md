# VPS Setup - Agents Guide

This repository contains Bash shell scripts for automated VPS configuration on Ubuntu 24.04. All agents working with this codebase should follow these guidelines.

## Project Structure

- `scripts/vps-setup.sh` - Main setup script (core system configuration)
- `scripts/deploy.sh` - Deployment orchestrator with predefined configurations
- `scripts/services.sh` - Optional service installation modules
- `README.md` - Comprehensive documentation

## Build/Test/Execute Commands

### Running Scripts

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run main setup script (requires root)
sudo ./scripts/vps-setup.sh

# Run deployment configurations
sudo ./scripts/deploy.sh [config]  # minimal|web|database|dev|production|cicd|full

# Install individual services
./scripts/services.sh [service]     # mysql|php|nginx|docker|etc.
```

### Testing

- No automated test framework - scripts must be tested on actual Ubuntu 24.04 systems
- Validate scripts in a VM/container before production deployment
- Test with `bash -n` for syntax checking: `bash -n scripts/vps-setup.sh`

### Validation

- Check script exit codes: `echo $?`
- Verify service status: `systemctl status [service]`
- Test firewall rules: `ufw status verbose`
- Validate configurations: `nginx -t`, `mysql --help`, etc.

## Code Style Guidelines

### Shell Scripting Standards

- Use `#!/bin/bash` shebang (not `#!/bin/sh`)
- Always include `set -euo pipefail` at the top of scripts
- Use functions for logical organization (max 50 lines per function)
- Quote all variables: `"$VAR"` not `$VAR`
- Use `[[ ]]` for conditional tests, not `[ ]`
- Use `local` for function-scoped variables

### Error Handling

- All functions must handle errors appropriately
- Use descriptive error messages with color coding
- Exit with non-zero status on failure
- Implement proper cleanup on errors where needed
- Always backup configuration files before modification

### Logging Standards

- Use the standardized logging functions:

  ```bash
  log()      # Blue informational messages
  success()  # Green success messages  
  warning()  # Yellow warnings
  error()    # Red errors
  ```

- Include timestamps in all log messages
- Use consistent formatting: `[TIMESTAMP] message`

### Variable Naming

- Use UPPER_CASE for global constants and configuration variables
- Use lower_case for local variables
- Prefix private/internal variables with underscore: `_internal_var`
- Configuration variables should be grouped at script top

### Import/Source Conventions

- No external imports - all functionality self-contained
- Source external scripts only when necessary: `source ./config.sh`
- Use absolute paths for system binaries: `/usr/bin/nginx`

### Function Organization

- Order functions alphabetically or by logical dependency
- Use descriptive function names: `install_nginx()` not `nginx()`
- Each function should have a single responsibility
- Include brief comment describing function purpose

### Security Practices

- Never log passwords or sensitive data
- Validate user inputs in scripts
- Use `mktemp` for temporary files
- Set proper file permissions: `chmod 600` for config files
- Avoid eval and command injection vulnerabilities

### Configuration Management

- All configurable variables at script top
- Use meaningful defaults where possible
- Allow environment variable overrides
- Document configuration options in comments

### Script Portability

- Target Ubuntu 24.04 specifically (document limitations)
- Use standard POSIX commands where possible
- Check command existence before use: `command -v nginx`
- Handle different package managers gracefully

### Documentation

- Include script header with purpose, author, requirements
- Document complex logic with inline comments
- Maintain usage examples in comments
- Update README when adding new services

## Service Installation Patterns

### Package Management

```bash
# Update before installing
apt-get update -y

# Install with specific version when possible
apt-get install -y package_name=version

# Clean up after installation
apt-get autoremove -y
apt-get autoclean
```

### Service Management

```bash
# Enable and start services
systemctl enable service_name
systemctl restart service_name

# Verify service status
systemctl status service_name
```

### Configuration File Pattern

```bash
# Backup original
cp /etc/service/config /etc/service/config.backup.$(date +%Y%m%d)

# Create new config
cat > /etc/service/config << 'EOF'
# Configuration content
EOF

# Test configuration
service_name -t
```

## Code Review Checklist

- [ ] Scripts use `set -euo pipefail`
- [ ] All variables are properly quoted
- [ ] Error handling implemented for external commands
- [ ] Configuration files backed up before modification
- [ ] Logging functions used consistently
- [ ] Sensitive data not logged or hardcoded
- [ ] Functions are properly scoped with `local` variables
- [ ] Script tested on Ubuntu 24.04
- [ ] Documentation updated for new features

## Common Pitfalls to Avoid

- Don't use `sudo` inside functions that are already run as root
- Avoid hardcoding paths - use variables for configurability
- Don't ignore command output unless intentional
- Avoid creating files in /tmp without cleanup
- Don't modify system-wide settings without user consent
- Avoid using deprecated commands or options

## Development Workflow

1. Test script syntax: `bash -n script.sh`
2. Test in isolated environment (VM/container)
3. Validate all service installations work correctly
4. Test error scenarios and edge cases
5. Update documentation and README
6. Commit with descriptive message following pattern: `feat: add new service installation`
