"""Blender helpers that make a scripted pack touch exactly the faces it was given (import inside Blender).

  safe_pack(objs, targets, page_px, ...)  packs only `targets` ({object name: set of polygon indices}) and RAISES if any
      other face's UVs changed. Selecting polygons in object mode and entering edit mode with UV sync in VERTEX select
      mode flushes the selection onto every face whose vertices are all selected, so pack_islands moved faces of other
      pages (hidden shared-atlas faces left their real regions; density looked fine). FACE select mode prevents the
      flush; the before/after snapshot proves it.
      equalize=True (default) runs average_islands_scale on the targets first: the scaled pack keeps RELATIVE island
      sizes, so charts moved from a 2048 to a 1024 otherwise land at half density.
  fresh_world()  evaluates every view layer; parented objects carry stale matrix_world in a freshly loaded file until
      then (review copies placed from them landed tens of metres off, and an outside-visibility render check passed
      because the model was off camera). Call it before reading matrix_world in any background script.
"""
import bpy


def fresh_world():
    for sc in bpy.data.scenes:
        for vl in sc.view_layers:
            vl.update()


def _snap(objs, uv_layer, targets):
    out = {}
    for o in objs:
        me = o.data; ul = (me.uv_layers[uv_layer] if uv_layer else me.uv_layers.active).data; t = targets.get(o.name, set())
        for p in me.polygons:
            if p.index not in t:
                out[(o.name, p.index)] = tuple((round(ul[l].uv.x, 7), round(ul[l].uv.y, 7)) for l in p.loop_indices)
    return out


def safe_pack(objs, targets, page_px, margin_px=4.0, equalize=True, rotate_method='CARDINAL', shape_method='CONCAVE',
              uv_layer=None):
    """pack exactly targets = {obj.name: {polygon index, ...}} of `objs` into 0-1; returns a small report"""
    objs = list(objs)
    ts = bpy.context.scene.tool_settings
    saved = (tuple(ts.mesh_select_mode), ts.use_uv_select_sync)
    if uv_layer:
        for o in objs:
            o.data.uv_layers.active = o.data.uv_layers[uv_layer]
    before = _snap(objs, uv_layer, targets)
    try:
        ts.use_uv_select_sync = True
        ts.mesh_select_mode = (False, False, True)          # FACE mode: no flush onto neighbouring faces
        if bpy.context.object and bpy.context.object.mode != 'OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')
        for o in bpy.context.view_layer.objects:
            o.select_set(o in objs)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='DESELECT'); bpy.ops.object.mode_set(mode='OBJECT')
        n = 0
        for o in objs:
            t = targets.get(o.name, set())
            for p in o.data.polygons:
                p.select = p.index in t; n += p.select
        if not n:
            return {'targets': 0, 'moved_non_targets': 0}
        bpy.ops.object.mode_set(mode='EDIT')
        if equalize:
            bpy.ops.uv.average_islands_scale()
        bpy.ops.uv.pack_islands(udim_source='CLOSEST_UDIM', rotate=True, rotate_method=rotate_method, scale=True,
                                merge_overlap=False, margin_method='FRACTION', margin=margin_px / page_px, pin=False,
                                shape_method=shape_method)
        bpy.ops.object.mode_set(mode='OBJECT')
    finally:
        ts.mesh_select_mode, ts.use_uv_select_sync = saved
    after = _snap(objs, uv_layer, targets)
    moved = [k for k, v in before.items() if after.get(k) != v]
    if moved:
        raise RuntimeError(f'safe_pack: {len(moved)} non-target faces moved, e.g. {moved[:5]}')
    return {'targets': n, 'moved_non_targets': 0}
