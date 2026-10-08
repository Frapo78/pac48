#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMULATOR="${ZENZX_BIN:-zenzx-headless}"
OUT="${ZENZX_OUTPUT_DIR:-$ROOT/build/zenzx}"
FRAMES="${ZENZX_FRAMES:-120}"
command -v "$EMULATOR" >/dev/null || { echo "Missing ZenZX executable: $EMULATOR" >&2; exit 1; }
test -s "$ROOT/build/pac48.bin" || { echo "Build PAC48 first: ./tools/build.sh" >&2; exit 1; }
[[ "$FRAMES" =~ ^[1-9][0-9]*$ ]] || { echo "ZENZX_FRAMES must be positive integer" >&2; exit 1; }
mkdir -p "$OUT"
"$EMULATOR" -model=48k -bin="$ROOT/build/pac48.bin" -binaddr=0x8000 -frames="$FRAMES" -shot-dir="$OUT" -shot-prefix=pac48 >"$OUT/emulator.log" 2>&1
find "$OUT" -maxdepth 1 -name '*.png' -size +0c | grep -q . || { cat "$OUT/emulator.log"; echo "No nonempty emulator screenshot" >&2; exit 1; }
echo "ZenZX 48K screenshot smoke test passed; evidence in $OUT"
