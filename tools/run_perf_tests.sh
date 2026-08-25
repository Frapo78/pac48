#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
HARNESS_BIN="$BUILD_DIR/perf_harness.bin"
ASSEMBLE_LOG="$BUILD_DIR/perf_harness_assemble.log"
RESULTS_FILE="$BUILD_DIR/perf_results.txt"
MEASURE_START=49000
MEASURE_STOP=49900
COMMON_TARGET=12000
WARNING_LIMIT=14000

for cmd in sjasmplus trace.py; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: required performance-test command '$cmd' not found" >&2
    exit 1
  }
done

mkdir -p "$BUILD_DIR"
cd "$ROOT_DIR"
test -s src/generated/pac_shifted.asm || {
  echo "ERROR: generated sprite include missing; run generator first" >&2
  exit 1
}

echo "Assembling Render_Commit performance harness..."
if ! sjasmplus --raw="$HARNESS_BIN" tests/perf_harness.asm 2>&1 | tee "$ASSEMBLE_LOG"; then
  echo "ERROR: performance harness assembly failed" >&2
  exit 1
fi

# Performance evidence is invalid if the harness assembly emitted warnings:
# a previous ORG/raw-file warning produced plausible but false equal timings.
if grep -qi 'warning' "$ASSEMBLE_LOG"; then
  echo "ERROR: performance harness assembly emitted warning(s); refusing timing evidence" >&2
  exit 1
fi

# Raw binary must physically cover the fixed measurement stop address.
EXPECTED_MIN_BYTES=$((MEASURE_STOP - 32768 + 1))
ACTUAL_BYTES="$(wc -c < "$HARNESS_BIN" | tr -d '[:space:]')"
if (( ACTUAL_BYTES < EXPECTED_MIN_BYTES )); then
  echo "ERROR: performance harness raw binary is $ACTUAL_BYTES bytes; expected at least $EXPECTED_MIN_BYTES" >&2
  exit 1
fi

measure_case() {
  local name="$1"
  local setup_start="$2"
  local snapshot="$BUILD_DIR/perf_${name}_ready.z80"
  local setup_log="$BUILD_DIR/perf_${name}_setup.log"
  local measure_log="$BUILD_DIR/perf_${name}_measure.log"

  trace.py \
    --org 32768 \
    --start "$setup_start" \
    --stop "$MEASURE_START" \
    --no-interrupts \
    --max-operations 500000 \
    "$HARNESS_BIN" "$snapshot" \
    >"$setup_log"

  trace.py \
    --start "$MEASURE_START" \
    --stop "$MEASURE_STOP" \
    --no-interrupts \
    --cmio \
    --state tstates=0 \
    --max-operations 100000 \
    --stats \
    "$snapshot" \
    >"$measure_log"

  local tstates
  tstates="$(sed -n 's/^Z80 execution time: \([0-9][0-9]*\) T-states.*/\1/p' "$measure_log" | head -n1)"
  if [[ ! "$tstates" =~ ^[0-9]+$ ]]; then
    echo "ERROR: could not parse T-state count for $name" >&2
    cat "$measure_log" >&2 || true
    exit 1
  fi

  printf '%s=%s\n' "$name" "$tstates" | tee -a "$RESULTS_FILE"
}

: >"$RESULTS_FILE"
measure_case common_dirty1 45000
measure_case cardinal_dirty2 46000
measure_case arbitrary_dirty4 47000

COMMON="$(awk -F= '$1=="common_dirty1" {print $2}' "$RESULTS_FILE")"
if (( COMMON > WARNING_LIMIT )); then
  echo "ERROR: common Render_Commit is $COMMON T-states, above $WARNING_LIMIT warning ceiling" >&2
  exit 1
fi

if (( COMMON > COMMON_TARGET )); then
  echo "WARNING: common Render_Commit is $COMMON T-states, above the $COMMON_TARGET engineering target" >&2
fi

echo "PAC48 Render_Commit performance measurements passed"
cat "$RESULTS_FILE"
