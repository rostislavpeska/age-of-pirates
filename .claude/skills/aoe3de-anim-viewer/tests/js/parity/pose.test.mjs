// node --test: viewer/lib/rig.js world matrices against the Python references that tests/test_parity_js.py writes
// into AV_POSE_FIXTURE: a bundle folder and cases {anim, variant, time, normalize, expect [{role, model, worlds}]}.
// Each expected set is named by its source (gr2_curves + gr2_model compose, or aoe3de-unit-animation's pose_sim seated
// on the mount, converted back from the converter frame); the case tolerance applies to every matrix entry. Optional
// `vertices` compare rig.skinPositions (CPU linear-blend skinning) with pose_sim.skin, mesh by mesh.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Rig, skinPositions } from '../../../viewer/lib/rig.js';
import { loadBundleDir, readFixture, maxAbsDiff } from './disk.mjs';

test('rig world matrices equal the Python references', async (t) => {
  const fx = await readFixture('AV_POSE_FIXTURE');
  if (!fx) return t.skip('AV_POSE_FIXTURE not set (run through tests/test_parity_js.py)');
  const bundle = await loadBundleDir(fx.bundle_dir);
  for (const c of fx.cases) {
    const rig = new Rig(bundle, { anim: c.anim, variant: c.variant || 0, logic: c.logic || {}, sync: c.sync || 'absolute',
      normalize: c.normalize || 'newton1', method: c.method || 'bspline' });
    rig.pose(c.time);
    for (const e of c.expect) {
      const inst = rig.instances.find((x) => x.role === e.role && x.model.id === e.model);
      assert.ok(inst, `${c.name}: no ${e.role} instance of ${e.model} (have ${rig.instances.map((x) => x.role + ':' + x.model.id)})`);
      if (e.bones) assert.deepEqual(inst.model.names, e.bones, `${c.name}: bone order of ${e.model}`);
      if (e.clip !== undefined) assert.equal(inst.clip ? inst.clip.id : null, e.clip, `${c.name}: clip of ${e.role}`);
      const d = maxAbsDiff(inst.worlds, e.worlds);
      console.log(`# ${c.name} ${e.source} ${e.role} ${e.model.split('/').pop()}: max |JS - Python| ${d.toExponential(2)} (tol ${c.tolerance})`);
      assert.ok(d < c.tolerance, `${c.name} ${e.source} ${e.role}: ${d} >= ${c.tolerance}`);
    }
    for (const e of c.vertices || []) {                 // CPU linear-blend skinning against pose_sim.skin
      const inst = rig.instances.find((x) => x.role === e.role && x.model.id === e.model);
      assert.ok(inst, `${c.name}: no ${e.role} instance of ${e.model}`);
      const got = skinPositions(inst, inst.model.meshes[e.mesh], bundle.view);
      const d = maxAbsDiff(got, e.positions);
      console.log(`# ${c.name} ${e.source} vertices ${e.role} ${e.model.split('/').pop()} mesh ${e.mesh} (${got.length / 3}): max |JS - Python| ${d.toExponential(2)} (tol ${e.tolerance})`);
      assert.ok(d < e.tolerance, `${c.name} vertices ${e.role} mesh ${e.mesh}: ${d} >= ${e.tolerance}`);
    }
  }
});
