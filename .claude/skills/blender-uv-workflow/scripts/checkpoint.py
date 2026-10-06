"""Evidence-bound subcheckpoints. No Blender mutations; Pillow validates view files."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parent))
from shared_mapping import metric_errors as shared_mapping_errors

STAGES = {
    'geometry': ('coverage geometry attachments mesh_budget', 'model ground attachments'),
    'clean': ('coverage charts continuity stretch', 'model checker uv_sheet'),
    'materials': ('coverage material_classes protected_scope', 'model materials legend'),
    'share': ('coverage families correspondence channels protected_scope', 'model families uv_sheet'),
    'ao': ('coverage ao_correspondence ao_recipe continuity', 'model ao_heatmap families'),
    'freeze': ('coverage overlap density page_budget padding source_detail shared_mapping', 'model checker uv_sheet'),
    'base': ('coverage bindings bake_contract texture_qa', 'model basecolor normal ao'),
    'details': ('bindings texture_qa protected_scope', 'model details player_color'),
    'game': ('source_binding export_roundtrip runtime_lint installed_hashes game_test', 'intact destruction'),
}


def digest(data):
    return hashlib.sha256(json.dumps(data, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def file_hash(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'), parse_constant=lambda x: (_ for _ in ()).throw(ValueError(x)))


def atomic_new(path, data):
    """Immutable receipt: atomic creation without a replace race."""
    path = Path(path)
    payload = json.dumps(data, sort_keys=True, indent=2, allow_nan=False).encode() + b'\n'
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if read(path) == data:
            return
        raise ValueError('receipt already exists with different content; use a new checkpoint path')
    fd, temp = tempfile.mkstemp(dir=path.parent, prefix='.checkpoint-')
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(payload); f.flush(); os.fsync(f.fileno())
        try:
            os.link(temp, path)  # fails if another writer created the destination
        except FileExistsError:
            if read(path) != data:
                raise ValueError('concurrent checkpoint has different content')
    finally:
        Path(temp).unlink(missing_ok=True)


def validate(spec, base, seen=None, receipt=False):
    errors, incomplete, advice = [], [], []
    base = Path(base)
    seen = set(seen or ())

    def artifact(ref, label):
        if not isinstance(ref, dict) or not isinstance(ref.get('path'), str) or not ref.get('sha256'):
            incomplete.append(label + ': missing path/hash'); return None
        p = (base / ref['path']).resolve()
        if not p.is_file() or not p.stat().st_size:
            incomplete.append(label + ': missing/empty file'); return None
        if file_hash(p) != ref['sha256']:
            errors.append(label + ': hash mismatch'); return None
        return p

    def bound(data):
        return all(data.get(k) == spec.get(k) for k in ('asset', 'revision', 'stage')) and data.get('inputs') == inputs

    if not isinstance(spec, dict):
        return {'status': 'FAIL', 'errors': ['spec must be an object'], 'incomplete': [], 'advisories': []}
    stage = spec.get('stage')
    if spec.get('schema') != 1 or stage not in STAGES:
        errors.append('unknown schema/stage')
    for k in ('asset', 'revision'):
        if not isinstance(spec.get(k), str) or not spec[k].strip():
            incomplete.append('missing ' + k)
    if receipt:
        body = {k: v for k, v in spec.items() if k != 'receipt_id'}
        if spec.get('receipt_id') != digest(body):
            errors.append('receipt content hash mismatch')
    inp = spec.get('inputs')
    if not isinstance(inp, dict) or not inp:
        incomplete.append('missing inputs'); inp = {}
    inputs = {}
    for role, ref in inp.items():
        if artifact(ref, 'input ' + role):
            inputs[role] = ref['sha256']

    parent = spec.get('parent')
    if stage != 'geometry' and not parent:
        incomplete.append('missing predecessor checkpoint')
    if parent:
        p = artifact(parent, 'parent')
        if p:
            if p in seen:
                errors.append('checkpoint cycle')
            else:
                up = read(p)
                result = validate(up, p.parent, seen | {p}, receipt=True)
                if result['status'] != 'PASS':
                    errors.append('parent checkpoint is not valid: ' + result['status'])
                order = list(STAGES)
                allowed = {stage}
                if stage in order and order.index(stage):
                    allowed.add(order[order.index(stage) - 1])
                if up.get('asset') != spec.get('asset') or up.get('stage') not in allowed:
                    errors.append('wrong asset or predecessor stage')

    required, view_kinds = STAGES.get(stage, ('', ''))
    reports = {}
    for ref in spec.get('checks', []):
        p = artifact(ref, 'check')
        if not p:
            continue
        report = read(p); name = report.get('check')
        if not isinstance(name, str) or name in reports:
            errors.append('missing/duplicate check name'); continue
        reports[name] = report
        if name not in required.split() and not name.startswith('advisory:'):
            errors.append('check not applicable: ' + name); continue
        if not bound(report):
            errors.append('stale/wrong binding: ' + name)
        validator = report.get('validator') or {}
        if not validator.get('name') or not validator.get('version') or not isinstance(report.get('metrics'), dict) or not report['metrics']:
            incomplete.append('missing validator/metrics: ' + name)
        status = report.get('status')
        if name == 'shared_mapping':
            for problem in shared_mapping_errors(report.get('metrics') or {}):
                incomplete.append('shared_mapping: ' + problem)
        if status not in ('PASS', 'FAIL', 'INCOMPLETE', 'REVIEW'):
            errors.append('invalid check status: ' + name)
        elif name.startswith('advisory:'):
            advice.append({'check': name, 'status': status, 'metrics': report.get('metrics')})
        elif status == 'INCOMPLETE':
            incomplete.append('check incomplete: ' + name)
        elif status == 'FAIL':
            errors.append('check failed: ' + name)
        elif status == 'REVIEW':
            artifact((spec.get('dispositions') or {}).get(name), 'review disposition ' + name)
    for name in required.split():
        if name not in reports:
            incomplete.append('missing check: ' + name)

    visible = set()
    for ref in spec.get('views', []):
        p = artifact(ref, 'view')
        if p:
            if p.suffix.lower() not in ('.png', '.jpg', '.jpeg', '.webp'):
                errors.append('view must be an image: ' + str(p))
            try:
                with Image.open(p) as im:
                    im.verify()
                with Image.open(p) as im:
                    im.load()
                    if im.width < 1 or im.height < 1:
                        raise ValueError('empty image')
            except (OSError, ValueError, SyntaxError) as e:
                errors.append('invalid view image: ' + str(p) + ': ' + str(e))
            visible.add(ref.get('kind'))
    for kind in view_kinds.split():
        if kind not in visible:
            incomplete.append('missing visible evidence: ' + kind)
    acceptance = spec.get('acceptance') or {}
    if acceptance.get('scope') != stage:
        incomplete.append('owner acceptance not scoped to stage')
    owner_evidence = artifact(acceptance.get('evidence'), 'owner acceptance')
    # INC-092: a delivered WIP receipt is observable evidence, not acceptance.
    # Evidence provenance is still a trusted/manual boundary; never override an
    # explicit pending/negative decision merely because its file exists.
    if owner_evidence and owner_evidence.suffix.lower() == '.json':
        decision = read(owner_evidence)
        if isinstance(decision, dict) and (
            decision.get('owner_accepted') is False or
            decision.get('status') in ('pending', 'rejected', 'denied', 'wip')
        ):
            incomplete.append('owner evidence explicitly lacks acceptance')
    pub = spec.get('publication') or {}
    p = artifact(pub.get('evidence'), 'publication readback')
    if pub.get('level') not in ('FILE_VERIFIED', 'LIVE_VERIFIED'):
        incomplete.append('publication level missing/invalid')
    if p:
        data = read(p)
        if not bound(data) or data.get('level') != pub.get('level'):
            errors.append('publication is not bound to this checkpoint/level')
        if pub.get('level') == 'LIVE_VERIFIED' and not all(data.get(k) for k in ('session_id', 'scene', 'readback_operation')):
            incomplete.append('live verification lacks session/scene/operation')
    return {'status': 'FAIL' if errors else 'INCOMPLETE' if incomplete else 'PASS',
            'errors': errors, 'incomplete': incomplete, 'advisories': advice}


def load_validate(path, receipt=False):
    p = Path(path).resolve()
    spec = read(p)
    return spec, validate(spec, p.parent, {p}, receipt=receipt)


def write(spec_path, out):
    spec, result = load_validate(spec_path)
    if result['status'] != 'PASS':
        return result
    if Path(spec_path).resolve().parent != Path(out).resolve().parent:
        raise ValueError('spec and receipt must share a directory so relative paths retain their meaning')
    spec = copy.deepcopy(spec); spec.pop('receipt_id', None)
    spec['receipt_id'] = digest(spec)
    atomic_new(out, spec)
    return result


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('command', choices=('validate', 'write', 'check', 'summary'))
    ap.add_argument('path'); ap.add_argument('--out')
    a = ap.parse_args(argv)
    try:
        if a.command == 'write':
            if not a.out:
                raise ValueError('write requires --out')
            result = write(a.path, a.out)
        else:
            spec, result = load_validate(a.path, receipt=a.command in ('check', 'summary'))
            if a.command == 'summary':
                result.update(asset=spec.get('asset'), revision=spec.get('revision'), stage=spec.get('stage'),
                              publication=(spec.get('publication') or {}).get('level'))
        print(json.dumps(result, indent=2))
        return {'PASS': 0, 'INCOMPLETE': 2, 'FAIL': 3}[result['status']]
    except (OSError, ValueError, TypeError, KeyError, AttributeError, RecursionError) as e:
        print(json.dumps({'status': 'FAIL', 'errors': [str(e)]}))
        return 3


if __name__ == '__main__':
    sys.exit(main())
