"""Owner 2026-10-09: "this handoff contract should be unbreakable". A handoff that asks for the owner's review or
acceptance is refused unless his live viewer read back exactly the primary .blend and its active scene."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import handoff as H  # noqa: E402

SCENE = 'Castle | UV r4 OPERATOR'


def specimen(tmp_path, readback=True, **over):
    (tmp_path / 'Model.blend').write_bytes(b'the delivered blend')
    rb = {'version': 'uv-r4-pub01', 'file_sha256': H.sha(tmp_path / 'Model.blend'), 'scene': SCENE,
          'viewer': 'pid 29084', 'at': '2026-10-09T13:00:00Z'}
    spec = {'model': 'castle', 'phase': '03_uv', 'status': 'wip', 'owner_review': 'pending', 'producer': 'fixture',
            'next': 'texturing', 'primary_blend': 'Model.blend', 'active_scene': SCENE,
            'canonical': {'blend': {'path': 'Model.blend'}}}
    if readback:
        spec['delivery'] = {'live_readback': rb}
    spec.update(over)
    p = tmp_path / 'SPEC.json'; p.write_text(json.dumps(spec))
    return p, tmp_path / 'HANDOFF.json'


def test_review_request_with_matching_readback_is_written_and_checks(tmp_path):
    spec, out = specimen(tmp_path)
    assert H.write(spec, out) == 0
    assert json.loads(out.read_text())['schema'] == 2 and H.check(out) == 0


def test_review_request_without_readback_is_refused(tmp_path, capsys):
    spec, out = specimen(tmp_path, readback=False)
    assert H.write(spec, out) == 3 and not out.exists()
    assert "not visible in the owner's Blender" in capsys.readouterr().out


def test_readback_of_other_bytes_or_scene_is_refused(tmp_path, capsys):
    spec, out = specimen(tmp_path)
    d = json.loads(spec.read_text()); d['delivery']['live_readback']['file_sha256'] = 'f' * 64; spec.write_text(json.dumps(d))
    assert H.write(spec, out) == 3
    assert 'viewer showed other bytes' in capsys.readouterr().out
    spec, out = specimen(tmp_path)
    d = json.loads(spec.read_text()); d['delivery']['live_readback']['scene'] = 'Castle | UV r1 OPERATOR'; spec.write_text(json.dumps(d))
    assert H.write(spec, out) == 3


def test_primary_blend_must_be_canonical(tmp_path, capsys):
    spec, out = specimen(tmp_path, primary_blend='Other.blend')
    assert H.write(spec, out) == 3
    assert 'primary_blend must name a canonical .blend entry' in capsys.readouterr().out


def test_accepted_needs_the_owners_words(tmp_path, capsys):
    spec, out = specimen(tmp_path, status='accepted', phase='01_geometry')
    assert H.write(spec, out) == 3
    assert "the owner's own words" in capsys.readouterr().out
    spec, out = specimen(tmp_path, status='accepted', phase='01_geometry',
                         owner_acceptance={'quote': 'the UV is fine', 'at': '2026-10-09T12:40:00Z'})
    assert H.write(spec, out) == 0


def test_check_catches_a_blend_edited_after_delivery(tmp_path):
    spec, out = specimen(tmp_path)
    assert H.write(spec, out) == 0
    (tmp_path / 'Model.blend').write_bytes(b'edited after the owner saw it')
    assert H.check(out) == 3


def test_internal_wip_step_needs_no_viewer(tmp_path):
    spec, out = specimen(tmp_path, readback=False, owner_review='not requested')
    assert H.write(spec, out) == 0
