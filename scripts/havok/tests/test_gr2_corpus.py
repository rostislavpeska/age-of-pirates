"""The gr2_lint defect corpus (fixtures/gr2_specimens.json): every in-game defect model fails exactly its checks.

    python -m pytest scripts/havok/tests/test_gr2_corpus.py -q

Why a manifest: 5 of the gr2_lint tests read these files from a session temp folder and SKIP when it is cleared - a
lint that silently stops being tested. Here a changed file FAILS (sha256), a missing one skips with "specimen missing"
(not in tasks/allowed_skips.json, so run_all_tests.py turns red), and each specimen must fail exactly the checks the
manifest lists: a check that stops firing, or starts firing on a defect it never covered, both show.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

import test_gr2_lint as T

MANIFEST = json.loads((Path(__file__).parent / "fixtures" / "gr2_specimens.json").read_text(encoding="utf-8"))
SPECS = MANIFEST["specimens"]


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def test_manifest_is_well_formed():
    ids = [s["id"] for s in SPECS]
    assert len(ids) == len(set(ids)) == 4
    for s in SPECS:
        assert len(s["sha256"]) == 64 and s["stage"] in ("intact", "damaged") and s["fails"] and s["defect"]
        assert not Path(s["file"]).is_absolute() and ".." not in Path(s["file"]).parts


@pytest.mark.parametrize("spec", SPECS, ids=[s["id"] for s in SPECS])
def test_specimen_is_the_recorded_file(spec):
    p = T.SPEC / spec["file"]
    T.need(p)
    assert sha256(p) == spec["sha256"], f"{p} changed: a specimen is evidence, never rebuilt in place"


@pytest.mark.parametrize("spec", [s for s in SPECS if not s.get("dll")], ids=[s["id"] for s in SPECS if not s.get("dll")])
def test_specimen_fails_exactly_its_checks(spec):
    p = T.SPEC / spec["file"]
    T.need(p)
    kw = {"damaged": str(p)} if spec["stage"] == "damaged" else {"intact": str(p), "damaged": None, "hkt": None}
    res = T.run(**kw)
    # KTC-165: the texture ceiling and the UV density floor judge the shipped .material pages (3 sets, the matc hidden
    # page), not the defect each specimen was kept for; every Korean TC build fails them (test_gr2_lint.py pins how)
    for stage in {spec["stage"], "intact"} & {s for s, _ in res}:
        assert all(res[(stage, c)]["status"] == "FAIL" for c in T.TEXTURE_GATES if (stage, c) in res), stage
    fails = sorted(c for (s, c), r in res.items() if s == spec["stage"] and r["status"] == "FAIL"
                   and c not in T.TEXTURE_GATES)
    assert fails == sorted(spec["fails"]), {c: res[(spec["stage"], c)]["summary"] for c in set(fails) ^ set(spec["fails"])
                                            if (spec["stage"], c) in res}
    other = [f"{s}:{c}" for (s, c), r in res.items() if s != spec["stage"] and r["status"] == "FAIL"
             and c not in T.TEXTURE_GATES]
    assert other == [], other                      # the installed intact model linted alongside still passes
