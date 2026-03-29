#!/bin/bash

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root."
        echo
        exit 1
    fi
}

require_restic_env() {
    if [[ -z "${RESTIC_REPOSITORY:-}" ]]; then
        echo "Error: RESTIC_REPOSITORY is not set."
        echo
        exit 1
    fi
}

require_config() {
    local config="$1"
    if [[ ! -r "$config" ]]; then
        echo "Error: Cannot read configuration file: $config"
        echo
        exit 1
    fi
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required but not installed."
        echo
        exit 1
    fi
}

require_tag_exists() {
    local tag="$1"
    local config="$2"

    if ! jq -e --arg tag "$tag" '.tags[$tag]' "$config" >/dev/null; then
        echo "Error: Tag '$tag' not found in configuration."
        echo
        exit 1
    fi
}