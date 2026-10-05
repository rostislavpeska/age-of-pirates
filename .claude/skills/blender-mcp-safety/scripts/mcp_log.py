"""Crash log for live Blender MCP work (see ../SKILL.md).

python mcp_log.py before --action "rebuild Review_Pilot" --risk R2 [--file x.blend] [--agent claude]
python mcp_log.py after --ok | --error "message"
python mcp_log.py crash --note "owner: Blender crashed"      # marks the last 'before' as suspect
python mcp_log.py restart --file x.blend [--exe blender.exe]  # launch Blender, wait for MCP port 9876
python mcp_log.py tail [-n 10]
"""
import argparse
import datetime
import json
import os
import socket
import subprocess
import time
import uuid
from pathlib import Path

LOG = Path(os.environ.get('AOP_BLENDER_LOG') or Path(__file__).resolve().parents[1] / 'CRASH_LOG.jsonl')
AOP = Path(__file__).resolve().parents[4]
DEFAULT_EXE = r'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe'


def write(entry):
    entry = dict(time=datetime.datetime.now().isoformat(timespec='seconds'), **entry)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG, 'a', encoding='utf-8') as f:
        f.write(json.dumps(entry) + '\n'); f.flush(); os.fsync(f.fileno())
    return entry


def entries():
    return [json.loads(x) for x in LOG.read_text(encoding='utf-8').splitlines() if x.strip()] if LOG.exists() else []


def blender_exe():
    cfg = AOP / 'config' / 'tool-paths.local.json'
    if cfg.exists():
        p = json.loads(cfg.read_text()).get('tools', {}).get('blender', {}).get('path')
        if p:
            return p
    return DEFAULT_EXE


def port_open(port=9876):
    try:
        socket.create_connection(('localhost', port), timeout=1).close(); return True
    except OSError:
        return False


def operation_status(operation_id):
    events = [e for e in entries() if e.get('operation_id') == operation_id]
    return {'operation_id': operation_id, 'status': events[-1].get('status', 'UNKNOWN') if events else 'NOT_FOUND',
            'events': events}


def begin(action, risk, file, agent, operation_id=None):
    operation_id = operation_id or str(uuid.uuid4())
    if operation_status(operation_id)['status'] != 'NOT_FOUND':
        raise ValueError('operation already logged; reconcile status before any retry')
    return write(dict(event='before', status='IN_PROGRESS', operation_id=operation_id,
                      action=action, risk=risk, file=file, agent=agent))


def finish(operation_id, status, evidence):
    if status not in ('VERIFIED', 'FAILED', 'UNKNOWN') or not evidence:
        raise ValueError('completion needs VERIFIED/FAILED/UNKNOWN and evidence/reason')
    if operation_status(operation_id)['status'] == 'NOT_FOUND':
        raise ValueError('unknown operation; record intent before execution')
    return write(dict(event='after', operation_id=operation_id, status=status, evidence=evidence))


def main():
    ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest='cmd', required=True)
    b = sub.add_parser('before'); b.add_argument('--action', required=True); b.add_argument('--risk', default='none')
    b.add_argument('--file'); b.add_argument('--agent', default='claude'); b.add_argument('--operation')
    a = sub.add_parser('after'); a.add_argument('--ok', action='store_true'); a.add_argument('--error')
    a.add_argument('--operation'); a.add_argument('--unknown'); a.add_argument('--evidence')
    s = sub.add_parser('status'); s.add_argument('--operation', required=True)
    c = sub.add_parser('crash'); c.add_argument('--note', default='')
    r = sub.add_parser('restart'); r.add_argument('--file', required=True); r.add_argument('--exe'); r.add_argument('--timeout', type=int, default=120)
    t = sub.add_parser('tail'); t.add_argument('-n', type=int, default=10)
    x = ap.parse_args()
    if x.cmd == 'before':
        print(json.dumps(begin(x.action, x.risk, x.file, x.agent, x.operation)))
    elif x.cmd == 'after':
        if x.operation:
            state = 'UNKNOWN' if x.unknown else 'FAILED' if x.error else 'VERIFIED' if x.ok else 'UNKNOWN'
            print(json.dumps(finish(x.operation, state, x.unknown or x.error or x.evidence)))
        else:
            # Keep old logs usable but never call this uncorrelated event verified.
            print(write(dict(event='after', status='LEGACY_UNCORRELATED', ok=bool(x.ok and not x.error), error=x.error)))
    elif x.cmd == 'status':
        print(json.dumps(operation_status(x.operation)))
    elif x.cmd == 'crash':
        last = next((e for e in reversed(entries()) if e['event'] == 'before'), None)
        print(write(dict(event='crash', note=x.note, suspect=last)))
    elif x.cmd == 'restart':
        exe = x.exe or blender_exe(); subprocess.Popen([exe, x.file])
        t0 = time.time()
        while time.time() - t0 < x.timeout and not port_open():
            time.sleep(2)
        print(write(dict(event='restart', file=x.file, mcp_port_open=port_open(), seconds=round(time.time() - t0))))
    else:
        for e in entries()[-x.n:]:
            print(json.dumps(e))


if __name__ == '__main__':
    main()
