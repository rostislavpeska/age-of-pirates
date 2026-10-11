# Organic modeling tools

Background-Blender tools for the organic modeling skill. Run every command from the folder that holds the files
you pass in. The host Python finds Blender and relaunches the script in `blender -b --factory-startup`, so no
Blender window opens.

**Finding Blender.** The host form of `organic_audit.py`, `organic_probe.py` and `tangent_compare.py` looks in this
order:
1. `--blender-exe EXE` on the command line;
2. `--local-config FILE`: the library's local tool-path JSON, `{"tools": {"blender": {"path": "..."}}}` (the file the
   skill-library audit reads with its own `--local-config`);
3. the `BLENDER` environment variable;
4. `blender` on PATH;
5. the standard install folder, newest version first (`Program Files/Blender Foundation/Blender <version>` on
   Windows, `/Applications/Blender.app` on macOS).

A path named by 1-3 that is not a file stops the tool with `MISSING Blender` (exit 2); it never falls back to a
later source. An unreadable local config is a setup error. `python scripts/blender_env.py [--blender-exe EXE]
[--local-config FILE]` prints the executable it found. The tests read only 3-5: set `BLENDER` when Blender is named
only in a local config.

**Direct form.** Each Blender tool also runs inside Blender directly (`fixture_bodies.py` runs only this way):

```bash
blender -b --factory-startup --python-exit-code 2 --python scripts/organic_audit.py -- --blend FILE.blend ...
```

Keep `--python-exit-code 2`. Without it, an exception that escapes a tool exits 0, which reads as a pass. The tools
catch their own errors and exit 2 either way; the flag covers the rest, such as a failing import.

**Where output goes.** Output goes only to a scratch folder. A report, probe folder or reference inside any git
work tree is refused with exit code 2. When no path is given, each tool makes a new folder in the system temp
directory.

| File | Runs in | What it does |
| --- | --- | --- |
| `scripts/organic_audit.py` | Blender | Checks a skinned mesh, normally the export copy, against its contract: counts, weights, bones, donor skeleton, symmetry and 8-bit weights. Writes a JSON report and sets the exit code. |
| `scripts/organic_probe.py` | Blender | Reruns the synthetic Blender experiments behind the measured claims L1-L16 in [sources](../references/sources.md). |
| `scripts/tangent_compare.py` | Blender | Compares the tangents stored in a game vertex buffer with Blender's MikkTSpace tangents. |
| `scripts/fixture_bodies.py` | Blender | Builds the synthetic test bodies for the audit tests: one clean body and one file per seeded defect. |
| `scripts/organic_weights.py` | any Python | Shared helpers, no bpy: 8-bit quantization, left/right name pairing, name lists. |
| `scripts/blender_env.py` | any Python | Finds Blender, refuses output inside a git work tree, builds the background command line. |

## organic_audit.py

```bash
# once, on the freshly imported donor skeleton, before any edit
python scripts/organic_audit.py --blend donor.blend --write-reference SCRATCH/donor_ref.json

# every export copy (replace the capitals with the contract's numbers)
python scripts/organic_audit.py --blend asset_export.blend --armature rig --mesh body --mesh weapon \
    --max-tris CEILING --target-tris TARGET --max-verts VERTEX_CEILING --cap 4 --max-mean-influences MEAN \
    --allowed-bones @allowed.txt --mesh-bones body=@body_bones.txt --mesh-bones weapon=@weapon_bones.txt \
    --reference SCRATCH/donor_ref.json --symmetry body --report SCRATCH/audit.json

# the working file during weighting: quads, live modifiers and REF_ objects allowed
python scripts/organic_audit.py --blend asset_work.blend --stage working --allowed-bones @allowed.txt
```

**Arguments:**
- **Meshes.** Without `--mesh`, the audit takes every mesh bound to the armature whose name does not start with
  `--ref-prefix` (default `REF_`). `--collection` narrows the search to one collection, including the `REF_` check.
- **Allowed bones.** `--allowed-bones` takes `A,B,C` or `@file`. The file is either text (one exact name per line,
  `#` starts a comment) or JSON (a list, or `{"bones": [...]}`). Without it, `allowed_bones` and `deform_flags`
  report SKIP.
- **Per-mesh bones.** `--mesh-bones MESH=BONES` (repeatable, `A,B` or `@file`) gives one mesh its own list, a
  subset of `--allowed-bones`: a body and a skinned weapon on one armature each carry only their own bones.
  `allowed_bones` checks each mesh against its list; `deform_flags` still checks against `--allowed-bones`, the
  union. A list outside the union, a list without `--allowed-bones`, or a mesh that is not audited is a setup
  error.
- **Symmetry.** `--symmetry MESH` (repeatable, `*` for all) names the meshes that must carry mirrored weights. Leave
  out asymmetric parts, such as a weapon held in one hand.
- **Units.** Distances are in armature-space units: the armature's local frame, before its object scale.

**Exit codes:**
- 0: no FAIL;
- 1: at least one FAIL;
- 2: setup error, or the audit could not run. Causes: an object is missing; an argument is bad; a `--reference`,
  `--allowed-bones`, `--mesh-bones` or `--quantized-json` file is missing or malformed; the `.blend` cannot be
  opened; the path is refused; Blender is missing; an unexpected exception (its traceback is printed). Exit 2 prints
  `SETUP ERROR: ...` and writes no report.

**Report contents.** The report names the Blender version, the input file and its SHA-256, the stage, the meshes,
every threshold with its unit, the per-mesh counts and one row per check: `id`, `status`, `value`, `limit` and
`detail`.

| Check id | FAIL when | Notes |
| --- | --- | --- |
| `ngons` | a face has more than 4 corners | WARN at the working stage |
| `triangulated` | the export copy has quads | INFO at the working stage |
| `triangle_budget` | the triangle count (loop triangles, all audited meshes) is above `--max-tris` | WARN above `--target-tris` |
| `vertex_budget` | the Blender vertex count is above `--max-verts` | GPU-vertex estimate in `detail`: distinct vertex, UV, split normal, material and UV-winding keys |
| `modifiers` | the export copy has a modifier other than the armature binding | INFO at the working stage |
| `armature_binding` | a mesh does not have exactly one Armature modifier on the audited armature | |
| `transforms_match` | (WARN only) the mesh and armature object matrices differ | |
| `preserve_volume` | Preserve Volume is on | the linear-blend preview is the one that counts |
| `unweighted` | a vertex has no bone weight | |
| `influence_cap` | a vertex has more nonzero bone influences than `--cap` | histogram in `detail` |
| `influence_mean` | the mean influences per vertex is above `--max-mean-influences` | INFO without the option |
| `weight_sums` | \|sum - 1\| is above `--sum-tol` (default 1e-6) | |
| `clean_limit` | a bone weight lies in (0, `--clean-limit`) (default 0.02) | zero-weight memberships counted in `detail` |
| `allowed_bones` | a weighted bone group is not in the allowed list (exact strings), or a mesh named by `--mesh-bones` carries a bone outside its own list | `detail.outside_mesh_lists` names the mesh and bones |
| `group_hygiene` | a vertex group is not a bone, or carries no weight | WARN at the working stage |
| `side_suffix` | a group name ends in `.L`/`.R` and is not a bone (a temporary mirror rename left behind) | |
| `deform_flags` | the Deform flag is on for a bone outside the allowed list | automatic weights follow this flag |
| `nondeform_weights` | a weight sits on a bone whose Deform flag is off | Blender ignores it; an exporter may not |
| `ref_objects` | the export file holds an object named with `--ref-prefix` | INFO at the working stage |
| `donor_match` | a bone name, parent, head, tail or rest matrix, or the armature object matrix, differs from `--reference` by more than `--donor-tol` (1e-5) | a changed bone order is a WARN |
| `mirror_names` | never; WARN when `bpy.utils.flip_name` gives a partner other than the explicit one, or a partner bone is missing | INFO lists the names `flip_name` leaves unchanged: Blender's mirror tools pair nothing there |
| `weight_symmetry` | a mirrored vertex pair (within `--mirror-tol`, default 1e-4) differs by more than `--symmetry-weight-tol` (1/255); the mesh has no pair at all; or a vertex has no mirror partner, whose weights therefore cannot be compared (`--symmetry-unpaired warn` makes that a WARN) | left/right bones paired by side token anywhere in the name; `detail` counts the unpaired vertices and lists the first 20 indices |
| `quantized_255` | the 8-bit quantization of a vertex does not sum to 255, leaves a used slot at 0, is not descending or holds a bone twice | `--quantized-json` checks weights read back from a game file the same way |

**Quantization recipe** (`organic_weights.quantize`):
1. Drop influences below 0.5/255 and renormalize.
2. Take `floor(255 w)`, then hand the remaining units, one at a time, to the largest fractional parts.
3. A kept influence that ended at 0 takes one unit from the largest entry.

The error per influence stays below 1/255 whenever every kept influence is at least 1/255. The clean limit (0.02,
about 5/255) always ensures that, so step 3 never acts on a cleaned mesh. Step 3 acts only on a kept influence below
1/255. Each unit it moves adds up to 1/255 to the donor entry's error, so with 4 influences that error can approach
2/255. Example: 255 w = 117.555, 0.536, 136.384, 0.525 quantizes to 118, 1, 135, 1, an error of 1.384/255 on the
third entry. The alternative, giving every influence 1 unit before the share, costs the largest weight up to about
(n - 1)/255. It was measured at 3/255 on the 4-influence test body.

**Quantized JSON format.** `{"vertices": [[["bone", q], ...], ...]}`, or `{"meshes": {"name": [...]}}`. The q
values are integers.

## organic_probe.py

```bash
python scripts/organic_probe.py --list
python scripts/organic_probe.py --out SCRATCH/probe              # every experiment, about 10 s
python scripts/organic_probe.py --only flip_name,rings,shrinkwrap
```

The probe writes `OUT/probe.json`, plus the `.blend` files and silhouette PNGs it saves, into the scratch folder.
`probe.json` holds one key per experiment result and `_lkeys`, which maps each sources key to the result keys that
reproduce it. When an experiment needs a file that an earlier experiment saves, that experiment is added
automatically. Exit 0 means every experiment ran; 1 means at least one experiment raised (its traceback is under
`errors` in `probe.json`); 2 means a setup error or a crash outside the experiments.

| Experiment | Reproduces | Result keys |
| --- | --- | --- |
| `flip_name` | L1 | `L1_flip_name` |
| `operator_defaults` | L8 | `L8_operator_defaults` |
| `bone_deform_enum` | L16 | `bone_deform_enum`: `group_select_mode='BONE_DEFORM'` raises TypeError until the mesh is bound to an armature (Armature modifier or parenting with empty groups); the hygiene chain then finishes |
| `skin` | L2, L9 | `A_skin_*`, `B_skin_armature_*`, `C_autoweights_*`, `C_joint_rings_*`, `D_pose_*` |
| `autoweight_pitfalls` | L2 | `C2_autoweight_pitfalls` (scale 1, 0.008, applied x100, loose part) |
| `shell_transfer` | L3, L4 | `E_shell_transfer` |
| `remesh_decimate` | L6, L7 | `F_quadriflow_*`, `G_decimate` |
| `vertex_split` | L5 | `H_vertex_split` |
| `curves` | - | `I_curves` (strap and rope cross-section counts) |
| `silhouette` | L10 | `J_silhouette` |
| `proportional` | L13 | `K_proportional_translate` |
| `rings` | L2, L11, L15 | `D2_fixed_skeleton_rings` |
| `shell_poke` | L4 | `E2_shell_poke` |
| `unnormalized` | L2 | `L_unnormalized_weight_preview` (weight 0.5 against a weight 1.0 control) |
| `skin_edge_rings` | - | `P3_skin_edge_rings` (rings the Skin modifier adds along an edge) |
| `shrinkwrap` | L12, L14 | `P4_shrinkwrap` |

**Validation.** On Blender 5.1.2 (2026-10-11) the port reproduced the original research outputs exactly, all 26
result keys, timings and file paths aside. `scripts/test_organic_probe.py` asserts the qualitative claims on every
Blender version and the exact numbers on 5.1.

## tangent_compare.py

```bash
python scripts/tangent_compare.py --input SCRATCH/meshes.json --out SCRATCH/tangents.json
python scripts/tangent_compare.py --make-synthetic SCRATCH/sphere.json    # self-test input
```

**Input.** The project's own game-file reader writes the input; this package does not ship one. The format is
`[{"file", "meshes": [{"name", "P", "N", "T", "UV", "I"}]}]`:
- `P`, `N`, `T` and `UV` hold one entry per vertex of the game buffer, at any scale (int8 or float).
- The sign of T's w component is the bitangent sign.
- `I` is the triangle list.

A missing or malformed input exits 2 with `SETUP ERROR` and writes nothing. Malformed means: not JSON, P/N/T/UV of
different lengths, T without its w component, or an index out of range.

**What it compares.** For each mesh and each UV convention (`v` and `1-v`), the tool:
1. sets the stored normals as custom normals;
2. computes MikkTSpace tangents;
3. reports, per corner, the median and 5th percentile of the tangent dot product, the shares above 0.95 and below
   -0.95, and the bitangent-sign agreement.

A median near 1 with sign agreement near 1 in one convention means that a normal map baked with MikkTSpace in
Blender shades in the game as baked.

The port reproduced the original research comparison exactly (8 meshes).

## Tests

```bash
python -B -m pytest .claude/skills/blender-organic-modeling/scripts -q -p no:cacheprovider
```

- **Pure tests.** `scripts/test_organic_weights.py` and the planning tests in `scripts/test_organic_probe.py` run
  on any Python.
- **Blender tests.** `scripts/test_organic_audit.py`, `scripts/test_organic_probe.py` and
  `scripts/test_tangent_compare.py` build synthetic bodies in background Blender, and skip when Blender is not
  found. The audit tests build 19 fixtures with `scripts/fixture_bodies.py` and run 43 audits in parallel. Each
  seeded defect must fail exactly its own check or checks; the clean body must fail none.
- **Setup errors.** Nine missing, malformed or inconsistent inputs must each exit 2 with `SETUP ERROR` and no report. A missing
  `--reference` must do so in all three forms: host, direct, and direct without `--python-exit-code`. A seeded crash
  in the audit or the probe must exit 2 with its traceback. The host form must find Blender from `--blender-exe` and
  from `--local-config`, ahead of a wrong `BLENDER`.
- **Duration.** The whole suite (121 tests) takes about 45 s with Blender. Every file goes to pytest's temp folder.
