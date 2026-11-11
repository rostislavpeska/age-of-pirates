// node --test: viewer/lib/camera.js frames and cameras (pure maths).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  DISPLAY, engineToDisplay, gxoToDisplay, engineToGxo, gxoToEngine, boundsToGxo, gameCamera, renderObjCamera, projectCM,
  GAME_PITCH,
} from '../../viewer/lib/camera.js';

const near = (a, b, tol = 1e-9) => a.every((x, i) => Math.abs(x - b[i]) < tol);

test('frames: display = engine with x negated; gxo as unit_gr2.to_gxo_point', () => {
  const e = [0.3, 1.7, -2.2];
  assert.deepEqual(engineToDisplay(e), [-0.3, 1.7, -2.2]);
  assert.ok(near(engineToGxo(e), [-0.3, 2.2, 1.7]));                 // g = e @ A.T with A = [[-1,0,0],[0,0,-1],[0,1,0]]
  assert.ok(near(gxoToEngine(engineToGxo(e, 1 / 2.54), 1 / 2.54), e));
  assert.ok(near(gxoToDisplay(engineToGxo(e)), engineToDisplay(e)));
  const det = DISPLAY[0] * DISPLAY[5] * DISPLAY[10];
  assert.equal(det, -1);                                              // a reflection: the gr2 frame is left-handed
  const g = boundsToGxo({ min: [-1, 0, -2], max: [3, 4, 5] });
  assert.deepEqual(g, { lo: [-3, -5, 0], hi: [1, 2, 4] });
});

test('the game camera looks down at its pitch and keeps the subject in view', () => {
  const bounds = { min: [-0.7, 0, -1.5], max: [1.0, 3.2, 1.5] };
  const cam = gameCamera({ bounds, yaw: 35, aspect: 1, fit: 1 });   // fit 1: the bounding sphere fills the view
  assert.equal(cam.pitch, GAME_PITCH);
  const mid = projectCM(cam.viewProj, cam.target);
  assert.ok(Math.abs(mid[0] / mid[3]) < 1e-5 && Math.abs(mid[1] / mid[3]) < 1e-5);
  const dir = cam.target.map((x, i) => x - cam.eye[i]);
  const elev = Math.atan2(-dir[1], Math.hypot(dir[0], dir[2])) * 180 / Math.PI;
  assert.ok(Math.abs(elev - GAME_PITCH) < 1e-6, String(elev));
  for (const x of [bounds.min[0], bounds.max[0]]) {
    for (const y of [bounds.min[1], bounds.max[1]]) {
      for (const z of [bounds.min[2], bounds.max[2]]) {
        const p = projectCM(cam.viewProj, engineToDisplay([x, y, z]));
        assert.ok(Math.abs(p[0] / p[3]) <= 1 && Math.abs(p[1] / p[3]) <= 1, 'corner outside the view');
      }
    }
  }
});

test("render_obj's camera: centre on the axis, Blender's ortho scale, eye along az", () => {
  const lo = [-1, -2, 0], hi = [1, 1, 3];                            // gxo frame
  for (const [az, el] of [[90, 0.05], [35, 0.2], [270, 0.05]]) {
    const cam = renderObjCamera({ lo, hi, az, el, units: 1, aspect: 1 });
    const c = projectCM(cam.viewProj, gxoToDisplay([0, -0.5, 1.5]));
    assert.ok(Math.abs(c[0]) < 1e-5 && Math.abs(c[1]) < 1e-5);     // the bounds centre projects to the middle (f32)
    assert.ok(Math.abs(cam.size - 3) < 1e-12);
    // ortho scale = size * 1.05 across the view, as Blender's ortho_scale (oblique views may crop corners, as there)
    const edge = projectCM(cam.viewProj, gxoToDisplay([0, -0.5, 1.5]).map((v, i) => v + (i === 1 ? 1.575 : 0)));
    if (el === 0.05) assert.ok(Math.abs(Math.abs(edge[1]) - 1) < 0.01, String(edge[1]));
  }
  // az 90: Blender camera at +X of the centre (gxo), i.e. display x > centre
  const side = renderObjCamera({ lo, hi, az: 90, el: 0, units: 1 });
  assert.ok(side.eye[0] > 0 && Math.abs(side.eye[2] - 0.5) < 1e-9);
});
