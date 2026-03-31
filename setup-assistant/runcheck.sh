#!/bin/sh

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