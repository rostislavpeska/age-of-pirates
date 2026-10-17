"""
Backdrop Seam Continuity and Spatial Ordering Regression Test

Validates that:
1. Spatial Slot Ordering: The cylinder mesh material slots (0..3) monotonically advance
   from Screen-Left to Screen-Right, matching textures [matA, matB, matC, matD].
   Prevents regression where matD was assigned to Slot 0, placing the right edge
   of the panorama adjacent to the left edge (matA) and creating a visible seam discontinuity.
2. Mesh Seam Coincidence: Adjacent panels along the cylinder curve share coincident
   boundary vertices in 3D space (0-1, 1-2, 2-3), confirming a continuous arc.
3. UV Seam Alignment: The U coordinates at coincident boundary vertices meet seamlessly
   (U_right_boundary ≈ 1.0 meets U_left_boundary ≈ 0.0).
4. Texture Pixel Continuity: Sliced texture panels have sub-pixel continuous RGB values
   across internal seams (A right edge meets B left edge, B meets C, C meets D).
5. Game DDT Asset Freshness: All 4 DXT1 .ddt textures exist in the game mod with correct
   engine byte size (2,796,328 bytes for 2048x2048 DXT1 with mipmaps).

Checks 1-3 query a live Blender, opt-in only (INC-392): AOP_REVIEW_BLENDER_PORT names the port of a disposable
review Blender (scripts/tools/local_env.py). Unset, not a port or 9876 (the owner's live Blender): they skip before
any socket exists.
"""

import os
import sys
import json
import socket
import threading
import pytest
import cv2
import numpy as np

KOREAN_MOD_TEXTURE_DIR = os.path.abspath(
    os.path.join(
        os.path.dirname(__file__),
        '..', '..', '..', '..', 'age-of-pirates-koreans',
        'art', 'homecity', 'korean', 'korean_background', 'textures'
    )
)

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import local_env  # noqa: E402

# the backdrop working folder: AOP_HC_BACKDROP_SCRATCH of this device's local environment (scripts/tools/local_env.py:
# the environment, else config/aop.local.env); None = not on this device, the pixel test skips
SCRATCH = local_env.value('AOP_HC_BACKDROP_SCRATCH')
SCRATCH_DIR = os.path.abspath(SCRATCH) if SCRATCH else None


def review_blender_port():
    """the opt-in review Blender port; skips the calling test, before any socket exists, when there is none"""
    port, why = local_env.review_blender_port()
    if port is None:
        pytest.skip(f"live-Blender test, opt-in only: {why}. Set it to the port of a disposable review Blender "
                    "(blender-mcp-safety open_review.py --port 9877); the owner's Blender on 9876 is never queried")
    return port


def query_blender(code_str, timeout=10.0):
    port = review_blender_port()
    s = socket.socket()
    s.settimeout(timeout)
    try:
        s.connect(('127.0.0.1', port))
    except Exception as e:
        s.close()
        pytest.skip(f"review Blender not reachable on AOP_REVIEW_BLENDER_PORT={port}: {e}")
    req = json.dumps({'type': 'execute', 'code': code_str, 'strict_json': False}) + '\0'
    s.sendall(req.encode('utf-8'))
    buf = bytearray()
    while True:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf.extend(chunk)
        if b'\0' in buf:
            break
    s.close()
    resp = json.loads(buf.partition(b'\0')[0].decode('utf-8'))
    assert resp.get('status') == 'ok', f"Blender query failed: {resp}"
    return resp.get('result', {})


def test_game_mod_ddt_assets():
    """Verify all 4 DXT1 .ddt files exist in the Korean mod directory with correct size."""
    expected_panels = ['korean_bg_matA_basecolor', 'korean_bg_matB_basecolor',
                       'korean_bg_matC_basecolor', 'korean_bg_matD_basecolor']
    expected_size = 2796328  # 2048x2048 DXT1 with mips

    assert os.path.exists(KOREAN_MOD_TEXTURE_DIR), f"Mod textures dir missing: {KOREAN_MOD_TEXTURE_DIR}"

    for panel in expected_panels:
        ddt_path = os.path.join(KOREAN_MOD_TEXTURE_DIR, f"{panel}.ddt")
        assert os.path.isfile(ddt_path), f"Missing DDT file: {ddt_path}"
        actual_size = os.path.getsize(ddt_path)
        assert actual_size == expected_size, (
            f"DDT {panel} has invalid size {actual_size} (expected {expected_size})"
        )


def test_texture_seam_pixel_continuity():
    """Verify that adjacent sliced panels have continuous colors across their seams."""
    if not SCRATCH_DIR:
        pytest.skip("AOP_HC_BACKDROP_SCRATCH not set on this device (config/aop.local.env; "
                    "python scripts/tools/local_env.py)")
    slices_dir = os.path.join(SCRATCH_DIR, 'slices_soft_80')
    if not os.path.exists(slices_dir):
        pytest.skip(f"Slices dir {slices_dir} not found")

    panels = [
        cv2.imread(os.path.join(slices_dir, 'korean_bg_matA_basecolor.png')),
        cv2.imread(os.path.join(slices_dir, 'korean_bg_matB_basecolor.png')),
        cv2.imread(os.path.join(slices_dir, 'korean_bg_matC_basecolor.png')),
        cv2.imread(os.path.join(slices_dir, 'korean_bg_matD_basecolor.png')),
    ]

    for idx, p in enumerate(panels):
        assert p is not None, f"Panel {idx} failed to load from {slices_dir}"

    # Check internal seams: (A right edge meets B left edge), (B meets C), (C meets D)
    for i in range(3):
        left_edge = panels[i][:, -1, :].astype(np.float32)   # Last column of panel i
        right_edge = panels[i+1][:, 0, :].astype(np.float32)  # First column of panel i+1

        mean_diff = np.mean(np.abs(left_edge - right_edge))
        max_diff = np.max(np.abs(left_edge - right_edge))

        assert mean_diff < 5.0, (
            f"Seam {i}-{i+1} discontinuous! Mean pixel delta: {mean_diff:.2f} (max {max_diff:.1f})"
        )

    # Negative test: D right edge meets A left edge MUST be discontinuous
    d_right = panels[3][:, -1, :].astype(np.float32)
    a_left = panels[0][:, 0, :].astype(np.float32)
    wrap_diff = np.mean(np.abs(d_right - a_left))
    assert wrap_diff > 15.0, (
        f"Expected wrap seam D-A to be discontinuous (not 360 wrap), got delta {wrap_diff:.2f}"
    )


def test_blender_backdrop_spatial_slot_ordering():
    """Verify material slots in Blender are strictly ordered Left-to-Right matching matA..matD."""
    blender_code = """
import bpy, bpy_extras, os
from mathutils import Vector

cam = bpy.context.scene.camera
obj = bpy.data.objects.get('Korean_Backdrop_Cylinder')
mesh = obj.data

slot_screen_x = []
slot_textures = []

for idx, mat in enumerate(obj.data.materials):
    verts = [mesh.vertices[v].co for p in mesh.polygons if p.material_index == idx for v in p.vertices]
    world_verts = [obj.matrix_world @ v for v in verts]
    screen_pts = [bpy_extras.object_utils.world_to_camera_view(bpy.context.scene, cam, w) for w in world_verts]
    xs = [pt.x for pt in screen_pts]
    mean_x = sum(xs)/len(xs) if xs else 0.0
    slot_screen_x.append(mean_x)
    
    tex_path = ""
    if mat.node_tree:
        for n in mat.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image:
                tex_path = n.image.filepath
    slot_textures.append(os.path.basename(tex_path).lower())

result = {
    'slot_screen_x': slot_screen_x,
    'slot_textures': slot_textures
}
"""
    res = query_blender(blender_code)
    slot_x = res['slot_screen_x']
    textures = res['slot_textures']

    # 1. Monotonically advancing Screen-X (left to right)
    assert len(slot_x) == 4, f"Expected 4 material slots, got {len(slot_x)}"
    for i in range(3):
        assert slot_x[i] < slot_x[i+1], (
            f"Slots not ordered Left-to-Right! Slot {i} X={slot_x[i]:.3f} >= Slot {i+1} X={slot_x[i+1]:.3f}"
        )

    # 2. Correct texture mapping: Slot 0=matA, Slot 1=matB, Slot 2=matC, Slot 3=matD
    expected_suffixes = ['mata', 'matb', 'matc', 'matd']
    for idx, expected in enumerate(expected_suffixes):
        assert expected in textures[idx], (
            f"Slot {idx} has wrong texture '{textures[idx]}' (expected containing '{expected}')"
        )


def test_blender_mesh_seam_coincidence_and_uvs():
    """Verify adjacent panels share coincident 3D boundary vertices and have matching boundary UVs."""
    blender_code = """
import bpy

obj = bpy.data.objects.get('Korean_Backdrop_Cylinder')
mesh = obj.data
uv_layer = mesh.uv_layers.active.data

seam_checks = []
for m0, m1 in [(0, 1), (1, 2), (2, 3)]:
    polys0 = [p for p in mesh.polygons if p.material_index == m0]
    polys1 = [p for p in mesh.polygons if p.material_index == m1]
    
    uvs0 = []
    uvs1 = []
    for p in polys0:
        for loop_idx, v_idx in zip(p.loop_indices, p.vertices):
            uvs0.append((mesh.vertices[v_idx].co, uv_layer[loop_idx].uv))
    for p in polys1:
        for loop_idx, v_idx in zip(p.loop_indices, p.vertices):
            uvs1.append((mesh.vertices[v_idx].co, uv_layer[loop_idx].uv))
            
    coincident_count = 0
    uv_pairs = []
    for co0, uv0 in uvs0:
        for co1, uv1 in uvs1:
            if (co0 - co1).length < 0.05:
                coincident_count += 1
                uv_pairs.append({'u0': round(uv0.x, 4), 'u1': round(uv1.x, 4)})
                break
                
    seam_checks.append({
        'pair': f'{m0}-{m1}',
        'coincident': coincident_count,
        'uv_pairs': uv_pairs
    })

result = {'seam_checks': seam_checks}
"""
    res = query_blender(blender_code)
    seam_checks = res['seam_checks']

    for check in seam_checks:
        pair = check['pair']
        coincident = check['coincident']
        # Each seam in the cylinder mesh has 3 coincident vertices along its vertical height
        assert coincident >= 3, f"Seam {pair} has insufficient coincident boundary vertices ({coincident})"

        # Check that left slot U is ~1.0 and right slot U is ~0.0
        for uv in check['uv_pairs']:
            assert uv['u0'] > 0.95, f"Seam {pair} left boundary U not near 1.0: {uv['u0']}"
            assert uv['u1'] < 0.05, f"Seam {pair} right boundary U not near 0.0: {uv['u1']}"


# INC-392: without the opt-in the two live-Blender tests skip and no socket is ever created
BLENDER_TESTS = (test_blender_backdrop_spatial_slot_ordering, test_blender_mesh_seam_coincidence_and_uvs)


def _no_socket(*_a, **_k):
    raise AssertionError('a live-Blender test opened a socket without the AOP_REVIEW_BLENDER_PORT opt-in')


@pytest.mark.parametrize('setting, why', [
    (None, 'is not set'), ('9876', "the owner's live Blender port"), ('blender', 'not a port')])
def test_blender_tests_skip_without_a_socket(monkeypatch, setting, why):
    monkeypatch.setattr(local_env, 'read_env_file', lambda _path: {})       # this device's config/aop.local.env
    if setting is None:
        monkeypatch.delenv('AOP_REVIEW_BLENDER_PORT', raising=False)
    else:
        monkeypatch.setenv('AOP_REVIEW_BLENDER_PORT', setting)
    monkeypatch.setattr(socket, 'socket', _no_socket)
    monkeypatch.setattr(socket, 'create_connection', _no_socket)
    for test in BLENDER_TESTS:
        with pytest.raises(pytest.skip.Exception, match=why):
            test()


def test_opt_in_queries_the_configured_review_port(monkeypatch):
    """a fake bridge on an OS-assigned port (never 9876) receives the request and answers it"""
    srv = socket.socket()
    srv.bind(('127.0.0.1', 0))
    srv.listen(1)
    srv.settimeout(10)
    port = srv.getsockname()[1]
    assert port != local_env.OWNER_BLENDER_PORT
    got = {}

    def serve():
        conn, _ = srv.accept()
        with conn:
            buf = bytearray()
            while b'\0' not in buf:
                chunk = conn.recv(65536)
                if not chunk:
                    break
                buf.extend(chunk)
            got['request'] = json.loads(buf.partition(b'\0')[0].decode('utf-8'))
            conn.sendall(json.dumps({'status': 'ok', 'result': {'answer': 42}}).encode('utf-8') + b'\0')

    monkeypatch.setattr(local_env, 'read_env_file', lambda _path: {})
    monkeypatch.setenv('AOP_REVIEW_BLENDER_PORT', str(port))
    t = threading.Thread(target=serve, daemon=True)
    t.start()
    try:
        assert query_blender('result = 1') == {'answer': 42}
    finally:
        t.join(10)
        srv.close()
    assert got['request'] == {'type': 'execute', 'code': 'result = 1', 'strict_json': False}


def test_korean_homecity_camera_contract():
    """Regression gate: Ensure Korea Home City strictly uses the WoL Aztec cathedral camera angle."""
    import xml.etree.ElementTree as ET

    korean_xml_path = os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            '..', '..', '..', '..', 'age-of-pirates-koreans',
            'data', 'homecityzpkoreans.xml'
        )
    )
    assert os.path.isfile(korean_xml_path), f"Missing Korean home city XML: {korean_xml_path}"

    tree = ET.parse(korean_xml_path)
    root = tree.getroot()

    camera = root.findtext('camera', '').strip()
    widescreencamera = root.findtext('widescreencamera', '').strip()

    expected_cam = r'aztec\aztec_homecity_cathedral_camera.cam'
    expected_cam_norm = expected_cam.replace('/', '\\').lower()

    assert camera.replace('/', '\\').lower() == expected_cam_norm, (
        f"HEAVY REGRESSION: Korean <camera> is '{camera}', must be '{expected_cam}' (WoL camera angle)!"
    )
    assert widescreencamera.replace('/', '\\').lower() == expected_cam_norm, (
        f"HEAVY REGRESSION: Korean <widescreencamera> is '{widescreencamera}', must be '{expected_cam}' (WoL camera angle)!"
    )

