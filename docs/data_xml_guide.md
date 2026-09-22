# Reference location

The maintained shared reference is [data_xml_guide.md](../skills/aoe3de-reference/references/data_xml_guide.md).
Read its [source and coverage notes](../skills/aoe3de-reference/references/provenance.md).

The following AoP-specific observations remain here; counts and executable addresses
are historical evidence, not a portable schema or current-build guarantee.

# Placement Rules (data\placementrules\*.xml)

A placement rule file decides where a building may be dropped. A protoUnit points at one through its _PlacementFile_ attribute, resolved relative to `Data\placementrules`. A random map can repoint a protoUnit at a different rule file for that map only — see _Random Map Data Overrides_ below. The _PlacementRulesOverride_ tech effect swaps one protoUnit's rule set for another protoUnit's at runtime.

The root element is _PlacementRules_; anything else is rejected with `Expected tag 'PlacementRules' but found '%S' instead.` (exe 0x02409548). Every child element is one rule: the element name is the rule type, the element text is the target unitType, and the qualifiers are XML attributes. An unrecognised child name produces `'%S' is not a valid rule type.` (exe 0x024097e0). Matching is case-insensitive; every shipped file writes tags and attributes fully lowercase.

All rules in a file must pass for placement to be allowed. Rules with no target unitType (_DistanceAtLeastFromCliff_, _DistanceAtLeastFromTradeRoute_) are usually written as empty elements.

&lt;placementrules&gt;

&lt;obstructionatleastfromtype player="any" foundation="any" distance="8" errorstringid="34686"&gt;Mill&lt;/obstructionatleastfromtype&gt;

&lt;distanceatleastfromtype player="enemy" foundation="any" distance="65" errorstringid="25521"&gt;FirstTC&lt;/distanceatleastfromtype&gt;

&lt;distanceatleastfromcliff distance="6" errorstringid="25529" /&gt;

&lt;/placementrules&gt;

Only the Definitive Edition executable was available when this section was written, so **no Legacy / Definitive Edition split is claimed for this parser** — the entries below are what the DE parser accepts. Where a rule type or attribute is never used by shipped data it is marked as such, in the same spirit as the unused protoUnit flags documented above.

## Rule Types

The complete rule-type vocabulary is a contiguous block of wide strings at exe 0x02409580-0x024097da, corroborated by the RTTI class names `.?AVBPlacementRule*@@` at exe 0x02f20288-0x02f205d8. Usage counts below are element counts in the 30 vanilla files under `Data\placementrules` versus the 15 files in this mod.

- **DistanceAtLeastFromType:** Placement fails if any matching unit is closer than _distance_, measured centre to centre. The workhorse rule — vanilla 174, this mod 117. (exe 0x024095c0)
- **DistanceAtMostFromType:** Placement fails unless a matching unit is within _distance_. Used to force a building to stay near your own base — vanilla 22, this mod 13. (exe 0x02409590)
- **ObstructionAtLeastFromType:** As _DistanceAtLeastFromType_, but measured from the target's obstruction rather than its centre, so the target's footprint counts against the gap. Vanilla 188, this mod 80. (exe 0x024095f0)
- **DistanceAtLeastFromCliff:** Placement fails if a cliff is within _distance_. Takes no target unitType — only _distance_ and _errorStringID_. Vanilla 21, this mod 9. (exe 0x024097a8)
- **DistanceAtLeastFromTradeRoute:** Placement fails if the trade route is within _distance_. Takes no target unitType. Vanilla 6 (mills, fields, plantations, Community Plaza), this mod 2. (exe 0x024096b8)
- **DistanceAtMostFromSocket:** Placement fails unless a socket of the target unitType is within _distance_; on success the building is snapped onto that socket. This is the rule that makes Trading Posts buildable only on sockets. Carries the socket-specific attributes _linkUnit_, _successStringID_ and _occupiedStringID_. Vanilla 1 (`tradepost.xml`), this mod 2. (exe 0x02409640)
- **DistanceAtMostFromTradeRoute:** The inverse of _DistanceAtLeastFromTradeRoute_ — placement fails unless the trade route is within _distance_. Present in the parser and in RTTI (`BPlacementRuleDistanceAtMostFromTradeRoute`); **no vanilla or mod file uses it**. (exe 0x02409678)
- **DistanceAtMostFromWater:** Placement fails unless water is within _distance_. Parser and RTTI only; **no vanilla or mod file uses it** — docks instead rely on the engine's built-in shoreline check. (exe 0x024096f8)
- **DistanceAtMostFromMapEdge:** Placement fails unless the map edge is within _distance_. Parser and RTTI only; **no vanilla or mod file uses it**. (exe 0x02409748)
- **InsidePerimeterWall:** Placement is restricted to the interior of a perimeter wall. Parser and RTTI only; **no vanilla or mod file uses it**. Related to the _PerimeterGenerator_ protoUnit flag, itself unused. (exe 0x02409780)
- **InColony:** Placement is restricted to a colony as defined in `Data\placementrules\colonies.xml`. Parser and RTTI only; **no vanilla or mod file uses it**. Pairs with the equally unused _allowTeamColony_ attribute. (exe 0x02409628)
- **FortLinkType:** Fort-linking rule (`BPlacementRuleFortLink`), presumably the SPC fort-wall attach behaviour. Parser and RTTI only; **no vanilla or mod file uses it**. Purpose unverified. (exe 0x02409728)
- **MapType:** Restricts the rule set by random map type, validated against the same map-type name list the nugget parser uses — a bad value yields `'%S' is not a valid map type` (exe 0x02409508). The class `BPlacementRuleMapType` exists at exe 0x02f205a8, but the tag literal is not in the rule-type block; it is pooled with the nugget parser's `MapType` at exe 0x023ade30. **No vanilla or mod file uses it**, so the exact spelling accepted here is unverified.
- **And:** Composite rule — all child rules must pass. `BPlacementRuleAnd` at exe 0x02f202b0. **No vanilla or mod file uses it.** (exe 0x02409580)
- **Or:** Composite rule — any child rule may pass. `BPlacementRuleOr` at exe 0x02f202d8. **No vanilla or mod file uses it.** The literal is two characters long and sits immediately after _and_, which is why a three-character-minimum string scan misses it. (exe 0x02409588)

## Attributes

Attribute names are stored as ASCII in a contiguous block at exe 0x024093a8-0x02409548, interleaved with the parser's own error strings. Counts below are attribute occurrences across vanilla plus this mod.

- **player:** Which players' units the rule tests against. Required on the three unitType rules — 594 uses. See _player Values_ below.
- **foundation:** Which build state of the target counts. Required on the three unitType rules; every shipped file writes `any` (594 uses). The only other value literal in the parser's block is `fullybuilt` (exe 0x024094a8), which **no vanilla or mod file uses**. (exe 0x02409498)
- **distance:** The distance threshold, in world units. Required by every rule type; omitting it yields `No distance specified.` (exe 0x02409410). 635 uses. The attribute name itself is a pooled literal and does not sit in the placement block.
- **errorStringID:** String ID of the message shown when the rule blocks placement. Present on every rule in every shipped file — 635 uses. (exe 0x024093a8)
- **successStringID:** String ID shown when the rule is satisfied. Used only by _DistanceAtMostFromSocket_, to label a valid socket. 3 uses. (exe 0x024093b8)
- **occupiedStringID:** String ID shown when the target socket is already taken. Used only by _DistanceAtMostFromSocket_. 3 uses. (exe 0x024094f0)
- **linkUnit:** `true` on a _DistanceAtMostFromSocket_ rule links the new building to the socket it snapped to. All 3 socket rules in vanilla and this mod set it. (exe 0x024093e0)
- **noRushOnly:** `true` restricts the rule to the No-Rush period, after which it stops blocking. Used on the Trading Post's "must be near your first Town Centre" rule so the restriction lifts once No-Rush ends. 32 uses. (exe 0x02409440)
- **nugget:** `true` on a _DistanceAtLeastFromType_ rule whose target is _AbstractNugget_. Every one of the 15 uses in vanilla and this mod is exactly that pairing, so the attribute appears to scope the check to treasure instances; **exact behaviour unverified**. (exe 0x024093d8)
- **hideUnderFog:** `true` makes the rule not report against units the player cannot currently see, so a placement error cannot be used to probe fogged ground. Only 2 uses, both in vanilla `torp.xml` against _deTorp_ / _deTorpGeneric_. (exe 0x024093c8)
- **includeObstructionRadius:** Presumably makes a distance rule measure from the placed building's own obstruction as well. **No vanilla or mod file uses it**; purpose unverified. (exe 0x024094c0)
- **allowTeamColony:** Presumably widens an _InColony_ test to a team-mate's colony. **No vanilla or mod file uses it**, consistent with _InColony_ itself being unused; purpose unverified. (exe 0x024094e0)
- **linkTakenStringID:** A missing value for it yields `No link taken string id.` (exe 0x02409468). **No vanilla or mod file uses this spelling** — shipped socket rules write _occupiedStringID_ instead, so this is most likely the internal name of the same slot, or a superseded alias. Purpose unverified. (exe 0x02409450)

Two further parser errors exist for malformed input: `Invalid type.` when the element text is not a known unitType (exe 0x02409400), and `'%S' is not a valid map type` (exe 0x02409508).

## player Values

Six literals make up the ownership enum. `any`, `team` and `ally` sit inside the placement-rule block; `self`, `enemy` and `gaia` are a pooled triple shared with the protoAction parser's block. Only three are ever written in shipped data.

- **any:** Every player, gaia included. 520 uses. Vanilla rules written with `player="any"` target gaia-owned objects such as _AbstractNugget_, _AbstractMine_, _Herdable_, _Huntable_ and _ypKingsHill_, which is what establishes that `any` covers gaia. (exe 0x02409428)
- **enemy:** Players you are at war with. 41 uses — the classic "no building within 65 of an enemy Town Centre" rule. (exe 0x02408e80)
- **team:** You and your allies. 33 uses. (exe 0x02409430)
- **gaia:** Gaia-owned units. **No vanilla or mod file uses it**, so its behaviour is inferred, not observed. It is a separate literal from `enemy`, but do not read that as `enemy` excluding gaia — the engine's player-relation enum, exported to XS at exe 0x0241b718-0x0241b7e8 as `cPlayerRelationAny`, `cPlayerRelationSelf`, `cPlayerRelationEnemy`, `cPlayerRelationAlly`, `cPlayerRelationEnemyNotGaia` and `cPlayerRelationAllyExcludingSelf`, carries a distinct _EnemyNotGaia_ value, which implies plain _Enemy_ **includes** gaia-owned units. Treat `player="enemy"` as covering capturable, socketed and map-placed objects until tested otherwise. (exe 0x02408e90)
- **self:** The placing player only. **No vanilla or mod file uses it.** (exe 0x02408e70)
- **ally:** Allies only, presumably excluding yourself, as distinct from `team`. **No vanilla or mod file uses it.** (exe 0x02409488)

## Colonies (data\placementrules\colonies.xml)

`colonies.xml` shares the `placementrules` folder but is a separate parser with root _Colonies_, rejecting anything else with `Expected tag 'Colonies' but found '%S' instead.` (exe 0x02409878); its per-entry parser reports `Expected tag 'Colony' but found '%S' instead.` (exe 0x0242b1d8). It is what the unused _InColony_ rule and _allowTeamColony_ attribute refer to. Vanilla ships two colonies, `Standard` and `SPCMilitaryColony`, both used by the campaign colony system.

- **Colony:** One colony definition. Attribute **name** is its identifier.
- **StartTypes:** Container of _Type_ elements naming the protoUnits that seed a colony. Attribute **maxCount** on each _Type_ caps how many seed it.
- **AddTypes:** Container of _Type_ elements naming the unitTypes that count as belonging to a colony once built.
- **WallCost / WallRepairCost:** Containers of resource elements (_Food_, _Wood_) for raising and repairing the colony wall.
- **WallRadius / WallMaxRadius / WallRadiusIncrease / WallRadiusIncreaseInterval:** Colony wall geometry and its growth over time, in world units and seconds.
- **WallBuildRate / WallDownTime / WallDamageRadius / WallSegments:** Colony wall build speed, downtime after being breached, damage radius and segment count.
- **StartingUnits:** Container of _StartingUnitInfo_ blocks, each holding _UnitType_ elements with a **count** attribute plus _ApplyStringID_, _ApplyStringIDAsian_ and _ApplyStringIDNative_ for the message shown to European, Asian and Native civs respectively.

# Nuggets (nuggets.xml, nuggetmods.xml)

A nugget is a treasure: a gaia-owned prop guarded by hostile units, which grants a reward when the guardians are cleared and the treasure is walked into. `Data\nuggets.xml` is the vanilla list; a mod adds its own in `Data\nuggetmods.xml`, whose root element is _NuggetMods_ rather than _NuggetManager_ — this mod ships 234 nuggets that way. Both files then use the same _Nuggets_ / _Nugget_ body.

The parser is `BNuggetManager` (`e:\_work\p4\gass_dev\source\age3\nuggetmanager.cpp`, exe 0x02416fb0). Its tag vocabulary is a contiguous block of wide strings at exe 0x024171f0-0x02417450, with _Nugget_, _Guardian_, _GuardianUnit_ and _MapType_ pooled into a neighbouring block at exe 0x023ade00-0x023ade40. Which nuggets a map receives is filtered by _MapType_ and by the difficulty window set with the `rmSetNuggetDifficulty` random-map syscall (exe 0x024afe40).

As with placement rules, only the Definitive Edition executable was available, so **no Legacy / Definitive Edition split is claimed for this parser**.

&lt;nugget&gt;

&lt;name&gt;Blueberries&lt;/name&gt;

&lt;type&gt;AdjustResource&lt;/type&gt;

&lt;nuggetunit&gt;NuggetBearCampsite&lt;/nuggetunit&gt;

&lt;rolloverstringid&gt;25460&lt;/rolloverstringid&gt;

&lt;applystringid&gt;25461&lt;/applystringid&gt;

&lt;resource&gt;Food&lt;/resource&gt;

&lt;amount&gt;140&lt;/amount&gt;

&lt;maptype&gt;greatLakes&lt;/maptype&gt;

&lt;guardianunit&gt;

&lt;unit&gt;BlackBear&lt;/unit&gt;

&lt;idleanim&gt;Bear_Campsite_Idle&lt;/idleanim&gt;

&lt;attachdummy&gt;bone_nuggetA&lt;/attachdummy&gt;

&lt;/guardianunit&gt;

&lt;difficulty&gt;3&lt;/difficulty&gt;

&lt;/nugget&gt;

## Attributes

Counts below are element counts in vanilla `nuggets.xml` (961 nuggets) versus this mod's `nuggetmods.xml` (234 nuggets).

- **Name:** Internal nugget name, and the handle used by random-map and trigger code. Required — one per nugget. Pooled literal, no unique offset.
- **Type:** Nugget effect type. Optional — 953 of 961 vanilla nuggets set it, and a nugget without one still loads. See _Nugget Types_ below. Pooled literal.
- **NuggetUnit:** The protoUnit used as the visible treasure prop. Required in practice — vanilla 961, this mod 212. (exe 0x024172a8)
- **RolloverStringID:** String ID for the rollover shown before the treasure is claimed. Vanilla 959, this mod 212. (exe 0x023a25f0)
- **ApplyStringID:** String ID for the message shown when the reward is granted. Vanilla 959, this mod 212. (exe 0x024172c0)
- **Resource:** Resource granted by an _AdjustResource_ nugget — `Food`, `Wood`, `Gold`, `XP`. Vanilla 705, this mod 113. Pooled literal.
- **Amount:** Amount granted. For _AdjustResource_ the resource quantity, for _SpawnUnit_ the unit count, for _AdjustHP_ a multiplier. Vanilla 813, this mod 149.
- **Resource2 / Amount2:** A second resource and quantity, letting one treasure pay out twice. Vanilla 94 each, this mod 12 each. (exe 0x02417370, 0x02417388)
- **UnitType:** For a _SpawnUnit_ nugget, the protoUnit to spawn; _Amount_ gives the count. Also used inside _ResourceModEntry_. Vanilla 100, this mod 26.
- **Tech:** For a _GiveTech_ nugget, the technology to activate. Vanilla 78, this mod 9. Pooled literal.
- **TargetType:** Restricts an _AdjustHP_ or _AdjustSpeed_ nugget to a unitType — vanilla uses `Hero` so a treasure buffs the Explorer only. Vanilla 19, this mod 2. Pooled literal.
- **MapType:** Random map type this nugget may appear on. Repeated once per map — the single most common element in the file. Vanilla 5055, this mod 643. (exe 0x023ade30)
- **Difficulty:** Difficulty weight used to filter nuggets against the window set by `rmSetNuggetDifficulty`. Vanilla 934, this mod 211. (exe 0x024173f0)
- **Guardian:** Shorthand guardian entry — a protoUnit name, repeated once per guardian, with no animation data. Vanilla 1900, this mod 460. (exe 0x023ade40)
- **GuardianUnit:** Long-form guardian entry, a container element — see _Guardian and Convert Sub-Elements_ below. Vanilla 683, this mod 357. (exe 0x023ade10)
- **ConvertUnit:** Container element describing a unit handed to the player by a _ConvertUnit_ nugget, using the same sub-elements as _GuardianUnit_. Vanilla 81, this mod 34. (exe 0x024172e0)
- **ConvertSettler:** `true` marks a _ConvertUnit_ nugget whose reward is a settler — the vanilla kidnap treasures. Vanilla 16, this mod 16. (exe 0x02417440)
- **KillUnitOnApply:** `0` keeps the guarded unit alive when the treasure is claimed instead of removing it. Vanilla 63, this mod 18. (exe 0x02417408)
- **TeamNugget:** `1` makes the reward apply to the whole team rather than the collecting player. Vanilla 87, this mod 12. (exe 0x02417428)
- **WaterNugget:** `true` marks a treasure placed on water and collectable by ships. Vanilla 63, this mod 28. (exe 0x02417290)
- **Icon:** Overrides the icon used for the treasure notification. Vanilla 7, this mod 5.
- **Idle2Anim:** Present in the parser's tag block between _SpawnUnit_ and _ExitAnim_, so presumably a second idle animation for a guardian or converted unit. **No vanilla or mod file uses it**; purpose unverified. (exe 0x02417310)
- **EnterAnim:** Counterpart to _ExitAnim_. **No vanilla or mod file uses it**; purpose unverified. (exe 0x02417340)
- **Pattern:** **No vanilla or mod file uses it**; purpose unknown. (exe 0x02417398)
- **ExploreDistance:** **No vanilla or mod file uses it**; purpose unknown, the name suggests a reveal or discovery radius. (exe 0x024173a8)
- **GuardianDistance:** **No vanilla or mod file uses it**; purpose unknown, the name suggests how far guardians are scattered around the prop. (exe 0x024173c8)
- **SpawnUnit:** A wide literal sitting inside the tag block, adjacent to _ConvertUnit_ which is a real container tag. **No vanilla or mod file uses `<spawnunit>` as an element** — _SpawnUnit_ nuggets name their unit with _UnitType_ and _Amount_ instead — so this may be a container tag that was never used, or the enum comparison for the nugget type. Purpose unverified. (exe 0x024172f8)

## Nugget Types

Seven values, stored as ASCII in a contiguous block at exe 0x02ec2110-0x02ec2170. The engine also exports them to XS as `cNuggetType*` constants (exe 0x0241bbc8-0x0241bcb8), which is what fixes the set exactly.

- **AdjustResource:** Grants _Resource_ / _Amount_, optionally a second payout through _Resource2_ / _Amount2_. By far the most common — vanilla 705, this mod 113. Vanilla also writes the lowercase-initial spelling `adjustResource` 83 times, so the comparison is case-insensitive. (exe 0x02ec2110)
- **SpawnUnit:** Spawns _Amount_ units of _UnitType_ for the collector. Vanilla 82, this mod 26. (exe 0x02ec2120)
- **ConvertUnit:** Hands over the units listed in the _ConvertUnit_ containers. Vanilla 67, this mod 26. (exe 0x02ec2130)
- **GiveTech:** Activates the technology named in _Tech_. Vanilla 78, this mod 9. (exe 0x02ec2168)
- **AdjustHP:** Multiplies hitpoints of _TargetType_ by _Amount_. Vanilla 19, this mod 2. (exe 0x02ec2158)
- **AdjustSpeed:** Multiplies movement speed of _TargetType_ by _Amount_. Vanilla 2, this mod 0. (exe 0x02ec2148)
- **GiveLOS:** Grants line of sight. Exported to XS as `cNuggetTypeGiveLOS` and present in the enum block, but **no vanilla or mod nugget uses it**. (exe 0x02ec2140)

## Guardian and Convert Sub-Elements

_GuardianUnit_ and _ConvertUnit_ are containers; each instance describes one unit and how it is posed on the treasure prop. Both accept the same children. `Did not find dummy location, creating from source.` and `Could not place where we wanted it, destroying.` (exe 0x02417180, 0x024171b8) are the placement diagnostics for this step.

- **Unit:** ProtoUnit to place. Vanilla 764, this mod 391.
- **IdleAnim:** Animation the unit loops while the treasure is unclaimed. Vanilla 550, this mod 119. (exe 0x0240ca40)
- **ExitAnim:** Animation played when the treasure is claimed and the unit breaks from its pose. Vanilla 392, this mod 115. (exe 0x02417328)
- **AttachDummy:** Name of the bone/dummy on the treasure prop that the unit is attached to, for example `bone_nuggetA`. Vanilla 698, this mod 154. (exe 0x02417358)

## ResourceModTech Entries

Optional block at the head of the file, wrapping the treasure-multiplier technologies. Vanilla defines six; this mod defines none.

- **ResourceModTechEntries:** Container of _ResourceModTechEntry_ blocks. (exe 0x02417210)
- **ResourceModTechEntry:** One technology and the units it affects. (exe 0x023adda8)
- **ResourceModTech:** The technology name, for example `DEHCREVLetterOfMarque`. (exe 0x023add88)
- **ResourceModEntries:** Container of _ResourceModEntry_ blocks. (exe 0x02417240)
- **ResourceModEntry:** One unitType and its multiplier. (exe 0x023addd8)
- **UnitType:** The unitType whose treasure collection is modified — `Unit` for all units.
- **ModValue:** The multiplier applied, for example `2.0`. (exe 0x02417278)

# Random Map Data Overrides (randmaps\&lt;map&gt;.mods.xml)

A random map can rewrite protoUnit data for the duration of that map alone. The engine looks for a file named after the map script with the suffix `.mods.xml` alongside it in `randmaps\` — the suffix literal is at exe 0x0235b2d8. This is how a map rebinds a building's placement rules: `randmaps\zpistanbulb.mods.xml` repoints _Dock_, _YPDockAsian_ and _dePort_ at `dock_city.xml`, so the city map's tighter dock spacing applies without touching the global `protomods.xml`.

**No vanilla map ships a `.mods.xml`** — the feature exists in the engine but the shipped random maps do not use it. This mod ships 17 of them.

A sibling suffix `.mods.tactics` exists at exe 0x023adbd0, next to the `.tactics` and `Tactics` literals, implying a matching per-map tactics override. **This mod does not use it and no vanilla map does**; purpose unverified.

Note that neither the literal `protomods` nor the literal `mods` for these element names appears in the executable's string tables, in ASCII or in UTF-16 — the parser evidently resolves them without a stored literal, exactly as the `*mods.xml` data-file names themselves are composed at runtime. Their existence is established from working data files, not from the binary. A failed string scan is not evidence that a name is unsupported.

## Structure

&lt;?xml version="1.0"?&gt;

&lt;mods&gt;

&lt;protomods&gt;

&lt;unit name="Dock"&gt;

&lt;placementfile&gt;dock_city.xml&lt;/placementfile&gt;

&lt;/unit&gt;

&lt;unit id="20330" name="zpAmericanEmbassy"&gt;

&lt;flag&gt;NoIdleActions&lt;/flag&gt;

&lt;flag mergemode="remove"&gt;NotSelectable&lt;/flag&gt;

&lt;/unit&gt;

&lt;/protomods&gt;

&lt;/mods&gt;

- **Mods:** Root element. _ProtoMods_ is the only child witnessed in working files.
- **ProtoMods:** Container of _Unit_ overrides. Takes an optional **version** attribute, written `version='1'` in two of this mod's 17 files (`zpgrinch.mods.xml`, `zpwinterwonderlandii.mods.xml`); its effect is unverified, and the other 15 files omit it with no observable difference.
- **Unit:** One protoUnit to override. Attribute **name** is the protoUnit's internal name and is always present — 845 uses across this mod's 17 files. Attribute **id** is the numeric protoUnit id, written alongside _name_ in 9 cases; it is redundant where _name_ resolves.

Inside _Unit_, any protoUnit element from `protoy.xml` / `protomods.xml` is accepted and replaces the value for that map. Elements this mod actually overrides per map, with occurrence counts across its 17 files: _PlacementFile_ 462, _Flag_ 487, _AnimFile_ 94, _Icon_ 76, _PortraitIcon_ 76, _ObstructionRadiusX_ 67, _ObstructionRadiusZ_ 67, _DisplayNameID_ 37, _Cost_ 25, _MinimapIcon_ 24, _UnitType_ 22, _UnitRegen_ 19, _BuildPoints_ 16, _InitialHitpoints_ 15, _MaxHitpoints_ 15, _Tactics_ 13, _DamageBonus_ 7, _TrainPoints_ 7, _RolloverTextID_ 6, _ShortRolloverTextID_ 6, _CivFlagOverride_ 6, _Command_ 6, _ProtoAction_ 4, _LOS_ 3, _Damage_ 3, _DamageType_ 3, _MaxRange_ 3, _ROF_ 3, _MovementType_ 2, _InitialResource_ 1, _Train_ 1. Attributes carried on those elements behave exactly as in `protomods.xml` — _resourcetype_ on _Cost_ and _InitialResource_, _damagetimeout_ on _UnitRegen_, _type_ on _DamageBonus_ and _Rate_, _page_ / _column_ / _row_ on _Command_ and _Train_.

## Merge Modes

Every element inside _Unit_ accepts a **mergeMode** attribute controlling how the override combines with the base data. The attribute name is at exe 0x02652250. This is the same mechanism used by the global `data\*mods.xml` family (`protomods.xml`, `civmods.xml`, `techtreemods.xml`, `protounitcommandmods.xml`, `politicianmods.xml`, `maptypemods.xml`, `mapspecifictechmods.xml`, `nuggetmods.xml`, `randomnamemods.xml`).

- **add:** Adds the entry to the existing list rather than replacing it. 1968 uses across this mod's data. Writing it is usually unnecessary: an element given without _mergeMode_ already appends when the target is a list (_Flag_, _UnitType_) and overwrites when the target is a scalar (_PlacementFile_, _MaxHitpoints_). The literal is pooled with an unrelated `add` elsewhere in the binary rather than stored next to _mergeMode_.
- **remove:** Deletes the named entry from the existing list. This is how a map strips a flag it does not want — `&lt;flag mergemode="remove"&gt;NotSelectable&lt;/flag&gt;` and `&lt;flag mergemode="remove"&gt;TieToWaterSurface&lt;/flag&gt;` in `zpistanbulb.mods.xml`. 64 uses. (exe 0x02652240)
- **replace:** Replaces the existing list wholesale. 3 uses in this mod. Pooled literal, like _add_.
- **modify:** Sits directly beside _remove_ and _mergeMode_ in the binary, so it is almost certainly a fourth value of this enum. **No vanilla or mod file uses it**; purpose unverified. (exe 0x02652230)