"""Cached-source extraction/normalization and identity failure controls, INC-564."""
import json,tempfile,unittest
from pathlib import Path
import numpy as np
from replay_saved_pages import replay,sha
from test_mixed_pages import pages


class SavedReplayTests(unittest.TestCase):
    def test_real_consumer_path_and_hash_bound_whole_chart_scope(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t);source=root/'source.blend';source.write_bytes(b'saved specimen')
            actual=root/'ACTUAL.json'
            rows=[dict(face='wall#0',uv_chart=0,resource=0,material_sha256='wall',
                uv=[[0,0],[.2,0],[.2,.2],[0,.2]],points=[[0,0,0],[2,0,0],[2,2,0],[0,2,0]]),
                dict(face='wall#1',uv_chart=0,resource=0,material_sha256='wall',
                uv=[[.2,0],[.4,0],[.4,.2],[.2,.2]],points=[[2,0,0],[4,0,0],[4,2,0],[2,2,0]])]
            actual.write_text(json.dumps(dict(source_inputs=dict(source_sha256=sha(source)),faces=rows)))
            d=dict(source_sha256=sha(source),actual_sha256=sha(actual),faces=['wall#0','wall#1'],
                source_sizes={'0':2048},materials={'wall':dict(opacity='opaque',channels=['color','normal'],binding='wall')},
                pages=pages(),authority='fixture contract')
            out=replay(actual,source,d,92.,8.)
            self.assertEqual(out['status'],'PROPOSAL_ONLY')
            self.assertFalse(out['dependencies_present'])
            for row in out['faces'].values():
                q=np.array(row['uv'])*1024
                self.assertAlmostEqual(np.linalg.norm(q[1]-q[0]),184.)
                self.assertAlmostEqual(np.linalg.norm(q[2]-q[1]),184.)
            d['faces']=['wall#0']
            with self.assertRaisesRegex(ValueError,'fragments'):
                replay(actual,source,d,92.,8.)
            source.write_bytes(b'changed specimen')
            with self.assertRaisesRegex(ValueError,'identity'):
                replay(actual,source,d,92.,8.)


if __name__=='__main__':unittest.main()
