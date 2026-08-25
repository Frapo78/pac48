#!/usr/bin/env python3
"""Validate PAC48 maze topology, not just dimensions.

The player-visible maze must remain a connected, symmetric arcade-style graph.
Normal pellets may never be stranded in inaccessible islands. Empty cells are
allowed for future house/metadata reservations, but if they are part of the
player component they must not create accidental dead ends.

The functional centre tunnel is part of the graph: its left/right endpoint
cells are adjacent even though they live on opposite sides of Maze_Map.
"""

from __future__ import annotations

import argparse
from collections import deque
import pathlib
import re
import sys


def fail(message: str) -> None:
    raise ValueError(message)


def parse_equ(text: str, name: str) -> int:
    match = re.search(rf"^\s*{re.escape(name)}\s+EQU\s+(\d+)\s*$", text, re.MULTILINE)
    if not match:
        fail(f"missing numeric {name} EQU")
    return int(match.group(1))


def parse_rows(text: str) -> list[list[int]]:
    if "Maze_Map:" not in text:
        fail("maze source is missing Maze_Map")
    tail = text.split("Maze_Map:", 1)[1]
    rows: list[list[int]] = []
    for line in tail.splitlines():
        code = line.split(";", 1)[0].strip()
        if not code.upper().startswith("DEFB"):
            continue
        rows.append([int(part.strip(), 0) for part in code[4:].split(",") if part.strip()])
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--maze", type=pathlib.Path, required=True)
    parser.add_argument("--config", type=pathlib.Path, required=True)
    args = parser.parse_args()

    try:
        maze_text = args.maze.read_text(encoding="utf-8")
        config_text = args.config.read_text(encoding="utf-8")
        width = parse_equ(config_text, "Maze_Width")
        height = parse_equ(config_text, "Maze_Height")
        start_x = parse_equ(config_text, "Pac_StartX")
        start_y = parse_equ(config_text, "Pac_StartY")
        tunnel_y = parse_equ(config_text, "Maze_TunnelRow")
        tunnel_left = parse_equ(config_text, "Maze_TunnelLeftX")
        tunnel_right = parse_equ(config_text, "Maze_TunnelRightX")
        rows = parse_rows(maze_text)

        if len(rows) != height:
            fail(f"maze has {len(rows)} rows; expected {height}")
        for y, row in enumerate(rows):
            if len(row) != width:
                fail(f"maze row {y} has {len(row)} cells; expected {width}")
            if row != list(reversed(row)):
                fail(f"maze row {y} broke required horizontal symmetry")

        if not (0 <= start_x < width and 0 <= start_y < height):
            fail(f"Pac start {(start_x, start_y)} is outside the maze")
        if rows[start_y][start_x] == 1:
            fail(f"Pac start {(start_x, start_y)} is a wall")

        if not (0 <= tunnel_y < height):
            fail(f"tunnel row {tunnel_y} is outside maze height {height}")
        if tunnel_left != 0 or tunnel_right != width - 1:
            fail(
                f"functional tunnel must join edge cells 0 and {width - 1}; "
                f"got {tunnel_left} and {tunnel_right}"
            )
        if rows[tunnel_y][tunnel_left] == 1 or rows[tunnel_y][tunnel_right] == 1:
            fail("functional tunnel endpoints must be walkable")

        walkable = {
            (x, y)
            for y, row in enumerate(rows)
            for x, value in enumerate(row)
            if value != 1
        }
        pellets = {
            (x, y)
            for y, row in enumerate(rows)
            for x, value in enumerate(row)
            if value == 0
        }

        def neighbours(pos: tuple[int, int]) -> list[tuple[int, int]]:
            x, y = pos
            result: list[tuple[int, int]] = []
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                candidate = (x + dx, y + dy)
                if candidate in walkable:
                    result.append(candidate)

            if y == tunnel_y:
                if x == tunnel_left:
                    result.append((tunnel_right, tunnel_y))
                elif x == tunnel_right:
                    result.append((tunnel_left, tunnel_y))
            return result

        start = (start_x, start_y)
        seen = {start}
        queue = deque([start])
        while queue:
            pos = queue.popleft()
            for candidate in neighbours(pos):
                if candidate not in seen:
                    seen.add(candidate)
                    queue.append(candidate)

        unreachable_pellets = sorted(pellets - seen)
        if unreachable_pellets:
            preview = ", ".join(map(str, unreachable_pellets[:12]))
            fail(
                f"{len(unreachable_pellets)} pellet cells are unreachable from Pac start; "
                f"first: {preview}"
            )

        dead_ends: list[tuple[int, int]] = []
        for pos in seen:
            degree = len(set(neighbours(pos)))
            if degree <= 1:
                dead_ends.append(pos)
        if dead_ends:
            fail(f"player component contains dead ends: {sorted(dead_ends)}")

        print(
            "PAC48 maze topology passed: "
            f"{width}x{height}, {len(seen)} player-reachable cells, "
            f"{len(pellets)} reachable pellets, functional tunnel "
            f"({tunnel_left},{tunnel_y})<->({tunnel_right},{tunnel_y}), 0 dead ends"
        )
        return 0
    except (OSError, ValueError) as exc:
        print(f"maze topology check failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
