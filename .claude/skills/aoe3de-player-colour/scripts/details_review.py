"""details_review.py - preview AoE3 DE player colour in a Blender review scene with the game's own formula.

    albedo_lin = BaseColor_lin * lerp(1, PlayerColour_lin, Details.R)        Details: Non-Color, R only, UV0

One shared node group (GROUP) holds THE player colour (RGB node 'Player Colour') and a 'Strength' value (1 = the game,
0 = off); every wired material uses it, so one set_player(1..8) recolours the whole scene (vanilla playercolors.xml).
Declared Details files must exist. Missing files are errors, never magenta placeholders.
The old R*(1-B) missing-file workaround is not the engine formula and is rejected on existing groups.
Audit: 2026-10-21-codex-sol-import62-03, INC-580 / Blendify #62.

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
        errors = _group_errors(g)
        if errors:
            raise ValueError('Unsupported existing player-colour group: ' + '; '.join(errors))
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
    sep = N.new('ShaderNodeSeparateColor'); sep.name = 'Details channels'; sep.mode = 'RGB'; sep.location = (-600, 150)
    f2 = N.new('ShaderNodeMath'); f2.operation = 'MULTIPLY'; f2.use_clamp = True; f2.location = (-100, 150)   # * Strength
    f2.name = 'Details weight'
    lerp = N.new('ShaderNodeMix'); lerp.data_type = 'RGBA'; lerp.blend_type = 'MIX'; lerp.clamp_factor = True
    lerp.name = 'lerp(1, PC, R)'; lerp.location = (80, -100)
    lerp.inputs[6].default_value = (1.0, 1.0, 1.0, 1.0)
    mul = N.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.name = 'BaseColor x'
    mul.inputs[0].default_value = 1.0; mul.location = (300, 0)
    L.new(gi.outputs['Details'], sep.inputs['Color'])
    L.new(sep.outputs['Red'], f2.inputs[0]); L.new(st.outputs[0], f2.inputs[1])
    L.new(f2.outputs[0], lerp.inputs[0]); L.new(pc.outputs[0], lerp.inputs[7])
    L.new(gi.outputs['Base Color'], mul.inputs[6]); L.new(lerp.outputs[2], mul.inputs[7])
    L.new(mul.outputs[2], go.inputs['Color'])
    return g


def _fed(socket, source):
    return len(socket.links) == 1 and socket.links[0].from_socket == source


def _group_errors(g):
    """Validate the active formula, rather than trusting the shared group's name."""
    try:
        N = g.nodes
        gi = next(n for n in N if n.type == 'GROUP_INPUT')
        go = next(n for n in N if n.type == 'GROUP_OUTPUT' and n.is_active_output)
        sep, weight = N['Details channels'], N['Details weight']
        lerp, mul = N['lerp(1, PC, R)'], N['BaseColor x']
        pc, strength = N['Player Colour'], N['Strength']
        checks = [sep.bl_idname == 'ShaderNodeSeparateColor' and sep.mode == 'RGB',
                  weight.type == 'MATH' and weight.operation == 'MULTIPLY',
                  lerp.type == 'MIX' and lerp.data_type == 'RGBA' and lerp.blend_type == 'MIX',
                  mul.type == 'MIX' and mul.data_type == 'RGBA' and mul.blend_type == 'MULTIPLY',
                  pc.type == 'RGB' and strength.type == 'VALUE',
                  tuple(lerp.inputs[6].default_value) == (1, 1, 1, 1), mul.inputs[0].default_value == 1,
                  _fed(sep.inputs['Color'], gi.outputs['Details']),
                  _fed(weight.inputs[0], sep.outputs['Red']), _fed(weight.inputs[1], strength.outputs[0]),
                  _fed(lerp.inputs[0], weight.outputs[0]), _fed(lerp.inputs[7], pc.outputs[0]),
                  _fed(mul.inputs[6], gi.outputs['Base Color']), _fed(mul.inputs[7], lerp.outputs[2]),
                  _fed(go.inputs['Color'], mul.outputs[2])]
        return [] if all(checks) else ['formula is not BaseColor * mix(white, player, Details.R * Strength)']
    except (KeyError, IndexError, StopIteration, AttributeError, TypeError):
        return ['unrecognized or legacy formula; preserve it for explicit migration on a copy']


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
    """Load an existing, explicitly declared linear map; never repoint a same-name image."""
    path = bpy.path.abspath(str(path))
    if not os.path.isfile(path):
        raise FileNotFoundError('Declared Details map is missing: ' + path)
    identity = os.path.normcase(os.path.abspath(path))
    img = next((im for im in bpy.data.images
                if im.source == 'FILE' and im.colorspace_settings.name == 'Non-Color'
                and os.path.normcase(os.path.abspath(bpy.path.abspath(im.filepath))) == identity), None)
    if img is None:
        img = bpy.data.images.load(path, check_existing=False)
        if name:
            img.name = name
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


def _upstream_images(node):
    pending, seen, images = [node], set(), []
    while pending:
        current = pending.pop()
        if current in seen:
            continue
        seen.add(current)
        if current.type == 'TEX_IMAGE':
            images.append(current)
            continue
        inputs = [current.inputs['Base Color']] if current.name == GROUP and current.type == 'GROUP' else current.inputs
        pending.extend(link.from_node for sock in inputs for link in sock.links)
    return images


def _uv_source(node):
    """Preserve an explicit coordinate chain through AO mixes; refuse conflicting readers."""
    images = _upstream_images(node)
    sources = [n.inputs['Vector'].links[0].from_socket if n.inputs['Vector'].links else None for n in images]
    if sources and any(source != sources[0] for source in sources):
        raise ValueError('Unsupported BaseColor chain: conflicting or implicit/explicit texture coordinates')
    return sources[0] if sources else None


def _binding_error(mat):
    N = mat.node_tree.nodes
    gn, t = N.get('AoP Player Colour'), N.get('AoP Details')
    if gn is None and t is None:
        return None
    b, lk = _base_link(mat)
    if gn is None or t is None or gn.type != 'GROUP' or t.type != 'TEX_IMAGE':
        return 'partial or conflicting named player-colour nodes'
    if gn.node_tree is None or _group_errors(gn.node_tree):
        return 'unsupported player-colour group'
    if lk is None or lk.from_node != gn or lk.from_socket != gn.outputs['Color']:
        return 'player-colour output does not feed Principled Base Color'
    if not gn.inputs['Base Color'].links or not _fed(gn.inputs['Details'], t.outputs['Color']):
        return 'missing BaseColor or Details input link'
    if not t.inputs['Vector'].links:
        return 'Details has no explicit UV input'
    try:
        expected_uv = _uv_source(gn.inputs['Base Color'].links[0].from_node)
    except ValueError as exc:
        return str(exc)
    if expected_uv is not None and not _fed(t.inputs['Vector'], expected_uv):
        return 'Details coordinates differ from the BaseColor chain'
    return None


def wire_material(mat, img, uv_map='UVMap'):
    """BaseColor -> tint group(Base Color, Details) -> Principled Base Color; idempotent (re-wiring swaps the image).
    The Details node reuses the BaseColor node's UV input (UV0), else a UV Map node on `uv_map`."""
    if img is None or img.colorspace_settings.name != 'Non-Color' or not os.path.isfile(bpy.path.abspath(img.filepath)):
        raise ValueError('Details must be an existing explicitly loaded Non-Color image')
    if not mat or not mat.node_tree:
        raise ValueError('Unsupported material: no node tree')
    N, L = mat.node_tree.nodes, mat.node_tree.links
    if sum(n.type == 'BSDF_PRINCIPLED' for n in N) != 1:
        raise ValueError(mat.name + ': unsupported (requires one Principled shader)')
    err = _binding_error(mat)
    if err:
        raise ValueError(mat.name + ': ' + err)
    if 'AoP Player Colour' in N:
        N['AoP Details'].image = img; return 'updated'
    b, lk = _base_link(mat)
    if lk is None:
        raise ValueError(mat.name + ': unsupported (no linked Principled Base Color)')
    group = tint_group()  # Validate before touching the material.
    src = lk.from_socket; src_node = lk.from_node
    uv_source = _uv_source(src_node)
    t = N.new('ShaderNodeTexImage'); t.name = t.label = 'AoP Details'; t.image = img; t.interpolation = 'Linear'; t[TAG] = 1
    t.location = (src_node.location.x, src_node.location.y + 320)
    if uv_source is not None:
        L.new(uv_source, t.inputs['Vector'])
    else:
        uv = N.new('ShaderNodeUVMap'); uv.uv_map = uv_map; uv[TAG] = 1; L.new(uv.outputs['UV'], t.inputs['Vector'])
    gn = N.new('ShaderNodeGroup'); gn.node_tree = group; gn.name = gn.label = 'AoP Player Colour'; gn[TAG] = 1
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
    """Match upstream BaseColor images, including AO multiply chains and existing tint groups."""
    if not basecolor_match:
        raise ValueError('A nonempty BaseColor identity filter is required')
    out = []
    for m in bpy.data.materials:
        b, lk = _base_link(m)
        if lk is None:
            continue
        for node in _upstream_images(lk.from_node):
            if node.type == 'TEX_IMAGE' and node.image:
                im = node.image
                hay = ' '.join(str(x) for x in (im.name, im.filepath, im.get('aop_final_path', ''))).lower()
                if basecolor_match.lower() in hay:
                    out.append(m); break
    return out


def install(details_path, basecolor_match='BaseColor', player=None, strength=None, final_path=None, uv_map='UVMap'):
    """wire every matching material; loads at most one Details image; never reloads, re-points or saves anything else"""
    if not os.path.isfile(bpy.path.abspath(str(details_path))):
        raise FileNotFoundError('Declared Details map is missing: ' + str(details_path))
    mats = targets(basecolor_match)
    if not mats:
        raise ValueError('No material matches BaseColor filter: ' + basecolor_match)
    for mat in mats:
        err = _binding_error(mat)
        if err:
            raise ValueError(mat.name + ': ' + err)
        b, lk = _base_link(mat)
        if sum(n.type == 'BSDF_PRINCIPLED' for n in mat.node_tree.nodes) != 1 or lk is None:
            raise ValueError(mat.name + ': unsupported (requires one linked Principled shader)')
        _uv_source(lk.from_node)
    if player is not None and int(player) not in PLAYER_COLORS:
        raise ValueError('Player must be 1..8')
    if strength is not None and not 0 <= float(strength) <= 1:
        raise ValueError('Strength must be 0..1')
    g = tint_group()
    img = details_image(str(details_path), final_path=final_path)
    if player is not None:
        set_player(player)
    if strength is not None:
        set_strength(strength)
    res = {m.name: wire_material(m, img, uv_map) for m in mats}
    return f'player colour installed (group "{g.name}"): {len(mats)} material(s) {res}; Details -> {details_path}'


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
        err = _binding_error(m)
        if err:
            bad.append(f'{m.name}: {err}')
        if t is None or t.image is None or t.image.colorspace_settings.name != 'Non-Color':
            bad.append(f'{m.name}: Details image missing or not Non-Color')
        elif not os.path.isfile(bpy.path.abspath(t.image.filepath)):
            bad.append(f'{m.name}: declared Details file is missing')
    return 'SELFTEST PASS' if not bad else 'SELFTEST FAIL: ' + '; '.join(bad)
