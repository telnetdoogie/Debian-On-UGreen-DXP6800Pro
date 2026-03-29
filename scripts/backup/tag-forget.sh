#!/bin/bash
# Convenient "restic forget" job, organized by tags
# By telnetdoogie. Includes AI slop.
# Todo:
# *

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

echo
set -euo pipefail

require_root
require_restic_env
require_config "$CONFIG_FILE"
require_jq

########################################
# If no parameters supplied, list tags
########################################
if [[ $# -eq 0 ]]; then
    echo "Available tags with retention policies:"
    echo

    jq -r '
        .tags
        | to_entries[]
        | select(.value.keep != null)
        | "\(.key)\t\(.value.job_description)"
    ' "$CONFIG_FILE" \
    | column -t -s $'\t'
    echo
    echo "Usage:"
    echo "  $0 <tag>"
    echo
    exit 0
fi

TAG="$1"

require_tag_exists "$TAG" "$CONFIG_FILE"


########################################
# Check keep exists
########################################
if ! jq -e --arg tag "$TAG" '.tags[$tag].keep' "$CONFIG_FILE" >/dev/null; then
    echo "Skipping retention for tag '$TAG' (no keep policy defined)"
    echo
    exit 0
fi

########################################
# Load keep values
########################################
KEEP_DAILY=$(jq -r --arg tag "$TAG" '.tags[$tag].keep.daily // empty' "$CONFIG_FILE")
KEEP_WEEKLY=$(jq -r --arg tag "$TAG" '.tags[$tag].keep.weekly // empty' "$CONFIG_FILE")
KEEP_MONTHLY=$(jq -r --arg tag "$TAG" '.tags[$tag].keep.monthly // empty' "$CONFIG_FILE")
KEEP_YEARLY=$(jq -r --arg tag "$TAG" '.tags[$tag].keep.yearly // empty' "$CONFIG_FILE")

########################################
# Build restic args
########################################
RESTIC_ARGS=(--tag "$TAG")

[[ -n "$KEEP_DAILY" ]]   && RESTIC_ARGS+=(--keep-daily "$KEEP_DAILY")
[[ -n "$KEEP_WEEKLY" ]]  && RESTIC_ARGS+=(--keep-weekly "$KEEP_WEEKLY")
[[ -n "$KEEP_MONTHLY" ]] && RESTIC_ARGS+=(--keep-monthly "$KEEP_MONTHLY")
[[ -n "$KEEP_YEARLY" ]]  && RESTIC_ARGS+=(--keep-yearly "$KEEP_YEARLY")

########################################
# Output job details
########################################
echo "Running retention job:"
echo "  Tag:           $TAG"
echo "  Keep policy:"
[[ -n "$KEEP_DAILY" ]]   && echo "    daily:   $KEEP_DAILY"
[[ -n "$KEEP_WEEKLY" ]]  && echo "    weekly:  $KEEP_WEEKLY"
[[ -n "$KEEP_MONTHLY" ]] && echo "    monthly: $KEEP_MONTHLY"
[[ -n "$KEEP_YEARLY" ]]  && echo "    yearly:  $KEEP_YEARLY"
echo

########################################
# Run forget (NO PRUNE HERE)
########################################
restic forget "${RESTIC_ARGS[@]}" --dry-run

echo
echo "Retention applied (no prune performed)"
echo