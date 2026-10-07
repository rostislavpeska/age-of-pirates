"""Device-local Painter discovery. Never stores an installation path in shared code.

python painter_environment.py --local-config config/tool-paths.local.json [--start]
Read-only by default. --start is for an operator-authorized launch, never a restart.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time


def config_path(explicit=None):
    value = explicit or os.environ.get('PAINTER_LOCAL_CONFIG')
    if value:
        path = Path(value).expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError('Local tool configuration does not exist: ' + str(path))
        return path
    # Works in an AoP checkout; exported skills may pass their own local file.
    for root in [Path.cwd(), *Path(__file__).resolve().parents]:
        path = root / 'config' / 'tool-paths.local.json'
        if path.is_file():
            return path
    return None


def settings(explicit=None):
    path = config_path(explicit)
    data = json.loads(path.read_text(encoding='utf-8-sig')) if path else {}
    result = dict(data.get('tools', {}).get('substance-painter', {}))
    for key, variable in [('path', 'PAINTER_EXECUTABLE'), ('host', 'PAINTER_HOST'), ('port', 'PAINTER_PORT')]:
        if os.environ.get(variable):
            result[key] = os.environ[variable]
    result['host'] = result.get('host') or 'localhost'
    result['port'] = int(result.get('port') or 60041)
    if result['host'] not in ('localhost', '127.0.0.1', '::1'):
        raise ValueError('Painter scripting is restricted to a loopback endpoint')
    if not 1 <= result['port'] <= 65535:
        raise ValueError('Painter port must be in 1..65535')
    result['config'] = str(path) if path else None
    return result


def windows_processes():
    if os.name != 'nt':
        return []
    script = "@(Get-CimInstance Win32_Process -Filter \"Name='Adobe Substance 3D Painter.exe' OR Name='Substance 3D Painter.exe' OR Name='Substance Painter.exe'\" | ForEach-Object { $p=Get-Process -Id $_.ProcessId -ErrorAction Stop; [pscustomobject]@{ProcessId=$_.ProcessId;ExecutablePath=$_.ExecutablePath;CommandLine=$_.CommandLine;MainWindowHandle=$p.MainWindowHandle.ToInt64();MainWindowTitle=$p.MainWindowTitle} }) | ConvertTo-Json -Compress"
    result = subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', script],
                            capture_output=True, text=True, check=True, timeout=15)
    data = json.loads(result.stdout) if result.stdout.strip() else []
    data = data if isinstance(data, list) else [data]
    import ctypes
    visible = ctypes.windll.user32.IsWindowVisible
    visible.argtypes = [ctypes.c_void_p]
    visible.restype = ctypes.c_int
    for process in data:
        process['WindowVisible'] = bool(visible(process.get('MainWindowHandle', 0)))
    return data


def registry_candidates():
    if os.name != 'nt':
        return []
    import winreg
    found = set()
    for hive in (winreg.HKEY_CURRENT_USER, winreg.HKEY_LOCAL_MACHINE):
        for view in (winreg.KEY_WOW64_64KEY, winreg.KEY_WOW64_32KEY):
            try:
                with winreg.OpenKey(hive, r'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 0, winreg.KEY_READ | view) as key:
                    for i in range(winreg.QueryInfoKey(key)[0]):
                        with winreg.OpenKey(key, winreg.EnumKey(key, i)) as entry:
                            try:
                                name = winreg.QueryValueEx(entry, 'DisplayName')[0]
                                if 'painter' not in name.lower() or 'substance' not in name.lower():
                                    continue
                                location = Path(winreg.QueryValueEx(entry, 'InstallLocation')[0])
                            except OSError:
                                continue
                            for exe in ('Adobe Substance 3D Painter.exe', 'Substance 3D Painter.exe', 'Substance Painter.exe'):
                                path = location / exe
                                if path.is_file():
                                    found.add(str(path.resolve()))
            except OSError:
                continue
    return sorted(found)


def resolve_executable(config, running=None, candidates=None):
    explicit = config.get('path')
    if explicit:
        path = Path(os.path.expandvars(explicit)).expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError('Configured Painter path is stale; update this device\'s local configuration: ' + str(path))
        return path
    running = windows_processes() if running is None else running
    observed = {p['ExecutablePath'] for p in running if p.get('ExecutablePath')}
    if not observed:
        observed = set(registry_candidates() if candidates is None else candidates)
    paths = {Path(p).resolve() for p in observed if Path(p).is_file()}
    if len(paths) != 1:
        raise RuntimeError('Need one verified Painter installation; set tools.substance-painter.path locally. Candidates: ' + str(sorted(map(str, paths))))
    return paths.pop()


def capabilities():
    import sp_remote as sp
    version = sp.check()
    if not version:
        return {'reachable': False, 'endpoint': [sp.HOST, sp.PORT]}
    source = '''import os, sys, pkgutil, importlib.util
import substance_painter as s
import substance_painter.project as p
modules = [m.name for m in pkgutil.iter_modules(s.__path__)]
layer_commands = []
if 'layerstack' in modules:
    import substance_painter.layerstack as ls
    layer_commands = [n for n in ('insert_fill','insert_generator_effect','insert_group','get_root_layer_nodes','InsertPosition') if hasattr(ls,n)]
RESULT = {'pid':os.getpid(), 'executable':sys.executable, 'api_version':getattr(s,'__version__',None),
          'modules':modules, 'layer_commands':layer_commands,
          'qt6':importlib.util.find_spec('PySide6') is not None,
          'qt5':importlib.util.find_spec('PySide2') is not None,
          'project_open':p.is_open(), 'project_path':p.file_path() if p.is_open() else None,
          'busy':p.is_busy()}
'''
    result = sp.py(source, timeout=15, operation='painter.capabilities', mutating=False)
    result.update(reachable=True, painter_version=version, endpoint=[sp.HOST, sp.PORT])
    result['public_layer_editing'] = all(n in result['layer_commands'] for n in ('insert_fill','get_root_layer_nodes','InsertPosition'))
    result['legacy_adapter'] = 'original_batch_quarantined' if version == '9.1.2' else 'unverified'
    result['bounded_layer_adapter'] = '9.1.2_trial_verified; verify_target_project_separately' if version == '9.1.2' else 'unverified'
    return result


def instance_status(report, processes):
    """Connection, observed window and intended instance are distinct facts."""
    backend = next((p for p in processes if p['ProcessId'] == report.get('pid')), None)
    visible = [p['ProcessId'] for p in processes if p.get('WindowVisible', False)]
    return {'processes': processes, 'visible_window_pids': visible,
            'backend_has_main_window': bool(backend and backend.get('MainWindowHandle', 0)),
            'backend_window_visible': bool(backend and backend.get('WindowVisible', False)),
            'other_visible_instance': any(pid != report.get('pid') for pid in visible),
            'foreground_verified': False,
            'target_pid_required': len(processes) > 1}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--local-config')
    parser.add_argument('--start', action='store_true')
    parser.add_argument('--report', type=Path)
    parser.add_argument('--timeout', type=float, default=60)
    args = parser.parse_args()
    config = settings(args.local_config)
    if args.local_config:
        os.environ['PAINTER_LOCAL_CONFIG'] = str(config_path(args.local_config))
    import sp_remote as sp
    sp.HOST, sp.PORT = config['host'], config['port']
    running = windows_processes()
    executable = resolve_executable(config, running)
    report = capabilities()
    if not report['reachable'] and args.start:
        if config['port'] != 60041:
            raise RuntimeError('Launching a nondefault scripting port is unverified; attach to an already configured endpoint or use the verified default port')
        if running:
            raise RuntimeError('Painter already runs but scripting is unreachable; no duplicate instance or automatic restart. PIDs: ' + str([p['ProcessId'] for p in running]))
        startup = subprocess.STARTUPINFO() if os.name == 'nt' else None
        if startup:
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = 0
        process = subprocess.Popen([str(executable), '--enable-remote-scripting'], startupinfo=startup)
        deadline = time.monotonic() + args.timeout
        while time.monotonic() < deadline:
            report = capabilities()
            if report['reachable']:
                if report['pid'] != process.pid:
                    raise RuntimeError('Scripting endpoint belongs to a different PID than the newly launched process; inspect before continuing')
                break
            if process.poll() is not None:
                raise RuntimeError('Painter exited during startup; inspect its log before another launch')
            time.sleep(2)
    report['configured_executable'] = str(executable)
    report['local_config'] = config['config']
    report.update(instance_status(report, windows_processes()))
    if report['reachable']:
        report['installation_matches'] = Path(report['executable']).resolve() == executable
        if not report['installation_matches']:
            raise RuntimeError('The scripting endpoint belongs to a different installation: ' + report['executable'])
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))
    return 0 if report['reachable'] else 2


if __name__ == '__main__':
    raise SystemExit(main())
