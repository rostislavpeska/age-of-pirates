"""AO compatibility for conjoinment: may this member share its owner's baked AO?

Faces carry measured AO samples in their own development coordinates:
    face['ao'] = [[x_texels, y_texels, ao], ...]      (ao: 0 = black, 1 = open)
A chart's AO fingerprint is those samples binned onto a BINS x BINS grid in the
chart's normalised minimum-rectangle frame (the frame conjoin.py maps in). A member
is compared with its candidate owner under the exact candidate map M.

Approaches (return True = compatible, keep/merge):
  D1 'mean'   |mean_m - mean_o| <= t_mean                      darkness only
  D2 'p95'    95th percentile of |m - o| over bins <= t_p95     darkness + local shadow
  D3 'ssim'   mean check and, where either side has structure (std > s_min),
              SSIM(m, o) >= t_ssim                              occlusion SHAPE
  D4 'class'  same darkness class (dark < .55 <= mid < .8 <= light) and same
              'has shadow shape' flag (p90 - p10 > .2)          coarse classes
"""
import math
import numpy as np

BINS = 6
DEFAULTS = dict(t_mean=.06, t_p95=.15, t_ssim=.5, s_min=.05, dark=.55, light=.8, shape=.2)


def fingerprint(chart, bins=BINS):
    """Mean AO per bin in the chart's normalised frame; NaN where no sample fell."""
    if 'ao_fp' in chart:
        return chart['ao_fp']
    N = chart['N']; L, W = chart['L'], chart['W']
    s = np.zeros((bins, bins)); c = np.zeros((bins, bins)); allv = []
    for f in chart['faces']:
        for x, y, a in f.get('ao', []):
            u = N[0, 0] * x + N[0, 1] * y + N[0, 2]; v = N[1, 0] * x + N[1, 1] * y + N[1, 2]
            i = min(bins - 1, max(0, int(u / L * bins))); j = min(bins - 1, max(0, int(v / W * bins)))
            s[j, i] += a; c[j, i] += 1; allv.append(a)
    fp = np.where(c > 0, s / np.maximum(c, 1), np.nan)
    chart['ao_fp'] = fp
    chart['ao_all'] = np.asarray(allv) if allv else np.asarray([np.nan])
    return fp


def mapped_pairs(m, o, M, bins=BINS):
    """(member bin value, owner bin value) at corresponding positions under map M."""
    fm, fo = fingerprint(m, bins), fingerprint(o, bins)
    out = []
    for j in range(bins):
        for i in range(bins):
            a = fm[j, i]
            if np.isnan(a):
                continue
            x = (i + .5) / bins * m['L']; y = (j + .5) / bins * m['W']
            X = M[0, 0] * x + M[0, 1] * y + M[0, 2]; Y = M[1, 0] * x + M[1, 1] * y + M[1, 2]
            I = int(X / o['L'] * bins); J = int(Y / o['W'] * bins)
            if 0 <= I < bins and 0 <= J < bins and not np.isnan(fo[J, I]):
                out.append((a, fo[J, I]))
    return np.asarray(out) if out else np.zeros((0, 2))


def _ssim(a, b):
    c1, c2 = .01 ** 2, .03 ** 2
    ma, mb = a.mean(), b.mean(); va, vb = a.var(), b.var(); cov = ((a - ma) * (b - mb)).mean()
    return ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma * ma + mb * mb + c1) * (va + vb + c2))


def compatible(m, o, M, method='p95', p=None):
    p = dict(DEFAULTS, **(p or {}))
    pr = mapped_pairs(m, o, M)
    if len(pr) == 0:   # no overlapping evidence: fall back to whole-chart means
        fingerprint(m); fingerprint(o)
        am, ao = np.nanmean(m['ao_all']), np.nanmean(o['ao_all'])
        if np.isnan(am) or np.isnan(ao):
            return True
        return abs(am - ao) <= p['t_mean']
    a, b = pr[:, 0], pr[:, 1]
    if method == 'mean':
        return abs(a.mean() - b.mean()) <= p['t_mean']
    if method == 'p95':
        return float(np.percentile(np.abs(a - b), 95)) <= p['t_p95']
    if method == 'ssim':
        if abs(a.mean() - b.mean()) > p['t_mean']:
            return False
        if len(a) < 4 or max(a.std(), b.std()) <= p['s_min']:
            return True
        return _ssim(a, b) >= p['t_ssim']
    if method == 'class':
        cls = lambda x: 0 if x < p['dark'] else 1 if x < p['light'] else 2
        shp = lambda v: (np.percentile(v, 90) - np.percentile(v, 10)) > p['shape']
        fingerprint(m); fingerprint(o)
        am, ao = m['ao_all'][~np.isnan(m['ao_all'])], o['ao_all'][~np.isnan(o['ao_all'])]
        if len(am) == 0 or len(ao) == 0:
            return True
        return cls(am.mean()) == cls(ao.mean()) and shp(am) == shp(ao)
    raise ValueError(method)
