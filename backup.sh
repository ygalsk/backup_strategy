#!/bin/bash
# borg-backup.sh - Simple backup of data directories to Hetzner

set -uo pipefail

HETZNER_REPO="ssh://hetzner-backup/home/backups"
LOG_FILE="/opt/alles/log/borg-backup.log"
DATA_ROOT="/opt/alles/soda4lca"

# Borg settings
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes
export BORG_RELOCATED_REPO_ACCESS_IS_OK=yes

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Backup a single data directory
backup_datafiles() {
    local datafiles_path="$1"
    local parent_dir=$(basename "$(dirname "$datafiles_path")")
    local repo="${HETZNER_REPO}/${parent_dir}"
    local archive="${parent_dir}-$(date +%Y-%m-%d_%H-%M-%S)"
    
    log "=== Backing up: $parent_dir ==="
    
    # Initialize repo if needed
    if ! borg info "$repo" &>/dev/null; then
        log "Initializing repo: $repo"
        borg init --encryption=none "$repo" || {
            log "ERROR: Failed to initialize repo"
            return 1
        }
    fi
    
    # Create backup
    log "Creating backup: $archive"
    borg create \
        --stats \
        --compression lz4 \
        "${repo}::${archive}" \
        "$datafiles_path" || {
        log "ERROR: Backup failed for $parent_dir"
        return 1
    }
    
    # Prune old backups
    log "Pruning old backups..."
    borg prune \
        --keep-daily=7 \
        --keep-weekly=4 \
        --keep-monthly=6 \
        "$repo"
    
    log "✓ Backup complete: $parent_dir"
}

# Main
main() {
    log "========== Backup started =========="
    
    # Find all directories containing 'datafiles'
    find "$DATA_ROOT" -type d -name "datafiles" | while read datafiles_dir; do
        backup_datafiles "$datafiles_dir"
    done
    
    log "========== All backups complete =========="
}

main "$@"