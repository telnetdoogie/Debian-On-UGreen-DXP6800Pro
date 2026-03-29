#!/bin/bash

set -euo pipefail
trap 'echo "***** $(date) ERROR: backup-prune failed at line $LINENO *****" >&2' ERR

source /etc/restic-env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMMON_FILE="$SCRIPT_DIR/backup_common.sh"
if [[ ! -r "$COMMON_FILE" ]]; then
    echo "Error: Required library not found: $COMMON_FILE"
    echo
    exit 1
fi

if ! source "$COMMON_FILE"; then
    echo "Error: Failed to load common library: $COMMON_FILE"
    echo
    exit 1
fi

require_root
require_restic_env

LOG="/var/log/backup.log"

{
    echo "================================================================"
    echo "===== $(date) STARTING RESTIC PRUNE  ====="
    echo "================================================================"

    restic prune --dry-run
    # move to the below when you're ready for the big league
    # restic prune

    echo "================================================================"
    echo "===== $(date) FINISHED RESTIC PRUNE ====="
    echo "================================================================"
} 2>&1 | tee -a "$LOG"