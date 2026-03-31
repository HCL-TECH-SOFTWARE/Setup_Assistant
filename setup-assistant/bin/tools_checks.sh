#!/bin/bash

# tools_checks.sh - verify kubectl, helm, openssl and container runtime versions

run_tools_checks() {
  log "## 🛠️ Tools Check"

  # --------------------------
  # kubectl
  # --------------------------
  if command_exists kubectl; then
    kubectl version --client 2>&1 | tee -a "$LOG_FILE"
    log_status "kubectl Installation" 0 "PASS" "kubectl present"
  else
    log_status "kubectl Installation" 1 "kubectl not found" "kubectl not found"
  fi

  # --------------------------
  # Helm
  # --------------------------
if command_exists helm; then
    helm version --short 2>&1 | tee -a "$LOG_FILE"
    log_status "Helm Installation" 0 "PASS" "Helm is installed"
else
    log_status "Helm Installation" 1 "FAIL" "Helm not found"
fi

  # --------------------------
  # OpenSSL
  # --------------------------
  if command_exists openssl; then
    openssl version >> "$LOG_FILE" 2>&1
    log_status "OpenSSL Installation" 0 "PASS" "OpenSSL present"
  else
    log_status "OpenSSL Installation" 1 "OpenSSL not found" "OpenSSL not found"
  fi

  # --------------------------
  # Container Runtime (Docker or Podman)
  # --------------------------
  if command_exists docker; then
    docker --version 2>&1 | tee -a "$LOG_FILE"
    log_status "Container Runtime" 0 "PASS" "Docker present"
  elif command_exists podman; then
    podman --version 2>&1 | tee -a "$LOG_FILE"
    log_status "Container Runtime" 0 "PASS" "Podman present"
  else
    log_status "Container Runtime" 1 "Not found" "Neither Docker nor Podman installed"
  fi

  # --------------------------
  # cert-manager pod check (delegated to k8s_checks ideally)
  # --------------------------
}