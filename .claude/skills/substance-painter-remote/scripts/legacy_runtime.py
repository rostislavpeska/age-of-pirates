"""Painter 9.1.2 Qt adapter. Executed inside Painter, never imported by the CLI.

Uses named widgets and their signals; no desktop coordinates or global mouse input.
Internal Qt controls are version-specific, unlike the public project/resource APIs.
"""
from PySide2 import QtCore, QtGui, QtWidgets
import shiboken2


def audit_step(stage, phase):
    # The queue supplies this passive writer. Never inspect/store Qt wrappers here.
    hook = globals().get('_sp_audit_step')
    if hook is not None:
        hook(stage, phase)


audit_step('widgets.enumerate', 'before')
APP = QtWidgets.QApplication.instance()
# Keep wrappers alive for this job: Painter-owned custom QWidget subclasses can
# otherwise be invalidated when a temporary parent wrapper is collected.
ALL_WIDGETS = APP.allWidgets()
audit_step('widgets.enumerate', 'after')


def one(items, description):
    items = list(items)
    if len(items) != 1:
        raise RuntimeError('%s: expected one match, found %s' % (description, len(items)))
    return items[0]


def widgets(root=None, cls=None, name=None):
    values = root.findChildren(QtWidgets.QWidget) if root else ALL_WIDGETS
    found={}
    for w in values:
        if shiboken2.isValid(w) and (cls is None or w.metaObject().className()==cls) and (name is None or w.objectName()==name):
            found[shiboken2.getCppPointer(w)[0]]=w
    return list(found.values())


def stack():
    return one((w for w in widgets(cls='Alg::LayersStackView') if w.isVisible()), 'layer stack')


def labels():
    return [w for w in widgets(stack(), cls='Alg::EditLabel', name='name') if w.parentWidget().objectName()=='layerWidget']


def layer(name):
    return one((w for w in labels() if w.property('text') == name), 'layer '+name)


def rename(old, new):
    if old == new:
        return {'name': new, 'changed': False}
    if any(w.property('text') == new for w in labels()):
        raise RuntimeError('Layer name already exists: '+new)
    w = layer(old)
    audit_step('rename.enter_edit', 'before')
    QtCore.QMetaObject.invokeMethod(w, 'enterEdition', QtCore.Qt.DirectConnection)
    audit_step('rename.enter_edit', 'after')
    edit = one(w.findChildren(QtWidgets.QLineEdit), 'layer name editor')
    audit_step('rename.commit', 'before')
    edit.setText(new)
    edit.editingFinished.emit()
    if w.property('text') != new:
        raise RuntimeError('Rename did not update layer label')
    audit_step('rename.commit', 'after')
    return {'name':new, 'changed':True}


def material():
    return one((w for w in widgets(cls='Alg::MaterialParametersView', name='materialView') if w.isVisible()), 'fill properties')


def activate_widget(w):
    pos=QtCore.QPointF(w.rect().center())
    for kind,buttons in [(QtCore.QEvent.MouseButtonPress,QtCore.Qt.LeftButton),(QtCore.QEvent.MouseButtonRelease,QtCore.Qt.NoButton)]:
        e=QtGui.QMouseEvent(kind,pos,QtCore.Qt.LeftButton,buttons,QtCore.Qt.NoModifier)
        QtWidgets.QApplication.sendEvent(w,e)


def channels():
    rows = []
    for view in widgets(material(), cls='Alg::SourceParametersView'):
        titles = widgets(view, cls='QLabel', name='dropzone_title')
        if not titles: continue
        title = one(titles, 'channel title').text().replace('<b>','').replace('</b>','')
        source = one(widgets(view, cls='Alg::DropZoneWidget', name='source'), 'channel source')
        text = one(widgets(source, cls='QLabel', name='dropzone_text'), 'channel source label').text()
        rows.append({'title':title, 'text':text, 'view':view, 'source':source})
    return rows


def inspect():
    import substance_painter.resource as resources
    mats=[w for w in widgets(cls='Alg::MaterialParametersView',name='materialView') if w.isVisible()]
    return {'layers':[w.property('text') for w in labels()],
            'channels':[{k:v for k,v in r.items() if k not in ('view','source')} for r in channels()] if mats else [],
            'referenced_resources':[r.url() for r in resources.list_layer_stack_resources()]}


def bind_texture(channel, url):
    row=one((r for r in channels() if r['title']==channel),'channel '+channel)
    return bind_resource(row['source'],url)


def bind_resource(target,url):
    import substance_painter.resource as resources
    import time
    if not url.startswith('resource://'):
        raise ValueError('A Painter resource URL is required')
    rid=resources.ResourceID.from_url(url)
    resource=one(resources.Resource.retrieve(rid),'resource URL')
    display=resource.gui_name()
    label=one(widgets(target,cls='QLabel',name='dropzone_text'),'resource label')
    before=label.text()
    if before==display and url in [r.url() for r in resources.list_layer_stack_resources()]:
        return {'after':before,'changed':False}
    if any(isinstance(w,QtWidgets.QMenu) and w.isVisible() for w in APP.allWidgets()):
        raise RuntimeError('Close the existing popup before assigning a resource')
    outcome={}
    deadline=time.monotonic()+8
    def finish():
        views=picker_views()
        if not views and time.monotonic()<deadline:
            QtCore.QTimer.singleShot(100,finish); return
        try:
            outcome.update(choose_picker(display,expected_url=url))
        except Exception as exc:
            outcome['error']=str(exc)
            for v in views: v.window().close()
    QtCore.QTimer.singleShot(100,finish)
    # The picker has a nested Qt event loop. Queue its completion BEFORE opening it.
    audit_step('resource_picker.open', 'before')
    activate_widget(target)
    if outcome.get('error'):raise RuntimeError(outcome['error'])
    if not outcome:raise RuntimeError('Resource picker did not complete')
    audit_step('resource_picker.open', 'after')
    audit_step('resource_picker.readback', 'before')
    after=label.text()
    if after!=display:raise RuntimeError('Resource label readback differs: '+after)
    if url not in [r.url() for r in resources.list_layer_stack_resources()]:
        raise RuntimeError('Resource missing from public layer-stack resource readback')
    audit_step('resource_picker.readback', 'after')
    return {'before':before,'after':after,'changed':True}


def picker_views():
    return [w for w in APP.allWidgets() if isinstance(w,QtWidgets.QListView) and w.isVisible() and isinstance(w.window(),QtWidgets.QMenu)]


def choose_picker(name,expected_url=None):
    audit_step('resource_picker.choose', 'before')
    views=picker_views()
    view=one(views,'resource picker')
    model=view.model()
    index=one((model.index(i,0) for i in range(model.rowCount()) if model.data(model.index(i,0))==name),'resource '+name)
    if expected_url:
        mime=model.mimeData([index])
        if not mime or [u.toString() for u in mime.urls()] != [expected_url]:
            raise RuntimeError('Picker resource URL differs from requested URL')
    view.setCurrentIndex(index)
    view.clicked.emit(index)
    audit_step('resource_picker.choose', 'after')
    return {'resource':name}


def select_layer(name):
    w=layer(name)
    audit_step('layer.select', 'before')
    activate_widget(one(widgets(w.parentWidget(),cls='QToolButton',name='contentIcon'),'layer content icon'))
    audit_step('layer.select', 'after')
    return {'selected':name}


def layer_view(name):
    w=layer(name)
    while w and w.metaObject().className()!='Alg::LayerView':w=w.parentWidget()
    if w is None:raise RuntimeError('Layer container missing')
    return w


def ensure_mask(name):
    select_layer(name)
    icon=one(widgets(layer_view(name),cls='QToolButton',name='maskIcon'),'mask icon')
    exists=not icon.isHidden()
    if not exists:
        audit_step('mask.create', 'before')
        menu_action('addMask','Add black mask')
        audit_step('mask.create', 'after')
    audit_step('mask.select', 'before')
    activate_widget(icon)
    if icon.isHidden():raise RuntimeError('Mask was not created')
    audit_step('mask.select', 'after')
    return {'mask':name,'created':not exists}


def ensure_generator(name,url):
    import substance_painter.resource as resources
    res=one(resources.Resource.retrieve(resources.ResourceID.from_url(url)),'generator resource')
    display=res.gui_name()
    ensure_mask(name)
    views=widgets(layer_view(name),cls='Alg::ActionView')
    matches=[w for w in views if any(c.property('text')==display for c in widgets(w,cls='Alg::EditLabel',name='name'))]
    if matches:
        activate_widget(one(matches,'generator effect'))
    else:
        if any(any(c.property('text')=='Generator' for c in widgets(w,cls='Alg::EditLabel',name='name')) for w in views):
            raise RuntimeError('An unconfigured generator exists; inspect before retrying')
        menu_action('addEffect','Add generator')
        ALL_WIDGETS.extend(APP.allWidgets())
    root=one((w for w in widgets(cls='Alg::GeneratorView') if w.isVisible()),'generator properties')
    result=bind_resource(one(widgets(root,cls='Alg::DropZoneWidget',name='generator'),'generator source'),url)
    return dict(result,generator=display,created=not bool(matches))


def set_numeric(edit,value):
    value=float(value)
    before=edit.text()
    edit.setText(str(value))
    edit.editingFinished.emit()
    if abs(float(edit.text())-value)>1e-5:raise RuntimeError('Numeric readback differs')
    return {'before':before,'after':edit.text()}


def set_generator_parameter(name,value):
    root=one((w for w in widgets(cls='Alg::GeneratorView') if w.isVisible()),'generator properties')
    slider=one(widgets(root,cls='Alg::Slider',name=name),'generator parameter '+name)
    return set_numeric(one(widgets(slider,cls='Alg::CustomLineEdit',name='value'),'parameter value'),value)


def set_opacity(name,value):
    if not 0<=float(value)<=100:raise ValueError('Opacity must be 0..100')
    root=layer(name).parentWidget()
    menu=one(widgets(root,cls='QMenu',name='opacityMenu'),'layer opacity menu')
    result=set_numeric(one(widgets(menu,cls='Alg::CustomLineEdit',name='value'),'opacity field'),value)
    button=one(widgets(root,cls='QToolButton',name='opacity'),'opacity button')
    if abs(float(button.text())-float(value))>1e-5:raise RuntimeError('Layer opacity did not update')
    return result


def add_fill(name):
    if any(w.property('text')==name for w in labels()):
        select_layer(name)
        return {'name':name,'created':False}
    before=[w.property('text') for w in labels()]
    button=one(widgets(stack(),cls='QToolButton',name='addFillLayer'),'add fill button')
    if not button.isEnabled():raise RuntimeError('Add fill layer is disabled')
    audit_step('fill.add_click', 'before')
    button.click()
    audit_step('fill.add_click', 'after')
    audit_step('fill.readback', 'before')
    ALL_WIDGETS.extend(APP.allWidgets())
    fresh=[w for w in labels() if w.property('text') not in before]
    w=one(fresh,'new fill layer')
    audit_step('fill.readback', 'after')
    rename(w.property('text'),name)
    return {'name':name,'created':True}


def set_channels(enabled):
    buttons=widgets(material(),cls='QToolButton',name='channelSelector')
    known={b.text():b for b in buttons}
    if not set(enabled).issubset(known):raise ValueError('Unknown channel toggle')
    for key,b in known.items():
        wanted=key in enabled
        if b.isChecked()!=wanted:
            audit_step('channel.toggle.'+key, 'before')
            b.click()
            audit_step('channel.toggle.'+key, 'after')
    return {'enabled':[key for key,b in known.items() if b.isChecked()]}


def menu_action(button_name,text):
    allowed={'addMask':['Add black mask','Add white mask'], 'addEffect':['Add generator','Add fill','Add filter','Add levels']}
    if text not in allowed.get(button_name,[]):raise ValueError('Unsupported menu action')
    b=one(widgets(stack(),cls='QToolButton',name=button_name),'layer action menu')
    action=one((a for a in b.menu().actions() if a.text()==text),'action '+text)
    if not action.isEnabled():raise RuntimeError('Action is disabled: '+text)
    audit_step('menu.action.'+text, 'before')
    action.trigger()
    audit_step('menu.action.'+text, 'after')
    return {'action':text}


def dispatch(request):
    op=request['op']
    if op in ('set_generator_parameter','set_opacity','open_resource_picker','choose_picker','ensure_generator','bind_generator') or (op=='menu_action' and request.get('text')=='Add generator'):
        raise RuntimeError('Command quarantined: modal/numeric adapter requires isolated validation; do not retry on the working project')
    if op=='inspect': return inspect()
    if op=='show_window':
        main=one(widgets(cls='Alg::S4MainWindow'),'Painter main window')
        main.showNormal()
        main.raise_()
        main.activateWindow()
        return {'title':main.windowTitle(),'visible':main.isVisible()}
    if op=='rename': return rename(request['old'],request['name'])
    if op=='bind_texture': return bind_texture(request['channel'],request['url'])
    if op=='bind_generator':
        root=one((w for w in widgets(cls='Alg::GeneratorView') if w.isVisible()),'generator properties')
        return bind_resource(one(widgets(root,cls='Alg::DropZoneWidget',name='generator'),'generator source'),request['url'])
    if op=='ensure_fill':return add_fill(request['name'])
    if op=='select_layer':return select_layer(request['name'])
    if op=='set_channels':return set_channels(request['enabled'])
    if op=='ensure_mask':return ensure_mask(request['name'])
    if op=='ensure_generator':return ensure_generator(request['name'],request['url'])
    if op=='set_generator_parameter':return set_generator_parameter(request['name'],request['value'])
    if op=='set_opacity':return set_opacity(request['name'],request['value'])
    if op=='menu_action':return menu_action(request['button'],request['text'])
    if op=='choose_picker': return choose_picker(request['name'])
    if op=='open_resource_picker':
        row=one((r for r in channels() if r['title']==request['channel']), 'channel')
        activate_widget(row['source'])
        return {'channel':request['channel']}
    raise ValueError('Unsupported operation: '+op)
