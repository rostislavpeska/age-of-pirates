# Contract, skeleton, blockout and silhouette (G0, G1, final silhouette)

Source keys refer to [sources](sources.md). "Reference asset" means a shipped asset of the target game of the same
kind (a shipped rider for a new rider); the game layer names which one and supplies its measurements.

## 1. Session-start contract (must)

Agree these terms before modelling and record them in the phase handoff (`conventions` and `open_issues`). Repeat
an existing owner-confirmed contract instead of asking again. A missing term is asked, never guessed.

| Term | What to record |
| --- | --- |
| Target skeleton | donor file, bone table (names, parents), the bones that may carry weight, bind pose, root and origin placement |
| Frame and scale | import route, working scale, axis frame, export route back ([conventions](../../blender-asset-conventions/references/scene-and-export.md)), and whether that route has already carried new skinned geometry into the game; if not, the G0 round trip ([skinning and pose tests](skinning-pose-tests.md), section 12) |
| Reference asset | the shipped asset of the same kind that sets the floors and ranges, and who measured it |
| Budget per LOD | triangles after triangulation, GPU-vertex estimate, material slots, influence cap |
| Skinning model | linear blend or dual quaternion, with its evidence level ([skinning and pose tests](skinning-pose-tests.md), section 6) |
| Test animations | every clip the asset will play (idle, move, attack, death, work), plus the mount and its paired clips for a rider |
| On-screen size | game camera pitch and the asset's pixel height, measured from an existing in-game capture |
| Texture budget | page count and size, handed to the organic UV skill (`blender-organic-uv`) |
| References | URLs or file paths of the pinned visual references |
| Design deviations | every deliberate departure from the references for readability, for the owner to approve |
| LOD decision | whether a low LOD is made, and how the engine selects it |
| Weapon and props | rigid attachment or skinned chain, decided before modelling ([clothing and armour](clothing-armour.md)) |

Check: every term has a value or an `open:` line naming who decides; nothing past G1 starts with an open budget,
skeleton or test-animation term. Source: process rule of this skill (agree before modelling); R8 describes the same
plan-first order in a studio pipeline.

## 2. References (must)

- Pin the primary references before modelling and write their URLs or paths into the handoff, under
  `conventions.references` (the handoff contract has no top-level `references` field).
- Prefer primary sources (museum objects, period plates, official art breakdowns) over reposts.
- Keep verified facts (what a source states) apart from readings of an image; a plate that cannot be text-checked
  stays "reference to inspect", not a fact.
- Exaggeration for readability is a recorded design deviation, not history: list it under
  `conventions.design_deviations`, and add an `open_issues` line for each deviation the owner has not approved yet.

Check: `conventions.references` has at least one primary source per major part (body, headgear, garment, weapon);
`conventions.design_deviations` lists each exaggeration; every unapproved deviation has an `open_issues` line.
Sources: R8 (Total War artists research and plan seams and reuse during the sculpt).

## 3. The skeleton is fixed input (must)

When the asset must play existing animation clips, the skeleton is not yours to design.

- Import the target skeleton through the same route the export will take back; work in that frame.
- Never rebuild, rename, re-parent or move a joint, and never "tidy" the armature. In an engine that plays clips
  straight onto the skeleton, without retargeting, clips bind to bones (commonly by name, in some formats by index)
  and store full local transforms, so a changed name, hierarchy or rest transform shifts the mesh in every clip, and
  a bone that no clip animates keeps its rest pose and rides rigidly with its parent. An engine that retargets clips
  at load time may tolerate some differences; rely on that only after the game layer has proved it.
- Never generate the rig: Skin "Create Armature" makes one generic bone per input edge and, under a Mirror, rigs only
  the modelled half (A1, B11); Rigify and similar produce a different skeleton.
- A low LOD may ship with its own skeleton file whose bind, names or bound set differ from LOD0: validate each
  LOD against its own donor ([LOD](lod.md)).

Check: for every bone, the head position of the working armature equals the donor's within the project's skeleton
tolerance, with identical names, parents and order; the armature object's matrix equals the imported one; after
export the project's skin checker reports no bone added, removed, renamed or re-parented. Changing a bone's deform
flag for weighting is not a skeleton edit ([skinning and pose tests](skinning-pose-tests.md), section 1), but the
exported bone list must still equal the donor's.

## 4. Model in the bind pose (must)

- Model and skin in the donor's bind pose, whatever it is. Do not convert to a T-pose and do not model the pose the
  asset plays most.
- Name the primary deformation pose (for a rider: seated, legs spread around the barrel; for infantry: the combat
  stance) and test it from G2 on, not at the end.

Check: with the armature in rest position, an imported reference body evaluates to its raw positions (rest equals
bind); the bind angles measured on the export (hip, knee, elbow, arm, thigh spread) equal the donor's within 0.5 deg.
Source: process rule of this skill; it follows from section 3 (clips store full local transforms against the
donor's bind pose).

## 5. Proportions and stylisation (should)

- Segment lengths come from the skeleton and cannot change; every reused clip re-imposes them.
- Stylise through volume: headgear, shoulder line, weapon, garment flare. Size those from an overlay with a reference
  asset at the same scale and pose, not from figure-drawing canons, which are realistic norms (R16).
- Prefer bigger shapes to small parts for a high camera (R9, R10).

Check: overlay the new mesh and the reference asset in the bind pose; joint heads (pelvis, knees, elbows, head) sit
inside the new mesh (BVH ray parity, A4); head-plus-headgear span divided by total height lies within the reference
assets' span unless a deviation is recorded.

## 6. Blockout (should)

- Start by box modelling or from a base mesh over front and side references (PC7, PC8). Load the reference asset as
  a scratch overlay (`REF_` prefix, never exported).
- Model half-side with a Mirror modifier on X, Clipping and Merge on, the object origin on the skeleton mid-plane
  (B7).
- Skin modifier from joint vertices: a proportion blockout or a Shrinkwrap/bake target only, never the shipped mesh.
  Branch areas (crotch, armpits) give complicated, possibly overlapping topology (B11); the output has no UVs (L9);
  its Symmetry checkboxes do not mirror geometry, so put a Mirror above it. Ring count per edge is
  floor(edge length / (2 x mean radius)) + 1, capped at 128, with exceptions at branch and loose-end vertices (A9).

Check: after applying any generator, self-intersection count 0 (BVH overlap of the mesh with itself, ignoring pairs
that share a vertex), no n-gons at the crotch or armpits, triangle count inside the budget; no `REF_` object in the
export list.

## 7. Readability at the game camera (should)

- Render flat silhouettes in background Blender: Workbench, Flat lighting, Single colour black, transparent film,
  orthographic camera tilted to the game's pitch, 4-8 headings plus one side view (B18). Save the PNG and reload it
  to read alpha; Render Result pixels are not readable directly (L10).
- Size the renders to the asset's on-screen pixel height measured from an existing in-game capture. Taking a new
  capture is screen control and follows the project's screen-control rule. Until the size is measured, render at
  several small heights (for example 32, 48, 64 px) and say the size is provisional.
- Render the reference asset with the same camera, scale and pose beside it.
- Read hierarchy: the primary identifier (weapon, headgear) reads in every heading, and so does facing (R5, R6).
  Plan 3-5 large value blocks, with the strongest contrast at chest and weapon hand and darker values low (R5, R7, R8).

- The same sheet is rendered again on the finished, skinned mesh with every layer after G3 (section 10), and on
  each LOD at G5.

Check: alpha coverage per heading and IoU against the reference render; the identifier adds outline pixels compared
with a render where it is hidden; images go to the session scratchpad and are sent to the owner.

## 8. Spend triangles on the outline (should)

- Spend triangles on what changes the outline from the game camera (headgear, shoulder line, weapon arc, limbs around
  a mount); little on face detail, fingers and mid-limb roundness (PC3, R5, R11).
- Silhouette savings never come out of deformation rings at the groin, thigh root, knee or elbow.

Check: dissolve a candidate edge on a copy; if the silhouette mask XOR is 0 at every heading and the pose metrics
([skinning and pose tests](skinning-pose-tests.md)) are unchanged, dissolve it on the mesh.

## 9. G1 gate: blockout approval (must)

Present the blockout on the skeleton (bind pose and the primary pose), the silhouette sheet beside the reference
asset and the budget table. Detail modelling starts only after the owner approves. Adjusting a placeholder is not
approval.

The G1 handoff (phase `01_geometry`) asks for the owner's review, so the phase-handoff writer refuses it unless it
carries the delivery fields the contract enforces for `owner_review: pending`, status `review` or status `accepted`
(`blender-architecture-texturing/references/handoff-contract.md`, "Delivered means visible"; enforced in
`blender-architecture-texturing/scripts/handoff.py`, `delivery_errors`):

- `primary_blend`: the blockout `.blend`, listed as a `canonical` entry;
- `active_scene`: the scene that file opens on;
- `delivery.live_readback = {version, file_sha256, scene, viewer, at}` from the live viewer pair the
  [conventions](../../blender-asset-conventions/SKILL.md) name, matching that file and scene;
- after approval, status `accepted` with `owner_acceptance = {quote, at}`: the owner's own words and the date.

Write only contract fields: references, deviations, the budget table and the contract terms go under
`conventions`, undecided terms under `open_issues`, the silhouette sheet under `qa`; never invent top-level keys.

Check: the handoff writer accepts the G1 handoff (exit 0) with `owner_review: pending` before the review, and with
status `accepted` and `owner_acceptance` after it; no top-level key outside the handoff contract. Source: process
rule of this skill (approve before detail), enforced by the handoff contract.

## 10. Final silhouette gate, after G3 (should)

The blockout sheet approves proportions, not the finished asset: layers, plates, the weapon and the final triangle
choices change the outline after G1. Before UVs are frozen and before export, render the section 7 sheet again on
the finished, skinned mesh with every layer and the weapon, in the bind pose and the primary pose, beside the
reference asset at the same camera and pixel heights, and present it to the owner next to the G1 sheet.

Check: per heading, alpha coverage and IoU against the reference render are no worse than at G1, or the change is a
recorded design deviation; the identifier still adds outline pixels; the sheet is in the handoff `qa` block and was
sent to the owner. Sources: R5, R6, R7 (silhouette-first reads, judged in context at the game camera) and a process
rule of this skill (check again after the shape changes).
