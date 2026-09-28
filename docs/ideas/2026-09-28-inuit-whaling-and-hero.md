# Inuit whaling by map type, and the Inuit tech as a hero (PARKED)

Status: **parked idea, 2026-09-28.** The owner keeps an eye on it; nothing is implemented or approved. The owner's
view: a new map type (`inuitwhaling`) is unique, so it cannot clash with any other map.

## The problem

- The Inuit tech `zpInuitUmiaks` (`data/techtreemods.xml`, Trading Post button page 2 column 6) ships 2
  `deOutlawWhalingShip` and enables them at the Dock. Since the 2026-09-11 "Arctic pass" (`ca2b2f7b`), it no
  longer ships 3 `zpInuitWarCanoe`.
- Every map- or native-dependent ship in vanilla shares ONE Dock button (page 0, column 6), in this order: Canoe,
  Wokou Junk, Marathan Catamaran, African Catamaran, Privateer, Merc Battleship, Whaling Ship, Xebec, Dhow. Only one
  can show.
- Vanilla `DENativeInuit` (the Inuit alliance itself) enables the **Canoe**. So after an Inuit alliance, the Canoe
  sits ahead of the Whaling Ship on the European Dock, and the whaler button is most likely hidden. Which entry wins
  when two are enabled has not been checked in game. Native American civs have the Canoe from the start. The Asian
  Dock (column 5), the African Port (column 4) and `zpDrydock` (page 1) list the whaler on their own buttons.
- Since that commit, `zpInuitWarCanoe` (Dock column 12, its own button) is enabled by nothing: an orphan.

## How vanilla ties ships to a map (background)

`rmSetMapType("<type>")` makes the engine apply that type's block in `Data/mapspecifictechs.xml` plus the mod's
`data/mapspecifictechmods.xml`. Each call adds its block. `<forcetech>` techs are activated for every player at game
start. A new type must also be registered in `data/maptypemods.xml`. Examples of ships tied to map types:

| Mechanism | Vanilla example |
|---|---|
| a forced flag + a Shadow tech with that flag as prereq | `deMapAfricanCoast` + `deCatamaranAfrican` (horn, swahilicoast) |
| a forced ship tech | `DESaloonXebec` (gold/ivory/pepper coast, niger delta, tripolitania), `DESaloonDhow` (borneo, ceylon, highlands, sudd) |
| a native alliance marks a Shadow obtainable; the map flag decides whether it fires | every Asian native sets `YPNativeJunk` (needs `ypMapFarEast`) and `YPNativeCatamaran` (needs `ypMapIndian`) |

`deMapArctic` (arcticterritories) is cosmetic only: trade ships renamed Umiak/Icebreaker, white wolves. No vanilla
map type unlocks whalers; vanilla has them only through the Fortress-age card `DEHCHireWhalingCrew2`.

## Part 1: whalers from the map

- **New map type `inuitwhaling`:**
  - register it in `data/maptypemods.xml`;
  - add a `<map name="inuitwhaling">` block in `data/mapspecifictechmods.xml` forcing `zpMapInuitWhaling`;
  - rebuild both XMB twins.
- **Techs** (`data/techtreemods.xml`, next to each other, as TEST-free production records):
  - `zpMapInuitWhaling`: an empty Shadow flag.
  - `zpInuitWhalingShips`: Shadow, OBTAINABLE, prereqs the flag + `Colonialize`, so it activates at Age 2. Pattern:
    `zpInuitAcclimationBig`. It enables `deOutlawWhalingShip` and moves its button to the free **column 9** on
    `Dock`, `YPDockAsian` and `dePort`: CommandRemove + CommandAdd proto, the pair `zpNatInuitInfluence` already
    uses on the Trading Post. No other ship can then hide it.
- **Maps:** `rmSetMapType("inuitwhaling")` in `game/randmaps/zpcoldwar.xs` and `zplabradorcoast.xs`, and in
  `zpunknown.xs` only inside the two Inuit branches (lines ~8331 and ~8793). zpunknown would set the type late in
  the script, so one in-game check is needed.
- **The ship:** `deOutlawWhalingShip` costs 400 gold / 100 wood, has 1,500 HP, and is a fishing boat,
  poison-bolt warship and 50-slot transport in one, capped at 3. From Age 2 for every player on those maps is a
  balance call.
- **AI:** it will not train them; teaching it is an AI change (AGENTS.md rule 7) and not part of this idea.

## Part 2: the Inuit tech ships a hero instead

- **Precedents to copy:**
  - Vanilla `DENatBerberDynasties` (250 food / 250 wood / 250 gold) ships the Berber Sultan and enables two merc
    units only he trains.
  - Ours: `zpNatHabsburgPizarro` ships `zpSPCPizarro`, who trains `zpNatMercHuaminca` (own cap 7) at page 6
    column 5.
- **Hero proto** (a copy of the `zpSPCPizarro` block, next id above the TEST marker):
  - **Look:** the vanilla arctic Regicide Regent, referenced by path: model `units\trade\arctic_trader\arctic_trader`
    with `materialvariant index="1"` (the `arctic_regent_mata_*` textures), portrait
    `resources\art\units\spc\regent\regent_arctic.png`. Selected in vanilla by `bpRegicideArcticMap` in
    `units\spc\regent\regent.xml`.
  - **Weapon:** the harpooner's harpoon (`units\spc\outlaws\harpoon` on `BIP01 PROP1`) and its standard
    `animation_library` anims. The arctic trader plays standard library anims in the regent file, so the skeletons
    should match. One bench test confirms it; fallback: the regent's knife.
  - **Behaviour:** revivable (`KnockoutDeath`), limit 1. Trains a Trading Post and the existing
    `zpNatMercInuitHarpooner` (id 21192): same stats as the Trading Post Harpooner, own cap of 12, no shared pool
    (`scripts/mapcheck/tests/test_inuit_harpooner.py` pins that).
  - **Files:** a new animfile + `_snds.xml` (CRLF), tactics naming only anims the animfile has (the known crash
    class).
- **The tech keeps its internal name `zpInuitUmiaks`.** The Trading Post button and the AI's
  `zpInuitTechMonitor` (`game/ai/core/aipiraterules.xs` ~4894) keep working without an AI change.
  - **New effects:** ship the hero + 4 merc Harpooners, enable `zpNatMercInuitHarpooner`.
  - **Gather point:** `CheckWaterHCGatherPoint` becomes `CheckLandHCGatherPoint`.
  - **Strings:** new name and rollover (ids 500598/500601, `aoe-game-text`), hero name and rollover new;
    `stringsync --build` for 14 languages.
- **AGENTS.md rule 9 deletion, needs the owner's yes:** remove `FreeHomeCityUnit 2 deOutlawWhalingShip` and
  `Enable deOutlawWhalingShip` from `zpInuitUmiaks`.

### The hero: Tuglavina

Tuglavina (c. 1738-1798), a leader among the Labrador Inuit. He began as an angakok (spiritual authority) and became
a successful trader and middleman, sailing a two-masted sloop between the European posts and the northern Inuit. He
piloted and guided the Moravian missionaries, took four wives (a sign of exceptional prestige), and was ambitious
and, in later years, obsessed with the fear of revenge for past killings. He was baptised at Chateau Bay in 1783
and died at Nain on 4 October 1798. Personality for the game: a proud, cunning trader-chief who hires fighters.

Alternative: Mikak (c. 1740-1795), his wife from about 1770. She was captured after the 1767 attack on Nicholas
Darby's fishing station at Cape Charles and taken to London in 1768, where John Russell painted her in a dress from
the Dowager Princess of Wales. She helped the Moravians win their grant (1769) and choose the site of Nain (1771).
There is no female regent model, so she fits a line in the tech's description rather than a hero.

Why the swap is historical: the whaling ships in these waters were European (Basque stations in 16th-century
southern Labrador, later Dutch, English and Danish fleets). The Inuit hunted from umiaks with harpoons and traded
baleen with those stations. So the ship comes from the coast (the map), the harpooners and their leader from the
Inuit.

Sources: Dictionary of Canadian Biography, [Tuglavina](http://www.biographi.ca/en/bio/tuglavina_4E.html) and
[Mikak](http://www.biographi.ca/en/bio/mikak_4E.html).

## Open decisions (defaults in bold)

1. Rule 9: remove the two whaler effects from `zpInuitUmiaks`: **yes** / no.
2. Whalers from Age **2**, or Age 3 like the vanilla card.
3. Tech cost **unchanged** (600 wood / 200 gold, Fortress prereq), or 250/250/250 like `DENatBerberDynasties`.
4. Hero **Tuglavina with a harpoon** (knife fallback).
5. **4** merc Harpooners shipped; hero-trained pool **12**.
6. The orphaned `zpInuitWarCanoe`: ship a few with the hero (the umiak is the Inuit whaling boat), or delete it
   (rule 9 again).

## Verification when built

- Offline: `xmlcheck.py`, mapcheck, `scripts/mapcheck/tests` (incl. `test_inuit_harpooner.py`), new pins for the
  map type, both techs and the hero's train list.
- In game (screen control, AGENTS.md rule 11: announce first): a unit bench of the hero (renders, harpoon, anims),
  and one zpcoldwar skirmish (whaler button on Dock column 9 from Age 2).
