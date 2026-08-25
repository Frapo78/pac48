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
TAP_LOAD_SNAPSHOT="$BUILD_DIR/tap_load.z80"
TAP_LOAD_LOG="$BUILD_DIR/tap_load.log"
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
require_cmd tap2sna.py
require_cmd trace.py
require_cmd snapinfo.py
test -n "$VERSION" || { echo "ERROR: VERSION file is empty"; exit 1; }

mkdir -p "$BUILD_DIR" "$GENERATED_DIR"
cd "$ROOT_DIR"

echo "[1/9] Generating masked pre-shifted sprites..."
python3 tools/gen_shifted_sprites.py src/sprites.asm "$GENERATED_SPRITES"

echo "[2/9] Running structural and architecture checks..."
python3 tools/check_project.py \
  --maze src/maze.asm \
  --generated-sprites "$GENERATED_SPRITES" \
  --source-root src

echo "[3/9] Running renderer reference-model tests..."
python3 tools/test_render_model.py

echo "[4/9] Assembling game..."
sjasmplus --raw="$OUTPUT_BIN" src/main.asm
test -f "$OUTPUT_BIN" || { echo "ERROR: sjasmplus did not create $OUTPUT_BIN"; exit 1; }

python3 tools/check_project.py \
  --maze src/maze.asm \
  --generated-sprites "$GENERATED_SPRITES" \
  --source-root src \
  --binary "$OUTPUT_BIN" \
  --max-binary-bytes "$MAX_BIN_BYTES"

echo "[5/9] Running headless Z80 runtime harness..."
chmod +x tools/run_runtime_tests.sh
tools/run_runtime_tests.sh

echo "[6/9] Measuring Render_Commit with 48K contention..."
chmod +x tools/run_perf_tests.sh
tools/run_perf_tests.sh

echo "[7/9] Creating TAP..."
bin2tap.py -o 32768 -s 32768 -c 32767 "$OUTPUT_BIN" "$OUTPUT_TAP"

echo "[8/9] Creating versioned TAP..."
cp "$OUTPUT_TAP" "$VERSIONED_TAP"

echo "[9/9] Simulating a fresh 48K TAP load to entry point..."
rm -f "$TAP_LOAD_SNAPSHOT" "$TAP_LOAD_LOG"
if ! tap2sna.py --start 32768 "$OUTPUT_TAP" "$TAP_LOAD_SNAPSHOT" >"$TAP_LOAD_LOG" 2>&1; then
  echo "ERROR: simulated 48K TAP load failed" >&2
  cat "$TAP_LOAD_LOG" >&2 || true
  exit 1
fi
test -s "$TAP_LOAD_SNAPSHOT" || {
  echo "ERROR: tap2sna.py did not create $TAP_LOAD_SNAPSHOT" >&2
  exit 1
}

# Record the resulting machine state as durable evidence. tap2sna.py with
# --start 32768 simulates a freshly booted 48K Spectrum running LOAD and stops
# when the program counter reaches PAC48's real entry/load address.
snapinfo.py "$TAP_LOAD_SNAPSHOT" >>"$TAP_LOAD_LOG"
grep -Eq '(^|[^0-9])32768([^0-9]|$)|\$8000|0x8000' "$TAP_LOAD_LOG" || {
  echo "ERROR: TAP load snapshot evidence does not show entry PC 32768/$8000" >&2
  cat "$TAP_LOAD_LOG" >&2 || true
  exit 1
}

BIN_BYTES="$(wc -c < "$OUTPUT_BIN" | tr -d '[:space:]')"
HEADROOM_BYTES="$((MAX_BIN_BYTES - BIN_BYTES))"

echo
echo "Build complete:"
echo "  Version: $VERSION"
echo "  BIN: $OUTPUT_BIN ($BIN_BYTES bytes)"
echo "  Upper-RAM budget headroom: $HEADROOM_BYTES bytes before safety ceiling"
echo "  TAP: $OUTPUT_TAP"
echo "  Versioned TAP: $VERSIONED_TAP"
echo "  TAP load simulation: PASS (fresh 48K -> entry 32768)"
echo "  Generated sprites: $GENERATED_SPRITES"
if [[ -s "$BUILD_DIR/perf_results.txt" ]]; then
  echo "  Render_Commit T-states:"
  sed 's/^/    /' "$BUILD_DIR/perf_results.txt"
fi
