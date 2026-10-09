"""Launch an OWN, hidden second Painter instance with its own scripting endpoint (startup plugin, default port 60042).

Use when another Painter instance (the owner's, another agent's) already owns the built-in endpoint 60041 and its
project must not be touched. The new process gets SUBSTANCE_PAINTER_PLUGINS_PATH -> scripts/second_instance (its
startup/rpc_endpoint.py) for this process only and is started WITHOUT --enable-remote-scripting, hidden (no window,
no screen control). It refuses when the port already answers; it verifies the answering PID is the launched one.

    python launch_second_instance.py --report OUT.json [--port 60042] [--local-config tool-paths.local.json] [--timeout 180]

Then point the client at it:  PAINTER_HOST=127.0.0.1 PAINTER_PORT=<port> PAINTER_EXPECT_PID=<endpoint_pid>
(sp_remote reads them; LegacySession requires PAINTER_EXPECT_PID). Read references/second-instance-9.1.2.md.
"""
import argparse, base64, http.client, json, os, subprocess, sys, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
PLUGIN = HERE / 'second_instance'


def ask(expr, port, timeout=5):
    body = json.dumps({'python': base64.b64encode(expr.encode()).decode()})
    c = http.client.HTTPConnection('127.0.0.1', port, timeout=timeout)
    try:
        c.request('POST', '/run.json', body, {'Content-type': 'application/json'})
        return json.loads(c.getresponse().read().decode())
    finally:
        c.close()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--report', type=Path, required=True)
    ap.add_argument('--port', type=int, default=60042)
    ap.add_argument('--local-config')
    ap.add_argument('--timeout', type=float, default=180)
    a = ap.parse_args()
    if a.port == 60041:
        sys.exit('60041 is the built-in endpoint; choose another port')
    sys.path.insert(0, str(HERE))
    from painter_environment import settings
    exe = settings(a.local_config).get('path') or os.environ.get('PAINTER_EXECUTABLE')
    if not exe or not Path(exe).is_file():
        sys.exit('no Painter executable: set tools.substance-painter.path in the local config or PAINTER_EXECUTABLE')
    try:
        ask('1', a.port)
        sys.exit(f'port {a.port} already answers; refusing a second launch')
    except OSError:
        pass
    env = dict(os.environ)
    prior = env.get('SUBSTANCE_PAINTER_PLUGINS_PATH')
    env['SUBSTANCE_PAINTER_PLUGINS_PATH'] = str(PLUGIN) + (os.pathsep + prior if prior else '')
    env['PAINTER_RPC_PORT'] = str(a.port)
    si = None
    if os.name == 'nt':
        si = subprocess.STARTUPINFO(); si.dwFlags |= subprocess.STARTF_USESHOWWINDOW; si.wShowWindow = 0
    proc = subprocess.Popen([exe], env=env, startupinfo=si)
    t0 = time.monotonic()
    while time.monotonic() - t0 < a.timeout:
        if proc.poll() is not None:
            sys.exit(f'Painter exited during startup (code {proc.returncode}); read its log before another launch')
        try:
            pid = ask('__import__("os").getpid()', a.port)
            break
        except OSError:
            time.sleep(2)
    else:
        sys.exit(f'no answer on {a.port} after {a.timeout:.0f} s (pid {proc.pid} still running: inspect, do not relaunch)')
    report = {'launched_pid': proc.pid, 'endpoint_pid': pid, 'port': a.port, 'hidden': os.name == 'nt',
              'seconds_to_endpoint': round(time.monotonic() - t0, 1),
              'project_open': ask('__import__("substance_painter.project").project.is_open()', a.port),
              'python_api': ask('__import__("substance_painter").__version__', a.port)}
    a.report.parent.mkdir(parents=True, exist_ok=True)
    a.report.write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))
    if pid != proc.pid:
        sys.exit(f'endpoint PID {pid} differs from the launched PID {proc.pid}')


if __name__ == '__main__':
    main()
