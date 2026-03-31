#!/bin/bash

# k8s_checks.sh - Kubernetes related checks

run_k8s_checks() {
  log "## ☸️ Kubernetes Checks"

  # --------------------------
  # Cluster availability
  # --------------------------
  if kubectl cluster-info &> /dev/null; then
    log_status "Kubernetes Cluster" 0 "Available" "kubectl cluster-info OK"
  else
    log_status "Kubernetes Cluster" 1 "Not available" "kubectl not configured or cluster unreachable"
    return
  fi

  # --------------------------
  # cert-manager
  # --------------------------
  if kubectl get pods -n cert-manager &> /dev/null; then
    if kubectl get pods -n cert-manager | grep -q "cert-"; then
      log_status "cert-manager Pod" 0 "Running" "cert-manager namespace has pods"
    else
      log_status "cert-manager Pod" 1 "Not running" "No cert-manager pods found"
    fi
  else
    log_status "cert-manager Pod" 0 "N/A" "cert-manager namespace not present"
  fi

  # --------------------------
  # Helm Releases
  # --------------------------
    if command_exists helm; then
      if helm list -A &> /dev/null; then
        HELM_RELEASE_COUNT=$(helm list -A -q | wc -l)
        log_status "Helm Connectivity" 0 "PASS" "Helm connected to cluster. Releases found: $HELM_RELEASE_COUNT"
      else
        log_status "Helm Connectivity" 1 "FAIL" "Helm installed but unable to reach cluster"
      fi
    else
      log_status "Helm Connectivity" 1 "FAIL" "Helm not installed"
    fi

  # --------------------------
  # Storage class / PV
  # --------------------------
# --------------------------
  # Storage class / PV Logic
  # --------------------------
  
  # NEW: If storage class is 'manual', we ignore the SC check and only look for the PV
  if [ "$storage_class_name" = "manual" ]; then
    log "ℹ️ StorageClass is set to 'manual'. Skipping StorageClass check and verifying PV instead."
    
    if [ -n "$ck_pv_name" ]; then
      log "🔎 Checking Persistent Volume: $ck_pv_name"
      if kubectl get pv "$ck_pv_name" &> /dev/null; then
        log_status "PV ($ck_pv_name)" 0 "PASS" "PV exists (Manual Mode)"
      else
        log_status "PV" 1 "FAIL" "PersistentVolume '$ck_pv_name' not found (Required for manual storage)"
      fi
    else
      log_status "Storage Check" 1 "FAIL" "Storage set to 'manual' but no PV name (ck_pv_name) provided"
    fi

  # STANDARD: If storage class is NOT 'manual', check the StorageClass first
  elif [ -n "$storage_class_name" ]; then
    log "🔎 Checking StorageClass: $storage_class_name"
    if kubectl get storageclass "$storage_class_name" &> /dev/null; then
      log_status "Storage Class ($storage_class_name)" 0 "PASS" "StorageClass exists"
    else
      log_status "Storage Class" 1 "FAIL" "StorageClass '$storage_class_name' not found in cluster"
    fi

  # FALLBACK: If only a PV is provided without any StorageClass
  elif [ -n "$ck_pv_name" ]; then
    log "🔎 Checking Persistent Volume: $ck_pv_name"
    if kubectl get pv "$ck_pv_name" &> /dev/null; then
      log_status "PV ($ck_pv_name)" 0 "PASS" "PV exists"
    else
      log_status "PV" 1 "FAIL" "PersistentVolume '$ck_pv_name' not found"
    fi

  else
    log_status "Storage Check" 2 "SKIP" "Neither StorageClass nor PV defined in properties"
  fi

  # --------------------------
  # GatewayClass (NO SKIP LOGIC)
  # --------------------------
  if [ -n "$gateway_class_name" ]; then
    if kubectl get gatewayclass "$gateway_class_name" &> /dev/null; then
      log_status "GatewayClass ($gateway_class_name)" 0 "PASS" "GatewayClass present"
    else
      log_status "GatewayClass ($gateway_class_name)" 1 "Not found" "GatewayClass $gateway_class_name not found"
    fi
  else
    # generic check: at least one GatewayClass must exist
    if kubectl get gatewayclass &> /dev/null && \
       [ "$(kubectl get gatewayclass --no-headers | wc -l)" -gt 0 ]; then
      log_status "GatewayClass" 0 "PASS" "GatewayClass present in cluster"
    else
      log_status "GatewayClass" 1 "Not found" "No GatewayClass found in cluster"
    fi
  fi
}
