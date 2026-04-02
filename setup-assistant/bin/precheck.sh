#!/bin/bash
# Copyright 2026 HCL America, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==========================
# Core utilities
# ==========================
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/property_parser.sh"

# ==========================
# Modules
# ==========================
source "$SCRIPT_DIR/os_checks.sh"
source "$SCRIPT_DIR/network_checks.sh"
source "$SCRIPT_DIR/tools_checks.sh"
source "$SCRIPT_DIR/k8s_checks.sh"
source "$SCRIPT_DIR/registry_checks.sh"
source "$SCRIPT_DIR/sql_checks.sh"
#source "$SCRIPT_DIR/storage_checks.sh"
source "$SCRIPT_DIR/debug_pod.sh"
source "$SCRIPT_DIR/troubleshoot_checks.sh"
source "$SCRIPT_DIR/sizing_checks.sh"

log "========================================"
log "      Pre-check Validator (Hybrid)       "
log "========================================"

# ==========================
# Property file detection
# ==========================
if parse_common_values; then
  PROPERTY_MODE=true
  PRECHECK_MODE="2"
  log "Property file detected."
  log "Running FULL pre-checks automatically."
else
  PROPERTY_MODE=false
fi

# ==========================
# Interactive mode selection
# ==========================
if [ "$PROPERTY_MODE" = false ]; then
  log "Property file not found."
  log "Select execution mode:"
  log "1) Baseline checks only (OS / Network / Tools)"
  log "2) Full checks only (K8s / Registry / SQL / Storage)"
  log "3) Debug pod only (No pre-checks)"
  log "4) Troubleshoot (K8s API + MTU checks)"
  log "5) Sizing checks (Cluster capacity & node sizing)"
  read -p "Enter choice [1/2/3/4/5]: " PRECHECK_MODE
fi

# ==========================
# Troubleshoot mode
# ==========================
if [ "$PRECHECK_MODE" = "4" ]; then
  log "Troubleshoot mode selected."
  run_troubleshoot_checks
  exit $status
fi

# ==========================
# Debug pod mode
# ==========================
if [ "$PRECHECK_MODE" = "3" ]; then
  log "Debug pod mode selected."
  run_debug_pod
  exit 0
fi

# ==========================
# Sizing checks mode (FULL SCREEN)
# ==========================
if [ "$PRECHECK_MODE" = "5" ]; then
  clear

  log "=============================================="
  log "          CLUSTER SIZING VALIDATION            "
  log "=============================================="
  log ""
  log "This mode validates cluster capacity against"
  log "recommended sizing requirements."
  log ""
  log "Press ENTER to continue..."
  read

  run_sizing_checks
  exit $status
fi

# ==========================
# Interactive fallback for FULL mode
# ==========================
if [ "$PRECHECK_MODE" = "2" ] && [ "$PROPERTY_MODE" = false ]; then
  log "Collecting inputs for FULL validation..."

  # Registry
  prompt_input "Docker Registry URL" docker_registry_address
  prompt_input "Docker Registry Username" docker_registry_username
  prompt_input "Docker Registry Password" docker_registry_password true

  # SQL
  prompt_input "SQL Connection String" database_connection

  database_ip=$(echo "$database_connection" | awk -F'[=;]' '{for(i=1;i<=NF;i++) if($i~/Data Source/) print $(i+1)}')
  user_id=$(echo "$database_connection" | awk -F'[=;]' '{for(i=1;i<=NF;i++) if($i~/User ID/) print $(i+1)}')
  database_password=$(echo "$database_connection" | awk -F'[=;]' '{for(i=1;i<=NF;i++) if($i~/Password/) print $(i+1)}')

  # Storage
  prompt_input "Storage Class Name (optional)" storage_class_name
  prompt_input "Persistent Volume Name (optional)" ck_pv_name

  PROPERTY_MODE=true
fi

# ==========================
# BASELINE CHECKS (Mode 1)
# ==========================
if [ "$PRECHECK_MODE" = "1" ]; then
  log "Running BASELINE checks..."
  run_os_checks
  run_network_checks
  run_tools_checks
fi

# ==========================
# FULL CHECKS (Mode 2)
# ==========================
if [ "$PRECHECK_MODE" = "2" ] && [ "$PROPERTY_MODE" = true ]; then
  log "Running FULL checks..."
  run_k8s_checks
  run_registry_checks
  run_sql_checks
fi

# ==========================
# Summary
# ==========================
log "------------ SUMMARY ------------"
if [ "$status" -eq 0 ]; then
  log_status "Overall Result" 0 "SUCCESS" "All executed checks passed"
else
  log_status "Overall Result" 1 "FAILURE" "One or more checks failed. See $LOG_FILE"
fi

exit $status
