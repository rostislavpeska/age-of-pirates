import tempfile, unittest
from pathlib import Path

import journal as J


class JournalTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.f = Path(self.tmp.name) / 'j.jsonl'

    def tearDown(self):
        self.tmp.cleanup()

    def rec(self, agent='claude', kind='correction', **kw):
        base = dict(stage='atlas', skills='aoe-uv-atlas-export', lesson='Keep one density.',
                    evidence='S18c p10 107', date='2026-09-28', path=self.f)
        base.update(kw)
        return J.add(agent, kind=kind, **base)

    def test_ids_never_collide_between_agents(self):
        a, b, c = self.rec('claude'), self.rec('astra'), self.rec('claude')
        self.assertEqual([a['id'], b['id'], c['id']],
                         ['2026-09-28-claude-01', '2026-09-28-astra-01', '2026-09-28-claude-02'])
        self.assertEqual(len(J.load(self.f)), 3)

    def test_validation(self):
        with self.assertRaises(ValueError):
            self.rec(kind='diary')
        with self.assertRaises(ValueError):
            self.rec(evidence='  ')
        with self.assertRaises(ValueError):
            self.rec(skills='no-such-skill')
        with self.assertRaises(ValueError):
            self.rec(repeats='missing-id')
        self.assertEqual(self.rec(skills='new:uv-nesting')['skills'], ['new:uv-nesting'])

    def test_digest_flags_corrections_and_repeats(self):
        first = self.rec(kind='idea')
        self.rec('astra', kind='idea', repeats=first['id'])
        self.rec(kind='measurement', skills='blender-uv-conjoin')
        text = J.digest(J.load(self.f))
        self.assertIn('## aoe-uv-atlas-export - 2 open - DISTILL CANDIDATE', text)
        self.assertIn('## blender-uv-conjoin - 1 open\n', text + '\n')

    def test_mark(self):
        r = self.rec()
        with self.assertRaises(ValueError):
            J.mark(r['id'], 'distilled', path=self.f)
        J.mark(r['id'], 'distilled', into='aoe-uv-atlas-export/SKILL.md', path=self.f)
        self.assertEqual(J.select(J.load(self.f), open_only=True), [])
        self.assertEqual(J.load(self.f)[0]['distilled_into'], 'aoe-uv-atlas-export/SKILL.md')


if __name__ == '__main__':
    unittest.main()
