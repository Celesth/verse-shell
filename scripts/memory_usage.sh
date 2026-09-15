#!/bin/sh
# MemAvailable includes reclaimable cache and is the useful "in use" figure.
awk '
    /^MemTotal:/ { total = $2 }
    /^MemAvailable:/ { available = $2 }
    END {
        if (total > 0) printf "%d\n", (100 * (total - available)) / total
        else print 0
    }
' /proc/meminfo
