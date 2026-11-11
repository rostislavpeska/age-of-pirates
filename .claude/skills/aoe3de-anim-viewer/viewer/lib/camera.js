// Cameras of the viewer. Pure (node --test: tests/js/camera.test.mjs). Matrices here are GL-style column-major
// Float32Arrays used as `P * V * D * p`, unlike the bone matrices (row-major row vectors, skeleton.js).
//
// Frames:
// - engine (the gr2 frame, +Y up): left-handed, ArtToolInfo Right -X, Up +Y, Back +Z.
// - display (what GL draws, right-handed, +Y up) = engine with x negated: DISPLAY = diag(-1, 1, 1). Drawn so, a unit
//   looks as in the converter's GXO frame and in Blender (unit_gr2 frame A, det -1), not mirrored. Triangle winding
//   flips with it; the viewer draws both faces.
// - gxo (the converter / pose_sim / Blender OBJ frame, +Z up): gxo = (-ex, -ez, ey) * units (unit_gr2.to_gxo_point).
//
// Game camera: pitch 47 degrees below the horizon by default (game.cfg limitPitch=47; meaning unverified), orbit
// heading, distance and FOV free - the game's FOV and distance are UNKNOWN until calibration (design section 8 item 1).

export const GAME_PITCH = 47;
export const DEFAULT_FOV = 30;          // degrees, vertical: a placeholder (unknown, labelled U)
export const DISPLAY = new Float32Array([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

const RAD = Math.PI / 180;

export function engineToDisplay(p) { return [-p[0], p[1], p[2]]; }
export function gxoToDisplay(g) { return [g[0], g[2], -g[1]]; }
export function engineToGxo(p, units = 1) { return [-p[0] * units, -p[2] * units, p[1] * units]; }
export function gxoToEngine(g, units = 1) { return [-g[0] / units, g[2] / units, -g[1] / units]; }

function sub(a, b) { return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]; }
function cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; }
function norm(a) { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; }
function dot(a, b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }

export function perspective(fovyDeg, aspect, near, far) {
  const f = 1 / Math.tan((fovyDeg * RAD) / 2), nf = 1 / (near - far);
  return new Float32Array([f / aspect, 0, 0, 0, 0, f, 0, 0, 0, 0, (far + near) * nf, -1, 0, 0, 2 * far * near * nf, 0]);
}

export function ortho(l, r, b, t, n, f) {
  return new Float32Array([2 / (r - l), 0, 0, 0, 0, 2 / (t - b), 0, 0, 0, 0, -2 / (f - n), 0,
    -(r + l) / (r - l), -(t + b) / (t - b), -(f + n) / (f - n), 1]);
}

export function lookAt(eye, target, up) {
  const z = norm(sub(eye, target));
  let x = cross(up, z);
  if (Math.hypot(...x) < 1e-9) x = cross([0, 0, 1], z);
  x = norm(x);
  const y = cross(z, x);
  return new Float32Array([x[0], y[0], z[0], 0, x[1], y[1], z[1], 0, x[2], y[2], z[2], 0,
    -dot(x, eye), -dot(y, eye), -dot(z, eye), 1]);
}

// column-major a * b
export function mulCM(a, b) {
  const o = new Float32Array(16);
  for (let c = 0; c < 4; c++) {
    for (let r = 0; r < 4; r++) {
      o[c * 4 + r] = a[r] * b[c * 4] + a[4 + r] * b[c * 4 + 1] + a[8 + r] * b[c * 4 + 2] + a[12 + r] * b[c * 4 + 3];
    }
  }
  return o;
}

// project a display-space point with a column-major matrix -> [x, y, z, w]
export function projectCM(m, p) {
  const [x, y, z] = p;
  return [m[0] * x + m[4] * y + m[8] * z + m[12], m[1] * x + m[5] * y + m[9] * z + m[13],
    m[2] * x + m[6] * y + m[10] * z + m[14], m[3] * x + m[7] * y + m[11] * z + m[15]];
}

// eye position (display space) of an orbit: heading `yaw` (0 = looking along -Z, i.e. from +Z), `pitch` below horizon
export function orbitEye(target, distance, yawDeg, pitchDeg) {
  const y = yawDeg * RAD, p = pitchDeg * RAD;
  return [target[0] + distance * Math.cos(p) * Math.sin(y), target[1] + distance * Math.sin(p),
    target[2] + distance * Math.cos(p) * Math.cos(y)];
}

// engine-frame bounds {min, max} -> gxo-frame {lo, hi} (gxo = (-ex, -ez, ey), units 1)
export function boundsToGxo(b) {
  return { lo: [-b.max[0], -b.max[2], b.min[1]], hi: [-b.min[0], -b.min[2], b.max[1]] };
}

// the game-like perspective camera; bounds (engine frame) frame the subject when no distance is given
export function gameCamera({ bounds, target, distance, yaw = 35, pitch = GAME_PITCH, fov = DEFAULT_FOV, aspect = 1,
  fit = 0.9 }) {
  const lo = bounds ? engineToDisplay(bounds.min) : [-1, 0, -1], hi = bounds ? engineToDisplay(bounds.max) : [1, 2, 1];
  const c = target || [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2];
  const radius = 0.5 * Math.hypot(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]) || 1;
  const d = distance || (fit * radius) / Math.sin((Math.min(fov, fov * aspect) * RAD) / 2);
  const eye = orbitEye(c, d, yaw, pitch);
  const view = lookAt(eye, c, [0, 1, 0]);
  const proj = perspective(fov, aspect, Math.max(d * 0.01, 0.01), d * 10 + radius * 4);
  return { kind: 'game', eye, target: c, distance: d, yaw, pitch, fov, view, proj, viewProj: mulCM(proj, view) };
}

// the camera of aoe3de-unit-animation's render_obj.py (Blender, orthographic, OBJ z up = the gxo frame): centre and
// size of the posed bounds, eye at c + normalize(sin az, -cos az, el) * size * 3, up +Z, ortho scale size * 1.05.
// lo/hi: gxo-frame bounds in `units` per engine unit (pose_sim's OBJ: 1/2.54); aspect: width / height.
export function renderObjCamera({ lo, hi, az, el, units = 1, aspect = 1 }) {
  const loE = lo.map((v) => v / units), hiE = hi.map((v) => v / units);
  const c = [(loE[0] + hiE[0]) / 2, (loE[1] + hiE[1]) / 2, (loE[2] + hiE[2]) / 2];
  const size = Math.max(hiE[0] - loE[0], hiE[1] - loE[1], hiE[2] - loE[2]);
  const r = az * RAD;
  const dir = norm([Math.sin(r), -Math.cos(r), el]);
  const eyeG = [c[0] + dir[0] * size * 3, c[1] + dir[1] * size * 3, c[2] + dir[2] * size * 3];
  const eye = gxoToDisplay(eyeG), target = gxoToDisplay(c);
  const view = lookAt(eye, target, [0, 1, 0]);
  const scale = size * 1.05;                       // Blender: ortho_scale spans the larger render dimension
  const hw = aspect >= 1 ? scale / 2 : (scale / 2) * aspect, hh = aspect >= 1 ? scale / 2 / aspect : scale / 2;
  const proj = ortho(-hw, hw, -hh, hh, size * 0.01, size * 100);
  return { kind: 'render_obj', eye, target, size, az, el, view, proj, viewProj: mulCM(proj, view) };
}
