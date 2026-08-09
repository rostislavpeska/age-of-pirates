# Map profile schema v1

One JSON file per map: `scripts/maps/<stem>.json`, where `<stem>` is the
`.xs` file stem (`zptortuga`, `zp_z_z_zcivilwar2`, `000_independence_war`).
The profile is the SINGLE SOURCE OF TRUTH for a map's verified weirdnesses
(plan_mapsim_architecture.md Parts D and G3). Loader/validator:
`scripts/mapcheck/profile.py` — unknown keys are hard errors, and every
override must cite an evidence entry (no evidence, no override).

Consumed by BOTH tools: mapcheck (expectations, tests, known_issues) and
the mapsim grid build (overrides, via `waterdata.depth_overrides`).

## Fields (all optional except `map` and `version`)

```jsonc
{
  "map": "zp_z_z_zcivilwar2",     // MUST equal the file stem
  "version": 1,                   // schema version, MUST be 1
  "script": "install:RandMaps/zp_z_z_zcivilwar2.xs",  // doc-only pointer
  "notes": "free text",

  // The evidence ledger. Every override (and optionally expectations /
  // known_issues) points here by id. source: in-game | guide | measurement.
  "evidence": [
    {"id": "ford-walkable-2026-08-09", "date": "2026-08-09",
     "source": "in-game",
     "claim": "what was verified, one sentence",
     "ref": "where to find it (session, screenshot, guide line)"}
  ],

  // Data overrides applied during the map's grid build. v1: water depths.
  "overrides": {
    "water_depth_m": {
      "ZP Mississippi River": {"value": 1.5,
                               "evidence": "ford-walkable-2026-08-09"}
    }
  },

  // Class probes: point (x_frac, z_frac) must classify as stated. These
  // are regression locks for verified terrain facts.
  "expectations": [
    {"probe": [0.87, 0.556], "class": "SHALLOW",
     "why": "east river ford", "evidence": "ford-walkable-2026-08-09"}
  ],

  // Template instances (registry: scripts/mapcheck/templates/). A map-
  // specific concern is ALWAYS template + params, never per-map code.
  "tests": [
    {"template": "player_spawn_complete",
     "params": {"spawn_classes": ["LAND", "SHALLOW"]},
     "why": "what regression this guards"}
  ],

  // Finding suppression: matching findings are demoted to INFO and
  // labeled "[known: why]" — visible in every report, absent from the
  // CI gate. check = the finding's check id; match = message substring.
  "known_issues": [
    {"check": "SIM:ROUTE_TOO_FAR", "match": "harbour",
     "why": "harbours dock in-game; model overestimates the offset",
     "evidence": "played-2026-08-09"}
  ]
}
```

## Guard rails (enforced by the loader)

1. Unknown key anywhere -> profile invalid -> `P0 FAIL` on every run.
2. `overrides.*` entry without a resolvable `evidence` id -> invalid.
3. `known_issues` need a `why`; suppression is always visible as INFO.
4. Only `water_depth_m` overrides exist in v1. New override kinds require
   a schema bump + loader support — never ad-hoc keys.

## Promotion workflow

observe weirdness -> verify IN-GAME -> add `evidence` entry -> add the
override/expectation/known_issue referencing it -> run
`python -m scripts.mapcheck <stem> --matrix` -> commit profile + findings.
