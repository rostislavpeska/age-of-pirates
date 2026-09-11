---
name: native-politician
description: Add a consulate politician ("Choose a Foreign Ally" card) for any native, Royal House, faction or pirate captain - the consulate tech, the portrait, the politician SET a map fires, the AI pick, and every variant the mod uses (special unit + special tech, unit + two techs, techs only, stat-only, whole-native alliance, map-bonus rename). The pirate captain with a new flagship is the full worked example (proxy training, shared build limit, settlement spawn chain, second-flagship tech, voices). Triggers on "new politician", "new pirate captain", "foreign ally", "consulate option", "add a captain to <map>", "politician set", "map bonus politician".
---

# Adding a consulate politician

A politician is **one tech + one portrait**. Everything else is wiring that
decides where the card appears and what it grants. Built from the 85 existing
`zpConsulate*` techs (survey 2026-09-08) and the John Paul Jones captain
(2026-09-07, spec `scripts/mapcheck/tests/test_jones_captain.py`).

## 1. Anatomy (every politician)

**The tech** (`data/techtreemods.xml`) - copy a sibling of the same variant:

```xml
<tech name="zpConsulate<Group><Name>" type="Normal">
  <dbid>NEXT FREE</dbid>                       <!-- lowest unused above 41504 -->
  <displaynameid>NAME</displaynameid>          <!-- the card title -->
  <cost resourcetype="Gold">250.0000</cost>
  <researchpoints>1.0000</researchpoints>
  <status>UNOBTAINABLE</status>
  <icon>resources\images\icons\techs\nat_blackflag.png</icon>   <!-- group icon, not shown on the card -->
  <rollovertextid>ROLLOVER</rollovertextid>    <!-- the card body -->
  <flag>CountsTowardMilitaryScore</flag>
  <flag>YPConsulateTech</flag>                 <!-- makes it a consulate option -->
  <flag>YPSequesterTech</flag>
  <flag>DoNotQueue</flag>
  <effects> ... see 2 ... </effects>
</tech>
```

**The portrait** (`data/politicianmods.xml`) - element named after the tech,
lowercased:

```xml
<zpconsulate<group><name> portraitfilename="ui\ingame\politicians\consulate_portuguese" portraitfilenamewpf="resources/images/icons/politicians/<name>.png">
</zpconsulate<group><name>>
```

The wpf png is what the card shows (the `portraitfilename` is the legacy
fallback every entry shares). No registration anywhere else.

**The set** - which cards a player gets to choose from. A set is a
`zpTurnConsulateOn/Off<Set>` shadow tech (`YPInfiniteTech`) that flips every
consulate tech: the set's own members `obtainable`, everybody else
`unobtainable`. There are ~38 of them; **every set must name the new
politician** (off in all but its own), otherwise a set fired later leaves
him visible. A map fires its set from the consulate switcher triggers
(`Activate <Faction><k>` -> `ZP Set Tech Status (XS)` status 2 -> `ZP Pick
Consulate Tech`); see the `map-politician-triggers` skill for that family.
A map-exclusive politician = his own set (clone the group's set, swap him
in) + the map switched to it. Pirates today: `zpTurnConsulateOffPirates`
(default, IW + Caribbean Wars), `...PiratesMedi` (Istanbul),
`...PiratesBaltic` (Elbe, Iceland), `...PiratesAustralia`, `...PiratesIndependence`.

**The AI** never opens the dialog: maps carry a `ZP Pick Pirate Captain<k>`
trigger (`ZP PLAYER Human` false + the alliance tech active) that fires one
consulate tech from a random roll. Add the new one to the roll (and remove the
one it replaces).

## 2. Variants - what the effects grant

| pattern | signature | examples | rollover headers |
|---|---|---|---|
| special unit + special tech | Enable proto, CommandAdd proto to the buildings, CommandAdd tech p2 c5/c6 on TradingPost | pirate captains, Wokou, Venice houses, Hansa, XMass | `TRAINING:` / `SPECIAL TECH:` |
| unit + two techs | as above but two techs | Scientists (Nemo, Loveless), Orthodox, Hussites, Western, Estate | `TRAINING:` / `TECHS:` |
| techs only | CommandAdd two techs, nothing enabled | Maltese, Jewish, Cossacks, Rev, Penal Colony | `TECHS:` |
| stat only | Data effects on the player's units, no unit, no tech | Rev President/General/Admiral | `TECHS:` (text only) |
| whole-native alliance | Enable the native's units, CommandAdd all its techs, `UpgradeSubCivAlliance`, `SetName` | Maya, Zapotec, Tupi, Cherokee, Lakota, Jesuit, Electors | `TRAINING:` / `TECHS:` |
| map bonus | a map-setup tech `SetName`s the politician tech to a "(Map Bonus)" name + a bonus rollover | Barbarossa on Istanbul (`zpPirateGunners`), Nemo on two maps, Dolfin | see 4 |

Common tail every tech carries after its own effects:

```xml
<effect type="TechStatus" status="unobtainable">zp<Group>BigButtonTech</effect>   <!-- pirates: zpTheBlackFlag -->
<effect type="TechStatus" status="obtainable">ypPickConsulateTech</effect>
<effect type="CommandRemove" tech="zp<Group>BigButtonTech"><target type="ProtoUnit">TradingPost</target></effect>
```

Special techs are made **obtainable by the native's alliance hub tech**
(`zpNativePirates`, `zpNativeWokou`, ...), not by the politician; the
politician only places the button (`CommandAdd tech=... page="2" column="6"`).

## 3. Rollover text - the house formats

Literal two-character `\n`, colour tags escaped. Three shapes exist; pick the
one your variant uses and do not invent sections (extra sections overflow the
card):

```
TRAINING:\n<unit>\n\n<one description line>\n\nSPECIAL TECH:\n<tech>            (300010, Blackbeard)
TRAINING:\n<unit>\n\n<description>\n\nTECHS:\n<tech 1>, <tech 2>                (301750-style)
TECHS:\n<tech 1>, <tech 2>  [+ description]                                     (techs only)
```

Header colour `&lt;color=1.0, 0.9, 0.5&gt;...&lt;/color&gt; `; note the
trailing space before `\n`.

## 4. Map bonus - exactly Barbarossa's way

`303390` "Hayreddin Barbarossa (Map Bonus)" + `303391`:

```
TRAINING:\nSultana\n\n<green>Bonus:</green> Ships Captain Hizir hero character.\n\nSPECIAL TECH:\nCorsair Emissary
```

The bonus line **replaces** the description line, one line, green
`&lt;color=0.0, 1.0, 0.0&gt;Bonus:&lt;/color&gt;`, no bullet, no extra header.
A multi-map politician keeps its plain name/rollover and a map-setup tech
swaps them (`<effect type="SetName" tech="zpConsulate..." newname="ID"
newrollover="ID">`); a map-exclusive one just IS the map-bonus version. The
bonus effects live in the politician tech (Jones: `Hitpoints ×1.15 BasePercent`
on `xpIronclad` and `deSteamer` - the USA hulls; the pirate/Wokou/Hansa
steamers are different protos).

## 5. Pirate captain with a new flagship - the full chain (Jones, 2026-09-07)

Order matters; every layer below was needed, and the spec covers each.

1. **Ship** `zpSPC<Ship>` = clone `zpSPCBlackPearl` (2660): new id/dbid in the
   real sequence (21160+, NOT the 3xxxx test range), animfile, icon
   (`<icon>` = the *_icon.png, `<portraiticon>` = the big png), displayname,
   editorname, own rollover; drop the `<train>` lines if no pirate training;
   keep `frigate.tactics`, `<buildlimit>1`, `sharedbuildlimitunit
   zpSPCQueenAnne`, `UseSharedBuildLimit`, `AbstractPirateShip`,
   `AbstractLegendaryShip`, `Abilities` command.
2. **Proxy** `zpSPC<Ship>Proxy` = clone `zpSPCBlackPearlProxy` (3891): the
   training ticket (900 hp, 40 s, `NotPlayerPlaceable`); cost = the Prau
   proxy's 600 gold / 200 wood unless told otherwise.
3. **Second ship** (PrauB pattern) `zpSPC<Ship2>` = clone of the ship, own
   editor name, same display name, no proxy, `AbstractLegendaryShip` removed.
4. **Shared build limit**: add all three names to EVERY
   `<sharedbuildlimitunittypes>` list of the pirate family (16 carriers today
   -> 19); the clones carry the full list themselves. `sharedselectionunittypes`
   listing ship + ship2 on both if they should select together.
5. **civmods** `NatPirates`: `<multipleblocktrain>` proxy -> ship for
   `zpSPCPirateDock` and `zpSPCPirateDockB`, last block of each dock group.
6. **abilitymods**: `<zpspc<ship>>` and `<zpspc<ship2>>` with
   `PowerBroadside<rof>60`. **randomnamemods**: one `<protounit>` per ship,
   `<title>` = the name string. **sound**: `sound/zpspc<ship>_snds.xml` per
   ship (found by proto name), cloned from the Black Pearl's with the wanted
   voice (`DEAmericanFrigateSelect/Acknowledge` for American).
7. **Politician tech** (pattern "unit + special tech"): Enable proxy;
   CommandAdd proxy on TradingPost p0 c4, `zpSPCPirateDock` p0 c1,
   `zpSPCPirateDockB` p0 c1; the common tail; CommandAdd the special tech on
   TradingPost p2 c6. Stat techs that name flagships (`zpNatLegendaryPrivateer`,
   `zpPirateLock/UnlockCitystateTechs`) get the new ship/proxy for parity.
8. **Special tech** (second flagship, Wokou pattern `zpWokouSecondaryFlagship`):
   800 gold, 30 s, prereq Industrialize, flags `CountsTowardMilitaryScore`
   `YPNativeImprovement` `CheckWaterHCGatherPoint` `DEHideAdvancedRollover`;
   effects `BuildLimit +1 Absolute` on the pool holder `zpSPCQueenAnne` and
   `FreeHomeCityUnit` ship2. Made obtainable by `zpNativePirates`.
9. **Settlement training** (maps with pirate settlements: Independence War):
   proxy near the socket -> `cTechzpTrain<Ship><s>` -> `Spawn<Ship>` on
   `zpPirateWaterSpawnFlag<s>`. Needs `zpTrain<Ship>1/2` (clone
   `zpTrainBlackPearl1/2`, only the action name differs), a `Spawn<Ship>`
   action in `data/tactics/waterspawnpoint.tactics` (action block + tactic
   list entry; the `...Proxy` spawn variants are used nowhere), and the map's
   `<Captain>Train<s>ON/OFFPlr<k>` pair + its Fire Events in the settlement
   capture/release triggers.
10. **Set + map + AI**: own `zpTurnConsulateOffPirates<Map>` set (replace the
    captain he stands in for - IW dropped Grace), every other set turns him
    off, the map's `Activate Tortuga` fires the new set, the AI roll includes
    him. Root working copy first (`Game\RandMaps\000_*.xs`), mirror to the
    repo, byte-identical.
11. **Strings** in id order after the block's highest id (303xxx). **Twins**:
    protomods, techtreemods, civmods, politicianmods, randomnamemods,
    abilitymods, stringmods.

## 6. Placement, endings, tests

- New records go at the END of a file's real content, directly above its first
  long commented/TEST section (`<!--TEST AND TEMPORARY CONTENT-->` in
  protomods, `<!--TEST TECHS-->` in techtreemods), never beside a related old
  record; civ blocks inside the owning civ; files with no comments -> last.
- All these files are CRLF on disk: read bytes, insert with the file's own
  newline, write with `newline=""`, re-count. Never build XML with `\n` in a
  bash heredoc (the `\n` becomes a real newline - measured); write a `.py`.
- Write the spec first: `test_jones_captain.py` is the template - static
  shape per file, every shared list identical, every set names the
  politician, placement, map switch + root==repo, twin freshness. Run it red,
  build, run it green, then the game.

## Known traps (all hit once)

- `rmTriggerID` of a trigger created later resolves to "(None)": create every
  trigger first, then fill.
- The politician must be turned off in *all* other sets, not just the group's.
- A second description section on the card overflows; use the Barbarossa
  layout.
- Ids 30042+ and empty `id=""` are the test units; real content continues
  21160+.
