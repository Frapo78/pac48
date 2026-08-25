#!/usr/bin/env python3
"""Generate masked, horizontally pre-shifted PAC48 actor sprites.

Canonical player frames remain in src/sprites.asm. This tool extracts the 8x8
Pac_* frame labels, expands each frame into eight horizontal phases, and emits
assembly data suitable for the masked renderer.

Each generated row is four bytes:
    mask_left, image_left, mask_right, image_right

The renderer applies:
    screen = (screen & mask) | image
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

FRAME_GROUPS = {
    "Right": [f"Pac_Frame{i}" for i in range(5)],
    "Left": [f"Pac_FrameLeft{i}" for i in range(5)],
    "Up": [f"Pac_FrameUp{i}" for i in range(5)],
    "Down": [f"Pac_FrameDown{i}" for i in range(5)],
}

LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):\s*$")
ROW_RE = re.compile(r"^\s*DEFB\s+%([01]{8})\s*(?:;.*)?$", re.IGNORECASE)


def parse_frames(path: pathlib.Path) -> dict[str, list[int]]:
    wanted = {label for labels in FRAME_GROUPS.values() for label in labels}
    frames: dict[str, list[int]] = {}
    current: str | None = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        label_match = LABEL_RE.match(line.strip())
        if label_match:
            label = label_match.group(1)
            current = label if label in wanted else None
            if current is not None:
                if current in frames:
                    raise ValueError(f"duplicate sprite label: {current}")
                frames[current] = []
            continue

        if current is None:
            continue

        row_match = ROW_RE.match(line)
        if row_match:
            frames[current].append(int(row_match.group(1), 2))
            if len(frames[current]) > 8:
                raise ValueError(f"{current} contains more than 8 bitmap rows")

    missing = sorted(wanted - frames.keys())
    if missing:
        raise ValueError(f"missing canonical sprite frames: {', '.join(missing)}")

    for label in sorted(wanted):
        if len(frames[label]) != 8:
            raise ValueError(f"{label} must contain exactly 8 rows, got {len(frames[label])}")

    return frames


def shifted_row(row: int, phase: int) -> tuple[int, int, int, int]:
    if not 0 <= row <= 0xFF:
        raise ValueError("sprite row outside byte range")
    if not 0 <= phase <= 7:
        raise ValueError("phase outside 0..7")

    image16 = ((row << 8) >> phase) & 0xFFFF
    mask16 = (~image16) & 0xFFFF

    mask_left = (mask16 >> 8) & 0xFF
    image_left = (image16 >> 8) & 0xFF
    mask_right = mask16 & 0xFF
    image_right = image16 & 0xFF
    return mask_left, image_left, mask_right, image_right


def bits(value: int) -> str:
    return f"%{value:08b}"


def generate(frames: dict[str, list[int]], source_name: str) -> str:
    out: list[str] = [
        "; ============================================================",
        "; GENERATED FILE - DO NOT EDIT BY HAND",
        f"; Source: {source_name}",
        "; Generator: tools/gen_shifted_sprites.py",
        "; Row layout: maskL, imageL, maskR, imageR",
        "; ============================================================",
        "",
    ]

    for direction, labels in FRAME_GROUPS.items():
        out.append(f"; ---- {direction} ------------------------------------------------")
        for frame_index, canonical_label in enumerate(labels):
            rows = frames[canonical_label]
            for phase in range(8):
                generated_label = f"Pac_Shifted_{direction}_F{frame_index}_P{phase}"
                out.append(f"{generated_label}:")
                for row in rows:
                    mask_l, image_l, mask_r, image_r = shifted_row(row, phase)
                    out.append(
                        "    DEFB "
                        + ", ".join(
                            (bits(mask_l), bits(image_l), bits(mask_r), bits(image_r))
                        )
                    )
                out.append("")

        out.append(f"Pac_ShiftedTable{direction}:")
        for frame_index in range(5):
            labels_for_frame = [
                f"Pac_Shifted_{direction}_F{frame_index}_P{phase}" for phase in range(8)
            ]
            out.append("    DW " + ", ".join(labels_for_frame))
        out.append("")

    return "\n".join(out).rstrip() + "\n"


def self_check(frames: dict[str, list[int]]) -> None:
    # Phase zero must reproduce the canonical byte in the left byte and leave
    # the spill byte transparent. Every mask must be the inverse occupancy of
    # the corresponding generated image bits.
    for rows in frames.values():
        for row in rows:
            m_l, i_l, m_r, i_r = shifted_row(row, 0)
            if i_l != row or i_r != 0 or m_l != ((~row) & 0xFF) or m_r != 0xFF:
                raise AssertionError("phase-0 generation invariant failed")
            for phase in range(8):
                m_l, i_l, m_r, i_r = shifted_row(row, phase)
                if m_l != ((~i_l) & 0xFF) or m_r != ((~i_r) & 0xFF):
                    raise AssertionError("mask/image invariant failed")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify that an existing output exactly matches regenerated content",
    )
    args = parser.parse_args()

    try:
        frames = parse_frames(args.source)
        self_check(frames)
        generated = generate(frames, args.source.as_posix())
    except (OSError, ValueError, AssertionError) as exc:
        print(f"sprite generation error: {exc}", file=sys.stderr)
        return 1

    if args.check:
        try:
            existing = args.output.read_text(encoding="utf-8")
        except OSError as exc:
            print(f"sprite generation check error: {exc}", file=sys.stderr)
            return 1
        if existing != generated:
            print(f"generated sprite file is stale: {args.output}", file=sys.stderr)
            return 1
        return 0

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(generated, encoding="utf-8")
    print(f"Generated {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
