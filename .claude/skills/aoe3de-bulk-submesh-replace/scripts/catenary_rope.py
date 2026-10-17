"""
Catenary Rope and Connector Tube Generator for AoE3DE Composite Models.

Constructs continuous, manifold 4-sided rope or wire tubes along 3D waypoints
(such as building eaves, bridge posts, and lamp strings) with authentic
AoE3DE fiber UV coordinates and outward-facing normals.
"""
import numpy as np

def generate_rope_mesh(waypoints, radius=0.018, uv_v_min=0.957, uv_v_max=0.967, u_scale=0.28):
    """
    Generates vertices, quad faces, and loop UVs for a 4-sided rope tube.
    waypoints: list of (x, y, z) tuples or np.ndarray of shape (N, 3).
    radius: cross-section radius (default ~0.018m matches vanilla AoE3DE ropes).
    uv_v_min, uv_v_max: V coordinates on texture atlas sampling the rope fiber stripe.
    u_scale: distance scaling factor for U coordinate.
    """
    pts = np.array(waypoints, dtype=np.float64)
    N = len(pts)
    if N < 2:
        return np.empty((0, 3)), [], []

    # Compute tangents
    tangents = np.zeros_like(pts)
    for i in range(N):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == N - 1:
            t = pts[N - 1] - pts[N - 2]
        else:
            t = pts[i + 1] - pts[i - 1]
        norm = np.linalg.norm(t)
        tangents[i] = t / norm if norm > 1e-6 else np.array([1.0, 0.0, 0.0])

    # Compute coordinate frames (u, v) perpendicular to tangent
    verts = []
    dists = [0.0]
    for i in range(1, N):
        dists.append(dists[-1] + np.linalg.norm(pts[i] - pts[i - 1]))

    up_ref = np.array([0.0, 0.0, 1.0])
    for i in range(N):
        t = tangents[i]
        u = np.cross(t, up_ref)
        u_norm = np.linalg.norm(u)
        if u_norm < 1e-4:
            u = np.cross(t, np.array([0.0, 1.0, 0.0]))
            u_norm = np.linalg.norm(u)
        u = u / u_norm
        v = np.cross(u, t)
        v = v / np.linalg.norm(v)

        # 4 corners of cross section
        c0 = pts[i] + radius * ( u + v) / np.sqrt(2.0)
        c1 = pts[i] + radius * (-u + v) / np.sqrt(2.0)
        c2 = pts[i] + radius * (-u - v) / np.sqrt(2.0)
        c3 = pts[i] + radius * ( u - v) / np.sqrt(2.0)

        verts.extend([c0, c1, c2, c3])

    # Connect into quads with verified outward-facing normals
    faces = []
    uvs = []
    for i in range(N - 1):
        idx_curr = i * 4
        idx_next = (i + 1) * 4
        u_curr = dists[i] * u_scale
        u_next = dists[i + 1] * u_scale

        sides = [
            (0, 1, uv_v_min, uv_v_max),
            (1, 2, uv_v_max, uv_v_max),
            (2, 3, uv_v_max, uv_v_min),
            (3, 0, uv_v_min, uv_v_min),
        ]

        for j1, j2, v_a, v_b in sides:
            v_curr1 = idx_curr + j1
            v_curr2 = idx_curr + j2
            v_next1 = idx_next + j1
            v_next2 = idx_next + j2

            # Quad winding order ensuring outward normal: [v_curr2, v_curr1, v_next1, v_next2]
            quad = [v_curr2, v_curr1, v_next1, v_next2]
            faces.append(quad)
            uvs.append([
                (u_curr, v_b),
                (u_curr, v_a),
                (u_next, v_a),
                (u_next, v_b)
            ])

    return np.array(verts), faces, uvs
