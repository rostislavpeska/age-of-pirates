# Bug report — native unit upgrades no longer rename units (`SetName` tech effect)

**Build:** 24241387 (Baltic Powers beta)
**Mods:** reproduced with **all mods disabled** (Tools / Mods → deactivated)
**Severity:** cosmetic but pervasive — affects every native civ's Veteran / Guard /
Legendary upgrade in the game

---

## Summary

The `SetName` tech effect no longer applies. When a native Veteran or Guard
upgrade is researched, the unit's **stat bonuses apply correctly** but its
**displayed name never changes** — it keeps the base name instead of becoming
"Veteran …" / "Guard …" / "Legendary …".

Because the stats do apply, the tech is clearly being researched and its other
effects execute. Only the rename is dropped.

---

## Steps to reproduce

1. Disable all mods (Tools → Mods).
2. Start a skirmish on any map with a **Hanover** native settlement
   (e.g. Saxony, or any map listing Hanover).
3. Build a Trading Post on the Hanover socket and train a **Totenkopf Hussar**.
4. Advance to Fortress age and research **Veteran Hanoverians**
   (`DEVeteranHanover`).

**Expected:** existing and newly trained Totenkopf Hussars are renamed to
"Veteran Totenkopf Hussar" (string id `122428`), and their hitpoints/attack
increase.

**Actual:** hitpoints and attack increase as expected. The unit name stays
"Totenkopf Hussar". Same for Black Brunswicker.

The same happens for every native I tested, and for the Guard tier
(`DEGuardHanover`, string `122431`) and the Legendary tier
(`ImpLegendaryNativesShadow`, string `122434`).

---

## Technical detail

The effect in question, from `techtreey.xml`:

```xml
<tech name="DEVeteranHanover" type="Normal">
  ...
  <effect type="SetName" proto="deNatTotenkopf" culture="none" newname="122428" />
  <effect type="SetName" proto="deNatTotenkopf" culture="none" newname="122434"
          reqtech="ImpLegendaryNativesShadow" />
```

The referenced strings exist and are correct in
`Data/strings/English/stringtabley.xml`:

```
122428  Veteran Totenkopf Hussar
122431  Guard Totenkopf Hussar
122434  Imperial Totenkopf Hussar
```

`SetName` is used **1938 times** across `techtreey.xml`. The most common shape is
`proto` + `culture` + `newname` (1255 occurrences), with a further 319 adding
`reqtech`. If the effect is being ignored, the impact covers essentially every
unit-upgrade rename in the game — native Veteran/Guard/Legendary tiers, Imperial
upgrades, and card-driven renames such as `ChurchThinRedLine` → Redcoats.

Note that the `tech`-targeted form (`newname` + `newrollover` + `tech`, 174
occurrences) renames **techs** rather than protos; I have not verified whether
that variant is affected.

---

## What this is not

To rule out the obvious:

- Not a string-table problem — the ids resolve and display correctly elsewhere.
- Not the tech failing to research — the `Data` effects in the *same* tech apply.
- Not mod interference — reproduced with all mods disabled.
- Not specific to one civ or one native — observed across multiple natives and
  both upgrade tiers.

---

## Impact

Every native alliance upgrade in the game silently loses its rename. Players see
no feedback that a Veteran or Guard upgrade has taken effect beyond the stat
change, and Legendary-tier units are indistinguishable from base units by name.

For mod authors the effect is larger: `SetName` is the only mechanism for
retitling a proto at runtime, so any content relying on tiered names is broken
with no workaround available.
