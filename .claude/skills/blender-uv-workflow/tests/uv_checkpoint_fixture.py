"""Small synthetic evidence chain for downstream integration tests, never production evidence."""
import json
from pathlib import Path
import sys
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import checkpoint as CP


def freeze_fixture(root, asset, canonical, through='freeze'):
    root = Path(root); parent = None
    def ref(p):
        return {'path': str(p.resolve()), 'sha256': CP.file_hash(p)}
    for stage, (checks, views) in CP.STAGES.items():
        d = root / stage; d.mkdir(parents=True, exist_ok=True)
        inputs = {role: ref(path) for role, path in canonical.items()}
        bind = dict(asset=asset, revision='synthetic-fixture', stage=stage,
                    inputs={role: r['sha256'] for role, r in inputs.items()})
        spec = dict(schema=1, asset=asset, revision=bind['revision'], stage=stage, inputs=inputs, checks=[], views=[])
        for name in checks.split():
            p = d / (name + '.json')
            metrics = dict(shared_face_count=0,unmapped=0,incompatible=0,unbound=0,outside_cells=0,unreviewed_exposure=0,coverage_errors=0) if name=='shared_mapping' else {'fixture_only':True}
            p.write_text(json.dumps(dict(bind, check=name, status='PASS',
                metrics=metrics, validator={'name': 'synthetic-unit-test', 'version': '1'})))
            spec['checks'].append(ref(p))
        for kind in views.split():
            p = d / (kind + '.png'); Image.new('RGB', (8, 8), 'grey').save(p)
            spec['views'].append(dict(ref(p), kind=kind))
        p = d / 'readback.json'; p.write_text(json.dumps(dict(bind, level='FILE_VERIFIED')))
        spec['publication'] = {'level': 'FILE_VERIFIED', 'evidence': ref(p)}
        p = d / 'owner.txt'; p.write_text('Synthetic test approval, not an owner decision.')
        spec['acceptance'] = {'scope': stage, 'evidence': ref(p)}
        if parent:
            spec['parent'] = ref(parent)
        p = d / 'spec.json'; p.write_text(json.dumps(spec))
        parent = d / 'CHECKPOINT.json'
        # Multiple test calls in the same directory may deliberately change the candidate.
        # Delete only this temporary test receipt, never a production file.
        parent.unlink(missing_ok=True)
        result = CP.write(p, parent)
        if result['status'] != 'PASS':
            raise AssertionError(result)
        if stage == through:
            return ref(parent)
    raise ValueError(through)
