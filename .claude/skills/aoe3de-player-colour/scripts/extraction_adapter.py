"""Read-only canonical group descriptor for Blendify saved allocation extraction.

Audit: 2026-10-21-codex-sol-extract62-04 / INC-580. No binder or scene mutation.
"""
import hashlib
import importlib.util
import math
from pathlib import Path

BINDER_SHA256 = 'bfbd907690ddf9634c40feb5df9e4fae4297ff0c081aac214023247385334fde'
ADAPTER_ID = 'aop-player-colour-r-only-v1'


def _binder():
    path = Path(__file__).with_name('details_review.py')
    if hashlib.sha256(path.read_bytes()).hexdigest() != BINDER_SHA256:
        raise ValueError('canonical player-colour binder source mismatch')
    spec = importlib.util.spec_from_file_location('_aop_extraction_binder', path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


def describe_group(node, material, uv_layer):
    """Recognize exactly the finite canonical graph; unknown/ambiguous graphs fail."""
    binder = _binder()
    group = node.node_tree
    if node.name != binder.GROUP or group.name != binder.GROUP:
        raise ValueError('unsupported nested group: ' + group.name)
    if binder._group_errors(group) or binder._binding_error(material):
        raise ValueError('unsupported or incomplete canonical player-colour binding')
    if len(group.nodes) != 8 or len(group.links) != 8:
        raise ValueError('ambiguous canonical group: extra nodes or links')
    if any(getattr(n, 'mute', False) or getattr(n, 'node_tree', None) for n in group.nodes):
        raise ValueError('muted or nested canonical group is unsupported')
    if (not group.nodes['Details weight'].use_clamp
            or not group.nodes['lerp(1, PC, R)'].clamp_factor):
        raise ValueError('canonical player weight clamp changed')
    if sum(n.type == 'BSDF_PRINCIPLED' for n in material.node_tree.nodes) != 1:
        raise ValueError('ambiguous Principled binding')
    if len(node.inputs['Base Color'].links) != 1 or len(node.inputs['Details'].links) != 1:
        raise ValueError('missing or ambiguous source binding')
    details = material.node_tree.nodes['AoP Details']
    if details.image is None or details.image.colorspace_settings.name != 'Non-Color':
        raise ValueError('Details requires bound Non-Color image bytes')
    base_images = binder._upstream_images(node.inputs['Base Color'].links[0].from_node)
    if len(base_images) != 1 or base_images[0].image is None:
        raise ValueError('ambiguous or missing BaseColor source (explicit additional adapter required)')
    if base_images[0].image.colorspace_settings.name != 'sRGB':
        raise ValueError('BaseColor requires sRGB source')
    coordinate = details.inputs['Vector'].links[0].from_node
    # This descriptor supports a named UV0 source, not an arbitrary coordinate evaluator.
    if coordinate.type != 'UVMAP' or coordinate.uv_map != uv_layer:
        raise ValueError('Details requires the extracted explicit UV0 layer')
    base_uv = binder._uv_source(base_images[0])
    if base_uv is None:
        raise ValueError('implicit BaseColor UV0 is not explicit extraction evidence')
    player = list(group.nodes['Player Colour'].outputs[0].default_value)
    strength = float(group.nodes['Strength'].outputs[0].default_value)
    if not all(math.isfinite(v) for v in player + [strength]):
        raise ValueError('nonfinite player control')
    return {'adapter_id': ADAPTER_ID, 'binder_sha256': BINDER_SHA256,
            'formula': 'BaseColor * mix(white, PlayerColour, clamp(Details.R * Strength, 0, 1))',
            'details_channel': 'R', 'details_colorspace': 'Non-Color', 'uv_layer': uv_layer,
            'basecolor_node': base_images[0].name, 'details_node': details.name,
            'player_linear_rgba': player, 'strength': strength,
            'player_number': next((p for p, rgb in binder.PLAYER_COLORS.items()
                                   if all(abs(a-b) < 1e-6 for a,b in zip(player, binder._lin(rgb)))), None)}
