# Version 7.2: Baltic Powers Compatibility & Independence War

Summer 2026 release. The headline is the clean blend with the Baltic Powers DLC (Danish and Polish civs, DLC Inuits, the new engine build) plus one new historical map. Istanbul and its Ottoman content are held back for the next wave.

## Baltic Powers compatibility (the clean blend)
- The mod now runs on the DLC engine build (25040513) and loads every DLC civ, unit and building side by side with its own content.
- **Art collisions resolved**: mod assets that sat on paths the DLC now uses were renamed, so DLC content renders with its own art again — Polish church, Ukrainian (Cossack) church, Goose, Pig and the Teutonic helmet.
- **Stale overrides retired**: 105 vanilla values the game had added since our copies were made are back (settler fishing animation, healer gather rates, ship stealth mode, 60 trade-route decals, trade-crate techs, Capitol display entry, 12 unit-type registrations, Folwark building transforms, arctic trade-route upgrade paths). The 762-soundset sound override became a small additive file, restoring 268 soundsets.
- **Danish and Polish voices** added to every mod unit that speaks per civ (plus Italian / Maltese / Japanese / Canadian / Haudenosaunee branches that were missing); Mexican units no longer speak Spanish, the Steamer's Japanese crew no longer speaks Portuguese.
- **Folwark, Danish houses and churches, the Sejm** are buildable by all mod villagers; every mod villager can work fishing holes and Folwarks at vanilla rates.
- **Dry Dock** offers the DLC's Whaling Ship and Gunboat.
- **DLC Inuits**: the mod's own Inuit civ was retired in favour of extending the DLC one (same approach as Aztecs and Maya). The Harpooner stays as an elite unit (build limit 7, 240 HP, 26 ranged damage, 100F/100W) on the DLC sled-rider model; Aurora, Inuit Whalers (ships the DLC Whaling Ship) and Inuit Expansion survive; Cold War and Labrador Coast use the DLC settlement.
- **Herdables**: all 17 livestock animals — the DLC Pig and Goose included — can now fatten at the mod's Livestock Pen, Town Mill and Aztec Granary.
- **Strings**: the mod's text block moved off the id row the DLC now uses (no more DLC lines showing mod text); all languages ship the English table.
- Vanilla revolutions remain removed mod-wide; the DLC's revolution routes are handled per map.

## Maps
- **Independence War** — American Revolutionary War map, attackers (Patriots) versus defenders (Loyalists). Fort tables for every player count, symmetric 1v1, harbours, pirate peninsulas, Haudenosaunee settlement ladder, spread estates with a guard gate, full trade loop with harbour crates, hold-the-estates victory countdown, Declaration of Independence flag/name/music. Natives: Colonial Estate, Haudenosaunee, Pirates. Playable civs include Spanish, Polish and the DLC civs.
  - Loyalist politicians let Explorers and War Chiefs build Frontier Forts; Patriot politicians revolt into the American Revolution; Rochambeau's Expedition ships 24 Voltigeurs; American Expeditionary Fleet ships Dispatch Vessels.
  - John Paul Jones as pirate captain: the Bonhomme Richard flagship, the captured Serapis as a second one (Prize of Flamborough Head), replacing Grace O'Malley on this map. Both flagships train the new Pirate Gunboat on water.

### Map updates
- **Paris** — the Seine gets its own warship: River Monitors (see units) are unlocked for every civ at the Dock, Port and Asian Dock in Age III, while the standard warships and the Danish levy gunboat stay banned; the Bourbon settlement's Battleship can no longer be trained on the river either.
- **The First Cold War** — arctic pass with the DLC content: the map now uses the Arctic Territories map types (land and water), the arctic trade route with its umiak trail and level upgrades, tiered walrus herds along the shores, fishing holes on the water, caribou, musk ox and musk deer huntables with the Rockies snow overlays, and the DLC Inuit settlement (Rockies-snow retextured villages) in place of the mod's old Inuit civ; Inuit Whalers ship the DLC Whaling Ship.

## Natives
### Colonial Estate (new)
- City-state native representing colonial nobility. Capturing the estate lets you elect one of six historical personas, each granting two units and four techs, built on the Prince Elector system: King George III (Hannover), James Oglethorpe (Penal Colony) and Jean de Brébeuf (Jesuit) for defenders; Daniel Boone (Frontier Town), Marquis de Lafayette (Sansculottes) and Haym Salomon (Jewish) for attackers.
- Estate Militia, Estate Economy aura, Naval Inventions (unlocks the Dispatch Vessel), Estate Colony Export; Veteran and Guard upgrades covering all estate units; Native Embassy roster.
### Pirates
- Tortuga settlement update: new house set and tower textures.
- Dry Dock mechanics improved: instead of a single automatic workshop, the Dry Dock now has a dedicated maintenance tactic for each ship type it can maintain (Venetian Galley, Privateer, Alexandrian Galley, Ironclad), each unlocked by its own tech. Maintenance can be combined — one dock can keep, say, Privateers and Venetian Galleys in service at the same time — and no tech takes an already-earned ship away any more.
- Pirate Gunboat (see units), trained on John Paul Jones' flagships.
### Penal Colony / Wokou — Mutineer split
- **Mutineer** (Wokou consulate / Cyprus Frigate, and the Great Mutiny mercenaries) rebuilt on the DLC Sailor: blunderbuss with area damage and a Buckshot charge, good against heavy infantry, weak to cavalry; chops wood and repairs ships (Carpentry). Native stats, Sailor portrait, three crew voices (Irish, British, Japanese).
- **Absconder** (Penal Colony, formerly the Australian Mutineer): keeps the knife-thrower design, now a fully separate unit with its own mercenary twin shipped by Great Rebellion. Veteran / Guard / Legendary tiers apply to both families.

## New units and content
- **Dispatch Vessel** — new frigate-class steam warship with its own model and textures, unlocked through the Colonial Estate's Naval Inventions and shipped by the American Expeditionary Fleet (American voice).
- **River Monitor** — a gunboat for every civ on river maps: vanilla gunboat hull with Sailor rowers (Danish and Swedish keep their paddlers), 800 HP, 240w/200g, Age III, build limit 4, no population cost, x3 attack against warships with a minimum range so it has to manoeuvre; no mortar. Unlocked by the map setup; the Danish levy gunboat is banned on those maps.
- **Pirate Gunboat** — pirate crew and captain in a tricorne under the black flag, 1000 HP with the levy's hitpoint drain, 120w/100g, 10 s training, build limit 3, British Privateer voice.
- **Patriot** unit for the Independence War (anim, icons, sounds, Settler Muster spawn ability).
- **Estate Militia** — the Colonial Estate's cheap line infantry (50F/40W, no population cost, build limit 20, Age II), block-trained at the estate and delivered by the Native Embassy; upgraded by the estate's Veteran and Guard improvements.
- **Regal Ship** — heavy double-hulled warship, stronger than a Frigate but slower, with a very powerful broadside (2100 HP, 600w/500g, French crew); arrives with the Sansculotte Imperial Expedition carrying 24 Voltigeurs and benefits from the Imperial Man-O-War upgrades.

## Other improvements
- Fishing-rod and basket attachments for all mod villagers (they animate at fishing holes now).
- Cherry Orchard now dies into its own foundation socket instead of the Vineyard's.
- Herdable fattening rates follow each animal's own vanilla numbers.
- Tooling (not player-facing): map simulator + automatic map checks, pre-zip deployment audit, vanilla-file extraction and merge tools, icon forge.

## AI changes
- The DLC AI core is now the only AI (the pre-DLC core could not load on the new engine build).
- Danish and Polish civ support merged from the community AI: Danish houses, King Christian (fast fortress, trade) and Jan Sobieski (rusher, natives, cavalry) personalities, DLC card handling, economy and tech rules.
- Independence War: AI revolts to side-specific politician sets in the Industrial Age (Patriot personas for attackers, Loyalist for defenders) and needs an estate alliance before electing a leader; AI pirate captain roll includes John Paul Jones.
- Inuit tech monitor rewired to the DLC settlement; Hansa and Cossack monitors carried over.
- AssertiveWall updates: revolution villager-garrison handling, military train-plan buildings.

## Game balance
- Rowboats and Cossack Rowboats are weaker but cheaper.
- American Expeditionary Fleet: 1700 gold, ships Dispatch Vessels instead of Steamers.
- Harpooner rebalanced as an elite unit (see Inuits).
- Mutineer: 150 HP, 80 gold, blunderbuss 12 damage; Absconder unchanged.

## Bugfixes
- Hayreddin Barbarossa spoke with a Cherokee/Cheyenne native voice set instead of the Ottoman one — fixed.
- Veteran and Guard Mutineer upgrades both applied the moment the unit was enabled, so the Penal Colony improvements changed nothing — fixed, they now follow the settlement's Veteran / Guard research.
- Bourbon settlement's Battleship could be trained on river maps after the standard-warship ban — banned with the rest.
- Dry Dock: a Consulate tech typo (Spawnprivateer) left the privateer route silently dead — fixed.
- Pooled build limits on Prince Elector and Estate proxies read as infinite — fixed.
- Cossack church rendered a mixture of mod and DLC textures — fixed by the rename.
- Custom settlers had no animation when working a fishing hole — fixed.
- Livestock Pen / Town Mill could not fatten most animals — fixed.
- Mexican units speaking Spanish, Steamer's Japanese crew speaking Portuguese — fixed.

---
*Held for the next wave: Istanbul (map, House of Phanar, Ottoman politicians, Mediterranean pirates, Sultan Palaces, Fisherman's Guild), Black Sea terrain pass.*
