"""INC-187 (2026-10-09): orphan pointer fixups make the Granny DLL convert a .gr2 out of bounds.

The append-only writer re-pointed root arrays and Model.MeshBindings to new arrays and left the old arrays WITH their
pointer fixups. granny2_age3de.dll then wrote live memory pointers past the converted section: the output depended on the
process memory layout and some files crashed (0xC0000005), while single DLL runs passed. Every Korean writer output had
12-58 orphan fixups; the 15 vanilla Shrine/scaffold files have none.

    python -m pytest scripts/havok/tests/test_gr2_fixups.py -q

Vanilla bytes are read from the game archives into the test's temp folder (never the repo, AGENTS.md rule 3); without a
game install the tests skip. The DLL test also needs AOP_GR2_DLL and Smart App Control off.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pytest

HAVOK = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HAVOK))
import gr2_lint as L  # noqa: E402
from gr2_dump import refs  # noqa: E402
from gr2_fixups import orphan_fixups, scrub  # noqa: E402
from gr2_read import Gr2  # noqa: E402
from gr2_splitmesh import Builder, member_offsets  # noqa: E402

SHRINE = 'art/buildings/asian_civs/shrine/age_2/japan_shrine_age2_01'


def vanilla(tmp_path, rel):
    bt, index = L._bartool()
    entry = index.get(rel.lower()) if bt else None
    if entry is None:
        pytest.skip(f'game archives not readable here ({rel})')
    p = tmp_path / Path(rel).name
    p.write_bytes(bt.read_entry(entry))
    return p


def repoint_root_meshes(src, dst, drop_old):
    """the INC-187 bisect step: root.Meshes re-pointed to a new array holding the SAME mesh pointers"""
    g = Gr2(str(src)); r = g.root(); B = Builder(g)
    off = member_offsets(g, (g.root_type_sec, g.root_type_off), ['Meshes'])[0]
    ptrs = [loc for _, loc in refs(g, r['Meshes'])]
    arr = B.alloc(0, bytes(8 * len(ptrs)))
    for i, p in enumerate(ptrs):
        B.ptr(0, arr + 8 * i, p)
    B.i32(g.root_sec, g.root_off + off, len(ptrs)); B.repoint(g.root_sec, g.root_off + off + 4, (0, arr))
    if drop_old:
        (s, o), n = r['Meshes'][2], r['Meshes'][1]
        B.relocs[s] = [x for x in B.relocs[s] if not (o <= x[0] < o + 8 * n)]
    B.write(dst)
    return len(ptrs)


def same_content(a, b):
    A, B = L.read_raw(a), L.read_raw(b)
    if A['materials'] != B['materials'] or [x['name'] for x in A['bones']] != [x['name'] for x in B['bones']]:
        return False
    return all(np.array_equal(x[k], y[k]) for x, y in zip(A['render'], B['render']) for k in ('pos', 'uv', 'tris'))


def test_vanilla_has_no_orphan_fixups(tmp_path):
    for suffix in ('.gr2', '_damaged.gr2'):
        rep = orphan_fixups(vanilla(tmp_path, SHRINE + suffix))
        assert rep['orphans'] == [] and rep['fixups'] > 300


def test_a_repointed_root_array_leaves_orphans_and_scrub_removes_only_them(tmp_path):
    src = vanilla(tmp_path, SHRINE + '.gr2')
    bad, ok = tmp_path / 'bad.gr2', tmp_path / 'ok.gr2'
    n = repoint_root_meshes(src, bad, drop_old=False)
    assert len(orphan_fixups(bad)['orphans']) == n == 2              # the old array's two mesh pointers
    repoint_root_meshes(src, ok, drop_old=True)
    assert orphan_fixups(ok)['orphans'] == []
    clean = tmp_path / 'clean.gr2'
    rep = scrub(bad, clean)
    assert rep['dropped'] == 2 and orphan_fixups(clean)['orphans'] == [] and Gr2(str(clean)).crc_check()
    assert same_content(bad, clean) and same_content(src, clean)


def test_the_writer_leaves_no_orphans_and_refuses_an_orphaned_donor(tmp_path):
    from multimaterial_gr2 import replace
    from gr2_uv_convention import blender_to_gr2_uv
    src = vanilla(tmp_path, SHRINE + '.gr2')
    r = L.read_raw(src); root = r['bones'][0]['name']; m = r['render'][0]
    uvb = blender_to_gr2_uv(m['uv'])                                  # v -> 1 - v is its own inverse
    tris = m['tris'][:40]; vs = np.unique(tris); remap = {int(v): i for i, v in enumerate(vs)}
    verts = [dict(p=m['pos'][v].tolist(), n=(m['nrm'][v] / np.linalg.norm(m['nrm'][v])).tolist(),
                  uv=[float(x) for x in uvb[v]], weights=[[root, 1.0]]) for v in vs]
    parts = [dict(material='mata', bone=root, vertices=verts, faces=[[remap[int(a)] for a in t] for t in tris])]
    mats = {'mata': dict(runtime_name='mata', resource_class='vanilla')}
    out = tmp_path / 'written.gr2'
    replace(src, parts, out, mats)
    assert orphan_fixups(out)['orphans'] == []
    bad = tmp_path / 'orphaned_donor.gr2'
    repoint_root_meshes(src, bad, drop_old=False)
    with pytest.raises(ValueError, match='orphan pointer fixups'):
        replace(bad, parts, tmp_path / 'never.gr2', mats)


def test_lint_check_fixups_fails_an_orphaned_file(tmp_path):
    src = vanilla(tmp_path, SHRINE + '.gr2')
    bad = tmp_path / 'bad.gr2'
    repoint_root_meshes(src, bad, drop_old=False)
    assert L.check_fixups('intact', bad, L.header(bad))['status'] == 'FAIL'
    assert L.check_fixups('intact', src, L.header(src))['status'] == 'PASS'


def test_dll_route_settings(tmp_path, monkeypatch):
    vals = {'AOP_GR2_DLL_ROUTE': 'sideways'}
    monkeypatch.setattr(L, '_local_value', lambda k: vals.get(k))
    tools = tmp_path / 'tools'; tools.mkdir(); (tools / 'gr2_to_raw.py').write_text('DISTRO = "Ubuntu"\n')
    real = sys.modules.pop('gr2_to_raw', None)                       # the stub must not outlive this test
    try:
        r = L.dll_read(tmp_path / 'x.gr2', tools, tmp_path)
        assert r['status'] == 'FAIL' and 'not one of' in r['tail']
        vals['AOP_GR2_DLL_ROUTE'] = 'native'                         # no AOP_GR2_DLL: never a pass
        r = L.dll_read(tmp_path / 'x.gr2', tools, tmp_path)
        assert r['status'] == 'SKIP' and 'AOP_GR2_DLL' in r['why']
    finally:
        sys.modules.pop('gr2_to_raw', None)
        if real is not None:
            sys.modules['gr2_to_raw'] = real


def test_native_dll_catches_the_orphans_a_single_run_misses(tmp_path):
    dll = L._local_value('AOP_GR2_DLL')
    if not dll or not Path(dll).is_file() or L.smart_app_control_on() is not False:
        pytest.skip('native DLL route not available here (AOP_GR2_DLL, Smart App Control)')
    tools = L.find_tools(L.load_profiles())
    if tools is None:
        pytest.skip('gr2_to_raw.py not on this device')
    sys.path.insert(0, str(tools))
    import gr2_to_raw as g2r
    src = vanilla(tmp_path, SHRINE + '.gr2')
    bad, ok = tmp_path / 'bad.gr2', tmp_path / 'ok.gr2'
    repoint_root_meshes(src, bad, drop_old=False)
    repoint_root_meshes(src, ok, drop_old=True)
    exe = tmp_path / 'tool.exe'; exe.write_bytes(g2r.build_exe())
    rc_ok, _ = L._dll_native(g2r, ok, tmp_path / 'ok_flat.gr2', exe, dll)
    rc_bad, tail = L._dll_native(g2r, bad, tmp_path / 'bad_flat.gr2', exe, dll)
    assert rc_ok == 0
    assert rc_bad != 0 and ('differ between memory layouts' in tail or '0xC0000005' in tail)
