"""aoe3de-anim-viewer scripts/ui_shot.py without a browser: the stdlib WebSocket / DevTools client against a fake
DevTools endpoint (handshake, a ping, an unrelated event, a fragmented 100 KB reply with the 64-bit length form), the
DevToolsActivePort reader, the page-target lookup, and the refusals that happen before any browser starts.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_ui_shot.py -q          # CI-safe
"""
import base64
import hashlib
import json
import socket
import struct
import sys
import threading
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_common as C  # noqa: E402
import ui_shot as S  # noqa: E402

PNG = b'\x89PNG\r\n\x1a\n' + bytes(range(256)) * 400          # ~100 KB: the reply needs the 8-byte length form


def _frame(opcode, payload, fin=True):
    n = len(payload)
    b0 = (0x80 if fin else 0) | opcode
    if n < 126:
        hdr = bytes([b0, n])
    elif n < 65536:
        hdr = bytes([b0, 126]) + struct.pack('>H', n)
    else:
        hdr = bytes([b0, 127]) + struct.pack('>Q', n)
    return hdr + payload


def _read_frame(conn):
    def read(n):
        out = b''
        while len(out) < n:
            chunk = conn.recv(n - len(out))
            if not chunk:
                raise ConnectionError('closed')
            out += chunk
        return out
    b0, b1 = read(2)
    n = b1 & 0x7F
    if n == 126:
        n = struct.unpack('>H', read(2))[0]
    elif n == 127:
        n = struct.unpack('>Q', read(8))[0]
    assert b1 & 0x80, 'client frames must be masked (RFC 6455)'
    mask = read(4)
    data = bytes(b ^ mask[i & 3] for i, b in enumerate(read(n)))
    return b0 & 0x0F, data


class FakeDevTools:
    """one port that answers GET /json/list and the WebSocket upgrade of /devtools/page/X like Chrome does."""

    def __init__(self):
        self.srv = socket.socket()
        self.srv.bind(('127.0.0.1', 0))
        self.srv.listen(4)
        self.port = self.srv.getsockname()[1]
        self.log = []
        self.thread = threading.Thread(target=self.serve, daemon=True)
        self.thread.start()

    def serve(self):
        for _ in range(2):
            conn, _addr = self.srv.accept()
            with conn:
                req = b''
                while b'\r\n\r\n' not in req:
                    req += conn.recv(4096)
                line = req.split(b'\r\n')[0].decode()
                self.log.append(line)
                if line.startswith('GET /json/list'):
                    body = json.dumps([
                        {'type': 'service_worker', 'url': 'http://127.0.0.1/x', 'webSocketDebuggerUrl': 'ws://127.0.0.1:1/x'},
                        {'type': 'page', 'url': 'http://127.0.0.1:5/viewer/app/index.html?token=t',
                         'webSocketDebuggerUrl': 'ws://127.0.0.1:%d/devtools/page/ABC' % self.port}]).encode()
                    conn.sendall(b'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\n'
                                 b'Connection: close\r\n\r\n' % len(body) + body)
                    continue
                key = next(h.split(b':', 1)[1].strip() for h in req.split(b'\r\n') if h.lower().startswith(b'sec-websocket-key'))
                accept = base64.b64encode(hashlib.sha1(key + S.WS_GUID.encode()).digest())
                conn.sendall(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
                             b'Sec-WebSocket-Accept: ' + accept + b'\r\n\r\n')
                op, data = _read_frame(conn)
                msg = json.loads(data)
                self.log.append(msg)
                conn.sendall(_frame(0x9, b'hi'))                                   # a ping first
                op2, pong = _read_frame(conn)
                self.log.append(('pong', op2, pong))
                conn.sendall(_frame(0x1, json.dumps({'method': 'Page.frameNavigated', 'params': {}}).encode()))
                reply = json.dumps({'id': msg['id'], 'result': {'data': base64.b64encode(PNG).decode()}}).encode()
                half = len(reply) // 2
                conn.sendall(_frame(0x1, reply[:half], fin=False) + _frame(0x0, reply[half:], fin=True))
                try:
                    self.log.append(('close', _read_frame(conn)[0]))
                except (ConnectionError, OSError):
                    pass

    def close(self):
        self.srv.close()


def test_devtools_capture_against_a_fake_endpoint(tmp_path):
    fake = FakeDevTools()
    try:
        (tmp_path / S.DEVTOOLS_FILE).write_text('%d\n/devtools/browser/xyz\n' % fake.port, encoding='ascii')
        state = {'profile': tmp_path, 'devtools': None}
        png = S.capture_png(state)
        state['devtools'].close()
        fake.thread.join(5)
    finally:
        fake.close()
    assert png == PNG
    assert state['devtools_port'] == fake.port
    assert fake.log[0].startswith('GET /json/list')
    assert fake.log[1].startswith('GET /devtools/page/ABC')
    assert fake.log[2] == {'id': 1, 'method': 'Page.captureScreenshot',
                           'params': {'format': 'png', 'captureBeyondViewport': False}}
    assert fake.log[3] == ('pong', 0xA, b'hi')
    assert fake.log[4] == ('close', 0x8)


def test_devtools_port_and_target_errors(tmp_path):
    assert S.devtools_port(tmp_path, timeout=0.2) is None
    (tmp_path / S.DEVTOOLS_FILE).write_text('not a port\n', encoding='ascii')
    assert S.devtools_port(tmp_path, timeout=0.2) is None
    with pytest.raises(RuntimeError, match='DevTools did not start'):
        S.capture_png({'profile': tmp_path, 'devtools': None, 'port_timeout': 0.2})
    with pytest.raises(ValueError, match='127.0.0.1'):
        S.WebSocket('ws://example.com:9222/devtools/page/1')
    with pytest.raises(ValueError):
        S.WebSocket('http://127.0.0.1:9222/x')


def test_refusals_before_any_browser_starts(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    started = []
    monkeypatch.setattr(S.H, 'select_browsers', lambda *a, **k: started.append(1) or [])
    root = tmp_path / 'bundles'
    with pytest.raises(FileNotFoundError):
        S.run_ui_shots('0123456789abcdef', [{'name': 'x'}], bundle_root=root)
    C.write_json(root / '0123456789abcdef' / 'manifest.json', {'schema': C.SCHEMA_NAME})
    with pytest.raises(ValueError, match='unsafe'):
        S.run_ui_shots('0123456789abcdef', [{'name': '../escape'}], bundle_root=root)
    with pytest.raises(C.RepoPathError):
        S.run_ui_shots('0123456789abcdef', [{'name': 'ok'}], bundle_root=root, out_dir=HERE / 'no_images_here')
    assert not (HERE / 'no_images_here').exists()
    assert started == []
    rec = S.run_ui_shots('0123456789abcdef', [{'name': 'ok'}], bundle_root=root, out_dir=tmp_path / 'out', log=lambda m: None)
    assert rec['status'] == 'no-browser' and started == [1] and (tmp_path / 'out' / 'run.json').is_file()
