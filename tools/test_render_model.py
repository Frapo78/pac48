#!/usr/bin/env python3
"""Reference-model regression tests for PAC48's renderer.

These tests do not emulate Z80 instructions. They validate the invariants the
assembly renderer depends on: Spectrum scanline addressing, pre-shifted sprite
layout, masked compositing, and dirty-cell coverage.
"""

from __future__ import annotations

import importlib.util
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GENERATOR = ROOT / "tools" / "gen_shifted_sprites.py"
SPRITES = ROOT / "src" / "sprites.asm"


def load_generator():
    spec = importlib.util.spec_from_file_location("pac48_sprite_generator", GENERATOR)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load sprite generator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def spectrum_line_address(y: int) -> int:
    if not 0 <= y < 192:
        raise ValueError(y)
    return 0x4000 + ((y & 0xC0) << 5) + ((y & 0x07) << 8) + ((y & 0x38) << 2)


def assembly_formula_model(y: int) -> int:
    # Mirrors Video_CalcLineAddress, expressed without depending on the Z80.
    high = 0x40 + ((y & 0xC0) >> 3) + (y & 0x07)
    low = (y & 0x38) << 2
    return (high << 8) | low


def touched_cells(x_px: int, y_px: int, offset_x: int = 2, offset_y: int = 2):
    tile_x = (x_px >> 3) - offset_x
    tile_y = (y_px >> 3) - offset_y
    cells = {(tile_x, tile_y)}
    if x_px & 7:
        cells.add((tile_x + 1, tile_y))
    if y_px & 7:
        cells.add((tile_x, tile_y + 1))
    if (x_px & 7) and (y_px & 7):
        cells.add((tile_x + 1, tile_y + 1))
    return cells


def test_scanline_addresses() -> None:
    addresses = []
    for y in range(192):
        expected = spectrum_line_address(y)
        actual = assembly_formula_model(y)
        assert actual == expected, (y, hex(actual), hex(expected))
        assert 0x4000 <= actual <= 0x57E0, (y, hex(actual))
        addresses.append(actual)
    assert len(set(addresses)) == 192


def test_shift_and_mask_model() -> None:
    gen = load_generator()
    frames = gen.parse_frames(SPRITES)
    assert len(frames) == 20

    for label, rows in frames.items():
        assert len(rows) == 8, label
        for row in rows:
            for phase in range(8):
                mask_l, image_l, mask_r, image_r = gen.shifted_row(row, phase)

                # Occupied pixels are exactly the inverse mask bits in the
                # current transparency model.
                assert mask_l == ((~image_l) & 0xFF)
                assert mask_r == ((~image_r) & 0xFF)

                # The two generated image bytes must equal an 8-bit source
                # shifted right inside a 16-bit two-byte window.
                expected16 = ((row << 8) >> phase) & 0xFFFF
                actual16 = (image_l << 8) | image_r
                assert actual16 == expected16, (label, row, phase)

                # Masked drawing must preserve every transparent background
                # bit and force every sprite bit on, regardless of background.
                for background_l, background_r in (
                    (0x00, 0x00),
                    (0xFF, 0xFF),
                    (0xAA, 0x55),
                    (0x3C, 0xC3),
                ):
                    out_l = (background_l & mask_l) | image_l
                    out_r = (background_r & mask_r) | image_r
                    assert (out_l & image_l) == image_l
                    assert (out_r & image_r) == image_r
                    assert ((out_l ^ background_l) & mask_l) == 0
                    assert ((out_r ^ background_r) & mask_r) == 0


def test_dirty_cell_coverage() -> None:
    # The current renderer supports arbitrary x/y phases, even though the
    # player moves cardinally. Verify the general maximum of four cells.
    for x_phase in range(8):
        for y_phase in range(8):
            x = 8 * 10 + x_phase
            y = 8 * 10 + y_phase
            cells = touched_cells(x, y)
            expected = 1 + (1 if x_phase else 0)
            expected *= 1 + (1 if y_phase else 0)
            assert len(cells) == expected, (x_phase, y_phase, cells)
            assert len(cells) <= 4

    # Current cardinal one-pixel movement remains aligned on one axis and thus
    # touches at most two cells; this is the common player budget.
    for phase in range(8):
        horizontal = touched_cells(8 * 10 + phase, 8 * 10)
        vertical = touched_cells(8 * 10, 8 * 10 + phase)
        assert len(horizontal) <= 2
        assert len(vertical) <= 2


def main() -> int:
    tests = (
        test_scanline_addresses,
        test_shift_and_mask_model,
        test_dirty_cell_coverage,
    )
    try:
        for test in tests:
            test()
            print(f"PASS {test.__name__}")
    except (AssertionError, OSError, RuntimeError, ValueError) as exc:
        print(f"renderer model test failed: {exc}", file=sys.stderr)
        return 1

    print("PAC48 renderer reference-model tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
