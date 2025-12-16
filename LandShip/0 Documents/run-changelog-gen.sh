#!/bin/sh
set -euo pipefail

# Determine the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR"

TOOL_DIR="$ROOT/Tools/ChangelogGen"
BUILD_DIR="$TOOL_DIR/.build/release"
TOOL_BINARY="$BUILD_DIR/ChangelogGen"

echo "Running changelog update tool from $TOOL_DIR"

if [ ! -x "$TOOL_BINARY" ]; then
  echo "Building changelog tool..."
  (cd "$TOOL_DIR" && swift build -c release)
fi

if [ ! -x "$TOOL_BINARY" ]; then
  echo "Failed to build changelog tool." >&2
  exit 1
fi

echo "Updating CHANGELOG.md..."
"$TOOL_BINARY" --root "$ROOT" --changelog "$ROOT/CHANGELOG.md" "$@"

echo "CHANGELOG.md updated successfully."
