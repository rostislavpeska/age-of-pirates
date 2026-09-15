"""Write the rig table straight from the Blender rig scene - no converter needed.
Output is the small text form the Granny tools already read (the converter's GXO `b` / `m` / `mb` / `v` lines):
  b "name" parent m00..m22 tx ty tz   absolute rest transform in armature space (row-major 3x3 = R transposed)
  m "sail_01_cloth" / mb "bone" / v x y z   every object whose name starts with sail_ -> its bone + vertex positions
Armature space of the rig scenes = engine units, x across, y along the ship, z up (engine = (-x, z, -y)), i.e. the
same frame and units as a converter GXO of a converter-made model, so gr2_addbones.py (--map mirror), gr2_splitmesh.py,
dmg_extract.py and dmg_bonetable.py take this file exactly like a converter dump.

    blender -b rig.blend --python scripts/havok/rig_table.py -- out.gxo
"""
import bpy, sys

out = sys.argv[sys.argv.index('--') + 1]
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
bones = list(arm.data.bones); index = {b.name: i + 1 for i, b in enumerate(bones)}
lines = []
for b in bones:
    M = b.matrix_local; R = M.to_3x3(); t = M.translation
    nums = [R[c][r] for r in range(3) for c in range(3)]              # row-major of R transposed (GXO convention)
    lines.append('b "%s" %d %s' % (b.name, index[b.parent.name] if b.parent else 0, ' '.join('%.9g' % x for x in nums + [t.x, t.y, t.z])))
nsail = 0
for o in sorted(bpy.data.objects, key=lambda o: o.name):
    if o.type != 'MESH' or not o.name.startswith('sail_'): continue
    bone = o.vertex_groups[0].name if o.vertex_groups else (o.parent_bone or '')
    lines.append('m "%s"' % o.name); lines.append('mb "%s"' % bone); lines.append('mm 1')
    for v in o.data.vertices:
        p = o.matrix_local @ v.co if o.parent == arm else arm.matrix_world.inverted() @ (o.matrix_world @ v.co)
        lines.append('v %.9g %.9g %.9g' % (p.x, p.y, p.z))
    nsail += 1
open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
print('WROTE', out, 'bones', len(bones), 'sail meshes', nsail)
