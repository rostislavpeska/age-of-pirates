"""Blender author UV -> AoE3DE raw GR2 UV boundary.

The authoring UV origin is bottom left; raw GR2 addresses the DDT from the top.
Do this once, before computing exported tangents. Do not vertically flip DDT
images as an additional compensation. The Korean TC converter/readback and
13,573 matching TC triangles established this convention (INC-133).
"""
import numpy as np


def blender_to_gr2_uv(uv):
    result = np.asarray(uv, dtype=np.float64).copy()
    if result.ndim != 2 or result.shape[1] != 2 or not np.isfinite(result).all():
        raise ValueError('UV coordinates must be finite N x 2 Blender coordinates')
    result[:, 1] = 1.0 - result[:, 1]
    return result
