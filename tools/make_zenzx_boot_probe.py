#!/usr/bin/env python3
"""Generate a minimal Z80 48K program that writes Spectrum screen RAM."""
from pathlib import Path
import sys

def main():
    target=Path(sys.argv[1] if len(sys.argv)>1 else "build/zenzx-probe/boot.bin")
    target.parent.mkdir(parents=True,exist_ok=True)
    # DI; LD SP,0xFFFF; LD HL,0x5800; LD (HL),0x47;
    # LD DE,0x5801; LD BC,767; LDIR; LD HL,0x4000;
    # LD (HL),0xAA; LD DE,0x4001; LD BC,6143; LDIR; HALT; JR -3
    program=bytes.fromhex("F3 31 FF FF 21 00 58 36 47 11 01 58 01 FF 02 ED B0 21 00 40 36 AA 11 01 40 01 FF 17 ED B0 76 18 FD")
    target.write_bytes(program)
    print(f"Created {target}: {len(program)} bytes, entry 0x8000")

if __name__=="__main__":
    main()
