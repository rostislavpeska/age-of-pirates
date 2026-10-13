"""Replay 8-bit native candidate-minus-baseline deltas within a binary scope.
Audit: 2026-10-13-codex-roof-pattern-48. No renderer, bake or art tuning.
"""
import argparse
import hashlib
import json
import shutil
import time
from pathlib import Path
import numpy as np
from PIL import Image


def apply_delta(source, before, after, scope, channels):
    if source.dtype != np.uint8 or before.dtype != np.uint8 or after.dtype != np.uint8:
        raise ValueError('Only explicit uint8 inputs are supported')
    if before.ndim == 2:
        before, after = before[:, :, None], after[:, :, None]
    if before.shape != after.shape or source.shape[:2] != before.shape[:2] or scope.shape != source.shape[:2]:
        raise ValueError('Input dimensions differ')
    if scope.dtype != bool or len(set(channels)) != len(channels) or any(c < 0 or c >= source.shape[2] for c in channels):
        raise ValueError('Invalid scope or channel mapping')
    if before.shape[2] < len(channels):
        raise ValueError('Not enough native channels')
    out = source.copy()
    for i, channel in enumerate(channels):
        delta = after[:, :, i].astype(np.int16) - before[:, :, i].astype(np.int16)
        values = np.clip(source[:, :, channel].astype(np.int16) + delta, 0, 255).astype(np.uint8)
        out[:, :, channel][scope] = values[scope]
    return out


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def replay(recipe_path, root, out, source_dir=None):
    started = time.monotonic()
    recipe_path, root, out = Path(recipe_path), Path(root).resolve(), Path(out)
    recipe = json.loads(recipe_path.read_text(encoding='utf-8'))
    inputs = {}
    def read(relative, rgba=False):
        path = (root / relative).resolve()
        if not path.is_relative_to(root):
            raise ValueError('Recipe input escapes its root')
        inputs[relative] = digest(path)
        with Image.open(path) as im:
            return np.array(im.convert('RGBA') if rgba else im)
    raw_scope = read(recipe['scope'])
    if raw_scope.ndim != 2 or not np.isin(raw_scope, [0, 255]).all():
        raise ValueError('Scope must be an unambiguous binary grayscale map')
    scope = raw_scope == 255
    out.mkdir(parents=True, exist_ok=False)
    results = {}
    for row in recipe['maps']:
        name = row['name']
        if Path(name).name != name or not name.endswith('.png'):
            raise ValueError('Invalid output filename')
        if source_dir:
            src_path = Path(source_dir) / name
            inputs['source_override/' + name] = digest(src_path)
            with Image.open(src_path) as im:
                source = np.array(im.convert('RGBA'))
        else:
            src_path = root / row['source']
            source = read(row['source'], True)
        if row.get('channels'):
            result = apply_delta(source, read(row['before']), read(row['after']), scope, row['channels'])
            Image.fromarray(result).save(out / name)
        else:
            result = source
            shutil.copy2(src_path, out / name)
        reference = read(row['reference'], True)
        if result.shape != reference.shape:
            raise ValueError('Reference dimensions differ')
        changed = np.any(result != source, axis=2)
        diff = np.any(result != reference, axis=2)
        results[name] = {'changed_pixels': int(changed.sum()), 'outside_scope_changed': int(changed[~scope].sum()),
                         'reference_different_pixels': int(diff.sum()), 'sha256': digest(out / name)}
    receipt = {'status': 'PASS' if all(r['reference_different_pixels'] == 0 for r in results.values()) else 'MISMATCH',
               'scope': 'Composite stage only; native authoring and upstream replay not proven',
               'recipe_sha256': digest(recipe_path), 'tool_sha256': digest(Path(__file__)), 'input_sha256': inputs,
               'maps': results, 'elapsed_s': round(time.monotonic() - started, 3), 'new_bakes': 0, 'native_runs': 0}
    (out / 'REPLAY.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recipe', required=True)
    parser.add_argument('--root', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('--source-dir')
    args = parser.parse_args()
    report = replay(args.recipe, args.root, args.out, args.source_dir)
    print(json.dumps({k: v for k, v in report.items() if k != 'input_sha256'}))
    raise SystemExit(0 if report['status'] == 'PASS' else 2)
