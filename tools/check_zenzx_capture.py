#!/usr/bin/env python3
"""Fail closed on black/blank ZenZX captures without external dependencies."""
import argparse
import pathlib
import struct
import zlib

def pixels(path):
    data = pathlib.Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Not a PNG")
    pos = 8
    raw = bytearray()
    width = height = color = None
    while pos < len(data):
        size = struct.unpack_from(">I", data, pos)[0]
        kind = data[pos+4:pos+8]
        payload = data[pos+8:pos+8+size]
        pos += size + 12
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            if (width,height,depth,color,compression,filtering,interlace) != (256,192,8,2,0,0,0):
                raise ValueError("Expected 256x192 RGB8 noninterlaced PNG")
        if kind == b"IDAT":
            raw.extend(payload)
        if kind == b"IEND":
            break
    if width is None:
        raise ValueError("Missing IHDR")
    decoded = zlib.decompress(raw)
    stride = width * 3
    previous = bytearray(stride)
    colors = set()
    offset = 0
    for _ in range(height):
        mode = decoded[offset]
        offset += 1
        row = bytearray(decoded[offset:offset+stride])
        offset += stride
        for i in range(stride):
            left = row[i-3] if i >= 3 else 0
            up = previous[i]
            upper_left = previous[i-3] if i >= 3 else 0
            if mode == 0: predictor = 0
            elif mode == 1: predictor = left
            elif mode == 2: predictor = up
            elif mode == 3: predictor = (left+up)//2
            elif mode == 4:
                p = left + up - upper_left
                distances = (abs(p-left),abs(p-up),abs(p-upper_left))
                predictor = (left,up,upper_left)[distances.index(min(distances))]
            else: raise ValueError("Invalid PNG filter")
            row[i] = (row[i] + predictor) & 255
        colors.update(tuple(row[i:i+3]) for i in range(0,stride,3))
        previous = row
    return colors

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("captures", nargs="+", type=pathlib.Path)
    args = parser.parse_args()
    for path in args.captures:
        colors = pixels(path)
        print(f"{path}: {len(colors)} distinct RGB colors")
        if len(colors) < 2:
            raise SystemExit(f"FAIL: blank/monochrome capture: {path}")
    print("PASS: all captures contain visible color variation")

if __name__ == "__main__":
    main()
