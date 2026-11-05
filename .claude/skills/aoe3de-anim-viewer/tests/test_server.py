"""aoe3de-anim-viewer local server (scripts/server.py): static files, the token / Host / Origin guard, file writes
only into the output folder, events.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests -q

Synthetic and CI-safe: a server on 127.0.0.1 with a free port, a viewer folder and an output folder in pytest's temp
folder. Standard library only.
"""
import http.client
import json
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_common as C  # noqa: E402
from server import ViewerServer  # noqa: E402

BUNDLE = '0123456789abcdef'


@pytest.fixture
def srv(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    viewer = tmp_path / 'viewer'
    (viewer / 'm0').mkdir(parents=True)
    (viewer / 'm0' / 'index.html').write_text('<!doctype html><title>t</title>')
    (viewer / 'm0' / 'm0.js').write_text('export const x = 1;')
    (tmp_path / 'secret.txt').write_text('outside the root')
    bundles = tmp_path / 'bundles'
    (bundles / BUNDLE).mkdir(parents=True)
    (bundles / BUNDLE / 'manifest.json').write_text('{"schema": "aop-anim-viewer/bundle"}')
    s = ViewerServer(tmp_path / 'out', viewer_root=viewer, bundle_root=bundles, max_upload=1024).start()
    yield s
    s.stop()


def req(s, method, path, body=None, headers=None, token=True, host=None):
    c = http.client.HTTPConnection('127.0.0.1', s.port, timeout=10)
    h = {'Host': host or '127.0.0.1:%d' % s.port}
    if token:
        h['X-AV-Token'] = s.token if token is True else token
    h.update(headers or {})
    if body is not None and not isinstance(body, bytes):
        body = json.dumps(body).encode('utf-8')
        h.setdefault('Content-Type', 'application/json')
    c.request(method, path, body=body, headers=h)
    r = c.getresponse()
    data = r.read()
    c.close()
    return r.status, r.getheader('Content-Type'), data


def test_static_files_and_module_mime(srv):
    st, ct, data = req(srv, 'GET', '/viewer/m0/m0.js', token=False)
    assert st == 200 and ct.startswith('text/javascript') and data == b'export const x = 1;'
    st, ct, _ = req(srv, 'GET', '/viewer/m0/index.html', token=False)
    assert st == 200 and ct.startswith('text/html')
    assert req(srv, 'GET', '/viewer/m0/absent.js', token=False)[0] == 404
    assert req(srv, 'GET', '/api/ping', token=False)[2] == b'{"ok": true}'


@pytest.mark.parametrize('path', ['/viewer/../secret.txt', '/viewer/m0/%2e%2e/%2e%2e/secret.txt',
                                  '/viewer/m0/..%5c..%5csecret.txt', '/viewer//etc', '/viewer/C:/x'])
def test_traversal_is_refused(srv, path):
    st, _, data = req(srv, 'GET', path, token=False)
    assert st in (400, 404) and b'outside the root' not in data


def test_bundles_are_served_by_id_only(srv):
    st, _, data = req(srv, 'GET', '/bundle/%s/manifest.json' % BUNDLE, token=False)
    assert st == 200 and b'aop-anim-viewer/bundle' in data
    assert req(srv, 'GET', '/bundle/NOT-AN-ID/manifest.json', token=False)[0] == 404


def test_host_origin_and_token_guard(srv):
    assert req(srv, 'GET', '/viewer/m0/m0.js', token=False, host='evil.example:80')[0] == 403
    assert req(srv, 'POST', '/api/log', {'msg': 'x'}, token=False)[0] == 403
    assert req(srv, 'POST', '/api/log', {'msg': 'x'}, token='wrong')[0] == 403
    assert req(srv, 'POST', '/api/log', {'msg': 'x'}, headers={'Origin': 'https://evil.example'})[0] == 403
    assert req(srv, 'OPTIONS', '/api/log', token=False)[0] == 403
    assert req(srv, 'POST', '/api/log', {'msg': 'x'}, token='caf\xe9')[0] == 403    # non-ASCII: refused, no crash
    whys = [e['data']['why'] for e in srv.events if e['kind'] == 'rejected']
    assert whys == ['host', 'token', 'token', 'origin', 'cors', 'token']
    assert not any(e['kind'] == 'server-error' for e in srv.events)
    assert not any(e['kind'] == 'log' for e in srv.events)
    assert req(srv, 'POST', '/api/log', {'msg': 'ok'}, headers={'Origin': 'http://127.0.0.1:%d' % srv.port})[0] == 200
    assert [e['data']['msg'] for e in srv.events if e['kind'] == 'log'] == ['ok']


def test_files_go_only_into_the_output_folder(srv, tmp_path):
    png = b'\x89PNG\r\n\x1a\n' + b'0' * 20
    st, _, data = req(srv, 'POST', '/api/file?name=m0_readback.png', png, {'Content-Type': 'image/png'})
    assert st == 200 and json.loads(data)['bytes'] == len(png)
    assert (srv.out_dir / 'm0_readback.png').read_bytes() == png and srv.files == ['m0_readback.png']
    for name in ('..%2Fescape.png', 'sub%2Fx.png', 'x.exe', '.hidden.png'):
        assert req(srv, 'POST', '/api/file?name=' + name, png)[0] == 400, name
    assert req(srv, 'POST', '/api/file?name=big.png', b'0' * 2048)[0] == 413
    assert sorted(p.name for p in srv.out_dir.iterdir()) == ['m0_readback.png']
    assert not (tmp_path / 'escape.png').exists()


def test_done_and_error_events_wake_the_waiter(srv):
    assert srv.wait_for(timeout=0.2) is None
    assert req(srv, 'POST', '/api/done', {'status': 'ok', 'n': 3})[0] == 200
    ev = srv.wait_for(timeout=5)
    assert ev['kind'] == 'done' and ev['data'] == {'status': 'ok', 'n': 3}
    assert req(srv, 'POST', '/api/error', {'msg': 'boom'})[0] == 200
    assert srv.wait_for(('error',), timeout=5)['data']['msg'] == 'boom'
    assert req(srv, 'POST', '/api/done', b'{not json', {'Content-Type': 'application/json'})[0] == 400
    assert srv.hits == 3                                          # three requests reached the server


def test_url_carries_the_token(srv):
    u = srv.url('/viewer/m0/index.html', test=1)
    assert u.startswith('http://127.0.0.1:%d/viewer/m0/index.html?token=' % srv.port) and u.endswith('&test=1')
    assert srv.token in u and len(srv.token) >= 24


def test_an_output_folder_in_a_repo_is_refused(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    (tmp_path / 'repo' / '.git').mkdir(parents=True)
    with pytest.raises(C.RepoPathError):
        ViewerServer(tmp_path / 'repo' / 'shots')
    assert not (tmp_path / 'repo' / 'shots').exists()


# ---------------------------------------------------------------- M2 API: units, bundles, build, export
class StubBackend:
    def __init__(self):
        self.built = []

    def units(self, q):
        names = ['ypIronFlail', 'ypIronFlailGuard', 'Hussar']
        hits = [n for n in names if q.lower() in n.lower()]
        return {'units': [{'name': n} for n in hits], 'truncated': False, 'total': len(hits)}

    def build(self, proto=None, animfile=None):
        if proto == 'Nope':
            raise LookupError('proto Nope not found')
        self.built.append(proto or animfile)
        return {'bundle_id': BUNDLE, 'subject': {'proto': proto}}


@pytest.fixture
def api(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    bundles = tmp_path / 'bundles'
    (bundles / BUNDLE).mkdir(parents=True)
    (bundles / BUNDLE / 'manifest.json').write_text(json.dumps({
        'schema': 'aop-anim-viewer/bundle', 'bundle_id': BUNDLE, 'subject': {'proto': 'ypIronFlail'},
        'created': '2026-10-11T00:00:00Z', 'models': {'a': {}}, 'clips': {'x': {}, 'y': {}},
        'warnings': [{'code': 'anim-one-sided', 'path': 'p', 'message': 'm'}], 'buffers': [{'byteLength': 64}]}))
    s = ViewerServer(tmp_path / 'out', viewer_root=tmp_path, bundle_root=bundles, backend=StubBackend()).start()
    yield s
    s.stop()


def test_api_gets_need_the_token(api):
    for path in ('/api/units?q=iron', '/api/bundles', '/api/bundle/%s' % BUNDLE):
        assert req(api, 'GET', path, token=False)[0] == 403, path
        assert req(api, 'GET', path, token='wrong')[0] == 403, path
    assert req(api, 'GET', '/api/ping', token=False)[0] == 200


def test_units_bundles_and_summary(api):
    st, _, data = req(api, 'GET', '/api/units?q=iron')
    assert st == 200 and [u['name'] for u in json.loads(data)['units']] == ['ypIronFlail', 'ypIronFlailGuard']
    st, _, data = req(api, 'GET', '/api/bundles')
    assert st == 200 and [b['bundle_id'] for b in json.loads(data)['bundles']] == [BUNDLE]
    st, _, data = req(api, 'GET', '/api/bundle/%s' % BUNDLE)
    d = json.loads(data)
    assert st == 200 and d['counts']['clips'] == 2 and d['warnings'] == [{'code': 'anim-one-sided', 'path': 'p'}]
    assert req(api, 'GET', '/api/bundle/0000000000000000')[0] == 404
    assert req(api, 'GET', '/api/bundle/..%2f..%2fx')[0] == 404


def test_build_and_export(api):
    st, _, data = req(api, 'POST', '/api/build', {'proto': 'ypIronFlail'})
    assert st == 200 and json.loads(data)['bundle_id'] == BUNDLE and api.backend.built == ['ypIronFlail']
    assert req(api, 'POST', '/api/build', {'proto': 'Nope'})[0] == 404
    assert req(api, 'POST', '/api/build', {})[0] == 400
    assert req(api, 'POST', '/api/build', {'proto': 'x'}, token=False)[0] == 403
    png = b'\x89PNG\r\n\x1a\n' + b'1' * 10
    st, _, data = req(api, 'POST', '/api/export?name=ypIronFlail_Idle_v0_t0p000.png', png, {'Content-Type': 'image/png'})
    assert st == 200 and (api.out_dir / 'ypIronFlail_Idle_v0_t0p000.png').read_bytes() == png
    assert req(api, 'POST', '/api/export?name=notes.txt', b'x')[0] == 400            # PNG and JSON only
    assert [e['kind'] for e in api.events if e['kind'] in ('build', 'built', 'export')] == ['build', 'built', 'build',
                                                                                          'export']


def test_url_values_are_percent_encoded(api):
    u = api.url('/viewer/app/index.html', bundle=BUNDLE, job='{"frames": [{"name": "a b&c"}]}')
    assert '&job=%7B%22frames%22%3A%20%5B%7B%22name%22%3A%20%22a%20b%26c%22%7D%5D%7D' in u
