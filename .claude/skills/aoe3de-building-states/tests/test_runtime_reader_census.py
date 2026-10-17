"""Audit 2026-10-13-codex-roof-pattern-80; INC-334."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import numpy as np

p=Path(__file__).resolve().parents[1]/'scripts/runtime_reader_census.py'
s=importlib.util.spec_from_file_location('census',p); C=importlib.util.module_from_spec(s);s.loader.exec_module(C)


class CensusTests(unittest.TestCase):
    def mesh(self):
        return dict(name='two groups',tris=np.array([[0,1,2],[0,2,3]]),
            uv=np.array([[0,0],[1,0],[1,1],[0,1.]]),pos=np.zeros((4,3)),
            bone=np.array([0,1,1,0]),bone_names=['a','b'],
            mats=['protected','roof'],groups=[(1,0,1),(0,1,1)])

    def test_material_indices_not_group_order(self):
        mesh=self.mesh(); a,rows=C.collect({'render':[mesh]},{'protected':{},'roof':{}})
        self.assertEqual(a['material'].tolist(),['roof','protected'])
        self.assertEqual(a['triangle'].tolist(),[0,1])
        self.assertEqual(a['bone'].tolist(),[[0,1,1],[0,1,0]])
        self.assertEqual(rows[0]['bone_names'],['a','b'])

    def test_uncovered_triangle_refused(self):
        mesh=self.mesh();mesh['groups']=[(0,0,1)]
        with self.assertRaisesRegex(ValueError,'Uncovered'): C.collect({'render':[mesh]},{'protected':{}})

    def test_duplicate_reader_assignment_refused(self):
        mesh=self.mesh();mesh['groups']=[(0,0,2),(1,0,1)]
        with self.assertRaisesRegex(ValueError,'multiply'): C.collect({'render':[mesh]},{'protected':{},'roof':{}})

    def test_missing_material_refused(self):
        with self.assertRaisesRegex(ValueError,'Missing material'): C.collect({'render':[self.mesh()]},{'protected':{}})

    def test_missing_uv_refused(self):
        mesh=self.mesh();mesh['uv']=None
        with self.assertRaisesRegex(ValueError,'Missing/nonfinite UV'): C.collect({'render':[mesh]},{})


MATERIAL = '''<material>
  <submaterial name="{a}"><materialdef name="default" />
    <parameters><texture name="BaseColor" override="buildings\\x\\x_matA_BaseColor" /></parameters></submaterial>
  <submaterial name="{b}"><materialdef name="default_doublesided_cutout" /><parameters /></submaterial>
  <submaterial name="matD"><materialdef name="default" /><parameters /></submaterial>
</material>
'''


class CaseInsensitiveBindingTests(unittest.TestCase):
    """Audit 2026-10-17-claude-opus-5.5 harness-fixes-02: vanilla japan_consulate_age2.material
    declares matA/matB/matC, its GR2 binds mata/matb/matc; the game renders it textured."""

    def bindings(self, a='Protected', b='ROOF'):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'x.material'
            path.write_text(MATERIAL.format(a=a, b=b), encoding='utf-8')
            return C.material_bindings(path, Path(d))

    def test_bound_spelling_used_and_declared_name_kept(self):
        mesh = CensusTests.mesh(self)
        bound = C.match_bindings({'render': [mesh]}, self.bindings())
        self.assertEqual(list(bound), ['protected', 'roof', 'matD'])
        self.assertEqual(bound['protected']['declared_name'], 'Protected')
        self.assertEqual(bound['roof']['shader'], 'default_doublesided_cutout')
        self.assertNotIn('declared_name', bound['matD'])  # declared, never bound: own spelling
        a, _ = C.collect({'render': [mesh]}, bound)
        self.assertEqual(a['material'].tolist(), ['roof', 'protected'])

    def test_exact_spelling_unchanged(self):
        bound = C.match_bindings({'render': [CensusTests.mesh(self)]}, self.bindings('protected', 'roof'))
        self.assertNotIn('declared_name', bound['protected'])
        self.assertEqual(bound['protected']['textures']['BaseColor']['source'], 'archive_or_unresolved')

    def test_names_equal_up_to_case_refused(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate material name .*matA, mata'):
            self.bindings('matA', 'mata')

    def test_still_missing_when_no_case_variant_declared(self):
        mesh = CensusTests.mesh(self); mesh['mats'] = ['protected', 'roof2']
        with self.assertRaisesRegex(ValueError, 'Missing material binding: roof2'):
            C.collect({'render': [mesh]}, C.match_bindings({'render': [mesh]}, self.bindings()))


PASS_KEYS = {'schema', 'status', 'source_file', 'source_sha256', 'material_file', 'material_sha256', 'decoder',
             'decoder_sha256', 'script_sha256', 'dll', 'meshes', 'bindings', 'triangles_by_material',
             'triangle_count', 'arrays_sha256', 'conventions', 'limitations', 'audit', 'seconds'}


class FakeDecoder:
    """Stands in for gr2_lint: an uncompressed model whose one mesh binds `mats`."""
    def __init__(self, mats):
        self.mats = mats

    def header(self, path):
        return {'compressed': False}

    def load(self, path, dll):
        mesh = CensusTests.mesh(None); mesh['mats'] = self.mats
        return {'header': {'crc_ok': True}, 'render': [mesh], 'source': 'fake'}


class FailureRecordTests(unittest.TestCase):
    """Audit 2026-10-17-claude-opus-5.5 census-failure-record-01; INC-386: a failed census
    left an empty --out folder and only a stderr traceback."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        d = Path(self.tmp.name)
        self.model = d / 'x.gr2'; self.model.write_bytes(b'not decoded: FakeDecoder')
        self.material = d / 'x.material'; self.material.write_text(MATERIAL.format(a='Protected', b='ROOF'))
        self.out = d / 'out'

    def run_main(self, mats, model=None):
        argv = ['census', '--model', str(model or self.model), '--material', str(self.material),
                '--art-root', self.tmp.name, '--out', str(self.out)]
        with mock.patch.object(C, 'L', FakeDecoder(mats)), mock.patch.object(sys, 'argv', argv), \
                contextlib.redirect_stdout(io.StringIO()):
            C.main()

    def record(self):
        return json.loads((self.out / 'CENSUS.json').read_text())

    def test_failure_writes_record_and_reraises(self):
        with self.assertRaisesRegex(ValueError, 'Missing material binding: roof2'):
            self.run_main(['protected', 'roof2'])
        r = self.record()
        self.assertEqual((r['schema'], r['status'], r['error_type'], r['error']),
                         (1, 'FAILED', 'ValueError', 'Missing material binding: roof2'))
        self.assertEqual(r['source_sha256'], C.sha(self.model))
        self.assertEqual(r['material_sha256'], C.sha(self.material))
        self.assertEqual(r['script_sha256'], C.sha(C.__file__))
        self.assertIn('INC-386', r['audit'])
        self.assertIn('collect', ''.join(r['traceback']))
        self.assertEqual(r['partial_outputs'], [])
        self.assertEqual(sorted(p.name for p in self.out.iterdir()), ['CENSUS.json'])

    def test_failure_before_hashing_records_none(self):
        with self.assertRaises(FileNotFoundError):
            self.run_main(['protected', 'roof'], model=self.model.with_name('missing.gr2'))
        r = self.record()
        self.assertEqual((r['status'], r['error_type']), ('FAILED', 'FileNotFoundError'))
        self.assertIsNone(r['source_sha256']); self.assertIsNone(r['material_sha256'])
        self.assertEqual(r['script_sha256'], C.sha(C.__file__))

    def test_success_unchanged(self):
        self.run_main(['protected', 'roof'])
        r = self.record()
        self.assertEqual(set(r), PASS_KEYS)
        self.assertEqual((r['status'], r['triangle_count'], r['audit']),
                         ('PASS', 2, '2026-10-13-codex-roof-pattern-80; INC-334'))
        self.assertEqual(r['triangles_by_material'], {'protected': 1, 'roof': 1})
        self.assertEqual(r['arrays_sha256'], C.sha(self.out / 'READERS.npz'))
        self.assertEqual(np.load(self.out / 'READERS.npz')['material'].tolist(), ['roof', 'protected'])

    def test_existing_out_refused_and_kept(self):
        self.out.mkdir(); (self.out / 'CENSUS.json').write_text('prior census\n')
        with self.assertRaisesRegex(ValueError, 'Output already exists; retain prior census'):
            self.run_main(['protected', 'roof2'])
        self.assertEqual((self.out / 'CENSUS.json').read_text(), 'prior census\n')
        self.assertEqual(sorted(p.name for p in self.out.iterdir()), ['CENSUS.json'])

    def test_cli_failure_exits_nonzero_with_record(self):
        missing = self.model.with_name('missing.gr2')
        run = subprocess.run([sys.executable, str(p), '--model', str(missing), '--material', str(self.material),
                              '--art-root', self.tmp.name, '--out', str(self.out)], capture_output=True, text=True)
        self.assertEqual(run.returncode, 1)
        self.assertIn('FileNotFoundError', run.stderr)
        self.assertEqual(json.loads(run.stdout)['status'], 'FAILED')
        self.assertEqual(self.record()['error_type'], 'FileNotFoundError')


if __name__=='__main__':unittest.main()
