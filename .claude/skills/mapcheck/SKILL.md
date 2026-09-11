---
name: mapcheck
description: Run and read the automatic map test suite (scripts/mapcheck) for random map scripts - static validity, name catalogs, terrain-grid playability, per-map profile tests. Use when asked to "test a map", "check a map", "validate map names", diagnose spawn/crash issues on a map, or before shipping map changes. Triggers on "mapcheck", "test the map", "map findings", "is the map playable".
---

# mapcheck: automatic map testing

Never assert results from memory — run the command and read its output.

## Commands (from the repo root)

```bash
# one map, default P2T2 scenario
python -m scripts.mapcheck zptortuga

# the community-standard player-count sweep (P2T2, P4T2, P8T8)
python -m scripts.mapcheck 000_independence_war --matrix

# fast static-only pass (parse, names, files; no simulator)
python -m scripts.mapcheck zpaustralia --static-only

# machine-readable findings
python -m scripts.mapcheck zptortuga --json findings.json
```

Bare names resolve across BOTH roots: the mod (`game/randmaps/`) and the
game install (`<AoE3DE>/Game/RandMaps/`, where the development maps live).
Exit codes: 0 clean, 1 FAIL present, 2 checker crash. `--strict` also
fails on WARN.

Suites, when touching the checker itself:
`python -m pytest scripts/mapcheck/tests scripts/refdata/tests -q`
(add `-m "not slow"` to skip full-map runs).

## Reading findings

`SEVERITY CHECK map:line [scenario] message (evidence-ref)`

- **FAIL** gates CI; **WARN** needs a human look; **INFO** is context.
- **basis=deterministic** (S-tier, files, catalogs, golden diffs) is fact.
  **basis=model** (G-tier, SIM:*, T:*) is the mapsim terrain model —
  correct to its calibration, not engine ground truth.
- `[known: why]` prefix = a FAIL/WARN demoted to INFO by the map's profile
  (`scripts/maps/<stem>.json` known_issues). Visible on purpose.

Check id map: S1 parse / S2 duplicate vars / S3 terrain-init / S4 names
(water, proto, grouping — includes prefix-variant grouping resolution and
machine-local-path detection) / S5 companion files / G1 golden digest /
G2 player anchors / G5 reachability / SIM:* mapsim verdict engine /
T:* profile templates / P0 invalid profile. Evidence base:
docs/random_map_generation_guide_v2.md ch.21 and
docs/plan_mapsim_architecture.md Part F.

## Triage ladder — every FAIL lands in exactly one bucket

1. **Real map bug** → fix the .xs (or .xml), rerun until clean.
   Typical: S4 unknown name (typo — the message suggests the nearest
   real name), S2 duplicate variable, S5 missing companion file.
2. **Engine behavior verified in-game** → record it in the map's profile
   (see the `map-profile` skill): evidence entry + expectation/override/
   known_issue. NEVER suppress without an in-game verification.
3. **Simulator gap** → the model is wrong; fix scripts/mapsim (with the
   evidence-first discipline), never paper over it with a profile entry.

If a FAIL could be bucket 2 or 3, it stays OPEN — say so explicitly.

## Caveats

- Extraction follows one branch per scenario: content gated to other
  player counts is only seen by `--matrix`; content behind runtime
  randomness may be missed entirely (reported as extractor warnings).
- Goldens (`scripts/maps/goldens/<stem>_P#T#.json`) lock the EXTRACTION
  path; `scripts/mapsim/tests/goldens/` lock the curated-scene path.
  They are not interchangeable. Regenerate a golden only for a
  deliberate, reviewed map change.
