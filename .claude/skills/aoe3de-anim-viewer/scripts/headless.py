#!/usr/bin/env python
"""Run a viewer page in a headless Chromium browser - no window, no screen, the owner's browser profile untouched.

    python headless.py browsers                         # the browsers this device offers, and where each was found
    python headless.py m0 [--out DIR] [--gpu auto|d3d11|swiftshader|both] [--browser chrome|edge|PATH] [--timeout 60]
    python headless.py job BUNDLE_ID JOB.json [--out DIR] [--gpu auto] [--timeout 120]   # viewer frames -> PNGs

    import headless as H
    rec = H.run_job('c2ace5bb7182cc67', {'width': 800, 'height': 800, 'frames': [{'name': 'idle0', 'anim': 'Idle'}]})
    rec['result']['frames'], rec['files'], rec['out_dir']            # the page's report, the PNGs it posted

The page is served by server.py on 127.0.0.1 (a free port, a token per run) and posts its result back; this script
waits for that 'done' (or 'error') event, enforces the timeout, then ends the browser's process tree and deletes its
throwaway profile. Browser: --browser (chrome, edge or a path), else AOP_ANIM_VIEWER_BROWSER, else Chrome from the
device config (config/tool-paths.local.json tools.chrome.path) or PATH. Edge runs ONLY when named (--browser edge):
on 2026-10-11 its launcher, with an update pending, dropped --headless and the throwaway profile and opened a visible
window on the owner's own Edge profile (INC-237). Guards: a browser with a pending update swap (new_<exe> beside it)
is refused; a launch that exits within seconds without contacting the server is reported as 'browser-handoff', lists
the same-name processes that appeared (left alone: they may be the owner's), and stops every further launch; leftover
processes after a run are reported; a throwaway profile that cannot be deleted is reported with the processes that
still hold it (profile_deleted, profile_holders: by construction browsers this run started) and stops the M0 run.
Flags: --headless=new and a --user-data-dir under <cache>/profiles (system temp).
GPU modes: auto (the browser's choice; ANGLE on D3D11 on Windows), d3d11 (forced), swiftshader (CPU rendering:
--use-angle=swiftshader --enable-unsafe-swiftshader). Outputs - the page's PNG, run.json, browser.log - go to a
non-repository folder (av_common.output_dir; a repository, an AoE3 profile or the install is refused).

m0 = the M0 spike page (viewer/m0): WebGL2, a raw S3TC upload sampled into an RGBA16F target, float readback, PNG.
Its summary (m0_result.json) names the GPU path that ran and whether EXT_color_buffer_float,
WEBGL_compressed_texture_s3tc and WEBGL_compressed_texture_s3tc_srgb exist, for each GPU mode.

job = the viewer page (viewer/app) in job mode: the bundle is served from the bundle root (the cache), the job JSON
travels in the URL (?job=), the page renders every listed frame, posts one PNG per frame (plus the bone world matrices
when job.readback), logs each frame (printed with its time) and posts 'done'; the run ends at 'done', 'error', the
timeout or a browser exit. Job keys: width, height, background [r,g,b,a], grid, readback, player_color_index, frames
[{name, anim, variant, logic {type: state}, sync absolute|phase, method bspline|knots, time (s) | key (+ key_of
main|child), bones, camera {mode game, yaw, pitch, fov, distance} | {mode render_obj, lo, hi, az, el, units}}].
M3 adds `shading` (viewer/shading/hook.js); M5 (viewer/export/job.js, which documents them) adds `bounds`
frame|clip, `timeline`, `geometry`, `other` {bundle, anim, variant} (a second subject on the same clock), frame
`times` [...] (+ `other_times`), frame `at` tags|keys|fps=N and camera mode `close` / `ortho`. A job whose URL-encoded
JSON is longer than URL_JOB_LIMIT characters travels over GET /api/job (the page is opened with job=@server): a Windows
command line holds at most 32767 characters.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time
import uuid
from pathlib import Path
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).resolve().parent))
import av_common as C  # noqa: E402
from server import ViewerServer  # noqa: E402

BROWSER_ENV = 'AOP_ANIM_VIEWER_BROWSER'
PATH_NAMES = {'chrome': ('chrome', 'google-chrome', 'google-chrome-stable', 'chromium', 'chromium-browser'),
              'edge': ('msedge', 'microsoft-edge', 'microsoft-edge-stable')}
GPU_MODES = ('auto', 'd3d11', 'swiftshader')
BASE_FLAGS = (
    '--headless=new', '--no-first-run', '--no-default-browser-check', '--disable-extensions',
    '--disable-component-extensions-with-background-pages', '--disable-background-networking', '--disable-sync',
    '--disable-default-apps', '--disable-component-update', '--disable-domain-reliability', '--disable-breakpad',
    '--disable-client-side-phishing-detection', '--no-pings', '--metrics-recording-only', '--mute-audio',
    '--hide-scrollbars', '--force-device-scale-factor=1', '--password-store=basic', '--use-mock-keychain',
    '--enable-logging=stderr', '--log-level=1',
)
GPU_FLAGS = {'auto': (), 'd3d11': ('--use-angle=d3d11', '--ignore-gpu-blocklist'),
             'swiftshader': ('--use-angle=swiftshader', '--enable-unsafe-swiftshader')}
HANDOFF_WINDOW = 8.0          # s: a launcher that exits this fast without any request to the server handed off


def _norm(p):
    return os.path.normcase(os.path.abspath(p))


def _name_of(path):
    s = Path(path).name.lower()
    return 'edge' if 'edge' in s else 'chrome' if ('chrom' in s) else 'custom'


def find_browsers(explicit=None, config=None, env=None, which=shutil.which):
    """[{name, path, source}] in the order to try: $AOP_ANIM_VIEWER_BROWSER, the device config (chrome, then edge), PATH
    (chrome, then edge). Only existing files; duplicates removed. `explicit` 'chrome' / 'edge' keeps only that
    browser; any other value is a path and the ONLY candidate (nothing when it does not exist)."""
    env = os.environ if env is None else env
    only = explicit if explicit in PATH_NAMES else None
    if explicit and not only:
        p = Path(explicit)
        return [{'name': _name_of(p), 'path': str(p), 'source': '--browser'}] if p.is_file() else []
    cands = []
    if env.get(BROWSER_ENV):
        cands.append((_name_of(env[BROWSER_ENV]), env[BROWSER_ENV], BROWSER_ENV))
    for name in ('chrome', 'edge'):
        p = C.local_tool_path(name, config)
        if p:
            cands.append((name, p, 'config tools.%s.path' % name))
    for name in ('chrome', 'edge'):
        for exe in PATH_NAMES[name]:
            p = which(exe)
            if p:
                cands.append((name, p, 'PATH (%s)' % exe))
                break
    out, seen = [], set()
    for name, path, source in cands:
        if only and name != only:
            continue
        if not Path(path).is_file() or _norm(path) in seen:
            continue
        seen.add(_norm(path))
        out.append({'name': name, 'path': str(path), 'source': source})
    return out


def select_browsers(explicit=None, config=None, env=None, which=shutil.which):
    """the browsers a run may launch, in order. Named (--browser or AOP_ANIM_VIEWER_BROWSER): those only. Otherwise
    Chrome only - Edge is never an automatic fallback (INC-237)."""
    env = os.environ if env is None else env
    found = find_browsers(explicit, config, env, which)
    if explicit:
        return found
    if env.get(BROWSER_ENV):
        return [b for b in found if b['source'] == BROWSER_ENV][:1]
    return [b for b in found if b['name'] == 'chrome'][:1]


def pending_update(path):
    """the reason this browser must not be launched now, else None: a staged update swap (new_<exe> beside the
    executable) makes a Chromium launcher relaunch itself, which can drop --headless and --user-data-dir."""
    p = Path(path)
    swap = p.with_name('new_' + p.name)
    if swap.exists():
        return 'update swap pending (%s): start the browser once normally, then retry' % swap
    return None


def same_name_pids(exe):
    """process ids of every running process with the executable's file name (Windows tasklist); None elsewhere."""
    if os.name != 'nt':
        return None
    try:
        out = subprocess.run(['tasklist', '/FO', 'CSV', '/NH', '/FI', 'IMAGENAME eq %s' % Path(exe).name],
                             capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    pids = set()
    for line in out.splitlines():
        parts = [x.strip().strip('"') for x in line.split('","')]
        if len(parts) > 1 and parts[1].isdigit():
            pids.add(int(parts[1]))
    return pids


def parent_pids(pids):
    """{pid: parent pid} of the given process ids (a read-only Windows Toolhelp snapshot); {} elsewhere or on error."""
    want = set(pids or ())
    if os.name != 'nt' or not want:
        return {}
    try:
        import ctypes
        from ctypes import wintypes

        class _Entry(ctypes.Structure):
            _fields_ = [('dwSize', wintypes.DWORD), ('cntUsage', wintypes.DWORD), ('th32ProcessID', wintypes.DWORD),
                        ('th32DefaultHeapID', ctypes.c_size_t), ('th32ModuleID', wintypes.DWORD),
                        ('cntThreads', wintypes.DWORD), ('th32ParentProcessID', wintypes.DWORD),
                        ('pcPriClassBase', wintypes.LONG), ('dwFlags', wintypes.DWORD),
                        ('szExeFile', wintypes.WCHAR * 260)]

        k32 = ctypes.WinDLL('kernel32', use_last_error=True)
        k32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
        k32.CreateToolhelp32Snapshot.argtypes = (wintypes.DWORD, wintypes.DWORD)
        k32.Process32FirstW.argtypes = (wintypes.HANDLE, ctypes.POINTER(_Entry))
        k32.Process32NextW.argtypes = (wintypes.HANDLE, ctypes.POINTER(_Entry))
        k32.CloseHandle.argtypes = (wintypes.HANDLE,)
        snap = k32.CreateToolhelp32Snapshot(0x2, 0)                 # TH32CS_SNAPPROCESS
        if not snap or snap == wintypes.HANDLE(-1).value:
            return {}
        out = {}
        try:
            e = _Entry()
            e.dwSize = ctypes.sizeof(_Entry)
            ok = k32.Process32FirstW(snap, ctypes.byref(e))
            while ok:
                if e.th32ProcessID in want:
                    out[int(e.th32ProcessID)] = int(e.th32ParentProcessID)
                ok = k32.Process32NextW(snap, ctypes.byref(e))
        finally:
            k32.CloseHandle(snap)
        return out
    except (OSError, AttributeError, ValueError):
        return {}


def classify_appeared(appeared, before, ppids):
    """(possible leftovers of this run, owner_children): a process that appeared during the run whose parent was
    already running before it is a child of someone else's browser (the owner's), not ours; one with an unknown
    parent stays a possible leftover."""
    before = set(before or ())
    owner = sorted(p for p in appeared if ppids.get(p) in before)
    return sorted(p for p in appeared if p not in owner), owner


def browser_command(path, url, profile_dir, gpu='auto', size=(1280, 900)):
    """the argument list: headless, a throwaway profile, no background services, the GPU mode's flags, the URL."""
    if gpu not in GPU_FLAGS:
        raise ValueError('gpu mode %r (one of %s)' % (gpu, ', '.join(GPU_MODES)))
    return [str(path), *BASE_FLAGS, '--user-data-dir=%s' % profile_dir, '--window-size=%d,%d' % tuple(size),
            *GPU_FLAGS[gpu], url]


def profile_dir(run_id):
    """<cache>/profiles/<run id>: never the owner's browser profile, never inside a repository."""
    p = C.refuse_repo_path(C.cache_root() / 'profiles' / run_id, 'a browser profile')
    p.mkdir(parents=True, exist_ok=True)
    return p


def kill_tree(proc):
    """end the browser we started and its child processes (gpu, renderer, utility) - nothing else."""
    if proc.poll() is not None:
        return
    if os.name == 'nt':
        subprocess.run(['taskkill', '/PID', str(proc.pid), '/T', '/F'], capture_output=True, timeout=30)
    else:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except OSError:
            pass
    try:
        proc.wait(10)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(10)


def _rmtree_retry(p, tries=20):
    for _ in range(tries):
        try:
            shutil.rmtree(p)
            return True
        except FileNotFoundError:
            return True
        except OSError:
            time.sleep(0.25)                                   # child processes release their files a moment later
    return False


def profile_holders(profile):
    """[{pid, app}] of the processes that still hold the throwaway profile's lockfile open, asked read-only through
    the Windows Restart Manager; [] when none; None where it cannot be asked (not Windows, no lockfile, API error).
    A process holding OUR throwaway profile was started by this run: an orphan the launcher left behind when it
    exited (taskkill /T on an exited launcher no longer reaches its children). 2026-10-11 review: the INC-237 Edge
    launch left such a windowless browser on its throwaway profile for hours while the run reported nothing."""
    lock = Path(profile) / 'lockfile'
    if os.name != 'nt' or not lock.exists():
        return None
    try:
        import ctypes
        from ctypes import wintypes

        class _UniqueProcess(ctypes.Structure):
            _fields_ = [('dwProcessId', wintypes.DWORD), ('ProcessStartTime', wintypes.FILETIME)]

        class _ProcessInfo(ctypes.Structure):
            _fields_ = [('Process', _UniqueProcess), ('strAppName', wintypes.WCHAR * 256),
                        ('strServiceShortName', wintypes.WCHAR * 64), ('ApplicationType', ctypes.c_int),
                        ('AppStatus', wintypes.ULONG), ('TSSessionId', wintypes.DWORD), ('bRestartable', wintypes.BOOL)]

        rm = ctypes.WinDLL('rstrtmgr')
        session, key = wintypes.DWORD(), ctypes.create_unicode_buffer(33)
        if rm.RmStartSession(ctypes.byref(session), 0, key):
            return None
        try:
            files = (wintypes.LPCWSTR * 1)(str(lock))
            if rm.RmRegisterResources(session, 1, files, 0, None, 0, None):
                return None
            needed, count, reasons = wintypes.UINT(0), wintypes.UINT(0), wintypes.DWORD()
            rm.RmGetList(session, ctypes.byref(needed), ctypes.byref(count), None, ctypes.byref(reasons))
            arr = (_ProcessInfo * max(needed.value, 1))()
            count = wintypes.UINT(needed.value)
            if rm.RmGetList(session, ctypes.byref(needed), ctypes.byref(count), arr, ctypes.byref(reasons)):
                return None
            return [{'pid': int(arr[i].Process.dwProcessId), 'app': arr[i].strAppName} for i in range(count.value)]
        finally:
            rm.RmEndSession(session)
    except (OSError, AttributeError, ValueError):
        return None


def _printer(log):
    def on_event(ev):
        if ev['kind'] == 'done':
            d = ev['data'] or {}
            log('[%7.3f] done: status %s' % (ev['t'], d.get('status')))
        elif ev['kind'] == 'file':
            log('[%7.3f] file %s (%d bytes)' % (ev['t'], ev['data']['name'], ev['data']['bytes']))
        else:
            log('[%7.3f] %s %s' % (ev['t'], ev['kind'], json.dumps(ev['data'])[:400]))
    return on_event


def run_page(page, *, out_dir=None, query=None, timeout=60.0, browser=None, gpu='auto', log=print,
             keep_profile=False, label='run', bundle_root=None, job=None):
    """serve viewer/<page> and run it in one headless browser; returns the run record (also written as run.json):
    {status: done|error|timeout|browser-exited|browser-handoff|refused|no-browser, browser, gpu_mode, page, elapsed_s,
    result (the page's 'done' JSON), error, files, out_dir, browser_log, rejected, foreign_processes,
    leftover_processes, owner_children (same-name processes that appeared during the run as children of a browser
    that ran before it: the owner's, never counted as ours), profile, profile_deleted (None when kept or never
    made), profile_holders [{pid, app}]}
    job: a dict the server hands to the page on GET /api/job (the page asks for it when its query says job=@server)."""
    out = C.output_dir(out_dir, label)
    rec = {'status': 'no-browser', 'browser': browser, 'gpu_mode': gpu, 'page': page, 'out_dir': str(out),
           'elapsed_s': 0.0, 'result': None, 'error': None, 'files': [], 'browser_log': None, 'rejected': [],
           'foreign_processes': [], 'leftover_processes': [], 'owner_children': [], 'profile': None,
           'profile_deleted': None, 'profile_holders': []}
    if not browser:
        C.write_json(out / 'run.json', rec)
        return rec
    why = pending_update(browser['path'])
    if why:
        rec.update(status='refused', error=why)
        log('refused %s: %s' % (browser['name'], why))
        C.write_json(out / 'run.json', rec)
        return rec
    before = same_name_pids(browser['path'])
    run_id = '%s-%s' % (time.strftime('%Y%m%d-%H%M%S'), uuid.uuid4().hex[:8])
    prof = profile_dir(run_id)
    srv = ViewerServer(out, bundle_root=bundle_root, on_event=_printer(log), job=job).start()
    url = srv.url('/viewer/' + page, test=1, **(query or {}))
    cmd = browser_command(browser['path'], url, prof, gpu)
    blog = out / 'browser.log'
    rec['browser_log'] = str(blog)
    t0 = time.monotonic()
    log('start %s (%s, gpu %s) on %s, timeout %ss' % (browser['name'], browser['path'], gpu, page, timeout))
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
                    quick = time.monotonic() - t0 < HANDOFF_WINDOW and srv.hits == 0
                    rec['status'] = 'browser-handoff' if quick else 'browser-exited'
                    rec['error'] = ('the launcher exited (code %s) after %.1f s without loading the page: it may have '
                                    'handed the start to another browser instance, possibly a VISIBLE window on the '
                                    "owner's own profile. No further browser is launched; report it."
                                    % (proc.returncode, time.monotonic() - t0)) if quick else \
                        'browser exited with code %s before the page reported' % proc.returncode
                    break
                if time.monotonic() - t0 > timeout:
                    rec['status'] = 'timeout'
                    rec['error'] = 'no result after %ss' % timeout
                    break
            if ev is not None:
                rec['status'] = ev['kind']
                if ev['kind'] == 'done':
                    rec['result'] = ev['data']
                    srv.wait_for(('__never__',), timeout=0.2)    # let a trailing log line arrive
                else:
                    rec['error'] = ev['data']
    finally:
        if proc is not None:
            kill_tree(proc)
        srv.stop()
        rec['profile'] = str(prof)
        if not keep_profile:
            rec['profile_deleted'] = _rmtree_retry(prof)
            if not rec['profile_deleted']:
                holders = profile_holders(prof)
                rec['profile_holders'] = holders or []
                log('WARNING: the throwaway profile %s was NOT deleted%s' % (
                    prof, ': still held by %s - a browser this run started is still running (not ended here); end it, '
                          'then delete the folder' % ', '.join('%s (pid %d)' % (h['app'], h['pid']) for h in holders)
                    if holders else ' (holders unknown)'))
    after = same_name_pids(browser['path'])
    if before is not None and after is not None:
        appeared = sorted(after - before - {proc.pid if proc else -1})
        # same-name processes that appeared during this run and are still alive: never ended here (they may be the
        # owner's); after a handoff they are the suspects, after a normal run they are possible leftovers - except
        # the children of a browser that was already running before this run (the owner's own browser opening a
        # tab or a utility process meanwhile: 2026-10-11, M5 review), listed apart as owner_children
        if rec['status'] == 'browser-handoff':
            rec['foreign_processes'] = appeared
            new = appeared
        else:
            new, rec['owner_children'] = classify_appeared(appeared, before, parent_pids(appeared))
            rec['leftover_processes'] = new
        if new:
            log('WARNING: %d %s process(es) appeared during the run and are still running: %s (left alone)'
                % (len(new), Path(browser['path']).name, new))
    rec['elapsed_s'] = round(time.monotonic() - t0, 2)
    rec['files'] = list(srv.files)
    rec['rejected'] = [e['data'] for e in srv.events if e['kind'] == 'rejected']
    rec['events'] = [{'kind': e['kind'], 't': e['t'], 'data': e['data']} for e in srv.events
                     if e['kind'] in ('log', 'file', 'error', 'rejected')]
    C.write_json(out / 'run.json', rec)
    log('end: %s after %.1f s' % (rec['status'], rec['elapsed_s']))
    return rec


# ---------------------------------------------------------------------------------------------------- M0 spike
def summarise_m0(rec):
    """the short M0 answer for one run: GPU path, renderer, the three extensions, target, per-region errors, PNG."""
    r = rec.get('result') or {}
    ren = r.get('renderer') or {}
    return {
        'run_status': rec['status'], 'page_status': r.get('status'), 'browser': (rec.get('browser') or {}).get('name'),
        'gpu_mode': rec['gpu_mode'], 'gpu_path': r.get('gpu_path'),
        'renderer': ren.get('unmasked_renderer') or ren.get('renderer'), 'webgl2': r.get('webgl2'),
        'extensions': r.get('extensions'), 'target': r.get('target'), 'hdr_kept': r.get('hdr_kept'),
        'texture_decoder': r.get('texture_decoder'),
        'regions': {g['id']: {'path': g['path'], 'decoder': g.get('decoder_match'),
                              'max_abs_error': round(g['max_abs_error'], 5),
                              'error_exact_rgb': round(g['errors']['exact']['rgb'], 5),
                              'error_nvidia_rgb': round(g['errors']['nvidia']['rgb'], 5),
                              'error_alpha': round(g['errors']['exact']['alpha'], 5),
                              'max_value': round(g['max_value'], 4)} for g in r.get('regions') or []},
        'problems': r.get('problems'), 'fallbacks': r.get('fallbacks'), 'elapsed_s': rec['elapsed_s'],
        'png': str(Path(rec['out_dir']) / r['png']) if r.get('png') else None, 'error': rec.get('error'),
    }


STOP_ALL = ('browser-handoff',)          # after this nothing else is launched in the run
URL_JOB_LIMIT = 6000                     # characters of URL-encoded job JSON; longer jobs travel over GET /api/job


# ---------------------------------------------------------------------------------------------------- viewer jobs
def run_job(bundle_id, job, *, out_dir=None, bundle_root=None, browser=None, gpu='auto', timeout=120.0, log=print,
            label='job'):
    """render the frames of `job` (dict, see the module docstring) from bundle `bundle_id` in the headless viewer.
    Returns the run record of run_page (status, result = the page's report, files = the PNGs/JSON it posted, out_dir).
    Chrome only unless `browser` names another (select_browsers); a pending browser update is refused."""
    root = Path(bundle_root) if bundle_root else C.cache_root()
    if not (root / bundle_id / 'manifest.json').is_file():
        raise FileNotFoundError('no bundle %s under %s: build it first (anim_viewer.py build)' % (bundle_id, root))
    for other in _other_bundles(job):                           # compare / side-by-side subjects (M5)
        if not (root / other / 'manifest.json').is_file():
            raise FileNotFoundError('no bundle %s under %s: build it first (anim_viewer.py build)' % (other, root))
    browsers = select_browsers(browser)
    text = json.dumps(job, separators=(',', ':'))
    big = len(quote(text, safe='-_.~')) > URL_JOB_LIMIT              # a Windows command line holds 32767 characters
    return run_page('app/index.html', out_dir=out_dir, query={'bundle': bundle_id, 'job': '@server' if big else text},
                    timeout=timeout, browser=browsers[0] if browsers else None, gpu=gpu, log=log, label=label,
                    bundle_root=root, job=job if big else None)


def _other_bundles(job):
    """the extra bundle ids a job names (job.other.bundle: the compare / side-by-side subject)."""
    o = (job or {}).get('other') or {}
    return [o['bundle']] if o.get('bundle') else []


def run_m0(out_dir=None, gpu='both', browser=None, timeout=60.0, log=print):
    """the M0 spike in each GPU mode with the selected browser (Chrome unless --browser names another; Edge only when
    named). A handoff stops the whole run. Writes <out>/m0_result.json and returns it."""
    out = C.output_dir(out_dir, 'm0')
    browsers = select_browsers(browser)
    modes = ['auto', 'swiftshader'] if gpu == 'both' else [gpu]
    result = {'tool': C.TOOL_NAME, 'version': C.TOOL_VERSION, 'out_dir': str(out),
              'browsers_found': find_browsers(browser), 'browsers_selected': browsers, 'runs': [], 'summary': {}}
    if not browsers:
        result['summary'] = {'status': 'no-browser'}
        log('no browser selected: Chrome from config tools.chrome.path or PATH, %s, or --browser' % BROWSER_ENV)
        C.write_json(out / 'm0_result.json', result)
        return result
    stopped = None
    for mode in modes:
        for b in browsers:
            rec = run_page('m0/index.html', out_dir=out / ('%s-%s' % (mode, b['name'])), timeout=timeout, browser=b,
                           gpu=mode, log=log, label='m0')
            s = summarise_m0(rec)
            s['foreign_processes'] = rec.get('foreign_processes')
            s['leftover_processes'] = rec.get('leftover_processes')
            s['profile_deleted'] = rec.get('profile_deleted')
            s['profile_holders'] = rec.get('profile_holders')
            result['runs'].append(s)
            if rec.get('profile_holders'):                     # a browser of ours still runs: launch nothing more
                stopped = rec
                log('STOP: %s left %s on its throwaway profile' % (b['name'], rec['profile_holders']))
                break
            if rec['status'] == 'done':
                result['summary'][mode] = s
                break
            if rec['status'] in STOP_ALL:
                stopped = rec
                log('STOP: %s %s - %s' % (b['name'], rec['status'], rec['error']))
                break
            log('%s could not run the page in mode %s (%s)' % (b['name'], mode, rec['status']))
        if stopped:
            break
    first = result['summary'].get(modes[0]) or {}
    result['summary']['status'] = stopped['status'] if stopped else (first.get('page_status') or 'fail')
    C.write_json(out / 'm0_result.json', result)
    return result


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    sub = ap.add_subparsers(dest='cmd', required=True)
    sub.add_parser('browsers', help='list the browsers found on this device')
    m0 = sub.add_parser('m0', help='run the M0 spike page')
    m0.add_argument('--out', help='output folder (default: a new folder in the cache; a repository is refused)')
    m0.add_argument('--gpu', default='both', choices=GPU_MODES + ('both',))
    m0.add_argument('--browser', help='chrome (the default), edge (only when named: INC-237) or a browser path')
    m0.add_argument('--timeout', type=float, default=60.0)
    jb = sub.add_parser('job', help='render a job of viewer frames from a cached bundle')
    jb.add_argument('bundle_id')
    jb.add_argument('job', help='job JSON file (module docstring)')
    jb.add_argument('--out', help='output folder (default: a new folder in the cache; a repository is refused)')
    jb.add_argument('--gpu', default='auto', choices=GPU_MODES)
    jb.add_argument('--browser', help='chrome (the default), edge (only when named: INC-237) or a browser path')
    jb.add_argument('--timeout', type=float, default=120.0)
    a = ap.parse_args(argv)
    if a.cmd == 'job':
        try:
            rec = run_job(a.bundle_id, C.read_json(a.job), out_dir=a.out, browser=a.browser, gpu=a.gpu,
                          timeout=a.timeout)
        except (C.RepoPathError, FileNotFoundError) as e:
            print(e, file=sys.stderr)
            return 2
        print('job status: %s, %d file(s) in %s' % (rec['status'], len(rec['files']), rec['out_dir']))
        return 0 if rec['status'] == 'done' else 1
    if a.cmd == 'browsers':
        found, chosen = find_browsers(), select_browsers()
        for b in found:
            flag = 'default' if b in chosen else 'only with --browser %s' % b['name']
            why = pending_update(b['path'])
            print('%-7s %s  (%s; %s)%s' % (b['name'], b['path'], b['source'], flag, ('  REFUSED: ' + why) if why else ''))
        if not found:
            print('none found: set tools.chrome.path in config/tool-paths.local.json or %s' % BROWSER_ENV)
        return 0 if found else 2
    try:
        res = run_m0(a.out, a.gpu, a.browser, a.timeout)
    except C.RepoPathError as e:
        print(e, file=sys.stderr)
        return 2
    for mode, s in res['summary'].items():
        if mode == 'status':
            continue
        print('%-11s %-6s %-13s %s' % (mode, s['page_status'], s['gpu_path'], s['renderer']))
        print('            texture decoder: %s' % s.get('texture_decoder'))
        print('            extensions %s' % json.dumps(s['extensions']))
        print('            target %s, regions %s' % (json.dumps(s['target']), json.dumps(s['regions'])))
        if s['png']:
            print('            png %s' % s['png'])
    for r in res['runs']:
        if r.get('foreign_processes') or r.get('leftover_processes'):
            print('WARNING %s/%s: processes left running (not ended by this tool): %s'
                  % (r['browser'], r['gpu_mode'], r.get('foreign_processes') or r.get('leftover_processes')))
        if r.get('profile_deleted') is False:
            print('WARNING %s/%s: the throwaway profile was not deleted; held by %s'
                  % (r['browser'], r['gpu_mode'], r.get('profile_holders') or 'unknown processes'))
    print('M0 status: %s  (%s)' % (res['summary'].get('status'), Path(res['out_dir']) / 'm0_result.json'))
    return {'ok': 0, 'degraded': 0, 'no-browser': 2, 'browser-handoff': 3}.get(res['summary'].get('status'), 1)


if __name__ == '__main__':
    sys.exit(main())
