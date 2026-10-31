"""Write AoE3DE .ddt textures (RTS3 container, DXT5/BC3 payload with a full mip chain) for a
plain colour, plus the matching .material file. Layout verified against
art/buildings/sheriff/textures/sheriff_mata_BaseColor.ddt (header 16 B: 'RTS3', usage, alpha,
format 9 = DXT5, mip count, w, h; then (offset, size) per mip; then the blocks).

    python ddt_write.py OUTDIR NAME            # writes NAME_BaseColor/_Normals/_Masks.ddt + NAME.material
"""
import os, struct, sys


def rgb565(r, g, b):
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def dxt5_solid(w, h, rgba):
    """every 4x4 block: constant alpha (a0=a1=a, indices 0) + constant colour (c0=c1, indices 0)"""
    r, g, b, a = rgba
    block = struct.pack('<BB', a, a) + b'\0' * 6 + struct.pack('<HH', rgb565(r, g, b), rgb565(r, g, b)) + b'\0' * 4
    return block * (max(w // 4, 1) * max(h // 4, 1))


def write_ddt(path, rgba, size=256, usage=0, alpha=4):
    mips = []
    w = h = size
    while True:
        mips.append(dxt5_solid(w, h, rgba))
        if w == 1 and h == 1: break
        w, h = max(w // 2, 1), max(h // 2, 1)
    head = b'RTS3' + bytes([usage, alpha, 9, len(mips)]) + struct.pack('<II', size, size)
    off = 16 + 8 * len(mips); table = b''
    for m in mips:
        table += struct.pack('<II', off, len(m)); off += len(m)
    open(path, 'wb').write(head + table + b''.join(mips))
    return path


MATERIAL = """<material>
   <submaterial name="mata">
    <materialdef name="default">
    </materialdef>
    <parameters>
      <texture name="BaseColor" override="{p}_BaseColor">
      </texture>
      <texture name="Normals" override="{p}_Normals">
      </texture>
      <texture name="Masks" override="{p}_Masks">
      </texture>
    </parameters>
  </submaterial>
</material>
"""

if __name__ == '__main__':
    outdir, name = sys.argv[1], sys.argv[2]
    tex = os.path.join(outdir, 'textures'); os.makedirs(tex, exist_ok=True)
    # black, shiny metal: dark base; flat normal; masks guess = (metallic 255, roughness 40, ao 255, a 255)
    write_ddt(os.path.join(tex, name + '_BaseColor.ddt'), (18, 18, 20, 255))
    write_ddt(os.path.join(tex, name + '_Normals.ddt'), (128, 128, 255, 255))
    write_ddt(os.path.join(tex, name + '_Masks.ddt'), (255, 40, 255, 255))
    rel = 'buildings\\%s\\textures\\%s' % (os.path.basename(outdir), name)
    for stem in (name, name + '_damaged'):
        open(os.path.join(outdir, stem + '.material'), 'w', newline='\r\n').write(MATERIAL.format(p=rel))
    print('wrote', sorted(os.listdir(tex)), 'and', name + '.material /', name + '_damaged.material')
