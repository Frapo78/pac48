#!/usr/bin/env python3
"""Deterministic structural checks for PAC48.

These checks are intentionally emulator-independent. They catch repository and
asset regressions before assembly/runtime verification.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

MAZE_WIDTH = 28
MAZE_HEIGHT = 20
EXPECTED_MAZE_CELLS = MAZE_WIDTH * MAZE_HEIGHT
EXPECTED_SHIFTED_SPRITES = 4 * 5 * 8


def fail(message: str) -> None:
    raise ValueError(message)


def check_maze(path: pathlib.Path) -> None:
    text = path.read_text(encoding="utf-8")
    marker = "Maze_Map:"
    if marker not in text:
        fail(f"{path}: missing {marker}")

    tail = text.split(marker, 1)[1]
    values: list[int] = []
    for line in tail.splitlines():
        code = line.split(";", 1)[0].strip()
        if not code.upper().startswith("DEFB"):
            continue
        payload = code[4:].strip()
        for token in payload.split(","):
            token = token.strip()
            if token:
                values.append(int(token, 0))

    if len(values) != EXPECTED_MAZE_CELLS:
        fail(
            f"{path}: Maze_Map has {len(values)} cells; "
            f"expected {EXPECTED_MAZE_CELLS} ({MAZE_WIDTH}x{MAZE_HEIGHT})"
        )
    invalid = sorted(set(values) - {0, 1, 2})
    if invalid:
        fail(f"{path}: unexpected maze cell values: {invalid}")


def check_generated_sprites(path: pathlib.Path) -> None:
    text = path.read_text(encoding="utf-8")
    labels = re.findall(
        r"^Pac_Shifted_(?:Right|Left|Up|Down)_F[0-4]_P[0-7]:$",
        text,
        flags=re.MULTILINE,
    )
    if len(labels) != EXPECTED_SHIFTED_SPRITES:
        fail(
            f"{path}: found {len(labels)} shifted sprite phases; "
            f"expected {EXPECTED_SHIFTED_SPRITES}"
        )

    for table in (
        "Pac_ShiftedTableRight:",
        "Pac_ShiftedTableLeft:",
        "Pac_ShiftedTableUp:",
        "Pac_ShiftedTableDown:",
    ):
        if table not in text:
            fail(f"{path}: missing pointer table {table}")


def check_binary(path: pathlib.Path, max_bytes: int) -> None:
    size = path.stat().st_size
    if size <= 0:
        fail(f"{path}: binary is empty")
    if size > max_bytes:
        fail(
            f"{path}: binary is {size} bytes; safe budget is {max_bytes} bytes "
            "from ORG 32768, reserving upper-RAM stack/headroom"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--maze", type=pathlib.Path, required=True)
    parser.add_argument("--generated-sprites", type=pathlib.Path, required=True)
    parser.add_argument("--binary", type=pathlib.Path)
    parser.add_argument("--max-binary-bytes", type=int, default=28672)
    args = parser.parse_args()

    try:
        check_maze(args.maze)
        check_generated_sprites(args.generated_sprites)
        if args.binary is not None:
            check_binary(args.binary, args.max_binary_bytes)
    except (OSError, ValueError) as exc:
        print(f"project check failed: {exc}", file=sys.stderr)
        return 1

    print("PAC48 structural checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
