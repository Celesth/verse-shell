#!/bin/sh
# Print total CPU utilisation from two /proc/stat samples.
sample() {
    set -- $(awk '/^cpu / { print $2 + $3 + $4 + $5 + $6 + $7 + $8, $5 + $6; exit }' /proc/stat)
    printf '%s %s\n' "$1" "$2"
}

set -- $(sample)
total_before=$1 idle_before=$2
sleep 0.2
set -- $(sample)
total_after=$1 idle_after=$2

total_delta=$((total_after - total_before))
idle_delta=$((idle_after - idle_before))
[ "$total_delta" -gt 0 ] || { echo 0; exit; }
echo $(( (100 * (total_delta - idle_delta)) / total_delta ))
