#!/usr/bin/env python3
"""Create a deterministic 48K Spectrum SCR to verify emulator screenshot output."""
import pathlib
import sys

def main():
    target = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/zenzx/probe.scr")
    target.parent.mkdir(parents=True, exist_ok=True)
    bitmap = bytes([0xAA, 0x55]) * 3072
    attributes = bytes([0x47, 0x16, 0x2D, 0x70]) * 192
    data = bitmap + attributes
    assert len(data) == 6912
    target.write_bytes(data)
    print(f"Created {target} ({len(data)} bytes)")

if __name__ == "__main__":
    main()
