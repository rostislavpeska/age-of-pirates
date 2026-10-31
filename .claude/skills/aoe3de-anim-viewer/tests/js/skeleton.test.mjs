// node --test: viewer/lib/skeleton.js maths on hand-computed cases (no fixtures, no browser).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  nm, bspline, evalCurve, normalizeQuat, localMatrix, mul4, invert4, identity4, composeWorld, transformPoint, matchBone,
} from '../../viewer/lib/skeleton.js';

const close = (a, b, tol = 1e-12) => Array.from(a).every((x, i) => Math.abs(x - b[i]) < tol);

test('bone names match as the engine does', () => {
  assert.equal(nm('Bip01_R_Hand'), nm('bip01 r hand'));
  assert.deepEqual(matchBone('R HAND', ['Bip01_Root', 'Bip01_R_Hand']), { index: 1, match: 'alias' });
  assert.deepEqual(matchBone('ATTACHPOINT', ['root_x', 'bone_attachpoint']), { index: 1, match: 'alias' });
  assert.deepEqual(matchBone('bip01 pelvis', ['Bip01_Pelvis']), { index: 0, match: 'exact' });
  assert.equal(matchBone('hotspot', ['Bip01_Root']), null);
  assert.equal(matchBone('', ['a']), null);
});

test('B-spline: constants, linear keys, clamping and degree 2 blending', () => {
  const K = [0, 1, 2], C1 = [0, 10, 20];
  assert.deepEqual(Array.from(bspline([0], [5], 1, 2, 3)), [5]);
  assert.deepEqual(Array.from(bspline(K, C1, 1, 1, 0.5)), [5]);           // degree 1 = linear between keys
  assert.deepEqual(Array.from(bspline(K, C1, 1, 1, -4)), [0]);            // clamped to the first knot
  assert.deepEqual(Array.from(bspline(K, C1, 1, 1, 9)), [20]);            // and to the last
  assert.deepEqual(Array.from(bspline(K, C1, 1, 0, 1.5)), [20]);          // degree 0: the control of [K[i-1], K[i])
  // degree 2 on [K1, K2): controls C0..C2, knots K0..K3 clamped -> at t=1.5: (1-a)(1-o)C0 + ... (clip_decode order)
  const v = bspline([0, 1, 2, 3], [0, 0, 1, 0], 1, 2, 1.5)[0];
  assert.ok(Math.abs(v - 0.125) < 1e-12, String(v));           // clip_decode.bspline gives 0.125
  const curve = { kind: 'bspline', dim: 1, degree: 2, knots: [0, 1, 2, 3], controls: [0, 0, 1, 0] };
  assert.ok(Math.abs(evalCurve(curve, 1.5, 'knots')[0] - 0.5) < 1e-12);  // knots-linear debug view
  assert.deepEqual(Array.from(evalCurve({ kind: 'identity', dim: 4 }, 0)), [0, 0, 0, 1]);
  assert.deepEqual(Array.from(evalCurve({ kind: 'unavailable', dim: 3 }, 0)), [0, 0, 0]);
  assert.deepEqual(Array.from(evalCurve({ kind: 'constant', dim: 3, value: [1, 2, 3] }, 7)), [1, 2, 3]);
});

test('one Newton step normalises a near-unit quaternion', () => {
  const q = normalizeQuat(Float64Array.from([0, 0, 0, 1.01]));
  assert.ok(Math.abs(q[3] - 1.01 * (3 - 1.0201) / 2) < 1e-15);
  assert.ok(Math.abs(Math.hypot(...normalizeQuat(Float64Array.from([0.3, 0.1, 0, 0.95]))) - 1) < 1e-3);
  assert.ok(close(normalizeQuat(Float64Array.from([0, 0, 0, 2]), 'exact'), [0, 0, 0, 1]));
});

test('local matrix: row-vector rotation then scale-shear, translation row', () => {
  const s = Math.SQRT1_2;
  const M = localMatrix([1, 2, 3], [0, 0, s, s], [2, 0, 0, 0, 1, 0, 0, 0, 1]);     // 90 deg about +Z, x scaled by 2
  // p @ R: (1,0,0) -> (0,1,0); then @ S scales x only: (0,1,0)
  assert.ok(close(transformPoint([1, 0, 0], M), [1, 3, 3], 1e-12));
  assert.ok(close(transformPoint([0, 1, 0], M), [-1, 2, 3], 1e-12));   // (0,1,0) @ R = (-1,0,0); @ S = (-2,0,0); + t
  assert.ok(close([M[12], M[13], M[14]], [1, 2, 3]));
});

test('composition, inverse and parent order', () => {
  const A = localMatrix([0, 1, 0], [0, 0, 0, 1], [1, 0, 0, 0, 1, 0, 0, 0, 1]);
  const B = localMatrix([1, 0, 0], [0, Math.sin(0.3), 0, Math.cos(0.3)], [1, 0.1, 0, 0, 1, 0, 0, 0, 1]);
  const L = new Float64Array(32);
  L.set(B, 0);                                       // bone 0 is the child, listed before its parent
  L.set(A, 16);
  const W = composeWorld(L, Int32Array.from([1, -1]), identity4());
  assert.ok(close(W.subarray(0, 16), mul4(B, A), 1e-15));
  assert.ok(close(W.subarray(16), A));
  assert.ok(close(mul4(invert4(B), B), identity4(), 1e-12));
  assert.equal(invert4(new Float64Array(16)), null);
});
