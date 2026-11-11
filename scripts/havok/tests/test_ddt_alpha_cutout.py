"""Cutout compression must retain silhouette texels, including at mip scale."""
import sys
from pathlib import Path
import numpy as np
import pytest
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ddt_dxt1 import encode_alpha, encode_dxt1, write_ddt
from ddt_patch import header, decode_mip0, patch


def decode_alpha(alpha):
    import struct
    h, w = alpha.shape
    raw = encode_alpha(alpha, cutout_threshold=128)
    colour = np.frombuffer(encode_dxt1(np.full((h, w, 3), 170, np.uint8)), np.uint8).reshape(-1, 8)
    payload = np.concatenate((raw, colour), axis=1).tobytes()
    ddt = b'RTS3' + bytes([0, 4, 9, 1]) + struct.pack('<4I', w, h, 24, len(payload)) + payload
    return decode_mip0(ddt, header(ddt))[:, :, 3]


def test_cutoff_preserved_for_all_alpha_values_and_mixed_blocks():
    rng = np.random.default_rng(40)
    alpha = rng.integers(0, 256, (128, 128), dtype=np.uint8)
    alpha[:16, :16] = np.arange(256, dtype=np.uint8).reshape(16, 16)
    # Include the narrow ranges which straddle the cutoff after interpolation.
    alpha[16:20, :4] = np.array([0, 130, 255, 122] * 4).reshape(4, 4)
    decoded = decode_alpha(alpha)
    assert np.array_equal(decoded >= 128, alpha >= 128)


def test_patch_cutout_mips_and_noop(tmp_path):
    rng = np.random.default_rng(12)
    original = rng.integers(0, 256, (32, 32, 4), dtype=np.uint8)
    src, out = tmp_path/'in.ddt', tmp_path/'out.ddt'
    write_ddt(Image.fromarray(original), src, dxt5=True)
    b = src.read_bytes(); H = header(b)
    base = decode_mip0(b, H).copy()
    base[:, :, 3] = rng.integers(0, 256, (32, 32), dtype=np.uint8)
    new, mask = tmp_path/'new.png', tmp_path/'mask.png'
    Image.fromarray(base).save(new)
    Image.fromarray(np.full((32, 32), 255, np.uint8)).save(mask)
    patch(src, new, mask, out, cutout_threshold=128)
    result = out.read_bytes()
    assert header(result) == H
    for i, (offset, size) in enumerate(H['mips']):
        w = max(32 >> i, 4)
        one = dict(H, w=w, h=w, mips=[(offset, size)])
        decoded = decode_mip0(result, one)[:, :, 3]
        target = np.asarray(Image.fromarray(base[:, :, 3]).resize((w, w), Image.Resampling.LANCZOS))
        assert np.array_equal(decoded >= 128, target >= 128)
    Image.fromarray(np.zeros((32, 32), np.uint8)).save(mask)
    patch(src, new, mask, out, cutout_threshold=128)
    assert out.read_bytes() == b


@pytest.mark.parametrize('threshold', [0, 256, 127.5])
def test_invalid_threshold_is_rejected(threshold):
    with pytest.raises(ValueError):
        encode_alpha(np.zeros((4, 4), np.uint8), cutout_threshold=threshold)
