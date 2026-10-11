# Organic UV tools

Background-Blender and host-Python tools for the organic UV skill. No Blender window opens: the Blender tools run in
`blender -b --factory-startup --python-exit-code 2`. Every output path must be absolute and outside every git work
tree (a scratch folder); the tools refuse anything else with exit code 2. Source `.blend` files are never saved; the
apply step writes a copy.

**Finding Blender.** `uv_eval.py` looks in this order, through the companion skill's
`blender-organic-modeling/scripts/blender_env.py` (one implementation, imported by `uvenv.py`):
1. `--blender-exe EXE`;
2. `--local-config FILE`, the library's local tool-path JSON `{"tools": {"blender": {"path": "..."}}}` (a
   device-local, ignored file);
3. the `BLENDER` environment variable;
4. `blender` on PATH;
5. the standard install folder, newest version first.

The other Blender tools are started directly (`blender -b FILE.blend --factory-startup --python-exit-code 2 --python
TOOL.py -- ARGS`); keep `--python-exit-code 2`, without it a failing import exits 0 and reads as a pass.

| File | Runs in | What it does |
| --- | --- | --- |
| `mesh_dump.py` | Blender | Dumps the meshes the plan works on: positions, polygons, Blender's loop triangles, edges, part labels, ring/slot attributes, weights, the left/right mirror map |
| `seam_plan.py` | host | Applies a declared seam-rule table; island census (disk / disk with declared holes / FAIL) and mirror check |
| `organic_unwrap.py` | Blender | Marks the planned seams and flattens (SLIM by default); dumps raw per-corner UVs; saves nothing |
| `island_priority.py` | host | Island multipliers from a priority table, the bone-region head estimator, the head calibration; `ratio` CLI |
| `organic_layout.py` | host | Mirror-exact unique layout, upright islands, priorities, pair-aware raster packing with a gutter |
| `organic_apply.py` | Blender | Writes the layout as a new UV layer into a copy, removes named placeholder layers, marks seams, proves the geometry unchanged |
| `uv_eval.py` + `uv_eval_blender.py` | host + Blender | The UV cleanness evaluator: metrics.json, data.npz, renders and pictures |
| `uv_draw.py` | host | The evaluator's pictures (layout, stretch, model sheets, summary card) |
| `compare_runs.py` | host | Several evaluator runs side by side: one table picture + JSON |
| `uv_gates.py` | host | A gate profile (the game layer's, or a copy of `profiles/template_unit_body.json` filled from reference units) against evaluator runs |
| `uvlib.py` | any | Pure-numpy metrics (Sander stretch, islands, gaps, overlaps, coverage, orientation, bone regions) |
| `uvenv.py` | any | Output refusal, JSON helpers, Blender discovery via the companion skill |

## The chain

```bash
B="blender -b --factory-startup --python-exit-code 2"
S=.claude/skills/blender-organic-uv/scripts
$B SRC.blend --python $S/mesh_dump.py -- --out SCRATCH/dump.json --objects Body,Weapon,Body_LOW --part-map PARTS.json
python $S/seam_plan.py SCRATCH/dump.json RULES.json --out SCRATCH/seams.json
$B SRC.blend --python $S/organic_unwrap.py -- --seams SCRATCH/seams.json --out SCRATCH/raw.json
python $S/organic_layout.py SCRATCH/dump.json SCRATCH/raw.json LAYOUT.json --out SCRATCH/layout.json
$B SRC.blend --python $S/organic_apply.py -- --layout SCRATCH/layout.json --out SCRATCH/unit_uv.blend \
    --report SCRATCH/apply.json --remove-uv-layer UVMap --seams SCRATCH/seams.json
python $S/uv_eval.py --blend SCRATCH/unit_uv.blend --objects Body,Weapon --occluders Hat --uv-layer UV_ORGANIC \
    --page 1024 --gutter-px 8 --pose-npz SCRATCH/pose.npz --part-map PARTS.json --out SCRATCH/eval/page
python $S/uv_eval.py --blend SCRATCH/unit_uv.blend --objects Body --occluders Hat,Weapon --uv-layer UV_ORGANIC \
    --page 1024 --gutter-px 8 --pose-npz SCRATCH/pose.npz --part-map PARTS.json --out SCRATCH/eval/body
python $S/uv_gates.py --profile GAME_LAYER_PROFILE.json \
    --run page=SCRATCH/eval/page --run body=SCRATCH/eval/body --out SCRATCH/gates.json
python $S/compare_runs.py SCRATCH/compare.png SCRATCH/eval/page REFERENCE_RUN --json SCRATCH/compare.json
```

Run each command from any folder; relative inputs resolve against the current folder, outputs must be absolute (the
host tools make them absolute and refuse git work trees).

## File formats

**Seam rules** (`blender-organic-uv/seam-rules/1`): the full schema is the docstring of `seam_plan.py`
(`python seam_plan.py --help`); [method](../references/method.md) section 2 has a worked garment example. Rule kinds:
`border`, `centre`, `path`, `slot_line`, `ring_loop`, `tube`, `apex`, `edges`; object keys `mirror`, `graph`, `back`,
`up`, `hide`, `allow_holes`, `cone_deg`, `complete`.

**Layout config** (`blender-organic-uv/layout/1`): pages (name, size, gutter, objects), `mirror_objects`, `priority`
(`factors` per part, `face_factors`, `hidden_cap`, `never_visible`), `head_target` (`ratio`, `objects`, `num`, `den`,
`exclude_never_visible`, `bone_regions`), `halo_extra_px`, `search`. Docstring of `organic_layout.py`.

**Pose NPZ** for `uv_eval.py --pose-npz` (written by a game layer's pose simulator): `pose__<object>` arrays of posed
world positions in the mesh's vertex order (model units), optional `occluder_P` (N,3) and `occluder_F` (M,3) for a
mount or prop that hides faces, optional `forward` (3,) = the side heading 0 looks at. `--pose-frame N [--pose-action
NAME]` poses through Blender's own Armature modifiers instead.

**Gate profile** (`blender-organic-uv/gates/1`): `checks` of `{id, label, run, metric, hard, target, evidence}`; a
`run` names the evaluator folder given as `--run NAME=DIR`. [Gates](../references/gates.md).

## Exit codes

| Tool | 0 | 1 | 2 | 3 |
| --- | --- | --- | --- | --- |
| `seam_plan.py` | every island a disk (or declared holes), mirror-invariant | census FAIL (file written) | setup error | - |
| `organic_unwrap.py` | written | the solver left flipped faces (written) | setup error | - |
| `organic_layout.py` | written | a page did not pack or a mirror twin failed (written) | setup error | - |
| `organic_apply.py` | copy saved | - | setup error | geometry changed, nothing saved |
| `uv_eval.py` | metrics and pictures | - | setup error or Blender stage failed | drawing failed |
| `uv_gates.py` | every hard limit passes | a hard limit failed or a metric is missing | setup error | - |

## Tests

```bash
python -B -m pytest .claude/skills/blender-organic-uv/tests -q -p no:cacheprovider
```

`test_uvlib_and_gates.py`, `test_seam_plan.py` and `test_layout_priority.py` are pure Python (numpy, scipy, Pillow)
and run anywhere. `test_blender_pipeline.py` builds `tests/make_fixture_blend.py` in background Blender and checks the
evaluator against analytic answers (10 synthetic cases: isometric, anisotropic, two scales with a 3-texel gap,
cylinder seam visibility with and without an occluder, declared and undeclared mirror stacks, partial overlap, fold,
rotated island), its pictures, the three pose modes, the CONFORMAL refusal and the whole chain on a mirror-exact tube
body; it skips when no Blender is found.

The chain reproduced a full production unwrap exactly on 2026-10-11 (Blender 5.1.2): the same 138 + 51 seam edges as
the hand-written planner it generalises, a bit-identical SLIM unwrap, a layout within 1e-15 UV units, and 0
differences in the 503 numeric evaluator metrics it shares with the original run ([method](../references/method.md),
section 8).
