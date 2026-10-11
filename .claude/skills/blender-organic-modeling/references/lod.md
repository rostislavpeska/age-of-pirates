# Low LODs from a skinned mesh (G5)

Source keys refer to [sources](sources.md).

## 1. Decide whether a LOD is made (should)

- A low LOD is optional. Decide it with the owner and from the target game's precedent: the game layer says whether
  the engine selects a LOD, how, and whether shipped assets of this kind use one.
- Record the decision, the LOD triangle target and its texture route in the handoff before budgeting it.

Check: the handoff carries the decision and, when a LOD is made, the reference LOD-to-full triangle ratio it aims for.
Source: process rule of this skill; the precedent is the game layer's reference measurement.

## 2. Build it by hand (should)

- Dissolve loops of the full mesh, or remodel over it with face snapping (B12). Keep the same UVs where the texture
  route shares the page.
- Never ship a raw Decimate result: Decimate is not meant for economically modelled meshes and makes slivers (B13,
  L7). It may produce a draft, since it keeps vertex groups (L7).

Check: the sliver share (triangles with a minimum angle under 10 deg) is no higher than the reference LOD's; the
triangle count is inside the target.

## 3. Each LOD binds to its own target skeleton (must)

- Bind the LOD to the skeleton file the game ships for that LOD. A shipped LOD can differ from the full model in bind
  angles, bone-name spelling and the set of bound bones; validate against that file, never against the full model's.

Check: the bind and skeleton checks of [contract and blockout](contract-and-blockout.md) (section 3 and 4), run
against the LOD donor. Source: the game layer's reference measurement (whether its LOD skeleton files differ from
the full model's) and contract section 3 (a fixed skeleton per file); without that measurement, assume they differ
and compare.

## 4. Weights at distance (should)

- Use the LOD's own influence cap (often 2 for distant LODs; the game layer gives it), then Limit Total and Normalize
  All ([skinning and pose tests](skinning-pose-tests.md), section 2).
- At joints, one shared blended row at about 0.5, or a rigid seam, is acceptable at distance. This is a judgment call
  against PC1's collapse warning, made because the LOD is seen small: test the primary pose and accept mild volume loss
  but no limb crossing.

Check: maximum influences <= the LOD cap; in the primary pose, no BVH overlap between the thighs or between arm and
chest.

## 5. Keep the silhouette (should)

- Keep the full model's silhouette: save triangles in interior loops and mid-limb roundness, never in headgear, crest
  or weapon height. Simplify the head to a block (E8).
- Bounding box per axis within the range of the reference LOD pairs; without a measurement use 0.90-1.10 of the full
  model as a provisional heuristic, and never shorter than the full model by more than 2 %.

Check: per-axis bounding-box ratios; silhouette IoU against the full model at the smallest on-screen size, no worse
than the reference LOD pair at the same camera (the sheet of [contract and blockout](contract-and-blockout.md),
section 7).

## 6. Texture route (should)

Decide explicitly: the LOD shares the full model's page through its first UV set, or it gets a small page of its own.
Prove the chosen route loads in the game (bench test from the game layer) before relying on it.

Check: the LOD's UVs lie inside the chosen page; the bench result is recorded. Source: process rule of this skill
(prove a route in the game before relying on it).
