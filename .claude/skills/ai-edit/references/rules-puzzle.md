# How the AI's rules fit together

This file describes how the AI's rules fit together. Read it before adding a rule, and before touching a stock
rule's switch. The line numbers below were measured on 2026-09-24 in `game/ai/core/`; re-grep them before relying on
them.

## The runtime model

- **Files and rules.** `aicore.xs` includes every file (90-104). Each file declares globals, functions and
  `rule`s, and the engine runs every active rule on its `minInterval`.
- **Enabling.** A rule starts `active` or `inactive`. Other code turns it on with `xsEnableRule("name")` and off
  with `xsDisableRule` / `xsDisableSelf`. The name is a string resolved at run time, so a misspelt name fails
  silently.
- **Handlers are engine callbacks,** registered in `aisetup.xs` with `aiSetHandler`:
  - `buildingPlacementFailedHandler` (1254): every "no spot found". It is the ONLY place the main base grows.
  - `ageUpHandler`, `resignHandler` (a beaten AI offers resignation through a modal dialog that pauses the game),
    `gameOverHandler` and `nuggetHandler`.
- **Plans** (`aiPlanCreate`) own units. A unit obeys its plan's highest-priority claim:
  - stock army = 99, transport = 100 (guidelines rule 2);
  - a reserve at 101 keeps its units;
  - 90 (Paris `cityGateKiller`, `londonGateKiller`) sits below the army.

  Orders to units a plan owns are overwritten within seconds, so re-issue them every pass.
- **Control variables** (`cv...`) gate whole families. `cvOkToAttack` is read at the Age II transition
  (`aicore.xs` 2478-2490): only while it is true are `raidEnabler`, `mostHatedEnemy` and `attackManager` enabled.
  A rule that holds attacks must re-disable them every pass, and must enable all three itself on release.

## The stock families a map rule meets

| Rule | File:line | Interval | Decides | Map-rule policy |
|---|---|---|---|---|
| `attackManager` | aimilitary.xs:676 | 15 s | whether and whom to attack | may be HELD / RELEASED by a map war plan (approved for London) |
| `raidEnabler` | aiassertivewall.xs:189 | 10 s | raids | held with `attackManager` |
| `mostHatedEnemy` | aimilitary.xs:14 | 60 s | target player | enabled on release |
| `militaryManager` | aimilitary.xs:261 | 28 s | army composition | untouched |
| `tradingPostMonitor` | aibuildings.xs:4106 | 5 s | which socket to claim (TPs, natives, the London bridge post) | **gameplay: no map branch** (test) |
| `towerManager` | aibuildings.xs:3946 | 40 s | towers wanted | **gameplay: no map branch** (test) |
| `forwardTowerBaseManager` | aiassertivewall.xs:11268 | 30 s | whether a forward base exists | **gameplay: no map branch** (test); only its PLACE (`selectForwardBaseLocation`) is approved for London |
| `selectBuildPlanPosition` | aibuildings.xs | per plan | where a building goes | placement hooks allowed (approved list) |
| `buildingPlacementFailedHandler` | aibuildings.xs | per failure | base growth | growth limits allowed (approved list) |

## The map families in aipiraterules.xs

**Detection.** `initializePirateRules` (42, active, 1 s) detects each map by object and enables that map's family.
It also enables `aiTestDiag` when `gAITestDiag` is on.

| Family | Rules | Shares with the stock AI |
|---|---|---|
| Paris / Versailles (never patch, owner rule) | `initializeCityAttackmanager`, `cityGateKiller` (4 s), `rerunCityGateKiller`, `cityAttackmanager`, `buildPirateSocketTowers` (30 s) | disables `attackManager` |
| Istanbul | `istanbulAttackKOTH`, `istanbulGuardianKiller`, `istanbulDefendKOTH`, `istanbulPalaceMission`, `istanbulPalaceHomeKiller`, `istanbulPalaceHold` (10 s, reserve 101), `istanbulFortRaid`, `istanbulAreaRecalc` | amphibious stages |
| London (plan rounds 1-3 + placement) | see below | `attackManager` / `raidEnabler` / `cvOkToAttack` (war plan); placement hooks in aibuildings.xs |

## The London chain

1. **Detection:** `initializePirateRules` finds our own `zpAILondonBridge` marker. It sets `gIsLondon`, enables
   `buildPirateSocketTowers` and `londonSetup`, and echoes `LONDON p<N> build r<k>`.
2. **`londonSetup`** (10 s, one shot): reads the marker, the port socket, the bridge gates A/B and ours, and the Keeps
   near and far. It enables `londonDiag` (test mode), `londonWarPlan`, `londonGateKiller` and `londonKeepHold`.
3. **`londonWarPlan`** (10 s): while either bridge gate stands and is not ours or an ally's, it holds `attackManager`
   and `raidEnabler` with `cvOkToAttack = false`. When both gates are down or ours it RELEASES them
   (`gLondonWarState` 1 means held, 2 means released).
4. **`londonGateKiller`** (5 s, reserve 90): the ordered target list is the near Keep's gates, our bridge gate, the
   far bridge gate, then the far Keep's gates once released. Guardians are shot first; the strength ratio is 1.5;
   the mass floor is `gLondonArmyFloor`. When the list is empty, the reserve goes back to the stock attack.
5. **`londonKeepHold`** (30 s): for each Keep the team owns, a garrison reserve at 101 capped at `gLondonKeepGarrison`.
   The same garrison walks back to retake a lost flag.
6. **Placement** (in aibuildings.xs, every function on the approved list):
   - economic buildings at the countryside behind our wall gates (`londonFieldPoint`);
   - the Town Center countryside fallback;
   - base growth over the river, the hills and the countryside, capped at 120 m;
   - the forward base at the enemy bridgehead once `gLondonWarState == 2`.

The globals the chain shares, in declaration order:
- `aiglobals.xs`: `gIsLondon`, `gLondonWarState`, `gLondonFieldVec`, `gLondonFieldGate`, `gLondonPlaceEcho`,
  `gAITestDiag`, `gPlacementFailures`;
- `aipiraterules.xs` (top): `gLondonTestMode`, the bridge / gate / Keep ids, `gLondonArmyFloor`,
  `gLondonKeepGarrison`, the plan ids.

## Adding a piece to the puzzle

1. **Which family owns the decision?** If it is a stock gameplay decision (the table above), stop and propose.
2. **Where does it hook in?**
   - A new map rule goes at the end of the map's section, with its globals at the top, or in `aiglobals.xs` when an
     earlier file reads them.
   - A placement hook goes into the stock function inside `if (gIs<Map> == true)`, with a helper that returns at
     once off the map.
3. **Who enables it,** at which point of the chain, and what disables it on every exit path? Destroy plans on every
   exit (guidelines rule 3).
4. **Which echo proves it ran,** which refusal echo proves why it did not, and which criterion reads those echoes?
5. **The approval entry** in `APPROVED_LONDON_CODE`, with the owner's quote. No quote means no entry and no commit.
