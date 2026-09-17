"""Claude Code PostToolUse hook (Write / Edit / MultiEdit): if the written file is runtime XML the engine parses from the
mod folder (art/, sound/, data/: .xml .material .lgt .tactics .xs), make sure it is CRLF. LF-only art XML is silently
ignored by the game (Tower of London, 2026-09-17: unit places, model never renders). Reads the hook JSON on stdin,
converts in place, prints a one-line note. Never blocks the tool call."""
import json, os, sys

EXT = ('.xml', '.material', '.lgt', '.tactics', '.xs')


def main():
    try: payload = json.load(sys.stdin)
    except Exception: return 0
    ti = payload.get('tool_input') or {}
    paths = [ti.get('file_path')] if ti.get('file_path') else []
    for e in ti.get('edits') or []:
        if isinstance(e, dict) and e.get('file_path'): paths.append(e['file_path'])
    root = os.path.abspath(payload.get('cwd') or os.getcwd())
    for p in paths:
        if not p or not p.lower().endswith(EXT) or not os.path.isfile(p): continue
        rel = os.path.relpath(os.path.abspath(p), root).replace('\\', '/')
        if not rel.split('/')[0].lower() in ('art', 'sound', 'data'): continue
        b = open(p, 'rb').read()
        lone = b.count(b'\n') - b.count(b'\r\n')
        if lone:
            open(p, 'wb').write(b.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n'))
            print(f'[art-eol hook] {rel}: {lone} LF-only line(s) converted to CRLF (engine ignores LF art XML)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
