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
run_sql_checks() {
  log "## 📶 SQL Connectivity Test"

  # Variable Check
  echo "--- Variable ---"
  printf "DB_IP:   '%s'\n" "$database_ip"
  printf "DB_USER: '%s'\n" "$user_id"
  echo "-----------------------------"

  if [ -z "$database_ip" ] || [ -z "$user_id" ]; then
    log_status "SQL Connectivity" 1 "FAIL" "Database details not parsed"
    return
  fi

  local JOB_NAME="sqltest-job"
  local NAMESPACE="default"
  local IMAGE="${docker_registry_address:-}/sql-connection-tester:latest"
  local ARGS="[\"$database_ip\",\"AppScanCloudDB\",\"$user_id\",\"$database_password\"]"

  # ================================
  # 🔑 Create Registry Secret for K0s/K3s
  # ================================
  log "🔑 Injecting registry credentials into namespace '$NAMESPACE'..."
  
  # Clean up old secret if it exists
  kubectl delete secret registry-secret -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true

  # Create the new secret using parsed properties
  if [ -n "$docker_registry_address" ] && [ -n "$docker_registry_username" ] && [ -n "$docker_registry_password" ]; then
    kubectl create secret docker-registry registry-secret \
      --namespace="$NAMESPACE" \
      --docker-server="$docker_registry_address" \
      --docker-username="$docker_registry_username" \
      --docker-password="$docker_registry_password" >/dev/null 2>&1
  else
    log "⚠ No registry credentials found in properties; attempting to pull without secret..."
  fi

  # Cleanup old jobs
  kubectl delete job "$JOB_NAME" -n "$NAMESPACE" --ignore-not-found=true &>> "$LOG_FILE" || true

  log "📦 Creating SQL test job..."

  # Create Job
  cat <<EOF | kubectl apply -f - &>> "$LOG_FILE"
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB_NAME
  namespace: $NAMESPACE
spec:
  ttlSecondsAfterFinished: 60
  backoffLimit: 0
  template:
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      imagePullSecrets:
        - name: registry-secret
      containers:
      - name: sqltest
        image: $IMAGE
        args: $ARGS
        securityContext:
          runAsUser: 1000
          runAsGroup: 1000
          runAsNonRoot: true
          allowPrivilegeEscalation: false
      restartPolicy: Never
EOF

  log "⏳ Waiting for SQL test pod..."
  
  local STATUS="Pending"
  for _ in {1..30}; do
    STATUS=$(kubectl get pod -l job-name="$JOB_NAME" -n "$NAMESPACE" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Pending")
    [[ "$STATUS" == "Succeeded" || "$STATUS" == "Failed" ]] && break
    sleep 2
  done

  # Fetch and log results
  local POD_NAME=$(kubectl get pod -l job-name="$JOB_NAME" -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  local POD_LOGS=$(kubectl logs "$POD_NAME" -n "$NAMESPACE" 2>&1 || true)

  {
    echo "---- SQL Test Pod Logs ($POD_NAME) ----"
    echo "$POD_LOGS"
    echo "--------------------------------------"
  } >> "$LOG_FILE"

  if echo "$POD_LOGS" | grep -qi "Failed to connect"; then
    log_status "SQL Connectivity ($database_ip)" 1 "FAIL" "Connection rejected. See $LOG_FILE"
  elif [[ "$STATUS" == "Succeeded" ]]; then
    log_status "SQL Connectivity ($database_ip)" 0 "PASS" "Connection successful"
  else
    log_status "SQL Connectivity ($database_ip)" 1 "FAIL" "Pod status: $STATUS"
  fi

  # Final Cleanup
  kubectl delete job "$JOB_NAME" -n "$NAMESPACE" --ignore-not-found=true &>> "$LOG_FILE" || true
  kubectl delete secret registry-secret -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true
}