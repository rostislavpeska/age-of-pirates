"""Halve top mip of an RTS3 DDT (format 1, raw RGBA8888 mip chain of one level)."""
import struct
import sys

from PIL import Image


def halve(in_path: str, out_path: str) -> None:
    b = open(in_path, "rb").read()
    if b[:4] != b"RTS3":
        raise SystemExit("not RTS3: %s" % in_path)
    usage, alpha, fmt, nmips = b[4:8]
    if fmt != 1 or nmips != 1:
        raise SystemExit("expected fmt=1 single mip, got fmt=%d mips=%d" % (fmt, nmips))
    w, h = struct.unpack("<II", b[8:16])
    off, ln = struct.unpack("<II", b[16:24])
    if ln != w * h * 4:
        raise SystemExit("unexpected payload %d for %dx%d" % (ln, w, h))
    img = Image.frombytes("RGBA", (w, h), b[off : off + ln])
    nw, nh = max(w // 2, 1), max(h // 2, 1)
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    payload = img.tobytes()
    head = (
        b"RTS3"
        + bytes([usage, alpha, fmt, 1])
        + struct.pack("<II", nw, nh)
        + struct.pack("<II", 24, len(payload))
    )
    open(out_path, "wb").write(head + payload)
    print("wrote %s (%dx%d -> %dx%d, %d bytes)" % (out_path, w, h, nw, nh, len(head) + len(payload)))


if __name__ == "__main__":
    halve(sys.argv[1], sys.argv[2])
