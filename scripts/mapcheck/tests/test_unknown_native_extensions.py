"""Guard tests: the Unknown switches every native extension on for every player, unconditionally.

Owner 2026-10-28: "We can clearly activate all these bonus natives techs at once. It will not break anything and when
the bonus natives spawn, they spawn." The Maya flip had sat inside `if (bourbonAlliance != 1)` since 0ca200db
(2025-06-22, the old zpBonusBourbon loop reused), so the extended Maya stayed vanilla in every game that rolled the
Bourbon alliance - and in every game once the beta rig forced it. Habsburg is the one deliberate split
(habsburgSpawn picks zpSpanishHabsburgs or zpAustrianHabsburgs together with its grouping pool) and is not covered here.
"""
import re
from pathlib import Path
import pytest

REPO = Path(__file__).parents[3]
UNKNOWN = REPO / "game/randmaps/zpunknown.xs"
LOOP = "\tfor(i=1; <= cNumberNonGaiaPlayers) {"
EXTENSIONS = ("zpExtendMaya", "zpExtendedInuits", "zpExtendedPhanar", "zpExtendedStuart", "zpExtendedBourbons")


def _lines():
    return UNKNOWN.read_text(encoding="utf-8").splitlines()


@pytest.mark.parametrize("tech", EXTENSIONS)
def test_extension_flipped_for_every_player_unguarded(tech):
    lines = _lines()
    at = [i for i, l in enumerate(lines) if 'rmGetTechID("%s")' % tech in l]
    assert len(at) == 1, (tech, [i + 1 for i in at])
    i = at[0]
    assert lines[i - 2] == LOOP, (tech, i - 1, lines[i - 2])   # a main-scope per-player loop, one tab deep
    assert lines[i - 1].strip() == 'rmAddTriggerEffect("Set Tech Status");'
    assert lines[i + 2].strip() == 'rmSetTriggerEffectParamInt("Status", 2);'
    before = next(l for l in reversed(lines[:i - 2]) if l.strip())
    assert not re.match(r"\s*(if|else)\b", before), (tech, before)   # no condition right above the loop


def test_maya_extension_data_chain():
    t = (REPO / "data/techtreemods.xml").read_text(encoding="utf-8")
    ext = re.search(r'<tech name="zpExtendMaya".*?</tech>', t, re.S).group(0)
    assert re.search(r'<effect type="CommandAdd" tech="zpNatMayaInfluence" page="1" column="1">\s*'
                     r'<target type="ProtoUnit">TradingPost</target>', ext)
    hub = re.search(r'<tech name="NativeMaya">.*?</tech>', t, re.S).group(0)
    assert re.search(r'status="obtainable">zpNatMayaInfluence<', hub)


@pytest.mark.local("steam")
def test_root_twin_matches(steam_twin):
    steam_twin(UNKNOWN, "0zpunknown.xs")
