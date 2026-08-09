---
name: map-profile
description: Author or edit a map profile (scripts/maps/<stem>.json) - the single source of truth for one map's verified weirdnesses - water depth overrides, terrain class expectations, template test instances, known-issue suppressions. Use when recording an in-game verification, suppressing a false-positive mapcheck finding, or adding map-specific tests. Triggers on "map profile", "known issue", "override the depth", "record this verification", "suppress this finding".
---

# map-profile: one JSON per map, evidence first

The schema lives at `scripts/maps/schema.md` — read it before editing.
The loader (`scripts/mapcheck/profile.py`) rejects unknown keys and any
override that does not cite an evidence entry, and an invalid profile is
a P0 FAIL on every run of that map. Validate after every edit:

```bash
python -m scripts.mapcheck <stem> --static-only    # P0 shows immediately
python -m scripts.mapcheck <stem> --matrix         # full effect
```

## The rule that makes profiles trustworthy

**No evidence, no entry.** The workflow is always:

1. Observe the weirdness (a finding, a render mismatch, a hunch).
2. Verify IN-GAME (or cite a guide line / measurement). No verification →
   no profile entry; leave the finding open instead.
3. Add an `evidence` entry: id, date, source (`in-game | guide |
   measurement`), one-sentence claim, ref.
4. Add the override / expectation / known_issue referencing that id.
5. Run mapcheck; commit the profile together with the findings change.

Worked example — `scripts/maps/zp_z_z_zcivilwar2.json`: the user verified
in-game that the river fords are walkable-buildable; that became evidence
`ford-walkable-2026-08-09`, two `expectations` probes (ford SHALLOW at
[0.87, 0.556], channel DEEP at [0.5, 0.5]), and the harbours' route-offset
model artifact became a `known_issues` entry citing play evidence.

## What goes where

- **overrides.water_depth_m** — pins a water body's carved depth for THIS
  map's grid build (flows into mapsim via `waterdata.depth_overrides`).
  v1 has no other override kinds; do not invent keys.
- **expectations** — class probes ([x_frac, z_frac] must be LAND /
  SHALLOW / DEEP / CLIFF). Regression locks for verified terrain facts.
- **tests** — instances of registered templates
  (`scripts/mapcheck/templates/`: `player_spawn_complete`,
  `grouping_spawn_complete`, `area_class_probe`). A concern with no
  matching template means: generalize a NEW template into the registry
  first, then instantiate it — never write per-map check code.
- **known_issues** — demote a finding (check id + message substring) to
  a visible `[known: why]` INFO. For model false-positives on maps
  verified in-game, and for accepted quirks. Re-triage entries marked
  "re-triage" whenever the simulator improves.

## Hard DON'Ts

- No override without a resolvable evidence id (the loader enforces it).
- No new schema keys, no per-map Python, no editing checker thresholds to
  make one map pass.
- No known_issue for something you suspect is a REAL map bug — fix the
  map instead.
- Never delete evidence entries that overrides still reference.
