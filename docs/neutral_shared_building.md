# Neutral shared building — the "neutral merchant" system

One building that every player can see and use, which nobody owns. Each player
interacts with it through their own private, invisible click handle, and only
while they have a unit standing next to it.

Built 2026-08-19/20. Working end to end **for player 1 only**. The per-player design is not yet
generalise to 2-8 players; the route that was planned is ruled out. See
[Debt](#debt) D1/D2/D2b, and D2c for the design that survives.

State as of 2026-08-20. Line numbers are from our copy on that date.

---

## 1. Anatomy

Three layers occupying the same spot on the map.

### 1.1 The visible half — `zpNeutralCossackChurchProp` (id/dbid 30059)

`data/protomods.xml`. Gaia-owned. A verbatim clone of `zpNativeHouseVenetianC`
(protomods.xml:46771), the mod's proven passive-prop block, with the animfile
and portrait swapped and two Venice-specific entries dropped
(`<civflagoverride>objects\flags\venetian`, `<unittype>AbstractCityManisonB`).

What makes it work as a prop:

| element | why |
|---|---|
| `movementtype air` + `obstructionradius 0.0001` | units walk straight through the model |
| `NotSelectable` | nobody can click the church itself — clicks fall through to the pad |
| `NoUnitAI`, `StartOnNoUpdate`, `NoIdleActions` | costs nothing per tick |
| `Invulnerable`, `InvulnerableIfGaia` | indestructible |
| `PlaceAnywhere` | RM can drop it anywhere, including on top of the pad |
| `minimapicon ui\minimap\military_small` | copied from `zpSPCCathedral` ("Maltese Diocese") as `randmaps/zpkingofbohemia.mods.xml:288` sets it |

### 1.2 The clickable half — `zpNeutralCathedralP1` (id/dbid 30051)

`data/protomods.xml`. Owned by the player it belongs to. Started as a verbatim
clone of vanilla `deSPCCapturableFlag` (protoy.xml id 2360) with
`<tactics>captureflag.tactics</tactics>` removed so it cannot be captured, then
given the Orthodox Cathedral's identity — its unittype list, rollover 302099 and
`HasGatherPoint` — so that selecting it reads as selecting a cathedral.

| element | why |
|---|---|
| `NotSelectable` in base data | the OFF state; the tech is what turns it on |
| `SelectWithObstruction` | picking uses the obstruction, not the (near-absent) mesh |
| `obstructionradius 5.0` | the 10 × 10 m area a click has to land in |
| `animfile buildings\native_settlement\neutral_cathedral.xml` | one tiny model + the selection decal |
| `los 15` | the owner sees the spot |
| `NonCollideable` | does **not** block pathing — see debt item 3 |

### 1.3 The art — `art/buildings/native_settlement/neutral_cathedral.xml`

Skeleton copied from `cossack_church.xml` (the single-model form), model swapped
for `ui\editor\editor_revealer_01` — the smallest thing the game ships — and the
`<decal>` block lifted byte-for-byte out of `orthodox_cathedral.xml`:

```xml
<decal>
    <effecttype>bump</effecttype>
    <selectedtexture>shadows_selections\selection_square_128x128</selectedtexture>
    <bumptexture>shadows_selections\flat_normal_black_spec</bumptexture>
    <width>12.00</width>
    <height>14.00</height>
</decal>
```

`cossack_church.xml` has no `<decal>` of its own, so the selection square comes
entirely from the pad — which is correct, since the pad is what gets selected.

### 1.4 The sound — `sound/zpneutralcathedralp1_snds.xml`

Byte-for-byte copy of `zpcathedralorthodox_snds.xml`, only the `<protounit
name=...>` changed. Soundsets bind by **lowercased protounit name +
`_snds.xml`**; there is no index to register in.

---

## 2. The switch

Two techs, both at the **top** of `data/techtreemods.xml` (indices 0 and 1):

| tech | dbid | effects |
|---|---|---|
| `zpNeutralCathedralSelectableP1` | 408196 | flagid 12 → 1, flagid 230 → 1 |
| `zpNeutralCathedralUnselectableP1` | 408197 | flagid 12 → 0, flagid 230 → 0 |

`flagid` indexes the internal protoUnit flag enum documented in
`docs/data_xml_guide.md`: **12 = cSelectable**, **230 = cDisplaySocketPanel**.
Distilled from vanilla `DESPCNapoleonicSetup`, which applies both to
`deSPCCapturableFlag` among 82 other campaign effects.

### The mechanism that makes it repeatable

**Taking a tech from Active to Unobtainable does not undo its effects — it
re-arms it.** That is why a reversal tech is needed at all, and why the loop
works: each side sets the *opposite* tech to status 0 before setting its own to
status 2, so both can fire again on the next flip.

Status values, confirmed from our own maps (`Status 0` 237 uses, `Status 1` 58,
`Status 2` 2540): **0 unobtainable, 1 obtainable, 2 active.**

Setting an already-active tech to 2 is a no-op, so polling every tick is free.

---

## 3. The proximity loop

`0000_selectable_test.xs`, two triggers, both `rmSetTriggerLoop(true)`:

| trigger | condition | effects |
|---|---|---|
| `NeutralNear_Plr1` | `Units in Area` — player 1, `Unit`, dist `neutralRadius`, `>=` 1 | Unselectable → 0, Selectable → 2 |
| `NeutralFar_Plr1` | same area, `<` 1 | Selectable → 0, Unselectable → 2 |

Mutually exclusive, so exactly one is live. The pad ships `NotSelectable`, so the
starting state is already "off" — no initial grant.

The loop keys off `padUnitID`, derived from
`rmGetUnitPlacedOfPlayer(padP1ID, 1) + padUnitIdShift`. Object-def ids come back
offset by a per-map constant (`zp_z_zparis` +1, `000_istanbul` +2), so the map
echoes the id it derived. If the loop never fires, retune `padUnitIdShift`
first — see the `nugget-targeting` skill, rule 2.

---

## 4. Non-obvious constraints

Each of these cost real debugging time.

1. **New techs must go at the TOP of `techtreemods.xml`.** A tech near the bottom
   parses, compiles into the XMB as a real element with correct dbid and
   effects, and silently never applies. An 84-effect byte-for-byte clone of a
   vanilla tech did nothing at index 1262 of 1312 and worked immediately at
   index 0. Check tech index before debugging anything else.
2. **XMB rebuild.** `protomods.xml`, `techtreemods.xml` and
   `strings/english/stringmods.xml` are inert until Resource Manager rebuilds
   them. Mod off/on does not do it. Art XML and `_snds.xml` load directly and
   need no rebuild.
3. **To check whether an edit actually reached the game**, decompile the XMB —
   `data/*.xml.xmb` is `alz4`-wrapped, so unwrap first:
   `bt.xmb_to_xml(bt.unwrap_alz4(open(path,'rb').read()))` using
   `.claude/skills/bar-extract/scripts/bartool.py`.
4. **Copy blocks, do not derive them.** The one proto written from scratch
   (`editor_revealer.xml` anim, hand-picked flags) failed and cost a session;
   every verbatim clone worked.

---

## Debt

Honest state. The system is a **single-player prototype**, not a feature.

### D1 — Players 2–8 do not exist, and the planned route to them is dead

There is exactly one pad proto (`zpNeutralCathedralP1`), one tech pair, and one
trigger pair. Nothing exists for players 2–8.

The original plan — clone the proto and tech eight times and stack the pads — is
**ruled out** by D2 and D2b below. Do not build it. What works for player 1
today is a genuine single-player prototype; making it multiplayer means the D2c
redesign, not more cloning.

### D2 — ANSWERED 2026-08-20: selectability is read from the OWNER alone

Tested on `0000_selectable_test`: a second pad proto owned by player 2, its tech
granted to player 2 permanently and unlooped, 30 m from player 1's. **Player 1
could select player 2's pad.** Every viewer gets the same answer for a given
unit, so no protoUnit flag can ever scope selection to one player.

`cSelectable` is not viewer-relative. There is no per-viewer selectability in
this engine — that avenue is closed for good.

**What survives, and why this is not fatal on its own:** selection is not
control. A player can only issue commands to units they own, so even a pad that
everyone can *select* can only be *used* by its owner. The failure mode of
stacking eight pads is therefore "you click the building and get somebody else's
panel", not "other players can spend from your building".

That makes one question decisive, and it is now the only thing standing between
this and shipping.

### D2b — ANSWERED 2026-08-20: stacking does not work

Tested on `0000_selectable_test`: player 1's and player 2's pads placed on the
same point under one church, both selectable for their owners. **Picking does
not resolve to your own unit.** Clicking the building does not reliably give
you your own pad.

Combined with D2, this closes the per-player pad approach entirely:

- selectability cannot be scoped to a viewer (D2), and
- overlapping pads cannot be told apart by a click (D2b).

**Eight stacked pads is a dead design.** Do not spend the hour on D1 — cloning
P2-P8 would produce eight buildings that any player can select and none can
reliably reach. The surviving path is D2c.

The probe is left in place on the map (`zpNeutralCathedralP2` id 30052, tech
`zpNeutralCathedralSelectableP2` dbid 408198, and the map block marked
`D2 PROBE`/`D3 PROBE`). It is dead weight but harmless, and it documents the
experiment. Strip it whenever the fallback is built.

### D2c — The surviving design: one pad, ownership follows the player

Instead of eight pads, place **one** pad owned by gaia. Gaia never holds the
tech, so it is unselectable by default. The proximity loop then converts it to
whichever player is standing at the building and grants that player's tech;
when they leave, convert it back to gaia.

This works under owner-side selection because only one pad ever exists, and its
owner is by construction the player using it. Conversion is well-trodden ground
in this mod — `socketcapture.tactics`, `Convert Units in Area`, the Istanbul
palace chain. The cost is that the building serves one player at a time, which
for a merchant is arguably correct rather than a compromise. Contention between
two players inside the radius needs a tiebreak (first-come, or nearest).

### D3 — The pad does not block movement


`NonCollideable` is inherited from the flag clone. The original requirement was
"not walkable through"; units currently walk through both halves. The 5 × 5
obstruction is used for picking only. Swapping to `Collideable` is one line, but
it has not been tested against placement or pathing.

### D4 — The pad cannot take commands

`NotCommandable` is inherited from the flag clone. `HasGatherPoint` was added but
almost certainly cannot be used while `NotCommandable` is set. Until this is
resolved the building cannot train, research, or set a gather point — i.e. it is
selectable but not yet *useful*.

### D5 — `AbstractCityManison` on the pad

Inherited with the Orthodox Cathedral unittype list. City maps key logic off that
unittype (`zpistanbulb.mods.xml` assigns it deliberately to city props), so the
pad may be swept up by city-map building logic on those maps. Untested.

### D6 — Deselection lag

Walking out of the radius while the pad is selected leaves it selected; the flag
change only affects new picks. Fixable in the `NeutralFar` trigger.

### D7 — `flagid 230` is unproven

Kept because vanilla pairs it with 12 on this proto. It has never been tested
whether 12 alone is sufficient. One-line experiment, never run.

### D8 — Decal and obstruction disagree

Decal is 12 × 14 (the Orthodox Cathedral's numbers); the obstruction is 5.0
radius, a 10 × 10 footprint. The selection square reads slightly larger than the
clickable area, and rectangular against a square footprint.

### D9 — English strings only

303372–303376 exist only in `data/strings/english/stringmods.xml`. The other
fourteen language folders ship `.xmb` only and were not touched.

### D10 — The test map is outside the repo

`0000_selectable_test.{xs,xml}` lives in the game install's `Game/RandMaps/`,
untracked by git. It will be lost on a Steam verify or reinstall, and nobody else
on the team has it.

### D11 — Not integrated anywhere, and the AI cannot see it

No real map places this building. The AI has no handling for it at all.

### D12 — The two halves are independent units

Nothing binds prop to pad. If either is deleted, converted or fails placement,
the illusion breaks silently — a visible church with no handle, or a handle with
no church.
