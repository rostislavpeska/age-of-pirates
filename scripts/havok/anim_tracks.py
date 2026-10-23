"""Filter the tracks of an animation in the converter's GXO text form (a / cg / c / k lines).
Used to turn a Blender-baked pose (a track for EVERY bone) into a pose that only drives the bones that must move.

Why: the intact and the damaged model of a ship have different roots (vanilla damaged roots carry a 90 deg rest),
so a constant track copied from one model misplaces bones on the other (root track -> the whole model turns,
flag/muzzle tracks -> flag and cannons off). Only bones sitting under an `animtrans` bone (identity world) share
their local transforms between the models; for the Treasure Ship those are exactly the sail bones.

Blender's FBX exporter bakes a track for EVERY bone of the armature (with simplify factor 0 it force-keys all of
them; `bake_anim_use_all_bones=False` changes nothing - verified, 125 tracks either way), so this filter is a
mandatory step, not a repair.

    python anim_tracks.py in.gxo out.gxo --keep bone_sail            # keep tracks whose bone name starts with a prefix
    python anim_tracks.py in.gxo out.gxo --drop Object02 bone_master  # drop named tracks
    ... --group Object02                                             # force the track-group (cg) name = the model's root bone
Then convert out.gxo -> out.gr2 with your converter (scripts/havok/converter.py --format gr2 out.gxo).
The `cg` name is what the engine binds the anim by (it must equal the root bone name of the intact AND the damaged
model); converters may name it after the root bone (Kevsoft's does), the file or the armature - --group pins it.
"""
import argparse


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('src'); ap.add_argument('out')
    ap.add_argument('--keep', nargs='*', default=[], help='bone name prefixes to keep (everything else dropped)')
    ap.add_argument('--drop', nargs='*', default=[], help='exact bone names to drop')
    ap.add_argument('--group', help='track-group name to write on the cg line (the model root bone name)')
    a = ap.parse_args()
    out = []; skip = False; kept = []; dropped = []; group = None
    for line in open(a.src, encoding='utf-8', errors='replace'):
        if line.startswith('cg '):
            group = line.split('"')[1] if '"' in line else line.split()[1]
            if a.group and a.group != group:
                print(f'track group "{group}" -> "{a.group}"'); line = 'cg "%s"\n' % a.group; group = a.group
        if line.startswith('c "'):
            name = line.split('"')[1]
            skip = name in a.drop or (bool(a.keep) and not any(name.startswith(p) for p in a.keep))
            (dropped if skip else kept).append(name)
        if skip and (line.startswith('c "') or line.startswith('k ')): continue
        out.append(line)
    open(a.out, 'w', encoding='utf-8', newline='\n').writelines(out)
    print(f'{a.out}: track group "{group}", kept {len(kept)} tracks, dropped {len(dropped)}' + (f' ({dropped[:6]}{"..." if len(dropped) > 6 else ""})' if dropped else ''))


if __name__ == '__main__':
    main()
