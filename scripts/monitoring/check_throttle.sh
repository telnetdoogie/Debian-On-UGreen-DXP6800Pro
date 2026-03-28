#!/bin/bash

STATE_FILE="/var/tmp/thermal_throttle_prev"

# checks the throttle count for each core and totals them
CURRENT=$(grep . /sys/devices/system/cpu/cpu*/thermal_throttle/*count \
  | awk -F: '{sum+=$2} END {print sum}')

# print current value (for use on the command line)
echo "$CURRENT"

# First run: initialize and exit clean
if [ ! -f "$STATE_FILE" ]; then
  echo "$CURRENT" > "$STATE_FILE"
  exit 0
fi

PREV=$(cat "$STATE_FILE")
echo "$CURRENT" > "$STATE_FILE"

# get the delta between previous run and this run
DELTA=$((CURRENT - PREV))

# print delta (for command line use)
echo "delta=$DELTA" >&2

# Exit codes for monit - 1 if delta >0, 0 if no change
if [ "$DELTA" -gt 0 ]; then
  exit 1
else
  exit 0
fi