"""Object flag DDT in the vanilla flag profile (measured on Art/objects/flags/japan.ddt and the mod's
zpparlamentarian.ddt: RTS3, usage 0, alpha 0, DXT1, 9 mips 512..2, 174,856 bytes).

    python scripts/tools/flag_ddt.py OBJECT_FLAG_512.png art/objects/flags/NAME.ddt
(the 512x512 PNG comes from flagmaker_render.py with the "Object Flag" template)"""
import os, struct, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'havok'))
from ddt_dxt1 import encode_dxt1
src, out = sys.argv[1:3]
img = Image.open(src).convert('RGB')
assert img.size == (512, 512), img.size
mips = []; cur = img
while cur.size[0] >= 2:
    mips.append(encode_dxt1(np.asarray(cur, dtype=np.uint8)))
    cur = cur.resize((cur.size[0] // 2, cur.size[1] // 2), Image.LANCZOS)
head = b'RTS3' + bytes([0, 0, 4, len(mips)]) + struct.pack('<II', 512, 512)
off = 16 + 8 * len(mips); table = b''
for m in mips: table += struct.pack('<II', off, len(m)); off += len(m)
open(out, 'wb').write(head + table + b''.join(mips))
print(out, 'mips', len(mips), 'bytes', off)
