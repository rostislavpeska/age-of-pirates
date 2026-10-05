#!/usr/bin/env python3
"""Tool guard: a PreToolUse hook on Bash, PowerShell, Monitor and mcp__blender__execute_blender_code. Three incident
rules, deny through JSON.

  R1 raw repoint   (owner 2026-09-29 13:05: "The process is STILL flawed!"; journal 29-41: Back-to-final dropped the
                   decor). Blender MCP code that points an existing image at another file (`<image>.filepath = ...`,
                   `.filepath_raw = ...`, `<image>.reload()`, bpy.ops.image.reload / replace) bypasses the review
                   watcher: no snapshot, no Back, no preview gate, no 4-per-step reload limit (blender-mcp-safety R9,
                   the 19-image reload that dropped the MCP link). Maps reach the owner's Blender through
                   `python publish.py candidate ...` and the watcher API (st.beta_show(key) / start_preview). Loading a
                   NEW image (bpy.data.images.load) and render output paths (scene.render.filepath) are not repoints.
  R2 gate bypass   (journal 29-28: `python blender_gate.py ... | tail -1 && blender -b ...` launched Blender on a gate
                   TIMEOUT, because a pipeline's status is its last command's). blender_gate.py piped, or followed by
                   `;` / `||` and a background Blender, is denied: chain it with `&&`, or `set -o pipefail`.
  R3 endless loop  (INC-027, KTC-164: `while netstat -ano | grep -q ":9876 .*LISTENING"; do sleep 20; done`, started
                   with run_in_background, ran 32 h after its job ended; its Monitor twin was re-armed six times). A Bash
                   or PowerShell call with run_in_background=true, a Monitor command, or a FOREGROUND call that detaches
                   (a lone `&`, nohup, disown, setsid, Start-Job / Start-Process) that runs an endless loop is denied
                   unless it goes through .claude/hooks/watch.py (which ends it with its task, run, TTL or session) or a
                   `timeout` of at most 1h wraps the loop. Loops: while/until ... sleep, while true, ANY for loop with a
                   sleep, for (;;) (with an init too), do {} while, watch, tail -f, Get-Content -Wait, sleep infinity,
                   ping -t, inotifywait -m, setInterval, a recursive shell function, and those loops inside base64 text
                   the command decodes (INC-037). The .py / .sh / .ps1 file a background python / bash / powershell
                   call runs is read and scanned too (a `# aop-allow-loop: <reason>` line in it is its override). Only
                   a REAL `python .../watch.py start ...` that ends the command is the wrapper; the text alone is not.
                   Other foreground calls are never checked (the tool bounds them) and never start Python: the settings
                   command's `case` passes only background, Monitor, detaching, gate and Blender inputs to this script,
                   read with the `read` builtin (no fork, INC-038).

Override, logged: a line `# aop-allow-repoint: <reason>` (R1), `# aop-allow-gate: <reason>` (R2) or
`# aop-allow-loop: <reason>` (R3) in the code or command, reason >= 8 characters; or env AOP_TOOL_GUARD=off. Every deny and override is one line in harness_log.jsonl
(AOP_HARNESS_LOG). Contract: stdout carries only the hook JSON on a deny, nothing otherwise (0 bytes on allow); exit 0
always; an internal error fails OPEN (logged). Python standard library only.
"""
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

BLENDER_TOOL = 'mcp__blender__execute_blender_code'
MONITOR_TOOL = 'Monitor'
SHELL_TOOLS = ('Bash', 'PowerShell')
_TOOLS = str(Path(__file__).resolve().parents[2] / 'scripts' / 'tools')

# R1: an image context on the line (an image datablock, a node's .image, or a variable named like one) + a repoint
IMAGE_CTX = re.compile(r'images\s*[\[.]|\.image\b|\bimg\w*\b|\bimage\w*\b|\bim\b', re.I)
ASSIGN_PATH = re.compile(r'\.filepath(?:_raw)?\s*=(?!=)')
RENDER_PATH = re.compile(r'render\s*\.\s*filepath|\.render\b[^=\n]*\.filepath|\bscene\b[^=\n]*\.filepath|'
                         r'output_path|\.base_path|bake\w*\.filepath', re.I)
RELOAD = re.compile(r'\.reload\(\s*\)')
OPS = re.compile(r'bpy\.ops\.image\.(?:reload|replace)\b|setattr\([^,]+,\s*[\'"]filepath')
IMAGE_CODE = re.compile(r'bpy\.data\.images|\.image\b')   # the code handles images somewhere
ALLOW_R1 = re.compile(r'#\s*aop-allow-repoint:\s*(\S.{7,})')
# R2: blender_gate.py, then (in the same command) a pipe, or ; / || before a background Blender
_RUN_GATE = r'\bpy(?:thon)?[\w.]*\s+[^\n;&|]*?(?<![\w.-])blender_gate\.py'   # the gate RUN, not read or tested
GATE_PIPE = re.compile(_RUN_GATE + r'(?:[^\n;&|]|\d?>&\d)*\|(?!\|)')   # 2>&1 is a redirection, not a chain
GATE_UNCHECKED = re.compile(_RUN_GATE + r'[^\n]*?(?:;|\|\|)[^\n]*?\bblender(?:\.exe)?\b[^\n]*?(?:\s-b\b|--background)')
PIPEFAIL = re.compile(r'set\s+-o\s+pipefail|set\s+-\w*o\s+pipefail|PIPESTATUS')
ALLOW_R2 = re.compile(r'#\s*aop-allow-gate:\s*(\S.{7,})')
# R3: endless loops (INC-027). Each rule names what it found; the first hit's position decides whether a timeout wraps it.
# A command word starts the text or follows a blank, a separator, a quote (`eval '...'`, `bash -c "..."` in a process
# command line) or a path separator (/usr/bin/tail)
_START = r'(?:^|(?<=[\s;&|(`"\'\\/]))'
LOOP_RULES = (
    ('while/until loop with sleep', re.compile(r'\b(?:while|until)\b[\s\S]*?\bsleep\b', re.I)),
    ('endless while', re.compile(r'\bwhile\s*(?:\(\s*)?(?:\$?true|:|1)\s*\)?\s*(?:;|\n|\bdo\b|:|\{)|\buntil\s+false\b',
                                 re.I)),
    ('for (;;)', re.compile(r'\bfor\s*\(\(?\s*[^;()]*;\s*;')),       # an empty condition, with an init too
    ('for loop with sleep', re.compile(r'\bfor\s*(?:\(\([^)]*\)\)|\w+\s+in\b)[\s\S]*?\bdo\b[\s\S]*?\bsleep\b|'
                                       r'\b(?:for|foreach)\s*\([^)]*\)\s*\{[\s\S]*?\bsleep\b', re.I)),
    ('do-while loop', re.compile(r'\bdo\s*\{[\s\S]*?\}\s*(?:while|until)\b', re.I)),
    ('Get-Content -Wait', re.compile(r'\b(?:Get-Content|gc|cat|type)\b[^;|\n]*?\s-Wait\b', re.I)),
    ('recursive function', re.compile(r'(?:^|[\s;&|(])(?:function\s+)?([A-Za-z_][\w-]*)\s*(?:\(\s*\))?\s*\{'
                                      r'[^}]*(?<![\w-])\1(?![\w-])')),
    ('watch', re.compile(_START + r'watch(?:\.exe)?\s+-{1,2}[a-z]|'
                         r'(?:^|[;&|(\n`]|\bdo\b|\bthen\b|\bnohup\b)\s*watch(?:\.exe)?\s+[\w"\']', re.I)),
    ('tail -f', re.compile(_START + r'tail(?:\.exe)?\s+(?:[^;&|\n]*?\s)?'
                           r'(?:-[a-zA-Z0-9]*[fF][a-zA-Z0-9]*|--follow(?:=\w+)?)(?=[\s;&|)`\'"]|$)')),
    ('sleep infinity', re.compile(r'\bsleep\s+inf(?:inity)?\b', re.I)),
    ('ping -t', re.compile(r'\bping(?:\.exe)?\s+(?:[^;&|\n]*\s)?-t\b')),
    ('inotifywait -m', re.compile(r'\binotifywait\s+(?:[^;&|\n]*\s)?(?:-m|--monitor)\b')),
    ('setInterval', re.compile(r'\bsetInterval\s*\(')),
)
WATCH_PY = re.compile(r'watch\.py["\']?\s+start\b')          # an ancestor's command line runs the wrapper
# the wrapper as a COMMAND: python [opts] <path>watch.py start ... - it bounds its own check command, if nothing follows
WATCH_START = re.compile(r'(?:^|(?<=[\s;&|(]))["\']?py(?:thon)?[\w.]*(?:\.exe)?["\']?\s+(?:-[A-Za-z]\S*\s+)*'
                         r'["\']?[^\s;&|"\']*watch\.py["\']?\s+start\b')
B64 = re.compile(r'(?<![\w+/=])[A-Za-z0-9+/]{12,}={0,2}(?![\w+/=])')
DECODES = re.compile(r'\bbase64\s+(?:-\w*d\w*|--decode)\b|-(?:e|en|enc|encodedcommand)\s+[A-Za-z0-9+/=]{12,}', re.I)
DETACH = re.compile(r'\b(?:nohup|disown|setsid|Start-Job|Start-ThreadJob|Start-Process)\b', re.I)
SCRIPT_RUN = re.compile(r'(?:^|(?<=[\s;&|(]))(?:["\']?(?:py(?:thon)?[\w.]*(?:\.exe)?|bash|sh|zsh|pwsh|powershell)'
                        r'(?:\.exe)?["\']?\s+(?:-[-\w]+\s+)*|(?:\.|source)\s+|(?=\./))["\']?'   # run, not named
                        r'((?:[A-Za-z]:)?[^\s;&|"\'<>]*\.(?:py|sh|bash|ps1))["\']?(?=[\s;&|)]|$)', re.I)
CD = re.compile(r'(?:^|[;&|(]\s*|&&\s*)cd\s+(?:"([^"]+)"|\'([^\']+)\'|([^\s;&|]+))')
SCRIPT_MAX = 512 * 1024
TIMEOUT_WRAP = re.compile(_START + r'timeout(?:\.exe)?\s+(?:-{1,2}[a-zA-Z-]+(?:[= ]\s*[^\s-]\S*)?\s+)*'
                          r'(\d+(?:\.\d+)?)([smhd]?)(?=\s)')
LOOP_TIMEOUT_MAX_S = 3600    # a longer bound is a watch: tie it to its task with watch.py
_UNIT = {'': 1, 's': 1, 'm': 60, 'h': 3600, 'd': 86400}
ALLOW_R3 = re.compile(r'#\s*aop-allow-loop:\s*(\S.{7,})')

R1_TEXT = ('R1 raw repoint refused: this Blender code points an existing image at another file ({what}). That bypasses '
           'the review watcher (no snapshot, no Back, no preview gate, no 4-per-step reload limit). Register the maps '
           'with `python publish.py candidate <key> <dir>` and show them through the watcher: '
           "st = sys.modules['_aop_review_live_registry'].state; st.beta_show(key) (or start_preview). Loading a NEW "
           'image with bpy.data.images.load is fine. Deliberate and not the owner\'s review file: add a line '
           '`# aop-allow-repoint: <reason>` (logged).')
R2_TEXT = ('R2 gate bypass refused: {what}. A pipeline returns its LAST command\'s status, so a gate TIMEOUT (exit 3) '
           'would still launch Blender (journal 29-28). Chain it: `python blender_gate.py --timeout N && blender -b ...` '
           '(or `set -o pipefail`). Deliberate: add `# aop-allow-gate: <reason>` (logged).')
R3_TEXT = ('R3 endless background loop refused (INC-027: `while netstat ... LISTENING; do sleep 20; done` ran 32 h after '
           'its job ended): {what}. A background watch must end with its job: run it through the wrapper, '
           '`python .claude/hooks/watch.py start --task <KTC id> [--run <wf id>] --ttl 3h --every 20 '
           '--until-port-down 9876` (or --until-file PATH, or -- "<check command>"). It prints only state changes and '
           'ends at its TTL (max 12h), when the task ends, the run is unbound or the session is gone; '
           '`watch.py list` / `watch.py stop <id>`. A short wait may instead be bounded by a `timeout` of at most 1h '
           "that wraps the loop (`timeout 600 bash -c '...'`). Deliberate: add `# aop-allow-loop: <reason>` (logged).")


def utc_iso():
    return datetime.now(timezone.utc).isoformat(timespec='seconds')


def log_path():
    if os.environ.get('AOP_HARNESS_LOG'):
        return Path(os.environ['AOP_HARNESS_LOG'])
    if _TOOLS not in sys.path:
        sys.path.append(_TOOLS)
    import local_env
    return Path(local_env.tasks_dir()) / 'harness_log.jsonl'


def log(entry):
    rec = {'t': utc_iso(), 'hook': 'tool_guard'}
    rec.update(entry)
    try:
        p = log_path()
        p.parent.mkdir(parents=True, exist_ok=True)
        with open(p, 'a', encoding='utf-8', newline='\n') as f:
            f.write(json.dumps(rec, ensure_ascii=False, default=str) + '\n')
    except Exception:   # noqa: BLE001 - the log never breaks the tool call
        pass


def _code_lines(code):
    """(line number, line without its trailing # comment) for non-comment lines; strings are kept (rough but safe)"""
    for i, raw in enumerate(code.splitlines(), 1):
        s = raw.strip()
        if not s or s.startswith('#'):
            continue
        yield i, re.sub(r'\s+#[^\'"]*$', '', raw)


def check_repoint(code):
    """[what, ...] for every raw repoint in Blender code"""
    hits = []
    images = bool(IMAGE_CODE.search(code))
    for i, line in _code_lines(code):
        if ASSIGN_PATH.search(line) and not RENDER_PATH.search(line) and \
                (images or IMAGE_CTX.search(line.split('=')[0])):
            hits.append(f'line {i}: {line.strip()[:80]}')
        elif RELOAD.search(line) and (images or IMAGE_CTX.search(line)) and \
                not re.search(r'importlib|librar', line):
            hits.append(f'line {i}: {line.strip()[:80]}')
        elif OPS.search(line):
            hits.append(f'line {i}: {line.strip()[:80]}')
    return hits


def check_gate(command):
    if 'blender_gate' not in command or PIPEFAIL.search(command):
        return []
    hits = []
    if GATE_PIPE.search(command):
        hits.append('blender_gate.py output is piped')
    if GATE_UNCHECKED.search(command):
        hits.append('blender_gate.py is followed by ; or || before a background Blender')
    return hits


def _secs(m):
    return float(m.group(1)) * _UNIT[m.group(2).lower()]


def unquoted(text, chars=';&|\n'):
    """True when `text` holds one of `chars` outside quotes (a redirection 2>&1 / &> is not a separator)"""
    q, i = None, 0
    while i < len(text):
        c = text[i]
        if q:
            if c == '\\' and q == '"':
                i += 1
            elif c == q:
                q = None
        elif c in '"\'':
            q = c
        elif c == '\\':
            i += 1
        elif c in chars and not (c == '&' and ((i and text[i - 1] in '<>') or text[i + 1:i + 2] == '>')):
            return True
        i += 1
    return False


def watch_cut(command):
    """the text before a REAL `python .../watch.py start ...` that ends the command (its check command is the wrapper's,
    run with a timeout), else the whole command: `: watch.py start; while ...` or `watch.py start ...; while ...` keep
    their loop (INC-037)"""
    for m in WATCH_START.finditer(command):
        if not unquoted(command[m.end():]):
            return command[:m.start()]
    return command


def decoded(command):
    """the text the command decodes from base64 (`... | base64 -d`, powershell -EncodedCommand): scanned like the
    command itself (INC-037: eval of a base64 loop)"""
    import base64
    out = []
    if not DECODES.search(command):
        return out
    for tok in B64.findall(command):
        try:
            raw = base64.b64decode(tok + '=' * (-len(tok) % 4), validate=True)
        except ValueError:
            continue
        for enc in ('utf-8', 'utf-16-le'):
            try:
                t = raw.decode(enc)
            except UnicodeDecodeError:
                continue
            if t.isprintable() or '\n' in t:
                out.append(t)
                break
    return out


def check_loop(command):
    """[what, ...] for the endless loops in a background command; [] when there is none or a timeout (<= 1h) wraps
    the first one. The wrapper's own check command (after a real `watch.py start` that ends the command) is not
    counted; base64 text the command decodes is"""
    command = str(command or '')
    text = watch_cut(command)
    for t in decoded(text):
        inner = check_loop(t)
        if inner:
            return [f'encoded {h}' for h in inner]
    hits = sorted((m.start(), what, m.group(0)) for what, rx in LOOP_RULES for m in [rx.search(text)] if m)
    if not hits:
        return []
    first = hits[0][0]
    for m in TIMEOUT_WRAP.finditer(text):
        if m.start() >= first:
            break
        if 0 < _secs(m) <= LOOP_TIMEOUT_MAX_S and not re.search(r'[;&|\n]', text[m.end():first]):
            return []                           # `timeout 600 tail -f x`, `timeout 1h bash -c 'while ...'`
    out = []
    for _p, what, g in hits:
        g = ' '.join(g.split())
        out.append(f"{what} ({g[:60]}{'...' if len(g) > 60 else ''})")
    return out


def _background(v):
    return v is True or str(v).strip().lower() in ('true', '1', 'yes')


def detaches(cmd):
    """a foreground command that leaves something running after the call: a lone `&` (not &&, 2>&1, &>), nohup,
    disown, setsid, Start-Job / Start-Process (INC-037)"""
    return bool(DETACH.search(cmd)) or unquoted(cmd, '&') and bool(re.search(r'(?<![&<>|])&(?![&>])', cmd))


def _py_loops(src, name):
    """a Python file's loops: `while True` / `while 1`, and any while or for loop whose body sleeps"""
    import ast
    try:
        tree = ast.parse(src)
    except (SyntaxError, ValueError):
        return []
    hits = []
    for node in ast.walk(tree):
        if not isinstance(node, (ast.While, ast.For, ast.AsyncFor)):
            continue
        sleeps = any(isinstance(n, ast.Call) and ((isinstance(n.func, ast.Attribute) and n.func.attr == 'sleep') or
                                                  (isinstance(n.func, ast.Name) and n.func.id == 'sleep'))
                     for b in node.body for n in ast.walk(b))
        endless = isinstance(node, ast.While) and isinstance(node.test, ast.Constant) and bool(node.test.value)
        if endless or sleeps:
            kind = 'endless while' if endless else f"{'while' if isinstance(node, ast.While) else 'for'} loop with sleep"
            hits.append(f'{kind} in {name} line {node.lineno}')
    return hits


def scripts(cmd, cwd):
    """[(path, text)] of the .py / .sh / .ps1 files a command runs (relative to the call's cwd, or a `cd DIR` before
    it); the watch.py wrapper is not read (it bounds itself)"""
    out, base = [], Path(cwd) if cwd else None
    for m in SCRIPT_RUN.finditer(watch_cut(cmd)):
        name = m.group(1)
        if name.lower().endswith('watch.py'):
            continue
        cds = [next(g for g in c.groups() if g) for c in CD.finditer(cmd[:m.start()])]
        dirs = [Path(cds[-1]) if Path(cds[-1]).is_absolute() or base is None else base / cds[-1]] if cds else []
        for d in dirs + ([base] if base else []) + [Path.cwd()]:
            f = Path(name) if Path(name).is_absolute() else d / name
            try:
                if f.is_file() and f.stat().st_size <= SCRIPT_MAX:
                    out.append((f, f.read_text(encoding='utf-8', errors='replace')))
                    break
            except OSError:
                continue
    return out


def _r3(cmd, cwd=None):
    hits = check_loop(cmd)
    allow = ALLOW_R3.search(cmd)
    for f, text in scripts(cmd, cwd):
        found = _py_loops(text, f.name) if f.suffix.lower() == '.py' else \
            [f'{h} in {f.name}' for h in check_loop('\n'.join(ln for ln in text.splitlines()
                                                               if not ln.lstrip().startswith('#')))]
        if found:
            hits += found
            allow = allow or ALLOW_R3.search(text)
    if not hits:
        return 'allow', None, None, [], None
    if allow:
        return 'override', 'R3', None, hits, allow.group(1).strip()
    return 'deny', 'R3', R3_TEXT.format(what='; '.join(hits[:3])), hits, None


def evaluate(inp):
    """(decision, rule, reason, hits, override reason)"""
    tool = inp.get('tool_name') or ''
    ti = inp.get('tool_input') if isinstance(inp.get('tool_input'), dict) else {}
    if tool == BLENDER_TOOL:
        code = str(ti.get('code') or '')
        hits = check_repoint(code)
        if hits:
            m = ALLOW_R1.search(code)
            if m:
                return 'override', 'R1', None, hits, m.group(1).strip()
            return 'deny', 'R1', R1_TEXT.format(what='; '.join(hits[:3])), hits, None
    elif tool in SHELL_TOOLS:
        cmd = str(ti.get('command') or '')
        hits = check_gate(cmd) if tool == 'Bash' else []
        if hits:
            m = ALLOW_R2.search(cmd)
            if m:
                return 'override', 'R2', None, hits, m.group(1).strip()
            return 'deny', 'R2', R2_TEXT.format(what=' and '.join(hits)), hits, None
        if _background(ti.get('run_in_background')) or detaches(cmd):
            return _r3(cmd, inp.get('cwd'))
    elif tool == MONITOR_TOOL:
        return _r3(str(ti.get('command') or ''), inp.get('cwd'))
    return 'allow', None, None, [], None


def main():
    try:
        raw = sys.stdin.buffer.read().decode('utf-8', 'replace')
        inp = json.loads(raw) if raw.strip() else {}
        if not isinstance(inp, dict):
            return 0
        decision, rule, reason, hits, why = evaluate(inp)
        if decision == 'allow':
            return 0
        base = {'rule': rule, 'tool': inp.get('tool_name'), 'hits': hits[:5], 'session_id': inp.get('session_id'),
                'agent_id': inp.get('agent_id'), 'tool_use_id': inp.get('tool_use_id')}
        if (os.environ.get('AOP_TOOL_GUARD') or '').lower() in ('off', '0', 'false', 'disabled'):
            log(dict(base, decision='override', why='env AOP_TOOL_GUARD=off'))
            return 0
        if decision == 'override':
            log(dict(base, decision='override', why=why))
            return 0
        log(dict(base, decision='deny'))
        sys.stdout.write(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny',
                                                            'permissionDecisionReason': reason}}))
        return 0
    except Exception as e:  # noqa: BLE001 - fail open, logged
        log({'decision': 'error', 'error': f'{type(e).__name__}: {e}'})
        return 0


if __name__ == '__main__':
    sys.exit(main())
