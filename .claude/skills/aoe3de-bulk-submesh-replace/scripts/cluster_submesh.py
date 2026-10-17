"""
Submesh Clustering and Centroid Isolation for AoE3DE Composite Models.

Identifies repeated prop submeshes (such as lanterns, crates, barrels)
baked into composite meshes (e.g., stall_lanterns_GEOShape, bridgesandstuff).
"""
import numpy as np

def find_submesh_components(mesh, material_index=None, min_face_count=10):
    """
    Finds connected face components in a Blender mesh, optionally filtered by material index.
    Returns a list of dicts with component metadata:
      - 'face_indices': list of polygon indices
      - 'vertex_indices': set of vertex indices
      - 'centroid': (3,) np.ndarray
      - 'bbox_min': (3,) np.ndarray
      - 'bbox_max': (3,) np.ndarray
      - 'top_anchor': (3,) np.ndarray (highest vertex / top loop)
      - 'bottom_anchor': (3,) np.ndarray (lowest vertex / base)
    """
    # Filter polygons
    if material_index is not None:
        polys = [p for p in mesh.polygons if p.material_index == material_index]
    else:
        polys = list(mesh.polygons)

    if not polys:
        return []

    # Map vertex to polygon indices
    v_to_p = {}
    for pi, p in enumerate(polys):
        for v in p.vertices:
            v_to_p.setdefault(v, []).append(pi)

    # Union-find disjoint set
    parent = list(range(len(polys)))

    def find(i):
        path = []
        while parent[i] != i:
            path.append(i)
            i = parent[i]
        for p in path:
            parent[p] = i
        return i

    def union(i, j):
        ri, rj = find(i), find(j)
        if ri != rj:
            parent[ri] = rj

    for v, plist in v_to_p.items():
        for pi in plist[1:]:
            union(plist[0], pi)

    # Group components
    comps = {}
    for pi in range(len(polys)):
        comps.setdefault(find(pi), []).append(pi)

    results = []
    for root_pi, plist in comps.items():
        if len(plist) < min_face_count:
            continue

        v_indices = set(v for pi in plist for v in polys[pi].vertices)
        pts = np.array([mesh.vertices[v].co for v in v_indices], dtype=np.float64)

        c = np.mean(pts, axis=0)
        pmin = pts.min(axis=0)
        pmax = pts.max(axis=0)

        # Top anchor: mean of vertices within 0.01m of maximum Z
        top_pts = pts[pts[:, 2] >= pmax[2] - 0.01]
        top_anchor = np.mean(top_pts, axis=0) if len(top_pts) > 0 else pmax

        # Bottom anchor: mean of vertices within 0.01m of minimum Z
        bot_pts = pts[pts[:, 2] <= pmin[2] + 0.01]
        bot_anchor = np.mean(bot_pts, axis=0) if len(bot_pts) > 0 else pmin

        results.append({
            'face_indices': [polys[pi].index for pi in plist],
            'vertex_indices': v_indices,
            'centroid': c,
            'bbox_min': pmin,
            'bbox_max': pmax,
            'top_anchor': top_anchor,
            'bottom_anchor': bot_anchor,
            'face_count': len(plist)
        })

    return results


def deduplicate_multi_part_clusters(components, proximity_threshold=0.15):
    """
    Groups multi-part submesh clusters (e.g. body + hanging ring) that belong to
    the same logical object into unified entities.
    """
    clusters = []
    for comp in sorted(components, key=lambda c: (c['centroid'][0], c['centroid'][1])):
        matched = False
        for cl in clusters:
            dist = np.linalg.norm(comp['centroid'][:2] - cl['centroid'][:2])
            if dist < proximity_threshold:
                cl['face_indices'].extend(comp['face_indices'])
                cl['vertex_indices'].update(comp['vertex_indices'])
                cl['bbox_min'] = np.minimum(cl['bbox_min'], comp['bbox_min'])
                cl['bbox_max'] = np.maximum(cl['bbox_max'], comp['bbox_max'])
                cl['centroid'] = (cl['bbox_min'] + cl['bbox_max']) / 2.0
                if comp['top_anchor'][2] > cl['top_anchor'][2]:
                    cl['top_anchor'] = comp['top_anchor']
                if comp['bottom_anchor'][2] < cl['bottom_anchor'][2]:
                    cl['bottom_anchor'] = comp['bottom_anchor']
                cl['face_count'] += comp['face_count']
                matched = True
                break
        if not matched:
            clusters.append(dict(comp))

    return clusters
