#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
HARNESS_BIN="$BUILD_DIR/runtime_harness.bin"
HARNESS_SNAPSHOT="$BUILD_DIR/runtime_harness.z80"
HARNESS_LOG="$BUILD_DIR/runtime_harness.trace.log"
TEST_RESULT_ADDR=65000
TEST_STOP_ADDR=50000

for cmd in sjasmplus trace.py snapinfo.py; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: required runtime-test command '$cmd' not found" >&2
    exit 1
  }
done

mkdir -p "$BUILD_DIR"
cd "$ROOT_DIR"

# Generated sprite data must already exist; canonical build creates it before
# invoking this script.
test -s src/generated/pac_shifted.asm || {
  echo "ERROR: generated sprite include missing; run generator first" >&2
  exit 1
}

echo "Assembling headless Z80 runtime harness..."
sjasmplus --raw="$HARNESS_BIN" tests/runtime_harness.asm

echo "Executing harness in SkoolKit 48K Z80 simulator..."
trace.py \
  --org 32768 \
  --start 32768 \
  --stop "$TEST_STOP_ADDR" \
  --no-interrupts \
  --max-operations 500000 \
  --stats \
  "$HARNESS_BIN" "$HARNESS_SNAPSHOT" \
  >"$HARNESS_LOG"

test -s "$HARNESS_SNAPSHOT" || {
  echo "ERROR: runtime harness did not produce a snapshot" >&2
  cat "$HARNESS_LOG" >&2 || true
  exit 1
}

RESULT_LINE="$(snapinfo.py --peek "$TEST_RESULT_ADDR" "$HARNESS_SNAPSHOT" | head -n1)"
RESULT="$(awk '{print $3}' <<<"$RESULT_LINE")"

if [[ ! "$RESULT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: could not parse runtime harness result from: $RESULT_LINE" >&2
  cat "$HARNESS_LOG" >&2 || true
  exit 1
fi

if (( RESULT != 0 )); then
  echo "ERROR: PAC48 Z80 runtime harness failed with code $RESULT" >&2
  cat "$HARNESS_LOG" >&2 || true
  exit 1
fi

echo "PAC48 headless Z80 runtime harness passed"
cat "$HARNESS_LOG"
