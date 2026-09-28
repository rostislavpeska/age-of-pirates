"""Host: attach measured AO samples to conjoin faces in their own development coordinates.

faces: blender-uv-conjoin faces (id, chart, material, uv = development texels, same
       corner order as the Blender polygon). ao_json: output of ao_sample.py.
After attach(), use
    conjoin.families(faces, ..., compat=lambda m, o, M: ao_compat.compatible(m, o, M, 'points'))
"""
import json
import numpy as np


def attach(faces, ao_json):
    ao = json.load(open(ao_json)) if isinstance(ao_json, str) else ao_json
    by_id = {f['id']: f for f in faces}
    n = 0
    for rec in ao['faces']:
        f = by_id.get(rec['face'])
        if f is None:
            continue
        uv = np.asarray(f['uv'], float)
        f['ao'] = [[float(sum(uv[c][0] * wi for c, wi in zip(corner, w))),
                    float(sum(uv[c][1] * wi for c, wi in zip(corner, w))), a]
                   for corner, w, cell, a in rec['samples']]
        n += 1
    return n
