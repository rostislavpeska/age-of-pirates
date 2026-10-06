"""INC-088: resume the real WIP source without laundering it as accepted."""
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import handoff as H


def specimen(tmp_path, parent_status='wip', status='wip'):
    parent = tmp_path / 'parent.json'
    parent.write_text(json.dumps({'phase': '02_material_split', 'status': parent_status}))
    (tmp_path / 'candidate.dat').write_bytes(b'new material candidate')
    spec = tmp_path / 'SPEC.json'
    spec.write_text(json.dumps({
        'model': 'military', 'phase': '02_material_split', 'status': status,
        'producer': 'fixture', 'next': '03_uv',
        'canonical': {'model': {'path': 'candidate.dat'}},
        'inputs': [{'handoff': 'parent.json'}],
    }))
    return spec, parent, tmp_path / 'HANDOFF.json'


def test_wip_can_resume_real_wip_parent_with_hash(tmp_path):
    spec, parent, output = specimen(tmp_path)
    assert H.write(spec, output) == 0
    saved = json.loads(output.read_text())
    assert saved['status'] == saved['inputs'][0]['status'] == 'wip'
    assert saved['inputs'][0]['sha256'] == H.sha(parent)
    assert H.check(output) == 0
    parent.write_text(json.dumps({'status': 'wip', 'changed': True}))
    assert H.check(output) == 3


def test_wip_parent_does_not_promote_to_review_or_accepted(tmp_path):
    for status in ('review', 'accepted'):
        spec, _, output = specimen(tmp_path, status=status)
        assert H.write(spec, output) == 3
        assert not output.exists()


def test_superseded_parent_is_not_a_resumable_wip(tmp_path):
    spec, _, output = specimen(tmp_path, parent_status='superseded')
    assert H.write(spec, output) == 3


def test_check_rejects_status_promotion_with_wip_parent(tmp_path):
    spec, _, output = specimen(tmp_path)
    assert H.write(spec, output) == 0
    d = json.loads(output.read_text())
    d['status'] = 'accepted'
    output.write_text(json.dumps(d))
    assert H.check(output) == 3
