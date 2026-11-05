# Art name collisions with DLC content

Written 2026-07-25 against game build `24241387`.

## The class of problem

The mod ships 91 art files whose paths also exist in vanilla, and 3,079 that do
not. Most of the 91 are ordinary overrides. But some are **name collisions**: the
mod created a file, a later DLC shipped a different asset at the same path, and
the mod's copy now silently replaces the DLC's.

This is not a merge problem. Merging two unrelated models is meaningless — the
fix is to rename the mod's asset so both can coexist.

Collisions cannot be found by diffing content. They are found by asking: **does
any DLC-introduced proto's art reference a path the mod overrides?**

## A. Polish church — confirmed collision

`deChurchPolish` (Baltic Powers) has `animfile = buildings\church\polish_church.xml`.
That vanilla file loads:

```
polish_church_age2   _age2_con   _age2_damaged   _age2_deathanim   _age2_deathmodel
polish_church_age4   _age4_con   _age4_damaged   _age4_deathanim   _age4_deathmodel
```

The mod overrides **8** of those:

| File | Mod | Vanilla |
|---|---|---|
| `polish_church_age2.gr2` | 18 KB | 176 KB |
| `polish_church_age2.material` | | |
| `polish_church_age2_con.gr2` | 118 KB | 59 KB |
| `polish_church_age2_con.material` | | |
| `polish_church_age4.gr2` | 48 KB | 335 KB |
| `polish_church_age4.material` | | |
| `polish_church_age4_con.gr2` | 126 KB | 83 KB |
| `polish_church_age4_con.material` | | |

`_damaged`, `_deathanim` and `_deathmodel` are **not** overridden, so the DLC
church currently renders a mixture: mod base and construction models, vanilla
damaged and death models. Broken either way round.

### Answer to "is it only models and .material files?"

Yes — for this building, exactly 8 files: 4 `.gr2` + 4 `.material`. Textures are
safe: the mod's materials point at `buildings\church\textures\swedish_church_*`,
which do **not** exist in vanilla. (The mod's "polish church" is in fact a Swedish
church skin, which is why the model differs so much.)

### Rename plan

Use the `zp` prefix so the names become unique, as you suggested. Rename the mod's
files and repoint every reference:

```
art/buildings/church/polish_church_age2.gr2        -> zppolish_church_age2.gr2
art/buildings/church/polish_church_age2.material   -> zppolish_church_age2.material
art/buildings/church/polish_church_age2_con.gr2    -> zppolish_church_age2_con.gr2
art/buildings/church/polish_church_age2_con.material -> zppolish_church_age2_con.material
art/buildings/church/polish_church_age4.gr2        -> zppolish_church_age4.gr2
art/buildings/church/polish_church_age4.material   -> zppolish_church_age4.material
art/buildings/church/polish_church_age4_con.gr2    -> zppolish_church_age4_con.gr2
art/buildings/church/polish_church_age4_con.material -> zppolish_church_age4_con.material
```

A `.gr2` names its material internally, so the `.material` rename must be applied
inside the model too, or the renamed model will look for the old material name.
Verify this per model before committing — it is the step most likely to bite.

Three art definitions reference the old names and must be rewritten:

| File | References |
|---|---|
| `art/buildings/church/old_northern_church.xml` | `polish_church_age2`, `polish_church_age4` |
| `art/buildings/hanseatic/hansa_townhall.xml` | `polish_church_age2` |
| `art/buildings/test/prop_church.xml` | `polish_church_age4`, `polish_church_age4_con` |

Each is referenced by one proto in `protomods.xml`. No `data/` change is needed —
the protos point at the art *xml*, whose filename does not change.

### Verification

1. No file under `art/` named `polish_church_*` remains in the mod.
2. `mergetool classify art/` no longer lists any `polish_church` override.
3. In game: the mod's northern church / hansa townhall still render, and
   Poland's `deChurchPolish` renders the DLC model in age 2, age 4, under
   construction, damaged and on death.

## B. Finding the rest — this is deterministic, no guesswork needed

The reference graph is finite and fully readable with `bar-extract`, so the sweep
below needs no sampling and no judgement calls.

### B1. Collision sweep

1. Diff `scripts/source/protoy.xml` (pre-Baltic, verified: `deDanish` 0→3,
   `Folwark` 1→103) against the current build. 2456 → 2668 protos, **226 new**.
2. For each new proto, read `<animfile>` and open that art xml from vanilla.
3. Parse it for `<file>` references — models, anims, composites.
4. For each `.material` reached, parse `<texture override="...">` for `.ddt`.
5. Recurse until closed.
6. Intersect that closure with the mod's 91 art overrides.

Anything in the intersection is a collision like the Polish church. This is exact:
either a DLC proto's art references a path the mod overrides, or it does not.

### B2. Missing models and animations

For each overridden art `.xml`, compare the vanilla version's `<file>` and anim
references against the mod's. Vanilla-only references are content the mod's copy
does not load — the art equivalent of the missing `<typedanim>` we found in the
tactics files.

### B3. Dangling references

For every art file the mod ships, check that each referenced model, material,
texture and anim resolves in either the mod or vanilla. Anything unresolved is
already broken today, independent of the DLC.

### Why no baseline is required

Dating art changes is impossible — `scripts/source/art/` covers only 6 of the 91
overrides, so "vanilla has X, mod does not" cannot be split into *the DLC added
it* versus *the mod removed it deliberately*. B1 sidesteps that entirely by
keying on **which protos are new**, which the proto diff answers exactly.

Only B2 carries the old ambiguity, and it is a review list, not an auto-fix.

## C. Order of work

1. Run B1 — the collision list is the urgent output; every entry is silently
   replacing DLC content right now.
2. Fix the Polish church (section A) as the worked example.
3. Work the rest of the B1 list the same way, renaming rather than merging.
4. Run B3; it is cheap and catches pre-existing breakage.
5. Treat B2 as a review queue.

## Known cases to check first

- `polish_church_*` — confirmed, section A
- `art/buildings/church/textures/cossack_church_mata_{BaseColor,Masks,Normals}.ddt`
- `art/buildings/church/dutch_church.material` and its `dutch_church_mata_BaseColor.ddt`
- `art/buildings/church/{portuguese,russain_church,spanish_church}.gr2`
- the 8 `art/lightsets/*.lgt` — the mod's are supersets of vanilla, so probably
  safe, but they are overrides of files the DLC also touches
