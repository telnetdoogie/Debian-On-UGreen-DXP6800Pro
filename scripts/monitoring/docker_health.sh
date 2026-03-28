#!/usr/bin/env bash

UNHEALTHY_IDS="$(docker ps -q \
    -f health="none" \
    -f health="unhealthy" \
    -f status="exited" \
    -f status="dead" \
    -f status="paused" \
    )"

if [[ -z "$UNHEALTHY_IDS" ]]; then
    docker ps --format "table {{.Names}}\t{{.Status}}"
    exit 0
fi

echo >&2
echo "WARN: Unhealthy docker instances!" >&2
echo "---------------------------------" >&2
docker ps --format "table {{.Names}}\t{{.State}}\t{{.Status}}" \
    -f health="none" \
    -f health="unhealthy" \
    -f status="exited" \
    -f status="dead" \
    -f status="paused" >&2
exit 1