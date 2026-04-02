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
status=0

# ==========================
# Colors (same behavior as original tool)
# ==========================
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
NC="\e[0m"

run_troubleshoot_checks() {

  echo "========================================"
  echo "        Kubernetes Troubleshooter"
  echo "========================================"

  # ==========================
  # Kubernetes API checks
  # ==========================
  echo
  echo "[Kubernetes] Performing extended API reachability checks..."

  command -v kubectl >/dev/null 2>&1 \
    && printf "%-40s : ${GREEN}PASS${NC}\n" "kubectl binary" \
    || { printf "%-40s : ${RED}FAIL${NC}\n" "kubectl binary"; status=1; }

  kubectl config current-context >/dev/null 2>&1 \
    && printf "%-40s : ${GREEN}PASS${NC}\n" "kubectl auth/context" \
    || { printf "%-40s : ${RED}FAIL${NC}\n" "kubectl auth/context"; status=1; }

  kubectl get --raw=/healthz >/dev/null 2>&1 \
    && printf "%-40s : ${GREEN}PASS${NC}\n" "API /healthz" \
    || { printf "%-40s : ${RED}FAIL${NC}\n" "API /healthz"; status=1; }

  kubectl get svc kubernetes >/dev/null 2>&1 \
    && printf "%-40s : ${GREEN}PASS${NC}\n" "kubernetes service" \
    || { printf "%-40s : ${RED}FAIL${NC}\n" "kubernetes service"; status=1; }

  kubectl get endpoints kubernetes >/dev/null 2>&1 \
    && printf "%-40s : ${GREEN}PASS${NC}\n" "API service endpoints" \
    || { printf "%-40s : ${RED}FAIL${NC}\n" "API service endpoints"; status=1; }

  kubectl get pods -A >/dev/null 2>&1 \
    && printf "%-40s : ${GREEN}PASS${NC}\n" "API request" \
    || { printf "%-40s : ${RED}FAIL${NC}\n" "API request"; status=1; }

  # ==========================
  # Network / MTU checks
  # ==========================
  echo
  echo "[Network] Performing universal MTU validation..."

  DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk '{print $5}' | head -n1)

  if [ -n "$DEFAULT_IFACE" ]; then
    printf "%-40s : ${GREEN}PASS${NC}\n" "Default interface detection"
  else
    printf "%-40s : ${RED}FAIL${NC}\n" "Default interface detection"
    status=1
  fi

  CURRENT_MTU=""
  if [ -n "$DEFAULT_IFACE" ]; then
    CURRENT_MTU=$(ip link show "$DEFAULT_IFACE" 2>/dev/null | awk '/mtu/ {print $5}')
  fi

  if [ -n "$CURRENT_MTU" ]; then
    printf "%-40s : ${GREEN}PASS${NC}\n" "MTU detection"
    # Informational line (no status)
    printf "%-40s : %s\n" "Current MTU" "$CURRENT_MTU"
  else
    printf "%-40s : ${RED}FAIL${NC}\n" "MTU detection"
    status=1
  fi

  if [ -n "$CURRENT_MTU" ] && [ "$CURRENT_MTU" -ge 1500 ]; then
    printf "%-40s : ${GREEN}PASS${NC}\n" "MTU validation"
  else
    printf "%-40s : ${YELLOW}WARN${NC}\n" "MTU validation"
  fi

  ping -c 1 -M do -s 1472 8.8.8.8 >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    printf "%-40s : ${GREEN}PASS${NC}\n" "Path MTU check (tested 1472)"
  else
    printf "%-40s : ${YELLOW}WARN${NC}\n" "Path MTU check (tested 1472)"
  fi

  # ==========================
  # Summary
  # ==========================
  echo
  echo "------------ TROUBLESHOOT SUMMARY ------------"

  if [ "$status" -eq 0 ]; then
    printf "%-40s : ${GREEN}SUCCESS${NC}\n" "Overall Result"
  else
    printf "%-40s : ${RED}FAILURE${NC}\n" "Overall Result"
  fi

  return $status
}

