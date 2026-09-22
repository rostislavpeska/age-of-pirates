"""Verify bundled reference text against recorded LF-normalized SHA-256 hashes.

This proves packaging integrity, not current game API/schema completeness.
"""
import hashlib
import json
from pathlib import Path


def check(root):
    refs = root / 'references'
    entries = json.loads((refs / 'sources.json').read_text(encoding='utf-8'))['entries']
    errors = []
    for item in entries:
        path = refs / item['file']
        if not path.is_file():
            errors.append('Missing reference: ' + item['file'])
            continue
        data = path.read_text(encoding='utf-8').encode('utf-8')
        if hashlib.sha256(data).hexdigest() != item['normalizedSha256']:
            errors.append('Reference content changed: ' + item['file'])
    return errors


if __name__ == '__main__':
    errors = check(Path(__file__).resolve().parents[1])
    if errors:
        raise SystemExit('\n'.join(errors))
    print('All four reference texts match the recorded content; current-build coverage remains unverified.')
