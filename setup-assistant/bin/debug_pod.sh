#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DEBUG_POD_NAME="precheck-debug"
DEBUG_IMAGE_TAR="$ROOT_DIR/images/precheck-debug-latest.tar"

log() {
  echo "$1"
}

push_image_to_registry() {

  log "--- [Registry Push Mode - Multi Node Safe] ---"

  if [ ! -f "$DEBUG_IMAGE_TAR" ]; then
    log "❌ ERROR: TAR file not found at: $DEBUG_IMAGE_TAR"
    exit 1
  fi

  read -p "Enter Registry URL (e.g. localhost:5000 or myregistry.com): " REGISTRY_URL
  read -p "Enter Registry Username: " REGISTRY_USER
  read -s -p "Enter Registry Password: " REGISTRY_PASS
  echo ""

  # --- MINIMAL CHANGE: Wrapper Function ---
  # If docker doesn't exist but podman does, intercept all 'docker' commands and use podman
  if ! command -v docker &> /dev/null; then
    if command -v podman &> /dev/null; then
      docker() { podman "$@"; }
    else
      log "❌ ERROR: Neither docker nor podman found."
      exit 1
    fi
  fi
  # ----------------------------------------

  # Now we just write standard 'docker' commands. The function handles the translation!
  LOAD_OUTPUT=$(docker load -i "$DEBUG_IMAGE_TAR")
  
  # Grep the output and use $NF to safely grab the last word for both formats
  IMAGE_NAME=$(echo "$LOAD_OUTPUT" | grep -i "Loaded image" | awk '{print $NF}')

  TARGET_IMAGE="$REGISTRY_URL/precheck-debug:latest"

  docker tag "$IMAGE_NAME" "$TARGET_IMAGE"
  echo "$REGISTRY_PASS" | docker login "$REGISTRY_URL" -u "$REGISTRY_USER" --password-stdin
  docker push "$TARGET_IMAGE"

  DEBUG_IMAGE="$TARGET_IMAGE"
}

run_debug_pod() {

  # ================================
  # Namespace Prompt
  # ================================
  read -p "Enter Kubernetes namespace (leave blank for default): " USER_NAMESPACE

  if [ -z "$USER_NAMESPACE" ]; then
    DEBUG_NAMESPACE="default"
  else
    if kubectl get namespace "$USER_NAMESPACE" >/dev/null 2>&1; then
      DEBUG_NAMESPACE="$USER_NAMESPACE"
    else
      echo "⚠ Namespace '$USER_NAMESPACE' not found. Falling back to 'default'."
      DEBUG_NAMESPACE="default"
    fi
  fi

  echo "Using namespace: $DEBUG_NAMESPACE"
  echo ""

  # Push the image and capture credentials
  push_image_to_registry

  # ================================
  # 🔑 Create Registry Secret for Kubernates
  # ================================
  echo "🔑 Injecting registry credentials into namespace '$DEBUG_NAMESPACE'..."
  
  # Clean up old secret and pod if they exist
  kubectl delete secret registry-secret -n "$DEBUG_NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete pod "$DEBUG_POD_NAME" -n "$DEBUG_NAMESPACE" --ignore-not-found --force --grace-period=0 >/dev/null 2>&1 || true

  # Create the new secret using the credentials you just typed
  kubectl create secret docker-registry registry-secret \
    --namespace="$DEBUG_NAMESPACE" \
    --docker-server="$REGISTRY_URL" \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$REGISTRY_PASS" >/dev/null 2>&1

  echo "⏳ Creating debug pod..."

  # ================================
  # K0s-Compatible Pod Creation
  # ================================
  cat <<EOF | kubectl apply -f - 
apiVersion: v1
kind: Pod
metadata:
  name: $DEBUG_POD_NAME
  namespace: $DEBUG_NAMESPACE
spec:
  imagePullSecrets:
    - name: registry-secret
  containers:
  - name: debug
    image: $DEBUG_IMAGE
    imagePullPolicy: Always
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
      runAsNonRoot: true
      allowPrivilegeEscalation: false
  restartPolicy: Never
EOF

  if kubectl wait pod "$DEBUG_POD_NAME" \
      --for=condition=Ready \
      --timeout=120s \
      --namespace="$DEBUG_NAMESPACE"; then

    echo ""
    echo "✅ SUCCESS: Pod is running."
    echo "kubectl exec -it $DEBUG_POD_NAME -n $DEBUG_NAMESPACE -- bash"
    echo ""
    echo "To delete the pod:"
    echo "kubectl delete pod $DEBUG_POD_NAME -n $DEBUG_NAMESPACE"
    echo ""

  else
    echo "❌ ERROR: Pod failed. Fetching logs..."
    kubectl describe pod "$DEBUG_POD_NAME" -n "$DEBUG_NAMESPACE" | grep -A 10 "Events:"
    exit 1
  fi
}