#!/bin/sh
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
# Resolve the directory where this script is located
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

BIN_DIR="$BASE_DIR/bin"
PRECHECK_SCRIPT="$BIN_DIR/precheck.sh"

# Make all shell scripts in bin/ executable
if [ -d "$BIN_DIR" ]; then
  chmod +x "$BIN_DIR"/*.sh 2>/dev/null
fi

# Check if precheck.sh exists and is executable
if [ ! -x "$PRECHECK_SCRIPT" ]; then
  echo "ERROR: precheck.sh not found or not executable at:"
  echo "       $PRECHECK_SCRIPT"
  exit 1
fi

# Execute precheck.sh with any arguments passed to this script
exec "$PRECHECK_SCRIPT" "$@"