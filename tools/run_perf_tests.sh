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
ORG_ADDR=32768

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

MEASURE_START="$(export_addr Perf_MeasureStart)"
MEASURE_STOP="$(export_addr Perf_MeasureStop)"
RENDER_PLAYER_X="$(export_addr Render_PlayerX)"
RENDER_PLAYER_Y="$(export_addr Render_PlayerY)"
RENDER_PLAYER_SPRITE="$(export_addr Render_PlayerSprite)"
DIRTY_COUNT="$(export_addr Render_DirtyCount)"
NEXT_DIRTY_COUNT="$(export_addr Render_NextDirtyCount)"
DIRTY_CELLS="$(export_addr Render_DirtyCells)"
NEXT_DIRTY_CELLS="$(export_addr Render_NextDirtyCells)"
LINE_TABLE="$(export_addr Video_LineAddrTable)"
SPRITE_PHASE1="$(export_addr Pac_Shifted_Right_F0_P1)"
SPRITE_PHASE2="$(export_addr Pac_Shifted_Right_F0_P2)"

if ! (( ORG_ADDR <= MEASURE_START && MEASURE_START < MEASURE_STOP && MEASURE_STOP < 65536 )); then
  echo "ERROR: exported performance wrapper is outside expected 48K RAM range" >&2
  cat "$EXPORT_FILE" >&2
  exit 1
fi

# Exact-code guard: Perf_MeasureStart must physically be CALL ($CD) in the raw
# file. Performance evidence is rejected if assembler/export/raw addressing
# disagree for any reason.
MEASURE_OFFSET=$((MEASURE_START - ORG_ADDR))
FIRST_OPCODE="$(od -An -tu1 -j "$MEASURE_OFFSET" -N1 "$HARNESS_BIN" | tr -d '[:space:]')"
if [[ "$FIRST_OPCODE" != "205" ]]; then
  echo "ERROR: raw byte at Perf_MeasureStart=$MEASURE_START is $FIRST_OPCODE, expected CALL opcode 205" >&2
  exit 1
fi

# Build the 192-entry Spectrum bitmap scanline LUT exactly as startup does.
# Each trace invocation starts from the same raw binary and receives the same
# deterministic LUT through --poke, avoiding snapshot serialisation entirely.
LINE_POKES=()
for ((y=0; y<192; y++)); do
  addr=$((0x4000 | ((y & 0xC0) << 5) | ((y & 7) << 8) | ((y & 0x38) << 2)))
  table_addr=$((LINE_TABLE + y * 2))
  LINE_POKES+=(--poke "$table_addr,$((addr & 0xFF))")
  LINE_POKES+=(--poke "$((table_addr + 1)),$(((addr >> 8) & 0xFF))")
done

add_word_pokes() {
  local -n target=$1
  local address=$2
  local value=$3
  target+=(--poke "$address,$((value & 0xFF))")
  target+=(--poke "$((address + 1)),$(((value >> 8) & 0xFF))")
}

add_cell_pokes() {
  local -n target=$1
  local base=$2
  shift 2
  local offset=0 cell x y
  for cell in "$@"; do
    IFS=',' read -r x y <<<"$cell"
    target+=(--poke "$((base + offset)),$x")
    target+=(--poke "$((base + offset + 1)),$y")
    offset=$((offset + 2))
  done
}

measure_case() {
  local name="$1"
  local previous_dirty_count="$2"
  local next_dirty_count="$3"
  local player_x="$4"
  local player_y="$5"
  local sprite_ptr="$6"
  local previous_cells_csv="$7"
  local next_cells_csv="$8"
  local measure_log="$BUILD_DIR/perf_${name}_measure.log"

  IFS=';' read -ra previous_cells <<<"$previous_cells_csv"
  IFS=';' read -ra next_cells <<<"$next_cells_csv"

  local pokes=("${LINE_POKES[@]}")
  pokes+=(--poke "$DIRTY_COUNT,$previous_dirty_count")
  pokes+=(--poke "$NEXT_DIRTY_COUNT,$next_dirty_count")
  pokes+=(--poke "$RENDER_PLAYER_X,$player_x")
  pokes+=(--poke "$RENDER_PLAYER_Y,$player_y")
  add_word_pokes pokes "$RENDER_PLAYER_SPRITE" "$sprite_ptr"
  add_cell_pokes pokes "$DIRTY_CELLS" "${previous_cells[@]}"
  add_cell_pokes pokes "$NEXT_DIRTY_CELLS" "${next_cells[@]}"

  trace.py \
    --org "$ORG_ADDR" \
    --start "$MEASURE_START" \
    --stop "$MEASURE_STOP" \
    --no-interrupts \
    --cmio \
    --state tstates=0 \
    --reg sp=64000 \
    --max-operations 100000 \
    --stats \
    "${pokes[@]}" \
    "$HARNESS_BIN" \
    >"$measure_log"

  local tstates instructions
  tstates="$(sed -n 's/^Z80 execution time: \([0-9][0-9]*\) T-states.*/\1/p' "$measure_log" | head -n1)"
  instructions="$(sed -n 's/^Instructions executed: \([0-9][0-9]*\).*/\1/p' "$measure_log" | head -n1)"
  if [[ ! "$tstates" =~ ^[0-9]+$ || ! "$instructions" =~ ^[0-9]+$ ]]; then
    echo "ERROR: could not parse timing stats for $name" >&2
    cat "$measure_log" >&2 || true
    exit 1
  fi

  if (( instructions < 50 )); then
    echo "ERROR: $name executed only $instructions instructions; measurement is not credible" >&2
    exit 1
  fi

  printf '%s=%s instructions=%s dirty=%s next_dirty=%s\n' \
    "$name" "$tstates" "$instructions" "$previous_dirty_count" "$next_dirty_count" \
    | tee -a "$RESULTS_FILE"
}

: >"$RESULTS_FILE"

# Common frame: restore one aligned previous cell, draw a phase-1 player, then
# promote the two cells touched by the newly prepared horizontal phase.
measure_case \
  common_dirty1 1 2 25 24 "$SPRITE_PHASE1" \
  '1,1' '1,1;2,1'

# Current cardinal worst case: restore two horizontal cells and draw phase 2.
measure_case \
  cardinal_dirty2 2 2 26 24 "$SPRITE_PHASE2" \
  '1,1;2,1' '1,1;2,1'

# General arbitrary-position 8x8 case for future actors: four dirty cells.
measure_case \
  arbitrary_dirty4 4 4 26 26 "$SPRITE_PHASE2" \
  '1,1;2,1;1,2;2,2' '1,1;2,1;1,2;2,2'

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
