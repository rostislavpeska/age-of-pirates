"""Bounded native ArmorPaint batch runner. Windows hidden execution, no GUI input."""
from __future__ import annotations
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
from datetime import datetime, timezone
from PIL import Image

ERROR_PATTERN = re.compile(r'invalid script|parse error|compile error|runtime error|failed to compile|script error', re.I)
DRAIN = '''int frame=0;
void tick(){frame=frame+1;if(frame<8)script_notify_on_next_frame(tick);else console_info("EXPORT_DRAIN_COMPLETE");}
void main(){script_notify_on_next_frame(tick);}
'''

def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def runtime(exe=None, local_config=None):
    value = exe or os.environ.get('ARMORPAINT_EXE')
    if not value and local_config:
        value = json.loads(Path(local_config).read_text(encoding='utf-8'))['tools']['armorpaint']['path']
    if not value:
        raise ValueError('Set ARMORPAINT_EXE, --exe or tools.armorpaint.path in --local-config')
    result = Path(value).resolve()
    if not result.is_file():
        raise FileNotFoundError(result)
    return result

def prepare_directory(path):
    path = Path(path).resolve()
    if path.exists() and any(path.iterdir()):
        raise FileExistsError(f'Output directory must be new/empty: {path}')
    path.mkdir(parents=True, exist_ok=True)
    return path

def check_evidence(returncode, text, marker, expected, png_size=None):
    errors = []
    if returncode != 0:
        errors.append(f'Native process exited {returncode}')
    if ERROR_PATTERN.search(text):
        errors.append('Native script error in log')
    if marker and marker not in text:
        errors.append(f'Missing completion marker: {marker}')
    outputs = {}
    for item in expected:
        p = Path(item)
        if not p.is_file() or p.stat().st_size == 0:
            errors.append(f'Missing/empty expected output: {p}')
            continue
        record = {'bytes':p.stat().st_size, 'sha256':digest(p)}
        if p.suffix.lower() == '.png':
            try:
                with Image.open(p) as im:
                    im.load()
                    if im.format != 'PNG':
                        raise ValueError('Expected PNG')
                    record.update(size=list(im.size), mode=im.mode)
                    if png_size and im.size != tuple(png_size):
                        raise ValueError(f'Wrong dimensions: {im.size}, expected {png_size}')
            except Exception as exc:
                errors.append(f'Invalid PNG {p}: {exc}')
        outputs[str(p)] = record
    return errors, outputs

def execute(exe, args, out, expected, marker, inputs=(), timeout=120, png_size=None):
    if os.name != 'nt':
        raise RuntimeError('Hidden Windows runtime only; other platforms untested')
    if not 1 <= timeout <= 600:
        raise ValueError('Timeout must be between 1 and 600 seconds')
    expected = [Path(p).resolve() for p in expected]
    for p in expected:
        if p.exists():
            raise FileExistsError(f'Refusing stale or overwrite output: {p}')
    inputs = {str(Path(p).resolve()):digest(p) for p in inputs}
    command = [str(exe), '--background', '--nowindow'] + list(map(str, args))
    report = {'started_at':datetime.now(timezone.utc).isoformat(), 'command':command,
              'runtime_sha256':digest(exe), 'inputs':inputs, 'visible_windows':[], 'timed_out':False}
    si = subprocess.STARTUPINFO(); si.dwFlags |= subprocess.STARTF_USESHOWWINDOW; si.wShowWindow = 0
    started = time.monotonic()
    try:
        with (out/'stdout.txt').open('wb') as stdout, (out/'stderr.txt').open('wb') as stderr:
            process = subprocess.Popen(command, cwd=exe.parent, stdin=subprocess.DEVNULL,
                stdout=stdout, stderr=stderr, startupinfo=si, creationflags=subprocess.CREATE_NO_WINDOW)
            report['pid'] = process.pid
            @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
            def visit(hwnd, unused):
                pid = ctypes.c_ulong()
                ctypes.windll.user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
                if pid.value == process.pid and ctypes.windll.user32.IsWindowVisible(hwnd):
                    report['visible_windows'].append(int(hwnd))
                return True
            try:
                while process.poll() is None:
                    ctypes.windll.user32.EnumWindows(visit, 0)
                    if report['visible_windows'] or time.monotonic()-started > timeout:
                        report['timed_out'] = not bool(report['visible_windows'])
                        process.kill(); process.wait(timeout=10)
                        break
                    time.sleep(.1)
            finally:
                if process.poll() is None:
                    process.kill(); process.wait(timeout=10)
        report['returncode'] = process.returncode
        logs = (out/'stdout.txt').read_text(errors='replace') + (out/'stderr.txt').read_text(errors='replace')
        errors, outputs = check_evidence(process.returncode, logs, marker, expected, png_size)
        if report['timed_out']: errors.append('Timed out; owned process terminated')
        if report['visible_windows']: errors.append('Visible window detected; owned process terminated')
        for p, sha in inputs.items():
            if not Path(p).is_file() or digest(p) != sha:
                errors.append(f'Source mutation detected: {p}')
        report.update(errors=errors, outputs=outputs, ok=not errors)
    except Exception as exc:
        report.update(ok=False, errors=[f'{type(exc).__name__}: {exc}'])
    finally:
        report['seconds'] = time.monotonic()-started
        report['visible_windows'] = sorted(set(report['visible_windows']))
        (out/'RUN.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    return report

def run_script(exe, input_path, script_path, out_dir, expected, marker, timeout=120):
    if not expected or not marker or not marker.strip():
        raise ValueError('Script runs require expected outputs and a completion marker')
    source, script = Path(input_path).resolve(), Path(script_path).resolve()
    for p in (source, script):
        if not p.is_file(): raise FileNotFoundError(p)
    out = prepare_directory(out_dir)
    return execute(exe, [source, '--script', script], out, expected, marker, [source, script], timeout)

def export(exe, input_path, out_dir, size=2048, timeout=120):
    source = Path(input_path).resolve()
    if not source.is_file() or source.suffix.lower() != '.arm':
        raise ValueError('Export requires an existing .arm project')
    out = prepare_directory(out_dir)
    drain = out/'drain.c'; drain.write_text(DRAIN, encoding='utf-8')
    names = [out/f'{source.stem}_{suffix}.png' for suffix in ['base','nor','occ','rough','metal']]
    return execute(exe, [source, '--export-textures','png','generic',out,'--script',drain],
                   out, names, 'EXPORT_DRAIN_COMPLETE', [source], timeout, (size,size))

def resize_script(size, destination):
    if not isinstance(size, int) or isinstance(size, bool) or size < 64 or size > 16384 or size & (size-1):
        raise ValueError('Resolution must be a square power of two from 64 through 16384')
    target = json.dumps(str(Path(destination).resolve()))
    return (f'int frame=0;void tick(){{frame=frame+1;if(frame==1){{'
            f'bool ok=script_set_texture_resolution({size});'
            'console_info(string("RESIZE_ACCEPTED=%d",ok));}'
            f'if(frame==5){{script_set_pack_assets(1);project_filepath_set({target});project_save(0);}}'
            'if(frame<9)script_notify_on_next_frame(tick);else console_info("RESIZE_COMPLETE");}'
            'void main(){script_notify_on_next_frame(tick);}')

def resize(exe, input_path, out_dir, size, timeout=120):
    """Requires the pinned resolution extension; never rewrites the source project."""
    source = Path(input_path).resolve()
    if not source.is_file() or source.suffix.lower() != '.arm':
        raise ValueError('Resize requires an existing .arm project')
    out = Path(out_dir).resolve()
    target = out/f'{source.stem}_{size}.arm'
    code = resize_script(size, target)
    prepare_directory(out)
    script = out/'resize.c'; script.write_text(code, encoding='utf-8')
    report = execute(exe, [source,'--script',script], out, [target],
                     'RESIZE_COMPLETE', [source], timeout)
    if report['ok']:
        report['export_verification'] = export(exe, target, out/'verified-export', size, timeout)
        if not report['export_verification']['ok']:
            report['ok'] = False
            report['errors'].append('Resized project failed reopened export validation')
        (out/'RUN.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    return report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe'); parser.add_argument('--local-config')
    sub = parser.add_subparsers(dest='operation', required=True)
    for name in ['run','export','resize']:
        p = sub.add_parser(name); p.add_argument('--input', required=True)
        p.add_argument('--out-dir', required=True); p.add_argument('--timeout', type=float, default=120)
        if name == 'run':
            p.add_argument('--script', required=True); p.add_argument('--expect', action='append', required=True)
            p.add_argument('--marker', required=True)
        else: p.add_argument('--size', type=int, default=2048,
                            help='Project resolution; export validates but does not resize')
    a = parser.parse_args()
    try:
        exe = runtime(a.exe, a.local_config)
        result = (run_script(exe,a.input,a.script,a.out_dir,a.expect,a.marker,a.timeout) if a.operation=='run'
                  else (resize if a.operation=='resize' else export)(exe,a.input,a.out_dir,a.size,a.timeout))
    except Exception as exc:
        result = {'ok':False, 'errors':[f'{type(exc).__name__}: {exc}']}
    print(json.dumps(result, indent=2))
    return 0 if result['ok'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
