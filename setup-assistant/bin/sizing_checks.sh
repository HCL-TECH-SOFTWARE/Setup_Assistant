#!/bin/bash

run_sizing_checks() {

  log "=============================="
  log " Configuration Sizing Check"
  log "=============================="

  # --------------------------
  # Install type
  # --------------------------
  log "Select installation type:"
  log "1) AIO (All-In-One)"
  log "2) FF  (Full Fledged)"
  read -p "Enter choice [1/2]: " INSTALL_TYPE

  # --------------------------
  # Concurrency inputs (default 0)
  # --------------------------
  read -p "Enter number of concurrent scans for DAST [default: 0]: " DAST_CONCURRENCY
  read -p "Enter number of concurrent scans for SAST [default: 0]: " SAST_CONCURRENCY
  read -p "Enter number of concurrent scans for SCA  [default: 0]: " SCA_CONCURRENCY

  DAST_CONCURRENCY=${DAST_CONCURRENCY:-0}
  SAST_CONCURRENCY=${SAST_CONCURRENCY:-0}
  SCA_CONCURRENCY=${SCA_CONCURRENCY:-0}

  # --------------------------
  # Per-scan requirements
  # --------------------------
  # SAST
  SAST_MIN_RAM=16
  SAST_REC_RAM=28
  SAST_MIN_CPU=2
  SAST_REC_CPU=4

  # DAST
  DAST_MIN_RAM=3
  DAST_REC_RAM=4
  DAST_MIN_CPU=2
  DAST_REC_CPU=3

  # SCA (same as SAST)
  SCA_MIN_RAM=16
  SCA_REC_RAM=28
  SCA_MIN_CPU=2
  SCA_REC_CPU=4

  # --------------------------
  # ASCP baseline (always added)
  # --------------------------
  ASCP_CPU=12
  ASCP_RAM=28

  log "ASCP Baseline Reserved Resources:"
  log "CPU    : ${ASCP_CPU} vCores"
  log "Memory : ${ASCP_RAM} GB"

  # --------------------------
  # Calculate total requirements
  # --------------------------
  TOTAL_MIN_CPU=$(( \
    (DAST_MIN_CPU * DAST_CONCURRENCY) + \
    (SAST_MIN_CPU * SAST_CONCURRENCY) + \
    (SCA_MIN_CPU  * SCA_CONCURRENCY)  + \
    ASCP_CPU ))

  TOTAL_REC_CPU=$(( \
    (DAST_REC_CPU * DAST_CONCURRENCY) + \
    (SAST_REC_CPU * SAST_CONCURRENCY) + \
    (SCA_REC_CPU  * SCA_CONCURRENCY)  + \
    ASCP_CPU ))

  TOTAL_MIN_RAM=$(( \
    (DAST_MIN_RAM * DAST_CONCURRENCY) + \
    (SAST_MIN_RAM * SAST_CONCURRENCY) + \
    (SCA_MIN_RAM  * SCA_CONCURRENCY)  + \
    ASCP_RAM ))

  TOTAL_REC_RAM=$(( \
    (DAST_REC_RAM * DAST_CONCURRENCY) + \
    (SAST_REC_RAM * SAST_CONCURRENCY) + \
    (SCA_REC_RAM  * SCA_CONCURRENCY)  + \
    ASCP_RAM ))

  # --------------------------
  # Fetch cluster capacity
  # --------------------------
  if [ "$INSTALL_TYPE" = "2" ]; then
    # FF mode – sum capacity across all nodes
    NODE_CPU=$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.capacity.cpu}{"\n"}{end}' | awk '{s+=$1} END {print s}')
    NODE_MEM_KI=$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.capacity.memory}{"\n"}{end}' | sed 's/Ki//' | awk '{s+=$1} END {print s}')
    NODE_MEM_GI=$(( NODE_MEM_KI / 1024 / 1024 ))

    log "Detected Cluster Capacity (FF mode):"
    log "CPU    : $NODE_CPU vCores (sum of all nodes)"
    log "Memory : $NODE_MEM_GI GB (sum of all nodes)"

  else
    # AIO mode – single node only
    NODE_CPU=$(kubectl get nodes -o jsonpath='{.items[0].status.capacity.cpu}')
    NODE_MEM_KI=$(kubectl get nodes -o jsonpath='{.items[0].status.capacity.memory}')
    NODE_MEM_GI=$(( ${NODE_MEM_KI%Ki} / 1024 / 1024 ))

    log "Detected Node Capacity (AIO mode):"
    log "CPU    : $NODE_CPU vCores"
    log "Memory : $NODE_MEM_GI GB"
  fi

  # --------------------------
  # Display calculated requirements
  # --------------------------
  log "Calculated Total Requirements (including ASCP):"
  log "CPU    : Min=$TOTAL_MIN_CPU | Recommended=$TOTAL_REC_CPU"
  log "Memory : Min=$TOTAL_MIN_RAM GB | Recommended=$TOTAL_REC_RAM GB"

  # --------------------------
  # CPU validation
  # --------------------------
  if [ "$NODE_CPU" -lt "$TOTAL_MIN_CPU" ]; then
    log_status "CPU Check" 1 "FAIL" "Minimum required: $TOTAL_MIN_CPU vCores"
    status=1
  elif [ "$NODE_CPU" -lt "$TOTAL_REC_CPU" ]; then
    log_status "CPU Check" 0 "WARN" "Recommended: $TOTAL_REC_CPU vCores"
  else
    log_status "CPU Check" 0 "PASS" "Meets recommended requirement"
  fi

  # --------------------------
  # Memory validation
  # --------------------------
  if [ "$NODE_MEM_GI" -lt "$TOTAL_MIN_RAM" ]; then
    log_status "Memory Check" 1 "FAIL" "Minimum required: $TOTAL_MIN_RAM GB"
    status=1
  elif [ "$NODE_MEM_GI" -lt "$TOTAL_REC_RAM" ]; then
    log_status "Memory Check" 0 "WARN" "Recommended: $TOTAL_REC_RAM GB"
  else
    log_status "Memory Check" 0 "PASS" "Meets recommended requirement"
  fi

  # --------------------------
  # Install-type note
  # --------------------------
  if [ "$INSTALL_TYPE" = "2" ]; then
    log "NOTE: FF installation selected."
    log "Sizing is validated against total cluster capacity."
  else
    log "NOTE: AIO installation selected."
    log "Sizing is validated against a single node."
  fi
}

