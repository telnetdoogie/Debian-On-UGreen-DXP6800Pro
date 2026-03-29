#!/bin/bash
# Convenient "restic backup" job, organized by tags
# By telnetdoogie. Includes AI slop.
# Todo:
#  * make pre/post script execution more robust / safe

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
    echo "Available backup tags:"
    echo

    jq -r '
        .tags
        | to_entries[]
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
# Load values
########################################
JOB_DESCRIPTION=$(jq -r --arg tag "$TAG" '.tags[$tag].job_description' "$CONFIG_FILE")
BACKUP_PATH=$(jq -r --arg tag "$TAG" '.tags[$tag].backup_path' "$CONFIG_FILE")
PRE_SCRIPT=$(jq -r --arg tag "$TAG" '.tags[$tag].pre_script // empty' "$CONFIG_FILE")
POST_SCRIPT=$(jq -r --arg tag "$TAG" '.tags[$tag].post_script // empty' "$CONFIG_FILE")
mapfile -t EXCLUDES < <(
    jq -r --arg tag "$TAG" '.tags[$tag].excludes // [] | .[]' "$CONFIG_FILE" || true
)
RESTIC_ARGS=()
for exclude in "${EXCLUDES[@]}"; do
    RESTIC_ARGS+=(--exclude "$exclude")
done

########################################
# Output job details
########################################
echo "Running backup job:"
echo "  Tag:           $TAG"
echo "  Description:   $JOB_DESCRIPTION"
echo "  Path:          $BACKUP_PATH"
echo "  Excludes:"
if [[ ${#EXCLUDES[@]} -eq 0 ]]; then
    echo "    (none)"
else
    for e in "${EXCLUDES[@]}"; do
        echo "    - $e"
    done
fi
echo

########################################
# Run pre-script if present
########################################
if [[ -n "$PRE_SCRIPT" ]]; then
    echo "Running pre-script:"
    echo "  $PRE_SCRIPT"
    echo
    eval "$PRE_SCRIPT"
    echo
fi

########################################
# Run the backup
########################################

restic backup --tag "$TAG" -x "$BACKUP_PATH" "${RESTIC_ARGS[@]}"

########################################
# Run post-script if present
########################################
if [[ -n "$POST_SCRIPT" ]]; then
    echo
    echo "Running post-script:"
    echo "  $POST_SCRIPT"
    echo
    eval "$POST_SCRIPT"
    echo
fi

echo "Completed"
echo