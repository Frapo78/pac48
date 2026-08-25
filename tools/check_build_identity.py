#!/usr/bin/env python3
"""Build/version identity guards for PAC48.

Keeps VERSION as the single semantic-version source and guarantees that the
playable binary contains a generated, screenshot-visible version/build stamp.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys


def fail(message: str) -> None:
    raise ValueError(message)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", type=pathlib.Path, required=True)
    parser.add_argument("--build-info", type=pathlib.Path, required=True)
    parser.add_argument("--main", type=pathlib.Path, required=True)
    parser.add_argument("--menu", type=pathlib.Path, required=True)
    args = parser.parse_args()

    try:
        version = args.version.read_text(encoding="utf-8").strip()
        build_info = args.build_info.read_text(encoding="utf-8")
        main_asm = args.main.read_text(encoding="utf-8")
        menu_asm = args.menu.read_text(encoding="utf-8")

        if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", version):
            fail(f"{args.version}: unsupported VERSION format: {version!r}")

        core = version.split("-", 1)[0]
        if f'DB "PAC48 {version}",13,0' not in build_info:
            fail("generated build info does not contain the canonical full menu version")

        label_match = re.search(r'Build_ScreenLabel:\s*\n\s*DB "([^"]+)",0', build_info)
        if not label_match:
            fail("generated build info is missing Build_ScreenLabel")
        label = label_match.group(1)
        if not re.fullmatch(rf"V{re.escape(core)} B(?:[0-9A-F]{{7}}|D[0-9A-F]{{6}})", label):
            fail(f"generated screen label has unexpected format: {label!r}")

        x_match = re.search(r"Build_ScreenLabelX\s+EQU\s+(\d+)", build_info)
        width_match = re.search(r"Build_ScreenLabelWidth\s+EQU\s+(\d+)", build_info)
        if not x_match or not width_match:
            fail("generated build info is missing label X/width constants")
        x = int(x_match.group(1))
        width = int(width_match.group(1))
        if width != len(label) * 4 - 1:
            fail("generated label width does not match 3x5 font spacing")
        if x != (256 - width) // 2:
            fail("generated label is not horizontally centered")
        if x < 0 or x + width > 256:
            fail("generated label does not fit the Spectrum screen")

        if 'INCLUDE "generated/build_info.asm"' not in main_asm:
            fail("src/main.asm does not include generated build metadata")
        if 'INCLUDE "hud.asm"' not in main_asm:
            fail("src/main.asm does not include the mini-HUD renderer")
        if not re.search(r"\bCALL\s+HUD_DrawBuildStamp\b", main_asm, flags=re.IGNORECASE):
            fail("src/main.asm does not draw the version/build stamp at startup")

        # Semantic version strings belong in VERSION/generated output only.
        if re.search(r"PAC48\s+\d+\.\d+\.\d+", menu_asm):
            fail("src/menu.asm hardcodes a semantic version; use Build_MenuTitle")
        if "Build_MenuTitle" not in menu_asm:
            fail("src/menu.asm does not use the generated menu title")

        # User-facing invariant: Kempston FIRE must be a direct start shortcut.
        if not re.search(r"LD\s+BC,\s*PORT_KEMPSTON", menu_asm, flags=re.IGNORECASE):
            fail("src/menu.asm does not poll Kempston in the control menu")
        if not re.search(r"BIT\s+4,\s*A", menu_asm, flags=re.IGNORECASE):
            fail("src/menu.asm does not test Kempston FIRE bit 4")
        if not re.search(r"JR\s+NZ,\s*\.choose_kempston", menu_asm, flags=re.IGNORECASE):
            fail("Kempston FIRE does not select Kempston mode")

    except (OSError, ValueError) as exc:
        print(f"build identity check failed: {exc}", file=sys.stderr)
        return 1

    print(f"PAC48 build identity checks passed: {label}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
