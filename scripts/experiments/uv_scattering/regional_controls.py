"""Session-only review controls. Launch Blender with --python this_file.py."""
import bpy, json, os
from pathlib import Path
from mathutils import Vector

ROOT = Path(bpy.data.filepath).parent
AUDIT = json.loads((ROOT / 'native_audit.json').read_text())
STATE = {'variant': 'Regional', 'scope': 'Tower', 'display': 'VERTEX'}

def apply_view(frame=False):
    sc = bpy.data.scenes['REVIEW_' + STATE['variant']]
    bpy.context.window.scene = sc
    shown = []
    for ob in sc.objects:
        part = ob.get('source_part', '')
        scope = STATE['scope']
        visible = ob.type == 'MESH' and (scope == 'All' or
            scope == 'Tower' and 'Tower_' in part or
            scope == 'Lower' and part.endswith('Tower_LowerEave') or
            scope == 'Upper' and part.endswith('Tower_UpperPaljakRoof'))
        ob.hide_set(not visible)
        ob.select_set(False)
        if visible: shown.append(ob)
    if shown: bpy.context.view_layer.objects.active = shown[0]
    pts = [ob.matrix_world @ Vector(c) for ob in shown for c in ob.bound_box]
    if pts:
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
    for area in bpy.context.screen.areas:
        if area.type != 'VIEW_3D': continue
        space = area.spaces.active
        space.show_region_ui = True
        space.shading.type = 'SOLID'
        space.shading.light = 'FLAT'
        space.shading.color_type = STATE['display']
        space.shading.show_shadows = False
        space.shading.show_specular_highlight = False
        space.overlay.show_floor = False
        space.overlay.show_axis_x = False
        space.overlay.show_axis_y = False
        if frame and pts:
            rv = space.region_3d
            rv.view_perspective = 'ORTHO'
            rv.view_location = (lo + hi) / 2
            rv.view_distance = max(hi - lo) * 1.65
            rv.view_rotation = (-Vector((12,-20,-12))).to_track_quat('-Z','Y')
        area.tag_redraw()

class UVREVIEW_OT_change(bpy.types.Operator):
    bl_idname = 'uvreview.change'
    bl_label = 'Change UV review'
    field: bpy.props.StringProperty()
    value: bpy.props.StringProperty()
    def execute(self, context):
        if context.object and context.object.mode != 'OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')
        STATE[self.field] = self.value
        apply_view(frame=self.field == 'scope')
        return {'FINISHED'}

class UVREVIEW_PT_panel(bpy.types.Panel):
    bl_label = 'Regional roof experiment'
    bl_idname = 'UVREVIEW_PT_panel'
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'UV Review'
    def draw(self, context):
        col = self.layout.column(align=True)
        col.label(text='Compare candidate')
        for value, label in [('Previous','Previous'),('Regional','Regional policy'),('RegionalBroad','Broader search')]:
            op = col.operator('uvreview.change',text=label,depress=STATE['variant']==value)
            op.field='variant';op.value=value
        col.separator();col.label(text='Inspect part')
        for value,label in [('All','Whole building'),('Tower','Tower underside'),('Lower','Lower roof'),('Upper','Upper roof')]:
            op=col.operator('uvreview.change',text=label,depress=STATE['scope']==value)
            op.field='scope';op.value=value
        col.separator()
        row=col.row(align=True)
        for value,label in [('VERTEX','Island colors'),('TEXTURE','Checker')]:
            op=row.operator('uvreview.change',text=label,depress=STATE['display']==value)
            op.field='display';op.value=value
        if STATE['scope'] in ('Lower','Upper'):
            suffix='Tower_LowerEave' if STATE['scope']=='Lower' else 'Tower_UpperPaljakRoof'
            rec=next(r for r in AUDIT[STATE['variant']] if r['part'].endswith(suffix))
            col.label(text=str(rec['native_charts_all_faces'])+' native UV islands (all faces)')
            col.label(text=str(rec['charts_touching_original_visible_faces'])+' touch originally visible faces')
        col.separator();col.label(text='CandidateUV is editable')
        col.label(text='Diagnostic atlas; rebake pending')

for cls in (UVREVIEW_OT_change,UVREVIEW_PT_panel): bpy.utils.register_class(cls)

def ready():
    apply_view(frame=True)
    text=bpy.data.texts.get('REGIONAL_REVIEW_CONTROLS') or bpy.data.texts.new('REGIONAL_REVIEW_CONTROLS')
    text.clear();text.write(Path(__file__).read_text())
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    (ROOT/'live_regional.json').write_text(json.dumps({'pid':os.getpid(),'file':bpy.data.filepath,'scene':bpy.context.scene.name,'state':STATE,'panel_registered':True},indent=2))
    return None

bpy.app.timers.register(ready,first_interval=1.5)
