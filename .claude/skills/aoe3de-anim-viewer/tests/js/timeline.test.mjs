// node --test: the timeline maths (viewer/timeline/model.js) on synthetic records - tag times on every clock, weights
// and the weighted roll, overflow, the key grid, AnimationRate and the ROF fit, tag stepping. Pure, CI-safe.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  laneOf, weightsOf, variantWeights, mulberry32, rollVariant, keyGrid, clipTimeAt, mainTimesOf, buildTimeline,
  tagLanes, tagStops, nextTagTime, tacticsRate, actionsFor, TAG_LANES, OVERFLOW_LANE, OTHER_LANE,
} from '../../viewer/timeline/model.js';

const close = (a, b, tol = 1e-12, msg = '') => assert.ok(Math.abs(a - b) <= tol, `${msg} ${a} != ${b} (tol ${tol})`);
const closeAll = (a, b, tol = 1e-12, msg = '') => {
  assert.equal(a.length, b.length, msg + ' length');
  a.forEach((x, i) => close(x, b[i], tol, msg + '[' + i + ']'));
};

test('lanes by tag type; fraction > 1 goes to the overflow lane; unknown types to other', () => {
  assert.equal(laneOf({ type: 'Attack', fraction: 0.5 }), 'Attack');
  assert.equal(laneOf({ type: 'footstepleft', fraction: 0.5 }), 'FootstepLeft');
  assert.equal(laneOf({ type: 'SpecificSoundSet', fraction: 1.0 }), 'SpecificSoundSet');
  assert.equal(laneOf({ type: 'SpecificSoundSet', fraction: 1.2 }), OVERFLOW_LANE);
  assert.equal(laneOf({ type: 'Attack', fraction: 0.2, overflow: true }), OVERFLOW_LANE);
  assert.equal(laneOf({ type: 'WindEffect', fraction: 0.1 }), 'WindEffect');
  assert.equal(laneOf({ type: 'CameraShake', fraction: 0.1 }), 'CameraShake');
  assert.equal(laneOf({ type: 'Particles', fraction: 0.1 }), 'Particles');
  assert.equal(laneOf({ type: 'BuildingDamage', fraction: 0.1 }), OTHER_LANE);
  assert.deepEqual(TAG_LANES, ['Attack', 'FootstepLeft', 'FootstepRight', 'SpecificSoundSet', 'Particles', 'WindEffect',
    'CameraShake']);
});

test('weights: animfile.weights_of value for value (declared, uniform hypothesis, mixed, zero sum, none)', () => {
  const v = (...ws) => ws.map((weight) => ({ weight }));
  const d = weightsOf(v(40, 10, 10, 10));
  assert.equal(d.rule, 'declared');
  closeAll(d.normalized, [40 / 70, 10 / 70, 10 / 70, 10 / 70]);
  const u = weightsOf(v(null, null, null));
  assert.equal(u.rule, 'uniform-hypothesis');
  closeAll(u.normalized, [1 / 3, 1 / 3, 1 / 3]);
  const m = weightsOf(v(3, null));
  assert.equal(m.rule, 'mixed');
  closeAll(m.normalized, [0.75, 0.25]);
  const z = weightsOf(v(0, 0));
  closeAll(z.normalized, [0.5, 0.5]);
  assert.deepEqual(weightsOf([]), { rule: 'none', normalized: [] });
});

test('variantWeights: the bundle normalised weights win, labels name the hypothesis', () => {
  const rec = { variants: [{ weight: null }, { weight: null }], weights: { rule: 'uniform-hypothesis', normalized: [0.5, 0.5] } };
  const w = variantWeights(rec);
  assert.equal(w.rule, 'uniform-hypothesis');
  assert.ok(w.hypothesis);
  assert.match(w.label, /^uniform \(hypothesis\)/);
  assert.deepEqual(w.raw, [null, null]);
  const d = variantWeights({ variants: [{ weight: 40 }, { weight: 10 }] });   // no bundle weights: recomputed
  assert.equal(d.rule, 'declared');
  assert.equal(d.sum, 50);
  assert.ok(!d.hypothesis);
  closeAll(d.normalized, [0.8, 0.2]);
  const bad = variantWeights({ variants: [{ weight: 1 }, { weight: 3 }], weights: { rule: 'declared', normalized: [1] } });
  closeAll(bad.normalized, [0.25, 0.75], 1e-12, 'a stale normalised list is recomputed');
});

test('roll: deterministic per seed, frequencies follow the normalised weights', () => {
  const w = [40 / 70, 10 / 70, 10 / 70, 10 / 70];
  const a = mulberry32(7), b = mulberry32(7);
  const sa = Array.from({ length: 10 }, () => rollVariant(w, a));
  const sb = Array.from({ length: 10 }, () => rollVariant(w, b));
  assert.deepEqual(sa, sb);
  const rng = mulberry32(20261011);
  const n = 40000, hits = [0, 0, 0, 0];
  for (let i = 0; i < n; i++) hits[rollVariant(w, rng)]++;
  hits.forEach((h, i) => close(h / n, w[i], 0.01, 'frequency of v' + i));
  assert.equal(rollVariant([0.5, 0.5], () => 0.999999999), 1);
  assert.equal(rollVariant([0.5, 0.5], () => 0), 0);
  assert.equal(rollVariant([], () => 0.3), -1);
});

test('key grid: clip_decode grid k / round(fps), non-integer rates and an off-grid last key flagged', () => {
  const g = keyGrid({ duration: 1.5, fps_declared: 191.99999427795427, key_count: 289 });
  assert.equal(g.rounded, 192);
  assert.equal(g.count, 289);
  assert.ok(!g.nonInteger && !g.lastOffGrid);
  close(g.time(288), 1.5);
  close(g.time(3), 3 / 192);
  assert.equal(g.keyAt(0.81), 156);                     // 155.52 -> 156
  assert.equal(g.keyAt(99), 288);
  const n = keyGrid({ duration: 1.0, fps_declared: 186.4 });
  assert.ok(n.nonInteger);
  assert.equal(n.rounded, 186);
  assert.equal(n.count, 187);
  const off = keyGrid({ duration: 0.51, fps: 60, keyCount: 32 });
  assert.ok(off.lastOffGrid);
  close(off.time(31), 0.51);                            // the last key at the duration, not at 31/60
});

test('clocks: main, absolute, phase and own; main times of a clip time', () => {
  close(clipTimeAt('main', 0.7, 1.5, 1.5), 0.7);
  close(clipTimeAt('absolute', 3.0, 2.0, 3.6), 2.0, 1e-12, 'absolute holds its last key');
  close(clipTimeAt('phase', 0.75, 2.0, 1.5), 1.0);
  close(clipTimeAt('own', 0.9, 0.4, 1.5), 0.1);
  closeAll(mainTimesOf('absolute', 0.5, 2.0, 1.5), [0.5]);
  closeAll(mainTimesOf('phase', 1.0, 2.0, 1.5), [0.75]);
  closeAll(mainTimesOf('own', 0.1, 0.4, 1.0, 1.0), [0.1, 0.5, 0.9]);
  closeAll(mainTimesOf('own', 0.35, 0.4, 1.0, 1.0), [0.35, 0.75]);
  closeAll(mainTimesOf('own', 0.5, 0.4, 1.0, 1.0), [0.5], 1e-12, 'overflow past its own clip end: once');
  closeAll(mainTimesOf('own', 0.2, 0, 1.0, 1.0), [0.2]);
});

// a synthetic rig: main horse (1.5 s at 192 fps, an animlengthoverride of 3 s), a rider in absolute time (2 s at
// 60 fps: its end is never reached), a torch on its own clock (0.4 s), a second rider model on the same side
function synthetic(sync = 'absolute') {
  const clip = (id, duration, fps) => ({ id, duration, fps, keyCount: Math.round(duration * Math.round(fps)) + 1 });
  const horse = { anim: 'Attack', variant: 0, clip: clip('h.gr2', 1.5, 192), variantRec: { animlengthoverride: 3.0, tags: [
    { type: 'Attack', fraction: 0.54, attrs: {} },
    { type: 'SpecificSoundSet', fraction: 1.2, attrs: { set: 'Swoosh', checkvisible: '1' }, overflow: true },
    { type: 'FootstepLeft', fraction: 0.25, attrs: { footprintbone: 'HS Bone Hoof Frnt Lt', footprinttype: 'Horse' } }] } };
  const rider = { anim: 'Attack', variant: 0, clip: clip('r.gr2', 2.0, 60), variantRec: { animlengthoverride: null, tags: [
    { type: 'FootstepLeft', fraction: 0.5, attrs: {} }] } };
  const torch = { anim: 'Idle', variant: 0, clip: clip('t.gr2', 0.4, 30), variantRec: { tags: [
    { type: 'Particles', fraction: 0.25, attrs: { name: 'sparks' } }] } };
  const inst = (index, role, animfile, side, clock, model, parent) => Object.assign({ index, role, animfile, clock,
    model: { id: model }, parent, notes: [], attach: parent >= 0 ? { a: role } : null }, side);
  return {
    duration: 1.5,
    instances: [
      inst(0, 'main', 'h.xml', horse, 'main', 'horse_0.gr2', -1),
      inst(1, 'child', 'r.xml', rider, sync === 'phase' ? 'phase' : 'absolute', 'rider_0.gr2', 0),
      inst(2, 'child', 'r.xml', rider, sync === 'phase' ? 'phase' : 'absolute', 'rider_hat.gr2', 0),
      inst(3, 'attachment', 't.xml', torch, 'own', 'torch.gr2', 1),
    ],
  };
}

const MANIFEST = {
  animfiles: {
    'h.xml': { attachments: [] },
    'r.xml': { attachments: [{ name: 'attachment_whip', include: 'w.xml', audit: ['declared-not-attached'] },
      { name: 'torch', include: 't.xml', audit: [] }] },
    't.xml': { attachments: [], audit: [] },
    't.xml#fire': { attachments: [], audit: [{ code: 'effect-not-rendered', type: 'popcornFx', file: 'fire_torch_b.pkfx' }] },
  },
  composition: { main: 'h.xml', children: [
    { animfile: 'r.xml', attachment: 'RiderAttachment', scope: 'component', attach: { syncanims: true }, declared_in: { animfile: 'h.xml' } },
    { animfile: 't.xml', attachment: 'torch', scope: 'anim', attach: { syncanims: false }, declared_in: { animfile: 'r.xml', anims: ['Attack'] } },
    { animfile: 't.xml#fire', attachment: 'fire', scope: 'anim', attach: { syncanims: false }, declared_in: { animfile: 't.xml', anims: ['Idle'] } },
    { animfile: 'x.xml', attachment: 'other_anim_only', scope: 'anim', attach: { syncanims: false }, declared_in: { animfile: 'r.xml', anims: ['Raze'] } },
  ] },
};

test('timeline: sides, spans, repeats, tag times per clock, overflow, overrides and ghosts, lanes', () => {
  const tl = buildTimeline(synthetic(), MANIFEST);
  close(tl.D, 1.5);
  assert.equal(tl.sides.length, 3, 'two rider models share one side');
  const [h, r, t] = tl.sides;
  assert.deepEqual(r.models, ['rider_0.gr2', 'rider_hat.gr2']);
  assert.equal(h.grid.rounded, 192);
  assert.equal(r.grid.rounded, 60);
  assert.ok(r.pastMainEnd && !r.holdsLastKey);
  closeAll(r.span, [0, 2.0]);
  closeAll(t.repeats, [0, 0.4, 0.8, 1.2], 1e-12, 'own loop starts inside [0, D)');
  const by = (type, role) => tl.tags.find((x) => x.type === type && x.role === role);
  const atk = by('Attack', 'main');
  closeAll(atk.times, [0.81]);
  close(atk.ghost, 0.54 * 3.0, 1e-12, 'stretched by animlengthoverride (ghost)');
  assert.equal(atk.key, 156);
  const snd = by('SpecificSoundSet', 'main');
  assert.equal(snd.lane, OVERFLOW_LANE);
  assert.ok(snd.overflow);
  closeAll(snd.times, [1.8]);
  assert.deepEqual(snd.reached, [], 'past D: never reached while the main clip loops');
  const fl = by('FootstepLeft', 'child');
  closeAll(fl.times, [1.0]);
  assert.equal(fl.footstep, true);
  assert.equal(by('FootstepLeft', 'main').footprintbone, 'HS Bone Hoof Frnt Lt');
  const part = by('Particles', 'attachment');
  closeAll(part.times, [0.1, 0.5, 0.9, 1.3], 1e-12, 'own clock repeats');
  assert.equal(tl.overrides.length, 1);
  close(tl.overrides[0].length, 3.0);
  close(tl.tEnd, 1.2 * 3.0, 1e-12, 'the axis spans the override and every ghost (the overflow tag stretched: 3.6 s)');
  assert.deepEqual(tl.unattached.map((u) => u.name), ['attachment_whip']);
  assert.deepEqual(tl.effects.map((e) => [e.name, e.reason]), [['fire', 'effect not rendered: popcornFx fire_torch_b.pkfx']],
    'model-less attachments in scope; anim-scope children of other anims are left out');
  const lanes = tagLanes(tl.tags);
  assert.deepEqual(lanes.map((l) => l.name), [...TAG_LANES, OVERFLOW_LANE]);
  assert.deepEqual(lanes.map((l) => l.tags.length), [1, 2, 0, 0, 1, 0, 0, 1]);
  assert.equal(tagLanes([{ lane: OTHER_LANE }]).some((l) => l.name === OTHER_LANE), true);
});

test('timeline in normalised phase: the child tags and keys map through D / d', () => {
  const tl = buildTimeline(synthetic('phase'), MANIFEST);
  const r = tl.sides[1];
  assert.equal(r.clock, 'phase');
  closeAll(r.span, [0, 1.5]);
  assert.ok(!r.pastMainEnd);
  const fl = tl.tags.find((x) => x.type === 'FootstepLeft' && x.role === 'child');
  closeAll(fl.times, [0.75]);
  close(fl.clipTime, 1.0);
});

test('tag stepping: unique reached stops, next and previous wrap around', () => {
  const tl = buildTimeline(synthetic(), MANIFEST);
  const stops = tagStops(tl.tags, tl.D);
  closeAll(stops, [0.1, 0.375, 0.5, 0.81, 0.9, 1.0, 1.3]);
  close(nextTagTime(stops, 0, 1), 0.1);
  close(nextTagTime(stops, 0.81, 1), 0.9, 1e-12, 'strictly after the current time');
  close(nextTagTime(stops, 1.4, 1), 0.1, 1e-12, 'wraps to the first');
  close(nextTagTime(stops, 0.81, -1), 0.5);
  close(nextTagTime(stops, 0.05, -1), 1.3, 1e-12, 'wraps to the last');
  assert.equal(nextTagTime([], 0.3, 1), null);
  closeAll(tagStops([{ reached: [0.2, 0.2 + 1e-9, 0.4] }], 1), [0.2, 0.4]);
});

test('tactics rate: AnimationRate (H3) x clip / ROF (H1 ROF fit), labelled, each part optional', () => {
  const raze = tacticsRate({ rof_effective: 3.0, rof_source: 'protoaction', animationrate: null }, 1.0);
  close(raze.rate, 1 / 3);
  close(raze.cycle, 3.0);
  assert.deepEqual(raze.parts.map((p) => p.rule), ['H1 ROF fit']);
  assert.ok(raze.notes.some((n) => /AnimationRate/.test(n)));
  const both = tacticsRate({ rof_effective: 1.5, rof_source: 'protoaction', animationrate: 0.46875 }, 1.5);
  close(both.rate, 0.46875);
  close(both.cycle, 3.2);
  assert.deepEqual(both.parts.map((p) => p.rule), ['H3', 'H1 ROF fit']);
  close(tacticsRate({ rof_effective: 1.5, animationrate: 0.46875 }, 1.5, { rofFit: false }).rate, 0.46875);
  close(tacticsRate({ rof_effective: 2.0, animationrate: 0.5 }, 1.5, { animationRate: false }).rate, 0.75);
  const none = tacticsRate({ rof_effective: null, animationrate: null }, 1.5);
  close(none.rate, 1);
  assert.equal(none.parts.length, 0);
  assert.ok(none.notes.some((n) => /no ROF/.test(n)));
});

test('actions for an anim: case-insensitive, in bundle order', () => {
  const timing = { actions: [{ action: 'A', anim: 'Attack_melee' }, { action: 'B', anim: 'raze_attack' },
    { action: 'C', anim: 'attack_MELEE' }, { action: 'D', anim: null }] };
  assert.deepEqual(actionsFor(timing, 'Attack_Melee').map((r) => r.action), ['A', 'C']);
  assert.deepEqual(actionsFor(null, 'x'), []);
});
