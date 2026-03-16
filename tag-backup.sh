#!/bin/bash

# Convenient Backup job, organized by tags
# By telnetdoogie. Includes AI slop.
# Todo:
#  * add pre/post script execution
#  * add --keep tags for running forget / prunes with the same script
#  * add functionality to run all tagged jobs.


echo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/backup-tags.json"

########################################
# Ensure running as root
########################################
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root."
    echo
    exit 1
fi

########################################
# Ensure RESTIC repository variable exists
########################################
if [[ -z "${RESTIC_REPOSITORY:-}" ]]; then
    echo "Error: RESTIC_REPOSITORY environment variable is not set."
    echo "This usually means root's restic environment has not been loaded."
    echo
    exit 1
fi

########################################
# Ensure config file exists
########################################
if [[ ! -r "$CONFIG_FILE" ]]; then
    echo "Error: Cannot read configuration file:"
    echo "  $CONFIG_FILE"
    echo
    exit 1
fi

########################################
# Ensure jq is installed
########################################
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed."
    echo
    exit 1
fi

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

########################################
# Check tag exists
########################################
if ! jq -e --arg tag "$TAG" '.tags[$tag]' "$CONFIG_FILE" >/dev/null; then
    echo "Error: Tag '$TAG' not found in configuration."
    echo
    exit 1
fi

########################################
# Load values
########################################
JOB_DESCRIPTION=$(jq -r --arg tag "$TAG" '.tags[$tag].job_description' "$CONFIG_FILE")
BACKUP_PATH=$(jq -r --arg tag "$TAG" '.tags[$tag].backup_path' "$CONFIG_FILE")
PRE_SCRIPT=$(jq -r --arg tag "$TAG" '.tags[$tag].pre_script // empty' "$CONFIG_FILE")
POST_SCRIPT=$(jq -r --arg tag "$TAG" '.tags[$tag].post_script // empty' "$CONFIG_FILE")
mapfile -t EXCLUDES < <(
    jq -r --arg tag "$TAG" '.tags[$tag].excludes[]? // empty' "$CONFIG_FILE"
)
RESTIC_ARGS=()
for exclude in "${EXCLUDES[@]}"; do
    RESTIC_ARGS+=(--exclude "$exclude")
done

########################################
# Run the job
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

restic backup --tag "$TAG" -x "$BACKUP_PATH" "${RESTIC_ARGS[@]}"

echo "Completed"