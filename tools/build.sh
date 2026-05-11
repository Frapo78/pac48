#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
VERSION_FILE="$ROOT_DIR/VERSION"
VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
OUTPUT_BIN="$BUILD_DIR/pac48.bin"
OUTPUT_TAP="$BUILD_DIR/pac48.tap"
VERSIONED_TAP="$BUILD_DIR/pac48-${VERSION}.tap"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command '$1' not found." >&2
    exit 1
  }
}

require_cmd sjasmplus
require_cmd bin2tap.py
test -n "$VERSION" || { echo "ERROR: VERSION file is empty"; exit 1; }

mkdir -p "$BUILD_DIR"
cd "$ROOT_DIR"

echo "[1/2] Assembling..."
sjasmplus --raw="$OUTPUT_BIN" src/main.asm
test -f "$OUTPUT_BIN" || { echo "ERROR: sjasmplus did not create $OUTPUT_BIN"; exit 1; }

echo "[2/2] Creating TAP..."
bin2tap.py -o 32768 -s 32768 -c 32767 "$OUTPUT_BIN" "$OUTPUT_TAP"
cp "$OUTPUT_TAP" "$VERSIONED_TAP"

echo
echo "Build complete:"
echo "  Version: $VERSION"
echo "  BIN: $OUTPUT_BIN"
echo "  TAP: $OUTPUT_TAP"
echo "  Versioned TAP: $VERSIONED_TAP"
