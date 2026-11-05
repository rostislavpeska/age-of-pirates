"""aoe3de-anim-viewer layered VFS (scripts/vfs.py): mod order, archive layer, XMB twins, the engine's silent failures.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_vfs.py -q

Synthetic and CI-safe: a fake profile (mods/age3-mod-status.json + mod folders) and a fake game folder with .bar
archives are built in pytest's temp folder by av_fixtures; the cache goes there too (AOP_ANIM_VIEWER_CACHE).
"""
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
import av_fixtures as F  # noqa: E402
import vfs as V  # noqa: E402

ANIM = '<animfile><component>ModelComp<assetreference type="GrannyModel"><file>units\\x\\x</file></assetreference>' \
       '</component><anim>Idle<component>ModelComp</component></anim></animfile>'


@pytest.fixture(autouse=True)
def cache_in_tmp(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))


def world(tmp_path):
    g = F.Game(tmp_path / 'game')
    g.add('Art', 'units/x/x.xml', ANIM, xmb=True)
    g.add('Art', 'units/x/x.gr2', b'GR2-GAME', compress=False)
    g.add('Art', 'units/y/y.material', '<material><submaterial name="mata"/></material>', xmb=True)
    g.add('Data', 'tactics/foo.tactics', '<tactics><action><name>A</name></action></tactics>', xmb=True)
    g.write()
    p = F.Profile(tmp_path / 'profile')
    aop = p.mod('age-of-pirates', priority=1)
    kor = p.mod('age-of-pirates-koreans', priority=2)
    p.mod('Disabled Mod', priority=0, enabled=False).write('art/units/x/x.gr2', b'DISABLED')
    p.mod('Gone', priority=5, create=False)
    p.write()
    return g, p, aop, kor


def fs_of(tmp_path, **kw):
    return V.VFS(profile=tmp_path / 'profile', game_dir=tmp_path / 'game', **kw)


# ---------------------------------------------------------------- paths
def test_physical_and_logical_paths():
    assert V.physical('units/x/y.gr2') == 'art/units/x/y.gr2'
    assert V.physical('Art' + chr(92) + 'Units' + chr(92) + 'Y.gr2') == 'art/units/y.gr2'
    assert V.physical('data/tactics/a.tactics') == 'data/tactics/a.tactics'
    assert V.physical('Sound/x_snds.xml') == 'sound/x_snds.xml'
    assert V.ref_id('units' + chr(92) + 'asians' + chr(92) + 'iron_rider_0', '.gr2') == 'units/asians/iron_rider_0.gr2'
    assert V.ref_id('a/b.gr2', '.gr2') == 'a/b.gr2'
    assert V.is_runtime_xml('art/units/x/x.xml') and V.is_runtime_xml('data/tactics/a.tactics')
    assert V.is_runtime_xml('art/x/y.material') and V.is_runtime_xml('sound/x_snds.xml')
    assert not V.is_runtime_xml('data/protomods.xml')


def test_eol_classification():
    assert V.eol_of(b'a\r\nb\r\n') == 'crlf'
    assert V.eol_of(b'a\nb\n') == 'lf'
    assert V.eol_of(b'a\r\nb\n') == 'mixed'
    assert V.eol_of(b'<a/>') == 'none'


def test_xml_helpers_are_case_insensitive_and_keep_spelling():
    import xml.etree.ElementTree as ET
    el = ET.fromstring('<Unit mergeMode="replace" name="X"><DBID> 12 </DBID><Rate type="Unit">1.0 </Rate>'
                       'Walk</Unit>')
    assert V.attr(el, 'mergemode') == 'replace' and V.kid_text(el, 'dbid') == '12'
    assert V.number('12') == 12 and V.number('1.0 ') == 1.0 and V.number('x') is None
    assert V.flag('1') is True and V.flag('0') is False and V.flag('maybe') is None
    assert V.fields(el)[1] == {'tag': 'Rate', 'attrs': {'type': 'Unit'}, 'text': '1.0'}


# ---------------------------------------------------------------- layers
def test_layers_follow_the_mod_status_file(tmp_path):
    world(tmp_path)
    fs = fs_of(tmp_path)
    recs = fs.layer_records()
    assert [r['id'] for r in recs] == ['mod:age-of-pirates', 'mod:age-of-pirates-koreans', 'game']
    assert recs[0] == {'id': 'mod:age-of-pirates', 'kind': 'mod', 'title': 'age-of-pirates', 'priority': 1,
                       'enabled': True, 'source': 'mods/age3-mod-status.json'}
    assert recs[-1]['kind'] == 'game' and recs[-1]['source'] == 'archives'
    codes = [w['code'] for w in fs.warnings]
    assert codes == ['mod-folder-missing']                         # 'Gone' is enabled but has no folder
    ins = fs.inputs()
    assert [i['id'] for i in ins] == [r['id'] for r in recs] and all(len(i['fingerprint']) == 16 for i in ins)


def test_find_profile_walks_up(tmp_path):
    world(tmp_path)
    deep = tmp_path / 'profile' / 'mods' / 'local' / 'age-of-pirates' / '.claude' / 'skills'
    deep.mkdir(parents=True)
    assert V.find_profile(deep) == tmp_path / 'profile'
    assert V.find_profile(tmp_path / 'game') is None


def test_no_profile_and_no_game_are_warnings_not_errors(tmp_path, monkeypatch):
    bartool, _ = V._bartool()
    monkeypatch.setattr(bartool, 'DEFAULT_GAME_DIRS', [str(tmp_path / 'no-steam')])
    monkeypatch.delenv('AOE3DE_GAME', raising=False)
    fs = V.VFS(include_mods=False, game_dir=tmp_path / 'nowhere')
    assert fs.layers == [] and [w['code'] for w in fs.warnings] == ['game-unavailable']
    monkeypatch.setattr(V, 'find_profile', lambda start=None: None)
    fs = V.VFS(include_game=False)
    assert fs.layers == [] and [w['code'] for w in fs.warnings] == ['mods-unavailable']
    assert fs.read('units/x.gr2') is None and fs.warnings[-1]['code'] == 'file-missing'


# ---------------------------------------------------------------- lookup and precedence
def test_the_first_layer_wins_and_disabled_mods_are_ignored(tmp_path):
    g, p, aop, kor = world(tmp_path)
    kor.write('Art/Units/X/X.gr2', b'GR2-KOREANS')                 # case differs from the request
    fs = fs_of(tmp_path)
    vf = fs.read('units/x/x.gr2')
    assert vf.layer == 'mod:age-of-pirates-koreans' and vf.data == b'GR2-KOREANS' and vf.form == 'raw'
    assert vf.name == 'Art/Units/X/X.gr2' and vf.local.is_file() and vf.eol is None
    aop.write('art/units/x/x.gr2', b'GR2-AOP')
    fs = fs_of(tmp_path)
    assert fs.read('units/x/x.gr2').data == b'GR2-AOP'
    hits = fs.hits('units/x/x.gr2')
    assert [h[0].id for h in hits] == ['mod:age-of-pirates', 'mod:age-of-pirates-koreans', 'game']
    assert fs.find('units/x/x.gr2') == ('mod:age-of-pirates', 'art/units/x/x.gr2', 'raw')


def test_game_layer_reads_archives_and_decodes_xmb(tmp_path):
    world(tmp_path)
    fs = fs_of(tmp_path)
    vf = fs.read_xml('units/x/x.xml')
    assert vf.layer == 'game' and vf.form == 'xmb' and vf.eol == 'xmb' and vf.source_form == 'xmb'
    assert vf.container == 'Art.bar' and vf.name == 'Art/units/x/x.xml.XMB'
    assert V.tag(vf.root) == 'animfile' and V.text(V.kid(vf.root, 'anim')) == 'Idle'
    t = fs.read_xml('data/tactics/foo.tactics')
    assert t.container == 'Data.bar' and V.kid_text(V.kid(t.root, 'action'), 'name') == 'A'
    rec = fs.provenance.records[vf.provenance]
    assert rec['layer'] == 'game' and rec['path'] == 'units/x/x.xml.xmb' and rec['container'] == 'Art.bar'
    assert rec['sha256'] == C.sha256_bytes(vf.data)
    assert fs.read_xml('units/x/x.xml') is vf                     # cached


def test_missing_files_warn_unless_quiet(tmp_path):
    world(tmp_path)
    fs = fs_of(tmp_path)
    assert fs.read('units/none/none.gr2', quiet=True) is None and fs.warnings[-1]['code'] == 'mod-folder-missing'
    assert fs.read('units/none/none.gr2') is None
    assert fs.warnings[-1]['code'] == 'file-missing' and fs.warnings[-1]['path'] == 'units/none/none.gr2'
    assert not fs.exists('units/none/none.gr2') and fs.exists('units/x/x.gr2')


def test_a_mod_xmb_twin_wins_and_a_stale_one_is_reported(tmp_path):
    g, p, aop, kor = world(tmp_path)
    plain = '<protomods><unit name="A"><dbid>1</dbid></unit></protomods>'
    aop.write('data/protomods.xml', plain)
    aop.write('data/protomods.xml.xmb', F.alz4(F.to_xmb(plain)))
    kor.write('data/protomods.xml', plain)
    kor.write('data/protomods.xml.XMB', F.to_xmb('<protomods><unit name="B"/></protomods>'))
    fs = fs_of(tmp_path)
    each = fs.read_each('data/protomods.xml')
    assert [(v.layer, v.form) for v in each] == [('mod:age-of-pirates', 'xmb'), ('mod:age-of-pirates-koreans', 'xmb')]
    assert V.attr(V.kid(each[1].root, 'unit'), 'name') == 'B'      # the engine reads the twin, stale or not
    stale = [w for w in fs.warnings if w['code'] == 'stale-xmb-twin']
    assert [w['layer'] for w in stale] == ['mod:age-of-pirates-koreans']
    notes = [r for r in fs.provenance.records if r['note']]
    assert {r['layer'] for r in notes} == {'mod:age-of-pirates', 'mod:age-of-pirates-koreans'}


def test_lf_only_runtime_xml_in_a_mod_is_flagged_and_can_fall_through(tmp_path):
    g, p, aop, kor = world(tmp_path)
    aop.write('art/units/x/x.xml', ANIM.replace('><', '>\n<'), eol='lf')
    fs = fs_of(tmp_path)
    vf = fs.read_xml('units/x/x.xml')
    assert vf.layer == 'mod:age-of-pirates' and vf.eol == 'lf' and vf.engine_ignored and vf.form == 'xml'
    w = [w for w in fs.warnings if w['code'] == 'lf-only-runtime-xml']
    assert len(w) == 1 and w[0]['layer'] == 'mod:age-of-pirates' and 'rule 1' in w[0]['message']
    fs = fs_of(tmp_path, lf_policy='engine')
    vf = fs.read_xml('units/x/x.xml')
    assert vf.layer == 'game' and vf.shadowed == ['mod:age-of-pirates'] and not vf.engine_ignored
    with pytest.raises(ValueError):
        fs_of(tmp_path, lf_policy='nope')


def test_crlf_and_mixed_runtime_xml(tmp_path):
    g, p, aop, kor = world(tmp_path)
    aop.write('art/units/x/x.xml', ANIM.replace('><', '>\n<'), eol='crlf')
    aop.write('art/units/y/y.material', b'<material>\r\n<submaterial name="a"/>\n</material>\r\n')
    aop.write('data/notruntime.xml', '<a>\n</a>', eol='lf')
    fs = fs_of(tmp_path)
    assert fs.read_xml('units/x/x.xml').eol == 'crlf'
    m = fs.read_xml('units/y/y.material')
    assert m.eol == 'mixed' and not m.engine_ignored
    assert fs.read_xml('data/notruntime.xml').eol == 'lf'
    assert [w['code'] for w in fs.warnings if 'eol' in w['code'] or 'lf-only' in w['code']] == ['mixed-eol-runtime-xml']


def test_broken_xml_is_reported_not_raised(tmp_path):
    g, p, aop, kor = world(tmp_path)
    aop.write('art/units/x/x.xml', '<animfile><anim>Idle</animfile>')
    fs = fs_of(tmp_path)
    vf = fs.read_xml('units/x/x.xml')
    assert vf.root is None and vf.unavailable_reason == 'xml-parse-failed'
    assert fs.warnings[-1]['code'] == 'xml-parse-failed'


def test_materialize_copies_archive_files_into_the_cache_only(tmp_path):
    g, p, aop, kor = world(tmp_path)
    fs = fs_of(tmp_path)
    out = fs.materialize('units/x/x.gr2')
    assert out.read_bytes() == b'GR2-GAME' and str(out).startswith(str(tmp_path / 'cache'))
    assert fs.materialize('units/x/x.gr2') == out
    aop.write('art/units/x/x.gr2', b'GR2-AOP')
    fs = fs_of(tmp_path)
    assert fs.materialize('units/x/x.gr2') == aop.folder / 'art' / 'units' / 'x' / 'x.gr2'


def test_materialize_refuses_a_cache_inside_a_repository(tmp_path, monkeypatch):
    world(tmp_path)
    (tmp_path / 'repo' / '.git').mkdir(parents=True)
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'repo' / 'cache'))
    fs = fs_of(tmp_path)
    with pytest.raises(C.RepoPathError):
        fs.materialize('units/x/x.gr2')
    assert not (tmp_path / 'repo' / 'cache').exists()


def test_the_vfs_never_writes_into_layers(tmp_path):
    g, p, aop, kor = world(tmp_path)
    aop.write('art/units/x/x.xml', ANIM, eol='lf')
    before = sorted(str(q) for q in (tmp_path / 'profile').rglob('*')) + \
        sorted(str(q) for q in (tmp_path / 'game').rglob('*'))
    fs = fs_of(tmp_path)
    fs.read_xml('units/x/x.xml')
    fs.materialize('units/x/x.gr2')
    fs.read_each('data/protomods.xml')
    after = sorted(str(q) for q in (tmp_path / 'profile').rglob('*')) + \
        sorted(str(q) for q in (tmp_path / 'game').rglob('*'))
    assert before == after


def test_explicit_layers(tmp_path):
    g, p, aop, kor = world(tmp_path)
    aop.write('art/a.gr2', b'A')
    lay = V.Layer('mod:test', 'mod', 'test', 1, True, 'test', aop.folder, V.ModStore(aop.folder))
    fs = V.VFS([lay])
    assert fs.read('a.gr2').data == b'A' and fs.layer_records()[0]['id'] == 'mod:test'
