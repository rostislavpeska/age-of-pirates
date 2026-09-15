"""Bone table for the damaged model, in the GXO `b` line form gr2_addbones.py reads (absolute transforms in the
converter's frame, 1-based parent index, 0 = root). Vanilla battleship pattern: per sail an `animtrans_sailNN`
bone under the sail's mast piece with an IDENTITY absolute transform (the appender turns that into the local
transform that cancels the piece's offset), and the rig's sail chain + bar bones under it with their intact-model
transforms copied verbatim from the rig GXO, so one idle/walk pair drives both models.

    python dmg_bonetable.py rig.gxo dmg.json out_bones.gxo
"""
import sys, json
from gxo_sails import parse, fmt


def main():
    rigp, jpath, outp = sys.argv[1:4]
    _, rb, _ = parse(rigp); J = json.load(open(jpath))
    rig_names = [b[0] for b in rb]; rig = {b[0]: b for b in rb}
    lines = ['b "bone_main" 0 1 0 0 0 1 0 0 0 1 0 0 0']                 # the damaged model's root (existing, skipped by the appender)
    index = {'bone_main': 1}
    for sail, mast in J['sail_mast'].items():                             # mast pieces: existing bones, listed only as parents
        if mast not in index: lines.append(f'b "{mast}" 1 1 0 0 0 1 0 0 0 1 0 0 0'); index[mast] = len(lines)
    letter = {s: J['rig_mb'][s + '_cloth'].replace('bone_sail', '').replace('_bottom', '') for s in J['sail_mast']}
    for sail in sorted(J['sail_mast']):
        at = f'animtrans_{sail}'; lines.append(f'b "{at}" {index[J["sail_mast"][sail]]} 1 0 0 0 1 0 0 0 1 0 0 0'); index[at] = len(lines)
        L = letter[sail]
        for n in rig_names:
            if not (n == f'bone_sail{L}_rot' or n == f'bone_sail{L}' or n == f'bone_sail{L}_bottom' or n.startswith(f'bone_sail{L}mast_')): continue
            par_name = rig_names[rig[n][1] - 1]
            par = index[at] if par_name == 'Object02' else index[par_name]
            lines.append('b "%s" %d %s' % (n, par, ' '.join(fmt(x) for x in rig[n][2]))); index[n] = len(lines)
    open(outp, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
    print('WROTE', outp, 'entries', len(lines), '| sails', sorted(J['sail_mast']), '| new bones', len(lines) - 1 - len(set(J['sail_mast'].values())))


if __name__ == '__main__':
    main()
