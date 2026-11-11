"""aoe3de-anim-viewer ddt.py: RTS3 header, raw BC mips for S3TC upload, RGBA decode for the PNG fallback.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_ddt.py -q

Synthetic and CI-safe: every .ddt is assembled inside the test (deterministic block bytes); the PNG writes go to
pytest's temp folder. Needs numpy and Pillow; the parity case also needs the companion skill
aoe3-texture-weathering (ddt2png.py) and is skipped without it.
"""
import io
import math
import struct
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_common as C  # noqa: E402
import ddt as D  # noqa: E402

PIL = pytest.importorskip('PIL')
from PIL import Image  # noqa: E402

BLOCK = {4: 8, 5: 8, 8: 16, 9: 16}
TEXEL = {1: 4, 7: 1}


def expected_bytes(fmt, w, h):
    if fmt in BLOCK:
        return math.ceil(w / 4) * math.ceil(h / 4) * BLOCK[fmt]
    return w * h * TEXEL[fmt]


def make_ddt(fmt, w, h, mips, usage=0, alpha=0, seed=1):
    """an RTS3 file: header, face-major image table, deterministic image bytes."""
    faces = 6 if usage & 8 else 1
    rng = np.random.default_rng(seed)
    imgs = []
    for _face in range(faces):
        for level in range(mips):
            lw, lh = max(1, w >> level), max(1, h >> level)
            imgs.append(rng.integers(0, 256, expected_bytes(fmt, lw, lh), dtype=np.uint8).tobytes())
    off = 16 + 8 * len(imgs)
    table = b''
    for im in imgs:
        table += struct.pack('<II', off, len(im))
        off += len(im)
    return b'RTS3' + bytes([usage, alpha, fmt, mips]) + struct.pack('<II', w, h) + table + b''.join(imgs), imgs


def alz4_literal(raw):
    n = len(raw)
    rest = n - 15
    head = bytes([n << 4]) if n < 15 else bytes([0xF0]) + b'\xff' * (rest // 255) + bytes([rest % 255])
    block = head + raw
    return b'alz4' + struct.pack('<III', n, len(block), 1) + block


# ---------------------------------------------------------------- header
def test_header_of_a_bc1_chain_that_stops_at_4x4():
    data, imgs = make_ddt(5, 64, 64, 5, alpha=1)
    h = D.parse_header(data)
    assert (h['format'], h['format_name'], h['bc'], h['mip_count'], h['faces']) == (5, 'dxt1-alpha', 'BC1', 5, 1)
    assert (h['width'], h['height'], h['header_size'], h['alpha_type']) == (64, 64, 56, 'player')
    assert [(i['level'], i['width'], i['height'], i['length']) for i in h['images']] == \
        [(0, 64, 64, 2048), (1, 32, 32, 512), (2, 16, 16, 128), (3, 8, 8, 32), (4, 4, 4, 8)]
    assert h['images'][0]['offset'] == 56 and h['problems'] == []


def test_format_codes_map_to_block_compression():
    for fmt, bc in ((4, 'BC1'), (5, 'BC1'), (8, 'BC2'), (9, 'BC3'), (1, None), (7, None)):
        data, _ = make_ddt(fmt, 16, 8, 2)
        assert D.parse_header(data)['bc'] == bc, fmt


def test_usage_bits_and_a_cube_table():
    data, imgs = make_ddt(4, 8, 8, 2, usage=8 | 4 | 2)
    h = D.parse_header(data)
    assert h['faces'] == 6 and h['usage_flags'] == ['low-detail', 'bump', 'cube']
    assert [(i['face'], i['level']) for i in h['images']][:3] == [(0, 0), (0, 1), (1, 0)]
    assert len(h['images']) == 12 and h['header_size'] == 16 + 8 * 12
    assert D.images(data, face=5)[1]['data'] == imgs[11]


def test_an_alz4_wrapped_ddt_reads_the_same():
    data, _ = make_ddt(9, 16, 16, 3)
    assert D.parse_header(alz4_literal(data)) == D.parse_header(data)


def test_broken_files_raise_ddt_error():
    with pytest.raises(D.DdtError):
        D.parse_header(b'DDS ' + bytes(60))
    data, _ = make_ddt(4, 16, 16, 3)
    with pytest.raises(D.DdtError):
        D.parse_header(data[:20])


# ---------------------------------------------------------------- bundle record
def test_texture_record_puts_every_mip_into_the_buffer_unchanged():
    data, imgs = make_ddt(9, 32, 16, 4, alpha=4)
    w = C.BufferWriter('tex')
    rec = D.texture_record('units/x/t_basecolor.ddt', data, w, provenance=2)
    assert rec['decodable'] and rec['unavailable_reason'] is None and rec['provenance'] == 2
    assert (rec['ddt_format'], rec['bc'], rec['width'], rec['height'], rec['mip_count']) == (9, 'BC3', 32, 16, 4)
    assert rec['max_level'] == 3 and rec['complete_to_1x1'] is False and rec['fallback'] is None
    buf = w.data()
    for mip, raw in zip(rec['mips'], imgs):
        v = mip['view']
        assert v['dtype'] == 'u8' and v['components'] == 1 and v['byteOffset'] % 16 == 0
        assert v['byteLength'] == expected_bytes(9, mip['width'], mip['height']) == len(raw)
        assert C.read_view(buf, v).tobytes() == raw
    assert [(m['level'], m['width'], m['height']) for m in rec['mips']] == [(0, 32, 16), (1, 16, 8), (2, 8, 4),
                                                                            (3, 4, 2)]
    C.json_text(rec)


def test_a_cube_texture_record_names_each_face():
    data, imgs = make_ddt(4, 8, 8, 1, usage=8)
    rec = D.texture_record('effects/sky/s.ddt', data, C.BufferWriter('tex'))
    assert rec['decodable'] and rec['faces'] == 6 and [m['face'] for m in rec['mips']] == list(range(6))


def test_unsupported_or_broken_textures_keep_their_id_and_say_why():
    w = C.BufferWriter('tex')
    data, _ = make_ddt(1, 8, 8, 1)
    rec = D.texture_record('a.ddt', data, w)
    assert not rec['decodable'] and rec['unavailable_reason'] == 'ddt-format-1' and rec['mips'] == []
    rec = D.texture_record('b.ddt', b'nope' * 10, w)
    assert rec['unavailable_reason'] == 'ddt-header-invalid' and rec['id'] == 'b.ddt'
    data, _ = make_ddt(4, 16, 16, 2)
    bad = bytearray(data)
    struct.pack_into('<I', bad, 20, 7)                 # level 0 claims 7 bytes
    rec = D.texture_record('c.ddt', bytes(bad), w)
    assert rec['unavailable_reason'] == 'ddt-size-mismatch' and rec['problems']
    assert D.texture_record('d.ddt', None, w)['unavailable_reason'] == 'file-missing'
    assert w.data() == b''


# ---------------------------------------------------------------- RGBA decode
def bc1(c0, c1, idx):
    return struct.pack('<HHI', c0, c1, idx)


def one_block(fmt, block):
    return b'RTS3' + bytes([0, 0, fmt, 1]) + struct.pack('<IIII', 4, 4, 24, len(block)) + block


def test_bc1_follows_the_d3d11_rules():
    for fmt in (4, 5):
        assert D.decode_rgba(one_block(fmt, bc1(0xF800, 0x001F, 0)))[0, 0].tolist() == [255, 0, 0, 255]
        assert D.decode_rgba(one_block(fmt, bc1(0xF800, 0x001F, 0xAAAAAAAA)))[0, 0].tolist() == [170, 0, 85, 255]
        three = D.decode_rgba(one_block(fmt, bc1(0x001F, 0xF800, 0xFFFFFFFF)))
        assert three[..., 3].max() == 0 and three[..., :3].max() == 0          # index 3: transparent black


def test_bgra_and_grey_are_converted_directly():
    data, imgs = make_ddt(1, 4, 2, 1)
    a = D.decode_rgba(data)
    raw = np.frombuffer(imgs[0], np.uint8).reshape(2, 4, 4)
    assert a.shape == (2, 4, 4) and (a == raw[..., [2, 1, 0, 3]]).all()
    data, imgs = make_ddt(7, 4, 4, 2)
    g = D.decode_rgba(data, level=1)
    assert g.shape == (2, 2, 4) and (g[..., 0] == np.frombuffer(imgs[1], np.uint8).reshape(2, 2)).all()
    assert (g[..., 3] == 255).all()


def test_any_mip_decodes_at_its_own_size():
    data, _ = make_ddt(8, 32, 32, 4)
    assert [D.decode_rgba(data, level=k).shape for k in range(4)] == [(32, 32, 4), (16, 16, 4), (8, 8, 4),
                                                                      (4, 4, 4)]
    with pytest.raises(D.DdtError):
        D.decode_rgba(data, level=4)


def test_top_mip_decode_matches_ddt2png(tmp_path):
    d2p = D._ddt2png()
    if d2p is None:
        pytest.skip('companion skill aoe3-texture-weathering (ddt2png.py) is absent')
    for fmt in (4, 5, 8, 9, 1):
        data, _ = make_ddt(fmt, 32, 16, 3, seed=fmt)
        p = tmp_path / ('t%d.ddt' % fmt)
        p.write_bytes(data)
        img, info = d2p.read_ddt(str(p))
        assert info['fmt'] == fmt
        assert (np.asarray(img) == D.decode_rgba(data, 0)).all(), fmt


def test_png_writes_go_outside_repositories_only(tmp_path):
    data, _ = make_ddt(9, 16, 8, 2)
    out = D.write_png(data, tmp_path / 'out' / 't.png', level=1)
    img = Image.open(io.BytesIO(out.read_bytes()))
    assert img.size == (8, 4) and img.mode == 'RGBA'
    repo = tmp_path / 'repo'
    (repo / '.git').mkdir(parents=True)
    with pytest.raises(C.RepoPathError):
        D.write_png(data, repo / 'art' / 't.png')
    assert not (repo / 'art').exists()


def test_fallback_png_lands_inside_the_bundle(tmp_path):
    data, _ = make_ddt(4, 8, 8, 1)
    rec = D.texture_record('units/x/Unit_BaseColor.ddt', data, C.BufferWriter('tex'))
    uri = D.write_fallback(rec, data, tmp_path / 'bundle')
    assert uri == 'fallback/Unit_BaseColor.png' == rec['fallback']
    assert (tmp_path / 'bundle' / 'fallback' / 'Unit_BaseColor.png').is_file()


def test_cli_info_and_png(tmp_path, capsys):
    data, _ = make_ddt(5, 8, 8, 2)
    p = tmp_path / 'x.ddt'
    p.write_bytes(data)
    assert D.main(['info', str(p)]) == 0
    assert '"format_name": "dxt1-alpha"' in capsys.readouterr().out
    assert D.main(['png', str(p), '--out', str(tmp_path / 'o'), '--level', '1']) == 0
    assert (tmp_path / 'o' / 'x_l1.png').is_file()
