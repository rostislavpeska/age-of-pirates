"""Audit 2026-10-13-codex-castle-delivery-01: packed-channel/alpha regression."""
import sys
from pathlib import Path
import numpy as np
import pytest
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ddt_dxt1 import write_ddt
from ddt_patch import header, decode_level, patch


def test_alpha_selectors_preserve_other_texels_and_endpoints(tmp_path):
    # Audit44: neighboring pixels in a changed block must remain exactly decoded.
    original=np.zeros((32,32,4),np.uint8);original[:,:,:3]=[100,150,200]
    original[:,:,3]=np.where(np.indices((32,32))[1]%2,255,0)
    src=tmp_path/'in.ddt';out=tmp_path/'out.ddt'
    write_ddt(Image.fromarray(original),src,dxt5=True)
    raw=src.read_bytes();h=header(raw);new=decode_level(raw,h,0).copy()
    mask=np.zeros((32,32),np.uint8);mask[13,13]=255;new[13,13,3]=0
    npng=tmp_path/'new.png';mpng=tmp_path/'mask.png'
    Image.fromarray(new).save(npng);Image.fromarray(mask).save(mpng)
    patch(src,npng,mpng,out,alpha_only=True,alpha_selectors_mode=True,cutout_threshold=128)
    result=out.read_bytes();got=decode_level(result,h,0);expected=decode_level(raw,h,0).copy();expected[13,13,3]=0
    assert np.array_equal(got,expected)
    for i,(off,size) in enumerate(h['mips']):
        a=np.frombuffer(raw[off:off+size],np.uint8).reshape(-1,16)
        b=np.frombuffer(result[off:off+size],np.uint8).reshape(-1,16)
        assert np.array_equal(a[:,:2],b[:,:2]);assert np.array_equal(a[:,8:],b[:,8:])
    Image.fromarray(np.zeros_like(mask)).save(mpng)
    patch(src,npng,mpng,out,alpha_only=True,alpha_selectors_mode=True)
    assert out.read_bytes()==raw


def test_alpha_selectors_fail_closed_on_unavailable_class():
    from ddt_patch import alpha_selectors
    old=np.array([[240,200,0,0,0,0,0,0]],np.uint8)
    with pytest.raises(ValueError,match='cannot represent'):
        alpha_selectors(old,np.zeros((1,16)),np.ones((1,16),bool),128)


def test_alpha_only_preserves_all_rgb_bytes_and_empty_mask(tmp_path):
    # audit2026-10-14-codex-zen-rollout-40: alpha edit cannot degrade accepted colour.
    rng = np.random.default_rng(9)
    original = rng.integers(0, 256, (32, 32, 4), dtype=np.uint8); original[:,:,3] = 255
    src, out = tmp_path/'in.ddt', tmp_path/'out.ddt'
    write_ddt(Image.fromarray(original), src, dxt5=True)
    before = src.read_bytes(); h = header(before); new = decode_level(before,h,0).copy()
    new[:,:,0:3] = 0; new[8:16,8:16,3] = 0
    mask = np.zeros((32,32),np.uint8); mask[8:16,8:16] = 255
    npng, mpng = tmp_path/'new.png', tmp_path/'mask.png'
    Image.fromarray(new).save(npng); Image.fromarray(mask).save(mpng)
    patch(src,npng,mpng,out,alpha_only=True,cutout_threshold=128)
    after = out.read_bytes(); assert header(after) == h
    for i,(offset,size) in enumerate(h['mips']):
        a=np.frombuffer(before[offset:offset+size],np.uint8).reshape(-1,16)
        b=np.frombuffer(after[offset:offset+size],np.uint8).reshape(-1,16)
        assert np.array_equal(a[:,8:],b[:,8:])
        assert np.array_equal(decode_level(before,h,i)[:,:,:3],decode_level(after,h,i)[:,:,:3])
    assert (decode_level(after,h,0)[8:16,8:16,3] < 128).all()
    Image.fromarray(np.zeros_like(mask)).save(mpng); patch(src,npng,mpng,out,alpha_only=True)
    assert out.read_bytes() == before
    for kwargs in ({'preserve_alpha':True},{'green_only_mode':True}):
        with pytest.raises(ValueError): patch(src,npng,mpng,out,alpha_only=True,**kwargs)


def test_alpha_only_rejects_dxt1(tmp_path):
    src=tmp_path/'in.ddt'; write_ddt(Image.new('RGB',(8,8)),src,dxt5=False)
    with pytest.raises(ValueError): patch(src,'unused','unused',tmp_path/'out.ddt',alpha_only=True)


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
