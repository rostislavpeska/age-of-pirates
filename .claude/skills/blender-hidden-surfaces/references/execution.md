# Data and execution

## Prerequisites

Blender 5.1.2 was tested. Snapshot/rays use Blender's Python with `bpy`, `mathutils`
and NumPy; run expensive rays through an isolated background worker. Offline
images/voxels/graph use Python with NumPy, SciPy and Numba. Do not install software
or open another interactive Blender as a side effect. Image review must use a
working project-approved MCP/API connection; saved background results alone are
not proof of the live scene.

Use a new scratch directory per source revision. Put the skill's `scripts`
directory on Python's import path. Do not put datasets, snapshots, renders or
Numba caches in runtime asset folders. `NUMBA_CACHE_DIR` can point to scratch.
The examples use caller-supplied paths, not machine-specific hardcoded locations.

## 1. Freeze original polygons

In a verified Blender session, import `snapshot_blender` and call:

```python
snapshot_blender.snapshot(
    objects=explicit_mesh_objects,
    output_dir=scratch_directory,
    dataset="building_v1",
    material_map={
        "WOOD": {"physical_material": "wood", "alpha": False},
        "EAVE_CUTOUT": {"physical_material": "tile", "alpha": True},
        # Include every material actually assigned to any input polygon.
    },
)
```

The helper refuses existing snapshot filenames, unmapped materials, Edit Mode,
active viewport modifiers and degenerate analysis triangles. For evaluated meshes,
prepare a separate analysis copy and explicit source correspondence; do not silently
apply modifiers to the authoring source. Its geometry/UV fingerprint includes
positions, polygon connectivity, all UV layers and object transforms. This is not
a complete shader, custom-normal, animation or texture-content hash; record those
separately when relevant. No authoring triangulation or material assignment occurs.

Snapshot files:

- `building_v1_faces.json`: ordered list with IDs `0..N-1`; each has `object`,
  `polygon`, ordered world-space `points`, unit geometric `normal`, world `area`,
  `triangles` (analysis indices), `part`, `alpha`, and `physical_material`.
  Optional `old_material` supports historical comparison data. Do not derive
  physical families from whatever black review material is currently displayed.
- `building_v1_geometry.npz`: float `triangles[T,3,3]`, integer `face_ids[T]`,
  integer `opaque[K]` triangle indices. No evaluated authoring changes.
- `building_v1_snapshot.json`: material contract and geometry/UV fingerprints.

Existing adapters can supply this schema. Original experiment datasets include
assistant proxy labels; the classifier ignores labels. Do not use those labels as
truth when tuning future buildings.

## 2. Measure from the frozen arrays

Copy [baseline-config.json](baseline-config.json) to the consumer's scratch folder
and set documented world scale and camera assumptions. The sample count is fixed
at seven by the tested ray implementation; its helper rejects other counts.
Pairing distance 0.6 and voxel pitches 0.12/0.06 are world units, not universal defaults.

On the already available background Blender worker, after adding the packaged
scripts directory to `sys.path`:

```python
from measure_rays_blender import measure
result = measure(scratch_directory, "building_v1", config_dict)
```

This writes the ordered per-face ray/pairing evidence and progress file. The worker
need not open the source `.blend` because analysis arrays contain all geometry.
Do not call this on the interactive connection during the user's inspection.

Then in standalone Python:

```text
python /path/to/skill/scripts/measure_evidence.py --data-dir /scratch/revision --dataset building_v1 --config /scratch/revision/config.json
python /path/to/skill/scripts/hybrid_visibility.py --data-dir /scratch/revision --dataset building_v1 --config /scratch/revision/config.json --output /scratch/revision/hybrid.json
```

Images and voxel evidence are separate files. Each contains its measurement
configuration; rays retain counts/epsilon/timing. Preserve the full config and
snapshot alongside them. Before reusing cached files, compare source fingerprints
and relevant parameters; equal array length is insufficient. Do not mix revisions.
The voxel helper refuses grids above `voxel_max_cells`; choose asset scale/pitch
deliberately rather than removing the memory limit.

The core accepts an optional `--keep /scratch/overrides.json` where keys are original
face IDs and values are nonempty reasons. It outputs scores, protected/candidate IDs,
graph size, voxel instability and withheld exposure IDs. It does not mutate Blender.
Overrides change the proposed classification, not measurements or ground truth.

## 3. Material-only review handoff

Duplicate scene and mesh datablocks independently. Verify original object/polygon
mapping against the frozen revision, then assign candidate polygons to family-aware
black review materials. Preserve the original physical-family attribute and add a
boolean candidate attribute plus original-face IDs. All other faces retain the
approved solid family palette. A corner-normal or UV change fails this checkpoint.

For the following **hidden-family split**, retain the same candidate mask and use
distinct `HIDDEN_WOOD`, `HIDDEN_STONE`, `HIDDEN_CLAY`, `HIDDEN_PLASTER`, etc.
review materials for the families actually present. Physical family, visibility,
and atlas target are three separate properties. Assigning `target_atlas=H` is only
an allocation intent until a later approved UV step moves coordinates. Multiple
authoring family IDs can share regions of one hidden atlas and may be consolidated
for export later; this does not demand one texture or draw call per authoring color.

Use original material provenance and connected-component evidence to recover
families lost to an older all-black pass. Exact copied faces and components with
unanimous physical-family seeds are stronger evidence than whole-object names.
Retain mixed-component assumptions visibly in the report; roof tile, timber
soffit, ceramic ridge cap and metal fitting backs are different materials. Keep
the black review scene available separately, and change no visibility decisions
merely to make the material palette appear cleaner.

Save a standalone `.blend` containing named alternatives and append them to the
live session through the verified API. `bpy.data.libraries.write` alone creates a
library snapshot; an opened snapshot may start in an empty scene. For a reopenable
review file, select the intended scene in the background worker and use
`bpy.ops.wm.save_as_mainfile` there. Do not replace the user's unsaved live file.

Default to opaque material-color review with overlays and selection available.
For moving the viewpoint through solid walls, keep `space.shading.show_xray=False`,
use `region_3d.view_perspective='PERSP'` and a suitably small positive
`space.clip_start`. Dolly moves the viewpoint beyond ordinary zoom's pivot limit;
verify the active keymap (default Ctrl+Shift+middle-mouse drag). Walk navigation
is another option. X-Ray does not move the viewpoint and must not be enabled merely
because the user wants to zoom inside. For explicit transparent inspection only,
`show_xray=True` with adjustable `xray_alpha` is a reversible option. Record prior
values. X-Ray is not visibility evidence. Preserve the user's current view and mode
while they inspect; do not periodically reframe their scene.

Apply black on matching copies only; no automatic unique-UV reduction follows.
Deliver pictures, actual live scene names and the saved comparison file together.

## Verification

Run `python -m unittest discover -s /path/to/skill/scripts -p test_hybrid_visibility.py`.
These tests cover score polarity, material/normal boundaries, protected surfaces,
input refusal and input preservation. Replaying the frozen nine experiment
datasets verifies extraction fidelity. Neither establishes production acceptance
of hidden-face assignments on a new building.
