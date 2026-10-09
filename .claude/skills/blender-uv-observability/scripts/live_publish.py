"""Publish a checkpoint to the owner's live viewer and PROVE it is on his screen (pure Python, no Blender).

  python live_publish.py --live <live dir> --source <file.blend> --version <id> --scene "<scene>" [--shading MATERIAL]
                         [--with <sibling library> ...] [--note TEXT] [--wait 120]

Copies the .blend (and its sibling libraries) to <live dir>/<version>/, writes <live dir>/PUBLISHED.json atomically, then
waits for live_viewer.py's heartbeat <live dir>/VIEWER_STATE.json to report this version with the SAME file sha256 and
the published scene, fresh (heartbeat younger than STALE s). On success it writes <live dir>/<version>/LIVE_READBACK.json
= the delivery.live_readback block a handoff needs, prints LIVE_READBACK and exits 0. Otherwise it prints NOT VISIBLE
with the viewer's last state and exits 4: the checkpoint is published but NOT delivered (owner 2026-10-09: "this
handoff contract should be unbreakable"; a viewer stuck on an older file had been reported as delivered).
"""
import argparse
import hashlib
import json
import os
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

STALE = 30.0


def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(8 << 20), b''):
            h.update(b)
    return h.hexdigest()


def write_json(p, d):
    tmp = Path(p).with_suffix('.tmp'); tmp.write_text(json.dumps(d, indent=1), encoding='utf-8'); os.replace(tmp, p)


def age_s(at):
    try:
        t = datetime.strptime(at, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
    except (TypeError, ValueError):
        return float('inf')
    return (datetime.now(timezone.utc) - t).total_seconds()


def publish(live, source, version, scene, shading='MATERIAL', with_=(), note=''):
    live = Path(live); dst = live / version; dst.mkdir(parents=True, exist_ok=True)
    blend = dst / Path(source).name
    shutil.copyfile(source, blend)
    for w in with_:
        shutil.copyfile(w, dst / Path(w).name)
    ptr = {'version': version, 'file': str(blend), 'scene': scene, 'shading': shading, 'sha256': sha(blend), 'note': note,
           'published': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}
    write_json(live / 'PUBLISHED.json', ptr)
    return ptr


def readback_ok(ptr, st):
    """the viewer state proves the published bytes and scene are on screen now"""
    why = []
    if not st:
        return False, ['no viewer heartbeat (VIEWER_STATE.json missing): is the live viewer running?']
    if st.get('loaded_version') != ptr['version']:
        why.append(f"viewer shows {st.get('loaded_version')!r}, not {ptr['version']!r}")
    if st.get('file_sha256') != ptr['sha256']:
        why.append('viewer file bytes differ from the published copy')
    if st.get('scene') != ptr['scene']:
        why.append(f"viewer scene {st.get('scene')!r}, not {ptr['scene']!r}")
    if age_s(st.get('at')) > STALE:
        why.append(f"heartbeat is stale ({st.get('at')}): the viewer is not running or is blocked")
    if st.get('error'):
        why.append(f"viewer error: {st['error']}")
    return not why, why


def wait_readback(live, ptr, wait=120.0, poll=1.0):
    live = Path(live); deadline = time.time() + wait; st, why = None, []
    while True:
        try:
            st = json.loads((live / 'VIEWER_STATE.json').read_text(encoding='utf-8'))
        except (OSError, ValueError):
            st = None
        ok, why = readback_ok(ptr, st)
        if ok:
            rb = {'version': ptr['version'], 'file_sha256': ptr['sha256'], 'scene': ptr['scene'],
                  'viewer': f"pid {st.get('pid')}", 'at': st.get('at'), 'stashed': st.get('stashed') or []}
            write_json(live / ptr['version'] / 'LIVE_READBACK.json', rb)
            return True, rb
        if time.time() >= deadline:
            return False, {'why': why, 'viewer_state': st}
        time.sleep(poll)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument('--live', required=True); ap.add_argument('--source', required=True); ap.add_argument('--version', required=True)
    ap.add_argument('--scene', required=True); ap.add_argument('--shading', default='MATERIAL'); ap.add_argument('--note', default='')
    ap.add_argument('--with', dest='with_', action='append', default=[]); ap.add_argument('--wait', type=float, default=120.)
    a = ap.parse_args(argv)
    ptr = publish(a.live, a.source, a.version, a.scene, a.shading, a.with_, a.note)
    ok, res = wait_readback(a.live, ptr, a.wait)
    if ok:
        print('LIVE_READBACK', json.dumps(res)); return 0
    print('NOT VISIBLE - published but not delivered:', json.dumps(res)); return 4


if __name__ == '__main__':
    sys.exit(main())
