import pathlib
import struct
import tempfile
import unittest
import zlib
from tools.check_zenzx_capture import pixels

def png(rgb):
    width, height = 256, 192
    rows = b"".join(b"\x00" + rgb * width for _ in range(height))
    def chunk(kind, data):
        return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data)&0xffffffff)
    return (b"\x89PNG\r\n\x1a\n"
            +chunk(b"IHDR",struct.pack(">IIBBBBB",width,height,8,2,0,0,0))
            +chunk(b"IDAT",zlib.compress(rows))+chunk(b"IEND",b""))

class CaptureTests(unittest.TestCase):
    def test_black_is_monochrome(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=pathlib.Path(tmp)/"black.png"
            path.write_bytes(png(b"\x00\x00\x00"))
            self.assertEqual(len(pixels(path)),1)
    def test_invalid_png_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=pathlib.Path(tmp)/"bad.png"
            path.write_bytes(b"bad")
            with self.assertRaises(ValueError):
                pixels(path)

if __name__ == "__main__":
    unittest.main()
