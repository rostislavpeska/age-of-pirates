"""Execute the real adapter against minimal fake controls; never imports real Qt/Painter."""
from pathlib import Path
from types import ModuleType, SimpleNamespace as NS
import sys
import unittest
from unittest.mock import patch


class Signal:
    def __init__(self, callback):
        self.callback=callback

    def emit(self,*args):
        return self.callback(*args)


class RuntimeAuditTests(unittest.TestCase):
    def setUp(self):
        self.events=[]
        self.app=NS(allWidgets=lambda: [])
        self.callbacks=[]
        self.qt=NS(Qt=NS(DirectConnection=0),
                   QMetaObject=NS(invokeMethod=lambda *args: self.events.append('native.enter_edit')),
                   QTimer=NS(singleShot=lambda delay,fn:self.callbacks.append(fn)))
        self.qtw=NS(QApplication=NS(instance=lambda:self.app), QMenu=type('Menu',(),{}),
                    QLineEdit=type('LineEdit',(),{}), QListView=type('ListView',(),{}))
        self.resource=ModuleType('substance_painter.resource')
        package=ModuleType('substance_painter'); package.resource=self.resource
        self.module_patch=patch.dict(sys.modules,{
            'PySide2':NS(QtCore=self.qt,QtGui=NS(),QtWidgets=self.qtw),
            'shiboken2':NS(), 'substance_painter':package,
            'substance_painter.resource':self.resource})
        self.module_patch.start()
        self.addCleanup(self.module_patch.stop)
        self.g={'_sp_audit_step':lambda stage,phase:self.events.append((stage,phase))}
        self.source=Path(__file__).with_name('legacy_runtime.py').read_text(encoding='utf-8')
        exec(compile(self.source,'legacy_runtime.py','exec'),self.g)
        self.events.clear()

    def raise_native_error(self,*args):
        raise RuntimeError('simulated native failure')

    def fixture_picker(self, fail_click=False, wrong_label=False):
        url='resource://test/Texture'; label_state={'text':'uniform color'}
        model=NS(rowCount=lambda:1,index=lambda row,col:row,data=lambda index:'Texture',
                 mimeData=lambda indexes:NS(urls=lambda:[NS(toString=lambda:url)]))
        def clicked(index):
            self.events.append('native.picker.click')
            if fail_click:self.raise_native_error()
            label_state['text']='Wrong' if wrong_label else 'Texture'
        view=NS(model=lambda:model,setCurrentIndex=lambda index:self.events.append('native.picker.select'),
                clicked=Signal(clicked),window=lambda:NS(close=lambda:None))
        self.g['picker_views']=lambda:[view]
        self.g['widgets']=lambda *args,**kwargs:[NS(text=lambda:label_state['text'])]
        self.resource.ResourceID=NS(from_url=lambda value:value)
        self.resource.Resource=NS(retrieve=lambda rid:[NS(gui_name=lambda:'Texture')])
        self.resource.list_layer_stack_resources=lambda:[NS(url=lambda:url)]
        self.g['activate_widget']=lambda target:self.callbacks.pop(0)()
        return url

    def test_widget_enumeration_before_and_after(self):
        events=[]
        g={'_sp_audit_step':lambda stage,phase:events.append((stage,phase))}
        exec(compile(self.source,'legacy_runtime.py','exec'),g)
        self.assertEqual(events,[('widgets.enumerate','before'),('widgets.enumerate','after')])

    def test_widget_enumeration_failure_has_no_after(self):
        events=[]
        self.app.allWidgets=self.raise_native_error
        with self.assertRaises(RuntimeError):
            exec(compile(self.source,'legacy_runtime.py','exec'),
                 {'_sp_audit_step':lambda stage,phase:events.append((stage,phase))})
        self.assertEqual(events,[('widgets.enumerate','before')])

    def test_picker_open_choose_readback_order(self):
        url=self.fixture_picker()
        result=self.g['bind_resource']('target',url)
        self.assertTrue(result['changed'])
        self.assertEqual(self.events,[('resource_picker.open','before'),
            ('resource_picker.choose','before'),'native.picker.select','native.picker.click',
            ('resource_picker.choose','after'),('resource_picker.open','after'),
            ('resource_picker.readback','before'),('resource_picker.readback','after')])

    def test_picker_callback_failure_leaves_no_choose_or_open_after(self):
        url=self.fixture_picker(fail_click=True)
        with self.assertRaises(RuntimeError):self.g['bind_resource']('target',url)
        self.assertEqual(self.events,[('resource_picker.open','before'),
            ('resource_picker.choose','before'),'native.picker.select','native.picker.click'])

    def test_picker_readback_failure_leaves_no_readback_after(self):
        url=self.fixture_picker(wrong_label=True)
        with self.assertRaises(RuntimeError):self.g['bind_resource']('target',url)
        self.assertEqual(self.events[-2:],[('resource_picker.open','after'),('resource_picker.readback','before')])

    def fixture_rename(self,fail_commit=False):
        state={'name':'Old','edit':'Old'}
        def commit():
            self.events.append('native.rename.commit')
            if fail_commit:self.raise_native_error()
            state['name']=state['edit']
        edit=NS(setText=lambda value:state.update(edit=value),editingFinished=Signal(commit))
        label=NS(property=lambda name:state['name'],findChildren=lambda cls:[edit])
        self.g['labels']=lambda:[label]; self.g['layer']=lambda name:label

    def test_rename_commit_order_and_verified_after(self):
        self.fixture_rename()
        self.g['rename']('Old','New')
        self.assertEqual(self.events,[('rename.enter_edit','before'),'native.enter_edit',
            ('rename.enter_edit','after'),('rename.commit','before'),'native.rename.commit',('rename.commit','after')])

    def test_rename_commit_failure_has_no_after(self):
        self.fixture_rename(fail_commit=True)
        with self.assertRaises(RuntimeError):self.g['rename']('Old','New')
        self.assertEqual(self.events[-2:],[('rename.commit','before'),'native.rename.commit'])

    def fixture_fill(self,fail_click=False):
        state={'created':False}
        def click():
            self.events.append('native.fill.click')
            if fail_click:self.raise_native_error()
            state['created']=True
        self.g['labels']=lambda:[NS(property=lambda name:'Fresh')] if state['created'] else []
        self.g['widgets']=lambda *args,**kwargs:[NS(isEnabled=lambda:True,click=click)]
        self.g['stack']=lambda:None
        self.g['rename']=lambda old,new:self.events.append('native.rename')

    def test_fill_click_and_readback_order(self):
        self.fixture_fill()
        self.g['add_fill']('Base')
        self.assertEqual(self.events,[('fill.add_click','before'),'native.fill.click',
            ('fill.add_click','after'),('fill.readback','before'),('fill.readback','after'),'native.rename'])

    def test_fill_click_failure_has_no_after(self):
        self.fixture_fill(fail_click=True)
        with self.assertRaises(RuntimeError):self.g['add_fill']('Base')
        self.assertEqual(self.events,[('fill.add_click','before'),'native.fill.click'])

    def fixture_channels(self,fail_click=False):
        state={'color':False,'rough':True}
        buttons=[]
        for key in state:
            def click(key=key):
                self.events.append('native.toggle.'+key)
                if fail_click:self.raise_native_error()
                state[key]=not state[key]
            buttons.append(NS(text=lambda key=key:key,isChecked=lambda key=key:state[key],click=click))
        self.g['widgets']=lambda *args,**kwargs:buttons; self.g['material']=lambda:None

    def test_channel_toggle_order(self):
        self.fixture_channels()
        self.assertEqual(self.g['set_channels'](['color']),{'enabled':['color']})
        self.assertEqual(self.events,[('channel.toggle.color','before'),'native.toggle.color',
            ('channel.toggle.color','after'),('channel.toggle.rough','before'),'native.toggle.rough',('channel.toggle.rough','after')])

    def test_channel_failure_has_no_after_or_next_toggle(self):
        self.fixture_channels(fail_click=True)
        with self.assertRaises(RuntimeError):self.g['set_channels'](['color'])
        self.assertEqual(self.events,[('channel.toggle.color','before'),'native.toggle.color'])

    def fixture_mask_menu(self,fail_action=False,fail_select=False):
        state={'hidden':True}
        icon=NS(isHidden=lambda:state['hidden'])
        def trigger():
            self.events.append('native.menu.trigger')
            if fail_action:self.raise_native_error()
            state['hidden']=False
        action=NS(text=lambda:'Add black mask',isEnabled=lambda:True,trigger=trigger)
        button=NS(menu=lambda:NS(actions=lambda:[action]))
        self.g['widgets']=lambda *args,**kwargs:[icon if kwargs.get('name')=='maskIcon' else button]
        self.g['select_layer']=lambda name:None
        self.g['layer_view']=lambda name:None
        self.g['stack']=lambda:None
        def activate(w):
            self.events.append('native.mask.select')
            if fail_select:self.raise_native_error()
        self.g['activate_widget']=activate

    def test_mask_creation_menu_and_selection_order(self):
        self.fixture_mask_menu()
        self.g['ensure_mask']('Base')
        self.assertEqual(self.events,[('mask.create','before'),('menu.action.Add black mask','before'),
            'native.menu.trigger',('menu.action.Add black mask','after'),('mask.create','after'),
            ('mask.select','before'),'native.mask.select',('mask.select','after')])

    def test_menu_action_failure_has_no_menu_or_mask_after(self):
        self.fixture_mask_menu(fail_action=True)
        with self.assertRaises(RuntimeError):self.g['ensure_mask']('Base')
        self.assertEqual(self.events,[('mask.create','before'),('menu.action.Add black mask','before'),'native.menu.trigger'])

    def test_mask_selection_failure_has_no_after(self):
        self.fixture_mask_menu(fail_select=True)
        with self.assertRaises(RuntimeError):self.g['ensure_mask']('Base')
        self.assertEqual(self.events[-2:],[('mask.select','before'),'native.mask.select'])

    def test_generator_quarantine_survives_instrumentation(self):
        for request in [{'op':'ensure_generator'},{'op':'bind_generator'},
                        {'op':'menu_action','button':'addEffect','text':'Add generator'}]:
            with self.subTest(request=request), self.assertRaisesRegex(RuntimeError,'quarantined'):
                self.g['dispatch'](request)
        self.assertEqual(self.events,[])


if __name__=='__main__':
    unittest.main(verbosity=2)
