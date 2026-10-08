"""Small live UI for prepared review scenes. Run register(config) in Blender.

The project supplies names, paths, provenance and measurements; no UV authoring.
"""
import bpy,json,textwrap
from mathutils import Vector

CONFIG={}
def switch(context,mode=None):
    w=context.window;wm=context.window_manager
    if context.object and context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    mode=mode or wm.uvop_mode;wm.uvop_mode=mode
    w.scene=bpy.data.scenes[CONFIG['scenes'][mode]];sc=w.scene
    page=wm.uvop_page;model=wm.uvop_model
    bpy.ops.object.select_all(action='DESELECT');selected=[]
    for o in sc.objects:
        if o.type!='MESH' or not o.get('functional_page'):continue
        wanted=o['functional_page']==page and (model=='ALL' or o.get('semantic_id','').startswith('korean.house_'+model.lower()+'.'))
        o.hide_set(False)
        if wanted:
            o.select_set(True);o.data.uv_layers.active=o.data.uv_layers[CONFIG['uv_layer']];selected.append(o)
    if not selected:raise ValueError('No selectable meshes in requested model/page scope')
    context.view_layer.objects.active=selected[0]
    for ar in context.screen.areas:
        if ar.type=='IMAGE_EDITOR':
            ar.ui_type='UV';sp=ar.spaces.active;sp.image=bpy.data.images[CONFIG['images'][mode][page]]
            if hasattr(sp,'use_image_pin'):sp.use_image_pin=True
        elif ar.type=='VIEW_3D':
            sp=ar.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=True;sp.show_region_ui=True
            center=0 if model=='ALL' else ('ABC'.index(model)-1)*7
            sp.region_3d.view_location=(center,0,2.0);sp.region_3d.view_distance=22 if model=='ALL' else 10
            sp.region_3d.view_rotation=Vector((.75,1,-.65)).to_track_quat('-Z','Y');sp.region_3d.view_perspective='ORTHO'
    sc.tool_settings.use_uv_select_sync=True;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    for ar in context.screen.areas:
        if ar.type=='IMAGE_EDITOR':
            reg=next(r for r in ar.regions if r.type=='WINDOW')
            with context.temp_override(area=ar,region=reg):bpy.ops.uv.select_all(action='SELECT');bpy.ops.image.view_all(fit_view=True)
    sc['uv_scope']=page;sc['model_scope']=model

class UVOP_OT_view(bpy.types.Operator):
    bl_idname='uvop.view';bl_label='Show review mode';mode:bpy.props.StringProperty()
    def execute(self,context):switch(context,self.mode or None);return {'FINISHED'}

class UVOP_PT_operator(bpy.types.Panel):
    bl_label='UV WORKFLOW | OPERATOR';bl_idname='UVOP_PT_operator';bl_space_type='PROPERTIES';bl_region_type='WINDOW';bl_context='tool';bl_order=-100
    def draw(self,context):
        L=self.layout;wm=context.window_manager
        L.label(text=CONFIG['revision']);L.label(text=CONFIG['phase'],icon='TIME')
        for mode,title in [('DENSITY','1  Texel density'),('MATERIALS','2  Planned materials'),('FAMILIES','3  Conjoined families')]:
            op=L.operator('uvop.view',text=title,depress=wm.uvop_mode==mode);op.mode=mode
        L.prop(wm,'uvop_page',text='UV page');L.prop(wm,'uvop_model',text='Model');L.operator('uvop.view',text='Show page / model').mode=''
        L.separator();L.label(text='Editable map: '+CONFIG['uv_layer']);L.label(text='128 pixels per checker square')
        size=CONFIG['sizes'][wm.uvop_page];L.label(text=f'Working canvas {size[0]} x {size[1]} px');L.label(text='Unpacked worksheet; not runtime size')
        if wm.uvop_mode=='DENSITY':
            L.label(text='Target: 160 px / game unit');L.label(text='Architecture: 159.99 - 160.01');L.label(text='Ceramics: 159.83 - 164.15');L.label(text='Per-triangle verification pending')
        elif wm.uvop_mode=='MATERIALS':
            for k,v in CONFIG['roles'].items():
                L.label(text=k.upper()+': '+v[0].split(';')[0])
            L.label(text='TC / Barracks / Stable recipes');L.label(text='Texture bake and backing cells pending')
        else:
            L.label(text='GRAY: unique, not conjoined');L.label(text='ORANGE: shared ceramic charts');L.label(text='A owns, B / C reuse 3 mesh resources');L.label(text='Architectural conjoin: PENDING',icon='ERROR');L.label(text='AO variants: PENDING')
        o=context.active_object
        if o and o.get('semantic_id'):
            L.separator()
            for line in textwrap.wrap(o['semantic_id'],40):L.label(text=line)
            L.label(text='Physical material: '+o.get('material_role','UNKNOWN'))
        try:
            from pathlib import Path
            d=json.loads(Path(CONFIG['status']).read_text());L.separator();L.label(text=d['state']+' | '+d['updated'])
            for line in textwrap.wrap(d['action'],40):L.label(text=line)
            L.label(text='Failures: '+str(len(d.get('failures',[])))+' | see HOUSE LIVE AUDIT')
        except (OSError,ValueError,KeyError):L.label(text='Live log unavailable',icon='ERROR')

def register(config):
    global CONFIG
    CONFIG=config
    for old in ['UVOP_PT_operator','UVOP_OT_view','HOUSEQA_PT_live','HOUSEQA_PT_views']:
        cls=getattr(bpy.types,old,None)
        if cls:bpy.utils.unregister_class(cls)
    bpy.types.WindowManager.uvop_mode=bpy.props.StringProperty(default='DENSITY')
    bpy.types.WindowManager.uvop_page=bpy.props.EnumProperty(items=[(p,p,'Select only this texture page') for p in config['sizes']],default='ROOFS')
    bpy.types.WindowManager.uvop_model=bpy.props.EnumProperty(items=[(p,p,'Show model '+p) for p in ['ALL','A','B','C']],default='ALL')
    for cls in [UVOP_OT_view,UVOP_PT_operator]:bpy.utils.register_class(cls)
