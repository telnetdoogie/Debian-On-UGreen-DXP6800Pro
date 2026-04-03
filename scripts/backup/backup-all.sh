#!/bin/bash

set -euo pipefail
trap 'echo "***** $(date) ERROR: backup_all failed at line $LINENO *****" >&2' ERR

LOG="/var/log/backup.log"

{
    echo "================================================================"
    echo "===== $(date) STARTING BACKUP_ALL ====="
    echo "================================================================"

    run_backup() {
        local name="$1"
        echo "===== $(date) START $name ====="
        /root/backup-scripts/tag-backup.sh "$name"
        echo "===== $(date) END $name ====="
    }

    run_backup docker
    run_backup home
    run_backup rootfs
    run_backup scripts
    run_backup backup
    run_backup installs
    run_backup media

    echo "================================================================"
    echo "===== $(date) FINISHED BACKUP_ALL ====="
    echo "================================================================"
} >> "$LOG" 2>&1
