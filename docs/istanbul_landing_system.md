<!--
  REWRITTEN 2026-09-01. The previous version of this file documented
  `rule istanbulLanding` (aipiraterules.xs:8262-8835). That rule was DELETED by
  570d65a2 on 2026-08-27; aipiraterules.xs is now 7930 lines and the citations
  pointed past the end of it.

  Every line number below was re-verified against the working tree on
  2026-09-01. Where a claim rests on an engine primitive with no XS definition
  in this tree it is marked UNKNOWN, as before. Line numbers are valid for
  aipiraterules.xs at 7930 lines and aiassertivewall.xs as of this date -
  re-check them after any edit to either file.
-->

# THE ISTANBUL LANDING — stock AssertiveWall, by design

**Istanbul uses AssertiveWall's own amphibious system. There is no custom
landing rule, and that is deliberate: the stock path performs better than the
bespoke one it replaced.**

The map keeps only three concerns of its own — pirates, palaces, and water
forts with their guardians. Everything about getting troops across the water is
the stock AI's business.

---

## 1. WHAT CHANGED, AND WHEN

`570d65a2` (2026-08-27) removed the custom landing: "-995 lines per tree".
Deleted with it: `rule istanbulAmphibiousGate` (the "a fixed gun must die
first" gate, which the AI never obeyed and which could deadlock the map) and
`rule istanbulLanding` itself.

**The forbid went too.** The Istanbul block in `aipiraterules.xs` (opens at 200
`if (getGaiaUnitCount(cUnitTypeIstanbulVictoryObject) > 0)`) no longer writes
`gAmphibiousAssaultStage = cForbidAmphibiousAssault`. The only two remaining
writes of that constant belong to other maps: 136 (`zpvenicecity`) and 299
(`zpKingsHillNaval`). So on Istanbul the stage starts at its default and the
stock system is free to run.

What the Istanbul block still sets, and why it matters to the landing:

| Line | Statement | Effect |
|---|---|---|
| 224 | `gStartOnDifferentIslands = true;` | the naval master switch — read in ~120 places; without it dock priority drops to 60, the Age-3/4 dock clauses vanish, naval cards and techs are skipped |
| ~232 | `aiSetWaterMap(...)` | `aisetup.xs:1197` does this for island maps, but setup has already run by the time this rule fires, so it must be repeated |

`gIsArchipelagoMap` is **not** set for Istanbul (the write at 149 belongs to a
different map block). That matters — see §2.

---

## 2. THE STOCK PATH, AS IT NOW RUNS

Entry: `game/ai/core/aiassertivewall.xs:8667`
`bool amphibiousAssault(vector location = cInvalidVector)`

Two early exits, both verified:

- **8670** `if (gIsArchipelagoMap == true) return false;` — Istanbul does not set
  this flag, so it does not fire here.
- **8676** `if (gAmphibiousAssaultStage > cGatherNavy) return false;` —
  `cGatherNavy = 0`, `cForbidAmphibiousAssault = 99` (`aiglobals.xs:135, 141`).
  With the forbid gone this no longer blocks the first call.

Then the location chain (8681-8697):

```
8682  location = guessEnemyLocation();          <- the caller's argument is DISCARDED
8686  if invalid -> selectForwardBaseBeachHead()
8691  if invalid -> guessEnemyLocation() again
8694  if still invalid -> return false
8699  gAmphibiousAssaultStage = cGatherNavy;
8701  gAmphibiousAssaultTarget = selectPickupPoint(location, ourBase, 10, false);
8708+ plan created, cPlanReserve, cUnitTypeAbstractWarShip
```

`selectPickupPoint` is `aiassertivewall.xs:7144`, signature
`(friendlyLoc, enemyLoc, stepsBack = 1, waterBool = false)`. Note the call at
8701 passes the **enemy** location as `friendlyLoc` — arguments inverted on
purpose.

**The terrain vocabulary is one test.** `getCoastalPoint`
(`aiwaterrules.xs:403`) decides everything at 419
`if (kbAreaGetType(testAreaID) == cAreaTypeWater)`. There is no
`cAreaTypeImpassableLand` test and no `kbCanPath2` anywhere in
aiassertivewall.xs / aiwaterrules.xs / aiutilities.xs. **A cliff shelf is "not
water", therefore a beach.** This is the known limitation recorded in
`ai_technical_debt.md`, and it is now live rather than hypothetical.

`selectForwardBaseBeachHead()` contains **no terrain test at all** — its checks
are map bounds, black tiles, distance to enemy buildings, a 50 m exclusion, and
area-group tests. A fort build plan can still be aimed across water at an
untested shelf.

---

## 3. THE LANDING IS UNOBSERVABLE — measured, not assumed

```
grep -c aiEcho game/ai/core/aiassertivewall.xs   ->   0
```

**AssertiveWall contains no echo statements whatsoever.** It cannot report what
it is doing.

Confirmed empirically: across 6 one-hour test runs plus a baseline game — seven
AI players each, ~110,000 log lines total, with `showAiEchoes` and
`generateAIEchoesOutput` both enabled in `user.cfg` — there were **zero** lines
matching amphibious / landing / transport / eject / beachhead / coastal /
dropoff.

So the absence of landing output is not evidence of a problem, and equally
**a landing failure would leave no trace**. If the landing needs diagnosing, the
only routes are: add echoes to a copy of AssertiveWall, or observe in-game.

---

## 4. WHAT THE MOD STILL OWNS

Eight rules, enabled at `aipiraterules.xs:276-293`:

| Rule | Lines | aiEcho | Observed over 6 runs |
|---|---|---|---|
| `istanbulAttackKOTH` | 78 | **0** | silent by design — absence proves nothing |
| `istanbulGuardianKiller` | 180 | 3 | `GUARD` — tasks ships ~00:05-00:09 only |
| `istanbulDefendKOTH` | 230 | 2 | **never observed firing** |
| `istanbulPalaceMission` | 206 | 7 | `PALTRACE` / `PALACE` — adoption starts ~00:42 |
| `istanbulPalaceHomeKiller` | 221 | 7 | `PALACEHOME` — 500-900 events |
| `istanbulPalaceHold` | 90 | 1 | `HOLD` — 1,200-1,400 events |
| `istanbulFortRaid` | 148 | 1 | `RAID` — 0-7 events, sometimes none |
| `istanbulAreaRecalc` | 9 | 1 | exactly 7 (one per AI) at 00:01:31, as designed |

Measured behaviour worth acting on:

- **The guard starves.** `GUARD ... N ships onto guardians` fires only in the
  first ~9 minutes; after that `GUARD ... plan EMPTY - no free ship below pri
  90` repeats 306-444 times per run until ~00:38, then stops. Ratio of refusals
  to successes is 7:1 and worsens run over run.
- **Palace adoption is late and rare.** First adopt at 00:41-00:45 of a
  60-minute game; 11-38 adoptions against 6,800-8,000 `GETPALACE` lookups.
- **`PALTRACE` is ~45% of all AI output** and repeats identical content every
  tick. It is the reason a one-hour run produces ~3 MB of logs.
- **Fort garrisoning is the healthy subsystem** — 3,300-4,200 events spread
  evenly across the whole match.

---

## 5. HOW TO OBSERVE

`user.cfg` in the **profile** folder (not the Steam install) already carries
`showAiEchoes` and `generateAIEchoesOutput`. The engine writes
`Logs/Age3DEAIOutputPlayer<N>.txt` for the PREVIOUS match, at the moment the
next one starts — so a multi-run batch keeps only the last run unless something
copies them in between.

```
aitest/ai_collect.py --watch      archives every set before it is overwritten
aitest/ai_report.py               echo composition per player
aitest/ai_behaviour.py            events on a timeline: what actually happened
```

The files are UTF-16. `Age3Log.txt` carries no aiEcho lines — the per-player
files are the only source.

---

## 6. WHAT THE OLD DOCUMENT GOT RIGHT, AND WHERE IT LIVES NOW

The deleted `istanbulLanding` analysis is in git history at
`docs/istanbul_landing_system.md` before this commit, and in `570d65a2^`. Its
section 5 — "what the stock amphibious system would do instead" — was written
as a hypothetical and has become the live description; the substance of it is
carried into §2 above, re-verified.

Two of its findings survive unchanged and still matter:

- the caller's `location` argument to `amphibiousAssault` is discarded (8682)
- `getCoastalPoint`'s only terrain test is `cAreaTypeWater` (aiwaterrules 419)
