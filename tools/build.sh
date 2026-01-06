#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
OUTPUT_BIN="$BUILD_DIR/pac48.bin"
OUTPUT_TAP="$BUILD_DIR/pac48.tap"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found in PATH." >&2
    echo "Install sjasmplus and SkoolKit (provides bin2tap.py) before building." >&2
    exit 1
  fi
}

require_cmd sjasmplus
require_cmd bin2tap.py

mkdir -p "$BUILD_DIR"
cd "$ROOT_DIR"

sjasmplus src/main.asm "$OUTPUT_BIN"
bin2tap.py -o 32768 -s 32768 -c 32767 "$OUTPUT_BIN" "$OUTPUT_TAP"

printf "Build complete:\n  BIN: %s\n  TAP: %s\n" "$OUTPUT_BIN" "$OUTPUT_TAP"
