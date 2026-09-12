---
name: grouping-model-swap
description: Replace one proto by another inside random-map groupings while keeping the exact same model on screen (mesh + texture), when the two protos use different animfiles and different Variation lists - e.g. swap a walkable prop house for its solid twin, or a decal-less variant for the one with a decal. Use when a grouping unit must change proto "but look identical", when props are not solid / units walk through houses, when asked which model a variation number spawns, or to build a side-by-side validation grouping for the editor. Triggers on "same model different proto", "solid variant", "keep the appearance", "which variation is this model", "house B to house E", "model for model", "variation index".
---

# Model-for-model proto swap in groupings

## The rule (editor-verified 2026-09-12)

`<unit variation="N">Proto</unit>` shows entry **N mod K** of the proto animfile's first
`<logic type="Variation">` list - K children in file order, 0-based. Entries are `<data>` holding either an
`<assetreference><file>` or a `<submodelref ref="Name">` (then the model is the `<submodel>`'s component
file). No Variation logic = one model, N irrelevant. The editor's spinner loops, so authored values like
99 or 232 are ordinary indices (99 mod 13 = 8). Same model file in both animfiles = identical look including
texture, because the `.gr2` carries its own material.

So a swap is a lookup: `model = src_list[N mod K_src]` -> find the target proto whose list contains that
model -> `variation = its index there`. Models without a twin in any target stay on the source proto.

## Procedure

```bash
S=.claude/skills/grouping-model-swap/scripts; U="C:/Users/TIGO/Games/Age of Empires 3 DE/76561198347905238/RandMaps/groupings"
python $S/model_swap.py table    --from zpNativeHouseVenetianB --to zpNativeHouseVenetianE,zpNativeHouseVenetianG,zpNativeHouseVenetianD
python $S/model_swap.py validate --from zpNativeHouseVenetianB --to zpNativeHouseVenetianE,zpNativeHouseVenetianG --out "$U"
python $S/model_swap.py game/randmaps/groupings --from zpNativeHouseVenetianB --to zpNativeHouseVenetianE,zpNativeHouseVenetianG --prefix IS_            # dry run
python $S/model_swap.py game/randmaps/groupings --from zpNativeHouseVenetianB --to zpNativeHouseVenetianE,zpNativeHouseVenetianG --prefix IS_ --apply --also "$U"
```

1. **table** - read both animfiles, print the index -> model map and which target/index carries each model.
   It also prints obstruction radii and the `VariationLocked` flag of every proto (see pitfalls).
2. **validate** - writes a side-by-side grouping into the USER groupings folder: per mapped model three
   rows, original proto with the small index (z=+12), the target proto (z=0), original with index+K
   (z=-12). Restart the editor, place it: all three rows must look identical per column. This is the
   only proof that counts - do it before touching real groupings.
3. **dry run** on the real folder, read the per-file list, then **--apply --also** so the repo copy and
   the user's `RandMaps/groupings` copy stay byte-identical (the game loads the user folder locally).
4. Re-run the dry run: it must report 0 placements left. Commit the groupings.

## Pitfalls that cost a day

- **Not every model has a twin.** Venetian House B has 13 entries; only generic_04/05 (-> E), generic_08/09
  (-> G) and house3b/3c (-> D) exist elsewhere; walls, floors, campanile, rialto stay B. F is the church
  (no counterpart at all). Never force a "closest" model - the user wants 1:1.
- **`VariationLocked`** (`<flag>` on the proto): the engine rewrites N to N mod K on scenario save only for
  locked protos; every proto proven to honour N in the editor was locked. If a target is NOT locked
  (`zpNativeHouseVenetianD`), verify it in the validation grouping first, or add the flag.
- **Obstruction is the point of the swap** but also a side effect: the target's footprint (E 3.4x4.1,
  G 3.8x3.0) may now overlap paths - place `NativeTownObstruction`/path blocks accordingly, and never
  swap inside wall groupings without the user (IS_Wall_* keep their B towers by decision).
- Only the matched `<unit>` lines change; formatting, ordering and CRLF survive. Unit ORDER matters to
  some map scripts (sockets resolved as "last unit"), so never reorder.
- User-edited groupings: the user often has newer copies in `RandMaps/groupings` (added obstructions).
  Check mtimes and copy user -> repo before swapping, otherwise their work is overwritten by `--also`.
- Vanilla protos/animfiles: set `AOP_VANILLA` to a scratch extract root holding `vanilla/protoy.xml` and
  `allart/Art/...` (bar-extract skill) - never inside the repo.

Related: `grouping-terrain` (tiles, cliffs, heights, unit shifts, socket-last) and its `house_swap.py`,
the Venetian-specific predecessor of `model_swap.py`.
