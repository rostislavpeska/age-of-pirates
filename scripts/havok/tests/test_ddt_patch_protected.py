"""Audit 2026-10-13-codex-castle-delivery-01: packed-channel/alpha regression."""
import sys
from pathlib import Path
import numpy as np
import pytest
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ddt_dxt1 import write_ddt
from ddt_patch import header, decode_level, patch


@pytest.mark.parametrize('dxt5,green', [(True, False), (True, True), (False, True)])
def test_protected_channels_and_untouched_blocks_at_every_mip(tmp_path, dxt5, green):
    rng = np.random.default_rng(42)
    original = rng.integers(0, 256, (64, 64, 4), dtype=np.uint8)
    src, out = tmp_path/'in.ddt', tmp_path/'out.ddt'
    write_ddt(Image.fromarray(original), src, dxt5=dxt5)
    b = src.read_bytes(); H = header(b)
    new = decode_level(b, H, 0).copy()
    new[20:28, 20:28, 1] = 230
    if not green:
        new[20:28, 20:28, 0] = 30
        new[:, :, 3] = 0  # preservation must override even adversarial alpha
    mask = np.zeros((64, 64), np.uint8); mask[20:28, 20:28] = 255
    new_path, mask_path = tmp_path/'new.png', tmp_path/'mask.png'
    Image.fromarray(new).save(new_path); Image.fromarray(mask).save(mask_path)
    patch(src, new_path, mask_path, out, preserve_alpha=not green, green_only_mode=green)
    result = out.read_bytes(); assert header(result) == H
    changed = 0
    for i, (off, size) in enumerate(H['mips']):
        before = decode_level(b, H, i); after = decode_level(result, H, i)
        protected = [0, 2, 3] if green else [3]
        assert np.array_equal(before[:, :, protected], after[:, :, protected])
        bw = max(64 >> i, 4)//4
        touched = np.asarray(Image.fromarray(mask).resize((bw, bw), Image.Resampling.BOX)) > 0
        pad = np.pad(touched, 1)
        touched |= pad[2:, 1:-1] | pad[:-2, 1:-1] | pad[1:-1, 2:] | pad[1:-1, :-2]
        bpb = 16 if dxt5 else 8
        oldblocks = np.frombuffer(b[off:off+size], np.uint8).reshape(-1, bpb)
        newblocks = np.frombuffer(result[off:off+size], np.uint8).reshape(-1, bpb)
        assert np.array_equal(oldblocks[~touched.ravel()], newblocks[~touched.ravel()])
        if dxt5:
            assert np.array_equal(oldblocks[:, :8], newblocks[:, :8])
        changed += np.count_nonzero(before[:, :, 1] != after[:, :, 1])
    assert changed > 0
    Image.fromarray(np.zeros_like(mask)).save(mask_path)
    patch(src, new_path, mask_path, out, preserve_alpha=not green, green_only_mode=green)
    assert out.read_bytes() == b
