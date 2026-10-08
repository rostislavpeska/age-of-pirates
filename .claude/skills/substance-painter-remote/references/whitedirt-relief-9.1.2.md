# White-coat Dirt relief on Painter 9.1.2 (owner's plaster recipe, scripted)

Owner technique (2026-10-08, used on his Elector castles): a fill layer coloured white with a positive
height, masked by Painter's built-in **Dirt** generator, over the base plaster. It produces irregular
top-coat islands with soft raised rims, the "premium double-layer normal map". Proven by script on
Painter 9.1.2 twice on 2026-10-08 (Korean Barracks/Stable/Town Center plaster): 168 and 372 bounded
LegacySession steps, no crash, all generator values read back exactly after save/close/reopen.
Run evidence and scripts: the Korean `r70b` 2d-asset packages (`painter/` folder) in the AoE Buildings library.

## Mesh

- One texture set per surface to treat: assign the target faces to their own material
  (`plaster_B`, `plaster_S`, `plaster_T`); everything else goes on one tiny `context` occluder set
  that is never baked, painted or exported.
- Shared/stacked UVs: keep **one representative face per identical-UV group** (largest 3D area first)
  so each texel is covered once; check IoU against the feature mask (reached 0.991-0.9996).
- Owner faces may not cover every used texel (member-only strips, INC-137): add filler quads with
  exactly the missing UV rectangle, placed in the face plane and moved far away so nothing occludes.

## Project (public API)

1. `project.create` at 2048 (2.2 s), bake normal/WSN/AO/curvature/position/thickness with the
   `connect_strong` completion pattern (7.8-11.6 s for 2-3 sets). A plainly connected callback is
   dropped and the wait never returns.
2. **After a bake call `ui.switch_to_mode(UIMode.Edition)`**; Painter stays in baking mode with the
   Layers dock hidden and LegacySession fails with "layer stack: expected one match, found 0".
3. Bind the asset's own **AO as the AO mesh map** (`TextureSet.set_mesh_map_resource(MeshMapUsage.AO, id)`).
   Painter's owners-only AO drives the Dirt mask into one solid block; Korean Masks.R is the AO.
4. `save_as` to a NEW name with the **true-case path** (the adapter compares path strings
   case-sensitively: `C--Users` vs on-disk `c--Users` fails, and saving over the open file with a
   different case raises ProjectError).

## Layers (bounded LegacySession, one structural step per batch)

```text
[select_ts <set>, inspect]
[select_layer <above>?, ensure_fill <name>, set_channels [height] (+ color for a colour probe), bind_texture Height <url>, inspect]
[select_mask <name>]                       # REQUIRED immediately before the next step
[ensure_generator_effect <name> 'Dirt']    # without select_mask it inserts an empty generator
[bind_generator resource://starter_assets/mg_dirt/mg_dirt?version=...]
[set_generator_value ... , inspect_generator, save]
```

- Height texture value v maps to height 2v-1 (127 = 0). Coat 148-152/255 gives soft relief; 179 is
  too crunchy. **Height layers add**, they do not occlude: coat 151 + pit 110 = 133.5.
- `Grunge_Scale` is an integer slider (1.5 -> "Parameter readback mismatch").
- Measured settings (grunge_amount 1.0, edges_masking 0.5), coverage inside the plaster masks:

| Set | Coat level/contrast/scale | Pits level/contrast/scale | Coat / pits |
| --- | --- | --- | --- |
| Barracks | 0.46 / 0.75 / 2 | 0.30 / 1.0 / 6 | 49.3 % / 9.4 % |
| Stable | 0.44 / 0.75 / 3 | 0.20 / 1.0 / 5 | 51.6 % / 12.6 % |
| Town Center | 0.415 / 0.65 / 2 | 0.20 / 1.0 / 6 | 54.1 % / 10.6 % |

- Vary Grunge_Scale/contrast per asset: the grunge is laid out in UV space with the same default seed,
  so assets whose cells sit at similar UVs otherwise get the same pattern.
- Measure coverage with **probe channels** (coat layer base colour white, pits layer roughness white),
  not from the summed height.
- Layer opacity and the generator Invert toggle are not in the bounded adapter.

## Export and use

- 16-bit Height works only through an `exportParameters` entry filtered to
  `outputMaps: ['$textureSet_Height']` with `bitDepth: '16'`; `bitDepth` inside the map definition is
  ignored (8-bit output).
- Outside the treated faces the exports are dilated edge fill: clip to the feature masks.
- Where the bound AO is near black (door openings, contact strips) both generators saturate into flat
  raised blocks with hard steps: exclude or feather AO < ~0.1 before compositing.
- Painter's BaseColor from this recipe reads too light and procedural on its own; use the coat/pit
  masks and the height for relief and grade the colour in the compositor (warm cream top coat over a
  warmer, darker under-coat, feathered island edges, no dark seam lines).
