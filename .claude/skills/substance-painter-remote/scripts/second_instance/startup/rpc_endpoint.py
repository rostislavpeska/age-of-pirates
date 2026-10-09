"""Loopback scripting endpoint for a SECOND Painter instance (startup plugin).

Painter 9.1.2 hardcodes its own remote-scripting port (60041, bound on [::1]), which another person's or agent's
instance may own. This startup plugin is loaded only into the instance launched with SUBSTANCE_PAINTER_PLUGINS_PATH
pointing at the parent of this `startup/` folder (scripts/launch_second_instance.py) and serves the same protocol on
127.0.0.1:PAINTER_RPC_PORT (default 60042):

    POST /run.json  {"python": base64(expression)} -> JSON value of eval(expression)
                    {"js": base64(code)}           -> JSON value of substance_painter.js.evaluate(code)
    errors          {"error": {"description": traceback}}

It runs on Painter's main thread (Qt event loop), like the built-in server, so sp_remote.later() works unchanged.
"""
import base64
import json
import os
import traceback

try:
    from PySide6 import QtCore, QtNetwork
except ImportError:
    from PySide2 import QtCore, QtNetwork

PORT = int(os.environ.get('PAINTER_RPC_PORT', '60042'))
_server = None
_buffers = {}


def _evaluate(payload):
    if 'python' in payload:
        code = base64.b64decode(payload['python']).decode('utf-8')
        return eval(code, {'__name__': 'rpc_endpoint'})
    if 'js' in payload:
        import substance_painter.js
        return substance_painter.js.evaluate(base64.b64decode(payload['js']).decode('utf-8'))
    raise ValueError('expected a "python" or "js" field')


def _reply(sock, status, body):
    data = body.encode('utf-8')
    head = ('HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n'
            % (status, len(data))).encode('ascii')
    sock.write(head + data)
    sock.flush()
    sock.disconnectFromHost()


def _on_ready(sock):
    key = id(sock)
    _buffers[key] = _buffers.get(key, b'') + bytes(sock.readAll())
    raw = _buffers[key]
    if b'\r\n\r\n' not in raw:
        return
    head, body = raw.split(b'\r\n\r\n', 1)
    lines = head.decode('latin-1').split('\r\n')
    length = 0
    for line in lines[1:]:
        name, _, value = line.partition(':')
        if name.strip().lower() == 'content-length':
            length = int(value.strip())
    if len(body) < length:
        return
    _buffers.pop(key, None)
    request = lines[0].split(' ')
    if len(request) < 2 or request[0] != 'POST' or request[1] != '/run.json':
        _reply(sock, '404 Not Found', json.dumps({'error': {'description': 'POST /run.json only'}}))
        return
    try:
        result = json.dumps(_evaluate(json.loads(body[:length].decode('utf-8'))))
    except Exception:
        result = json.dumps({'error': {'description': traceback.format_exc()}})
    _reply(sock, '200 OK', result)


def _on_connection():
    while _server.hasPendingConnections():
        sock = _server.nextPendingConnection()
        sock.readyRead.connect(lambda s=sock: _on_ready(s))
        sock.disconnected.connect(lambda s=sock: (_buffers.pop(id(s), None), s.deleteLater()))


def start_plugin():
    global _server
    _server = QtNetwork.QTcpServer()
    if not _server.listen(QtNetwork.QHostAddress('127.0.0.1'), PORT):
        print('rpc_endpoint: cannot listen on 127.0.0.1:%d - %s' % (PORT, _server.errorString()))
        _server = None
        return
    _server.newConnection.connect(_on_connection)
    print('rpc_endpoint: listening on 127.0.0.1:%d (pid %d)' % (PORT, os.getpid()))


def close_plugin():
    global _server
    if _server is not None:
        _server.close()
        _server = None
