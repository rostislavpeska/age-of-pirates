"""AoP stays free of the Koreans civ.

The Koreans add-on is a separate mod and repository, ../age-of-pirates-koreans, and the single source of truth for
every Korean civ record, tool and test (owner 2026-10-08: "One source of truth", "NEVER TWO"). AoP keeps no copy,
no source folder and no export of it. TEMPORARY rule (owner 2026-10-09, AGENTS.md 15): ALL Korean content lives
there, the Korean building models, the shared Korean atlas, the 3D test benches, their sounds and test maps
included, until the owner orders the merge. Exception: zpKoreanBombard and the Korean soldier voices it uses.
"""
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
CIV_NAMES = ('zpKoreans', 'zpAge0Korean', 'zpKoreanVisuals', 'zpKoreanBuildings', 'zpKoreanHouseArrows',
             'zpHouseKorean', 'zpKoreanVillager', '_locid="60000')


def test_no_korean_civ_record_in_aop_data():
    for rel in ('data/civmods.xml', 'data/protomods.xml', 'data/techtreemods.xml',
                'data/strings/english/stringmods.xml', 'sound/soundsetsde.mods.xml'):
        text = (REPO / rel).read_text(encoding='utf-8')
        for word in CIV_NAMES:
            assert word not in text, (rel, word)


def test_no_second_copy_of_the_korean_add_on():
    for rel in ('koreans', 'data/homecityzpkoreans.xml', 'scripts/tools/export_koreans.py',
                'scripts/tools/korean_visuals.py',
                # the add-on's merged animfiles would replace every civ's buildings for AoP players
                'art/buildings/town_center/town_center.xml', 'art/buildings/asian_civs/bansho/bansho.xml',
                'art/buildings/asian_civs/stable/stable.xml'):
        assert not (REPO / rel).exists(), rel


KOREAN_ART = ('art/buildings/korean_tc', 'art/buildings/korean_shared', 'art/buildings/korean_tc_experiment',
              'art/zbench_korean_military')
KOREAN_BENCHES = ('zpKoreanTownCenterTest', 'zpChineseTownCenterControl', 'zzKoreanBarracksPhysics',
                  'zzJapaneseBarracksPhysics', 'zzKoreanStablePhysics', 'zzJapaneseStablePhysics', 'zzTESTKoreanBuilderWagon')


def test_no_korean_building_content_in_aop():
    """temporary rule (2026-10-09): the Korean models, atlas and benches live in ../age-of-pirates-koreans"""
    for rel in KOREAN_ART:
        assert not (REPO / rel).exists(), rel
    proto = (REPO / 'data/protomods.xml').read_text(encoding='utf-8')
    for name in KOREAN_BENCHES:
        assert f'name="{name}"' not in proto, name
    for rel in ('sound/zpkoreantowncentertest_snds.xml', 'sound/zpchinesetowncentercontrol_snds.xml',
                'sound/zztestkoreanbuilderwagon_snds.xml', 'data/tactics/test_korean_builder.tactics'):
        assert not (REPO / rel).exists(), rel


def test_the_bombard_exception_stays_in_aop():
    """owner 2026-10-09: zpKoreanBombard is AoP gameplay, with the Korean soldier voices it uses"""
    assert 'name="zpKoreanBombard"' in (REPO / 'data/protomods.xml').read_text(encoding='utf-8')
    assert (REPO / 'sound/korean').is_dir()
