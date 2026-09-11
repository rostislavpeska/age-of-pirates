---
name: nugget-targeting
description: Target nuggets and grouping units by engine unit id in RM trigger code ("Nugget Is Collectable", Unit Action Suspend, Convert Units in Area, Units Owned). Use when wiring or debugging ANY conversion/capture system - trade sockets, capturable factories/menageries/forts, pirate camps - or whenever a trigger that references a unit id silently never fires. Triggers on "nugget is collectable", "convert trigger doesn't fire", "targets the wrong unit", "unit id shifted", "AutoConvert suspend", "capturable building".
---

# Targeting nuggets and grouping units in RM triggers

Every rule here was paid for in hours of in-game debugging (2026-08-14,
000_istanbul). Follow the checklist; never re-derive from theory.

## Rule 1 - baked nuggets are PLACEHOLDERS, query the nuggetmods proto

A nugget unit authored inside a grouping XML (`Nugget`,
`zpNuggetKidnapGuillotine`, ...) does NOT exist at runtime. The active
`rmSetNuggetDifficulty(D, D)` latch replaces it at spawn with the
`<nuggetunit>` proto of difficulty D's record in `data/nuggetmods.xml`.

`rmGetGroupingInstanceUnitByType(placement, "<authored proto>")` therefore
returns garbage that resolves to a NEIGHBOURING unit - the failure mode is a
"Nugget Is Collectable" condition that silently never fires, or a suspend
that hits the wrong unit.

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

Istanbul truth table (verified): 517 harbours -> `ypNuggetTradingPost`,
516 factory -> `zpNuggetInvisible`, 520 fort -> `zpNuggetInvisible`,
98 menagerie -> `zpNuggetInvisible`. `zpNuggetInvisible` is also what Paris
and Independence War query for their estates - it is a real spawned proto,
not a placeholder.

## Rule 2 - the unit-id schema shift is per-map and empirical

Queried ids (`rmGetUnitPlaced` AND `rmGetGroupingInstanceUnitByType`) come
back offset from the real engine ids by a per-map constant:

- 000_istanbul: **+2** on every conversion id (`int unitIdShift = 2;` at the
  top of the conversion section - retune there if the build order changes)
- zp_z_zparis: +1 on every instance-queried id (its lines 1720-1748)
- 000_independence_war: object-def ids exact; grouping-last-unit sits at
  flagDef id -1 there, but +2 on Istanbul (pirate camps, in-game verified)

The direction/size CANNOT be derived - a build-order change can move it.
Verify in-game on ONE unit before trusting a batch. The user tests by
editing the constant and regenerating.

## Rule 3 - XS conventions for id code (fragile parser)

- ids are `int`s; build the param string INLINE: `""+myId` - no spaces,
  no intermediate string variables
- never pass a negative into `rm*MetersToFraction`/`rm*TilesToFraction`;
  write `base - rmXMetersToFraction(positive)` instead
- declare loop vars once (`fc`, `fd`, ... - main has NO block scope)

## Rule 4 - the proven trigger idioms

Suspend at start, release on nugget (Paris 1872-1961 / IW 2380-2430):

```
rmAddTriggerEffect("Unit Action Suspend");
rmSetTriggerEffectParam("SrcObject", ""+unitId);
rmSetTriggerEffectParam("ActionName", "AutoConvert");
rmSetTriggerEffectParam("Suspend", "True");     // "False" to release

rmAddTriggerCondition("Nugget Is Collectable");
rmSetTriggerConditionParam("NuggetObject", ""+nuggetId);
```

Ownership sweep after capture (Paris 2621-2687): `Units Owned` condition on
the flag id -> `Convert Units in Area` per UnitType (SrcObject = flag,
SrcPlayer 0, TrgPlayer k, Dist 35) -> optional `ZP Set Tech Status (XS)`
transform tech -> disable all players' variants of the trigger.

For NEW content, prefer IW's layout: place the nugget as its own object def
(`"Nugget"`, min 4 / max 6 around the socket) and take the id from
`rmGetUnitPlaced(def, 0)` - def-handle ids survive the difficulty swap and
need no adjacency arithmetic.

## Process-stale-data law (the 21:48 incident, 2026-08-15, measured)

The engine loads techtree/protomods/strings XMBs ONCE at PROCESS START.
Trigger "TechID" params are plain STRINGS resolved at SERIALIZATION time
against that in-process techtree: a tech added/regenerated after the game
launched does NOT resolve, the serializer DROPS the whole trigger, and the
drop can derail serialization of FOLLOWING triggers until a section whose
references all resolve (measured: Starting Techs with a post-launch tech
killed production+fort+waterfort triggers too; pirates/harbours with old
techs survived). Symptom reads as "works in editor, dead in Skirmish".
DIAGNOSIS FIRST, before touching any code: compare
`(Get-Process AoE3DE_s).StartTime` against the data *.xml.xmb mtimes -
if any XMB is newer than the process, EVERYTHING observed in-game since is
evidence about a stale process, not about the code. Fix = full game
restart. Verify after restart by reading `Trigger/trigtemp.xs` for the
trigger's rule + its trTechSetStatus lines - never by playing first.

## Trigger-name law (Starting Techs incident, 2026-08-15)

Create triggers with SPACES, look them up with UNDERSCORES - ALWAYS:
`rmCreateTrigger("Starting Techs")` then
`rmSwitchToTrigger(rmTriggerID("Starting_Techs"))`. A space (or wrong word)
inside an rmTriggerID lookup is NOT an error in the EDITOR - the map
generates fine - but SKIRMISH fails to resolve it and the trigger's effects
silently never run. This editor/skirmish split makes it the nastiest class
of bug: everything looks verified until a real game runs. Audit after any
trigger work: every rmTriggerID argument must be underscore-jointed.

## Tech-execution law (embassy incident, 2026-08-15)

`<effect type="TechStatus" status="active">X</effect>` inside a tech only
FLIPS X's status flag - it never executes X's effect list. Fine for empty
marker techs (anim `logic type="Tech"` branches read the flag, e.g.
deMapIsEuropean); useless for effect-carrying techs (deEUMapUpdateVisuals'
twenty UpdateVisuals silently never ran). To EXECUTE a tech's effects from a
map, fire it from a trigger: `ZP Set Tech Status (XS)` + `Status 2`, per
player - zp_z_zparis.xs 1804-1812 fires cTechdeEUMapUpdateVisuals for
i = 0..cNumberNonGaiaPlayers (gaia included) exactly this way.

## Diagnostic checklist when a conversion trigger is dead

1. Is the queried proto the **nuggetmods `<nuggetunit>`** for the latched
   difficulty? (Rule 1 - the most common failure.)
2. Does the id carry the map's **unitIdShift**? Is the constant still right?
   (User tests +/-1, +/-2 in-game.)
3. Are the params in proven XS form (`""+intVar` inline)?
4. Ground truth: save the generated scenario, census it
   (`sandbox/census/census.py`), and check what proto actually stands at the
   position - name-mapping is unreliable for zp protos, match by position.
5. Check the reference maps before inventing anything: zp_z_zparis.xs
   (factory/menagerie/fort), 000_independence_war.xs (harbours, pirates,
   estates), zp_mediterranean.xs (pirate ship training).
