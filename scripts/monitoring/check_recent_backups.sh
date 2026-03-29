#!/bin/bash
set -euo pipefail

source /etc/restic-env
CONFIG_DIR="/root/backup-scripts"
CONFIG_FILE="$CONFIG_DIR/backup-tags.json"
COMMON_FILE="$CONFIG_DIR/backup_common.sh"

if [[ ! -r "$COMMON_FILE" ]]; then
    echo "Error: Required library not found: $COMMON_FILE"
    echo
    exit 1
fi

# shellcheck disable=SC1090
if ! source "$COMMON_FILE"; then
    echo "Error: Failed to load common library: $COMMON_FILE"
    echo
    exit 1
fi

require_root
require_restic_env
require_config "$CONFIG_FILE"
require_jq

MAX_AGE_HOURS=26

fail=0

# get tags that should be backed up (i.e., have backup_path)
mapfile -t TAGS < <(
    jq -r '
        .tags
        | to_entries[]
        | select(.value.backup_path != null)
        | .key
    ' "$CONFIG_FILE"
)

for tag in "${TAGS[@]}"; do
    LAST=$(restic snapshots --tag "$tag" --json 2>/dev/null | jq -r '.[-1].time' || true)

    if [[ -z "$LAST" || "$LAST" == "null" ]]; then
        echo "Tag '$tag': no snapshots found"
        fail=1
        continue
    fi

    LAST_EPOCH=$(date -d "$LAST" +%s)
    NOW=$(date +%s)
    AGE_HOURS=$(( (NOW - LAST_EPOCH) / 3600 ))

    if (( AGE_HOURS > MAX_AGE_HOURS )); then
        echo "Tag '$tag': last backup ${AGE_HOURS}h ago (threshold ${MAX_AGE_HOURS})"
        fail=1
    else
        echo "Tag '$tag': OK (${AGE_HOURS}h ago)"
    fi
done

exit $fail