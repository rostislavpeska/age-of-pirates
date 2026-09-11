---
name: map-politician-triggers
description: Add or repair the consulate / Trading Post politician switcher triggers in a random map - the Activate_<Faction> + Human_Check_Plr family that lets a player swap their consulate politician list when they research a native big button (Orthodox Influence, The Black Flag, Sultanate Expansion, Cossack Expansion) or play an Asian civ. Use when a map is missing politicians for a native it places, when a consulate page is empty after allying, or when combining two patron systems on one map. Triggers on "no Orthodox politicians", "politician switcher", "consulate triggers", "Activate Tortuga", "empty consulate page", "add politicians to the map".
---

# Map politician switcher triggers

Reference implementations: `randmaps/zpblacksea.xs` **1697-1962** (read this one
first, it is complete) and `game/randmaps/zpvenice.xs` 1628-1850. Both ship
working. `randmaps/zpistanbulb.xs` uses a pre-declare idiom instead.

## Rule 0 - the balance/returner family is NOT optional

**This is the single mistake that breaks the construct, and it looks like dead
weight.** Every switcher grants `cTechzpBigButtonResearchDecrease` so the big
button researches instantly. `Cheat Returner` hands the cost **back** 10ms
later. Omit it and the discount is permanent - every later big button is free.
blacksea names it the *"Speed Always Wins Returner"*.

The two Italian triggers are load-bearing too: the faction big buttons
(`zpOrthodoxInfluence`, `zpTheBlackFlag`, `zpSultanateExpansion`) each carry

```xml
<effect type="SetOnTechResearchedTech" amount="0.00">DEShipItalianVillager</effect>
<effect type="SetOnTechResearchedTech" amount="0.00">DEShipItalianFishingBoat</effect>
```

so an Italian player silently loses those shipments unless the Ballance techs
repay them. They are **not** map-specific to Italian maps.

**Never conclude they are unused because the target map does not define them.**
That means the target map's construct is already incomplete - copy the pattern,
not the hole.

### Who fires what

| Switcher | Fire Events |
|---|---|
| Asian civ consulates (Japan / China / India / Khmer) | `Cheat_Returner` |
| Faction big buttons (Orthodox / Tortuga / Sultanate / Cossacks / Venice / Maltese) | `Italian_Vilager_Balance` + `Italian_Gondola_Balance` + `Cheat_Returner` |

Asian swaps do not touch the shipments, so they only need the returner.

### The three definitions - zpblacksea.xs 1697-1744

Priority **2** (the switchers are 4, so these resolve after), `Active(false)`,
`RunImmediately(false)`, `Loop(false)`.

```cpp
rmCreateTrigger("Italian Vilager Balance"+k);
rmAddTriggerCondition("ZP Player Civilization");
rmSetTriggerConditionParamInt("Player",k);
rmSetTriggerConditionParam("Civilization","DEItalians");
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpItalianSettlerBallance");
rmSetTriggerEffectParamInt("Status",2);

rmCreateTrigger("Italian Gondola Balance"+k);
rmAddTriggerCondition("ZP Tech Status Equals (XS)");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParam("TechID","cTechDEHCGondolas");
rmSetTriggerConditionParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpItalianGondolaBallance");
rmSetTriggerEffectParamInt("Status",2);

rmCreateTrigger("Cheat Returner"+k);          // Speed Always Wins Returner
rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("Param1",10);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchIncrease");
rmSetTriggerEffectParamInt("Status",2);
```

## The switcher itself

`Active(false)`, `RunImmediately(true)`, `Loop(true)`, priority 4. Armed by
`Human_Check_Plr`, never active on its own.

```cpp
rmCreateTrigger("Activate Orthodox"+k);
rmAddTriggerCondition("ZP Tech Researching (XS)");
rmSetTriggerConditionParam("TechID","cTechzpOrthodoxInfluence");   // the big button
rmSetTriggerConditionParamInt("PlayerID",k);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffOrthodoxBalkan");
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease");
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("ZP Pick Consulate Tech");
rmSetTriggerEffectParamInt("Player",k);
// ... then the Fire Events from Rule 0
```

Asian variants add a second condition `ZP Player Civilization` and gate on
`cTechzpPickConsulateTechAvailable` instead of a big button.

## Human_Check_Plr - the igniter

`Active(true)`, condition `ZP PLAYER Human` MyBool **true**. Grants
`cTechzpIsPirateMap`, then one `Fire Event` per `Activate_*` trigger. **A new
switcher is dead until you add its Fire Event here.**

## Combining two patron systems is safe

Every `zpTurnConsulateOff*` tech is a **total reset**: it sets *every* politician
in the mod unobtainable, then re-enables only its own three, naming the rivals
explicitly. `...OffPirates` disables Georgians/Bulgarians/Constantinopole;
`...OffOrthodoxBalkan` disables Blackbeard/Grace/BlackCaesar. They are
alternative patrons, never simultaneous, and each is gated on its own distinct
big button. Nothing to reconcile - the mutual exclusion is already in the data.

## Pick the right regional variant

| Tech | Enables | Used by |
|---|---|---|
| `zpTurnConsulateOffOrthodox` | Georgians, Bulgarians, **Russians** | kurils |
| `zpTurnConsulateOffOrthodoxBalkan` | Georgians, Bulgarians, **Constantinopole** | blacksea, venice, istanbul |
| `zpTurnConsulateOffOrthodoxSouth` | Georgians, Constantinopole, **Alexandria** | deadsea |

Read the `status="obtainable"` lines of the candidate tech - do not guess from
the name.

## Prerequisites on the map

The big button only exists if the player can ally with that native, so confirm:

1. `rmSetSubCiv(n, "zpOrthodox")` is registered
2. a grouping carrying the right socket is actually placed (`zpSocketOrthodox`
   for Orthodox - check the grouping XML, not the grouping name)
3. the alliance tech (`zpNativeOrthodox`) is what makes the big button obtainable

## Two idioms - match the target file

- **blacksea / venice**: `rmCreateTrigger` then conditions/effects immediately.
- **istanbul**: every trigger created at the top of the per-player loop, bodies
  filled later via `rmSwitchToTrigger(rmTriggerID(...))`. Creates must come
  **before** any `rmTriggerID` that references them.

`rmTriggerID` normalises spaces to underscores: create `"Activate Orthodox"`,
look up `"Activate_Orthodox"`. **Casing is not normalised.** istanbul creates
`"Starting Techs"` and looks up `"Starting techs"` - that returns -1 and the
switch silently fails; it only works because `rmCreateTrigger` leaves the new
trigger current. Some maps ban spaces in trigger names outright - follow the
local comment.

## AI players

Humans get the switcher; AI players need a separate roller, e.g.
`ZP Pick Orthodox Captain` (zpblacksea.xs 2667-2707) - `ZP PLAYER Human` MyBool
**false**, then `rmRandInt(1,3)` picking one `cTechzpConsulateOrthodox*`.
Without it an allied AI has an empty consulate page. Many maps omit it for every
faction; add it for all of them or none, never just the new one.

## Verify

```bash
python .claude/skills/map-politician-triggers/scripts/politiciancheck.py randmaps/<map>.xs
```

Reports every switcher and what it fires, flags any missing balance/returner
wiring, any `rmTriggerID` with no matching `rmCreateTrigger` (resolves to -1),
and brace balance. Then diff mapcheck against the pre-edit file - a bare FAIL
count means nothing, only *new* findings do:

```bash
git show HEAD:randmaps/<map>.xs > "<SteamRandMaps>/zzbaseline.xs"
python -m scripts.mapcheck zzbaseline ; python -m scripts.mapcheck <deployed-name>
```

Keep repo and every game-root copy byte-identical, and preserve the map's line
endings (`.xs` here are LF).
