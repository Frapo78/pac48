#!/usr/bin/env python3
"""Probe Spectrum ROM CLS after raw binary boot, then mark screen if it returns."""
from pathlib import Path
import sys
target=Path(sys.argv[1] if len(sys.argv)>1 else "build/zenzx-rom-probe/rom.bin")
target.parent.mkdir(parents=True,exist_ok=True)
# DI; LD SP,FFFF; CALL ROM_CLS ($0DAF); LD HL,5800; LD (HL),47;
# LD DE,5801; LD BC,767; LDIR; LD HL,4000; LD (HL),AA;
# LD DE,4001; LD BC,6143; LDIR; HALT; JR -3
program=bytes.fromhex("F3 31 FF FF CD AF 0D 21 00 58 36 47 11 01 58 01 FF 02 ED B0 21 00 40 36 AA 11 01 40 01 FF 17 ED B0 76 18 FD")
target.write_bytes(program)
print(f"Created {target}: {len(program)} bytes")
