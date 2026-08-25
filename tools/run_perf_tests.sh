#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
HARNESS_BIN="$BUILD_DIR/perf_harness.bin"
EXPORT_FILE="$BUILD_DIR/perf_harness.exp"
ASSEMBLE_LOG="$BUILD_DIR/perf_harness_assemble.log"
RESULTS_FILE="$BUILD_DIR/perf_results.txt"
COMMON_TARGET=12000
WARNING_LIMIT=14000

for cmd in sjasmplus trace.py od; do
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
if ! sjasmplus \
  --raw="$HARNESS_BIN" \
  --exp="$EXPORT_FILE" \
  tests/perf_harness.asm 2>&1 | tee "$ASSEMBLE_LOG"; then
  echo "ERROR: performance harness assembly failed" >&2
  exit 1
fi

WARNING_COUNT="$(sed -n 's/.*warnings: \([0-9][0-9]*\).*/\1/p' "$ASSEMBLE_LOG" | tail -n1)"
if [[ ! "$WARNING_COUNT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: could not parse sjasmplus warning count" >&2
  exit 1
fi
if (( WARNING_COUNT != 0 )); then
  echo "ERROR: performance harness assembly emitted $WARNING_COUNT warning(s); refusing timing evidence" >&2
  exit 1
fi

test -s "$EXPORT_FILE" || {
  echo "ERROR: sjasmplus did not create performance export file" >&2
  exit 1
}

export_addr() {
  local label="$1"
  local value
  value="$(awk -v label="$label:" '$1 == label && toupper($2) == "EQU" {print $3; exit}' "$EXPORT_FILE")"
  if [[ ! "$value" =~ ^0x[0-9A-Fa-f]+$ && ! "$value" =~ ^[0-9]+$ ]]; then
    echo "ERROR: could not resolve exported label $label from $EXPORT_FILE" >&2
    cat "$EXPORT_FILE" >&2
    exit 1
  fi
  printf '%d\n' "$((value))"
}

COMMON_SETUP="$(export_addr Perf_CommonSetup)"
DIRTY2_SETUP="$(export_addr Perf_Dirty2Setup)"
DIRTY4_SETUP="$(export_addr Perf_Dirty4Setup)"
MEASURE_START="$(export_addr Perf_MeasureStart)"
MEASURE_STOP="$(export_addr Perf_MeasureStop)"

if ! (( 32768 <= COMMON_SETUP && COMMON_SETUP < DIRTY2_SETUP && DIRTY2_SETUP < DIRTY4_SETUP && DIRTY4_SETUP < MEASURE_START && MEASURE_START < MEASURE_STOP && MEASURE_STOP < 65536 )); then
  echo "ERROR: exported performance labels are not in expected increasing 48K RAM order" >&2
  cat "$EXPORT_FILE" >&2
  exit 1
fi

# Validate the raw-file/address mapping before tracing: Perf_MeasureStart must
# physically contain a Z80 CALL opcode ($CD), not padding/implicit RAM.
MEASURE_OFFSET=$((MEASURE_START - 32768))
FIRST_OPCODE="$(od -An -tu1 -j "$MEASURE_OFFSET" -N1 "$HARNESS_BIN" | tr -d '[:space:]')"
if [[ "$FIRST_OPCODE" != "205" ]]; then
  echo "ERROR: raw byte at Perf_MeasureStart=$MEASURE_START is $FIRST_OPCODE, expected CALL opcode 205" >&2
  exit 1
fi

echo "Performance labels: common=$COMMON_SETUP dirty2=$DIRTY2_SETUP dirty4=$DIRTY4_SETUP measure=$MEASURE_START stop=$MEASURE_STOP"

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

  # Confirm that the snapshot still contains CALL at the measurement PC by
  # tracing exactly one instruction verbosely. This prevents a setup/snapshot
  # mismatch from becoming plausible-looking timing data.
  local first_trace
  first_trace="$(trace.py --start "$MEASURE_START" --no-interrupts --max-operations 1 --verbose "$snapshot" 2>&1 || true)"
  if ! grep -q 'CALL' <<<"$first_trace"; then
    echo "ERROR: $name snapshot does not execute CALL at Perf_MeasureStart" >&2
    echo "$first_trace" >&2
    exit 1
  fi

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

  local tstates instructions
  tstates="$(sed -n 's/^Z80 execution time: \([0-9][0-9]*\) T-states.*/\1/p' "$measure_log" | head -n1)"
  instructions="$(sed -n 's/^Instructions executed: \([0-9][0-9]*\).*/\1/p' "$measure_log" | head -n1)"
  if [[ ! "$tstates" =~ ^[0-9]+$ || ! "$instructions" =~ ^[0-9]+$ ]]; then
    echo "ERROR: could not parse timing stats for $name" >&2
    cat "$measure_log" >&2 || true
    exit 1
  fi

  # A real Render_Commit necessarily executes more than the six-byte wrapper;
  # hundreds of straight NOPs was the signature of INC-2026-006.
  if (( instructions < 50 )); then
    echo "ERROR: $name executed only $instructions instructions; measurement is not credible" >&2
    exit 1
  fi

  printf '%s=%s instructions=%s\n' "$name" "$tstates" "$instructions" | tee -a "$RESULTS_FILE"
}

: >"$RESULTS_FILE"
measure_case common_dirty1 "$COMMON_SETUP"
measure_case cardinal_dirty2 "$DIRTY2_SETUP"
measure_case arbitrary_dirty4 "$DIRTY4_SETUP"

COMMON="$(awk -F'[= ]' '$1=="common_dirty1" {print $2}' "$RESULTS_FILE")"
if (( COMMON > WARNING_LIMIT )); then
  echo "ERROR: common Render_Commit is $COMMON T-states, above $WARNING_LIMIT warning ceiling" >&2
  exit 1
fi

if (( COMMON > COMMON_TARGET )); then
  echo "WARNING: common Render_Commit is $COMMON T-states, above the $COMMON_TARGET engineering target" >&2
fi

echo "PAC48 Render_Commit performance measurements passed"
cat "$RESULTS_FILE"
