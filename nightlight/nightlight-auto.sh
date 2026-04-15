#!/bin/bash
# Nightlight auto-apply on login
# Checks current time and enables/disables nightlight accordingly
# Nightlight ON: 7 PM (19:00) to 7 AM (07:00)

HOUR=$(date +%H)

# If hour is >= 19 (7 PM) OR < 7 (before 7 AM), enable nightlight
if [ "$HOUR" -ge 19 ] || [ "$HOUR" -lt 7 ]; then
    # Kill any existing hyprsunset instance first
    pkill -x hyprsunset 2>/dev/null
    sleep 0.5
    # Start hyprsunset with warm temperature (4500K)
    hyprsunset -t 4500 &
else
    # Daytime - ensure nightlight is off
    pkill -x hyprsunset 2>/dev/null
fi
