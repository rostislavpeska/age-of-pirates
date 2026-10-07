"""Source-derived triangle UV/material correspondence, independent of the GR2 writer.

INC-133: density and serializer readback both passed a vertically inverted atlas.
The manifest must be built from frozen author geometry, never a candidate GR2.
"""
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import numpy as np


def digest(array, dtype):
    return hashlib.sha256(np.asarray(array, dtype=dtype).tobytes()).hexdigest()


def signature(positions, uv):
    return dict(corners=len(uv), position_f32_sha256=digest(positions, '<f4'),
                raw_uv_f16_sha256=digest(uv, '<f2'))


def from_author(payload):
    """Input positions already use the engine frame, UVs still use Blender's origin.

    Aggregate triangles by runtime material, preserving source order; repeated
    mesh chunks with that material are equivalent. Explicit reflection here is
    intentionally independent of the writer's conversion helper.
    """
    result={}
    for stage in ('intact','damaged'):
        groups=defaultdict(lambda: [[],[]])
        for part in payload[stage]:
            material=payload['materials'][part['material']]['runtime_name'].lower()
            positions,uv=groups[material]
            for face in part['faces']:
                for i in face:
                    vertex=part['vertices'][i];positions.append(vertex['p'])
                    u,v=vertex['uv'];uv.append((u,1.0-v))
        result[stage]={mat:signature(*values) for mat,values in groups.items()}
    return result


def from_runtime(info):
    groups=defaultdict(lambda: [[],[]])
    for mesh in info['render']:
        if len(mesh['mats'])!=1:
            raise ValueError('UV contract requires one explicit material per mesh')
        p,u=groups[mesh['mats'][0].lower()]
        p.extend(mesh['pos'][mesh['tris']].reshape(-1,3))
        u.extend(mesh['uv'][mesh['tris']].reshape(-1,2))
    return {mat:signature(*values) for mat,values in groups.items()}


def check(stage,info,config,repo_root):
    """Fail closed when a configured source contract is missing or changed."""
    try:
        path=Path(config['path'])
        if not path.is_absolute():path=Path(repo_root)/path
        data=path.read_bytes()
        if hashlib.sha256(data).hexdigest()!=config['sha256']:
            raise ValueError('source UV contract hash mismatch')
        manifest=json.loads(data)
        if manifest['convention']!='raw_gr2=(author_u,1-author_v)':
            raise ValueError('unsupported UV convention')
        expected=manifest['expected'][stage];actual=from_runtime(info)
        if expected!=actual:
            wrong=[mat for mat in sorted(set(expected)|set(actual)) if expected.get(mat)!=actual.get(mat)]
            raise ValueError('source geometry/material/UV mismatch: '+', '.join(wrong))
        return True,f"{sum(v['corners'] for v in actual.values())} corners match frozen source UVs and materials"
    except (KeyError,ValueError,OSError,TypeError) as exc:
        return False,str(exc)
