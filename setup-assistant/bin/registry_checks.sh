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
run_registry_checks() {
  log "\n## 🐳 Docker Registry Connectivity"

  # --- CHANGE for podman STARTS HERE ---
  if ! command_exists docker; then
    if command_exists podman; then
      # Create a transparent wrapper function. If the script calls 'docker', it runs 'podman'
      docker() { podman "$@"; }
    else
      log_status "Docker/Podman Installation" 1 "FAIL" "Neither docker nor podman command found"
      return
    fi
  fi
  # --- CHANGE ENDS HERE ---

  # --------------------------
  # Docker login
  # --------------------------
  if [ -n "${docker_registry_address:-}" ]; then
    if docker login "$docker_registry_address" \
        -u "$docker_registry_username" \
        -p "$docker_registry_password" &>> "$LOG_FILE"; then
      log_status "Docker Login to $docker_registry_address" 0 "PASS" "Login successful"
    else
      log_status "Docker Login to $docker_registry_address" 1 "FAIL" \
        "Docker login failed. Check credentials"
      return
    fi
  else
    log_status "Docker Registry" 2 "SKIP" "No registry configured"
    return
  fi

  # --------------------------
  # Image push / pull test
  # --------------------------
  image_tar_path="$PWD/images/sql-connection-tester_1.0.tar"
  echo "$image_tar_path"
  test_image_name="sql-connection-tester"
  target_tag="latest"
  local_image_tag="${test_image_name}:1.0"
  tagged_image="${docker_registry_address}/${test_image_name}:${target_tag}"

  if [ -f "$image_tar_path" ]; then
    log "Loading test image tar..."

    if ! docker load -i "$image_tar_path" &>> "$LOG_FILE"; then
      log_status "Docker Load Image" 1 "FAIL" "Failed to load image tar"
      return
    fi

    # Re-tag image explicitly
    if docker image inspect "$local_image_tag" &>/dev/null; then
      docker tag "$local_image_tag" "$tagged_image"
    else
      log_status "Docker Image Tag" 1 "FAIL" \
        "Expected image $local_image_tag not found after docker load"
      return
    fi

    # Push test
    if docker push "$tagged_image" &>> "$LOG_FILE"; then
      log_status "Docker Push Image" 0 "PASS" "Image pushed successfully"
    else
      log_status "Docker Push Image" 1 "FAIL" "Failed to push image"
      return
    fi

    # Remove local image
    docker rmi "$tagged_image" &>> "$LOG_FILE" || true

    # Pull test
    if docker pull "$tagged_image" &>> "$LOG_FILE"; then
      log_status "Docker Pull Image" 0 "PASS" "Image pulled successfully"
    else
      log_status "Docker Pull Image" 1 "FAIL" "Failed to pull image"
    fi

  else
    log_status "Docker Image Test" 2 "SKIP" \
      "Image tar not found: $image_tar_path"
  fi
}