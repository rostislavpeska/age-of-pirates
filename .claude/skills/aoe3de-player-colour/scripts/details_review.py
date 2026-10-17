"""details_review.py - preview AoE3 DE player colour in a Blender review scene with the game's own formula.

    albedo_lin = BaseColor_lin * lerp(1, PlayerColour_lin, Details.R)        Details: Non-Color, R only, UV0

One shared node group (GROUP) holds THE player colour (RGB node 'Player Colour') and a 'Strength' value (1 = the game,
0 = off); every wired material uses it, so one set_player(1..8) recolours the whole scene (vanilla playercolors.xml).
A missing Details file renders magenta (1, 0, 1) in Blender; the group multiplies R by (1 - B), so a missing file tints
nothing (Details maps have B = 0). A scene can therefore point at a Details file that does not exist yet.

Node and group names are the ones the Age of Pirates review scenes already carry ('AoP Player Colour', 'AoP Details'):
this module re-wires such a scene idempotently instead of stacking a second tint.

Runs INSIDE Blender (bpy). Live scene: one MCP call, logged first per blender-mcp-safety; it only adds nodes and at most
one image, never reloads other images and never saves:
    import importlib.util as u; s = u.spec_from_file_location('details_review', r'<this file>'); m = u.module_from_spec(s)
    s.loader.exec_module(m); print(m.install(r'<maps>/P2048_Details.png', basecolor_match='P2048_BaseColor'))
Background proof on a COPY of the scene: blender -b copy.blend --python-expr "<the same, then m.selftest()>".
"""
import os

import bpy

GROUP = 'AoP Player Colour'
TAG = 'aop_details'                      # custom prop on every node this module adds
# Data/playercolors.xml (vanilla, color1, sRGB 0-255) = pc_common.PLAYER_COLORS
PLAYER_COLORS = {1: (45, 45, 245), 2: (210, 40, 40), 3: (224, 224, 30), 4: (145, 15, 243), 5: (42, 212, 58),
                 6: (234, 135, 0), 7: (28, 194, 219), 8: (235, 97, 235)}


def srgb_to_lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _lin(rgb255):
    return tuple(srgb_to_lin(v) for v in rgb255) + (1.0,)


def tint_group():
    """the shared node group (created once): inputs Base Color, Details; output Color"""
    g = bpy.data.node_groups.get(GROUP)
    if g is not None:
        return g
    g = bpy.data.node_groups.new(GROUP, 'ShaderNodeTree'); g[TAG] = 1
    g.interface.new_socket('Base Color', in_out='INPUT', socket_type='NodeSocketColor')
    g.interface.new_socket('Details', in_out='INPUT', socket_type='NodeSocketColor')
    g.interface.new_socket('Color', in_out='OUTPUT', socket_type='NodeSocketColor')
    N, L = g.nodes, g.links
    gi = N.new('NodeGroupInput'); gi.location = (-800, 0)
    go = N.new('NodeGroupOutput'); go.location = (500, 0)
    pc = N.new('ShaderNodeRGB'); pc.name = pc.label = 'Player Colour'; pc.location = (-500, -250)
    pc.outputs[0].default_value = _lin(PLAYER_COLORS[1])
    st = N.new('ShaderNodeValue'); st.name = st.label = 'Strength'; st.location = (-500, -420); st.outputs[0].default_value = 1.0
    sep = N.new('ShaderNodeSeparateColor'); sep.location = (-600, 150)
    inv = N.new('ShaderNodeMath'); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1.0; inv.location = (-400, 250)
    f1 = N.new('ShaderNodeMath'); f1.operation = 'MULTIPLY'; f1.location = (-250, 150)          # R * (1 - B): magenta -> 0
    f2 = N.new('ShaderNodeMath'); f2.operation = 'MULTIPLY'; f2.use_clamp = True; f2.location = (-100, 150)   # * Strength
    lerp = N.new('ShaderNodeMix'); lerp.data_type = 'RGBA'; lerp.blend_type = 'MIX'; lerp.clamp_factor = True
    lerp.name = 'lerp(1, PC, R)'; lerp.location = (80, -100)
    lerp.inputs[6].default_value = (1.0, 1.0, 1.0, 1.0)
    mul = N.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.name = 'BaseColor x'
    mul.inputs[0].default_value = 1.0; mul.location = (300, 0)
    L.new(gi.outputs['Details'], sep.inputs['Color'])
    L.new(sep.outputs['Blue'], inv.inputs[1]); L.new(sep.outputs['Red'], f1.inputs[0]); L.new(inv.outputs[0], f1.inputs[1])
    L.new(f1.outputs[0], f2.inputs[0]); L.new(st.outputs[0], f2.inputs[1])
    L.new(f2.outputs[0], lerp.inputs[0]); L.new(pc.outputs[0], lerp.inputs[7])
    L.new(gi.outputs['Base Color'], mul.inputs[6]); L.new(lerp.outputs[2], mul.inputs[7])
    L.new(mul.outputs[2], go.inputs['Color'])
    return g


def set_player(num=1):
    tint_group().nodes['Player Colour'].outputs[0].default_value = _lin(PLAYER_COLORS[int(num)])
    return f'player colour {num} = sRGB {PLAYER_COLORS[int(num)]}'


def set_color_srgb(rgb255):
    tint_group().nodes['Player Colour'].outputs[0].default_value = _lin(rgb255)


def set_strength(v):
    tint_group().nodes['Strength'].outputs[0].default_value = float(v)


def controls():
    """(player colour socket, strength socket) for a UI panel (layout.prop(sock, 'default_value')), or None"""
    g = bpy.data.node_groups.get(GROUP)
    if g is None or 'Player Colour' not in g.nodes:
        return None
    return g.nodes['Player Colour'].outputs[0], g.nodes['Strength'].outputs[0]


def details_image(path, name=None, final_path=None):
    """a FILE image on `path` (may be missing: Blender shows magenta, which the group ignores), Non-Color"""
    name = name or os.path.basename(path)
    img = bpy.data.images.get(name)
    if img is None:
        if os.path.exists(path):
            img = bpy.data.images.load(str(path), check_existing=False); img.name = name
        else:
            img = bpy.data.images.new(name, 4, 4, alpha=False); img.source = 'FILE'; img.filepath = str(path)
    elif os.path.normcase(os.path.abspath(bpy.path.abspath(img.filepath))) != os.path.normcase(os.path.abspath(path)):
        img.filepath = str(path)
    img.colorspace_settings.name = 'Non-Color'
    if final_path:
        img['aop_final_path'] = str(final_path)       # review watchers that swap candidate maps track this
    img[TAG] = 1
    return img


def _base_link(mat):
    if not mat or not mat.node_tree:
        return None, None
    b = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if b is None or not b.inputs['Base Color'].links:
        return b, None
    return b, b.inputs['Base Color'].links[0]


def wire_material(mat, img, uv_map='UVMap'):
    """BaseColor -> tint group(Base Color, Details) -> Principled Base Color; idempotent (re-wiring swaps the image).
    The Details node reuses the BaseColor node's UV input (UV0), else a UV Map node on `uv_map`."""
    N, L = mat.node_tree.nodes, mat.node_tree.links
    if 'AoP Player Colour' in N and 'AoP Details' in N:
        N['AoP Details'].image = img; return 'updated'
    b, lk = _base_link(mat)
    if lk is None:
        return 'skipped (no Base Color link)'
    src = lk.from_socket; src_node = lk.from_node
    uv_link = src_node.inputs['Vector'].links[0] if src_node.type == 'TEX_IMAGE' and src_node.inputs['Vector'].links else None
    t = N.new('ShaderNodeTexImage'); t.name = t.label = 'AoP Details'; t.image = img; t.interpolation = 'Linear'; t[TAG] = 1
    t.location = (src_node.location.x, src_node.location.y + 320)
    if uv_link is not None:
        L.new(uv_link.from_socket, t.inputs['Vector'])
    else:
        uv = N.new('ShaderNodeUVMap'); uv.uv_map = uv_map; uv[TAG] = 1; L.new(uv.outputs['UV'], t.inputs['Vector'])
    gn = N.new('ShaderNodeGroup'); gn.node_tree = tint_group(); gn.name = gn.label = 'AoP Player Colour'; gn[TAG] = 1
    gn.location = (b.location.x - 260, b.location.y + 200)
    L.remove(lk)
    L.new(src, gn.inputs['Base Color']); L.new(t.outputs['Color'], gn.inputs['Details'])
    L.new(gn.outputs['Color'], b.inputs['Base Color'])
    return 'wired'


def unwire_material(mat):
    N, L = mat.node_tree.nodes, mat.node_tree.links
    gn = N.get('AoP Player Colour')
    if gn is None:
        return False
    b, _ = _base_link(mat)
    src = gn.inputs['Base Color'].links[0].from_socket if gn.inputs['Base Color'].links else None
    for n in [n for n in N if n.get(TAG)]:
        N.remove(n)
    if src is not None and b is not None:
        L.new(src, b.inputs['Base Color'])
    return True


def targets(basecolor_match):
    """materials whose Principled Base Color comes from an image whose name / file / aop_final_path contains the match"""
    out = []
    for m in bpy.data.materials:
        b, lk = _base_link(m)
        if m.node_tree and 'AoP Player Colour' in m.node_tree.nodes:
            out.append(m); continue
        if lk is None or lk.from_node.type != 'TEX_IMAGE' or lk.from_node.image is None:
            continue
        im = lk.from_node.image
        hay = ' '.join(str(x) for x in (im.name, im.filepath, im.get('aop_final_path', ''))).lower()
        if basecolor_match.lower() in hay:
            out.append(m)
    return out


def install(details_path, basecolor_match='BaseColor', player=1, strength=1.0, final_path=None, uv_map='UVMap'):
    """wire every matching material; loads at most one Details image; never reloads, re-points or saves anything else"""
    g = tint_group(); set_player(player); set_strength(strength)
    img = details_image(str(details_path), final_path=final_path)
    mats = targets(basecolor_match)
    res = {m.name: wire_material(m, img, uv_map) for m in mats}
    return (f'player colour installed (group "{g.name}", player {player} sRGB {PLAYER_COLORS[int(player)]}, strength '
            f'{strength}): {len(mats)} material(s) {res}; Details -> {details_path}'
            + ('' if os.path.exists(details_path) else ' (no file yet: no tint until one exists)'))


def uninstall():
    n = sum(unwire_material(m) for m in bpy.data.materials if m.node_tree)
    g = bpy.data.node_groups.get(GROUP)
    if g is not None and g.users == 0:
        bpy.data.node_groups.remove(g)
    return f'player colour removed from {n} material(s)'


def selftest():
    """structural check after install(): every wired material routes BaseColor through the group and the Details node is
    Non-Color on the BaseColor's UV. Renders are the separate before/after proof (references/review-preview.md)."""
    bad = []
    for m in bpy.data.materials:
        if not m.node_tree or 'AoP Player Colour' not in m.node_tree.nodes:
            continue
        N = m.node_tree.nodes; gn = N['AoP Player Colour']; t = N.get('AoP Details')
        b, lk = _base_link(m)
        if lk is None or lk.from_node != gn:
            bad.append(f'{m.name}: Principled Base Color is not fed by the tint group')
        if t is None or t.image is None or t.image.colorspace_settings.name != 'Non-Color':
            bad.append(f'{m.name}: Details image missing or not Non-Color')
        if not gn.inputs['Base Color'].links:
            bad.append(f'{m.name}: the group has no BaseColor input')
    return 'SELFTEST PASS' if not bad else 'SELFTEST FAIL: ' + '; '.join(bad)
