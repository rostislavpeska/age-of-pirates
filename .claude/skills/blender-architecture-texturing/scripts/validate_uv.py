"""Read-only UV-region and regression check. python validate_uv.py before after manifest"""
import json
import math
import sys


def validate(before, after, manifest):
    errors = []
    checked = 0
    total = 0
    if set(before['objects']) != set(after['objects']):
        errors.append('Object set changed')
    for name, old in before['objects'].items():
        new = after['objects'].get(name)
        if new is None:
            continue
        allowed = manifest.get('objects', {}).get(name, {}).get('faces', {})
        if old['vertices'] != new['vertices']:
            errors.append(f'{name}: vertex positions changed')
        if len(old['faces']) != len(new['faces']):
            errors.append(f'{name}: face count changed')
            continue
        for index in allowed:
            if not index.isdigit() or int(index) >= len(new['faces']):
                errors.append(f'{name}: invalid assigned face {index}')
        for i, (a, b) in enumerate(zip(old['faces'], new['faces'])):
            total += 1
            label = f'{name}:{i}'
            if a['vertices'] != b['vertices']:
                errors.append(f'{label}: topology changed')
            if len(b['uv']) != len(b['vertices']):
                errors.append(f'{label}: loop count mismatch')
            region_name = allowed.get(str(i))
            if region_name is None:
                if a != b:
                    errors.append(f'{label}: unrelated face changed')
                continue
            region = manifest.get('regions', {}).get(region_name)
            if region is None:
                errors.append(f'{label}: missing region {region_name}')
                continue
            checked += 1
            if b['material'] != region['material']:
                errors.append(f'{label}: wrong material')
            x0, y0, x1, y1 = region['bounds']
            w, h = region.get('size', [2048, 2048])
            pad = region.get('padding_px', 0)
            x0 += pad / w
            x1 -= pad / w
            y0 += pad / h
            y1 -= pad / h
            if x0 > x1 or y0 > y1:
                errors.append(f'{label}: invalid inset region')
                continue
            for u, v in b['uv']:
                if not (math.isfinite(u) and math.isfinite(v) and
                        x0 - 1e-7 <= u <= x1 + 1e-7 and y0 - 1e-7 <= v <= y1 + 1e-7):
                    errors.append(f'{label}: UV outside {region_name}')
                    break
    for name in manifest.get('objects', {}):
        if name not in after['objects']:
            errors.append(f'{name}: assigned object missing')
    return {'passed': not errors, 'assigned_faces_checked': checked,
            'total_faces': total, 'unassigned_faces': total - checked, 'errors': errors}


if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit('Usage: validate_uv.py BEFORE.json AFTER.json MANIFEST.json')
    result = validate(*(json.load(open(p, encoding='utf-8')) for p in sys.argv[1:]))
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['passed'] else 1)
