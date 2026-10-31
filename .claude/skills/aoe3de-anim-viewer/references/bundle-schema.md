# Unit bundle, schema v0

The unit bundle is the cached, decoded form of one unit that the Python backend writes and the browser viewer reads.
Status: **v0, 2026-10-11**. Written by the backend's `scripts/bundle.py` (M1) through the helpers in
`scripts/av_common.py`; read by `viewer/lib/bundle.js` and posed by `viewer/lib/rig.js` (M2). The optional fields the
M1 modules added are listed in section 18. Field names here are the contract: a writer or reader that
needs a new field adds it to this file first. Fields marked *reserved* are present with the value shown and filled by
a later slice.

## 1. Where a bundle lives

```
<cache root>/<bundle_id>/manifest.json      the manifest (this document)
<cache root>/<bundle_id>/<buffer id>.bin    binary buffers named in manifest.buffers
served as  http://127.0.0.1:<port>/bundle/<bundle_id>/manifest.json   (scripts/server.py)
```

- `<cache root>` = `av_common.cache_root()`: `AOP_ANIM_VIEWER_CACHE`, else `<system temp>/aop-anim-viewer`.
- `bundle_id` = `av_common.cache_key(*inputs)`: 16 lower-case hex digits over the canonical JSON of the inputs.
  The inputs are the subject, the logic state set, the layer list with each layer's hash, and `tool.version`.
  The same `inputs` are stored in the manifest so the id can be recomputed.
- A bundle holds vanilla-derived bytes. It is never written inside a git work tree, an AoE3 profile or mods folder,
  or the install; `av_common.refuse_repo_path` refuses all of them (AGENTS.md rules 3 and 8).

## 2. Conventions

| Item | Rule |
| --- | --- |
| JSON | UTF-8, LF, written by `av_common.write_json` (atomic; NaN and Infinity refused) |
| Ids of game files | `av_common.logical_path`: forward slashes, lower case, relative to the game's `Art/` root (the `art/` prefix is dropped), with the extension. Examples: `units/asians/chinese/iron_flail/iron_rider_0.gr2`, `animation_library/cavalry/horse_idle_a.gr2`. Data files keep their folder: `data/tactics/handcavalrysplash.tactics` |
| Material ids | `<material file id>#<submaterial name>`: `units/asians/chinese/iron_flail/iron_rider_0.material#mata` |
| Frame and units | the gr2's own frame and units, as stored (engine frame, +Y up); nothing is converted to Blender or GXO frames |
| Vectors and matrices | row vectors: `p' = p @ M`. A 3x3 is 9 numbers, row-major. A 4x4 is 16 numbers, row-major, with the translation in elements 12, 13 and 14 |
| Quaternion | `[x, y, z, w]` |
| Transform | `{position: [3], orientation: [4], scale_shear: [9]}`, the Granny triple |
| Local matrix of a transform | upper 3x3 `L = R @ S`, where `R` is the row-vector rotation of the quaternion (the transpose of the column-vector matrix) and `S` the scale-shear 3x3 as stored. The translation row is `position`. This is `clip_decode.local_matrix` without its GXO frame change; the converter's key 0 of horse_idle_a matches only this order (2.8e-7) |
| World matrix | `W(bone) = L(bone) @ W(parent)`; root bones: `W = L @ model.root` |
| Skinning | `skin(b) = inverse_world(b) @ W(b)`; `p' = sum over i of w_i * (p @ skin(bone_i))`, at most 4 influences, linear blend (measured from the game's vertex shader) |
| Bone names | matched as the engine does: a space equals an underscore, case-insensitive (`unit_gr2.nm`) |
| Time | seconds (float). Tag positions are fractions of the clip (section 9) |
| Enumerations | lower-case strings listed in this document; a reader treats an unknown value as "unavailable" and shows it, never drops it |

The fixed block `conventions` repeats these choices so a reader can assert them:

```json
"conventions": {"frame": "gr2", "up": "+y", "vectors": "row", "matrix_order": "row-major",
                "quaternion": "xyzw", "local": "R@S", "time": "seconds",
                "curve_eval": "bspline-clip_decode", "quat_normalize": "newton1"}
```

## 3. Binary buffers

- **Byte order:** little-endian throughout. The JS reader refuses a big-endian host.
- **Buffer record** (`manifest.buffers[]`): `{id, uri, byteLength, sha256}`. `uri` is relative to the bundle folder,
  normally `<id>.bin`. Usual ids are `geo` (vertex and index streams), `anim` (curve knots and controls) and `tex`
  (texture blocks), but any id is allowed.
- **View record:** used wherever an array lives in a buffer:

  | Field | Type | Meaning |
  | --- | --- | --- |
  | `buffer` | string | the buffer id |
  | `byteOffset` | int | start in the buffer, **a multiple of 16** |
  | `byteLength` | int | `count * components * size(dtype)` exactly |
  | `dtype` | string | one of the table below |
  | `count` | int | number of elements (vertices, keys, texels...) |
  | `components` | int | values per element (1 for a plain array) |
  | `normalized` | bool | the GL attribute flag: true for snorm/unorm streams |

- **Dtypes:**

  | dtype | bytes | numpy | JS typed array | GL type |
  | --- | --- | --- | --- | --- |
  | `f32` | 4 | `<f4` | Float32Array | FLOAT |
  | `f16` | 2 | `<f2` | Uint16Array (raw halves; `halfToFloat` reads one) | HALF_FLOAT |
  | `u8` | 1 | `u1` | Uint8Array | UNSIGNED_BYTE |
  | `i8` | 1 | `i1` | Int8Array | BYTE |
  | `u16` | 2 | `<u2` | Uint16Array | UNSIGNED_SHORT |
  | `i16` | 2 | `<i2` | Int16Array | SHORT |
  | `u32` | 4 | `<u4` | Uint32Array | UNSIGNED_INT |
  | `i32` | 4 | `<i4` | Int32Array | INT |

- **Writing:** `av_common.BufferWriter(id).add(array, dtype, components, normalized)` pads to the next 16-byte
  boundary with zero bytes and returns the view. `.data()` gives the bytes and `.record()` the buffer record.
- **Reading:** `av_common.read_view(bytes, view)` returns a numpy array of shape `(count, components)`;
  `bundle.js viewArray(buffers, view)` returns the typed array over the fetched ArrayBuffer without copying.
- **Layout example:** a mesh of 1000 vertices:

  ```
  geo.bin  offset 0      Position             f32 x3  12000 bytes
           offset 12000  Normal               i8  x4   4000 bytes  (12000 is a multiple of 16)
           offset 16000  TextureCoordinates0  f16 x2   4000 bytes
           offset 20000  BoneWeights          u8  x4   4000 bytes
           offset 24000  BoneIndices          u8  x4   4000 bytes
           offset 28000  indices              u16 x1   1500 x 3 x 2 = 9000 bytes
  ```

## 4. Manifest: top level

| Field | Type | Meaning |
| --- | --- | --- |
| `schema` | string | `"aop-anim-viewer/bundle"` |
| `schema_version` | int | `0` |
| `bundle_id` | string | 16 hex digits (section 1) |
| `created` | string | UTC ISO 8601 time |
| `tool` | object | `{name: "aoe3de-anim-viewer", version, shader_model: "none" or "v1"..., calibration: "none" or a version}` |
| `inputs` | list | the cache-key inputs (section 1) |
| `subject` | object | `{kind: "proto" or "animfile", proto: name or null, animfile: animfile id}` |
| `conventions` | object | section 2 |
| `buffers` | list | section 3 |
| `layers` | list | the lookup order of the virtual file system (below) |
| `provenance` | list | one record per source file; other records point to it by index |
| `warnings` | list | silent engine failures and other problems, never hidden (section 13) |
| `logic` | object | logic types and their states (section 6) |
| `composition` | object | how the animfiles combine: horse, rider, attachments (section 10) |
| `animfiles` | object | animfile id -> animfile record (section 9) |
| `models` | object | model id -> model record (section 7) |
| `materials` | object | material id -> material record (section 8) |
| `textures` | object | texture id -> texture record (section 8) |
| `clips` | object | clip id -> clip record (section 11) |
| `proto` | object or null | protounit timing data (section 12) |
| `tactics` | object or null | the tactics file (section 12) |
| `timing` | object | the merged timing view with hypotheses labelled (section 12) |
| `lighting` | object | lgt, reflection cube, LUTs, player colours (section 14) |
| `fidelity` | object | M, A, U or H per stage (section 15) |
| `oracles` | object | *reserved*: `{"precomp": null}` (section 16) |

**Layer record:** `{id, kind, title, priority, enabled, source}`.
- `id`: `mod:<folder title>` or `game`.
- `kind`: `mod` or `game`.
- `source`: for mods, `mods/age3-mod-status.json`; for the game, the archives.
- Order: the list is the lookup order, and the first layer holding a file wins.
- Mods come from `age3-mod-status.json`: enabled mods only, the lower `Priority` value first (AoP has 1).
- The Koreans add-on is the sibling folder `mods/local/age-of-pirates-koreans`, a mod layer like any other.
- `game` is always last.

**Provenance record:** `{layer, path, sha256, size, container, note}`, built by `av_common.Provenance.add`.
- `layer`: a layer id, or `synthetic` or `tool`.
- `path`: the logical path inside the layer.
- `sha256`: of the bytes as read, before any XMB decoding.
- `container`: the `.bar` file name for the game layer, else null.

Records point to it as `"provenance": <index>`.

## 5. Unavailable content

Nothing the subject references is dropped. A record that cannot be decoded keeps its id and says why:

```json
{"decodable": false, "unavailable_reason": "gr2-compressed-oodle1"}
```

Reason codes:
- `gr2-compressed-oodle1`, `gr2-compressed-oodle0`, `gr2-compressed-bitknit`, `gr2-compressed-unknown-<code>`
- `gr2-32bit`
- `curve-format-<name>` (for example `curve-format-d4nk16uc15u`)
- `file-missing`, `xmb-decode-failed`, `ddt-format-<code>`

The viewer lists every such record in its audit panel and draws a placeholder instead. Each also raises a warning
(section 13).

## 6. Logic

```json
"logic": {
  "types": {"Tech": ["none", "yphonoredironflail"], "LowPoly": ["normal", "lowpoly"]},
  "default": {"Tech": "none", "LowPoly": "normal"},
  "default_rule": "first branch of each logic type (a UI default, not an engine claim)"
}
```

Branch names keep the animfile's spelling. The union covers all animfiles of the subject.

## 7. Models

| Field | Type | Meaning |
| --- | --- | --- |
| `id`, `path` | string | logical path of the `.gr2` |
| `provenance` | int | index |
| `decodable`, `unavailable_reason` | bool, string or null | section 5 |
| `compression` | string | `none`, `oodle0`, `oodle1`, `bitknit`, `unknown-<code>` |
| `pointer_size` | int | 64 or 32 |
| `root` | 16 numbers | the root axis matrix, applied after the root bones; identity unless the M1 frame test says otherwise |
| `skeleton` | object | `{name, bones: [bone]}` |
| `meshes` | list | mesh records |
| `bounds` | object or null | `{min: [3], max: [3]}` of the rest-pose vertices |
| `root_count` | int | number of bones with parent -1. More than 1 adds the warning `gr2-two-roots`: the engine does not draw such a model |

**Bone:** `{name, parent, rest, inverse_world, flags}`.
- `parent`: index, or -1.
- `rest`: a transform (section 2), the bone's LocalTransform.
- `inverse_world`: 16 numbers, the file's InverseWorld4x4.
- `flags`: the Granny transform flags.

**Mesh:**

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | Granny mesh name |
| `vertex_count`, `triangle_count` | int | |
| `streams` | object | Granny vertex member name -> stream (below), e.g. `Position`, `Normal`, `Tangent`, `Binormal`, `TextureCoordinates0`, `BoneWeights`, `BoneIndices` |
| `indices` | view | `u16` or `u32`, 3 per triangle, as stored (Indices16 or Indices) |
| `groups` | list | `{material: material id or null, material_binding: name, first_triangle, triangle_count}` |
| `bone_bindings` | list | `{name, bone}`: the mesh's palette slot -> skeleton bone index (-1 = unresolved, plus the warning `bone-unresolved`) |

**Stream:** `{view, gr2_type, decode}`. The data is copied byte for byte from the gr2 vertex buffer (the GPU sees what
the game uploads).
- `gr2_type`: the Granny member type name (`real32`, `real16`, `int8`, `uint8`, `binormal_int8`, `normal_uint8`,
  `int16`, ...).
- `decode` is a closed list:
  - `float` (real32, real16)
  - `snorm` (binormal_int8, binormal_int16: `max(x / 127, -1)`, the D3D and WebGL rule)
  - `unorm` (normal_uint8, normal_uint16: `x / 255`)
  - `uint` (uint8, uint16, uint32)
  - `sint` (int8, int16, int32)
- `view.normalized` is true exactly for `snorm` and `unorm`.

Which semantic the game's vertex shader gives each member is checked against the shader model (M3), not assumed here.

## 8. Materials and textures

**Material:**

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | string | `<material file>#<submaterial>` |
| `material_file`, `submaterial` | string | |
| `provenance` | int | the `.material` file |
| `materialdef` | string | e.g. `default` |
| `slots` | object | slot name (`BaseColor`, `Normals`, `Masks`, `Details`, ...) -> `{texture: texture id or null, srgb: bool, source: "override" or "materialdef", unavailable_reason}` |
| `floats` | object | parameter name -> number or list, merged: overrides over materialdef defaults |
| `float_sources` | object | parameter name -> `override` or `materialdef` |
| `flags` | object | materialdef switches (cutout, double-sided, ...) as read |
| `eol` | string | `crlf`, `lf`, `mixed` or `xmb`. `lf` adds the warning `lf-only-runtime-xml`: the game ignores the file (AGENTS.md rule 1) |

sRGB belongs to the slot (the materialdef decides it), not to the texture. A texture used by an sRGB slot and a
linear slot is uploaded twice.

**Texture:**

| Field | Type | Meaning |
| --- | --- | --- |
| `id`, `path` | string | logical path of the `.ddt` |
| `provenance` | int | |
| `decodable`, `unavailable_reason` | | section 5 |
| `ddt_format` | int | the DDT header format code as read (4, 5, ...) |
| `bc` | string | `BC1`, `BC2` or `BC3` |
| `width`, `height`, `mip_count` | int | |
| `mips` | list | `{level, width, height, view}`: `view` is `u8`, one component, the raw blocks of that level, `byteLength` = `ceil(w/4) * ceil(h/4) * 8` (BC1) or `16` (BC2/BC3) |
| `fallback` | string or null | *reserved*: uri of a decoded RGBA8 PNG inside the bundle, for a browser without S3TC |

Upload rules (measured in the M0 spike, see `headless-gpu.md`):
- `BC1` is always uploaded as `COMPRESSED_RGBA_S3TC_DXT1_EXT`, or `COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT` for an
  sRGB slot. D3D11 BC1 decodes 3-colour index 3 as transparent black whatever the DDT header says.
- `BC3` is uploaded as `..._DXT5_EXT`.
- `TEXTURE_MAX_LEVEL` is set to `mip_count - 1`, so a chain that stops at 4x4 is complete.

## 9. Animfiles

**Animfile record:**

| Field | Type | Meaning |
| --- | --- | --- |
| `id`, `path` | string | logical path |
| `provenance` | int | |
| `eol` | string | as for materials; `lf` -> warning `lf-only-runtime-xml` |
| `source_form` | string | `xml` or `xmb`. An `.xmb` twin that wins over an edited `.xml` adds the warning `stale-xmb-twin` |
| `includes` | list | animfile ids pulled in by `<include>` |
| `definebones` | list | names as written |
| `attachments` | list | `{name, include: animfile id or null, used_by: [anim names], audit: [codes]}`. `declared-not-attached` when no `attach` uses it |
| `components` | list | `{name, tree, resolved, decals, attach}` (below) |
| `anims` | object | anim name (as written) -> anim record |

**Component:**
- `name`: e.g. `ModelComp`.
- `tree`: a logic node, kept in file order. A node is either
  `{logic: "Tech", branches: [{state: "none", node: <node>}, ...]}` or a leaf
  `{assets: [{type: "GrannyModel", model: model id, file: "<as written>"}]}`.
- `resolved`: every state combination flattened, e.g.
  `[{state: {"Tech": "none", "LowPoly": "normal"}, models: [model ids]}]`.
- `decals`: `{effecttype, texture, selectedtexture, width, height, isfakeshadow}` as read.
- `attach`: attach records (below).

**Anim:**

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | |
| `components` | list | component names the anim names (`<component>ModelComp</component>`) |
| `attach` | list | attach records declared inside the anim (the torch of Raze_idle on `R HAND`) |
| `variants` | list | one per `<assetreference type="GrannyAnim">`, in file order |
| `weights` | object | `{rule, normalized}` (below) |

`weights`:
- `rule`: `declared` (every variant has `<weight>`), `uniform-hypothesis` (none has one; equal weights are a
  hypothesis) or `mixed`.
- `normalized`: one number per variant, summing to 1.

**Variant:** `{index, clip, file, weight, animlengthoverride, tags}`.
- `clip`: clip id, or null when `file-missing`.
- `file`: as written.
- `weight`: int or null.
- `animlengthoverride`: seconds or null.

**Tag:** `{type, fraction, attrs, overflow}`.
- `type`: as written (`Attack`, `FootstepLeft`, `SpecificSoundSet`, ...).
- `fraction`: the element's number, a fraction of the clip.
- `attrs`: every other attribute (`footprintbone`, `footprinttype`, `set`, `checkvisible`, ...).
- `overflow`: `fraction > 1` (202 vanilla tags, up to 1.6; meaning unknown; drawn past the clip end).
- The viewer places a tag at `fraction * duration`. Whether `animlengthoverride` stretches tags is unknown, so
  `timing` labels it as a hypothesis.

**Attach record:** `{a, frombone, tobone, syncanims, allowrotation, attrs, resolved}`.
- `syncanims`: bool.
- `allowrotation`: bool or null.
- `attrs`: every other attribute (offsets and so on).
- `resolved`: `{attachment: name, animfile: id or null, frombone: bone index or null, tobone: bone index or null,
  notes: [codes]}`.
- `hotspot` exists in no rider gr2. It is engine-defined, resolved as the model origin, and adds the warning
  `engine-bone-assumed`.

## 10. Composition

```json
"composition": {
  "main": "units/asians/chinese/iron_flail/iron_flail.xml",
  "children": [
    {"animfile": "units/asians/chinese/iron_flail/iron_flail_rider.xml", "attachment": "RiderAttachment",
     "attach": {"a": "RiderAttachment", "frombone": "hotspot", "tobone": "ATTACHPOINT", "syncanims": true},
     "declared_in": {"animfile": "units/asians/chinese/iron_flail/iron_flail.xml", "component": "ModelComp"}}
  ],
  "pairing": {
    "rule": "same anim name; main variant i -> child variant i mod n",
    "status": "hypothesis",
    "sync_modes": ["absolute-time", "normalised-phase"],
    "mismatches": [{"anim": "Idle", "variant": 7, "main_duration": 3.667, "child_duration": 4.0}],
    "one_sided": [{"anim": "Highstep", "side": "main"}]
  }
}
```

- Horse and rider pairing is a labelled hypothesis until the timing run or the game's Animation Viewer settles it.
- `one_sided` lists anims present in only one animfile; the rider fallback shown for them is an assumption.
- A death anim whose clips are much shorter on one side (Death_by_havoc) adds the warning `ragdoll-not-simulated`.

## 11. Clips and curves

**Clip:**

| Field | Type | Meaning |
| --- | --- | --- |
| `id`, `path` | string | logical path of the animation `.gr2` |
| `provenance` | int | |
| `decodable`, `unavailable_reason` | | section 5 |
| `duration`, `timestep`, `oversampling` | number | as stored (seconds) |
| `fps_declared` | number | `1 / timestep` (60, 192, 30; 184-191 flagged non-integer) |
| `key_count` | int | `round(duration * round(fps_declared)) + 1`, the clip_decode key grid |
| `formats` | list | curve format names present (`K32fC32f`, `D3Constant32f`, `Identity`, ...) |
| `track_group` | object | `{name, initial_placement: transform or null}` |
| `tracks` | list | `{bone, position, orientation, scale_shear}`: three curves, dims 3, 4 and 9 |
| `precomp` | null | *reserved* oracle (section 16) |

**Curve:**

```json
{"kind": "bspline", "degree": 2, "dim": 4, "format": "K32fC32f",
 "knots": <view f32 x1, count K>, "controls": <view f32 x4, count K>}
{"kind": "constant", "dim": 3, "format": "D3Constant32f", "value": [0.0, 1.1418, 0.0]}
{"kind": "identity", "dim": 9, "format": "Identity", "inferred": false}
{"kind": "unavailable", "dim": 4, "format": "D4nK16uC15u", "reason": "curve-format-d4nk16uc15u"}
```

- An empty K32fC32f curve becomes `identity` with `inferred: true` (clip_decode reads it so).
- Identity values: position `[0, 0, 0]`, orientation `[0, 0, 0, 1]`, scale_shear the identity 3x3.

Evaluation contract (the JS side does all evaluation, Python only normalises):
- `bspline` is `clip_decode.bspline`: Cox-de Boor of the given degree, knot vector `u_m = K[m-1]` clamped at both ends,
  controls `C[i-degree..i]` on `[K[i-1], K[i])`.
- `t` is clamped to `[K[0], K[last]]`; a single knot means a constant.
- Orientations are renormalised with one Newton step, `q *= (3 - |q|^2) / 2`, in float32. This is the adopted
  default: it is what the Granny DLL is reported to do, unconfirmed on AoE3 data until the precomp oracle checks it.
- `knots` evaluation (every control a linear key) exists only as a debug view.

## 12. Proto, tactics and timing

**`proto`** (null when the subject is a bare animfile):
- `name`, `provenance`, `dbid`, `animfile` (id), `tactics_file` (id).
- `maxvelocity`, `maxrunvelocity`, `movementtype`.
- `protoactions`: `[{name, rof, damage, maxrange, fields}]`. `fields` keeps every child element as read.
- `techs_applied`: tech names whose effects were merged; empty in v0.

**`tactics`:**
- `id`, `provenance`.
- `actions`: `[{name, type, anim, idleanim, reloadanim, animationrate, rof, rate: [{type, value}], fields}]`.
- `tactics`: `[{name, speedmodifier, actions: [{name, priority}], anims: {idle, bored, death, walk, jog, run}, transitions, fields}]`.
  Each transition is `{tactic, length, exit}`.

**`timing`:** the view the timeline uses. Every inferred rule is labelled.

```json
"timing": {
  "actions": [
    {"action": "MeleeHandAttack", "anim": "Attack_melee", "rof_effective": 1.5, "rof_source": "protoaction",
     "rof_tactics": null, "animationrate": null, "clip_durations": [1.5, 1.5, 1.5, 1.5],
     "rules": ["H1: the protoaction ROF overrides the tactics ROF", "H2: tags scale with the clip, not with ROF"]}
  ],
  "status": "hypothesis"
}
```

- `rof_source` is `protoaction`, `tactics` or `none`.
- ROF comes from the proto's protoactions; the tactics file rarely carries one.
- A clip shorter than its ROF (Raze_attack 1.0 s against ROF 3.0) is the decisive in-game timing case.

## 13. Warnings

`{code, path, layer, message}`. Codes:

| Code | Meaning |
| --- | --- |
| `lf-only-runtime-xml` | the game ignores the file (AGENTS.md rule 1) |
| `stale-xmb-twin` | an `.xmb` is used instead of a newer `.xml` |
| `gr2-two-roots` | the model is not drawn by the engine |
| `gr2-compressed`, `gr2-32bit` | the model or clip is unavailable (section 5) |
| `curve-format-unsupported` | |
| `bone-unresolved` | |
| `attachment-declared-not-attached` | e.g. the Iron Flail `attachment_whip`; the whip is submaterial `matb` of `iron_rider_0` |
| `anim-one-sided` | |
| `tag-overflow` | |
| `engine-bone-assumed` | |
| `ragdoll-not-simulated` | |
| `attachment-effect-not-rendered` | the torch's `fire` item |
| `file-missing` | |

## 14. Lighting

Filled by `lighting.py` since M1 (a missing input stays null and raises `file-missing`); extra fields in section 18:
- `lgt`: `{name, id, provenance, fields}`. `fields` holds every lgt value as read.
- `refl`: `{id, provenance, size, mips: [{level, size, view}]}`. Each view is f32 x4, six faces in file order.
- `tonemap_lut`: `{size: 32, view}`, f32 x4, baked by `lighting.py`.
- `grade_lut`: `{id, size, view}`.
- `player_colors`: `[{index, rgb: [r, g, b]}]`, 0..255 as in `playercolors.xml`.
- `player_color_index`: int.

## 15. Fidelity

```json
"fidelity": {
  "calibration": "none", "shader_model": "none",
  "stages": {"skinning": "M", "pose": "M", "curve_sampling": "A", "vertex_input": "M", "texture_decode": "M",
             "material": "M", "brdf": "M", "lgt_mapping": "U", "player_colour": "U", "sun_direction": "U",
             "tonemap": "U", "shadows": "A", "camera": "U", "rider_sync": "H", "timing": "H"},
  "notes": {"texture_decode": "raw S3TC upload; on ANGLE D3D11 the GPU's own BC decoder runs (M0: NVIDIA rounding), SwiftShader decodes exactly"}
}
```

`M` = measured, `A` = approximated, `U` = unknown, `H` = labelled hypothesis. Every export caption carries this
block, so a preview is never taken for in-game truth.

## 16. Oracles (reserved)

`oracles.precomp` stays null in v0. A later slice decodes the engine's `.precomp` twins:
- per anim, the animfile's bounding box: min, max, centre and radius, Y up;
- per clip, about 16 engine samples for 24 sim-skeleton bones.

They are stored here and become local tests: posed bounds against the precomp bounds, and bone samples against the
clip samples.

## 17. Versioning

- `schema_version` changes when a field changes meaning or a required field is added.
- Adding an optional field, or filling a reserved one, keeps the version.
- `bundle.js checkManifest` refuses another version, so a stale cache can never be half-read.
- Bump `av_common.SCHEMA_VERSION` and `bundle.js SCHEMA_VERSION` together; a test compares them.

## 18. Optional fields added in M1 and M2 (v0 kept)

None of these changes the meaning of a field above; readers ignore what they do not know.

**Top level** (bundle.py): `content_sha256` (sha256 over every provenance `[layer, path, sha256]`: changes with any
source byte, while `bundle_id` stays stable for the same subject and layers), `build` (`{modules: {<module>: counts
and unavailable ids}, elapsed_s}`), `conventions.display` (the engine frame is drawn with x negated: the gr2 frame is
left-handed, Right -X, Up +Y, Back +Z; unit_gr2 frame A has det -1). `fidelity.viewer` names the viewer stage (`m2`)
whose rendering the stage flags describe; `fidelity.notes` explains each flag.

**Layers and files** (vfs.py): VFile `eol` may be `none` (no line break). Warning codes `mixed-eol-runtime-xml`,
`mods-unavailable`, `game-unavailable`, `mod-folder-missing`, `xml-parse-failed`, `proto-missing`, `not-an-animfile`,
`not-a-tactics-file`, `include-cycle`, `attach-target-undeclared`, `component-undeclared`.

**Models** (gr2_model.py, bundle.py): `layer`, `material_file` (the `.material` beside the gr2, or null with the warning
`material-file-missing`). A bone's `rest` is the transform with its Granny flags applied (bit 1 position, 2
orientation, 4 scale-shear; a clear bit is the identity whatever is stored). Unavailable reasons `gr2-bad-magic`,
`gr2-truncated`, `gr2-parse-failed`; a stream may carry `unavailable_reason: vertex-member-type-<n>`. Warning codes
`gr2-crc-mismatch`, `gr2-basis-differs`, `gr2-multiple-skeletons`, `material-unbound`, `vertex-member-unsupported`.
A mesh without `BoneWeights` is rigid: it follows its first bone binding (the viewer's rule, labelled).

**Clips** (gr2_curves.py): unavailable reasons `clip-no-animation`, `curve-malformed`; warning `clip-extra-track-groups`
(only the first track group of the first animation is read). Identity curves: an empty K32fC32f keeps format
`K32fC32f`, a curve without data has format `none`; both `inferred: true`. A clip with any unsupported curve has
`decodable: false` with its first reason; every decodable curve is still written (the viewer evaluates the others as
the identity and says so). `layer` added.

**Materials and textures** (material.py, ddt.py): slots gain `reference` and `default`; materials gain
`materialdef_path`, `materialdef_provenance`, `unknown_overrides`; slot reasons `override-missing`, `override-empty`.
Textures gain `format_name`, `usage`, `usage_flags`, `alpha`, `alpha_type`, `faces`, `max_level`, `complete_to_1x1`,
`problems`, `face` on cube mips, `uses` (`[{material, slot, srgb}]`); reasons `ddt-header-invalid`,
`ddt-size-mismatch`; warnings `material-override-missing`, `material-unknown-parameter`, `material-empty`,
`texture-unavailable`.

**Animfiles** (animfile.py): records gain `layer`, `audit` (`[{code, ...}]`), `other`, `submodels`, `engine_ignored`,
`unavailable_reason`; inline attachment bodies are records `<animfile id>#<name>` with `parent` and `inline`. Assets
gain `materialvariant`, `attrs`, `missing`; a repeated branch tag is the state `<tag>#<n>`. Attach `resolved` gains
`checks` (`[{side, model, bone, index, name, match}]`) and notes `bone-alias-assumed`, `bone-alias-ambiguous`,
`engine-bone-assumed`, `bones-not-checked`, `attachment-undeclared`. `resolved.tobone` / `frombone` index the FIRST
resolved state's model only; the viewer re-resolves the bone by name in the model it draws (the low-poly rider has
R Hand at 31, not 26).

**Composition**: children gain `scope` (`component`, `branch`, `anim`); an anim-scope child has
`declared_in {animfile, anims}`. `pairing` gains `child`, `durations_known`, `pairs` (`[{anim, main_variant,
child_variant, rule}]`) and `ragdoll`; `pairings` lists every synced child when there are several.

**Proto, tactics, timing**: proto gains `sources` (`[{layer, provenance, rule: base|merge|replace|add}]`) and `notes`;
tactics records gain `layer`, `source_form`, `eol`, `other`, `engine_ignored`; actions and tactics gain `stringid`;
tactic anims include `move`; transitions gain `anim`, `action`, `automatic`, `commandautomatic`, `fields`. Timing rows
gain `rof_protoaction`, `idleanim`, `reloadanim`, `tactics`, `notes`; the top level gains `rules` (H1..H4),
`movement`, `anims_unreferenced`, `anims_missing`.

**Lighting**: lgt `raw`, `derived` (each `{value, target, status, rule}`, status `measured`, `name-match`, `guess`,
`unknown`, `omitted-measured` or `not-ported`), `source_form`, `eol`; refl `mip_count`, `format`, `decodable`,
`unavailable_reason` (`refl-unreadable`), `layout`, `face_order`, `header_floats`, `levels_skipped`, `problems`;
tonemap_lut `white_point`, `enabled`, `encoding`, `order`, `build_input`, `lookup`, `after`, `source`, `status`,
`notes`; grade_lut `title`, `domain_*`, `order`, `lookup`, `status`; player colours `color2`, `color3`, `minimap`,
`rgb_source`; section `player_colors_special`.

**Viewer rules for the M2 rig** (rig.js; labelled in the page): models per animfile come from the components the anim
names and the resolved entry matching the chosen logic state; a child's root is `inverse(child frombone world) @
parent tobone world`, the model origin when the frombone is engine-defined; syncanims=1 children play the same anim
name, the parent's resolved variant i -> child i mod n, in absolute time (holding the last key past their end) or in
normalised phase; an anim the synced child lacks falls back to its `Idle`; syncanims=0 attachments play their own anim
(same name, else `Idle`, else the first) on their own looping clock.

**Viewer rules for the M4 timeline** (viewer/timeline/model.js, footprint.js; viewer/panels/data.js; read-only - the
bundle file is never changed):
- **Tag times.** A tag at fraction f of a clip of duration d sits at clip time f x d. Its main times follow the side's
  clock:
  - main and absolute: f x d (past the main duration D it is never reached while the main loops);
  - phase: f x D;
  - own: f x d + k x d inside [0, D].
- **Overflow and override.** f > 1 goes to the overflow lane. animlengthoverride adds a second length bar and ghost
  tags at f x override.
- **Key grid.** Key k at k / round(1 / timestep), the last key at d. A declared rate more than 0.001 from an integer is
  flagged `non-integer`, a duration that is not a whole number of steps `last key off-grid`.
- **Weights.** `animfile.weights_of` value for value; the roll is one draw over `weights.normalized`.
- **Tactics rate.** For a `timing.actions` row: AnimationRate when declared (H3), times clip duration / `rof_effective`
  when both are known ("H1 ROF fit"); the parts multiply.
- **Footprints.** A footprint dot is the `footprintbone`'s world translation at the tag's first main time, the bone
  matched by the engine name rule in the side's models. A bone the models lack sits at the side's placement origin
  (status `origin-assumed`); a footstep without a footprintbone gets no dot.
- **Fidelity in the page.** `applyTimelineFidelity` adds these stage keys to the in-memory `fidelity.stages` and
  `notes`, only when the bundle lacks them, and names them in `fidelity.viewer_stages` (`m4-timeline`):
  - `key_grid` M;
  - `tag_timing` H;
  - `tag_overflow` U;
  - `variant_choice` H;
  - `tactics_rate` H;
  - `footprint` A.

  bundle.py may adopt the same keys later; a stage the bundle carries always wins. The badge prefers the renderer's
  runtime block (`ren.fidelity()`) when it has one.

**M3 game shader** (lighting.py, bundle.py; viewer/shading/; formulas in [shader-model.md](shader-model.md)):
- **Lighting section.**
  - `shader`: `{version: "v1", entries}`, from `lighting.shader_constants`. Each entry is `{value, target, status,
    rule}`; some add `alternatives.linear_255`. The status words gain `measured-unused`.
  - `envbrdf`: the game's 8x8 split-sum table, `{size, scale[64], bias[64], order, lookup, source, status}`.
  - `presets`: `[{name, title, bundle_id, status, warnings}]`, one per lighting pack. The status is `ok`, `missing` or
    `error: ...`.
- **Refl records.** They gain `dtype` (`f32`, or `f16` in packs) and `level_stats`
  (`[{level, size, mean_rgb, mean_luminance, max, mean_alpha}]`, counted over every level, kept or not).
- **Lighting pack.** A bundle-schema v0 manifest with `subject: {kind: "lighting", proto: null, animfile: null,
  lgt}`. It sits under the cache root like a bundle and is served by the same `/bundle/<id>/` route.
  - It holds one lgt with every reflection-cube level (f16), its LUTs, `shader`, `envbrdf` and the player colours.
  - Its models, materials, textures, clips and animfiles are empty.
  - Its `fidelity` lists the shading stages only.
  - It is rewritten only when its inputs or content hash change.
- **Fidelity.** `fidelity.shader_model` and `tool.shader_model` are `v1`, and `fidelity.viewer` is `m3`. The stages of
  `lighting.SHADING_FIDELITY` are merged over the M2 table: material, normal_map, player_colour, brdf, ibl, envbrdf,
  specular_occlusion, gbuffer, shadows, ssao, lgt_mapping, sun_direction, tonemap, colour_grade, dither, fog,
  antialiasing.
- **Job shading options.** `job.shading` and a frame's `shading` (viewer/shading/hook.js): renderer, lighting, player,
  shadows, quant, tonemap, debug, samples, seed, shadow size / bias / softness, frontFace, overrides.
  - A frame's options apply on top of the job's; they do not carry over to the next frame.
  - Frame records gain `shading` (`GameRenderer.describe()`) and `fidelity` (the runtime block). The done record gains
    `shading_error`.

**M5 exports** (bundle.py; viewer/export/; scripts/sheets.py, video.py, metrics.py; read-only - the bundle file is
never changed by an export):
- **Fidelity.** bundle.py now writes the M4 timeline stages itself (`TIMELINE_STAGES`, the same flags and notes as
  `TIMELINE_FIDELITY`, so `applyTimelineFidelity` adds nothing to a current bundle) and the export stages
  (`EXPORT_STAGES`):
  - `export_frame_times` M: every exported frame is posed at an exact main-clock time (never a real-time capture);
  - `video_encode` A: H.264 yuv420p of the sRGB frames; WebP durations in whole milliseconds;
  - `compare_clock` H: two units start at t = 0 on one clock, each loops its own main clip;
  - `metric_penetration` A and `metric_hoof_height` A: the metrics.py rules below.
  `fidelity.viewer` stays `m3` (it names the rendering stage).
- **Job keys** (viewer/export/job.js, which replaces app.js's M2/M3 runner; M2/M3 frame records are unchanged):
  - `bounds`: `frame` (default; the camera fits each pose) or `clip` (one framing per clip: the union of the posed
    bounds at 24 even times and every tag stop; with two subjects, over both, so both share one camera);
  - `timeline`: the done record carries `timelines` (`"<subject>|<anim>|<variant>|<sync>"` -> `plan.js
    timelineSummary`: D, sides with key grids, tags with `reached` main times);
  - `geometry`: each frame also posts `<png stem>.geom.bin` (below);
  - `other` `{bundle, anim, variant, shading, sync}`: subject b, rendered after subject a at each frame; its files
    carry the suffix `__b`; its main time is the frame's `other.time` when given, else t inside `[0, D_b]`, wrapping
    past `D_b`;
  - frame `times` `[t...]` (+ `other_times`): one frame per time, named `<name>_<index 5 digits>`;
  - frame `at`: `tags` (every distinct reached tag time in `[0, D]` of both subjects; overflow tags and child tags past
    D are reported in the done record's `skipped`), `keys` (the main key grid), `fps=N` (i / N, i = 0 .. floor(D N));
    named `<name>_<label>` (`t0.8100_Attack`, `k156`, `f0003`);
  - camera `mode`: `game` (pitch 47), `close` (pitch 14, aimed at 62 % of the height, fit 0.55: a viewer choice, not
    a game camera), `ortho` `{az, el}` (render_obj's camera on the page's own bounds), `render_obj`.
  - A job longer than `headless.URL_JOB_LIMIT` URL characters reaches the page over `GET /api/job` (`job=@server`).
- **Frame records** gain `subject` (`a` | `b`), `bundle_id`, `framing`, `expand` `{kind, label, key, index}`, `geom`,
  `clock` (subject b) and `cell`: `{anim, variant, clip (main), key, keys_of, time, D, tag (label), tags [{subject,
  type, lane, role, side, fraction, time, clipTime, key, attrs, footstep, footprintbone}], keys [{role, side, clip,
  clock, clip_time, key, of}]}`. The done record gains `skipped`, `other` and `timelines`.
- **Geometry dump** (`*.geom.bin`, geometry.js / metrics.py): magic `AVGEOM1\0`, u32 header length, the header JSON
  `{version 1, t, meta, frame, instances [{index, role, model, animfile, anim, variant, clip, clock, clip_time, bones,
  meshes [{name, vertex_count, triangle_count, arrays {posed f32x3, bind f32x3, indices u32x3, bone i16}}]}]}` padded
  to 4 bytes, then the arrays at 4-byte offsets from the end of the header. `posed` = the viewer's CPU-skinned
  positions (engine frame, the unit on y = 0), `bone` = the largest-weight bone of each vertex (-1: none).
- **Metrics** (metrics.py): penetration = rider (`child`) vertices with |generalised winding number| > 0.5 of the
  horse (`main`) triangles, depth = distance to the nearest of them; hoof height = the lowest posed vertex of each leg
  above y = 0, legs = the lowest 12 % of the bind pose split at the middle of their z and x extents, the forward side
  where head/neck/skull-bound vertices sit and the left side where `*_l` / `L` bones sit (defaults +Z and -X, the Iron
  Flail horse); a footstep's footprintbone tokens (FRNT/FRONT/FORE, BACK/REAR/HIND, LT/LEFT, RT/RIGHT) pick its leg,
  else the tag type's side.
- **Export files** (anim_viewer.py; every folder outside every repository):
  - `render`: `<png>.cell.json` per cell (`cell_record`: png, subject, bundle_id, proto, anim, variant, clip, key,
    keys_of, time, D, tag, tags, keys, camera, framing, expand, lighting, renderer, fidelity {badge, counts,
    calibration, shader_model, viewer, stages, notes}, metrics), `sheet_<anim>.png` + `.json` (title, rows, columns,
    fidelity, notes, cells with their box), `report.json`, `job.json`;
  - `video`: `frames/v_<i>.png`, `<proto>_<anim>_v<n>[_vs_<other>].mp4` / `.webp`, `video.json` (fps, loops, D, frames,
    unique_poses, schedule [{index, t, t_global, loop, t_b, pose, hits}], tag_events, mp4 {cmd, returncode, boxes,
    faststart, probe, ffmpeg_version}, webp, fidelity, other);
  - `compare`: cell sidecars, `compare.png` + `.json` (sheet), `compare.json` (a, b, at, clock, rows [{label, t, a, b:
    {png, time, tag, key, penetration, footsteps, hooves}}], summary per subject, skipped, fidelity, timelines).
