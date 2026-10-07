# Mask sources

`details_mask.py` max-combines two sources into one Details map. Give the texels the owner named and nothing else;
report every face the mask reaches.

## Faces (geometry or class selection)

Pick faces by **structure**, not by height slabs or UV rectangles. For example, a lower infill panel is a wall face
with a mid rail directly above it (the wall continues above the rail) and a sill directly below it. List every
excluded face of the class with a reason. The selection logic belongs to the consuming project. The skill takes the
result as ids.

### Coverage completeness, separate from leakage

Before selecting face IDs, inventory the intended painted **architectural roles** on
every facade and repeated bay. Record role, facade/bay, intended weight, receiving
faces or painted subregion, and a reason for every exception. A name filter such as
`skirt` is only an implementation aid: equivalent end walls may use different names.
Show front, rear and both sides with the intended coverage highlighted. A collision
check proves that colour does not leak; it cannot prove that a missing band exists.

For a building set, repeat the paint grammar by role (for example lower wall band
plus courtyard trim), adapting it explicitly to open stalls versus enclosed walls.
Inspect the reference's actual Details channel; red or green BaseColor alone is not
proof of player colour. Atlas mask percentage is not visible surface coverage.

Declare paint roles before UV sharing. Then test actual shared texels, including
partial-face stripes and shared atlases, against all visible unpainted receivers.
An owner-family match is a useful warning, not an exact leakage verdict. Never
paint a shared reference atlas to repair a single building or silently create new
pages. Resolve any required scoped UV change through the existing freeze contract.

Evidence: Korean military r50 (2026-10-07, INC-115): selected skirt/coping pieces
passed collision checks while equivalent end walls and Stable secondary accents
were omitted. Japanese Bansho/Stable and Chinese War Academy Details masks instead
show repeated bands. See the consuming project's `PLAYER_COLOUR_R50.md` audit.

`faces.json` holds every face of the page, not only the selected ones, because sharing and the soft edge are
judged against the neighbours:

```json
{"size": 2048, "faces": {"Obj:1295": {"uv": [[0.101, 0.220], [0.130, 0.220], [0.130, 0.236]], "seen_px": 42}}}
```

Dump it from the final low mesh in Blender (UV0; one page = the faces whose material maps to that texture page):

```python
import bpy, json
def dump(obj, page_materials, uv_name=None, seen=None, size=2048, path='faces.json'):
    me = obj.data; uv = me.uv_layers[uv_name] if uv_name else me.uv_layers[0]
    out = {}
    for p in me.polygons:
        if obj.material_slots[p.material_index].name not in page_materials:
            continue
        k = f'{obj.name}:{p.index}'
        out[k] = dict(uv=[list(uv.data[li].uv) for li in p.loop_indices])
        if seen is not None:
            out[k]['seen_px'] = int(seen.get(k, 0))
    json.dump(dict(size=size, faces=out), open(path, 'w'))
```

`seen_px` = the face's best visible pixel count over the review cameras (an ID render). If it is missing, every
member counts as seen, which is the strict setting.

Rules the script enforces:

- **Texel groups**: faces whose centre-rasterised texels overlap by >= 3 are one group. Details shares UV0, so a
  painted group colours all of its members.
- **Refusal**: a group with a selected face and a *seen* unselected face is refused. The report proposes giving the
  selected faces their own texels, which is an unshare in the UV stage. Never accept collateral colour silently.
  Never-seen members are painted and listed.
- **Soft edge**: coverage is supersampled 4x4 per texel against the unselected neighbours, so a texel shared on a
  chart border gets its covered fraction. `check_state.py` later reports such neighbours as soft-edge (mean
  R <= 0.5), not as leaks.
- **Gutter**: dilation of 10 steps (match the BaseColor's) keeps lower mips from showing an uncoloured seam.

## All-reader audit before a new placement (military r50 evidence)

An owner-only export or bake-triangle file is not a complete list of surfaces
reading a texture. Use the authoritative full face-sharing plan (or full scene)
and explicitly prove that every stacked/mirrored reader was included. Two faces
both selected for a lower band can still conflict when their UV directions place
those bands on different texels. Compare requested weights at corresponding
texels, not only selected face sets or owner-family names.

Check shared atlas routes as well as the unique page. Some shared faces can be
visible bevels, rail ends or coping sides; shared material does not prove hidden
geometry. A protected shared atlas cannot receive a building-specific mask.
Separate paint roles before conjoining, or record the exact UV/material-index
exception required later. Same material and shape alone are insufficient when
one rail must be painted and another must remain natural.

Military r50 found six conflicting Barracks target faces and86 Stable targets;
one conservative owner-family warning cleared on the actual texels, while another
was only a15-texel border contact. Preserve safe reuse; do not unshare whole
families because of a name-based warning. Centre-texel clearance still requires
filtered-edge, padding, mip and multi-colour visual checks before acceptance.

An allocation proposal measures padded shapes in existing gaps at unchanged
density. Total free area is not a fit proof. Retain unsuccessful placement as
evidence, never as permission for a silent repack or resolution reduction.

## Procedural (segment a painted field in the existing BaseColor)

Use this when the owner wants the colour on painted detail that is already in the texture (lattice cells, stripes,
panels of one paint colour) and does not want the image regenerated. The region (`--region` PNG, or `--region-faces`
ids rasterised from faces.json) bounds the search. Each connected region component (one gable, one panel) is split
on its own:

1. Lab of the linear BaseColor. The field candidates have a hue in [`--hue-lo`, `--hue-hi`] and chroma >=
   `--min-chroma`. That excludes the frames, emblems and pale bands of other hues or low chroma.
2. **Otsu split on the hue** of the candidates. `--pick low|high` chooses the side. Hue, not luma: soot, fading and AO
   darken lines and cells alike, so a luma split merges them (the synthetic test shows 1.00 accuracy on hue against
   0.74 on luma under a soot gradient).
3. 4-connected components are the cells. Specks < `--min-cell` are dropped and enclosed holes <= `--hole-max` are
   filled (paint flakes).
4. The soft 1-texel edge is the ring texel's own field fraction from the hue and chroma distances, clamped to
   [0.5, 1] inside a cell and [0, 0.5] outside.

Tune on the texels, not by eye. Print the report's `hue_cell_median`, `hue_line_median` and `hue_split_deg` per
region; a region with no field reports `no field` and adds nothing. The defaults are the Korean TC gold (cells about
76 deg, lines about 88 deg, red frame about 35 deg, pale band chroma about 12): 55-100 deg, chroma >= 25, pick low.
