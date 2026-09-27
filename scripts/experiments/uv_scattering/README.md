# Reproduce the isolated S12 scattering comparison

Read RESEARCH.md for scope, evidence and limitations. This folder is research
code, not an installed Blender add-on or a production unwrap command.

Inputs: frozen S12 blend and the original S9 face metadata, verified through the
Korean-building repository's `tools/assets.py --verify`. Export actual current
world-space polygon corners, custom corner normals, active UVMap, Blender
loop-triangle indices, native vertex indices and persistent source face IDs to
`faces.json`. The archived lab includes that exact exported input.

Python dependencies: NumPy, Shapely 2.x and Pillow; optional xatlas 0.0.11 in
`<output>/deps`. Blender scripts require Blender 5.0.1 or a separately validated
version. Third-party code is not vendored into this repository.

Offline scripts accept an explicit output directory. Blender scripts in this
checkpoint use `%TEMP%/codex-uv-scattering-20260927`; adjust their `out` binding for
a new session. Always use a copy of the frozen model with `--factory-startup
--disable-autoexec`. Never run against another agent's live process.

Sequence:

1. `python experiment.py <output>` — baseline, planar, two unfolding bounds,
   external solver; rejection witnesses and measurements.
2. Blender `--background <lab.blend> --python blender_solver.py` — two native
   solver comparisons on a disposable analytical proxy.
3. `python evaluate_native.py <output>` — inspect native solver coordinates.
4. `python refine_measurements.py <output>` — native vs virtual connectivity,
   corner-normal seam risks, native chart colors.
5. `python protected_candidate.py <output>` — constrained unfolding candidate.
6. `python prepare_sewn.py <output>` derives `Sewn100.json` from Strip100
   coordinates with virtual-chart colors and an explicitly labeled results entry.
   `blender_review.py` implements the actual derived-mesh sewing.
7. Blender `--background <lab.blend> --python blender_review.py` — editable
   candidate scenes, fixed-view colors/checkers and comparison blend.
8. Blender `--background <comparison.blend> --python blender_finish.py` — roof
   cutaways and persistent checker scenes; uses a fresh unsuffixed comparison.
9. Blender `--background <comparison.blend> --python blender_audit.py` — independent
   saved-file readback. Assert plan write error, original UV preservation, source
   geometry/normals, expected native island counts and explicit sewing tolerance.
10. `python gallery.py <output>` — local HTML comparison, exact UV SVGs, montages.
    Copy RESEARCH.md alongside it, review all views, then archive the checkpoint.

Blender may exit zero after a Python exception: require the expected completion
files and inspect the log, not just the process exit status. All Blender RNA
handles must be reacquired after Edit Mode or CustomData attribute allocation.
The comparison is deliberately constructed from the original lab, not by
replaying scene creation into the existing comparison (which would add suffixes).

Run `python -m unittest discover -s scripts/experiments/uv_scattering -p 'test_*.py'`
from the worktree root. Tests do not depend on screenshots or private model files.

Keep generated blend, PNG/JPG, SVG UV sheets and large JSON out of Git and runtime
folders. The actual run is archived in OneDrive under
`Korean Buildings Blender/snapshots/2026-09-27-scattering-lab/`.
Cloud upload completion is not established by local file/hash verification.
