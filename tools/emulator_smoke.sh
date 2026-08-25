#!/usr/bin/env bash
set -euo pipefail

TAP_FILE="${1:-build/pac48.tap}"
OUT_DIR="${2:-build/emulator-smoke}"
DISPLAY_ID="${PAC48_TEST_DISPLAY:-:99}"

if [[ ! -s "$TAP_FILE" ]]; then
  echo "ERROR: TAP not found or empty: $TAP_FILE" >&2
  exit 1
fi

for cmd in Xvfb fuse xdotool import compare; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: required emulator-smoke command '$cmd' not found" >&2
    exit 1
  }
done

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/*.png "$OUT_DIR"/*.log "$OUT_DIR"/result.txt

export DISPLAY="$DISPLAY_ID"
Xvfb "$DISPLAY" -screen 0 1024x768x24 >"$OUT_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!
FUSE_PID=""

cleanup() {
  if [[ -n "$FUSE_PID" ]]; then
    kill "$FUSE_PID" >/dev/null 2>&1 || true
    wait "$FUSE_PID" >/dev/null 2>&1 || true
  fi
  kill "$XVFB_PID" >/dev/null 2>&1 || true
  wait "$XVFB_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 0.5

fuse --machine 48 --no-sound --accelerate-loader "$TAP_FILE" >"$OUT_DIR/fuse.log" 2>&1 &
FUSE_PID=$!

WINDOW_ID=""
for _ in $(seq 1 60); do
  WINDOW_ID="$(xdotool search --onlyvisible --name 'Fuse' 2>/dev/null | head -n1 || true)"
  if [[ -n "$WINDOW_ID" ]]; then
    break
  fi
  if ! kill -0 "$FUSE_PID" >/dev/null 2>&1; then
    echo "ERROR: Fuse exited before creating a window" >&2
    cat "$OUT_DIR/fuse.log" >&2 || true
    exit 1
  fi
  sleep 0.2
done

if [[ -z "$WINDOW_ID" ]]; then
  echo "ERROR: Fuse window was not found" >&2
  cat "$OUT_DIR/fuse.log" >&2 || true
  exit 1
fi

# Do not use windowactivate here: bare Xvfb has no window manager. xdotool's
# --window event delivery works directly against the Fuse X window.

# Accelerated autoload should reach PAC48's control menu quickly.
sleep 2
import -window "$WINDOW_ID" "$OUT_DIR/menu.png"

# Select keyboard mode (menu key 1) and capture the initial playfield.
xdotool key --window "$WINDOW_ID" 1
sleep 0.6
import -window "$WINDOW_ID" "$OUT_DIR/game-start.png"

# Hold P long enough for several 50 Hz polls, then capture the moved player.
xdotool keydown --window "$WINDOW_ID" p
sleep 0.35
xdotool keyup --window "$WINDOW_ID" p
sleep 0.2
import -window "$WINDOW_ID" "$OUT_DIR/moved-right.png"

if ! kill -0 "$FUSE_PID" >/dev/null 2>&1; then
  echo "ERROR: Fuse exited during PAC48 smoke test" >&2
  cat "$OUT_DIR/fuse.log" >&2 || true
  exit 1
fi

image_delta() {
  local before="$1"
  local after="$2"
  local metric
  metric="$(compare -metric AE "$before" "$after" null: 2>&1 || true)"
  metric="${metric%% *}"
  [[ "$metric" =~ ^[0-9]+$ ]] || {
    echo "ERROR: could not parse ImageMagick AE metric: '$metric'" >&2
    exit 1
  }
  printf '%s\n' "$metric"
}

MENU_TO_GAME="$(image_delta "$OUT_DIR/menu.png" "$OUT_DIR/game-start.png")"
GAME_TO_MOVE="$(image_delta "$OUT_DIR/game-start.png" "$OUT_DIR/moved-right.png")"

if (( MENU_TO_GAME < 500 )); then
  echo "ERROR: selecting keyboard did not produce a substantial screen change (AE=$MENU_TO_GAME)" >&2
  exit 1
fi

if (( GAME_TO_MOVE < 1 )); then
  echo "ERROR: holding P produced no visible frame change (AE=$GAME_TO_MOVE)" >&2
  exit 1
fi

cat >"$OUT_DIR/result.txt" <<EOF
PAC48 Fuse 48K smoke test passed
TAP: $TAP_FILE
menu_to_game_AE: $MENU_TO_GAME
game_to_move_AE: $GAME_TO_MOVE
EOF

cat "$OUT_DIR/result.txt"
