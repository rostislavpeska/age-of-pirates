---
name: native-ability-minify
description: Shrink a native civ's big 2x2 ability button on the Trading Post down to a normal 1x1 grid button, so an extended-civ big button (Inuit Expansion, Habsburg Expansion, native influence/dance techs) can occupy the slot without overlapping. Use when a native ability button overlaps the unit-upgrade big button, when adding an expansion big button to a subciv that already has an ability, when asked to make an ability button smaller/minify/shrink a native power, or when a small ability button appears but casting does nothing. Triggers on "big button overlap", "ability button too big", "2x2 button", "minify ability", "shrink native ability", "small variant of the ability".
---

# Shrinking a native ability button

A native ability on the Trading Post is drawn as a 2x2 overlay, not a grid cell.
When the subciv also gets an expansion big button, the two collide. The fix is a
**parallel small chain**: clone the ability, power, command and tech without their
size flags, then have the extension shadow tech swap one for the other.

```bash
python .claude/skills/native-ability-minify/scripts/abilitytool.py <command> [args]
```

Run from the repo root. Reads vanilla out of the `.bar` archives via `bar-extract`,
so it needs no unpacked game files.

| Command | Purpose |
|---|---|
| `find [pattern] [--big-only]` | Native ability commands in vanilla, with which size flags each carries |
| `slots <subciv> [--unit X]` | The proto's button grid, vanilla + mod + `CommandAdd`s, filtered to a subciv |
| `plan <command> [--page P --column C]` | Emit every block needed for the small variant |
| `verify [prefix]` | Audit every `*Small` chain in the mod; non-zero exit if anything is broken |

## The four layers

Three separate flags control the size. **All must be absent** or the button stays
big — dropping two of three changes nothing visible, which makes this easy to get
half-right.

| Layer | File | Flag to drop |
|---|---|---|
| ability | `abilities.xml` | `<usebigabilitybutton3>true</usebigabilitybutton3>` |
| command | `protounitcommands.xml` | `<usemediumbutton3 />` |
| tech | `techtreey.xml` | `<flag>DEUseMediumButton3</flag>` |

The fourth layer is not a flag and is the one that bites: the cloned
`<associatedtech>` starts UNOBTAINABLE and **something must set it active**, or
the button draws and does nothing. Vanilla does this from a civ tech — for Inuit
it is `DENatInuitResourcefulness`, which ends with

```xml
<effect type="TechStatus" status="active">deNatInuitArcticAcclimation</effect>
```

so the mod overrides that same tech and adds the clone. `plan` reports which
vanilla tech activates a given ability; `verify` fails if nothing does.

## Which ability is live: the gate techs

Both variants exist at once. Which one the player can cast is decided by the
`<tech>` gate on the `<ability>` entry, flipped by a pair of 0-cost shadow techs:

- `zp<Subciv>AbilityBig` — **OBTAINABLE**, prereq = whatever vanilla gated the
  ability on. Auto-researches, so an unextended game behaves exactly as vanilla.
- `zp<Subciv>AbilitySmall` — **UNOBTAINABLE** until the extension flips it.

The vanilla `<ability>` is rewritten with `mergemode="replace"` to point at the
Big gate — it *keeps* `usebigabilitybutton3`. Only the new twin drops it.

The extension shadow tech then does the swap, and it belongs near the **top** of
`techtreemods.xml` alongside `zpSpanishHabsburgs` / `zpAustrianHabsburgs`.
Command-swap techs do not take effect from further down the file.

```xml
<effect type="CommandRemove" command="deNatInuitArcticAcclimation">
  <target type="ProtoUnit">TradingPost</target>
</effect>
<effect type="CommandAdd" command="zpNatInuitArcticAcclimationSmall" page="0" column="5">
  <target type="ProtoUnit">TradingPost</target>
</effect>
<effect type="TechStatus" status="unobtainable">zpInuitAcclimationBig</effect>
<effect type="TechStatus" status="obtainable">zpInuitAcclimationSmall</effect>
```

## Picking the destination cell

Run `slots <subciv>` first. Commands carry `<subciv>`, so a cell already used by
another subciv's ability is free — `p0 c4` holds both Habsburg smalls and a Sufi
tech without conflict. Existing small buttons live at `p0 c4`/`p0 c5`.

Some vanilla abilities are placed as a **paired** `<tech>` *and* `<command>` at
the same cell (Habsburg); others as a command only (Inuit). Only the paired ones
need the `tech=` `CommandRemove`/`CommandAdd` as well. `plan` says which.

## Three ways this silently fails

- **Stale `.xmb`.** The engine loads `foo.xml.xmb` in preference to `foo.xml`.
  When only some of the four files get recompiled you get a live button bound to
  a power that is not in the loaded data — it appears and does nothing, which
  reads exactly like a design error. This has already cost one failed playtest.
  `verify` checks freshness of all four; delete the stale `.xmb` (they are
  tracked, so recoverable) and let the engine rebuild.
- **`mergeMode` vs `mergemode`.** The repo writes lowercase 611 times. If the
  parser is case-sensitive, a capitalised override *replaces* the vanilla tech's
  effects instead of adding to them — for a civ enabler that silently strips
  every unlock the civ has. `verify` counts the capitalised ones.
- **Nothing activates the cloned tech.** Covered above; the symptom is a
  permanently dark button.

## Worked example — Inuit, and what is already done

`zpExtendedInuits` (top of `techtreemods.xml`) swaps
`deNatInuitArcticAcclimation` → `zpNatInuitArcticAcclimationSmall` at p0 c5, with
gates `zpInuitAcclimationBig`/`Small` and the activation added to
`DENatInuitResourcefulness`. Confirmed working in game, both variants.

Eight small chains exist in the mod: Bourbon Royal March, Auditore Lighthouse,
Blanik Knights, Imperial Command, Sultan Command, both Habsburgs, and Inuit.
`find --big-only` lists the 14 vanilla abilities still on a big button.
