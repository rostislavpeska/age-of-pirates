# Palette, age progression and player color

These are owner decisions for the Korean set, not universal historical rules.

## Korean identity within the AoE Asian set

Owner direction, 2026-10-07: Korean buildings must keep their specific visual
language and still belong alongside AoE's Asian buildings. Use two reference roles:

- **Korean identity:** the accepted Korean Town Center anchors roof profiles,
  upturned wooden ridges, rounded tile ends, timber lattice and subdued hanji,
  palette and age-appropriate decoration.
- **Asian-set compatibility:** role/age-matched vanilla Japanese and Chinese
  buildings anchor game-scale readability, value contrast, material roughness,
  detail scale, contact shading and weathering. Adapt those rendering qualities
  while retaining the Korean structural and decorative choices.

Compare the candidate, TC and relevant vanilla examples at matched camera,
lighting and displayed scale. Report Korean identity and set compatibility as
separate visual findings; inspect full-building/game-scale views as well as crops.
For windows, cooler infill is a controlled comparison option: judge separation
from plaster and convincing frame recesses before escalating blue tint or AO.
This art direction does not accept a pending revision or expand its asset budget.

## Sign text: use the game's Korean localization

The owner requested Hangul instead of the earlier Hanja plaque and asked for the
official AoE wording. Verified directly in the installed AoE3 DE `Data.bar` on
2026-09-30: `Data/protoy.xml.XMB`, unit `TownCenter`, `displaynameid` **22841**;
`Data/strings/Korean/stringtabley.xml.XMB`, `_locid="22841"` = **마을 회관**.
The English table gives the same ID as **Town Center**. Use `마을 회관`, left to
right, on this model. Earlier suggestions `근민헌`, `시청`, and `읍사무소` were
superseded by the request to follow the game's official translation.

For future named buildings, resolve the actual proto's string ID in the installed
Korean table using `bar-extract`; do not invent a translation. Check the sign's
world-space reading direction: this Town Center's sign island is rotated 180
degrees in the atlas. Preserve its frame and keep text editable in the source.

## Material palette

| Feature | Current Fortress direction | Industrial direction |
|---|---|---|
| Lattice | Simple natural brown wood, visible joinery/bevels | Richer ornamental pattern; green-painted wood permitted |
| Filler | Greyish textured paper, restrained contact AO | Reassess with that model's brief |
| Roof | Dark clay, tile tone variation, restrained moss/worn lips | Carry coherent material character, tune to age/model |
| Green trim and gables | Preserve the darker original Claude-green impression | Elaborate decoration may increase with the age |
| Wall bottom player color | 100% weight | Preserve unless the owner changes the brief |
| Other designated green decoration | Approximately 90% player-color weight | Explicit mask, not every green pixel automatically |

The gable decoration's background was also requested darker. Do not brighten
it incidentally while converting painted decoration to player color. Preserve
the user's PSD/manual corrections; use a new scoped finish layer if needed.

In AoE3DE the Details texture's **red channel is the player-color weight**. Use
the existing player-color skill for actual encoding and shader behavior. The
owner's source direction was light grey/white painted wood or stone under the
mask, with material texture retained; the later darkening and 90% change describe
the desired rendered result. Do not multiply an already tinted screenshot back
into the source or assume a green BaseColor is the correct neutral substrate.

Treat neutral material, mask weight and preview player's tint as separate controls.
Verify several player colors on the full model. A 90% weight is a channel value,
not a gamma-space visual blend guessed from a screenshot. Export and decode the
Details map to check that compression preserves the intended weights and leaves
unpainted surfaces unaffected.

For gable borders, first account for the complete visible wooden gable, including
connected coplanar corner patches and short vertical returns. Derive the painted
border from the union's outer boundary, not just the sloping top or one named
panel. Validate both sides and all shared UV readers. Military r57 recorded a
failure where the central-panel check passed but four small Barracks corner
triangles remained undecorated; the project `KR-FINISH-01` card holds the recipe.

### Complete bands and restrained red timber (military r58)

The owner's "blue stripe all around all walls" is a complete architectural role,
including both ends, courtyard returns and elevated clerestory walls. A mask with
no leakage can still fail this brief by omitting entire walls. Use the player-colour
skill's per-component coverage check and front/back/corner review. If mirrored
upper plaster shares the proposed band texels, make scoped planar band cuts and
reuse compatible existing skirt texels at the original density. Do not tint the
upper plaster, duplicate whole wall charts or create another runtime page.

For restrained TC red wood, reuse the accepted TC pigment and weathering recipe:
seokganju `#8B3A2C`, faded wood `#948878`, soot `#2A241E`, 55% photographic high-pass
grain, paint roughness 0.55 and reduced grain normal strength. In military r58 the
scope is structural posts and gate timber, preserving natural-brown window frames,
roof ridges and fence rails. These values reproduce an authored TC recipe; they
are not a historical claim or a substitute for matched-lit comparison.

Gate decoration must cover the visible broad leaves continuously. Inspect thin
edge faces sharing the broad face's UV: an all-reader exclusion can protect the
edge yet cut a hole through the ornament. Reusing an existing congruent broad-leaf
patch repaired this without a new page or density loss. Validate the repaired
leaf in the model, not just its atlas. r58 is a candidate until visual/export checks
finish; the measured band repair added 217 vertices/184 faces across both models,
used zero new atlas area, and kept roughly 112/112 texels per model unit.

For plaster and wood, the owner rejected uniformly clean surfaces. Add restrained
material-scale variation and plausible dirt/contact buildup. Preserve structural
AO and normal separation; dirt is not automatically present in a normal map.
Once a dirt layer is composited into BaseColor or Masks, an export can carry it
there. Extra authoring masks need not become additional runtime texture sets.
Do not send masks/normals through a paid photographic upscaler without an explicit
channel-specific reason and validation. No paid calls are part of these recipes.
