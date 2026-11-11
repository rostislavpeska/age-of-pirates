# London debug list (2026-09-22, evening state)

One line per item: what was changed, what to look at after a FRESH game launch (every item below needs the
restart: protomods, techtreemods, commands, powers, abilities and strings all changed today), which artifact
proves it without playing, and the fallback if it fails. Work top to bottom; one restart can cover the
whole list because every check is a look, not a play-through, except where marked PLAY.

Artifacts: `T` = `<profile>\Trigger\trigtemp.xs` (read after the generation, before anything else),
`C` = a saved scenario censused with `python sandbox/census/census.py <save> --full`, `S` = a screenshot,
`E` = the editor's Object Info panel. Commits are on branch `inuit-harpooner`.

## A. Before anything: the process

| # | Check | How | Pass |
|---|---|---|---|
| A1 | The game process is newer than the XMBs | PowerShell: `(Get-Process AoE3DE_s).StartTime` vs `Get-Item data\techtreemods.xml.xmb` (and protomods, protounitcommandmods, abilities\powermods, abilities\abilitymods, strings) | process start later than every .xmb |
| A2 | The map compiles | generate once in the editor; `<profile>\RandMaps\Age3DERM00000_zplondon.dmp.txt` refreshed | dump present, no "failed to load" |
| A3 | No dead unit selections | `python .claude/skills/rm-trigger-testing/scripts/trigtemp_check.py` (the separate session's skill) or `grep -c 'trUnitSelect("' T` | 0 |

## B. London Bridge (commits 2fd4c579 .. 240a4195)

| # | Check | How | Pass | If it fails |
|---|---|---|---|---|
| B1 | Four `deSPCSocketCityTower` sockets stand at the tower spots, last four units of the export | E: click a socket; C: the four last indices of the bridge block | proto name deSPCSocketCityTower | export not deployed / stale process (A1) |
| B2 | Four gaia `deSPCCityTower` stand on them from the start (built for player 1, converted to gaia in the same trigger, again at 2 s) | S at 0:05; E: owner Gaia | towers present, gaia | T: `_BridgeTowers_Setup1` has `trSocketBuild(1, "281".."284", "deSPCCityTower")`; if present and no tower: the deck; try one socket on the bank (fallback: bake the towers into the export) |
| B3 | The deck is not deformed under the towers | S | flat deck | deSPCCityTower keeps FlattenGround; fallback: a Flat clone AGAIN but of deSPCCityTower with the tower techs' targets extended (data) |
| B4 | Player 1 does not keep LOS / ownership blips | S at 0:05 as player 1 | no blue towers | the 2 s safety convert missed: lengthen |
| B5 | The gates stand at start (gaia's zpConverGate on the two generic placeholders) | S | two gates | LondonStartingTechs dropped (A3, a TechID unresolved) |
| B6 | Bridge walls are props, off the minimap: `deSPCFortWallLargeProp` x4, `zpSPCFortCornerPropFlat` x4 | E | not selectable / no HP | export not deployed |
| B7 | PLAY: a Trading Post on the port socket (the Toll Station) converts gates, walls, corner props, sockets, towers to the owner | build one TP | all bridge units the owner's colour | T: `_Bridge_ON_Plr<k>` condition `trCountUnitsInArea("<port socket index>",k,"TradingPost",8)`; the TP must be within 8 m of the port socket, NOT on the land route's own socket 10 m away |
| B8 | PLAY: losing the post hands everything back to gaia | delete the TP | gaia again | `_Bridge_OFF_Plr<k>` |
| B9 | PLAY: a gate destroyed BEFORE the capture is rebuilt once at the capture (E/F sockets, zpConverGate5/6) | kill a gate, then capture | new gate | `_BridgeGate1_Rebuilt<k>` fired within 500 ms; the transform consumed the socket - one rebuild per gate is the Bohemia law |
| B10 | The tower techs are researchable at a captured tower | click an owned tower | DESPCCannonTowers, DESPCTraceItalienne in the menu | setups' `TechStatus obtainable` lines |
| B11 | AI rebuilds a destroyed tower on its socket (proxy) | PLAY with an AI ally on the bridge | tower returns within ~1.2 s | `_BuildTowerB1_ON_Plr<k>` active for AI players; the proxy command on deSPCSocketCityTower (zpSPCLondonAI) |

## C. The Royal Keeps (the two Tower exports; commits 0e7a6bf4 .. 8ac63e04)

| # | Check | How | Pass | If it fails |
|---|---|---|---|---|
| C1 | Four `zpSPCSocketCityTowerWooden` sockets at the corners, last four units of each export | E, C | proto name | export not deployed |
| C2 | Long walls are `deSPCFortWallLargeProp` (not selectable) | E | no HP bar | export |
| C3 | Two gates + `zpInvisibleGateSocketA/B` (C/D north) under them | C | four sockets in the two blocks | export |
| C4 | PLAY: capturing the flag converts building, gates, sockets, built towers, wall props | flag flips | everything the owner's colour | `_TowerConvS_Plr<k>` sweep from the building at 40 m, all source players |
| C5 | PLAY: the flare fires ONCE per capture, for the capturing team, at that Keep; no persistent flare | minimap | one flare, 10 s | 8ac63e04 removed Towers_ON; if a flare persists, T: which rule loops |
| C6 | PLAY: a gate missing at the capture is rebuilt once | as B9 | new gate | `_TowerSGate1_Rebuilt<k>` |
| C7 | PLAY: the owner can build wooden towers on the sockets | click a socket | zpSPCCityTowerWooden | the socket command; the socket must be the owner's |
| C8 | PLAY: victory - both flags one team 480 s | hold both | counter, then Team Victory | `_Victory_Counter<i>` / `_Victory_Counter_OFF<i>` |
| C9 | Names: the building is "Royal Keep", the objectives say "both Royal Keeps" | objective screen | new strings | strings not rebuilt / stale process |

## D. Harbours (fix B, indices moved 2026-09-22)

| # | Check | How | Pass | If it fails |
|---|---|---|---|---|
| D1 | All four harbours lock at start and release when their guard nugget is collected | PLAY one | release | the guard literals 366/371/376/381 assume the bridge gained exactly +3 units before section 8: C on a save, find the four `ypNuggetTradingPost`, update the eight numbers in the id block |

## E. Big buttons and revolt (commits 324ab9ea, 53164f58, 18a78614)

| # | Check | How | Pass | If it fails |
|---|---|---|---|---|
| E1 | Attacker: the Stuart big button (Divine Right of Kings, zpStuartExpansionSPC) shows on a Stuart post | click the post | button present, researchable at Fortress | 53164f58 added the hub grant; if still hidden: `DENativeStuart` block, Colonialize block |
| E2 | Attacker: the Parliament button shows greyed WITH name and the "Only the DEFENDERS..." text | hover | tooltip 503565 | the fake power's rolloverid; if no tooltip at all, the UI reads the associated tech: give `zpNatParliamentoffShadow` a displaynameid/rollovertextid |
| E3 | Defender: the reverse (Stuart greyed with 503566, Parliament live) | as above | | |
| E4 | No AI on the attackers' team ever revolts to the Commonwealth | PLAY to Industrial with AIs | attackers stay | 14.4 wraps `if (rmGetPlayerTeam(k) == 1)` |
| E5 | A defenders' AI revolts only while holding a Parliament post, at Industrial | PLAY | | `_ZP_Timer_Revolution<k>` / `_ZP_Execute_Revolution<k>` gated on cTechzpNativeParliament |
| E6 | Human: researching the Remonstrance still works (Activate Parliament, leader pick) | PLAY | leader cards | unchanged since 2026-09-19 |

## F. Setup and look (commits 324ab9ea, 18a78614)

| # | Check | How | Pass | If it fails |
|---|---|---|---|---|
| F1 | Population cap 250, no house build button | HUD | 250 | setups |
| F2 | Military Camp on the Explorer's build menu | click the Explorer | camp | setups |
| F3 | Cathedral techs (Papal Legate, Excommunication) and bank techs (Bank Loan, Mercenary Bounties) researchable | click the cathedral / bank | | setups |
| F4 | The bridge socket is called Toll Station with the toll icon (gaia included) | click it | 501979 | the 0..N loop in LondonStartingTechs |
| F5 | Embassies use the European design, gaia's too | S | European model | cTechdeEUMapUpdateVisuals in the 0..N loop |
| F6 | Waterloo house props are off the minimap (and red, no smoke - Paris's animfile line; strike it if unwanted) | minimap, S | | zplondon.mods.xml |
| F7 | Player buildings snap to the city grid (Paris's placement rules) | place a house... (houses are off) place a market | grid placement | zplondon.mods.xml |
| F8 | Fort gates rebuild instantly (buildpoints 0) | PLAY | | zplondon.mods.xml SPCFortGate |

## G. Known unknowns (not proven by anything offline)

- G1 `Socket Build` for player 1 on gaia-owned-then-converted sockets on the DECK with an AIR unit: three
  earlier failures were with a LAND unit; the air variant is Venice's precedent, not yet seen on London.
- G2 FlattenGround stays on deSPCCityTower (Venice never removes it); the deck may still deform (B3).
- G3 The marker arithmetic (`rmGetUnitPlaced + 3 - n`) was confirmed for the bridge by the compiled ids
  281-284 matching the predicted indices; the Keeps' markers are inferred the same way (C: check the four
  socket indices of each Keep against the echo line `LONDON ids: tower markers`).
- G4 The greyed fake button's tooltip source (power vs associated tech) - E2.
- G5 The guard literals after the bridge grew (D1).

## H. Order of work

A1-A3 first (no play). Then one generation, screenshots for B1-B6, C1-C3, C9, F1-F7 (no play). Then the
PLAY items in this order: D1, B7-B8, C4-C5, E1-E3, C8. One hypothesis per restart; when an item fails,
read T before changing anything, and paste the rule (the whole `rule _Name` block) into the chat.
