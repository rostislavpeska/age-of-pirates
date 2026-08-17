# AI technical debt — findings from the Age of Pirates side

Notes gathered while investigating why AI transports never land on cliffed
shores. Written for the AssertiveWall AI author. Every claim below is from
reading the shipped scripts in `game/ai/`; the one change we actually tested is
marked as such, including the regression it caused.

Line numbers are from our copy of the scripts as of 2026-08-17.

---

## 1. `cAreaTypeImpassableLand` is never tested anywhere in the AI

The engine exposes four area types (`docs/ai_reference.xs:2326-2329`):

```cpp
extern const int cAreaTypeForest;
extern const int cAreaTypeWater;
extern const int cAreaTypeImpassableLand;
extern const int cAreaTypeVPSite;
```

Across the AI scripts (counting `core/` once; `coreDLC/` duplicates it):

| constant | occurrences |
|---|---|
| `cAreaTypeWater` | 21 |
| `cAreaTypeImpassableLand` | **0** |

Every "walk until we leave land" routine therefore treats **cliff as valid
ground**, because a cliff is simply "not water".

### Where it bites — `getCoastalPoint`

`game/ai/core/aiwaterrules.xs:403`

```cpp
for (i = 0; < range)
{
    testPoint = testPoint + normalizedVector;
    testAreaID = kbAreaGetIDByPosition(testPoint);

    if (kbAreaGetType(testAreaID) == cAreaTypeWater)   // the only test
    {
        if (isWaterPoint == true) { return (nextPoint); }
        else                      { return (previousPoint); }
    }
    ...
}
```

Walking from land toward water across a cliffed shore:

```
base → land → land → CLIFF → CLIFF → water
```

The loop passes straight through the cliff, stops at water, and returns the last
non-water tile — **a cliff tile**. The transport then ejects onto rock, or the
troops land and cannot path off.

Same shape in `getDropoffPoint`, `game/ai/core/aiarchibelagoeconomy.xs:728`.

---

## 2. `getCoastalPoint` is a shared primitive with two incompatible contracts

**This is the important one, and it is why the obvious fix is wrong.**

`getCoastalPoint` has **19 live call sites across 6 files**, serving two
completely different purposes:

| purpose | `isWaterPoint` | example call sites |
|---|---|---|
| find a **land** point (landing spot, building site) | `false` | `aibuildings.xs:1002,1058` · `aiassertivewall.xs:7209` · `aiwaterrules.xs:733,734` |
| find a **water** point (navy staging, dock frontage) | `true` | `aiassertivewall.xs:8890,8981,9106` · `aibuildings.xs:1349,1354` |

### Tested change, and the regression it caused

We added a cliff test guarded to the land case only:

```cpp
if (isWaterPoint == false && testAreaType == cAreaTypeImpassableLand)
{
    return (previousPoint);
}
```

**Result in game: AI players failed to build docks at all.** Reverted.

The cause is `aibuildings.xs:1058`, which uses the same primitive to choose dock
sites and deliberately prefers the point **furthest** from base:

```cpp
tempCoastalPoint = getCoastalPoint(baseVec, tempVec, 1, false);
if (distance(tempCoastalPoint, baseVec) > distance(bestVec, baseVec))
{   // If the point is a little further away, it might be on one of the parts that jut out
    bestVec = tempCoastalPoint;
```

Stopping the walk early at a cliff returns points **closer** to base, so this
"find the spit that juts out" heuristic degraded everywhere, on every map with
any cliff between base and shore — not only on cliff-ringed maps.

`aibuildings.xs:1002` (dock tower coverage) has the same dependency.

**Conclusion:** the cliff test cannot be added to `getCoastalPoint` itself, even
guarded by `isWaterPoint`. Landing needs "stop at cliff"; building-site
selection needs "keep walking to the true coast". They are different questions
sharing one function.

Suggested shape instead — a separate landing-specific finder, leaving
`getCoastalPoint` untouched:

```cpp
vector getLandingPoint(vector landPoint, vector waterPoint, int stepsBack)
{
    // as getCoastalPoint, but ALSO stops on cAreaTypeImpassableLand,
    // and returns cInvalidVector if the last land tile is not reachable
    // from landPoint by land.
}
```

and calling it only from the eject/dropoff paths.

---

## 3. `getDropoffPoint` is dead at the actual eject site

`game/ai/core/aiassertivewall.xs:7936` and `:7957`

```cpp
dropoff = tempDropoffTarget;//getDropoffPoint(shipLoc, tempDropoffTarget, 0);
aiTaskUnitEject(gLandingShip1, dropoff);
```

The live value comes from `selectPickupPoint` (`:7927-7928`), so
`getDropoffPoint` is bypassed where the landing actually happens. Anyone fixing
"the landing function" will likely patch `getDropoffPoint` first and see no
effect — we did.

---

## 4. `selectPickupPoint` validates its samples but not its fallback

`game/ai/core/aiassertivewall.xs:7144`

The sampling loop is sound — 15 attempts at spread angles, each validated:

```cpp
tempVec = getCoastalPoint(friendlyLoc, tempVec, stepsBack, waterBool);
if (kbAreAreaGroupsPassableByLand(kbAreaGroupGetIDByPosition(tempVec),
                                  kbAreaGroupGetIDByPosition(friendlyLoc)))
```

But when all 15 fail, the fallback is unchecked:

```cpp
bestVec = getCoastalPoint(friendlyLoc, enemyLoc, 1, false);
return (bestVec);
```

So a fully cliffed shore returns an invalid landing point rather than reporting
"no landing possible here", and the assault proceeds into it.

Note the passability check compares the candidate against `friendlyLoc`, not
against the assault **target**. A point can be reachable from home and still be
walled off from the objective.

---

## 5. Smaller notes

- **`kbCanPath2` is declared and never used.** `docs/ai_reference.xs:1044`
  exposes `bool kbCanPath2(vector, vector, int protoUnitTypeID, float range)`.
  No AI script calls it. It looks like the natural primitive for validating a
  landing spot against the unit type being unloaded.
- **`core/` and `coreDLC/` have drifted.** `aiwaterrules.xs` differs between
  them by one line — `coreDLC` passes an extra `existingPlanUnitCount` argument
  to `createTransportPlan` (`:293`) that `core` does not. Any fix has to be
  applied to both, and it is easy to miss that they are not identical.
  `aiarchibelagoeconomy.xs` *is* identical between the two.

---

## Reproduction context

Observed on **zpistanbulb** (Age of Pirates), a strait map that initialises as
water (`rmTerrainInitialize("water")`) and paints land on. Six of its areas use
an impassable cliff type; the countryside flanks are ringed by it deliberately,
as a design constraint rather than an accident.

Behaviour: AI never establishes a landing on the cliffed flanks. The same
symptom appears on another of our maps that uses impassable cliff, which is what
suggested the cause is general rather than map-specific.

For contrast, **zpvenice** plays acceptably with the same AI — and it uses
**zero** impassable cliff areas, and is a land map with water features rather
than a water-initialised map.

---

## What we are asking for

Not the naive patch — we tested it and it costs dock placement. The useful
version is probably:

1. A landing-specific point finder that stops on `cAreaTypeImpassableLand`,
   separate from `getCoastalPoint` so building placement is unaffected.
2. Reachability validated against the **assault target**, not only against home.
3. An honest failure return, so the assault can be abandoned instead of ejecting
   troops onto rock.

Happy to test any of it — we have maps that reproduce the problem reliably.
