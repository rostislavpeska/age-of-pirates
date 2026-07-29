# Assignment — Colonial Estate map triggers

Add the trigger wiring for the Colonial Estate native to a random map. **The
groupings are already placed. Do not touch placement, terrain or groupings —
triggers only.**

All data-side content already exists in `data/`. Nothing in `data/` needs editing
for this task.

---

## What already exists

| piece | name |
|---|---|
| civ | `zpColonialEstate` |
| socket | `zpSocketColonialEstate` (city-state socket) |
| enabler tech | `zpNativeColonialEstate` (wired as the civ's Age0 `agetech`) |
| elect buttons | `zpColonialEstateElectDefender`, `zpColonialEstateElectAttacker` |
| alliance picks | `zpConsulateEstate{Hannover,PenalColony,Jesuit,Western,Sansculottes,Jewish}` |
| ladder techs | `zpEstateSiteIncrease`, `zpEstateSiteDecrease` |
| deck reset | `zpColonialEstateNativeSetup` |
| side unlocks | `zpEstateUnlockDefender`, `zpEstateUnlockAttacker` |

Defender alliances: Hannover, Penal Colony, Jesuit.
Attacker alliances: Western, Sansculottes, Jewish.

---

## Task 1 — assign the subciv

Wherever the map allocates subcivs, point the Colonial Estate slots at the civ:

```
subCivN = rmGetCivID("zpColonialEstate");
rmEchoInfo("subCivN is zpColonialEstate "+subCivN);
if (subCivN >= 0)
    rmSetSubCiv(N, "zpColonialEstate");
```

Copy the exact shape already used in `game/randmaps/zpcoldwar.xs` (search
`rmGetCivID("Inuit")`). Use the real civ name string `zpColonialEstate` — it is
case-insensitive in `rmGetCivID` but keep the casing for readability.

---

## Task 1b — clear the deck at map start

`zpColonialEstateNativeSetup` strips all 24 faction techs and all 12 proxy units
off the Trading Post, so nothing is visible until a player picks a persona. The
pick tech then re-adds only that persona's cards at the right slots.

**Without this the Trading Post shows every faction's cards at once**, which is
the bug it exists to prevent.

> **Map constraint.** The strip removes cards that also belong to the Western
> Village, Jewish, Sansculottes, Jesuit and Penal Colony natives. A map hosting
> Colonial Estates must therefore **not** host any of those five natives — an
> allied player would find that native's own cards stripped. Check the map's
> native list before adding Colonial Estates, and report rather than work around
> it if they clash.

Activate it once per player at map setup, `Status 2`, alongside the subciv
assignment:

```
rmSetTriggerEffectParam("TechID","cTechzpColonialEstateNativeSetup");
rmSetTriggerEffectParamInt("Status",2);
```

The Prince Electors do exactly this — see `zpCrownlandsSetup` and `zpElbeSetup`
in `data/techtreemods.xml`, which activate `zpPrinceElectorNativeSetup` the same
way. If the map already has its own `zp<MapName>Setup` tech, add the activation
there instead of creating a new trigger.

---

## Task 2 — unlock the elect button for the player's side

Neither elect button is available by default. Each player gets exactly one,
by activating that side's unlock tech:

- defenders → activate `cTechzpEstateUnlockDefender`
- attackers → activate `cTechzpEstateUnlockAttacker`

Activate **one** per player — never both. Use the `ZP Set Tech Status (XS)`
effect, the same one every other tech trigger in these maps uses:

```
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpEstateUnlockDefender");
rmSetTriggerEffectParamInt("Status",2);
```

`Status` values: 0 unobtainable, 1 obtainable, 2 active.

These techs only **add the card to the Trading Post deck** — the buttons are
already made obtainable by the civ's base tech `zpNativeColonialEstate`. So they
are additive display unlocks, not a filter: a player given neither tech simply
never sees an elect button. Do not try to "switch off" the other side; there is
nothing to switch off.

How the map decides who is a defender and who is an attacker is map-specific —
follow whatever team/side convention that map already uses.

---

## Task 3 — the site ladder, six deep

This is the bulk of the work and the part most likely to go wrong.

### Reference implementation

`randmaps/zpcrownlands.xs`, from the comment `// Prince Elector Increments`
(around line 1636). **Read it before writing anything.** The Colonial Estate
ladder is the same shape, extended from 4 sites to 6.

### What it counts

`zpCityStateFlagTeam` — a generic embellishment proto with no subciv, placed
inside the grouping XML, which converts to whoever captures the site.

> **Check first:** confirm the Colonial Estate groupings actually contain a
> `zpCityStateFlagTeam` unit. If they do not, the ladder can never fire and the
> grouping must be fixed before this task can work.

> **Conflict warning:** this proto is shared with the Prince Electors. If the map
> hosts **both** Prince Elector and Colonial Estate sites, the counts will mix
> and both ladders will misfire. On such a map, stop and report — a separate flag
> proto is needed, which is a data-side change outside this assignment.

### Structure

A chained ladder. Only the next rung is armed at any time, so it cannot
double-fire. For six sites:

```
Increase2  active   >= 2 flags  ->  arms Increase3, Decrease1
Increase3  inactive >= 3 flags  ->  arms Increase4, Decrease2
Increase4  inactive >= 4 flags  ->  arms Increase5, Decrease3
Increase5  inactive >= 5 flags  ->  arms Increase6, Decrease4
Increase6  inactive >= 6 flags  ->  arms Decrease5

Decrease1  inactive <= 1 flag   ->  arms Increase2
Decrease2  inactive <= 2 flags  ->  arms Increase3, Decrease1
Decrease3  inactive <= 3 flags  ->  arms Increase4, Decrease2
Decrease4  inactive <= 4 flags  ->  arms Increase5, Decrease3
Decrease5  inactive <= 5 flags  ->  arms Increase6, Decrease4
```

Every Increase fires `cTechzpEstateSiteIncrease` at status 2; every Decrease
fires `cTechzpEstateSiteDecrease` at status 2. Both are `YPInfiniteTech`, so
they can fire repeatedly.

Note there is **no `Increase1`** — the first site is the unit's base build limit.
`Increase2` is the only one created active; every other trigger starts inactive
and is armed by its neighbours.

### Per-trigger shape

Create all ten with `rmCreateTrigger` **first**, then fill them in with
`rmSwitchToTrigger` — `rmTriggerID` cannot resolve a trigger that does not exist
yet, and the ladder is full of forward references.

```
rmSwitchToTrigger(rmTriggerID("Estate Increase3"+k));
rmAddTriggerCondition("Player Unit Count");
rmSetTriggerConditionParamInt("PlayerID",k);
rmSetTriggerConditionParam("ProtoUnit","zpCityStateFlagTeam");
rmSetTriggerConditionParam("Op",">=");
rmSetTriggerConditionParamInt("Count",3);
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpEstateSiteIncrease");
rmSetTriggerEffectParamInt("Status",2);
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Increase4"+k));
rmAddTriggerEffect("Fire Event");
rmSetTriggerEffectParamInt("EventID", rmTriggerID("Estate_Decrease2"+k));
rmSetTriggerPriority(4);
rmSetTriggerActive(false);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
```

**Underscores in `rmTriggerID`.** Note the trigger is *created* as
`"Estate Increase3"` with a space but *referenced* as `"Estate_Increase3"` with
an underscore. That is not a typo — it is how the existing Elector code works and
how the engine normalises trigger names. Get this wrong and the event silently
never fires.

Wrap the whole block in `for (k=1; <= cNumberNonGaiaPlayers) { ... }`.

---

## Verification before handing back

1. The map loads without script errors.
2. `rmEchoInfo` confirms `zpColonialEstate` resolved to a valid civ id (>= 0).
3. Each player sees exactly **one** elect button, correct for their side.
4. Capturing a 2nd site raises unit build limits; losing it back to 1 lowers
   them. Test at least one step up and one step back down.
5. Ten triggers exist per player, and only `Estate Increase2` starts active.

State explicitly which of these you verified in-game versus only by reading the
script.

---

## Out of scope

Do not change: any file under `data/`, the groupings, unit or tech definitions,
placement, or terrain. If something in those is wrong or missing, report it
rather than fixing it.
