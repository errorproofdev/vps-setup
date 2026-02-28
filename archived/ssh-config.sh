#!/bin/bash

################################################################################
# SSH CONFIGURATION MODULE
# 
# Provides dynamic SSH connection resolution without hardcoded aliases
# Supports multiple configuration methods:
#   1. Environment variables (SSH_HOST, SSH_USER, SSH_PORT)
#   2. .env file configuration
#   3. SSH config file entries
#   4. Direct IP/hostname specification
#
# Usage in scripts:
#   source ./scripts/ssh-config.sh
#   SSH_CONN=$(resolve_ssh_host "sql-steelgem")
#   ssh $SSH_CONN "command here"
#
# Or with explicit parameters:
#   SSH_CONN=$(resolve_ssh_host "192.168.1.100" "ubuntu" "22")
#   scp -P "${SSH_PORT}" file.txt "$SSH_CONN:/path/to/file"
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default SSH configuration (can be overridden via environment)
SSH_DEFAULT_USER="${SSH_DEFAULT_USER:-ubuntu}"
SSH_DEFAULT_PORT="${SSH_DEFAULT_PORT:-22}"
SSH_CONFIG_FILE="${SSH_CONFIG_FILE:-${HOME}/.ssh/config}"

# Internal variables
export SSH_HOST=""
export SSH_USER=""
export SSH_PORT=""
export SSH_KEY=""

################################################################################
# LOGGING FUNCTIONS
################################################################################

_ssh_log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] SSH: $1${NC}" >&2
}

_ssh_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓ SSH: $1${NC}" >&2
}

_ssh_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ SSH: $1${NC}" >&2
}

_ssh_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗ SSH: $1${NC}" >&2
}

################################################################################
# PARSE SSH CONNECTION STRING
#
# Parses user@host:port format
# Returns: host port user
################################################################################
_parse_ssh_string() {
    local conn_string="$1"
    local user="${SSH_DEFAULT_USER}"
    local port="${SSH_DEFAULT_PORT}"
    local host=""

    # Extract user if present (user@host format)
    if [[ "$conn_string" == *"@"* ]]; then
        user="${conn_string%@*}"
        conn_string="${conn_string#*@}"
    fi

    # Extract port if present (host:port format)
    if [[ "$conn_string" == *":"* ]]; then
        host="${conn_string%:*}"
        port="${conn_string##*:}"
    else
        host="$conn_string"
    fi

    echo "$host $port $user"
}

################################################################################
# RESOLVE SSH HOST FROM SSH CONFIG
#
# Looks up host configuration from ~/.ssh/config
# Returns: user port key_file or empty if not found
################################################################################
_resolve_from_ssh_config() {
    local host_alias="$1"

    [[ ! -f "$SSH_CONFIG_FILE" ]] && return 1

    local section_found=false
    local config_user=""
    local config_port=""
    local config_key=""

    while IFS= read -r line; do
        # Check for matching host section
        if [[ "$line" =~ ^Host[[:space:]]+(.+)$ ]]; then
            section_found=false
            local hosts="${BASH_REMATCH[1]}"
            
            # Check if current host matches (supports wildcards)
            for h in $hosts; do
                if [[ "$h" == "$host_alias" ]]; then
                    section_found=true
                    break
                fi
            done
        elif $section_found; then
            # Extract configuration from matching section
            if [[ "$line" =~ ^[[:space:]]+User[[:space:]]+(.+)$ ]]; then
                config_user="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]+Port[[:space:]]+(.+)$ ]]; then
                config_port="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]+IdentityFile[[:space:]]+(.+)$ ]]; then
                config_key="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^Host[[:space:]] ]]; then
                # Reached next host section, stop searching
                break
            fi
        fi
    done < "$SSH_CONFIG_FILE"

    if $section_found; then
        echo "${config_user:-$SSH_DEFAULT_USER} ${config_port:-$SSH_DEFAULT_PORT} ${config_key:-}"
        return 0
    fi

    return 1
}

################################################################################
# RESOLVE SSH ENVIRONMENT VARIABLES
#
# Checks for SSH_* environment variables for host configuration
# Returns: user port key_file or empty if not found
################################################################################
_resolve_from_env() {
    local host="$1"
    local env_prefix="SSH_${host^^}"
    env_prefix="${env_prefix//-/_}"  # Convert hyphens to underscores

    # Check for SSH_HOSTNAME_USER, SSH_HOSTNAME_PORT, SSH_HOSTNAME_KEY
    local env_user="${env_prefix}_USER"
    local env_port="${env_prefix}_PORT"
    local env_key="${env_prefix}_KEY"

    local config_user="${!env_user:-}"
    local config_port="${!env_port:-}"
    local config_key="${!env_key:-}"

    if [[ -n "$config_user" || -n "$config_port" || -n "$config_key" ]]; then
        echo "${config_user:-$SSH_DEFAULT_USER} ${config_port:-$SSH_DEFAULT_PORT} ${config_key:-}"
        return 0
    fi

    return 1
}

################################################################################
# RESOLVE SSH HOST
#
# Resolves SSH connection details from multiple sources:
#   1. Direct parameters (user@host:port)
#   2. Environment variables (SSH_HOST, SSH_USER, SSH_PORT)
#   3. Hostname-specific env vars (SSH_HOSTNAME_USER, etc)
#   4. SSH config file (~/.ssh/config)
#   5. DNS/hostname resolution
#
# Usage:
#   resolve_ssh_host "hostname"                    # Use env/config
#   resolve_ssh_host "user@192.168.1.1:22"        # Direct params
#   resolve_ssh_host "sql-steelgem" "ubuntu" "22" # Explicit override
#
# Exports:
#   SSH_HOST - The resolved hostname/IP
#   SSH_USER - The SSH username
#   SSH_PORT - The SSH port
#   SSH_KEY  - The SSH private key (if configured)
################################################################################
resolve_ssh_host() {
    local host_ref="$1"
    local user_override="${2:-}"
    local port_override="${3:-}"
    local host="" port="" user=""

    _ssh_log "Resolving SSH host: $host_ref"

    # Parse direct connection string format (user@host:port)
    if [[ "$host_ref" =~ @ ]] || [[ "$host_ref" =~ : ]]; then
        read -r host port user <<< "$(_parse_ssh_string "$host_ref")"
        _ssh_log "Parsed connection string: host=$host user=$user port=$port"
    else
        host="$host_ref"
    fi

    # Try to resolve from SSH config file first
    if ! command -v ssh-keyscan &> /dev/null; then
        _ssh_warning "ssh-keyscan not available, skipping host key verification"
    fi

    local resolved=""
    if resolved=$(_resolve_from_ssh_config "$host" 2>/dev/null); then
        read -r user port ssh_key <<< "$resolved"
        _ssh_log "Found in SSH config: user=$user port=$port"
    fi

    # Try environment variables (SSH_HOSTNAME_USER, SSH_HOSTNAME_PORT, etc)
    if [[ -z "$user" ]] || [[ -z "$port" ]]; then
        if resolved=$(_resolve_from_env "$host" 2>/dev/null); then
            read -r env_user env_port env_key <<< "$resolved"
            user="${user:-$env_user}"
            port="${port:-$env_port}"
            ssh_key="${ssh_key:-$env_key}"
            [[ -n "${env_user}" ]] && _ssh_log "Found in environment variables"
        fi
    fi

    # Apply explicit overrides
    [[ -n "$user_override" ]] && user="$user_override"
    [[ -n "$port_override" ]] && port="$port_override"

    # Use defaults if still not set
    user="${user:-$SSH_DEFAULT_USER}"
    port="${port:-$SSH_DEFAULT_PORT}"

    # Validate host
    if [[ -z "$host" ]]; then
        _ssh_error "No host specified"
        return 1
    fi

    # Export resolved values
    export SSH_HOST="$host"
    export SSH_USER="$user"
    export SSH_PORT="$port"
    export SSH_KEY="${ssh_key:-}"

    _ssh_success "Resolved: $SSH_USER@$SSH_HOST:$SSH_PORT"

    echo "$SSH_USER@$SSH_HOST"
}

################################################################################
# VALIDATE SSH CONNECTION
#
# Tests connectivity to the specified SSH host
# Returns 0 if successful, 1 if failed
################################################################################
validate_ssh_connection() {
    local host="${SSH_HOST:-${1:-}}"
    local user="${SSH_USER:-${2:-$SSH_DEFAULT_USER}}"
    local port="${SSH_PORT:-${3:-$SSH_DEFAULT_PORT}}"

    if [[ -z "$host" ]]; then
        _ssh_error "No host provided to validate"
        return 1
    fi

    _ssh_log "Validating connection to $user@$host:$port..."

    if ssh -p "$port" "$user@$host" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "echo 'SSH connection successful'" > /dev/null 2>&1; then
        _ssh_success "Connection validated: $user@$host:$port"
        return 0
    else
        _ssh_error "Cannot connect to $user@$host:$port"
        return 1
    fi
}

################################################################################
# EXECUTE REMOTE COMMAND
#
# Executes a command on remote host with proper SSH connection handling
# Usage:
#   resolve_ssh_host "sql-steelgem"
#   ssh_exec "systemctl status nginx"
################################################################################
ssh_exec() {
    local command="$1"
    local host="${SSH_HOST:-}"
    local user="${SSH_USER:-$SSH_DEFAULT_USER}"
    local port="${SSH_PORT:-$SSH_DEFAULT_PORT}"

    if [[ -z "$host" ]]; then
        _ssh_error "No SSH host resolved. Call resolve_ssh_host first"
        return 1
    fi

    _ssh_log "Executing on $user@$host:$port: $command"
    ssh -p "$port" "$user@$host" "$command"
}

################################################################################
# COPY FILES TO REMOTE
#
# Copies files to remote host using scp
# Usage:
#   resolve_ssh_host "sql-steelgem"
#   ssh_copy_to "./local-file.txt" "/remote/path/"
################################################################################
ssh_copy_to() {
    local local_path="$1"
    local remote_path="$2"
    local host="${SSH_HOST:-}"
    local user="${SSH_USER:-$SSH_DEFAULT_USER}"
    local port="${SSH_PORT:-$SSH_DEFAULT_PORT}"

    if [[ -z "$host" ]]; then
        _ssh_error "No SSH host resolved. Call resolve_ssh_host first"
        return 1
    fi

    if [[ ! -e "$local_path" ]]; then
        _ssh_error "Local path does not exist: $local_path"
        return 1
    fi

    _ssh_log "Copying $local_path to $user@$host:$remote_path"
    scp -P "$port" -r "$local_path" "$user@$host:$remote_path"
}

################################################################################
# COPY FILES FROM REMOTE
#
# Copies files from remote host using scp
# Usage:
#   resolve_ssh_host "sql-steelgem"
#   ssh_copy_from "/remote/file.txt" "./local-path/"
################################################################################
ssh_copy_from() {
    local remote_path="$1"
    local local_path="$2"
    local host="${SSH_HOST:-}"
    local user="${SSH_USER:-$SSH_DEFAULT_USER}"
    local port="${SSH_PORT:-$SSH_DEFAULT_PORT}"

    if [[ -z "$host" ]]; then
        _ssh_error "No SSH host resolved. Call resolve_ssh_host first"
        return 1
    fi

    _ssh_log "Copying $user@$host:$remote_path to $local_path"
    scp -P "$port" -r "$user@$host:$remote_path" "$local_path"
}

################################################################################
# GET SSH CONNECTION STRING
#
# Returns properly formatted SSH connection string with options
# Usage:
#   resolve_ssh_host "sql-steelgem"
#   ssh_connection_string  # Returns: -p 22 ubuntu@hostname
################################################################################
ssh_connection_string() {
    local host="${SSH_HOST:-}"
    local user="${SSH_USER:-$SSH_DEFAULT_USER}"
    local port="${SSH_PORT:-$SSH_DEFAULT_PORT}"

    if [[ -z "$host" ]]; then
        _ssh_error "No SSH host resolved. Call resolve_ssh_host first"
        return 1
    fi

    echo "-p $port $user@$host"
}

################################################################################
# DISPLAY SSH CONFIGURATION
#
# Shows currently resolved SSH configuration
################################################################################
ssh_show_config() {
    echo "Current SSH Configuration:"
    echo "  Host:  ${SSH_HOST:-<not resolved>}"
    echo "  User:  ${SSH_USER:-$SSH_DEFAULT_USER}"
    echo "  Port:  ${SSH_PORT:-$SSH_DEFAULT_PORT}"
    echo "  Key:   ${SSH_KEY:-<default>}"
    echo ""
    echo "Configuration priority:"
    echo "  1. Direct parameters (user@host:port format)"
    echo "  2. SSH config file: $SSH_CONFIG_FILE"
    echo "  3. Environment variables: SSH_{HOSTNAME}_USER/PORT/KEY"
    echo "  4. Defaults: user=$SSH_DEFAULT_USER port=$SSH_DEFAULT_PORT"
}

# Export public functions
export -f resolve_ssh_host
export -f validate_ssh_connection
export -f ssh_exec
export -f ssh_copy_to
export -f ssh_copy_from
export -f ssh_connection_string
export -f ssh_show_config
