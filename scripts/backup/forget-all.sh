#!/bin/bash

source /etc/restic-env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/backup-tags.json"

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

set -euo pipefail
trap 'echo "***** $(date) ERROR: forget_all failed at line $LINENO *****" >&2' ERR

require_root
require_restic_env
require_config "$CONFIG_FILE"
require_jq

LOG="/var/log/backup.log"

{
    echo "================================================================"
    echo "===== $(date) STARTING FORGET_ALL ====="
    echo "================================================================"

    run_forget() {
        local name="$1"
        echo "===== $(date) START $name ====="
        /root/backup-scripts/tag-forget.sh "$name"
        echo "===== $(date) END $name ====="
    }

    # get all tags with a defined retention policy
    mapfile -t TAGS < <(
        jq -r '
            .tags
            | to_entries[]
            | select(.value.keep != null)
            | .key
        ' "${CONFIG_FILE}"
    )

    for tag in "${TAGS[@]}"; do
        run_forget "$tag"
    done

    echo "================================================================"
    echo "===== $(date) FINISHED FORGET_ALL ====="
    echo "================================================================"
} 2>&1 | tee -a "$LOG"