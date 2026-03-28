#!/bin/bash
# custom alert for NUT events

EVENT="$1"

logger "UPS EVENT: $EVENT"

# optional email
echo "UPS event: $EVENT" | mail -s "[$HOSTNAME] UPS Event occurred !" your_email@email.com