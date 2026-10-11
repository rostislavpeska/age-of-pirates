"""Pure-Python helpers for the organic checks: 8-bit weight quantization, side-token bone pairing and name lists.

No bpy: imported by organic_audit.py inside Blender and by the pure tests on any Python 3.9+.
"""
import json
import math
import re
from pathlib import Path

QUANT_TOTAL = 255

# ---------------------------------------------------------------- 8-bit weights


def quantize(weights, total=QUANT_TOTAL):
    """Quantize one vertex's influences to integers that sum to `total` (skinning-pose-tests section 4).

    weights: iterable of (bone, weight) with weight > 0, any sum.
    1. drop influences below 0.5/total and renormalize;
    2. q = floor(total x w), then one unit at a time to the largest fractional parts (largest remainder);
    3. a kept influence that ended at 0 takes one unit from the largest entry (only weights under 1/total can);
    4. return [(bone, q), ...] in descending q (ties: larger weight first, then name).
    Error per influence stays within 1/total except where step 3 acts. Giving every influence 1 unit before the
    share instead costs the largest weight up to about (n - 1)/total (3/255 measured on the 4-influence test
    body), so it is not used.
    Returns (entries, dropped_bones).
    """
    items = [(b, float(w)) for b, w in weights if w > 0]
    if not items:
        return [], []
    s = sum(w for _, w in items)
    floor_w = 0.5 / total
    kept = [(b, w / s) for b, w in items if w / s >= floor_w]
    dropped = [b for b, w in items if w / s < floor_w]
    if not kept:
        return [], dropped
    if len(kept) > total:
        raise ValueError('more influences than units')
    s = sum(w for _, w in kept)
    kept = [(b, w / s) for b, w in kept]
    q = {b: int(math.floor(total * w)) for b, w in kept}
    left = total - sum(q.values())
    order = sorted(kept, key=lambda t: (-(total * t[1] - math.floor(total * t[1])), -t[1], t[0]))
    for b, _ in order[:left]:
        q[b] += 1
    weight = dict(kept)
    for b in [b for b, v in q.items() if v == 0]:
        top = max(q, key=lambda k: (q[k], weight[k]))
        q[top] -= 1
        q[b] += 1
    entries = sorted(q.items(), key=lambda t: (-t[1], -weight[t[0]], t[0]))
    return entries, dropped


def check_quantized(entries, total=QUANT_TOTAL):
    """Problems of one quantized vertex [(bone, q), ...]: sum, zero slots in use, order, duplicates."""
    problems = []
    if not entries:
        return ['no influence']
    qs = [int(q) for _, q in entries]
    if sum(qs) != total:
        problems.append('sum %d != %d' % (sum(qs), total))
    if any(q <= 0 for q in qs):
        problems.append('influence at 0')
    if qs != sorted(qs, reverse=True):
        problems.append('not descending')
    bones = [b for b, _ in entries]
    if len(set(bones)) != len(bones):
        problems.append('bone twice')
    return problems


def quantization_error(weights, entries, total=QUANT_TOTAL):
    """Largest |q/total - w| over the vertex's influences, weights renormalized first."""
    s = sum(w for _, w in weights) or 1.0
    w = {b: x / s for b, x in weights}
    q = {b: x / total for b, x in entries}
    return max((abs(q.get(b, 0.0) - w.get(b, 0.0)) for b in set(w) | set(q)), default=0.0)


# ---------------------------------------------------------------- left/right bone names

_SEP = re.compile(r'([ _.\-:|])')
_SWAP = {'l': 'r', 'r': 'l', 'left': 'right', 'right': 'left'}
_CAMEL = re.compile(r'^(Left|Right|LEFT|RIGHT|left|right)(?=[A-Z0-9])')


def _swap_token(tok):
    low = tok.lower()
    if low in _SWAP:
        new = _SWAP[low]
        if tok.isupper():
            return new.upper()
        if tok[0].isupper():
            return new.capitalize()
        return new
    m = _CAMEL.match(tok)
    if m:
        return _swap_token(m.group(1)) + tok[len(m.group(1)):]
    return None


def mirror_name(name):
    """(partner, has_side): swap every left/right token wherever it sits in the name.

    Tokens are split at space, '_', '.', '-', ':' and '|': Bip01_L_Thigh <-> Bip01_R_Thigh, Bip01 L Thigh,
    Thigh.L, L_Thigh, LeftArm (camel prefix after a separator). A name without a side token is a centre name
    and its own partner. Blender's bpy.utils.flip_name only sees a marker at the start, the end or after the
    last separator, so mid-name markers need this explicit map.
    """
    parts = _SEP.split(name)
    has_side = False
    out = []
    for i, tok in enumerate(parts):
        if i % 2 == 0 and tok:
            new = _swap_token(tok)
            if new is not None:
                has_side = True
                out.append(new)
                continue
        out.append(tok)
    return ''.join(out), has_side


def side_suffix(name):
    """True for a temporary Blender-style side suffix (.L/.R/.l/.r) that a mirror rename can leave behind."""
    return bool(re.search(r'\.(L|R|l|r)$', name))


# ---------------------------------------------------------------- name lists


def parse_name_list(arg):
    """Names from 'A,B,C' or '@file' (.json list or {"bones": [...]}, else text: one per line, '#' comments).

    Names are exact strings; surrounding whitespace is stripped only in comma and text forms.
    """
    if arg is None:
        return None
    if arg.startswith('@'):
        path = Path(arg[1:])
        text = path.read_text(encoding='utf-8-sig')
        if path.suffix.lower() == '.json':
            data = json.loads(text)
            if isinstance(data, dict):
                data = data.get('bones', data.get('allowed', []))
            return [str(x) for x in data]
        names = []
        for line in text.splitlines():
            line = line.split('#', 1)[0].strip()
            if line:
                names.append(line)
        return names
    return [x.strip() for x in arg.split(',') if x.strip()]


def histogram(counts):
    """{influence count: vertices} with integer keys sorted."""
    h = {}
    for c in counts:
        h[c] = h.get(c, 0) + 1
    return dict(sorted(h.items()))
