#!/bin/bash

################################################################################
# Dotfile Backup Script
# Purpose: Find and copy all dotfiles from home directory for macbook migration
# Author: Joseph Vore
# Requirements: bash, find, cp commands
################################################################################

set -euo pipefail

# Configuration
BACKUP_DIR="${1:-.}/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
HOME_DIR="${HOME}"
EXCLUDE_PATTERNS=(
    ".git"
    ".cache"
    ".npm"
    ".npm-global"
    ".cargo/registry"
    ".rustup"
    "node_modules"
    ".gradle"
    ".m2"
    "Library/Caches"
    "Library/Saved Application State"
)

# Logging Functions
log() {
    echo -e "\033[36m[$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $*"
}

success() {
    echo -e "\033[32m[$(date '+%Y-%m-%d %H:%M:%S')] ✓\033[0m $*"
}

warning() {
    echo -e "\033[33m[$(date '+%Y-%m-%d %H:%M:%S')] ⚠\033[0m $*"
}

error() {
    echo -e "\033[31m[$(date '+%Y-%m-%d %H:%M:%S')] ✗\033[0m $*" >&2
}

# Show usage information
usage() {
    cat << 'EOF'
Usage: ./backup-dotfiles.sh [BACKUP_DIR]

Purpose: Find and copy all dotfiles from home directory for macbook migration

Arguments:
  BACKUP_DIR    Directory to store backups (default: ./dotfiles-backup-TIMESTAMP)

Examples:
  ./backup-dotfiles.sh                    # Creates backup in current directory
  ./backup-dotfiles.sh ~/migration-backup # Creates backup in specified directory
  ./backup-dotfiles.sh /tmp/dotfiles      # Creates backup in /tmp

The script will:
  - Find all dotfiles (files/dirs starting with .) in your home directory
  - Exclude cache directories and large dependency folders
  - Preserve directory structure
  - Report what was backed up
EOF
}

# Check if path should be excluded
should_exclude() {
    local _path="$1"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$_path" == *"$pattern"* ]]; then
            return 0  # true - should exclude
        fi
    done
    return 1  # false - don't exclude
}

# Create backup directory
setup_backup_dir() {
    if [[ -e "$BACKUP_DIR" ]]; then
        error "Backup directory already exists: $BACKUP_DIR"
        return 1
    fi
    
    if mkdir -p "$BACKUP_DIR"; then
        success "Created backup directory: $BACKUP_DIR"
    else
        error "Failed to create backup directory: $BACKUP_DIR"
        return 1
    fi
}

# Count dotfiles before backup
count_dotfiles() {
    local _count=0
    for _dotfile in "$HOME_DIR"/.*; do
        [[ "$_dotfile" == "$HOME_DIR"/. ]] || [[ "$_dotfile" == "$HOME_DIR"/.. ]] && continue
        should_exclude "$_dotfile" && continue
        ((_count++))
    done
    echo "$_count"
}

# Backup all dotfiles
backup_dotfiles() {
    local _total=0
    local _backed_up=0
    local _failed=0
    
    log "Starting dotfile backup from: $HOME_DIR"
    
    # Find and copy all dotfiles
    for _dotfile in "$HOME_DIR"/.*; do
        # Skip . and ..
        [[ "$_dotfile" == "$HOME_DIR"/. ]] || [[ "$_dotfile" == "$HOME_DIR"/.. ]] && continue
        
        # Skip excluded patterns
        should_exclude "$_dotfile" && continue
        
        ((_total++))
        
        local _relative_path
        _relative_path="${_dotfile#$HOME_DIR/}"
        
        local _backup_path="$BACKUP_DIR/$_relative_path"
        local _backup_parent
        _backup_parent=$(dirname "$_backup_path")
        
        # Create parent directory structure
        if ! mkdir -p "$_backup_parent" 2>/dev/null; then
            warning "Failed to create directory: $_backup_parent"
            ((_failed++))
            continue
        fi
        
        # Copy file or directory
        if cp -rP "$_dotfile" "$_backup_path" 2>/dev/null; then
            ((_backed_up++))
            log "Backed up: $_relative_path"
        else
            warning "Failed to backup: $_relative_path"
            ((_failed++))
        fi
    done
    
    # Summary
    echo ""
    success "Backup complete!"
    log "Total dotfiles found: $_total"
    log "Successfully backed up: $_backed_up"
    if [[ $_failed -gt 0 ]]; then
        warning "Failed to backup: $_failed"
    fi
    log "Backup location: $BACKUP_DIR"
    
    # Show sample of backed up items
    echo ""
    log "Sample of backed up items:"
    ls -la "$BACKUP_DIR" | tail -10
}

# Validate backup integrity
validate_backup() {
    log "Validating backup..."
    
    local _file_count
    _file_count=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l)
    
    local _dir_count
    _dir_count=$(find "$BACKUP_DIR" -type d 2>/dev/null | wc -l)
    
    if [[ $_file_count -gt 0 ]] || [[ $_dir_count -gt 1 ]]; then
        success "Backup validated: $_file_count files in $_dir_count directories"
        return 0
    else
        error "Backup appears empty"
        return 1
    fi
}

# Main execution
main() {
    if [[ ${1:-} == "-h" ]] || [[ ${1:-} == "--help" ]]; then
        usage
        return 0
    fi
    
    log "Dotfile Backup Utility"
    echo ""
    log "Excluded patterns: ${EXCLUDE_PATTERNS[*]}"
    echo ""
    
    # Setup
    if ! setup_backup_dir; then
        return 1
    fi
    
    # Count and backup
    local _dotfile_count
    _dotfile_count=$(count_dotfiles)
    log "Found $_dotfile_count dotfiles to backup"
    echo ""
    
    # Perform backup
    backup_dotfiles
    
    # Validate
    echo ""
    if ! validate_backup; then
        warning "Backup validation failed"
        return 1
    fi
    
    success "Migration backup ready for transfer!"
}

# Execute main function
main "$@"
