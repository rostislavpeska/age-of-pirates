"""INC580; audit 2026-10-21-codex-sol-extract62-04. Offline adapter controls."""
import importlib.util
from pathlib import Path
import pytest
from test_details_review import adapter, material


@pytest.fixture
def bound(adapter, tmp_path):
    binder, fake = adapter
    mat, _, _ = material(fake)
    path = tmp_path / 'Details.png'; path.touch()
    binder.install(path, 'selected', uv_map='UV0')
    spec = importlib.util.spec_from_file_location('extract_under_test', Path(__file__).with_name('extraction_adapter.py'))
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    return mod, binder, fake, mat, mat.node_tree.nodes[binder.GROUP]


def test_supported_real_binder_descriptor_preserves_graph(bound):
    mod, binder, fake, mat, node = bound
    before = tuple(mat.node_tree.links), tuple(node.node_tree.links)
    result = mod.describe_group(node, mat, 'UV0')
    assert result['adapter_id'] == 'aop-player-colour-r-only-v1'
    assert result['details_channel'] == 'R' and result['player_number'] == 1 and result['strength'] == 1
    assert before == (tuple(mat.node_tree.links), tuple(node.node_tree.links))
    binder.set_player(2)
    assert mod.describe_group(node, mat, 'UV0')['player_number'] == 2


@pytest.mark.parametrize('defect', ['unknown', 'missing', 'ambiguous', 'space', 'uv', 'clamp', 'mute', 'formula'])
def test_unsupported_sources_and_graphs_refused(bound, defect):
    mod, binder, fake, mat, node = bound
    if defect == 'unknown': node.node_tree.name = 'Unknown'
    elif defect == 'missing': mat.node_tree.nodes['AoP Details'].image = None
    elif defect == 'ambiguous': node.node_tree.nodes.new('ShaderNodeValue')
    elif defect == 'space': mat.node_tree.nodes['AoP Details'].image.colorspace_settings.name = 'sRGB'
    elif defect == 'uv': mat.node_tree.nodes['AoP Details'].inputs['Vector'].links[0].from_node.uv_map = 'wrong'
    elif defect == 'clamp': node.node_tree.nodes['Details weight'].use_clamp = False
    elif defect == 'mute': node.node_tree.nodes['Player Colour'].mute = True
    elif defect == 'formula': node.node_tree.nodes['Details weight'].operation = 'ADD'
    with pytest.raises(ValueError): mod.describe_group(node, mat, 'UV0')


def test_second_basecolor_source_refused(bound):
    mod, binder, fake, mat, node = bound
    base = node.inputs['Base Color'].links[0].from_socket
    mix = mat.node_tree.nodes.new('ShaderNodeMix')
    extra = mat.node_tree.nodes.new('ShaderNodeTexImage'); extra.image = base.node.image
    mat.node_tree.links.new(base, mix.inputs[6]); mat.node_tree.links.new(extra.outputs['Color'], mix.inputs[7])
    mat.node_tree.links.new(mix.outputs[2], node.inputs['Base Color'])
    with pytest.raises(ValueError): mod.describe_group(node, mat, 'UV0')


def test_retained_r3_legacy_blue_suppression_topology_refused(bound):
    """R3 native readback: 10 nodes/11 links; R*(1-B)*Strength, not R-only."""
    mod, binder, fake, mat, node = bound
    g = node.node_tree
    sep = g.nodes['Details channels']; sep.name = 'Separate Color'
    subtract = g.nodes.new('ShaderNodeMath'); subtract.name = 'Math'; subtract.operation = 'SUBTRACT'
    subtract.inputs[0].default_value = 1
    product = g.nodes.new('ShaderNodeMath'); product.name = 'Math.001'; product.operation = 'MULTIPLY'
    weight = g.nodes['Details weight']; weight.name = 'Math.002'
    g.links.new(sep.outputs['Blue'], subtract.inputs[1])
    g.links.new(sep.outputs['Red'], product.inputs[0]); g.links.new(subtract.outputs[0], product.inputs[1])
    g.links.new(product.outputs[0], weight.inputs[0])
    assert len(g.nodes) == 10 and len(g.links) == 11
    with pytest.raises(ValueError, match='unsupported or incomplete'): mod.describe_group(node, mat, 'UV0')
