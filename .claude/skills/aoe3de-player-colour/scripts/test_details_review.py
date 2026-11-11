"""Exercise the real binder with an offline bpy graph double, not a second binder.

Audit: 2026-10-21-codex-sol-import62-03 / INC-580. No Blender/pixel/replay claim.
"""
import importlib.util
import sys
from pathlib import Path
from types import SimpleNamespace as NS

import pytest


class Socket:
    def __init__(self, node, name):
        self.node, self.name, self.links = node, name, []
        self.default_value = 0.0


class Sockets(list):
    def __getitem__(self, key):
        return next(s for s in self if s.name == key) if isinstance(key, str) else super().__getitem__(key)


class Node:
    def __init__(self, tree, kind):
        self.tree, self.name, self.kind, self.bl_idname, self.props = tree, kind, kind, kind, {}
        types = {'NodeGroupInput': 'GROUP_INPUT', 'NodeGroupOutput': 'GROUP_OUTPUT',
                 'ShaderNodeTexImage': 'TEX_IMAGE', 'ShaderNodeGroup': 'GROUP',
                 'ShaderNodeBsdfPrincipled': 'BSDF_PRINCIPLED', 'ShaderNodeMix': 'MIX',
                 'ShaderNodeSeparateColor': 'SEP_COLOR', 'ShaderNodeMath': 'MATH',
                 'ShaderNodeRGB': 'RGB', 'ShaderNodeValue': 'VALUE', 'ShaderNodeUVMap': 'UVMAP'}
        self.type = types[kind]
        specs = {'GROUP_INPUT': ([], ['Base Color', 'Details']), 'GROUP_OUTPUT': (['Color'], []),
                 'TEX_IMAGE': (['Vector'], ['Color', 'Alpha']), 'GROUP': (['Base Color', 'Details'], ['Color']),
                 'BSDF_PRINCIPLED': (['Base Color', 'Normal', 'Roughness', 'Metallic', 'Alpha'], ['BSDF']),
                 'MIX': ([str(i) for i in range(8)], ['0', '1', '2']),
                 'SEP_COLOR': (['Color'], ['Red', 'Green', 'Blue']), 'MATH': (['0', '1'], ['0']),
                 'RGB': ([], ['Color']), 'VALUE': ([], ['Value']), 'UVMAP': ([], ['UV'])}
        ins, outs = specs[self.type]
        self.inputs, self.outputs = Sockets(Socket(self, s) for s in ins), Sockets(Socket(self, s) for s in outs)
        self.image, self.node_tree, self.uv_map = None, None, ''
        self.location = NS(x=0, y=0)
        self.is_active_output = True

    def __setattr__(self, key, value):
        if key == 'location' and isinstance(value, tuple):
            value = NS(x=value[0], y=value[1])
        object.__setattr__(self, key, value)

    def __getitem__(self, key):
        return self.props[key]

    def __setitem__(self, key, value):
        self.props[key] = value

    def get(self, key, default=None):
        return self.props.get(key, default)


class Nodes(list):
    def __init__(self, tree):
        super().__init__(); self.tree = tree

    def new(self, kind):
        n = Node(self.tree, kind); self.append(n); return n

    def get(self, name):
        return next((n for n in self if n.name == name), None)

    def __getitem__(self, key):
        if isinstance(key, str):
            n = self.get(key)
            if n is None:
                raise KeyError(key)
            return n
        return super().__getitem__(key)

    def __contains__(self, item):
        return self.get(item) is not None if isinstance(item, str) else super().__contains__(item)


class Links(list):
    def new(self, source, target):
        for link in list(target.links):
            self.remove(link)
        link = NS(from_socket=source, to_socket=target, from_node=source.node, to_node=target.node)
        self.append(link); source.links.append(link); target.links.append(link)
        return link

    def remove(self, link):
        link.from_socket.links.remove(link); link.to_socket.links.remove(link); super().remove(link)


class Tree(dict):
    def __bool__(self):
        return True

    def __init__(self, name):
        super().__init__(); self.name = name; self.nodes = Nodes(self); self.links = Links()
        self.interface = NS(new_socket=lambda *args, **kwargs: None)


class Groups(dict):
    def new(self, name, kind):
        tree = Tree(name); self[name] = tree; return tree


class Image(dict):
    def __bool__(self):
        return True

    def __init__(self, path, space='sRGB'):
        super().__init__(); self.filepath = str(path); self.name = Path(path).name
        self.colorspace_settings, self.source = NS(name=space), 'FILE'


class Images(list):
    def load(self, path, check_existing=False):
        image = Image(path); self.append(image); return image


@pytest.fixture
def adapter(monkeypatch):
    fake = NS(data=NS(node_groups=Groups(), materials=[], images=Images()), path=NS(abspath=str))
    monkeypatch.setitem(sys.modules, 'bpy', fake)
    spec = importlib.util.spec_from_file_location('details_review_under_test', Path(__file__).with_name('details_review.py'))
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module, fake


def material(fake, path='selected_BaseColor.png', ao=False):
    tree = Tree('material')
    mat = NS(name=path, node_tree=tree)
    fake.data.materials.append(mat)
    base = tree.nodes.new('ShaderNodeTexImage'); base.image = Image(path)
    uv = tree.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UV0'
    tree.links.new(uv.outputs['UV'], base.inputs['Vector'])
    bs = tree.nodes.new('ShaderNodeBsdfPrincipled')
    output = base.outputs['Color']
    if ao:
        mix = tree.nodes.new('ShaderNodeMix'); mix.name = 'AO multiply'
        tree.links.new(output, mix.inputs[6]); output = mix.outputs[2]
    tree.links.new(output, bs.inputs['Base Color'])
    normal = tree.nodes.new('ShaderNodeTexImage')
    tree.links.new(normal.outputs['Color'], bs.inputs['Normal'])
    return mat, bs, output


def evaluate(socket, base, details):
    n = socket.node
    def read(s):
        return evaluate(s.links[0].from_socket, base, details) if s.links else s.default_value
    if n.type == 'GROUP_INPUT':
        return base if socket.name == 'Base Color' else details
    if n.type in ('RGB', 'VALUE'):
        return socket.default_value
    if n.type == 'SEP_COLOR':
        return read(n.inputs['Color'])[['Red', 'Green', 'Blue'].index(socket.name)]
    if n.type == 'MATH':
        assert n.operation == 'MULTIPLY'
        return read(n.inputs[0]) * read(n.inputs[1])
    if n.type == 'MIX':
        a, b, f = read(n.inputs[6]), read(n.inputs[7]), read(n.inputs[0])
        if n.blend_type == 'MULTIPLY':
            return tuple(x * y for x, y in zip(a, b))
        return tuple(x * (1 - f) + y * f for x, y in zip(a, b))
    raise AssertionError(n.type)


def test_actual_group_uses_red_only_even_with_blue_and_green(adapter):
    mod, fake = adapter
    group = mod.tint_group(); assert not mod._group_errors(group)
    go = next(n for n in group.nodes if n.type == 'GROUP_OUTPUT')
    output = go.inputs['Color'].links[0].from_socket
    base = (.8, .6, .4, 1)
    mod.set_player(2)
    expected = tuple(x * y for x, y in zip(base, mod._lin(mod.PLAYER_COLORS[2])))
    assert evaluate(output, base, (1, .5, 1, 1)) == pytest.approx(expected)
    assert evaluate(output, base, (0, 1, 1, 1)) == pytest.approx(base)
    mod.set_strength(0)
    assert evaluate(output, base, (1, 1, 1, 1)) == pytest.approx(base)


def test_missing_declared_map_fails_before_scene_mutation(adapter, tmp_path):
    mod, fake = adapter
    material(fake)
    with pytest.raises(FileNotFoundError):
        mod.install(tmp_path / 'missing.png', 'selected')
    assert not fake.data.images and not fake.data.node_groups


def test_same_name_image_never_repointed_or_recoloured(adapter, tmp_path):
    mod, fake = adapter
    old = Image(tmp_path / 'old' / 'Details.png'); fake.data.images.append(old)
    path = tmp_path / 'Details.png'; path.touch()
    result = mod.details_image(path)
    assert result is not old and old.colorspace_settings.name == 'sRGB'
    assert old.filepath.endswith('old' + str(Path('/') / 'Details.png'))
    assert mod.details_image(path) is result


def test_install_scopes_existing_groups_and_is_idempotent(adapter, tmp_path):
    mod, fake = adapter
    selected, bs, source = material(fake)
    other, other_bs, other_source = material(fake, 'other_BaseColor.png')
    path = tmp_path / 'Details.png'; path.touch()
    mod.install(path, 'other', player=3)
    untouched = tuple(other.node_tree.links); other_image = other.node_tree.nodes['AoP Details'].image
    mod.install(path, 'selected')
    count = len(selected.node_tree.nodes); links = tuple(selected.node_tree.links)
    mod.install(path, 'selected')
    assert len(selected.node_tree.nodes) == count and tuple(selected.node_tree.links) == links
    assert tuple(other.node_tree.links) == untouched and other.node_tree.nodes['AoP Details'].image is other_image
    gn = selected.node_tree.nodes['AoP Player Colour']
    assert gn.inputs['Base Color'].links[0].from_socket is source
    assert bs.inputs['Normal'].links[0].from_node.type == 'TEX_IMAGE'
    assert mod.tint_group().nodes['Player Colour'].outputs[0].default_value == mod._lin(mod.PLAYER_COLORS[3])
    assert mod.selftest() == 'SELFTEST PASS'


def test_ao_chain_selected_and_preserved(adapter, tmp_path):
    mod, fake = adapter
    mat, bs, original = material(fake, ao=True)
    path = tmp_path / 'Details.png'; path.touch()
    mod.install(path, 'selected', uv_map='UV0')
    assert mat.node_tree.nodes['AoP Player Colour'].inputs['Base Color'].links[0].from_socket is original
    assert mat.node_tree.nodes['AO multiply'].inputs[6].links
    details_uv = mat.node_tree.nodes['AoP Details'].inputs['Vector'].links[0].from_socket
    base_uv = original.node.inputs[6].links[0].from_node.inputs['Vector'].links[0].from_socket
    assert details_uv is base_uv


def test_broken_named_graph_fails_before_changing_other_material(adapter, tmp_path):
    mod, fake = adapter
    good, _, _ = material(fake, 'selected_good_BaseColor.png')
    broken, _, _ = material(fake, 'selected_bad_BaseColor.png')
    broken.node_tree.nodes.new('ShaderNodeTexImage').name = 'AoP Details'
    before = tuple(good.node_tree.links)
    path = tmp_path / 'Details.png'; path.touch()
    with pytest.raises(ValueError, match='partial or conflicting'):
        mod.install(path, 'selected')
    assert tuple(good.node_tree.links) == before and not fake.data.images


def test_legacy_group_rejected_unchanged(adapter):
    mod, fake = adapter
    legacy = fake.data.node_groups.new(mod.GROUP, 'ShaderNodeTree')
    with pytest.raises(ValueError, match='Unsupported existing'):
        mod.tint_group()
    assert not legacy.nodes and fake.data.node_groups[mod.GROUP] is legacy


def test_deleted_map_and_disconnected_details_fail_selftest(adapter, tmp_path):
    mod, fake = adapter
    mat, _, _ = material(fake)
    path = tmp_path / 'Details.png'; path.touch()
    mod.install(path, 'selected')
    socket = mat.node_tree.nodes['AoP Player Colour'].inputs['Details']
    mat.node_tree.links.remove(socket.links[0]); path.unlink()
    report = mod.selftest()
    assert 'missing BaseColor or Details' in report and 'file is missing' in report


def test_tampered_formula_is_rejected(adapter):
    mod, fake = adapter
    group = mod.tint_group()
    sep = group.nodes['Details channels']; weight = group.nodes['Details weight']
    group.links.new(sep.outputs['Blue'], weight.inputs[0])
    before = tuple(group.links)
    with pytest.raises(ValueError, match='formula is not'):
        mod.tint_group()
    assert tuple(group.links) == before


def test_conflicting_coordinates_and_empty_selection_fail_without_mutation(adapter, tmp_path):
    mod, fake = adapter
    mat, _, output = material(fake, ao=True)
    path = tmp_path / 'Details.png'; path.touch()
    with pytest.raises(ValueError, match='No material matches'):
        mod.install(path, 'not-present')
    second = mat.node_tree.nodes.new('ShaderNodeTexImage'); second.image = Image('Masks.png')
    mat.node_tree.links.new(second.outputs['Color'], output.node.inputs[7])
    before = tuple(mat.node_tree.links)
    with pytest.raises(ValueError, match='conflicting'):
        mod.install(path, 'selected')
    assert tuple(mat.node_tree.links) == before and not fake.data.images
