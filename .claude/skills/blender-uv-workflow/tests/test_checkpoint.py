"""Receipt writer/checker behavior, including INC-078: text is not image evidence."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import io
from PIL import Image

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
sys.path.insert(0, str(SCRIPTS))
import checkpoint as C


class CheckpointTests(unittest.TestCase):
    def test_ao_and_freeze_require_white_baked_view(self):
        for stage in ('ao','freeze'):
            d,spec=self.candidate(stage)
            spec['views']=[v for v in spec['views'] if v['kind']!='ao_white']
            report=C.validate(spec,d)
            self.assertEqual(report['status'],'INCOMPLETE')
            self.assertTrue(any('ao_white' in text for text in report['incomplete']))
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def ref(self, folder, name, data):
        p = folder / name
        p.write_bytes(data if isinstance(data, bytes) else json.dumps(data).encode())
        return {'path': str(p), 'sha256': C.file_hash(p)}

    def candidate(self, stage, parent=None):
        d = self.root / stage; d.mkdir(exist_ok=True)
        spec = {'schema': 1, 'asset': 'barracks', 'revision': 'r16', 'stage': stage,
                'inputs': {'low': self.ref(d, 'mesh.bin', b'source revision')},
                'checks': [], 'views': [], 'dispositions': {}}
        binding = {k: spec[k] for k in ('asset', 'revision', 'stage')}
        binding['inputs'] = {k: v['sha256'] for k, v in spec['inputs'].items()}
        for name in C.STAGES[stage][0].split():
            metrics = dict(shared_face_count=0,unmapped=0,incompatible=0,unbound=0,outside_cells=0,unreviewed_exposure=0,coverage_errors=0) if name=='shared_mapping' else {'measured':1}
            spec['checks'].append(self.ref(d, name + '.json', dict(binding, check=name,
                status='PASS', validator={'name': 'fixture-measurement', 'version': '1'}, metrics=metrics)))
        for kind in C.STAGES[stage][1].split():
            image = io.BytesIO(); Image.new('RGB', (8, 8), 'grey').save(image, format='PNG')
            spec['views'].append(dict(self.ref(d, kind + '.png', image.getvalue()), kind=kind))
        spec['publication'] = {'level': 'FILE_VERIFIED', 'evidence': self.ref(d, 'readback.json', dict(binding, level='FILE_VERIFIED'))}
        spec['acceptance'] = {'scope': stage, 'evidence': self.ref(d, 'owner.json', {'message': 'accepted fixture'})}
        if parent:
            spec['parent'] = {'path': str(parent), 'sha256': C.file_hash(parent)}
        return d, spec

    def save(self, d, spec):
        p = d / 'spec.json'; p.write_text(json.dumps(spec))
        return p

    def receipt(self, stage, parent=None):
        d, spec = self.candidate(stage, parent)
        p = d / 'CHECKPOINT.json'
        self.assertEqual(C.write(self.save(d, spec), p)['status'], 'PASS')
        return p

    def clean(self):
        return self.candidate('clean', self.receipt('geometry'))

    def change_report(self, spec, index, **changes):
        ref = spec['checks'][index]; p = Path(ref['path'])
        report = C.read(p); report.update(changes); p.write_text(json.dumps(report))
        ref['sha256'] = C.file_hash(p)

    def test_clean_without_runtime_budget_and_full_chain_to_materials(self):
        parent = self.receipt('geometry')
        clean = self.receipt('clean', parent)
        end = self.receipt('materials', clean)
        self.assertEqual(C.load_validate(end, receipt=True)[1]['status'], 'PASS')

    def test_skipped_stage_rejected(self):
        d, spec = self.candidate('share', self.receipt('geometry'))
        self.assertIn('wrong asset or predecessor stage', C.validate(spec, d)['errors'])

    def test_missing_check_never_passes(self):
        d, spec = self.clean(); spec['checks'].pop(0)
        self.assertEqual(C.validate(spec, d)['status'], 'INCOMPLETE')

    def test_INC095_freeze_rejects_pending_shared_mapping_labeled_pass(self):
        parent = None
        for stage in ('geometry','clean','materials','share','ao'):
            parent = self.receipt(stage,parent)
        d,spec=self.candidate('freeze',parent)
        index=C.STAGES['freeze'][0].split().index('shared_mapping')
        self.change_report(spec,index,status='PASS',metrics=dict(shared_face_count=100,unmapped=1,incompatible=0,unbound=0,outside_cells=0,unreviewed_exposure=0,coverage_errors=0))
        self.assertEqual(C.validate(spec,d)['status'],'INCOMPLETE')

    def test_empty_metrics_never_passes(self):
        d, spec = self.clean(); self.change_report(spec, 0, metrics={})
        self.assertEqual(C.validate(spec, d)['status'], 'INCOMPLETE')

    def test_stale_revision_and_uv_input_rejected(self):
        d, spec = self.clean(); self.change_report(spec, 0, revision='old')
        self.assertEqual(C.validate(spec, d)['status'], 'FAIL')
        self.change_report(spec, 0, revision='r16', inputs={'low': 'wrong'})
        self.assertEqual(C.validate(spec, d)['status'], 'FAIL')

    def test_failure_cannot_be_waived_as_review(self):
        d, spec = self.clean(); self.change_report(spec, 0, status='FAIL')
        spec['dispositions']['coverage'] = self.ref(d, 'exception.txt', b'allow')
        self.assertEqual(C.validate(spec, d)['status'], 'FAIL')

    def test_review_disposition_is_required_and_bound_by_hash(self):
        d, spec = self.clean(); self.change_report(spec, 3, status='REVIEW')
        self.assertEqual(C.validate(spec, d)['status'], 'INCOMPLETE')
        spec['dispositions']['stretch'] = self.ref(d, 'review.txt', b'curved trim accepted')
        self.assertEqual(C.validate(spec, d)['status'], 'PASS')
        Path(spec['dispositions']['stretch']['path']).write_bytes(b'changed')
        self.assertEqual(C.validate(spec, d)['status'], 'FAIL')

    def test_space_diagnostic_does_not_reject_clean_stage(self):
        d, spec = self.clean()
        report = C.read(spec['checks'][0]['path'])
        report.update(check='advisory:unshared', status='FAIL', metrics={'fraction': 1})
        spec['checks'].append(self.ref(d, 'advice.json', report))
        result = C.validate(spec, d)
        self.assertEqual(result['status'], 'PASS'); self.assertEqual(len(result['advisories']), 1)

    def test_density_check_cannot_be_misapplied_to_clean(self):
        d, spec = self.clean(); self.change_report(spec, 0, check='density')
        self.assertEqual(C.validate(spec, d)['status'], 'FAIL')

    def test_no_promotion_without_observable_evidence(self):
        d, spec = self.clean(); spec['views'].pop()
        self.assertEqual(C.validate(spec, d)['status'], 'INCOMPLETE')

    def test_INC_092_delivered_or_rejected_is_not_accepted(self):
        """INC-092: a posted WIP or explicit rejection is not owner acceptance."""
        d, spec = self.clean()
        for content in ({'delivered_in_chat': True, 'owner_accepted': False},
                        {'status': 'pending'}, {'status': 'rejected'}, {'status': 'wip'}):
            with self.subTest(content=content):
                spec['acceptance']['evidence'] = self.ref(d, 'delivery.json', content)
                self.assertEqual(C.validate(spec, d)['status'], 'INCOMPLETE')

    def test_text_named_png_is_not_visual_evidence(self):
        d, spec = self.clean()
        ref = spec['views'][0]; Path(ref['path']).write_bytes(b'not an image')
        ref['sha256'] = C.file_hash(ref['path'])
        self.assertEqual(C.validate(spec, d)['status'], 'FAIL')

    def test_cannot_relabel_file_verification_as_live(self):
        d, spec = self.clean(); spec['publication']['level'] = 'LIVE_VERIFIED'
        self.assertEqual(C.validate(spec, d)['status'], 'FAIL')
        ref = spec['publication']['evidence']; data = C.read(ref['path']); data['level'] = 'LIVE_VERIFIED'
        Path(ref['path']).write_text(json.dumps(data)); ref['sha256'] = C.file_hash(ref['path'])
        self.assertEqual(C.validate(spec, d)['status'], 'INCOMPLETE')

    def test_changed_source_or_parent_invalidates_receipt(self):
        parent = self.receipt('geometry'); p = self.receipt('clean', parent)
        (parent.parent / 'mesh.bin').write_bytes(b'altered')
        self.assertEqual(C.load_validate(p, receipt=True)[1]['status'], 'FAIL')

    def test_same_write_is_idempotent_different_write_refused(self):
        p = self.receipt('geometry'); before = p.read_bytes()
        self.assertEqual(C.write(p.parent / 'spec.json', p)['status'], 'PASS')
        self.assertEqual(p.read_bytes(), before)
        data = C.read(p); data['revision'] = 'different'
        with self.assertRaises(ValueError):
            C.atomic_new(p, data)

    def test_receipt_tampering_detected(self):
        p = self.receipt('geometry'); data = C.read(p); data['revision'] = 'old'
        p.write_text(json.dumps(data))
        self.assertEqual(C.load_validate(p, receipt=True)[1]['status'], 'FAIL')

    def test_real_cli_returns_incomplete_and_writes_nothing(self):
        d, spec = self.clean(); spec['checks'] = []
        out = d / 'CHECKPOINT.json'
        run = subprocess.run([sys.executable, str(SCRIPTS / 'checkpoint.py'), 'write', str(self.save(d, spec)), '--out', str(out)], capture_output=True)
        self.assertEqual(run.returncode, 2); self.assertFalse(out.exists())


if __name__ == '__main__':
    unittest.main()
