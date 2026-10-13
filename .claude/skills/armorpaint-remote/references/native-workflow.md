# Tested native workflow

Upstream: [armory3d/armorpaint](https://github.com/armory3d/armorpaint), revision
`2ad9c473b2911c93bb755607f7951517976e9e64`, tested on Windows with D3D11.
Source was unchanged. Generated project compiled with portable clang-cl 23.1.3,
lld-link and xwin 0.10.0/MSVC 14.44 headers/libraries. This does not establish
compatibility with a released binary or another revision. Keep build provenance
and application assets alongside the executable; the executable alone is not
a portable distribution. Do not use an arbitrary binary from a third party.

## Hidden lifecycle

`--background --nowindow` are both required by this revision. `--nowindow` alone
in the first argument slot is missed by its parser. Use native Windows absolute
paths: forward-slash `C:/...` script paths were treated as invalid despite an
exit code of zero. Always JSON-escape paths placed inside C script strings.

Raw background `--export-textures` queues work for the next frame but may exit
before exporting. The adapter supplies an eight-frame script drain. Check actual
outputs and pixel changes. `script_timer` does not keep the background run alive;
`script_notify_on_next_frame` does. A longer script should schedule a bounded
number of frames and print a completion marker. A saved project must be reopened
in a second process before claiming editability/roundtrip success.

## Binding subset verified

- `script_import_asset(path, 0)`; OBJ and PNG inputs.
- `script_layer_new_color`, `script_layer_new_fill`, `script_layer_new_mask`,
  `script_layer_get`, `script_layer_set_name`, `script_layer_update`,
  `script_layer_delete`, `script_layer_count`.
- `script_material_create`, `script_material_create_node`,
  `script_material_get_node`, `script_material_connect`,
  `script_material_set_float`, `script_material_set_button`,
  `script_material_update`.
- `project_filepath_set`, `project_save(0)`; five-map generic PNG export.
- `script_set_pack_assets(1)` and `script_pack_assets("")` before saving a new
  deliverable. A packed effect project reopened and exported all five maps
  pixel-identically in a second process; still test portability on the consumer
  device rather than assuming the application's external asset paths are valid.

`script_material_set_float(node, 1, input_index, value)` sets an input default.
For `TEX_IMAGE`, button 0 is imported asset index. `TEX_COORD` output 2 is UV.
For `OUTPUT_MATERIAL_PBR`, inputs are BaseColor 0, Opacity 1, AO 2, Roughness 3,
Metallic 4, Normal 5. Native graph tests used TEX_IMAGE, TEX_NOISE, MAPRANGE,
CLAMP and MATH multiply/maximum. Query this runtime's `--print-api` before using
unverified bindings.

Two measured traps:

1. **Layer opacity:** set `parent_layer->mask_opacity` for effect strength.
   Setting the mask layer's opacity instead reduces masking and exposes the
   full fill. Keep the mask fully influential.
2. **Reversed MapRange:** disable the node's Clamp button and attach an explicit
   CLAMP [0,1] after reversed output ranges. Its built-in clamp used reversed
   bounds and produced broad tints in the failing specimen.

The colour smoke verified RGB [32,64,128] behind a black mask, then
[224,192,128] after disabling that mask. Roughness changed 178 to 76, AO 204
to 255. The flat native normal drifted one byte when adding a layer; preserve
the original Normal image for colour-only tasks. Imported base-image roundtrip
also resamples, so frozen-atlas pipelines need baseline-delta composition.

## Scope of integration

The stdio adapter invokes owned batch processes; it is not the application's
interactive mailbox MCP. It needs Python `mcp` only for the optional server,
and Pillow for image validation. Native scripts are trusted code and may perform
file writes: inspect scripts and use explicit new output paths. Input hash
checking detects a mutation; it is not a sandbox or rollback mechanism.

Texture projection, UV changes, all blend modes, mesh baking, arbitrary node
types, unattended GUI actions and exact engine lighting are not certified by
these tests. Follow the consuming project's texture budget and publication gates.

## Explicit page resolution (INC-288)

The stock native script API lacks project-resolution control. `export --size`
validates existing project dimensions; it does **not** resize. A 1024 request on
a default 2048 project correctly failed and its maps were not consumed.

The optional [14-line source extension](../patches/explicit-texture-resolution.patch)
applies to upstream `2ad9c473b2911c93bb755607f7951517976e9e64`. It exposes
`script_set_texture_resolution(size)`, returning false for invalid values.
It calls the application's existing queued layer resize and fill regeneration.
Square powers of two from64 through16384 are accepted; 512,1024 and2048 are the
measured paths, not a guarantee of device capacity at the largest values.
Preserve an unmodified build and build the extension as a separate executable.
The source patch is recorded as local commit
`88d0cf5caf7fb1646fea9da1ee8734977c073c98`.

Use `resize --input SOURCE.arm --out-dir NEW_DIR --size 1024` with this extended
runtime. It saves a **new** packed project, reopens it in another process and
checks all five exported dimensions. The stdio equivalent is
`armorpaint_resize_project`. No silent PNG downsampling or source overwrite.
For fresh authoring, call the native setter on frame1 and leave frames for its
queued resize before layer creation/save. The provided wrapper saves on frame5
and keeps the process alive through frame9.

Measured1024 smoke retained centreRGB `[224,192,128]` from the2048 original.
The castle's1024 native effect/baseline project exports also pass. Existing2048
fill scripts continue to pass. Consumer pixel/alpha/frozen-map tests still apply.
