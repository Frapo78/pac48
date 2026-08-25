#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
GENERATED_DIR="$ROOT_DIR/src/generated"
VERSION_FILE="$ROOT_DIR/VERSION"
VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
OUTPUT_BIN="$BUILD_DIR/pac48.bin"
OUTPUT_TAP="$BUILD_DIR/pac48.tap"
VERSIONED_TAP="$BUILD_DIR/pac48-${VERSION}.tap"
GENERATED_SPRITES="$GENERATED_DIR/pac_shifted.asm"
MAX_BIN_BYTES=28672

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command '$1' not found." >&2
    exit 1
  }
}

require_cmd python3
require_cmd sjasmplus
require_cmd bin2tap.py
test -n "$VERSION" || { echo "ERROR: VERSION file is empty"; exit 1; }

mkdir -p "$BUILD_DIR" "$GENERATED_DIR"
cd "$ROOT_DIR"

echo "[1/5] Generating masked pre-shifted sprites..."
python3 tools/gen_shifted_sprites.py src/sprites.asm "$GENERATED_SPRITES"

echo "[2/5] Running structural checks..."
python3 tools/check_project.py \
  --maze src/maze.asm \
  --generated-sprites "$GENERATED_SPRITES"

echo "[3/5] Assembling..."
sjasmplus --raw="$OUTPUT_BIN" src/main.asm
test -f "$OUTPUT_BIN" || { echo "ERROR: sjasmplus did not create $OUTPUT_BIN"; exit 1; }

python3 tools/check_project.py \
  --maze src/maze.asm \
  --generated-sprites "$GENERATED_SPRITES" \
  --binary "$OUTPUT_BIN" \
  --max-binary-bytes "$MAX_BIN_BYTES"

echo "[4/5] Creating TAP..."
bin2tap.py -o 32768 -s 32768 -c 32767 "$OUTPUT_BIN" "$OUTPUT_TAP"

echo "[5/5] Creating versioned TAP..."
cp "$OUTPUT_TAP" "$VERSIONED_TAP"

echo
echo "Build complete:"
echo "  Version: $VERSION"
echo "  BIN: $OUTPUT_BIN"
echo "  TAP: $OUTPUT_TAP"
echo "  Versioned TAP: $VERSIONED_TAP"
echo "  Generated sprites: $GENERATED_SPRITES"
