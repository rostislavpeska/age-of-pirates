---
name: junction-testbed
description: Score DECLARED junctions of a Blender model - roof meets roof (valley, hip, cross-gable, L corner), beam or rail into a post or wall, deck seated on a wall, member through a roof - against an answer key, numerically, and render a close-up of every failing one. Measures gap, penetration (closed shells by winding number, single-sided roof sheets along their normals), members proud of their post, contact cover, inside-out shells and self-crossing n-gons, plus undeclared overlaps. Use to gate a generated building, to compare agents or fixes on fixed junction fixtures, or to re-check a historical defect.
---

# Junction test bed

A junction is two named part groups that must meet in a stated way. The builder never decides whether a joint is
good: an answer key states it, and `scripts/junction_check.py` measures it. Built on `blender-overlap-cleanup`
(`logic_qa.py` sampling, winding-number containment and protrusion depth; `shell_orientation.py`), imported, not
copied. Background Blender only; nothing is edited or saved.

## Answer key

```json
{"name": "L-plan roof valley",
 "scope": {"collection": "optional", "exclude": ["fnmatch"]},
 "junctions": [{"id": "valley", "a": "Roof.Wing*", "b": "Roof.Main*", "strategy": "constructed"}],
 "orientation": ["*"],
 "undeclared": {"scan": true, "max_pen": 0.01}}
```

Every part matched by `a` is judged against the `b` parts within `reach` (default .25 m). Strategies:

| Strategy | Meaning | Defaults |
|---|---|---|
| constructed | the parts share the seam; neither continues behind the other | gap .005, pen .005 |
| seated | one rests in/on the other at a stated seat depth | gap .005, pen = `max_pen` (required) |
| butt | a member ends against the other and stays within its faces | gap .005, pen .02, proud .005 |
| camouflaged | no modelled seam (a texture valley) | gap .02, pen .02 |

Optional per junction: `max_gap`, `max_pen`, `max_proud`, `min_cover` (share of a's faces facing b that touch it:
attachment, not a corner contact), `reach`. A pattern matching nothing, or `seated` without `max_pen`, is
INCONCLUSIVE and fails the report. Never widen a limit to pass: fix the generator or change the declared strategy,
and say so.

## Run

```text
blender -b FILE.blend --factory-startup --python scripts/junction_check.py -- --key KEY.json --out REPORT.json [--strict]
blender -b FILE.blend --factory-startup --python scripts/junction_shots.py -- --report REPORT.json --out DIR
python scripts/run_cases.py --cases CASES.json --roots ROOTS.local.json --out DIR [--shots] [--only ID ...]
```

`run_cases.py` runs many (blend, key, expected verdict) cases and prints one table; it exits 1 unless every case
matches its expectation, including the exact set of failing checks. Case lists and device roots belong to the
project that owns the models (`${NAME}` paths, roots in an ignored `*.local.json`). Close-ups (red = `a`, blue = `b`,
grey = context within 3 m, occluders hidden; RTS, grazing and pair-only views, verdict stamped in) are images: write
them outside every repository.

## Bench: eight junction fixtures

`fixtures/` holds eight small scenes, one per junction class that failed on real buildings: J1 T-plan gable valleys,
J2 crossed hip roofs, J3 hall roof ending against a tower, J4 gable boards under a curved roof, J5 beam into an angled
wall, J6 posts under a sloping veranda roof, J7 railing with a corner post, J8 cornice around a tower. Each has a
`key.json` and two briefs with the same sizes and part names: `brief.md` states the junction rules in words and
millimetres (with `BUILDER_RULES.md`), `brief_plain.md` asks for the scene the way an owner normally would, with no
junction rules (with `BUILDER_RULES_PLAIN.md`). The pair measures how much stating the junctions helps. A builder
gets one rules file plus briefs of one set and returns one bpy script per brief; in a baseline run it never runs the
checker.

```text
python scripts/run_bench.py --submissions DIR --out OUT [--builders NAME ...] [--only J1 ...] [--shots] [--expect PASS|FAIL]
```

`DIR/<builder>/J1.py ... J8.py`. Each script runs in an empty background scene (`build_runner.py`), is saved, checked
against its key and, with `--shots`, the failing junctions are rendered; one table (fixtures x builders) goes to
`OUT/BENCH.md`. Never keep worked solutions in this skill (builders can read skills): the project that owns the bench
keeps a reference solution that must PASS and a known-bad solution that must FAIL for every fixture, and reruns both
with `--expect` after any change to a key, a brief or the checker.

## Trust

A check is trusted only after it catches planted defects. `scripts/blender_test_junction_check.py` builds one
minimal scene per defect class (gap, penetration, proud rail, corner-only deck contact, overlapping and rotated roof
slabs, crossed and overshooting roof sheets, inside-out board, self-crossing outline, undeclared overlap, missing
part) that MUST fail, and designed joints that MUST pass:

```text
blender -b --factory-startup --python scripts/blender_test_junction_check.py
```

Run it after every change here or in `blender-overlap-cleanup`. Before relying on a new key, run it on a historical
model with a known, owner-reported defect (it must fail on exactly that junction) and on the repaired model (it
must pass).

## Pitfalls found while building it

- BVH `overlap()` misses two sheets that meet along a shared triangle diagonal: depth is measured on every touching
  pair, not only on reported crossings.
- Single-sided roof sheets have no inside. For `constructed`, everything of one sheet behind the other's drawn side
  is overlap (an untrimmed valley, a wing sliding under the main roof). Otherwise only a pass-through counts, so a
  rafter resting under a roof field is a contact.
- A roof sheet ending exactly on a wall face: the wall's samples on that face project onto the sheet's border and read
  as both in front of and behind it. Only points landing at least 1 mm inside a sheet's open border count.
- A sheet whose own edge ends inside a solid (roof run into a tower) overlaps by its buried depth; a sheet that
  continues past a solid on every side (post poking up through a roof) is passed through by the solid's reach.
  Mixing the two reported a 0.4 m overlap as 1.65 m, and hid a 2 cm post poke behind a near-zero sample.
- Rails have two ends: judge every post within reach (`all_b`), not only the nearest.
- Attachment is cover, not gap: a deck touching its wall frame at one corner has gap 0 and 6 % cover.
- Name the whole assembly a part meets (wall panels sit behind the band, sill and posts that carry a deck).
- A whole-building view hides small joints; the close-ups aim at the measured worst point.
