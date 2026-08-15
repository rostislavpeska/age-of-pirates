# zpistanbulb — Full Refactoring Plan

Status: PLAN, approved block-by-block. Base = BROKEN CHECKPOINT `a0005da2`.
Rule of the rebuild: **proven patterns only** — no construct, call shape, or
ordering that does not exist in the reference corpus.

Reference corpus (all measured, 2026-08-15):
- Build order: `zp_z_zparis.xs`, `zp_z_zflorence.xs`, `zp_z_verseilles.xs`
- Triggers/conversion: `000_independence_war.xs`, `zpcaribbeanwars.xs`, `zp_mediterranean.xs`
- Syntax corpus additionally: `000_blacksea.xs`, `0zpunknown.xs` (17k lines),
  vanilla `unknown.xs` (11.7k), `unknownLOST.xs` (9.3k)

---

## 1. TOXIC PATTERNS — CORRECTED 2026-08-15 (second audit)

FIRST AUDIT WAS WRONG: it scanned only the Game-folder `zp_z_*` variants and
missed the mod's OWN working maps (`randmaps/zpparis.xs` etc. — the user's
production code, Skirmish-proven). Re-measured against BOTH corpora:

| construct | mod-corpus uses | verdict |
|-----------|----------------|---------|
| `const int` | 35 (zpparis 26, zpflorence 9) | PROVEN — keep ours |
| `xsVectorSet` vectors | 129 | PROVEN — keep |
| helper default params | 7 (paris/florence/verseilles/crownlands) | PROVEN — keep |
| `for (int i = ...)` header decl | 2 (paris, florence) | PROVEN — keep |
| `continue;` | 2 (paris, florence) | PROVEN — keep |
| `xsArrayCreateVector/Bool` | 3 each (paris, florence) | PROVEN — keep |
| **`while (...)`** | **0 anywhere, either corpus** | **T1: replace ours (fillHouses) with bounded for/modulo** |

Also standing (behavioral, unchanged by this correction):
- T2 trigger-name law: create with spaces, look up with underscores, never
  reference an uncreated name.
- The `""+intVar` concat, negative literal args, break, bool locals, all our
  trigger effect/condition names: proven in both corpora.

LESSON RECORDED: pattern audits must include `randmaps/*.xs` (the mod's own
working maps) — they are the primary precedent, senior to zp_z_* variants.
Syntax was NOT the root cause of the conversion bugs; the behavioral defects
(sections 2-3) were.

## 2. ID ARCHITECTURE (the root cause of the conversion bugs)

**Law: every unit a trigger will ever target is a PLACED OBJECT DEF.**
`rmGetUnitPlaced` ids were correct in every measurement all week;
`rmGetGroupingInstanceUnitByType` under-reports by +4 (buildings/flags) and
+2 (nuggets) on this map (save-census 2026-08-15, both instances of every
class agree) and IW abandoned it map-wide ("returned garbage here").

Consequences for content:
- `IS_Resource_Block_All1`: factory building + guillotine nugget move OUT of
  the XML; map places `zpSPCCapturableFactoryFlorence` + `Nugget` defs at the
  authored offsets under the 516 latch (IW harbour idiom, its 303-320).
- `IS_Resource_Block_Menagere`: same for `zpSPCMenagerie` + nugget (98).
- `IS_SPC_Military(_N)`: capturable flag + nugget move out; defs under 520.
- Pirate camps already done this way (flags out, socket = flag+1 verified).
- Water forts already marker-anchored (`rmGetUnitPlaced` raw), convert
  by type — keep as is.
- ALL id derivations live in ONE block: after the last placement, before the
  first trigger (Paris consolidates ids at 51-52%, triggers start 53%).

## 3. CANONICAL SCRIPT ORDER (measured from Paris/Florence/Versailles)

Consensus first-occurrence order (% of file):
natives 1-2% -> mapsize/lighting/sea 1-10% -> classes (one block) 3-22% ->
generic constraints -> trade routes 6-16% -> scaffolds/areas/city ->
fixed groupings -> players 44-49% -> player-dependent blocks + houses ->
countryside/resources -> nugget latches at each placement -> consolidated
ids -> triggers 53/68/78% to end.

**Constraint philosophy (the split the plan must respect):**
- GENERIC constraints (type-distance, terrain-distance, pie/box, class-based
  on classes already defined): define ONCE, immediately after classes.
- AREA-TIED constraints (`rmCreateAreaDistanceConstraint`, class constraints
  on classes populated later): define immediately AFTER the area/class they
  reference exists — references do this all the way to 50-57% of the file.
- Constraint naming: every constraint name unique, descriptive, lowercase.

### Full build order for zpistanbulb

1. Native subcivs (Florence idiom, guarded `rmAllocateSubCivs(6)`)
2. General map settings: size, lighting, sea type/level, map type stack
3. Tunables (plain `int`/`float` knobs — no `const`)
4. Classes — ALL `rmDefineClass` in one block
5. Generic constraints block
6. Trade routes (hand-edited literals) + route controllers + measured lanes
7. Invisible island scaffolding — ALL scaffolds before any river
8. Rivers (all `shoreRiver` before any island placement)
9. Trade harbours (sockets as object defs + instance groupings; suspension
   ids come later from the id block)
10. Floating islands: guns, then pirates (camp + flag def pairs)
11. City terrain: city areas, cliffs, promenade, walls, wall-dock cliffs
12. Countryside terrain: terraces, filler, hinterland, camp islands (after
    final valley terrain — the proven camp law)
13. City block grid:
    a. block grid geometry (rows/pitch from measured lanes)
    b. constants + centre/suburb/back zone tables (plain ints, T6 form)
    c. block grouping definitions (one config loop, corpus loop form)
    d. city players (Florence filter -> rmPlacePlayer)
    e. player start blocks + constr blocks (fixed cells, before houses)
    f. fixed-position objects, instance-style where a baked nugget must be
       latched (fort, factory, menagerie SHELLS — capturables now placed
       as separate defs per section 2, right after each shell)
    g. other fixed objects (natives x4 with _N clones, bazaar/mosque/park)
    h. centre resources -> suburb resources (placeGroupings into zones)
    i. houses on top (the weave — rebuilt under T1/T2/T5/T6 rules)
14. Decorations: shoreline decos, lighthouses, deco lanterns
15. Countryside content:
    a. cossack camps (groupings; after valley terrain)
    b. countryside players (CommandPost kit)
    c. forests -> gold -> herds/hunts -> treasures (difficulty latch before
       each; insideWorld + belowCliffs + socket/wall standoffs)
    d. water forts (route-clearance checked) -> fishes -> whales
16. **UNIT IDS block** — every trigger-targeted id, one place, object-def
    reads only, echoes for the log
17. Triggers, in this order (all names space-created/underscore-looked-up):
    1. Starting techs (Paris shape: switch, players loop 1..N;
       gaia gets ONLY an inert stat tech - zpParisGaiaSetup pattern, tech
       to be authored by the user; deEUMapUpdateVisuals stays 0..N)
    2. City object conversion (suspend OFF trigger + nugget releases) +
       KotH/water-fort conversion (tug-of-war families)
    3. Victory conditions - TBD
    4. Consulates + pirate/Orthodox politicians (Orthodox still missing -
       needs its Activate trigger + techs, mirror the Tortuga pattern)
    5. Pirate ship training (privateer + flagship families)
    6. Orthodox and Pirate AI captains (factions) - Medi captain pattern
18. Status text finish (1.00)

## 4. IMPLEMENTATION PHASES (one GO per phase, commit per verified phase)

Each phase = propose -> GO -> apply -> user verifies in game -> commit.
No phase starts on an unverified base. Estimated at the user's 16h budget.

- **P0 — Conventions charter + skeleton** (1h): this document approved;
  empty-section skeleton file with banners in canonical order.
- **P1 — Foundation port** (1h): sections 1-8 reordered to the canonical
  skeleton as-is (constructs stay — corrected audit cleared them); only the
  fillHouses `while` replaced (T1).
  GATE: generation identical to current (census diff on a fixed seed).
- **P2 — Harbours + floating islands** (1.5h): sections 9-10.
  GATE: guns 4/4, pirates walled, sockets suspended (Skirmish).
- **P3 — City + block grid** (3h): sections 11-13 with the capturable
  extraction (factory/menagerie/fort defs out of groupings — grouping XML
  edits, deploy x3, restart).
  GATE: city generates, players placed, capturables present, houses fill.
- **P4 — Countryside + resources** (2h): sections 14-15.
  GATE: camps walled, resources in-world, water forts spawn off-route.
- **P5 — Id block** (0.5h): section 16.
  GATE: echoes match a save-census pairing (the proven method).
- **P6 — Trigger systems** (4h): section 17 families one at a time in the
  listed order; each family its own GO + Skirmish test.
  GATE per family: suspend holds / converts / trains in Skirmish.
- **P7 — Cleanup** (1h): map profile tests (scripts/mapcheck), final
  Skirmish pass 2-team 4p + 8p, commit "GOOD" checkpoint, tag.

Contingency (16h total leaves ~1h): reserved for the map-list/enforced-
settings verification (2-team lobby requirement from the companion xml).

## 5. STANDING LAWS (from this session, apply to every phase)

- Repo `randmaps/zpistanbulb.*` is canonical; root `000_istanbul/gun_test`
  are derived copies synced every edit; no other istanbul-family file may
  exist anywhere the game looks.
- After data/*.xml edits: user regenerates XMB; after grouping edits or new
  groupings: full game restart; process-stale check = compare
  `(Get-Process AoE3DE_s).StartTime` vs xmb mtimes before trusting any test.
- Nugget protos come from nuggetmods `<nuggetunit>` per latched difficulty.
- Never pass a negative into `rm*MetersToFraction`/`rm*TilesToFraction`.
- Trigger `TechID`s must exist in the process-loaded techtree.
- Floating placements are checked against both trade-route polylines
  (>= ~50 m) before they are ever generated.
