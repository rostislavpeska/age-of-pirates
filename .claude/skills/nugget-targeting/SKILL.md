---
name: nugget-targeting
description: Target nuggets and grouping units by unit id in RM trigger code ("Nugget Is Collectable", Unit Action Suspend, Convert Units in Area, Units Owned). Use when wiring or debugging ANY conversion/capture system - trade sockets, capturable factories/menageries/forts, pirate camps - or whenever a trigger that references a unit id silently never fires. Triggers on "nugget is collectable", "convert trigger doesn't fire", "targets the wrong unit", "unit id shifted", "AutoConvert suspend", "capturable building", "only the last one works".
---

# Targeting nuggets and grouping units in RM triggers

Every rule here was paid for in hours of in-game debugging (2026-08-14 Istanbul,
2026-09-22 London: ~200 USD). Follow the checklist; never re-derive from theory.

## Rule 0 - a trigger parameter is a unit INDEX, and the game tells you what it got

The scenario's trigger compiler takes the number you put into `SrcObject` /
`NuggetObject` / `DstObject` as the unit's scenario **index** and resolves it to the
engine id itself. Read `<profile>\Trigger\trigtemp.xs` after ANY generation (the game
writes it every time, editor and skirmish):

```
trUnitSelectByID(262146);      <- the parameter was a valid index: resolved, works
trUnitSelect("262148");        <- the parameter was NOT an index: select-by-NAME, a silent no-op
trNuggetCollectable("363");    <- the index as given (the condition takes it verbatim)
```

That one file is the whole diagnosis. It replaces probes, chat echoes, shift copies and
debugRandomMaps. Save the generated scenario too when you want the census.

**What `rmGetUnitPlaced(def, 0)` really returns (London, 2026-09-22, measured):** the
ENGINE id of the unit, not its index. For a plain unit the two are equal. For a unit the
engine re-created after placement they are not - a socket docked on a trade route
(`rmSetObjectDefTradeRouteID` + `rmPlaceObjectDefAtLoc`, `zpOrientalFerry`) comes back as
`0x40000 | n` (262146, 262145, 262147 for London's first three ferries) at ANY read time,
early or late; only the last one docked on the lane kept a small number, and even that was
the engine id (169) of a unit whose index was 172. A `"Nugget"` placeholder read gives the
placeholder, not the record's spawned `<nuggetunit>`. None of these numbers is usable as a
trigger parameter; the symptom is "only the last harbour works" / "the first three are
blind", and NO shift constant can ever fix it (London burned 0..5).

`rmGetGroupingInstanceUnitByType(placement, proto) + shift` DOES give an index (London:
+3, Istanbul +2, measured per map with the test-copy method below).

**The forms that work for object-def units:**
1. Literal indices from a census (London harbours: ferries 169-172, resolved
   `ypNuggetTradingPost` 363/368/373/378 - five apart, nugget + four guardians). Stable
   as long as nothing placed BEFORE them changes its unit count; write the placement
   sequence next to the numbers and re-census after any change to it.
2. A plain anchor unit placed on the line before the docked one (Istanbul's
   `zpCinematicRevealer` marker) and `anchor + 1` - the self-adjusting form, untested on
   London as of 2026-09-22 (fix D / F copies); measure with trigtemp.xs before trusting.
3. Bake the socket's nugget into the grouping and query the instance by the RESOLVED
   proto (Istanbul's harbours).

## Rule 1 - baked nuggets are PLACEHOLDERS, query the nuggetmods proto

A nugget unit authored inside a grouping XML (`Nugget`, `zpNuggetKidnapGuillotine`, ...)
does NOT exist at runtime. The active `rmSetNuggetDifficulty(D, D)` latch replaces it at
spawn with the `<nuggetunit>` proto of difficulty D's record in `data/nuggetmods.xml`
(or vanilla `data/nuggets.xml`: 101 -> `ypNuggetTradingPost` + four guardians).

`rmGetGroupingInstanceUnitByType(placement, "<authored proto>")` therefore returns
garbage that resolves to a NEIGHBOURING unit - the failure mode is a "Nugget Is
Collectable" condition that silently never fires, or a suspend that hits the wrong unit.

**Always look the proto up - never guess:**

```bash
python - <<'PY'
import io, re
t = io.open("data/nuggetmods.xml", encoding='utf-8', errors='replace').read()
for m in re.finditer(r'<nugget[^>]*>.*?</nugget>', t, re.S):
    b = m.group(0)
    d = re.search(r'<difficulty>(\d+)</difficulty>', b)
    u = re.search(r'<nuggetunit>([^<]+)</nuggetunit>', b)
    if d and d.group(1) == "PUT_DIFFICULTY_HERE":
        print(d.group(1), u.group(1) if u else "??")
PY
```

Istanbul truth table (verified): 517 harbours -> `ypNuggetTradingPost`, 516 factory ->
`zpNuggetInvisible`, 520 fort -> `zpNuggetInvisible`, 98 menagerie -> `zpNuggetInvisible`.

## Rule 2 - the instance-id shift is per map, measured, and applies to instance queries only

`rmGetGroupingInstanceUnitByType` ids come back offset from the index by a per-map
constant: Istanbul +2, Paris +1, London +3 (2026-09-22). Measure it with four root copies
of the map (`00000_<map>_shift0..3.xs`, the same file with the constant set to 0..3, own
`displayName`s), one generation each, `trigtemp.xs` read after each - never by playing.
It does NOT apply to object-def units (Rule 0). Keep the constant in one block at the head
of the trigger section with every id derived there (Istanbul 4173-4193); no literal
arithmetic on an id anywhere else.

## Rule 3 - XS conventions for id code (fragile parser)

- ids are `int`s; build the param string INLINE: `""+myId` - no spaces, no intermediate
  string variables
- never pass a negative into `rm*MetersToFraction`/`rm*TilesToFraction`; write
  `base - rmXMetersToFraction(positive)` instead
- declare loop vars once (`fc`, `fd`, ... - main has NO block scope); run
  `scripts/mapcheck/xs_scope_check.py` (S6) before any generation - it catches use before
  declaration, double declaration at function scope, call before definition
- write the triggers LITERALLY, four `rmSetTrigger*` lines each, at the end of `main`
  (Istanbul); no helper functions around placements or triggers (user rule 2026-09-22)

## Rule 4 - the proven trigger idioms

Suspend at start, release on nugget (Istanbul 4866 / 4915, Elbe 1379, Paris 1872-1961):

```
rmAddTriggerEffect("Unit Action Suspend");
rmSetTriggerEffectParam("SrcObject", ""+unitId);
rmSetTriggerEffectParam("ActionName", "AutoConvert");
rmSetTriggerEffectParam("Suspend", "True");     // "False" to release

rmAddTriggerCondition("Nugget Is Collectable");
rmSetTriggerConditionParam("NuggetObject", ""+nuggetId);
```

Ownership sweep after capture (Paris 2621-2687): `Units Owned` condition on the flag id
-> `Convert Units in Area` per UnitType (SrcObject = flag, SrcPlayer 0, TrgPlayer k,
Dist 35) -> optional `ZP Set Tech Status (XS)` transform tech -> disable all players'
variants of the trigger.

Do NOT take an object-def unit's id from `rmGetUnitPlaced(def, 0)` for a trigger
parameter (the pre-2026-09-22 version of this file said the opposite): see Rule 0.

## Process-stale-data law (the 21:48 incident, 2026-08-15, measured)

The engine loads techtree/protomods/strings XMBs ONCE at PROCESS START. Trigger "TechID"
params are plain STRINGS resolved at SERIALIZATION time against that in-process techtree:
a tech added/regenerated after the game launched does NOT resolve, the serializer DROPS
the whole trigger, and the drop can derail serialization of FOLLOWING triggers until a
section whose references all resolve. Symptom reads as "works in editor, dead in
Skirmish". DIAGNOSIS FIRST: compare `(Get-Process AoE3DE_s).StartTime` against the data
*.xml.xmb mtimes - if any XMB is newer than the process, everything observed in-game
since is evidence about a stale process. Fix = full game restart. Verify after restart by
reading `Trigger/trigtemp.xs` - never by playing first.

## Trigger-name law (Starting Techs incident, 2026-08-15)

Create triggers with SPACES, look them up with UNDERSCORES - ALWAYS:
`rmCreateTrigger("Starting Techs")` then `rmSwitchToTrigger(rmTriggerID("Starting_Techs"))`.
A space inside an rmTriggerID lookup is NOT an error in the EDITOR but SKIRMISH fails to
resolve it and the trigger's effects silently never run. Audit after any trigger work:
every rmTriggerID argument must be underscore-jointed.

## Tech-execution law (embassy incident, 2026-08-15)

`<effect type="TechStatus" status="active">X</effect>` inside a tech only FLIPS X's
status flag - it never executes X's effect list. To EXECUTE a tech's effects from a map,
fire it from a trigger: `ZP Set Tech Status (XS)` + `Status 2`, per player -
zp_z_zparis.xs 1804-1812 does this for i = 0..cNumberNonGaiaPlayers (gaia included).

## Diagnostic checklist when a conversion trigger is dead

0. Generate once, read `Trigger/trigtemp.xs`: which ids did the compiler emit as
   `trUnitSelectByID(...)`, which as `trUnitSelect("...")` (dead)? The saved scenario's
   trigger data (zlib after the 8-byte `l33t` header, UTF-16 params) shows the raw numbers
   the script wrote. The RM dump `RandMaps/Age3DERM<map>.dmp.txt` proves the script
   compiled (symbol table only, values are 0 - it is written before the run).
1. Is the queried proto the **nuggetmods `<nuggetunit>`** for the latched difficulty?
2. Object-def unit? Then the id came from `rmGetUnitPlaced` - Rule 0, use a literal index
   or an anchor; no shift will fix it.
3. Instance query? Does the id carry the map's **instance shift**, measured with the
   shift copies?
4. Params in proven XS form (`""+intVar` inline)? S6 scope check clean?
5. Ground truth: save the generated scenario, census it (`sandbox/census/census.py <save>
   --full`); vanilla protos are named right, mod protos are not - match those by position
   and by "the only proto index that appears exactly N times".
6. Check the reference maps before inventing anything: zpistanbulb.xs (sockets, forts,
   palaces, the UNIT IDS block), zpelbe.xs (lone harbours with object-def nuggets),
   zp_z_zparis.xs (factory/menagerie/fort), 000_independence_war.xs.
