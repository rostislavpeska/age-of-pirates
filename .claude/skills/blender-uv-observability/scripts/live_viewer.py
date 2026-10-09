"""The owner's live viewer (GUI Blender started by an agent). The ONLY way a published checkpoint reaches his screen.

  blender <published copy> --python live_viewer.py -- --pointer <live dir>/PUBLISHED.json [--free-mcp-port]

Every TICK seconds it reads the pointer {version, file, scene, shading} written by live_publish.py. A newer version is
loaded at once. Unsaved edits in the open file are never discarded and never block the update: they are saved first to
<live dir>/stash/<old version>_unsaved_<UTC>.blend (copy) and named in the heartbeat. (A viewer that waited for unsaved
edits stayed on an old file while the new one was reported delivered; owner 2026-10-09: "this handoff contract should be
unbreakable".) After every tick it writes <live dir>/VIEWER_STATE.json:
  {pid, loaded_version, file, file_sha256, scene, at, stashed, error}
live_publish.py waits for that readback; the handoff records it as delivery.live_readback.
"""
import hashlib
import json
import os
import sys
import time
from pathlib import Path

import bpy

TICK = 5.0
STATE = {'version': None, 'file': None, 'sha': None, 'stashed': [], 'error': None}
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
PTR = Path(ARGS[ARGS.index('--pointer') + 1]) if '--pointer' in ARGS else None


def utc():
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())


def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(8 << 20), b''):
            h.update(b)
    return h.hexdigest()


def read_ptr(ptr):
    try:
        return json.loads(Path(ptr).read_text(encoding='utf-8-sig'))
    except (OSError, ValueError) as e:
        STATE['error'] = f'pointer unreadable: {e}'
        return None


def current_scene():
    w = bpy.context.window_manager.windows
    return (w[0].scene.name if w else bpy.context.scene.name) if bpy.context.scene else None


def heartbeat(ptr):
    st = {'pid': os.getpid(), 'loaded_version': STATE['version'], 'file': STATE['file'], 'file_sha256': STATE['sha'],
          'scene': current_scene(), 'at': utc(), 'stashed': STATE['stashed'][-5:], 'error': STATE['error']}
    out = Path(ptr).with_name('VIEWER_STATE.json'); tmp = out.with_suffix('.tmp')
    tmp.write_text(json.dumps(st, indent=1), encoding='utf-8'); os.replace(tmp, out)
    return st


def present(p):
    """switch every window to the published scene and shading, frame the models"""
    sc = bpy.data.scenes.get(p.get('scene') or '')
    for win in bpy.context.window_manager.windows:
        if sc:
            win.scene = sc
        for area in win.screen.areas:
            if area.type != 'VIEW_3D':
                continue
            sp = area.spaces.active
            sp.shading.type = p.get('shading') or 'SOLID'; sp.clip_end = 1000
            reg = [r for r in area.regions if r.type == 'WINDOW']
            if reg:
                with bpy.context.temp_override(window=win, area=area, region=reg[0]):
                    try:
                        bpy.ops.view3d.view_all(center=False)
                    except RuntimeError as e:
                        STATE['error'] = f'frame failed: {e}'


def load(p, ptr):
    """stash unsaved edits, then open the published file; never waits"""
    if bpy.data.is_dirty and bpy.data.filepath:
        d = Path(ptr).parent / 'stash'; d.mkdir(parents=True, exist_ok=True)
        stash = d / f"{STATE['version'] or 'unknown'}_unsaved_{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}.blend"
        bpy.ops.wm.save_as_mainfile(filepath=str(stash), copy=True, relative_remap=False)
        STATE['stashed'].append(str(stash))
    win = bpy.context.window_manager.windows
    if win:
        with bpy.context.temp_override(window=win[0]):
            bpy.ops.wm.open_mainfile(filepath=p['file'])
    else:
        bpy.ops.wm.open_mainfile(filepath=p['file'])
    STATE.update(version=p.get('version'), file=p['file'], sha=sha(p['file']), error=None)
    sc = bpy.data.scenes.get(p.get('scene') or '')
    if sc and bpy.context.window:
        bpy.context.window.scene = sc


def tick(ptr=None):
    ptr = ptr or PTR
    p = read_ptr(ptr)
    try:
        if p and p.get('version') != STATE['version']:
            load(p, ptr)
            present(p)
    except Exception as e:  # noqa: BLE001 - a viewer error must be visible in the heartbeat, never silent
        STATE['error'] = f'{type(e).__name__}: {e}'
    heartbeat(ptr)
    return TICK


def free_mcp_port():
    """the BlenderMCP add-on auto-starts a server on 9876; a viewer must not hold the port other agents connect to"""
    srv = getattr(bpy.types, 'blendermcp_server', None)
    if srv:
        try:
            srv.stop(); del bpy.types.blendermcp_server
        except Exception as e:  # noqa: BLE001
            STATE['error'] = f'BlenderMCP stop failed: {e}'


@bpy.app.handlers.persistent
def _on_load(_):
    p = read_ptr(PTR) if PTR else None
    if p:
        bpy.app.timers.register(lambda: present(p), first_interval=.5)


if __name__ == '__main__' and PTR:
    if '--free-mcp-port' in ARGS:
        free_mcp_port()
    p0 = read_ptr(PTR)
    if p0 and bpy.data.filepath and Path(bpy.data.filepath).resolve() == Path(p0['file']).resolve():
        STATE.update(version=p0.get('version'), file=p0['file'], sha=sha(p0['file']))
    if _on_load not in bpy.app.handlers.load_post:
        bpy.app.handlers.load_post.append(_on_load)
    bpy.app.timers.register(tick, first_interval=1., persistent=True)
    print('[live viewer] watching', PTR)
