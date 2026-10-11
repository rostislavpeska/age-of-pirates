"""Refresh every view layer before reading matrix_world (files saved by some pipelines store stale object matrices).
Use this as the prelude for scripts that SAVE the file; never precede a save with a prelude that moves data (for
example a bake-alignment script that shifts HIGH sources) - the moved transforms would be written to the output."""
import bpy

for sc in bpy.data.scenes:
    for vl in sc.view_layers:
        vl.update()
