// node --test: the M4 timeline, footprint dots and data panels on a real bundle that bundle.py wrote from the synthetic
// mounted unit (tests/test_timeline_panels.py writes AV_M4_FIXTURE: {bundle_dir, cases}). Every expected number comes
// from the Python side (gr2_model + gr2_curves for the footprint world positions and the curve deviations, the manifest
// for durations and layers). Run through pytest; standalone it fails without the fixture.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Rig } from '../../../viewer/lib/rig.js';
import { buildTimeline, variantWeights, tagLanes, tagStops } from '../../../viewer/timeline/model.js';
import { footprintDots } from '../../../viewer/timeline/footprint.js';
import {
  timingView, clipView, curveDeviation, materialView, provenanceView, auditView, pairingView, boneView, fidelityView,
  applyTimelineFidelity,
} from '../../../viewer/panels/data.js';
import { loadBundleDir, readFixture, maxAbsDiff } from '../parity/disk.mjs';

const close = (a, b, tol, msg = '') => assert.ok(Math.abs(a - b) <= tol, `${msg}: ${a} != ${b} (tol ${tol})`);

test('M4 timeline, footprints and panels on the synthetic bundle', async () => {
  const fx = await readFixture('AV_M4_FIXTURE');
  assert.ok(fx, 'AV_M4_FIXTURE not set (run through tests/test_timeline_panels.py)');
  const bundle = await loadBundleDir(fx.bundle_dir);
  const m = bundle.manifest;
  for (const c of fx.cases) {
    const rig = new Rig(bundle, { anim: c.anim, variant: c.variant || 0, sync: c.sync || 'absolute' });
    const tl = buildTimeline(rig, m);
    close(tl.D, c.D, 1e-9, c.anim + ' D');
    assert.deepEqual(tl.sides.map((s) => [s.role, s.clip ? s.clip.id : null, s.clock]), c.sides, c.anim + ' sides');
    for (const s of c.side_flags || []) {
      const side = tl.sides.find((x) => x.role === s.role);
      assert.equal(side.pastMainEnd, s.pastMainEnd, c.anim + ' ' + s.role + ' pastMainEnd');
      if (s.rounded !== undefined) assert.equal(side.grid.rounded, s.rounded, c.anim + ' ' + s.role + ' fps');
      if (s.keys !== undefined) assert.equal(side.grid.count, s.keys, c.anim + ' ' + s.role + ' keys');
    }
    const got = tl.tags.map((t) => ({ type: t.type, role: t.role, lane: t.lane, times: t.times, reached: t.reached.length }));
    assert.equal(got.length, c.tags.length, c.anim + ' tag count');
    c.tags.forEach((e, i) => {
      assert.equal(got[i].type, e.type);
      assert.equal(got[i].role, e.role);
      assert.equal(got[i].lane, e.lane, c.anim + ' lane of ' + e.type);
      assert.equal(got[i].reached, e.reached, c.anim + ' reached ' + e.type);
      assert.ok(maxAbsDiff(got[i].times, e.times) < 1e-9, c.anim + ' times of ' + e.type + ': ' + got[i].times + ' vs ' + e.times);
    });
    assert.deepEqual(tagLanes(tl.tags).filter((l) => l.tags.length).map((l) => l.name), c.lanes, c.anim + ' lanes');
    assert.ok(maxAbsDiff(tagStops(tl.tags, tl.D), c.stops) < 1e-9, c.anim + ' stops');
    // footprint dots against gr2_model + gr2_curves at the tag time
    const dots = footprintDots(bundle, { anim: c.anim, variant: c.variant || 0 }, tl);
    assert.equal(dots.length, (c.footprints || []).length, c.anim + ' footprint count');
    (c.footprints || []).forEach((e, i) => {
      assert.equal(dots[i].status, e.status, c.anim + ' footprint status');
      assert.equal(dots[i].index, e.index, c.anim + ' footprint bone index');
      close(dots[i].time, e.time, 1e-9, c.anim + ' footprint time');
      const d = maxAbsDiff(dots[i].position, e.position);
      console.log(`# ${c.anim} footprint ${e.bone}: max |JS - Python| ${d.toExponential(2)}`);
      assert.ok(d < 1e-9, c.anim + ' footprint position ' + dots[i].position + ' vs ' + e.position);
    });
    if (c.pairing) {
      const p = pairingView(m, c.anim);
      assert.deepEqual(p.one_sided, c.pairing.one_sided, c.anim + ' one-sided');
      if (c.pairing.one_sided) assert.match(p.fallback, /assumption/);
      assert.match(rig.instances.find((x) => x.role === 'child').notes.join(' '), new RegExp(c.pairing.note));
    }
    if (c.bones) {
      rig.pose(c.bones.t);
      const bv = boneView(rig, 0);
      const row = bv.rows.find((r) => r.name === c.bones.name);
      assert.ok(maxAbsDiff(row.world, c.bones.world) < 1e-9, 'bone readout ' + row.world + ' vs ' + c.bones.world);
      assert.ok(row.marks.some((x) => x.startsWith('attach RiderAttachment')), 'the seat bone is marked');
    }
  }
  // weights of the rider's Idle (declared 3 / 1)
  const rider = m.animfiles[fx.rider];
  const w = variantWeights(rider.anims.Idle);
  assert.equal(w.rule, 'declared');
  assert.ok(maxAbsDiff(w.normalized, fx.rider_idle_weights) < 1e-12);
  assert.equal(variantWeights(m.animfiles[m.composition.main].anims.Idle).rule, 'uniform-hypothesis');
  // clips: formats and the B-spline vs knots deviation against gr2_curves.evaluate
  for (const [id, e] of Object.entries(fx.clips)) {
    const cv = clipView(m, id);
    assert.deepEqual(cv.formats, e.formats, id + ' formats');
    assert.equal(cv.key_count, e.key_count, id + ' keys');
    assert.equal(cv.methods.reduce((n, x) => n + x.count, 0), e.curves, id + ' curve count');
    const dev = curveDeviation(bundle, id);
    for (const k of ['position', 'orientation', 'scale_shear']) {
      console.log(`# ${id.split('/').pop()} deviation ${k}: JS ${dev[k].toExponential(4)} Python ${e.deviation[k].toExponential(4)}`);
      close(dev[k], e.deviation[k], 1e-9, id + ' deviation ' + k);
    }
  }
  // provenance: every file of the synthetic unit comes from its one mod layer
  const all = new Rig(bundle, { anim: 'Attack' });
  const pv = provenanceView(m, { animfiles: [...new Set(all.instances.map((x) => x.animfile))],
    models: all.instances.map((x) => x.model.id), clips: all.instances.filter((x) => x.clip).map((x) => x.clip.id) });
  assert.ok(pv.rows.length >= 6, 'rows ' + pv.rows.length);
  assert.deepEqual([...new Set(pv.rows.map((r) => r.layer))], [fx.layer]);
  assert.deepEqual(pv.layers.map((l) => [l.id, l.here]), [[fx.layer, pv.rows.length]]);
  // materials: the rider's BaseColor / Details (BC1 16x16) and the materialdef default parameter
  const mats = materialView(m, [fx.rider_model]);
  assert.equal(mats.length, 1);
  assert.deepEqual(mats[0].slots.filter((s) => s.texture).map((s) => [s.name, s.bc, s.size, s.mips, s.srgb]), fx.rider_slots);
  assert.deepEqual(mats[0].floats, fx.rider_floats);
  // audit and warnings: the engine-defined hotspot
  const av = auditView(m);
  assert.ok(av.items.some((i) => i.code === 'engine-bone-assumed' && i.detail.bone === 'hotspot'));
  assert.equal(av.warnings.length, m.warnings.length);
  // timing without a proto: empty, never invented
  const tv = timingView(m, 'Attack');
  assert.deepEqual([tv.actions.length, tv.tactics.length, tv.status], [0, 0, m.timing ? m.timing.status || 'none' : 'none']);
  // fidelity: the bundle block plus the timeline stages
  const before = Object.keys(m.fidelity.stages).length;
  const added = applyTimelineFidelity(m);
  assert.equal(Object.keys(m.fidelity.stages).length, before + added.length);
  assert.equal(fidelityView(m).rows.length, before + added.length);
});
