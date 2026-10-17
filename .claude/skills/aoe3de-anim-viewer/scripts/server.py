#!/usr/bin/env python
"""Local HTTP server of the animation viewer: standard library only, 127.0.0.1, a free port, a token per run.

    python server.py [--out DIR] [--port N] [--bundles DIR] [--bundle ID]   # prints the page URLs, serves until Ctrl+C
    (anim_viewer.py serve --proto NAME builds a bundle first and prints the viewer URL)

Routes (every request must name this server in Host: 127.0.0.1:<port> or localhost:<port>):
    GET  /viewer/<path>          static ES modules and pages from the skill's viewer/ folder
    GET  /bundle/<id>/<path>     a cached bundle (bundle-schema.md) from the bundle root, id = 16 hex digits
    GET  /api/ping               {"ok": true}
    GET  /api/units?q=<text>     proto names containing the text (protoy + every enabled mod's protomods)  [token]
    GET  /api/bundles            the cached bundles, newest first                                           [token]
    GET  /api/bundle/<id>        one bundle's summary: subject, created, counts, warnings                   [token]
    POST /api/build              JSON {proto} or {animfile} -> builds the bundle into the bundle root       [token]
    POST /api/log                JSON {level, msg}           -> event 'log'
    GET  /api/job                the job this server was started with (headless.py: a job too long for the URL)  [token]
    POST /api/file?name=<name>   raw body (png/json/txt/bin) -> written ONLY into the output folder, event 'file'
    POST /api/export?name=<name> raw body (png/json)         -> the same, event 'export' (the page's export button)
    POST /api/done               JSON result of a page run   -> event 'done'
    POST /api/error              JSON {msg, stack}           -> event 'error'
Every /api/ POST and every /api/ GET but ping needs the run token in the X-AV-Token header (the page reads it from its
own ?token= query); a request with a foreign Origin, a wrong Host or no token is refused with 403 and recorded as
event 'rejected'. A custom header forces a CORS preflight, which this server never grants, so other web pages the
owner opens can neither post here nor read the API. /api/build reads the game and the mods read-only and writes only
into the bundle root (av_common refuses a repository, an AoE3 profile or mods folder and the install).
The page reads a job either from its own ?job=<JSON> query or, when the query says job=@server, from GET /api/job:
a Windows command line holds at most 32767 characters, so headless.py hands a long job (a video's frame times) over
this route.

The output folder comes from av_common.output_dir: never inside a git work tree, an AoE3 profile or mods folder or the
install (AGENTS.md rules 3 and 8). headless.py drives a page through this server without any window.
"""
from __future__ import annotations

import argparse
import json
import re
import secrets
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, unquote, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent))
import av_common as C  # noqa: E402

CONTENT_TYPES = {
    '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8',
    '.css': 'text/css; charset=utf-8', '.png': 'image/png', '.bin': 'application/octet-stream',
    '.txt': 'text/plain; charset=utf-8', '.svg': 'image/svg+xml',
}
FILE_TYPES = ('.png', '.json', '.txt', '.bin')       # .bin: the export geometry dumps (M5)
EXPORT_TYPES = ('.png', '.json')
UNITS_LIMIT = 200
BUNDLE_ID = re.compile(r'^[0-9a-f]{16}$')
MAX_JSON = 8 << 20


class _HTTPServer(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):
        exc = sys.exc_info()[1]
        if isinstance(exc, (ConnectionResetError, ConnectionAbortedError, BrokenPipeError)):
            return                                              # the browser closed a keep-alive connection
        self.viewer.event('server-error', {'error': repr(exc)})


class Backend:
    """the data side of /api/units and /api/build, created lazily: a cached VFS for the proto list, a fresh one per
    build (a VFS accumulates provenance and warnings, which must not leak from one bundle into the next)."""

    def __init__(self, bundle_root, log=None, fs_factory=None):
        self.bundle_root = Path(bundle_root)
        self.log = log or (lambda msg: None)
        self.fs_factory = fs_factory
        self._names = None
        self._lock = threading.Lock()

    def _fs(self):
        if self.fs_factory:
            return self.fs_factory()
        import vfs as V
        return V.VFS()

    def names(self):
        with self._lock:
            if self._names is None:
                import proto_resolve as P
                db = P.protodb(self._fs())
                names = {key: P._name(el) for key, el in db.units.items()}
                for _vf, idx in db._mod_units:
                    for key, els in idx.items():
                        names.setdefault(key, P._name(els[0]))
                self._names = sorted(names.values(), key=str.lower)
            return self._names

    def units(self, q, limit=UNITS_LIMIT):
        q = (q or '').strip().lower()
        hits = [n for n in self.names() if q in n.lower()]
        return {'units': [{'name': n} for n in hits[:limit]], 'truncated': len(hits) > limit, 'total': len(hits)}

    def build(self, proto=None, animfile=None):
        import bundle as B
        with self._lock:
            res = B.build_bundle(proto=proto, animfile=animfile, fs=self._fs(), out_root=self.bundle_root,
                                 log=self.log)
        return res.summary()


def bundle_summary(folder):
    """{bundle_id, subject, created, counts, warnings, fidelity, bytes} of a bundle folder, None without a manifest."""
    m = Path(folder) / 'manifest.json'
    if not m.is_file():
        return None
    d = C.read_json(m)
    return {'bundle_id': d.get('bundle_id'), 'subject': d.get('subject'), 'created': d.get('created'),
            'counts': {k: len(d.get(k) or {}) for k in ('animfiles', 'models', 'clips', 'materials', 'textures')},
            'warnings': [{'code': w.get('code'), 'path': w.get('path')} for w in d.get('warnings', [])],
            'fidelity': d.get('fidelity'), 'bytes': sum(b.get('byteLength', 0) for b in d.get('buffers', []))}


class ViewerServer:
    """ThreadingHTTPServer on 127.0.0.1 in a daemon thread. events: list of {kind, t, data}; wait_for() blocks until an
    event of the given kinds arrives; files: names written into out_dir. backend: a Backend for /api/units and
    /api/build (None: those answer 501)."""

    def __init__(self, out_dir=None, viewer_root=C.VIEWER_DIR, bundle_root=None, token=None, port=0,
                 max_upload=64 << 20, on_event=None, backend=None, job=None):
        self.out_dir = C.output_dir(out_dir, 'serve')            # refused before anything is served
        self.viewer_root = Path(viewer_root).resolve()
        self.bundle_root = Path(bundle_root).resolve() if bundle_root else None
        self.backend = backend
        self.job = job                                           # served by GET /api/job (None: 404)
        self.token = token or secrets.token_urlsafe(24)
        self.max_upload = max_upload
        self.on_event = on_event
        self.events, self.files = [], []
        self.hits = 0
        self._cond = threading.Condition()
        self._t0 = time.monotonic()
        self.httpd = _HTTPServer(('127.0.0.1', port), _Handler)
        self.httpd.viewer = self
        self.port = self.httpd.server_address[1]
        self.origins = {'http://127.0.0.1:%d' % self.port, 'http://localhost:%d' % self.port}
        self.hosts = {'127.0.0.1:%d' % self.port, 'localhost:%d' % self.port}
        self._thread = None

    # ---------------------------------------------------------------- lifecycle
    def start(self):
        self._thread = threading.Thread(target=self.httpd.serve_forever, name='av-server', daemon=True)
        self._thread.start()
        return self

    def stop(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        if self._thread:
            self._thread.join(5)

    def __enter__(self):
        return self.start()

    def __exit__(self, *exc):
        self.stop()

    def url(self, path='/', **query) -> str:
        """http://127.0.0.1:<port><path>?token=<token>&<query> (values percent-encoded)"""
        q = '&'.join('%s=%s' % (k, quote(str(v), safe='-_.~')) for k, v in {'token': self.token, **query}.items())
        return 'http://127.0.0.1:%d%s?%s' % (self.port, path, q)

    # ---------------------------------------------------------------- events
    def event(self, kind, data=None):
        ev = {'kind': kind, 't': round(time.monotonic() - self._t0, 3), 'data': data}
        with self._cond:
            self.events.append(ev)
            self._cond.notify_all()
        if self.on_event:
            try:
                self.on_event(ev)
            except Exception:                                  # a logging callback never breaks the server
                pass
        return ev

    def wait_for(self, kinds=('done', 'error'), timeout=60.0, start=0):
        """the first event of `kinds` at index >= start, or None after `timeout` seconds."""
        deadline = time.monotonic() + timeout
        with self._cond:
            while True:
                for ev in self.events[start:]:
                    if ev['kind'] in kinds:
                        return ev
                left = deadline - time.monotonic()
                if left <= 0:
                    return None
                self._cond.wait(min(left, 0.5))

    def write_file(self, name, data) -> Path:
        name = C.safe_name(name, FILE_TYPES)
        p = C.write_bytes(self.out_dir / name, data, 'a page export')
        self.files.append(name)
        return p


def _safe_rel(rel):
    """a relative URL path below a root: no '..', no backslash, no drive or absolute part; None when unsafe."""
    rel = unquote(rel)
    if not rel or chr(92) in rel or ':' in rel or rel.startswith('/'):
        return None
    parts = rel.split('/')
    if any(p in ('', '.', '..') for p in parts):
        return None
    return parts


class _Handler(BaseHTTPRequestHandler):
    server_version = 'aop-anim-viewer/' + C.TOOL_VERSION
    protocol_version = 'HTTP/1.1'

    @property
    def v(self) -> ViewerServer:
        return self.server.viewer

    def log_message(self, fmt, *args):                          # no stderr noise; rejected requests become events
        pass

    # ---------------------------------------------------------------- replies
    def _send(self, code, body=b'', ctype='application/json; charset=utf-8'):
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode('utf-8')
        elif isinstance(body, str):
            body = body.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Cross-Origin-Resource-Policy', 'same-origin')
        if self.close_connection:
            self.send_header('Connection', 'close')
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(body)

    def _reject(self, code, why):
        self.v.event('rejected', {'method': self.command, 'path': urlsplit(self.path).path, 'why': why})
        self._discard()
        self.close_connection = True                            # an unread request body must not reach the next request
        self._send(code, {'ok': False, 'error': why})

    def _discard(self, cap=16 << 20):
        """read and drop an unread request body (up to `cap` bytes) so the client gets the reply, not a reset."""
        if self.command not in ('POST', 'PUT') or getattr(self, '_body_read', False):
            return
        self._body_read = True
        try:
            left = min(int(self.headers.get('Content-Length', '0')), cap)
        except ValueError:
            return
        while left > 0:
            chunk = self.rfile.read(min(left, 1 << 16))
            if not chunk:
                break
            left -= len(chunk)

    def _host_ok(self):
        self.v.hits += 1                                        # any contact: headless.py tells a handoff from a slow page
        if self.headers.get('Host') not in self.v.hosts:
            self._reject(403, 'host')
            return False
        origin = self.headers.get('Origin')
        if origin is not None and origin not in self.v.origins:
            self._reject(403, 'origin')
            return False
        return True

    def _token_ok(self):
        sent = self.headers.get('X-AV-Token') or ''
        # bytes: compare_digest raises TypeError on a str with non-ASCII characters (a header is decoded as latin-1)
        if not secrets.compare_digest(sent.encode('utf-8', 'surrogateescape'), self.v.token.encode('utf-8')):
            self._reject(403, 'token')
            return False
        return True

    def _body(self, limit):
        try:
            n = int(self.headers.get('Content-Length', ''))
        except ValueError:
            self._reject(411, 'length required')
            return None
        if n < 0 or n > limit:
            self._reject(413, 'too large')
            return None
        self._body_read = True
        return self.rfile.read(n)

    # ---------------------------------------------------------------- verbs
    def do_OPTIONS(self):                                       # never grant a CORS preflight
        self._body_read = False
        self._reject(403, 'cors')

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        self._body_read = False
        if not self._host_ok():
            return
        url = urlsplit(self.path)
        path = url.path
        if path == '/api/ping':
            return self._send(200, {'ok': True})
        if path.startswith('/api/'):
            if not self._token_ok():
                return
            return self._api_get(path, parse_qs(url.query))
        if path.startswith('/viewer/'):
            return self._static(self.v.viewer_root, path[len('/viewer/'):])
        if path.startswith('/bundle/') and self.v.bundle_root:
            rest = path[len('/bundle/'):]
            bid, _, rel = rest.partition('/')
            if BUNDLE_ID.match(bid):
                return self._static(self.v.bundle_root / bid, rel)
        self._send(404, {'ok': False, 'error': 'not found'})

    def _api_get(self, path, query):
        if path == '/api/job':
            return self._send(200, self.v.job) if self.v.job is not None else                 self._send(404, {'ok': False, 'error': 'no job on this server'})
        if path == '/api/bundles':
            if not self.v.bundle_root:
                return self._send(200, {'bundles': []})
            import bundle as B
            return self._send(200, {'bundles': B.list_bundles(self.v.bundle_root)})
        if path.startswith('/api/bundle/'):
            bid = path[len('/api/bundle/'):]
            s = bundle_summary(self.v.bundle_root / bid) if self.v.bundle_root and BUNDLE_ID.match(bid) else None
            return self._send(200, s) if s else self._send(404, {'ok': False, 'error': 'no such bundle'})
        if path == '/api/units':
            if self.v.backend is None:
                return self._send(501, {'ok': False, 'error': 'no backend on this server'})
            try:
                return self._send(200, self.v.backend.units((query.get('q') or [''])[0]))
            except Exception as e:                              # noqa: BLE001 - reported to the page
                return self._send(500, {'ok': False, 'error': '%s: %s' % (type(e).__name__, e)})
        return self._send(404, {'ok': False, 'error': 'not found'})

    def _static(self, root, rel):
        parts = _safe_rel(rel)
        if parts is None:
            return self._reject(400, 'bad path')
        p = Path(root).joinpath(*parts)
        try:
            p.resolve().relative_to(Path(root).resolve())
        except ValueError:
            return self._reject(400, 'outside root')
        if not p.is_file():
            return self._send(404, {'ok': False, 'error': 'not found'})
        self._send(200, p.read_bytes(), CONTENT_TYPES.get(p.suffix.lower(), 'application/octet-stream'))

    def do_POST(self):
        self._body_read = False
        if not self._host_ok() or not self._token_ok():
            return
        url = urlsplit(self.path)
        if url.path in ('/api/file', '/api/export'):
            types = FILE_TYPES if url.path == '/api/file' else EXPORT_TYPES
            name = (parse_qs(url.query).get('name') or [''])[0]
            try:
                C.safe_name(name, types)
            except ValueError as e:
                return self._reject(400, str(e))
            body = self._body(self.v.max_upload)
            if body is None:
                return
            try:
                self.v.write_file(name, body)
            except (ValueError, OSError) as e:
                return self._reject(500, 'write failed: %s' % e)
            self.v.event('file' if url.path == '/api/file' else 'export', {'name': name, 'bytes': len(body)})
            return self._send(200, {'ok': True, 'name': name, 'bytes': len(body)})
        if url.path == '/api/build':
            return self._build()
        kind = {'/api/log': 'log', '/api/done': 'done', '/api/error': 'error'}.get(url.path)
        if kind is None:
            return self._send(404, {'ok': False, 'error': 'not found'})
        body = self._body(MAX_JSON)
        if body is None:
            return
        try:
            data = json.loads(body.decode('utf-8')) if body else None
        except (ValueError, UnicodeError):
            return self._reject(400, 'bad json')
        self.v.event(kind, data)
        self._send(200, {'ok': True})

    def _build(self):
        body = self._body(MAX_JSON)
        if body is None:
            return
        try:
            req = json.loads(body.decode('utf-8')) if body else {}
        except (ValueError, UnicodeError):
            return self._reject(400, 'bad json')
        if self.v.backend is None or not self.v.bundle_root:
            return self._send(501, {'ok': False, 'error': 'no backend on this server'})
        proto, animfile = req.get('proto'), req.get('animfile')
        if not (isinstance(proto, str) and proto) and not (isinstance(animfile, str) and animfile):
            return self._send(400, {'ok': False, 'error': 'proto or animfile needed'})
        self.v.event('build', {'proto': proto, 'animfile': animfile})
        try:
            s = self.v.backend.build(proto=proto or None, animfile=animfile or None)
        except (LookupError, ValueError) as e:                  # RepoPathError is a ValueError
            return self._send(404, {'ok': False, 'error': str(e)})
        except Exception as e:                                  # noqa: BLE001 - reported to the page
            self.v.event('build-error', {'error': repr(e)})
            return self._send(500, {'ok': False, 'error': '%s: %s' % (type(e).__name__, e)})
        self.v.event('built', {'bundle_id': s['bundle_id']})
        return self._send(200, dict(s, ok=True))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--out', help='output folder for page exports (default: a new folder in the cache)')
    ap.add_argument('--port', type=int, default=0, help='port (default: a free one)')
    ap.add_argument('--bundles', help='bundle cache root served under /bundle/ (default: the cache root)')
    ap.add_argument('--bundle', help='bundle id to open in the printed viewer URL')
    a = ap.parse_args(argv)
    root = a.bundles or C.cache_root()
    try:
        srv = ViewerServer(a.out, bundle_root=root, port=a.port, backend=Backend(root, log=print),
                           on_event=lambda ev: print('[%7.3f] %s %s' % (ev['t'], ev['kind'], json.dumps(ev['data'])[:300]),
                                                     flush=True))
    except C.RepoPathError as e:
        print(e, file=sys.stderr)
        return 2
    srv.start()
    print('output folder:', srv.out_dir)
    print('M0 spike page:', srv.url('/viewer/m0/index.html'))
    if a.bundle:
        print('viewer:', srv.url('/viewer/app/index.html', bundle=a.bundle))
    print('Ctrl+C stops the server.', flush=True)
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        srv.stop()
    return 0


if __name__ == '__main__':
    sys.exit(main())
