"""Accepted Korean comparison adapter; not a universal scene builder."""
import bpy,json,textwrap
from mathutils import Vector

SCENE=''
def scene():return bpy.data.scenes[SCENE]
def select_scope(ctx):
    wm=ctx.window_manager
    if wm.uvreview_mode=='AO' and not (scene().get('ao_production_mapping',False) or scene().get('diagnostic_uv_explicitly_requested',False)):
        raise ValueError('AO reference is display-only. Diagnostic UVs require a specific operator request.')
    if not any(ar.type=='IMAGE_EDITOR' for ar in ctx.screen.areas):
        raise ValueError('Open the UV Editing workspace first; this screen has no UV editor')
    if ctx.object and ctx.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    ctx.window.scene=scene();sc=scene();pages=json.loads(sc['review_pages']);page=wm.uvreview_page;pid=pages.index(page);chosen=[]
    bpy.ops.object.select_all(action='DESELECT')
    for o in sc.objects:
        if o.type!='MESH' or o.get('review_model')!=wm.uvreview_house or o.get('review_mode')!=wm.uvreview_mode:continue
        diagnostic=wm.uvreview_mode=='AO' and not sc.get('ao_production_mapping',False)
        selected=[p.index for p in o.data.polygons] if diagnostic else [p.index for p in o.data.polygons if o.data.attributes['review_page'].data[p.index].value==pid and p.material_index!=0]
        for p in o.data.polygons:p.select=p.index in selected
        if selected:o.select_set(True);chosen.append(o)
    if not chosen:raise ValueError('No faces for that copy and page; select the matching resource page')
    ctx.view_layer.objects.active=chosen[0]
    m=chosen[0].material_slots[next(p.material_index for p in chosen[0].data.polygons if p.select)].material
    image=next(n.image for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
    sc.tool_settings.mesh_select_mode=(False,False,True);sc.tool_settings.use_uv_select_sync=True
    for ar in ctx.screen.areas:
        if ar.type=='IMAGE_EDITOR':
            ar.ui_type='UV';sp=ar.spaces.active;sp.image=image;sp.use_image_pin=True
    bpy.ops.object.mode_set(mode='EDIT')
    for ar in ctx.screen.areas:
        if ar.type=='IMAGE_EDITOR':
            reg=next(r for r in ar.regions if r.type=='WINDOW')
            with ctx.temp_override(area=ar,region=reg):bpy.ops.image.view_all(fit_view=True)

class UVREVIEW_OT_select(bpy.types.Operator):
    bl_idname='uvreview.select';bl_label='Inspect real UVs of this copy'
    def execute(self,context):
        try:select_scope(context)
        except ValueError as e:self.report({'WARNING'},str(e));return {'CANCELLED'}
        return {'FINISHED'}
class UVREVIEW_OT_frame(bpy.types.Operator):
    bl_idname='uvreview.frame';bl_label='Frame comparison';scope:bpy.props.StringProperty(default='ALL')
    def execute(self,ctx):
        if ctx.object and ctx.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
        ctx.window.scene=scene();bpy.ops.object.select_all(action='DESELECT')
        house=ctx.window_manager.uvreview_house
        for ar in ctx.screen.areas:
            if ar.type=='VIEW_3D':
                sp=ar.spaces.active;sp.shading.type='MATERIAL';sp.show_region_ui=False
                sp.region_3d.view_rotation=Vector((0,1,-.75 if self.scope!='UNDER' else .35)).to_track_quat('-Z','Y');sp.region_3d.view_perspective='ORTHO'
                for ob in scene().objects:
                    if ob.type=='MESH' and ob.get('review_model') and (self.scope=='ALL' or ob.get('review_model')==house):ob.select_set(True)
                reg=next(r for r in ar.regions if r.type=='WINDOW')
                with ctx.temp_override(window=ctx.window,area=ar,region=reg):bpy.ops.view3d.view_selected(use_all_regions=False)
                sp.region_3d.view_rotation=Vector((0,1,-.75 if self.scope!='UNDER' else .35)).to_track_quat('-Z','Y')
                sp.region_3d.view_distance*=1.15
                bpy.ops.object.select_all(action='DESELECT')
        return {'FINISHED'}
class UVREVIEW_PT_panel(bpy.types.Panel):
    bl_label='HOUSE UV | SIMULTANEOUS REVIEW';bl_idname='UVREVIEW_PT_panel';bl_space_type='PROPERTIES';bl_region_type='WINDOW';bl_context='scene';bl_parent_id='SCENE_PT_scene'
    def draw(self,ctx):
        L=self.layout;wm=ctx.window_manager;sc=scene()
        L.label(text='LAYOUT ACCEPTED | UV QUALITY WIP',icon='INFO')
        has_ao=sc.get('ao_review_required',False)
        L.label(text='3 Houses x '+('7' if has_ao else '6')+' simultaneous copies')
        for line in ['1 Standard Blender checker','2 Walls only / rest black','3 Roofs only / rest black','4 Generic only / rest black','5 TC pottery only / rest black','6 Conjoined colors; gray = unique']:L.label(text=line)
        if has_ao:L.label(text='7 White AO | '+sc.get('ao_review_kind','PENDING'))
        row=L.row();row.operator('uvreview.frame',text='All '+('21' if has_ao else '18')).scope='ALL';row.operator('uvreview.frame',text='House row').scope='HOUSE';row.operator('uvreview.frame',text='Underside').scope='UNDER'
        L.prop(wm,'uvreview_house',text='House');L.prop(wm,'uvreview_mode',text='Copy');L.prop(wm,'uvreview_page',text='Actual page');L.operator('uvreview.select')
        L.label(text='PRODUCTION UVs | '+('processed AO uses same pages' if sc.get('ao_production_mapping',False) else 'AO reference is display-only'))
        L.label(text='Allowed: 512 / 1024 / 2048 square')
        L.label(text='Profile: AoP > Korean > Houses')
        if sc.get('texture_budget'):
            fit=json.loads(sc['texture_budget'])
            L.label(text='OWNED: 1 walls 2048 + 1 roofs 2048')
            L.label(text='REUSED: Korean generic + TC pottery')
            values=fit.get('owned_density_nominal',{})
            L.label(text='Walls %.1f / roofs %.1f t/u; floor 90' % (values.get('WALLS',0),values.get('ROOFS',0)))
        L.label(text='Subtypes are separate painting IDs')
        box=L.box()
        for line in ['wood planks / beams / red wood','timber ridges / lattice / player wood','stone blocks / solid granite','clay roof fields / clay roof ends','plaster / hanji / onggi pottery']:box.label(text=line)
        L.label(text=sc.get('operator_quality_note','WIP: generic cells / AO / atlas fit'),icon='ERROR')
        stats=json.loads(sc['sharing_statistics']);L.label(text=str(stats['shared_members'])+' shared charts; '+str(stats['owners'])+' owners')
        L.label(text='13 subtypes in labelled atlas regions')
        L.label(text='External resources show actual reused texture')
        L.label(text='Black = excluded resource, not hidden')

def register(scene_name):
    global SCENE
    SCENE=scene_name
    for name in ['UVOP_PT_operator','UVREVIEW_PT_panel','UVREVIEW_OT_select','UVREVIEW_OT_frame']:
        cls=getattr(bpy.types,name,None)
        if cls:bpy.utils.unregister_class(cls)
    sc=scene();pages=json.loads(sc['review_pages'])
    bpy.types.WindowManager.uvreview_house=bpy.props.EnumProperty(items=[(x,'House '+x,'') for x in 'ABC'],default='A')
    modes=['DENSITY','WALLS','ROOFS','GENERIC','POTTERY','FAMILIES']+(['AO'] if sc.get('ao_review_required',False) and (sc.get('ao_production_mapping',False) or sc.get('diagnostic_uv_explicitly_requested',False)) else [])
    bpy.types.WindowManager.uvreview_mode=bpy.props.EnumProperty(items=[(x,x,'') for x in modes],default='DENSITY')
    bpy.types.WindowManager.uvreview_page=bpy.props.EnumProperty(items=[(x,x,'') for x in pages],default=pages[0])
    for cls in [UVREVIEW_OT_select,UVREVIEW_OT_frame,UVREVIEW_PT_panel]:bpy.utils.register_class(cls)
