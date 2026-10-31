#!/usr/bin/env python
"""Full-UI screenshots of the viewer page (3D view, timeline dock, clip picker, data panels), headless: no window, no
screen, the owner's browser profile untouched.

    python ui_shot.py BUNDLE_ID --shot '{"name": "attack", "anim": "Attack_melee", "tag": "Attack", "tab": "timing",
                                         "tip": "Attack"}' [--shot ...] [--size 1600x1000] [--out DIR] [--timeout 120]
    python ui_shot.py --proto ypIronFlail --shot ...          # builds the bundle into the cache first

    import ui_shot as S
    rec = S.run_ui_shots(bundle_id, [{'name': 'attack', 'anim': 'Attack_melee', 'tag': 'Attack', 'tip': 'Attack'}])
    rec['shots']   # [{name, png, bytes}]      rec['result']  # the page's report (ui, checks)    rec['out_dir']

Shot keys (viewer/timeline/mount.js): name, anim, variant, sync (absolute|phase), action (a tactics action), trate
(the tactics-rate preset on/off), tag (pause at the first reached tag of that type) or time (s), tab (timing, clips,
bones, materials, provenance, audit, fidelity), tip (pin the tooltip of the first tag of that type).

How: server.py serves the viewer (127.0.0.1, a token per run) with ?test=1&uishot=<shots>. For each shot the page sets
the state, then posts 'uishot:<name>' to /api/log and waits for the reply; while that request is held this script
captures the page through the DevTools protocol (Page.captureScreenshot, a stdlib WebSocket client) and writes
<name>.png into the output folder, which av_common keeps outside every repository (AGENTS.md rules 3 and 8). After the
shots the page runs its interaction checks and posts 'done' with its report.

Browser: headless.py's choice and guards - Chrome unless --browser names another (Edge only when named, INC-237), a
pending update swap refused, --headless=new, a throwaway profile under <cache>/profiles, plus
--remote-debugging-port=0 (DevTools on 127.0.0.1 only, for this run's throwaway profile). At the end the browser's
process tree is ended, the profile deleted (holders reported if it cannot be), and same-name processes that appeared
during the run are reported (never ended: they may be the owner's).
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import socket
import struct
import subprocess
import sys
import time
import urllib.request
import uuid
from pathlib import Path
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent))
import av_common as C  # noqa: E402
import headless as H  # noqa: E402
from server import ViewerServer  # noqa: E402

DEVTOOLS_FILE = 'DevToolsActivePort'
WS_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
DEFAULT_SIZE = (1600, 1000)
PAGE = 'app/index.html'


# ---------------------------------------------------------------------------------------------------- DevTools
class WebSocket:
    """the client half of RFC 6455, enough for the DevTools protocol: text frames out (masked), text/binary frames in
    (fragmented or not), pings answered, a close frame raised."""

    def __init__(self, url, timeout=30.0):
        u = urlsplit(url)
        if u.scheme != 'ws' or u.hostname not in ('127.0.0.1', 'localhost'):
            raise ValueError('DevTools endpoint must be ws://127.0.0.1: %r' % url)
        self.sock = socket.create_connection((u.hostname, u.port), timeout=timeout)
        key = base64.b64encode(os.urandom(16)).decode('ascii')
        path = u.path + ('?' + u.query if u.query else '')
        self.sock.sendall(('GET %s HTTP/1.1\r\nHost: %s:%d\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
                           'Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n'
                           % (path, u.hostname, u.port, key)).encode('ascii'))
        head = bytearray()
        while b'\r\n\r\n' not in head:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError('websocket handshake: connection closed')
            head += chunk
        head, _, rest = bytes(head).partition(b'\r\n\r\n')
        self.buf = bytearray(rest)
        lines = head.decode('latin-1').split('\r\n')
        if len(lines[0].split()) < 2 or lines[0].split()[1] != '101':
            raise ConnectionError('websocket handshake refused: %s' % lines[0])
        hdrs = {k.strip().lower(): v.strip() for k, _, v in (ln.partition(':') for ln in lines[1:])}
        expect = base64.b64encode(hashlib.sha1((key + WS_GUID).encode('ascii')).digest()).decode('ascii')
        if hdrs.get('sec-websocket-accept') != expect:
            raise ConnectionError('websocket handshake: bad Sec-WebSocket-Accept')

    def _read(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(max(1 << 16, n - len(self.buf)))
            if not chunk:
                raise ConnectionError('websocket closed')
            self.buf += chunk
        out = bytes(self.buf[:n])
        del self.buf[:n]
        return out

    def _frame(self, opcode, data):
        n = len(data)
        hdr = bytearray([0x80 | opcode])
        if n < 126:
            hdr.append(0x80 | n)
        elif n < 65536:
            hdr.append(0x80 | 126)
            hdr += struct.pack('>H', n)
        else:
            hdr.append(0x80 | 127)
            hdr += struct.pack('>Q', n)
        mask = os.urandom(4)
        hdr += mask
        self.sock.sendall(bytes(hdr) + bytes(b ^ mask[i & 3] for i, b in enumerate(data)))

    def send_text(self, text):
        self._frame(0x1, text.encode('utf-8'))

    def recv_text(self):
        parts = []
        while True:
            b0, b1 = self._read(2)
            fin, op, n = b0 & 0x80, b0 & 0x0F, b1 & 0x7F
            if n == 126:
                n = struct.unpack('>H', self._read(2))[0]
            elif n == 127:
                n = struct.unpack('>Q', self._read(8))[0]
            mask = self._read(4) if b1 & 0x80 else None
            payload = self._read(n)
            if mask:
                payload = bytes(b ^ mask[i & 3] for i, b in enumerate(payload))
            if op == 0x8:
                raise ConnectionError('websocket closed by the browser')
            if op == 0x9:
                self._frame(0xA, payload)
                continue
            if op == 0xA:
                continue
            if op in (0x1, 0x2):
                parts = [payload]
            elif op == 0x0:
                parts.append(payload)
            if fin:
                return b''.join(parts).decode('utf-8')

    def close(self):
        try:
            self._frame(0x8, b'')
        except OSError:
            pass
        try:
            self.sock.close()
        except OSError:
            pass


class DevTools:
    """one page target of the browser this run started: call(method, params) -> result."""

    def __init__(self, ws_url, timeout=30.0):
        self.ws = WebSocket(ws_url, timeout)
        self.next_id = 0

    def call(self, method, params=None):
        self.next_id += 1
        mid = self.next_id
        self.ws.send_text(json.dumps({'id': mid, 'method': method, 'params': params or {}}))
        while True:
            msg = json.loads(self.ws.recv_text())
            if msg.get('id') == mid:
                if 'error' in msg:
                    raise RuntimeError('%s: %s' % (method, msg['error']))
                return msg.get('result') or {}

    def close(self):
        self.ws.close()


def devtools_port(profile, timeout=10.0):
    """the DevTools port Chrome wrote into the throwaway profile (--remote-debugging-port=0), or None."""
    p = Path(profile) / DEVTOOLS_FILE
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            first = p.read_text(encoding='ascii').splitlines()[0].strip()
            if first.isdigit():
                return int(first)
        except (OSError, IndexError, UnicodeError):
            pass
        time.sleep(0.1)
    return None


def page_target(port, match='/viewer/'):
    """the webSocketDebuggerUrl of the page whose URL contains `match` (no proxy for 127.0.0.1)."""
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open('http://127.0.0.1:%d/json/list' % port, timeout=10) as r:
        targets = json.loads(r.read().decode('utf-8'))
    for t in targets:
        if t.get('type') == 'page' and match in (t.get('url') or ''):
            return t['webSocketDebuggerUrl']
    raise LookupError('no page target with %r among %d target(s)' % (match, len(targets)))


def capture_png(state):
    """a PNG of the page as it is drawn now (the viewport), through a DevTools session opened on first use."""
    if state.get('devtools') is None:
        port = devtools_port(state['profile'], state.get('port_timeout', 10.0))
        if port is None:
            raise RuntimeError('no %s in the throwaway profile: DevTools did not start' % DEVTOOLS_FILE)
        state['devtools'] = DevTools(page_target(port))
        state['devtools_port'] = port
    res = state['devtools'].call('Page.captureScreenshot', {'format': 'png', 'captureBeyondViewport': False})
    return base64.b64decode(res['data'])


# ---------------------------------------------------------------------------------------------------- the run
def run_ui_shots(bundle_id, shots, *, out_dir=None, bundle_root=None, browser=None, gpu='auto', size=DEFAULT_SIZE,
                 timeout=120.0, log=print, label='uishot'):
    """capture each shot of the viewer UI; returns the run record (also written as run.json): {status: done|error|
    timeout|browser-exited|browser-handoff|refused|no-browser, shots [{name, png, bytes}], shot_errors, result (the
    page's 'done' JSON), out_dir, browser, elapsed_s, files, profile_deleted, profile_holders, leftover_processes,
    foreign_processes, rejected, events}"""
    root = Path(bundle_root) if bundle_root else C.cache_root()
    if not (root / bundle_id / 'manifest.json').is_file():
        raise FileNotFoundError('no bundle %s under %s: build it first (anim_viewer.py build)' % (bundle_id, root))
    shots = [dict(s) for s in shots]
    for i, s in enumerate(shots):
        s.setdefault('name', 'ui%d' % i)
        C.safe_name(s['name'] + '.png', ('.png',))                 # refused before anything starts
    out = C.output_dir(out_dir, label)
    rec = {'status': 'no-browser', 'browser': None, 'gpu_mode': gpu, 'page': PAGE, 'out_dir': str(out), 'size': list(size),
           'bundle_id': bundle_id, 'shots': [], 'shot_errors': [], 'result': None, 'error': None, 'files': [],
           'elapsed_s': 0.0, 'browser_log': None, 'rejected': [], 'foreign_processes': [], 'leftover_processes': [],
           'profile': None, 'profile_deleted': None, 'profile_holders': []}
    browsers = H.select_browsers(browser)
    if not browsers:
        log('no browser selected: Chrome from config tools.chrome.path or PATH, %s, or --browser' % H.BROWSER_ENV)
        C.write_json(out / 'run.json', rec)
        return rec
    b = browsers[0]
    rec['browser'] = b
    why = H.pending_update(b['path'])
    if why:
        rec.update(status='refused', error=why)
        log('refused %s: %s' % (b['name'], why))
        C.write_json(out / 'run.json', rec)
        return rec
    before = H.same_name_pids(b['path'])
    run_id = '%s-%s' % (time.strftime('%Y%m%d-%H%M%S'), uuid.uuid4().hex[:8])
    prof = H.profile_dir(run_id)
    state = {'profile': prof, 'devtools': None, 'srv': None}
    printer = H._printer(log)
    t0 = time.monotonic()

    def on_event(ev):
        if ev['kind'] != 'log' or (ev['data'] or {}).get('level') != 'uishot':
            printer(ev)
            return
        name = str((ev['data'] or {}).get('msg', ''))[len('uishot:'):] or 'ui'
        try:
            png = capture_png(state)
            p = state['srv'].write_file(name + '.png', png)
            rec['shots'].append({'name': name, 'png': str(p), 'bytes': len(png)})
            log('[%7.3f] shot %s: %d bytes -> %s' % (ev['t'], name, len(png), p))
        except Exception as e:                                  # noqa: BLE001 - reported in the run record
            rec['shot_errors'].append({'name': name, 'error': '%s: %s' % (type(e).__name__, e)})
            log('[%7.3f] shot %s FAILED: %s: %s' % (ev['t'], name, type(e).__name__, e))

    srv = ViewerServer(out, bundle_root=root, on_event=on_event).start()
    state['srv'] = srv
    url = srv.url('/viewer/' + PAGE, test=1, bundle=bundle_id, uishot=json.dumps(shots, separators=(',', ':')))
    cmd = H.browser_command(b['path'], url, prof, gpu, size)
    cmd.insert(len(cmd) - 1, '--remote-debugging-port=0')       # DevTools on 127.0.0.1, this throwaway profile only
    blog = out / 'browser.log'
    rec['browser_log'] = str(blog)
    log('start %s (%s, gpu %s) for %d shot(s), %dx%d, timeout %ss' % (b['name'], b['path'], gpu, len(shots), size[0],
                                                                    size[1], timeout))
    kw = {'creationflags': 0x08000000} if os.name == 'nt' else {'start_new_session': True}   # CREATE_NO_WINDOW
    proc = None
    try:
        with open(blog, 'wb') as lf:
            proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=lf, stderr=subprocess.STDOUT, **kw)
            ev = None
            while ev is None:
                ev = srv.wait_for(('done', 'error'), timeout=0.5)
                if ev is not None:
                    break
                if proc.poll() is not None:
                    quick = time.monotonic() - t0 < H.HANDOFF_WINDOW and srv.hits == 0
                    rec['status'] = 'browser-handoff' if quick else 'browser-exited'
                    rec['error'] = ('the launcher exited (code %s) after %.1f s without loading the page: it may have '
                                    'handed the start to another browser instance, possibly a VISIBLE window on the '
                                    "owner's own profile. Report it." % (proc.returncode, time.monotonic() - t0)) \
                        if quick else 'browser exited with code %s before the page reported' % proc.returncode
                    break
                if time.monotonic() - t0 > timeout:
                    rec['status'] = 'timeout'
                    rec['error'] = 'no result after %ss' % timeout
                    break
            if ev is not None:
                rec['status'] = ev['kind']
                if ev['kind'] == 'done':
                    rec['result'] = ev['data']
                else:
                    rec['error'] = ev['data']
    finally:
        if state.get('devtools') is not None:
            state['devtools'].close()
        if proc is not None:
            H.kill_tree(proc)
        srv.stop()
        rec['profile'] = str(prof)
        rec['profile_deleted'] = H._rmtree_retry(prof)
        if not rec['profile_deleted']:
            holders = H.profile_holders(prof)
            rec['profile_holders'] = holders or []
            log('WARNING: the throwaway profile %s was NOT deleted%s' % (
                prof, ': still held by %s - a browser this run started is still running (not ended here)'
                % ', '.join('%s (pid %d)' % (x['app'], x['pid']) for x in holders) if holders else ' (holders unknown)'))
    after = H.same_name_pids(b['path'])
    if before is not None and after is not None:
        new = sorted(after - before - {proc.pid if proc else -1})
        if rec['status'] == 'browser-handoff':
            rec['foreign_processes'] = new
        else:                                   # children of a browser running before this run are the owner's
            new, rec['owner_children'] = H.classify_appeared(new, before, H.parent_pids(new))
            rec['leftover_processes'] = new
        if new:
            log('WARNING: %d %s process(es) appeared during the run and are still running: %s (left alone)'
                % (len(new), Path(b['path']).name, new))
    rec['elapsed_s'] = round(time.monotonic() - t0, 2)
    rec['files'] = list(srv.files)
    rec['rejected'] = [e['data'] for e in srv.events if e['kind'] == 'rejected']
    rec['events'] = [{'kind': e['kind'], 't': e['t'], 'data': e['data']} for e in srv.events
                     if e['kind'] in ('log', 'file', 'error', 'rejected')]
    C.write_json(out / 'run.json', rec)
    log('end: %s after %.1f s, %d shot(s) in %s' % (rec['status'], rec['elapsed_s'], len(rec['shots']), out))
    return rec


def _size(text):
    w, _, h = text.lower().partition('x')
    return int(w), int(h)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('bundle_id', nargs='?', help='a cached bundle (anim_viewer.py build prints its id)')
    ap.add_argument('--proto', help='build (or rebuild) the bundle of this proto first')
    ap.add_argument('--shot', action='append', default=[], help='one shot as JSON (repeatable; module docstring)')
    ap.add_argument('--size', default='%dx%d' % DEFAULT_SIZE, help='viewport WxH (default %dx%d)' % DEFAULT_SIZE)
    ap.add_argument('--out', help='output folder (default: a new folder in the cache; a repository is refused)')
    ap.add_argument('--gpu', default='auto', choices=H.GPU_MODES)
    ap.add_argument('--browser', help='chrome (the default), edge (only when named: INC-237) or a browser path')
    ap.add_argument('--timeout', type=float, default=120.0)
    a = ap.parse_args(argv)
    bid = a.bundle_id
    if a.proto:
        import bundle as B
        bid = B.build_bundle(proto=a.proto).bundle_id
    if not bid:
        ap.error('a bundle id or --proto is needed')
    shots = [json.loads(s) for s in a.shot] or [{'name': 'ui'}]
    try:
        rec = run_ui_shots(bid, shots, out_dir=a.out, browser=a.browser, gpu=a.gpu, size=_size(a.size),
                           timeout=a.timeout)
    except (C.RepoPathError, FileNotFoundError, ValueError) as e:
        print(e, file=sys.stderr)
        return 2
    for s in rec['shots']:
        print('shot %-12s %s' % (s['name'], s['png']))
    for s in rec['shot_errors']:
        print('shot %-12s FAILED %s' % (s['name'], s['error']))
    return 0 if rec['status'] == 'done' and len(rec['shots']) == len(shots) else 1


if __name__ == '__main__':
    sys.exit(main())
