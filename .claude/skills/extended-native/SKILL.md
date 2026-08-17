---
name: extended-native
description: Build an extended native / extended Royal House (extended Habsburgs, extended Inuits, extended Phanar) - a second personality for a subciv that a map unlocks, adding an expansion big button on the Trading Post plus its own techs, and optionally shrinking the native's 2x2 ability to a small button. Use when asked to extend a Royal House or native, add an expansion big button, add techs behind an expansion, or wire the shadow tech that a map flips. Covers both cases - natives WITH an ability to transform and natives WITHOUT one. Triggers on "extended Habsburgs", "extended Royal House", "extend Phanar", "expansion big button", "new native techs", "unlock extended native".
---

# Extending a native / Royal House

An extended native is **not** a new subciv. It is the same subciv with a second
set of buttons that a **map trigger** switches on. Nothing in `techtreemods.xml`
ever activates it - see "The unlock" below.

Reference chains, all confirmed working in game:

| Extension | Shadow tech | Style |
|---|---|---|
| Spanish Habsburgs | `zpSpanishHabsburgs` (dbid 41242) | replaces ability with a **different** power |
| Austrian Habsburgs | `zpAustrianHabsburgs` (41247) | same power, small button |
| Inuits | `zpExtendedInuits` (41331) | same power, small button |
| Phanar | `zpExtendedPhanar` (41500) | same power, small button |

Read one end to end before writing anything. `zpAustrianHabsburgs` at the top of
`data/techtreemods.xml` is the cleanest template.

## Decide first: does this native have an ability?

Many natives have **no** 2x2 ability button. Then there is nothing to transform
and you skip three whole layers. Check with:

```bash
python .claude/skills/native-ability-minify/scripts/abilitytool.py slots <Subciv>
```

- A `command:deNat<X>...` row at `p2 c0` -> the native **has** an ability. Do
  everything below.
- No such row -> **no ability**. Do only parts C, D and E. Never invent a power
  or an `<ability>` entry for a native that has none.

## A. The power (only if the native has an ability)

`data/abilities/powermods.xml` - **CRLF**. Clone the vanilla power **byte for
byte** under a `zp` name. This is a *naming device only*: `zpNatPowerRadetzyMarch`
is field-for-field identical to vanilla `deNatPowerRadetzyMarch`, zero
differences. It exists so the second `<ability>` entry has a distinct key.

Get the vanilla text - never retype it:

```bash
python .claude/skills/bar-extract/scripts/bartool.py cat powers.xml > /tmp/powers.xml
```

Substituting a *different* power instead (Spanish Habsburgs swap Radetzy March
for El Deguello) is a design choice, not a requirement.

## B. The ability - two entries, and the exact diff

`data/abilities/abilitymods.xml` - **CRLF**, inside `<tradingpost>`.

**The big button already exists. Never add one.** You repoint its gate and
nothing else:

```xml
<ability mergemode="replace">deNatPowerGreekRevolution<tech>zpPhanarAbilityBig</tech>...<usebigabilitybutton3>true</usebigabilitybutton3>...</ability>
```

That line is the vanilla entry reproduced **verbatim** with `<tech>Colonialize</tech>`
swapped for the new gate. `usebigabilitybutton3` stays. Then the small twin:

```xml
<ability>zpNatPowerGreekRevolution<tech>zpPhanarAbilitySmall</tech>...</ability>
```

Same fields **minus `<usebigabilitybutton3>`**. Habsburg also drops
`<subcivstartincooldown>`; Phanar keeps it. Everything else carries over -
`subciv`, `subcivalliancefactor`, `activetimecooldown`, `uicommand`, `rof`,
`castonself`, `donotallowoverpoplimit`.

## C. Gate techs

Two 0-cost shadow techs, `prereqs` = whatever vanilla gated the ability on
(usually `Colonialize`). Note the space in `status ="active"` - match the file.

- default gate: **OBTAINABLE** (auto-researches, so an unextended game is exactly vanilla)
- extension gate: **UNOBTAINABLE** (the shadow tech flips it)

Naming follows one of two conventions already in the repo. Pick one, do not mix:
- per-house: `zpHabsburgColonialize` / `zpHabsburgAustrianColonialize`
- Big/Small: `zpInuitAcclimationBig` / `zpInuitAcclimationSmall`

For a native with **no** ability there is no gate pair at all.

## D. The expansion big button + its techs

Clone `zpAustrianHabsburgExpansion` (`techtreemods.xml` ~33372). Keep its
`icon` / `icontexturecoords` / `iconwpf` as placeholders unless told otherwise.
Flags `YPNativeImprovement` + `CountsTowardEconomicScore` + `NativeDance`,
prereq `Fortressize`. Its `<effects>` are only `CommandAdd`s for the new techs.

**Grid cells.** Run `slots <Subciv>` and copy Habsburg's layout:

| Cell | Holds |
|---|---|
| `p0 c4` | the small ability (command **and** tech form) |
| `p1 c1` | the expansion big button, beside `DEVeteran<X>` / `DEGuard<X>` |
| `p2 c5`, `p2 c6` | the two new techs |

`p2 c5/c6` are free on a **native** Trading Post: vanilla page 2 only reaches
c6, and the `p2 c0-c4` entries come from the **TradingPost proto** in
`protoy.xml`, not from a tech. Mod `CommandAdd`s that also land on c5/c6 belong
to the consulate path, a different building context.

## E. Two vanilla overrides - the part that is easy to miss

Without these the buttons draw and do nothing. Both use `mergemode="add"`
(lowercase - the repo writes it lowercase 611 times).

```xml
<tech name="DENative<Subciv>">          <!-- the obtainability hub -->
  <effects>
    <effect mergemode="add" type="TechStatus" status="obtainable">zpNat<X>AbilityClone</effect>
    <effect mergemode="add" type="TechStatus" status="obtainable">zp<X>Expansion</effect>
    <effect mergemode="add" type="TechStatus" status="obtainable">zp<X>NewTech1</effect>
    <effect mergemode="add" type="TechStatus" status="obtainable">zp<X>NewTech2</effect>
  </effects>
</tech>
<tech name="DENative<Subciv>Colonialize">   <!-- the activator -->
  <effects>
    <effect mergemode="add" type="TechStatus" status="active">zpNat<X>AbilityClone</effect>
    <effect type="CommandRemove" tech="zpNat<X>AbilityClone">
      <target type="ProtoUnit">TradingPost</target>
    </effect>
  </effects>
</tech>
```

`DENativeHabsburg` (~33050) makes the ability clone, **both** expansion buttons
and **all four** sub-techs obtainable - one hub, everything. Only override the
`DENative<X>` path; neither Habsburg nor Inuit touches `deUnknown<X>Alliance`.

## F. The extension shadow tech - must be at the TOP of techtreemods

`UNOBTAINABLE` + `<flag>Shadow</flag>`, placed beside `zpAustrianHabsburgs` /
`zpExtendedInuits`. **Command-swap techs do not take effect from further down
the file.**

```xml
<effect type="CommandRemove" command="deNat<X>Ability"> ... </effect>
<effect type="CommandAdd" command="zpNat<X>AbilitySmall" page="0" column="4"> ... </effect>
<effect type="CommandRemove" tech="deNat<X>Ability"> ... </effect>
<effect type="CommandAdd" tech="zpNat<X>Ability" page="0" column="4"> ... </effect>
<effect type="CommandAdd" tech="zp<X>Expansion" page="1" column="1"> ... </effect>
<effect type="TechStatus" status="unobtainable">zp<X>AbilityBig</effect>
<effect type="TechStatus" status="obtainable">zp<X>AbilitySmall</effect>
```

Vanilla places some abilities as a **paired** `tech=` *and* `command=` entry
(Habsburg, Phanar); others as a command only (Inuit). Only the paired ones need
the `tech=` remove/add as well - `abilitytool.py plan <command>` says which.

For a native with **no** ability the shadow tech shrinks to just the
`CommandAdd tech="zp<X>Expansion"` line.

## G. The unlock - from a map, never from techtreemods

Nothing in `techtreemods.xml` activates a shadow tech. Grep proves it: the
only writers are maps. Copy `zpcoldwar.xs` 1288-1301:

```cpp
for(k=1; <= cNumberNonGaiaPlayers) {
rmCreateTrigger("ExtendedPhanar"+k);
rmAddTriggerCondition("Always");
rmAddTriggerEffect("ZP Set Tech Status (XS)");
rmSetTriggerEffectParamInt("PlayerID",k);
rmSetTriggerEffectParam("TechID","cTechzpExtendedPhanar");
rmSetTriggerEffectParamInt("Status",2);
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}
```

Match the destination map's local idiom (some files use
`rmCreateTrigger` + `rmSwitchToTrigger`, and some forbid spaces in trigger
names). Also confirm the subciv is actually on that map - `rmSetSubCiv` plus a
placed native grouping.

**The map edit and the data edit must ship together.** A trigger naming a tech
that is not in the loaded `.xmb` references something that does not exist.

## Line endings - this has already destroyed a file

| File | Endings |
|---|---|
| `data/abilities/powermods.xml` | **CRLF** |
| `data/abilities/abilitymods.xml` | **CRLF** |
| `data/techtreemods.xml` | LF |
| `data/protounitcommandmods.xml` | LF |
| `data/strings/english/stringmods.xml` | LF |

Read bytes, preserve, verify after writing. See `preserve-crlf-line-endings` in
Claude memory.

**Do not build inserts in a bash heredoc.** The heredoc collapses `\\` to `\`,
and `\a` in `resources\abilities\...` is a *valid* escape (bell 0x07), so an
anchor silently stops matching while `\i` only warns. Write a `.py` file and run
it.

## Validation before you write a line

```bash
# 1. every new name must be free
grep -c '"zp<NewName>"' data/techtreemods.xml
# 2. free dbids + string ids
grep -o '<dbid>[0-9]*</dbid>' data/techtreemods.xml | sort -u | tail
# 3. the reference chain must be intact
python .claude/skills/native-ability-minify/scripts/abilitytool.py verify
```

After writing: XML parses, **no new** duplicate dbids or tech names (compare
counts against the backup - the repo already ships 15 dbid and 2 name
duplicates), `verify` passes, and the new gate is shape-identical to the
working one it copies.

## Then rebuild every touched .xmb

The engine reads `foo.xml.xmb` in preference to `foo.xml`, and only Resource
Manager writes them (needs the **.NET Desktop Runtime**, not the base runtime).
Rebuild **all** files you touched: a partial rebuild gives a live button bound
to a power that is not in the loaded data - it appears and does nothing, which
reads exactly like a design error. XMBs load once at process start, so restart
the game. A green test on stale XMBs is a false pass.
