#!/bin/bash


# os_checks.sh - system resource and OS related checks


run_os_checks() {
log "## 🖥️ System Resource Check"


# CPU details
if command_exists lscpu; then
    CPU_COUNT=$(lscpu | awk -F: '/^CPU\(s\)/ {gsub(/^[ \t]+/, "", $2); print $2}')
    ARCH=$(lscpu | awk -F: '/^Architecture/ {gsub(/^[ \t]+/, "", $2); print $2}')
    CPU_OPMODE=$(lscpu | awk -F: '/^CPU op-mode\(s\)/ {gsub(/^[ \t]+/, "", $2); print $2}')
    MODEL_NAME=$(lscpu | awk -F: '/^Model name/ {gsub(/^[ \t]+/, "", $2); print $2}')
    CORES_PER_SOCKET=$(lscpu | awk -F: '/^Core\(s\) per socket/ {gsub(/^[ \t]+/, "", $2); print $2}')
    THREADS_PER_CORE=$(lscpu | awk -F: '/^Thread\(s\) per core/ {gsub(/^[ \t]+/, "", $2); print $2}')

    CPU_INFO="CPU(s): ${CPU_COUNT}, Arch: ${ARCH}, Op-modes: ${CPU_OPMODE}, Model: ${MODEL_NAME}, Cores/socket: ${CORES_PER_SOCKET}, Threads/core: ${THREADS_PER_CORE}"

    log_status "CPU Information" 0 "$CPU_INFO" "$CPU_INFO"
else
    log_status "CPU Information" 1 "lscpu not found" "FAIL (lscpu command not found)"
fi


# Memory
if command_exists free; then
TOTAL_MEM_MB=$(free -m | awk '/Mem:/ {print $2}')
USED_MEM_MB=$(free -m | awk '/Mem:/ {print $3}')
USED_MEM_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($USED_MEM_MB/$TOTAL_MEM_MB)*100}")
DISPLAY_MSG="$TOTAL_MEM_MB MB (Used: $USED_MEM_PERCENT%)"
LOG_MSG="$TOTAL_MEM_MB MB Total, $USED_MEM_MB MB Used, $USED_MEM_PERCENT% Used"
log_status "Total RAM" 0 "$DISPLAY_MSG" "$LOG_MSG"
else
log_status "Total RAM" 1 "free not found" "FAIL (free command not found)"
fi


# Disk
if command_exists df; then
DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')
DISK_USED_PERC=$(df -h / | awk 'NR==2{print $5}')
DISPLAY_MSG="$DISK_USED_PERC used out of $DISK_TOTAL"
LOG_MSG="Used: $DISK_USED_PERC, Total: $DISK_TOTAL"
log_status "Disk Usage (/)" 0 "$DISPLAY_MSG" "$LOG_MSG"
else
log_status "Disk Usage" 1 "df not found" "FAIL (df command not found)"
fi

# Disk space for K0s (/var/lib)
if command_exists df; then
DISK_TOTAL=$(df -h /var/lib | awk 'NR==2{print $2}')
DISK_USED_PERC=$(df -h /var/lib | awk 'NR==2{print $5}')
DISPLAY_MSG="$DISK_USED_PERC used out of $DISK_TOTAL"
LOG_MSG="Used: $DISK_USED_PERC, Total: $DISK_TOTAL"
log_status "Disk Usage (/var/lib)" 0 "$DISPLAY_MSG" "$LOG_MSG"
else
log_status "Disk Usage" 1 "df not found" "FAIL (df command not found)"
fi


# SELinux / AppArmor
if command_exists getenforce; then
SE_STATUS=$(getenforce 2>/dev/null || echo "unknown")
log_status "SELinux" 2 "$SE_STATUS" "SELinux status: $SE_STATUS"
else
# check apparmor
if command_exists aa-status; then
AA_STAT=$(aa-status 2>&1 | head -n 3)
log_status "AppArmor" 2 "Present" "AppArmor: $AA_STAT"
else
log_status "SELinux/AppArmor" 0 "N/A" "No SELinux/AppArmor controls detected (commands not found)"
fi
fi
}
