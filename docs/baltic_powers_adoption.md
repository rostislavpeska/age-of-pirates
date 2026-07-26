# Baltic Powers adoption

What the Baltic Powers DLC broke in Age of Pirates, and what was done about it.
Written after the fact as a record; the forward-looking version is
[baltic_powers_merge_plan.md](baltic_powers_merge_plan.md).

Build at time of writing: 24241387 (Baltic Powers beta).

## The shape of the problem

The mod replaces roughly 150 vanilla files wholesale. When a patch *adds* records
to one of those files, the mod's copy silently drops them. Nothing errors. The
content is simply absent, and the symptom surfaces somewhere unrelated — a unit
goes mute, a tech stops resolving, a transform does nothing.

A second, quieter class: the DLC introduced content whose **names or paths
collide** with content the mod had already invented. Where they collide, the mod
wins, and the DLC's version is silently replaced.

Neither class produces an error message. Both had to be found by diffing the mod
against vanilla, which is what the two skills below exist to do.

## Tooling

Two Claude skills were built first, because none of the rest is tractable by hand.

**`.claude/skills/bar-extract`** — reads the 42 `.bar` archives (~122,000 files)
directly: ESPN v6 container, `alz4` compression, XMB→XML decompile. Standard
library only, no Resource Manager. Everything downstream reads vanilla through
this, so no unpacked copy of the game is needed.

**`.claude/skills/vanilla-merge`** — classifies every mod file as override or
new, reports which records an override drops, and splices the missing ones back
without touching the mod's own changes. Current state: **141 overrides, 5905
mod-only files**.

A third skill came later, out of the Inuit work:

**`.claude/skills/native-ability-minify`** — shrinks a native civ's 2×2 ability
button to a 1×1 grid button. See [Phase 2](#phase-2--inuits).

## Phase 1 — stale overrides

Fixed in `5684731e`, `d6e879e3`, `9e9fe569`, `7bca3463`, `b47db8b9`, `1d6c862f`.

| Area | What was lost | Fix |
|---|---|---|
| Sound | 268 soundsets missing from `soundsetsde.xml` alone | replaced the 226 KB override with an additive `soundsetsde.mods.xml` |
| `_snds` files | 5 stale per-unit sound overrides | merged the DLC's additions |
| `unittypes.xml` | 12 entries, including `AbstractFolwark` | restored |
| Farming techs | 11 techs had no Folwark effect | added `unittype="AbstractFolwark"` gather effects |
| `unittransform.xml` | 10 transforms, including all 8 Folwark upgrade/downgrade pairs | restored |
| `traderoutes.xml` | 4 arctic upgrade paths | restored |
| Misc data | 105 vanilla values across 17 files | restored |
| `protomods.xml` | new settlers lacked fishing/Folwark rates; missing Polish and Danish buildings; dry dock ships | added |

The Folwark case is the one worth remembering. `AbstractFolwark` was missing from
`unittypes.xml`, so the transforms referencing it were unkeyable, so the auditor
dropped them silently — and the in-game symptom was "Folwark transform does not
work", found by playing, not by tooling. The auditor now reports unkeyable
records instead of skipping them.

**Prefer an additive `.mods.xml` where the engine supports one.** Merging fixes a
stale override; it does not stop the file going stale again next patch. The sound
fix is permanent for that reason; most of the rest is not.

## Phase 1b — art collisions

Fixed in `6f48f8d2`.

Three cases where an AoP asset shadowed a DLC one by sharing a path or a name:

- **Polish church** — renamed under a `zp` prefix; the material must keep the
  model's name, so both moved together
- **Goose** — the DLC added its own; AoP's became a fully separated file set
- **Feral pig** — same treatment; the domestic pig was cloned onto the DLC pig's
  sound file, and `pig_portrait` was renamed to `feral_pig_portrait` so the DLC
  pig stopped inheriting the AoP icon

Path-level collisions are findable mechanically. Name-level ones (materials,
portraits) are not, and needed a sweep per asset class.

## Phase 2 — Inuits

Fixed in `c47e3725` and the commit this document ships with.

Baltic Powers shipped **its own Inuit civ**, colliding with the mod's. Two paths
were considered: rework ours into a distinct civ (the `SPCSufi` pattern), or
strip ours and extend theirs (the Aztec/Maya pattern).

Cloning was tried first and abandoned — the Qimmiit tech and the death-replacement
behaviour do not survive a clone, because tech effects target protos by name.
**Civ extension** was chosen instead.

What that meant:

- dropped 3 trainable units, the socket, 12 techs, and the `InuitNatives` civ
- kept the architecture and props, minus their `<subciv>` tag
- kept the harpooner, rebalanced as an elite coexisting unit — build limit 7,
  240 HP, 0.30 ranged armour, 26 ranged damage — sitting alongside the DLC Hunter
  rather than replacing it
- kept 3 techs: Aurora, Bering Strait Umiaks, and the Inuit Expansion big button
- `DENativeInuit` override unlocks them; `zpExtendedInuits` (dbid 41331, modelled
  on `zpExtendedAztecs`) puts the big button on the Trading Post

### The button-size system

The DLC Inuit ability, Arctic Acclimation, is drawn as a 2×2 overlay and
overlapped the `DEWarriorSocietyInuit`/`DEChampionInuit` upgrade button. The mod
had already solved this once for the Habsburg Radetzky March, and that solution
generalised into the `native-ability-minify` skill.

**Three flags control the size, and all three must be absent:**

| Layer | File | Flag |
|---|---|---|
| ability | `abilities.xml` | `<usebigabilitybutton3>` |
| command | `protounitcommands.xml` | `<usemediumbutton3 />` |
| tech | `techtreey.xml` | `<flag>DEUseMediumButton3</flag>` |

Dropping two of three changes nothing visible, which makes this easy to get
half-right.

**A fourth layer is not a flag.** The cloned `<associatedtech>` starts
UNOBTAINABLE and something must set it active, or the button draws and does
nothing. Vanilla does this from a civ tech — `DENatInuitResourcefulness` for
Inuit, `DENativeHabsburgColonialize` for Habsburg — so the mod overrides that
same tech.

Both variants stay defined at once; a pair of 0-cost shadow gate techs decides
which is live, so an unextended game is byte-for-byte unchanged.

There are now **8 small-button chains**: Bourbon Royal March, Auditore
Lighthouse, Blanik Knights, Imperial Command, Sultan Command, both Habsburgs, and
Inuit.

### Maps

- `zpcoldwar.xs`, `zplabradorcoast.xs` — subciv `inuitnatives` → `Inuit`
- `zpcoldwar.xs` — the two 50-unit avoid constraints retargeted from the deleted
  `zpSocketInuits` to the DLC's `deSocketInuit`
- all 5 `Native Inuit Village 0X` groupings rebuilt on `deSocketInuit`
- both maps got an all-player `Extended Inuits Plr` trigger

`zpunknown.xs` is deliberately untouched — it keeps its own `InuitNatives`
handling pending a separate rework.

The activation trigger is **not** inside `Human Check Plr`. That trigger is gated
on `ZP PLAYER Human`, and the tech modifies per-player Trading Post buttons — an
AI player would have been left with no expansion button while the AI rules tried
to research off it.

### Teutonic Knights — checked, no action needed

The DLC's Teutonic Knights are **revolution** content for Livonia
(`DERevolutionLivonia` → `deREVTeutonicKnight`), not a native civ. The mod's are
a native civ with its own sockets. All 29 mod Teutonic files are new paths, 0
overrides, and no string-id overlap. The only change made was adding the DLC
knight to `AbstractCrussaderKnight`, so the Paladin's aura reaches it.

## Failure modes worth remembering

**Stale `.xmb` masks `.xml` edits.** The engine loads `foo.xml.xmb` in preference
to `foo.xml` and recompiles some directories but not others. A *partial*
recompile is worse than none: a fresh `protounitcommandmods.xml.xmb` with a stale
`powermods.xml.xmb` produced a button that appeared and cast nothing, which reads
as a design error rather than a build error. Cost one playtest.
`native-ability-minify verify` checks freshness. Note the `.xmb` are
`alz4`-compressed — a raw string search proves nothing; decompress first.

**`mergeMode` vs `mergemode`.** The repo writes it lowercase 611 times. If the
parser is case-sensitive, the capitalised form *replaces* a vanilla tech's
effects instead of adding to them — on a civ enabler that silently strips every
unlock the civ has.

**Attribute spacing.** 168 of the techs use `name ="X"` with a space. Exact-string
lookups report "0 references removed" as success. Match whitespace-tolerantly and
assert on the count.

**Line endings differ per file.** `protomods.xml` is CRLF, `techtreemods.xml` is
LF. Writing the wrong one turns a 3-line change into a 190,000-line diff.

**Record identity is subtle.** Keying a singleton by its text makes every retuned
setting look like a drop plus an add; keying `transform` on `tech` turned 8
retuned transforms into 18 phantom drops. See the `vanilla-merge` skill for the
ordering rules.

## Remaining

**AI compatibility.** The Inuit AI has been adopted — `zpInuitTechMonitor` now
gates on `deSocketInuit` and its activation on `zpNativeHouseInuit`, both of which
resolve — but issues remain here. This is the open item.

Smaller, known:

- the monitor researches Influence, Umiaks and Aurora but not `zpInuitFeeders`,
  which the big button also unlocks
- `zpunknown.xs` still carries dog-villager, `UnknownAlliance` and `InuitNatives`
  references, pending its own rework
- 6 image overrides are byte-identical to vanilla and could be deleted
- a `.material` name-collision sweep was never run across all asset classes
