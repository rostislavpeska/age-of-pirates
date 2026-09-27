# London countryside resources: why they spawn unevenly, how many, and the fix plan

Written 2026-09-27 for the owner's decision. Scope: ONLY the countryside objects beyond the city walls (tin mines,
deer herds, berry clusters) in `randmaps/zplondon.xs` section 12.7. Not in scope and not touched: the city, the
player seat blocks, the map frame, terrain, nuggets, forests.

## 0. Answer in short

The countryside tin, deer and berries are scattered at random over each bank's whole countryside with
`rmPlaceObjectDefInArea` (`zplondon.xs:1751-1781`). Nothing mirrors the two banks, and the fences leave so thin a
band that the engine silently gives up on part of the request: the 1v1 save has **0 of 4** tin mines. The fix keeps
the owner's approach: place into the two countryside areas, with the same-kind spacing. It places one object per call
and retries with looser fences while a call comes back empty, the repo's tiered fallback (`zpcoldwar.xs:10-45`).
Counts follow the total player count, the same number on both banks.

## 1. Why the spawn is asymmetric (measured)

Countryside objects beyond the city wall in the four saved London generations
(`<profile>\Scenario\*.age3Yscn`, parsed with `sandbox/census/census.py`; MineTin is placed only by the countryside):

| Save | Frame | Tin asked (S+N) | Tin placed S / N | Deer S / N | Berries S / N |
|---|---|---|---|---|---|
| `gt_zplondon_P2T2` (1v1) | 645 m | 2 + 2 | **0 / 0** | 9 / 12 | 3 / 5 |
| `mapview_london4p` (2v2) | 685 m | 3 + 3 | 2 / 1 | 12 / 8 | 9 / 6 |
| `london_editor_check_1` (2v2) | 685 m | 3 + 3 | 1 / 1 | 7 / 21 | 10 / 7 |
| `gt_zplondon_P6T2` (3v3) | 765 m | 4 + 4 | 4 / 3 | 30 / 20 | 12 / 15 |

The 12.7 placement lines are unchanged since 2026-09-22 (`git blame`: 593a6e21), so every save ran today's code.

Three causes, in order of weight:

1. **Random scatter, no mirror.** One `rmPlaceObjectDefInArea(def, 0, bankArea, count)` per bank: the engine picks
   independent random tiles on each bank. Even when both counts come out right, the positions never match.
2. **Silent shortfall in a thin band.** The countryside is 66-72 m deep on the 1v1 frame, ~90 m on 2v2 and
   ~113-132 m from 3v3 up. The fences on each object: 20 m off every wall object (`avoidWallObjXL`), 8 m off the
   map edge (`insideFrame`), the wall hills reaching ~31-37 m out in the four gaps (`avoidCliff5`), the quays
   (`avoidPlateau8`), 8 m off the trade route, and 60 m between tin mines. On 1v1 about 40 m of depth is left; the
   engine's attempts land mostly on fenced tiles and it stops short, differently on each bank. The shortfall
   shrinks as the frame grows (1v1 0 %, 2v2 ~33-50 %, 3v3 88 %).
3. **Counts follow each bank's own head-count** (`seatsBankD / seatsBankA`, 1723-1731), so uneven lobbies differ by
   design. The owner wants the total player count instead (section 4).

Not a cause: the herd size `rmRandInt(6, 8)` is drawn once per object def, so both banks get the same herd size.

## 2. What the groupings already give each side

Per-unit amounts: vanilla `scripts/source/protoy.xml` and `data/protomods.xml`. MineTin 1500 coin, MineGold 5000,
deMineCoalBuildable 2000, zpSPCMineTin 1500, zpValuableSource 1000; Deer 400 food, zpGoose 400, BerryBush 1000,
menagerie animals 500-1000. Duck, DuckFamily and Wolf hold nothing.

Per bank, every lobby: the Bank block (4 x zpValuableSource = 4000), the Gold Smelter block (MineGold + 3 coal =
11000), the big park (zpSPCMineTin 1500) = **16500 coin**; the big park's 18 deer + the menagerie = **12440 wild
food**; the Food4 mill's 12 berry bushes = 12000 food.
Per seated player (1-4 per side, `EU_SPC_Player_London`): 2 coal mines (4000 coin), 3 deer + 14 geese (6800 wild
food), 6 berry bushes (6000). 1v1 only: the turned park `EU_SPC_Park_big_02` adds 18 deer (7200) per side.

| Players per side | Coin from groupings, side | per player | Wild food, side | per player | Berries, side |
|---|---|---|---|---|---|
| 1 | 20500 | 20500 | 26440 | 26440 | 18000 |
| 2 | 24500 | 12250 | 26040 | 13020 | 24000 |
| 3 | 28500 | 9500 | 32840 | 10946 | 30000 |
| 4 | 32500 | 8125 | 39640 | 9910 | 36000 |

The city already gives a 1v1 player 20500 coin. One countryside tin mine (1500) is a 7 % top-up, so the owner's
"one tin mine is enough for 1v1" holds.

Flag, out of scope: with 5+ on one side (uneven lobbies only) the grass-strip seat kit (`zplondon.xs:1583-1616`)
has no geese, so that side's wild food drops from ~9900 to ~3700 per player.

## 3. How other maps do it

Survey of 2026-09-27: the vanilla maps read as loose files in the Steam `Game\RandMaps` folder; the mod maps in
`randmaps/`. Counts are the requested numbers.

| Map | Extra mines | Hunts | Berries | How the sides stay even |
|---|---|---|---|---|
| Great Plains, New England, Carolina, Saguenay, Yukon, Colorado (vanilla) | 3 per player, map-wide (+ the starting mine) | 2N-6N herds | Carolina only, N clusters | team games: randomness only; 1v1: hand-mirrored coordinates |
| Texas, Colorado, Dakota (vanilla) | 3 per player | 1.5N mirrored pairs | none | **Riki's pair loop**: place A with every fence at max 0 m, and only if it lands, B at the mirror point |
| Florence (mod) | 2 + N per team side | 2 + N/2 ibex herds | none | equal counts into mirrored areas |
| Istanbul (mod) | 2 + N/4 flank + 1 + N/4 fill per side | same as mines | none | point-mirrored area pairs |
| King of Bohemia, Crownlands (mod) | 2N per half | 3N elk per half | N per half | North / South pie halves |
| Venice City, Elbe (mod) | 1 + 1.5N / 1.5N per island | 2N / 3N | N / 1 | per-island areas |
| Paris (mod) | 2 per side, only from 4 players | deer in tree clumps | none | mirrored areas; a trigger scales the city mines' amounts by ~0.5 N |

Conclusions for London:
- Vanilla gives about 8000 coin per player on the whole map (3 extra silver mines + the starting one, 2000 each),
  the same per player in every lobby size. London's groupings alone give 20500 per player in 1v1 and 8125 in 4v4
  (section 2). London's countryside can therefore be much thinner than vanilla's 3 per player.
- The mod maps give equal counts to mirrored areas. That makes the request even, not the outcome, which is London's
  bug. Only Riki's pair loop guarantees that both sides get the same.
- Florence, Istanbul and Paris already give bigger games less per player, as the owner wants for London.

## 4. Proposed counts (owner decision)

One number per bank, the same on both banks, from the total player count P (`cNumberNonGaiaPlayers`):
**K = (P + 1) / 2** (integer division). Tin mines, deer herds (6-8) and berry clusters (5) all use K.

| Lobby | P | K per bank | Tin now (per bank) | Coin per player, proposed (now) |
|---|---|---|---|---|
| 1v1 | 2 | 1 | 2 | 22000 (23500) |
| 2v1 | 3 | 2 | 3 / 2 | side of 2: 13750, side of 1: 23500 |
| 2v2 | 4 | 2 | 3 | 13750 (14500) |
| 3v2 | 5 | 3 | 4 / 3 | side of 3: 11000, side of 2: 14500 |
| 3v3 | 6 | 3 | 4 | 11000 (11500) |
| 4v3 | 7 | 4 | 5 / 4 | side of 4: 9625, side of 3: 11500 |
| 4v4 | 8 | 4 | 5 | 9625 (10000) |

Bigger teams get less per player, as asked: the city's fixed share is split among more players and K grows by one
per two players. Deer herds move from players-on-bank + 1 to K (1v1: 2 herds to 1; the turned park already adds 18
deer there). Berries stay at one cluster per player in even lobbies.

## 5. Fix plan

**Owner's decision, 2026-09-27: no architecture change; implemented the same day.** The counts are K = (P+1)/2
per bank for tin, deer and berries (section 4). Tin, deer and berries got looser fences: 4 m off the map edge
instead of 8 m (`insideFrameRes`), 10 m off the walls instead of 20 m (`avoidWallObjTree`), 4 m off the plateaus
instead of 8 m (`avoidPlateauShort`). The same-kind spacing and the treasures' strict set are unchanged.
`test_london_roles.py` pins the new values. The steps below are the fallback if an editor generation still shows a
shortfall.

The owner's approach: keep `rmPlaceObjectDefInArea` into the two countryside areas (`countryD`, `countryA`) and
keep the same-kind spacing fences (tin 60 m, deer 40 m, berries 40 m; `zplondon.xs:471-473`). That is today's
mechanism, so on its own it reproduces section 1. Two additions from blocks the repo already runs make it hold. All
changes stay inside 12.7 (`zplondon.xs:1705-1781`) plus one helper above `main`.

**Step 1 - one object per call, with a tiered fallback.** Copy `zpPlaceWalrusHerd` (`game/randmaps/zpcoldwar.xs:10-45`;
the pattern in `.claude/skills/rm-objects-herds`): a helper that places ONE object into one countryside area and falls
through while `rmGetNumberUnitsPlaced` is 0. Each tier is a fresh def with min 0 / max 0.5 map fraction, as in the
worked example:
- tier 1: today's fences, including the same-kind spacing;
- tier 2: without `avoidPlateau8` (the quay fence that already had to leave the forests, `zplondon.xs:1810-1813`),
  and 12 m off the walls instead of 20 m;
- tier 3: only the frame, world circle, cliffs, trade route, and the same-kind spacing at half distance.
The herd size is rolled once per pair and passed in, so both banks' herds match (a fresh def re-rolls
`rmRandInt`). The helper returns the tier that landed; `rmEchoInfo` prints it.

**Step 2 - pairs, bank by bank.** `for (k = 1; <= K)`: the helper on `countryD`, then on `countryA`, for tin, then
deer, then berries (fussiest first, as today). Both banks get the same number of calls, and each call retries until
something lands. The counts come out equal unless a bank fails all three tiers, and the echo names that case.
Positions stay random within each bank, as on vanilla team maps; the same-kind fences keep them spread. If
mirrored positions are wanted later, vanilla's pair loop "Symmetrical Mines - from Riki" (`texas.xs:1317-1380`,
hunts at 1701) is the drop-in.

**Step 3 - counts.** Replace `seatsBankD + 1`, `seatsBankA + 1`, `seatsBankD`, `seatsBankA` in the six calls with
K from section 4. `seatsBankD/A` stay for the echo line.

**Step 4 - offline checks, no game.**
- `python -m pytest scripts/mapcheck/tests -q -k london` (the London suites; the Steam twins `00000_zplondon.xs` and
  `000000_zplondon.xs` stay byte-identical through the sync hook).
- A new test `scripts/mapcheck/tests/test_london_countryside.py` that reads 12.7 and asserts: K = (P+1)/2 for
  P = 2..8, one formula for both banks, the same number of helper calls on `countryD` and `countryA` for each kind,
  the three tiers present, and the same-kind spacing fences present in tier 1.
- `python -m scripts.mapcheck randmaps/zplondon.xs --matrix` shows no new FAIL.

Trigger safety, checked: every London trigger finds its units dynamically (`rmGetUnitPlaced` + shift, grouping
instance lookups, `zplondon.xs:1993-2054`). No literal unit id appears, so changing the countryside counts moves
no trigger target.

**Step 5 - one editor generation per frame, only on the owner's word.** `000000_zplondon` (top of the Type list):
1v1, 2v2 and 4v4, each saved and counted with the census script used for section 1. Pass criterion: per bank,
exactly K tin mines, K herds and K berry clusters, the same on both banks, no two of a kind closer than their
spacing fence.

## 6. Decisions for the owner

1. The counts: K = (P+1)/2 per bank for all three kinds (section 4), or tin only with deer and berries unchanged.
2. The 5+ per side geese gap (section 2) is out of this task; say if it should become its own task.
