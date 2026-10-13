"""Preserve frozen channels and scope when applying native material deltas."""
import numpy as np
import pytest
from composite_delta import apply_delta


def test_delta_clips_without_wrap_and_preserves_non_target_and_alpha():
    source = np.full((2, 2, 4), 100, dtype=np.uint8)
    before = np.array([[[250, 10, 100]] * 2] * 2, dtype=np.uint8)
    after = np.array([[[0, 250, 120]] * 2] * 2, dtype=np.uint8)
    scope = np.array([[True, False], [False, True]])
    result = apply_delta(source, before, after, scope, [0, 1, 2])
    assert result[0, 0].tolist() == [0, 255, 120, 100]
    assert np.array_equal(result[~scope], source[~scope])
    assert np.array_equal(result[:, :, 3], source[:, :, 3])


def test_scalar_roughness_maps_to_only_requested_channel():
    source = np.full((2, 2, 4), 100, dtype=np.uint8)
    scalar = np.full((2, 2), 30, dtype=np.uint8)
    result = apply_delta(source, scalar, scalar + 10, np.ones((2, 2), dtype=bool), [1])
    assert np.all(result[:, :, 1] == 110)
    assert np.array_equal(result[:, :, [0, 2, 3]], source[:, :, [0, 2, 3]])


def test_rejects_mismatched_dimensions_and_ambiguous_channel_mapping():
    source = np.zeros((2, 2, 4), dtype=np.uint8)
    with pytest.raises(ValueError):
        apply_delta(source, source, source[:1], np.ones((2, 2), bool), [0])
    with pytest.raises(ValueError):
        apply_delta(source, source, source, np.ones((2, 2), bool), [1, 1])
