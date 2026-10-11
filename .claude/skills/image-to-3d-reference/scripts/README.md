# Image-to-3D reference tools

Background tools for inspecting and measuring a generated model without touching it or any live Blender. Every
command prints its usage with `--help` (no Blender needed for that).

**Blender.** `preview_glb.py`, `render_ortho.py` and `mesh_stats.py` run from host Python and relaunch themselves in
`blender -b --factory-startup` through the companion skill's `blender-organic-modeling/scripts/blender_env.py`.
Blender is found from `--blender-exe EXE`, else `--local-config FILE` (`tools.blender.path`), else `BLENDER`, else
`blender` on PATH, else the standard install folder; a named path that is not a file stops with exit 2. Direct form:

```bash
blender -b --factory-startup --python-exit-code 2 --python scripts/render_ortho.py -- --model MODEL.glb --out-dir DIR
```

**Output.** Only outside every git work tree (refused with exit 2 otherwise). Every output path is made absolute
before Blender sees it: Blender resolves a relative render path such as `renders/x.png` against the drive root
(`C:/renders/x.png` on Windows), not the working directory (found 2026-10-11).

**Models.** `.glb`, `.gltf`, `.obj`, `.fbx`, imported read-only. Exit codes everywhere: 0 = done, 2 = setup error
(missing input, refused path, no Blender, bad arguments) or an unexpected exception.

| File | Runs in | Does |
| --- | --- | --- |
| `scripts/preview_glb.py` | Blender | Solo views and, with `--reference-blend` + `--reference-object`, views beside a reference body scaled to its bounding-box height (a preview scale, not a fit); `PREFIX_stats.json` |
| `scripts/render_ortho.py` | Blender | Model scaled to `--height` (2.0 m), feet on z 0, centred; orthographic front and side on a transparent film; `PREFIX_ortho.json` with the pixel <-> metre mapping |
| `scripts/mesh_stats.py` | Blender | Welds glTF seam splits, then parts, fragments per height band, open and non-manifold edges, texture sizes |
| `scripts/grid.py` | host, Pillow | Grid overlay labelled in source pixels, with crop and zoom, for picking joints |
| `scripts/pose_angles.py` | host, numpy (Pillow for centring and overlays) | Angles from a picks JSON: 2D per limb, 3D arm from front + side picks, errors to a target, overlays |
| `scripts/glb_scene.py` | Blender | Shared Blender-side helpers of the three Blender tools (import, bounds, placement, lights, camera, render); not a command |

## Typical session

```bash
SKILL=.claude/skills/image-to-3d-reference/scripts
W=<work folder outside the repo>
python $SKILL/preview_glb.py --model $W/model.glb --out-dir $W/preview --reference-blend body.blend --reference-object Body
python $SKILL/mesh_stats.py --model $W/model.glb --out $W/model_stats.json
python $SKILL/render_ortho.py --model $W/model.glb --out-dir $W/ortho --prefix model
python $SKILL/grid.py $W/ortho/model_front.png $W/ortho/model_front_grid.png --step 50
python $SKILL/grid.py $W/ortho/model_front.png $W/ortho/elbow_zoom.png --step 10 --crop 650,450,900,650 --zoom 3
# write $W/picks.json (pose_angles.py --help shows the format), then
python $SKILL/pose_angles.py $W/picks.json --out $W/pose.json --overlay-dir $W/overlays
python $SKILL/pose_angles.py $W/picks.json --out $W/pose_centred.json --centre-limbs
```

`render_ortho.py --engine WORKBENCH` is several times faster than the default EEVEE and enough for silhouettes;
EEVEE shows the model's textures lit.

## Picks file (pose_angles.py)

```json
{"target": {"upper_arm_from_down": 26.2, "elbow": 26.5, "leg_spread": 16.4},
 "cases": {
  "model": {
   "front": {"image": "ortho/model_front.png",
             "arms": {"R": [[480, 410], [425, 530], [352, 618]], "L": [[720, 410], [780, 530], [845, 620]]},
             "legs": {"R": [[512, 1057]], "L": [[687, 1057]]},
             "hip_rule": {"height": 0.646, "half_width": 0.0615}},
   "side": {"arm": "L", "points": [[610, 405], [615, 525], [590, 618]]},
   "ortho": "ortho/model_ortho.json"}}}
```

Arm lists are shoulder, elbow, wrist; leg lists hip, (knee,) ankle, or only (knee,) ankle with a `hip_rule`. Paths
are relative to the picks file. `target` and every block but one limb are optional. The example numbers come from a
rider skeleton and a 1200 px render; take the target and the hip fractions from your own skeleton.

## Ported from, left out

Ported on 2026-10-11 from the helpers of the first generated-rider experiments (kept outside every repository):
the preview renderer, the ortho renderer, the welded census, the grid and the pose measurement (its hard-coded cases
became the picks file). Changes: explicit reference object (no name guessing), absolute output paths, scratch-only
output, model sha256 in every report, capped elbow runs are no longer centred (journal
`2026-10-11-claude-i3d-skill-01`), and ankles are picked by eye instead of found from boot silhouette runs at fixed
height fractions. Re-run on the original E3 model: identical mesh counts and an ortho render differing in 4 of
1.44 M pixels.

Not ported: the fit-overlay renderer and its sheet (bounding-box scale and two hard-coded variant names: the method
is superseded by the landmark fit in [fitting](../references/fitting.md)); the bind-pose conform script (it
implements the rejected route of posing the high-poly with transferred weights); the comparison-sheet maker
(hard-coded experiment names and layout); the request sender (it reads the MCP server's private configuration - use
the `generate_3d` tool).
