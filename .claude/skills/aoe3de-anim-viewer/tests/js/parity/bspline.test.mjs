// node --test: viewer/lib/skeleton.js curve evaluation against the Python reference (gr2_curves.evaluate =
// aoe3de-unit-model clip_decode.bspline) on curves that tests/test_parity_js.py generates and evaluates in Python
// (AV_BSPLINE_FIXTURE). Both methods (bspline, knots), degrees 0..3, dims 3/4/9, repeated knots, times outside the knot
// range; the Newton-step quaternion normalisation against gr2_curves.normalize_quaternion. Tolerance 1e-6.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { evalCurve, normalizeQuat } from '../../../viewer/lib/skeleton.js';
import { readFixture, maxAbsDiff } from './disk.mjs';

test('B-spline and knots-linear evaluation equal Python within 1e-6', async (t) => {
  const fx = await readFixture('AV_BSPLINE_FIXTURE');
  if (!fx) return t.skip('AV_BSPLINE_FIXTURE not set (run through tests/test_parity_js.py)');
  let worst = 0, n = 0;
  for (const c of fx.curves) {
    const curve = { kind: 'bspline', dim: c.dim, degree: c.degree, knots: Float32Array.from(c.knots),
      controls: Float32Array.from(c.controls) };
    for (const method of ['bspline', 'knots']) {
      c.times.forEach((tt, i) => {
        const got = evalCurve(curve, tt, method);
        const want = c.expect[method][i];
        const d = maxAbsDiff(got, want);
        worst = Math.max(worst, d);
        n++;
        assert.ok(d < fx.tolerance, `curve ${c.id} ${method} t=${tt}: ${d}`);
      });
    }
  }
  for (const q of fx.quaternions) {
    const got = normalizeQuat(Float64Array.from(q.q), 'newton1');
    const d = maxAbsDiff(got, q.newton1);
    worst = Math.max(worst, d);
    assert.ok(d < fx.tolerance, `quaternion ${q.q}: ${d}`);
  }
  console.log(`# bspline parity: ${n} evaluations, ${fx.quaternions.length} quaternions, max |JS - Python| ${worst}`);
});
