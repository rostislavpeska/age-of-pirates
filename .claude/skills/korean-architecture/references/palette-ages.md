# Palette, age progression and player color

These are owner decisions for the Korean set, not universal historical rules.

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

For plaster and wood, the owner rejected uniformly clean surfaces. Add restrained
material-scale variation and plausible dirt/contact buildup. Preserve structural
AO and normal separation; dirt is not automatically present in a normal map.
Once a dirt layer is composited into BaseColor or Masks, an export can carry it
there. Extra authoring masks need not become additional runtime texture sets.
Do not send masks/normals through a paid photographic upscaler without an explicit
channel-specific reason and validation. No paid calls are part of these recipes.
