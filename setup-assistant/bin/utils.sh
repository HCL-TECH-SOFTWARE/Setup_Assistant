#!/bin/bash

# utils.sh - common helpers for precheck-validator

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

LOG_FILE="$(pwd)/prerequisite_check.log"
status=0

# Create log file if it does not exist (DO NOT truncate)
touch "$LOG_FILE"

log() {
  echo -e "$@" | tee -a "$LOG_FILE"
}

# --------------------------
# Log run header (ONCE)
# --------------------------
if [ -z "$PRECHECK_LOG_HEADER_WRITTEN" ]; then
  PRECHECK_LOG_HEADER_WRITTEN=true

  log ""
  log "================================================"
  log " New execution started at $(date)"
  log "================================================"
fi

log_status() {
  local check_name="$1"
  local result_code="$2"  # 0=PASS,1=FAIL,2=INFO/SKIP
  local display_message="$3"
  local detailed_log_message="$4"

  if [ "$result_code" -eq 0 ]; then
    printf "%-40s : ${GREEN}%s${NC}\n" "$check_name" "$display_message"
  elif [ "$result_code" -eq 2 ]; then
    printf "%-40s : ${YELLOW}%s${NC}\n" "$check_name" "$display_message"
  else
    printf "%-40s : ${RED}%s${NC}\n" "$check_name" "$display_message"
    status=1
  fi

  printf "%-40s : %s\n" "$check_name" "$detailed_log_message" >> "$LOG_FILE"
}

command_exists() {
  command -v "$1" &>/dev/null
}

prompt_input() {
  local prompt="$1"
  local var_name="$2"
  local silent="$3"

  if [ "$silent" = "true" ]; then
    read -s -p "$prompt: " value
    echo
  else
    read -p "$prompt: " value
  fi

  eval "$var_name=\"$value\""
}
