// Curve evaluation and bone maths of the viewer (references/bundle-schema.md sections 2 and 11). Pure: no DOM, no GL,
// so node --test runs it (tests/js/skeleton.test.mjs, tests/js/parity/*.test.mjs).
//
// Conventions (the bundle's): row vectors, p' = p @ M; a 4x4 is 16 numbers row-major with the translation in 12..14;
// quaternions [x, y, z, w]; local 3x3 = R @ S (R the row-vector rotation of the quaternion, S the scale-shear as
// stored, full shear kept, never orthonormalised); W(bone) = L(bone) @ W(parent), root bones L @ model.root.
// A row-major row-vector matrix uploaded as a GLSL mat4 (column-major) is used as `M * vec4(p, 1)`.
// Numbers are JS doubles throughout, as the Python reference (gr2_curves.evaluate, float64); GPU uploads are float32.

export const IDENTITY = { 3: [0, 0, 0], 4: [0, 0, 0, 1], 9: [1, 0, 0, 0, 1, 0, 0, 0, 1] };
export const METHODS = ['bspline', 'knots'];
export const NORMALIZE = ['newton1', 'exact', 'none'];

// the engine's bone-name rule (unit_gr2.nm): a space equals an underscore, case-insensitive
export function nm(name) {
  return String(name).replace(/_/g, ' ').toLowerCase();
}

// clip_decode.bspline, operation for operation: the degree-p B-spline with knot K[m] and control C[m] per index.
// On [K[i-1], K[i]) the controls C[i-p..i] and the knot vector u_m = K[m-1] (indices clamped at both ends);
// t is clamped to [K[0], K[last]]; one knot = a constant. K: knots (n), C: controls flat (n * dim).
export function bspline(K, C, dim, degree, t, out = new Float64Array(dim)) {
  const n = K.length;
  if (n === 1 || n === 0) {
    for (let k = 0; k < dim; k++) out[k] = n ? C[k] : IDENTITY[dim] ? IDENTITY[dim][k] : 0;
    return out;
  }
  t = Math.min(Math.max(t, K[0]), K[n - 1]);
  let lo = 0, hi = n;                                   // first index whose knot is > t (numpy searchsorted 'right')
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (K[mid] <= t) lo = mid + 1; else hi = mid;
  }
  const i = Math.min(Math.max(lo, 1), n - 1);
  const p = degree | 0;
  const knot = (m) => K[Math.min(Math.max(m - 1, 0), n - 1)];
  const d = [];
  for (let j = 0; j <= p; j++) {
    const c = Math.min(Math.max(i - p + j, 0), n - 1) * dim;
    const v = new Float64Array(dim);
    for (let k = 0; k < dim; k++) v[k] = C[c + k];
    d.push(v);
  }
  for (let r = 1; r <= p; r++) {
    for (let j = p; j >= r; j--) {
      const a0 = knot(j + i - p), a1 = knot(j + 1 + i - r);
      const a = a1 === a0 ? 0.0 : (t - a0) / (a1 - a0);
      const dj = d[j], dm = d[j - 1];
      for (let k = 0; k < dim; k++) dj[k] = (1.0 - a) * dm[k] + a * dj[k];
    }
  }
  for (let k = 0; k < dim; k++) out[k] = d[p][k];
  return out;
}

// value of a prepared curve at t. method 'bspline' (the contract) or 'knots' (debug: every control a linear key at its
// knot = degree 1 when the curve's degree is above 1, as clip_decode.sample). Unavailable curves give the identity and
// set out.unavailable (the caller reports it).
export function evalCurve(curve, t, method = 'bspline', out) {
  const dim = curve.dim;
  out = out || new Float64Array(dim);
  if (curve.kind === 'bspline') {
    const deg = method === 'knots' && curve.degree > 1 ? 1 : curve.degree;
    return bspline(curve.knots, curve.controls, dim, deg, t, out);
  }
  const v = curve.kind === 'constant' ? curve.value : IDENTITY[dim];
  for (let k = 0; k < dim; k++) out[k] = v[k];
  return out;
}

export function normalizeQuat(q, rule = 'newton1') {
  if (rule === 'newton1') {
    const s = (3.0 - (q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3])) / 2.0;
    for (let k = 0; k < 4; k++) q[k] *= s;
  } else if (rule === 'exact') {
    const n = Math.hypot(q[0], q[1], q[2], q[3]) || 1.0;
    for (let k = 0; k < 4; k++) q[k] /= n;
  }
  return q;
}

// local 4x4 (row-major, row vectors) of a transform: upper 3x3 = R @ S, translation row = position
export function localMatrix(pos, q, ss, out = new Float64Array(16)) {
  const [x, y, z, w] = q;
  // column-vector rotation (clip_decode.q2m); the row-vector R is its transpose: R[r][c] = Q[c][r]
  const Q = [
    1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w),
    2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w),
    2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y),
  ];
  for (let r = 0; r < 3; r++) {
    for (let c = 0; c < 3; c++) {
      out[r * 4 + c] = Q[0 * 3 + r] * ss[0 * 3 + c] + Q[1 * 3 + r] * ss[1 * 3 + c] + Q[2 * 3 + r] * ss[2 * 3 + c];
    }
    out[r * 4 + 3] = 0;
  }
  out[12] = pos[0]; out[13] = pos[1]; out[14] = pos[2]; out[15] = 1;
  return out;
}

export function transformMatrix(tr, out) {
  return localMatrix(tr.position, tr.orientation, tr.scale_shear, out);
}

// C = A @ B for row-major 4x4s stored at offsets (C may not alias A or B)
export function mul4(A, B, out = new Float64Array(16), ao = 0, bo = 0, oo = 0) {
  for (let r = 0; r < 4; r++) {
    const a0 = A[ao + r * 4], a1 = A[ao + r * 4 + 1], a2 = A[ao + r * 4 + 2], a3 = A[ao + r * 4 + 3];
    for (let c = 0; c < 4; c++) {
      out[oo + r * 4 + c] = a0 * B[bo + c] + a1 * B[bo + 4 + c] + a2 * B[bo + 8 + c] + a3 * B[bo + 12 + c];
    }
  }
  return out;
}

export function identity4(out = new Float64Array(16)) {
  out.fill(0);
  out[0] = out[5] = out[10] = out[15] = 1;
  return out;
}

// general 4x4 inverse (row-major); returns null when singular
export function invert4(m, out = new Float64Array(16)) {
  const a = m;
  const b00 = a[0] * a[5] - a[1] * a[4], b01 = a[0] * a[6] - a[2] * a[4], b02 = a[0] * a[7] - a[3] * a[4];
  const b03 = a[1] * a[6] - a[2] * a[5], b04 = a[1] * a[7] - a[3] * a[5], b05 = a[2] * a[7] - a[3] * a[6];
  const b06 = a[8] * a[13] - a[9] * a[12], b07 = a[8] * a[14] - a[10] * a[12], b08 = a[8] * a[15] - a[11] * a[12];
  const b09 = a[9] * a[14] - a[10] * a[13], b10 = a[9] * a[15] - a[11] * a[13], b11 = a[10] * a[15] - a[11] * a[14];
  const det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;
  if (!det) return null;
  const d = 1.0 / det;
  out[0] = (a[5] * b11 - a[6] * b10 + a[7] * b09) * d;
  out[1] = (a[2] * b10 - a[1] * b11 - a[3] * b09) * d;
  out[2] = (a[13] * b05 - a[14] * b04 + a[15] * b03) * d;
  out[3] = (a[10] * b04 - a[9] * b05 - a[11] * b03) * d;
  out[4] = (a[6] * b08 - a[4] * b11 - a[7] * b07) * d;
  out[5] = (a[0] * b11 - a[2] * b08 + a[3] * b07) * d;
  out[6] = (a[14] * b02 - a[12] * b05 - a[15] * b01) * d;
  out[7] = (a[8] * b05 - a[10] * b02 + a[11] * b01) * d;
  out[8] = (a[4] * b10 - a[5] * b08 + a[7] * b06) * d;
  out[9] = (a[1] * b08 - a[0] * b10 - a[3] * b06) * d;
  out[10] = (a[12] * b04 - a[13] * b02 + a[15] * b00) * d;
  out[11] = (a[9] * b02 - a[8] * b04 - a[11] * b00) * d;
  out[12] = (a[5] * b07 - a[4] * b09 - a[6] * b06) * d;
  out[13] = (a[0] * b09 - a[1] * b07 + a[2] * b06) * d;
  out[14] = (a[13] * b01 - a[12] * b03 - a[14] * b00) * d;
  out[15] = (a[8] * b03 - a[9] * b01 + a[10] * b00) * d;
  return out;
}

export function transformPoint(p, M, mo = 0, out = new Float64Array(3)) {
  const x = p[0], y = p[1], z = p[2];
  out[0] = x * M[mo] + y * M[mo + 4] + z * M[mo + 8] + M[mo + 12];
  out[1] = x * M[mo + 1] + y * M[mo + 5] + z * M[mo + 9] + M[mo + 13];
  out[2] = x * M[mo + 2] + y * M[mo + 6] + z * M[mo + 10] + M[mo + 14];
  return out;
}

// world matrices (n * 16) from locals (n * 16): W(b) = L(b) @ W(parent), root bones L @ root; parents in any order
export function composeWorld(locals, parents, root, out) {
  const n = parents.length;
  out = out || new Float64Array(n * 16);
  const done = new Uint8Array(n);
  const visit = (i, depth) => {
    if (done[i]) return;
    const p = parents[i];
    if (p < 0 || p >= n || depth > n) {
      mul4(locals, root, out, i * 16, 0, i * 16);
    } else {
      visit(p, depth + 1);
      mul4(locals, out, out, i * 16, p * 16, i * 16);
    }
    done[i] = 1;
  };
  for (let i = 0; i < n; i++) visit(i, 0);
  return out;
}

// engine bone-name matching of animfile.match_bone: exact (nm) first, then the inferred engine alias that drops a
// leading 'bip01 ' / 'bone ' (R HAND = Bip01_R_Hand, ATTACHPOINT = bone_attachpoint). -> {index, match} | null
const BONE_PREFIXES = ['bip01 ', 'bone '];
function aliasOf(name) {
  const k = nm(name).trim();
  for (const p of BONE_PREFIXES) if (k.startsWith(p)) return k.slice(p.length);
  return k;
}
export function matchBone(name, names) {
  if (!name) return null;
  const key = nm(name).trim();
  for (let i = 0; i < names.length; i++) if (nm(names[i]).trim() === key) return { index: i, match: 'exact' };
  const short = aliasOf(name);
  const hits = [];
  for (let i = 0; i < names.length; i++) if (aliasOf(names[i]) === short) hits.push(i);
  if (hits.length) return { index: hits[0], match: hits.length === 1 ? 'alias' : 'alias-ambiguous' };
  return null;
}
