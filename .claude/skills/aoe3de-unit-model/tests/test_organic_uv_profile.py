"""The AoE3 unit-body gate profile for blender-organic-uv (pure Python; no game install, no Blender, CI-safe).

    python -B -m pytest .claude/skills/aoe3de-unit-model/tests/test_organic_uv_profile.py -q -p no:cacheprovider

Checks the profile's shape, that every metric path is one the generic evaluator writes (the generic template lists
them), and pins the documented evidence: the H1 rider of 2026-10-11 passes every hard limit and misses exactly the
visible-density and head-ratio targets (references/organic-uv-reference.md, section 6).
"""
import json
import sys
from pathlib import Path

PKG = Path(__file__).resolve().parents[1]
GENERIC = PKG.parent / 'blender-organic-uv'
sys.path.insert(0, str(GENERIC / 'scripts'))
import uv_gates as G  # noqa: E402

PROFILE = json.loads((PKG / 'profiles' / 'organic_uv_unit_body_1024.json').read_text(encoding='utf-8'))
TEMPLATE = json.loads((GENERIC / 'profiles' / 'template_unit_body.json').read_text(encoding='utf-8'))

H1_PAGE = {'flips': {'flipped_faces': 0, 'mirrored_islands': 0},
           'overlaps': {'self_fold_px2': 0.0, 'unintended_px2': 0.0, 'declared_mirror_px2': 0.0},
           'packing': {'min_island_gap_px': 16.5, 'min_page_border_px': 11.25, 'coverage_texels': 0.6026},
           'distortion': {'L2_stretch': 1.0257, 'Linf_stretch': 1.8132, 'angular_aniso_mean': 1.1227,
                          'angular_aniso_p90': 1.2979},
           'texel_density': {'all': {'p50': 372.3}, 'visible_weighted': {'p10': 344.9}},
           'counts': {'gpu_vertices_all_uv_layers': 899},
           'orientation': {'upright_share_15deg': 1.0}, 'symmetry': {'density_log2_asym_mean': 0.0}}
H1_BODY = {'seams': {'seam_per_sqrt_area': 5.5494, 'visible_mean_per_sqrt_area': 0.8674},
           'counts': {'uv_split_ratio': 1.2385}, 'islands': {'count': 15, 'tiny_count': 0},
           'bone_regions': {'head_torso': 1.1192, 'head_torso_visible': 1.2714}}


def test_profile_shape():
    assert PROFILE['schema'] == G.SCHEMA and PROFILE['date'] == '2026-10-11'
    ids = [c['id'] for c in PROFILE['checks']]
    assert len(ids) == len(set(ids))
    for c in PROFILE['checks']:
        assert c['run'] in PROFILE['runs'] and c.get('evidence')
        assert c['hard'] or c['target'] or c['evidence'].startswith('information')


def test_metric_paths_are_the_evaluators():
    known = {c['metric'] for c in TEMPLATE['checks']}
    assert {c['metric'] for c in PROFILE['checks']} <= known


def test_h1_evidence_is_pinned():
    r = G.evaluate(PROFILE, {'page': H1_PAGE, 'body': H1_BODY})
    assert r['hard_pass']
    assert sorted(r['targets_missed']) == ['density_visible_p10', 'head_torso']
    worse = dict(H1_PAGE, packing=dict(H1_PAGE['packing'], min_island_gap_px=7.9))
    assert not G.evaluate(PROFILE, {'page': worse, 'body': H1_BODY})['hard_pass']
