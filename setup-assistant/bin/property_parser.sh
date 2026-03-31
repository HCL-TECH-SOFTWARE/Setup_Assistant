#!/bin/bash

# ------------------------------------------------------------
# property_parser.sh (ROOT CAUSE FIXED)
# ------------------------------------------------------------

PROPERTY_MODE=false
DEBUG=${DEBUG:-false}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
property_file="$BASE_DIR/singular-singular.clusterKit.properties"

get_value() {
  local key="$1"
  [ ! -f "$property_file" ] && return 1

  # NEW LOGIC: Do not split by '='. Instead, match the key and grab 
  # everything after the first '=' character to preserve the DB string.
  awk -v k="$key" '
    BEGIN { prefix = k "=" }
    substr($0, 1, length(prefix)) == prefix {
      # Grab the entire string after KEY=
      val = substr($0, length(prefix) + 1)
      
      # Strip carriage returns and outer quotes
      gsub(/\r/, "", val)
      gsub(/^[ \t"'\'']+|[ \t"'\'']+$/, "", val)
      
      print val
      exit
    }
  ' "$property_file"
}

parse_common_values() {
  if [ ! -f "$property_file" ]; then return 1; fi

  storage_class_name=$(get_value "CK_CSI_STORAGE_CLASS_NAME")
  ck_pv_name=$(get_value "CK_CSI_STORAGE_SHARED_FILE_SYSTEM_VOLUME_NAME")
  docker_registry_address=$(get_value "CK_DOCKER_REGISTRY_ADDRESS")
  docker_registry_username=$(get_value "CK_DOCKER_REGISTRY_USERNAME")
  docker_registry_password=$(get_value "CK_DOCKER_REGISTRY_PASSWORD")
  gateway_class_name=$(get_value "CK_GATEWAY_CLASS_NAME")

  database_connection=$(get_value "CK_CONFIGURATION_CONFIDENTIAL_DEFAULT_CONNECTION")

  if [ -z "$database_connection" ]; then
    echo "Error: Could not retrieve the connection string."
    return 1
  fi

  # Your exact logic, now receiving the FULL connection string
  database_ip=$(echo "$database_connection" | awk -F'[=;]' '{for(i=1;i<=NF;i++) if($i ~ /Data Source/) print $(i+1)}')
  user_id=$(echo "$database_connection" | awk -F'[=;]' '{for(i=1;i<=NF;i++) if($i ~ /User ID/) print $(i+1)}')
  database_password=$(echo "$database_connection" | awk -F'[=;]' '{for(i=1;i<=NF;i++) if($i ~ /Password/) print $(i+1)}')

  # Strip any residual spaces or carriage returns
  database_ip=$(echo "$database_ip" | xargs | tr -d '\r')
  user_id=$(echo "$user_id" | xargs | tr -d '\r')
  database_password=$(echo "$database_password" | xargs | tr -d '\r')

  export database_ip user_id database_password
  PROPERTY_MODE=true
  return 0
}