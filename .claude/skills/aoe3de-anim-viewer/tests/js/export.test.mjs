// node --test: the M5 export planning (viewer/export/plan.js) and the geometry dump (viewer/export/geometry.js) on
// synthetic records - tag / key / fps expansion from the M4 timeline, two subjects on one clock, the cell record,
// the export cameras, the binary dump round trip. Pure, CI-safe.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildTimeline } from '../../viewer/timeline/model.js';
import {
  parseAt, expandAt, tagStopsOf, tagLabel, sharedClockTime, cellInfo, unionBounds, cameraFor, timelineSummary,
  CLOSE_PITCH,
} from '../../viewer/export/plan.js';
import { geometryParts, packGeometry, unpackGeometry, dominantBones, GEOM_MAGIC } from '../../viewer/export/geometry.js';
import { Model } from '../../viewer/lib/rig.js';
import { GAME_PITCH } from '../../viewer/lib/camera.js';

const close = (a, b, tol = 1e-12, msg = '') => assert.ok(Math.abs(a - b) <= tol, `${msg} ${a} != ${b} (tol ${tol})`);
const closeAll = (a, b, tol = 1e-12, msg = '') => {
  assert.equal(a.length, b.length, msg + ' length');
  a.forEach((x, i) => close(x, b[i], tol, msg + '[' + i + ']'));
};

// main horse 1.5 s @ 192 fps (Attack 0.54, FootstepLeft 0.25, an overflow sound at 1.2), a rider in absolute time
// 2.0 s @ 60 fps (FootstepLeft 0.5 -> 1.0 s, reached), a torch on its own 0.4 s clock (Particles 0.25 -> 4 repeats)
function synthetic(prefix = '') {
  const clip = (id, duration, fps) => ({ id: prefix + id, duration, fps, keyCount: Math.round(duration * Math.round(fps)) + 1 });
  const horse = { anim: 'Attack', variant: 0, clip: clip('h.gr2', 1.5, 192), variantRec: { animlengthoverride: null, tags: [
    { type: 'Attack', fraction: 0.54, attrs: {} },
    { type: 'SpecificSoundSet', fraction: 1.2, attrs: { set: 'Swoosh' }, overflow: true },
    { type: 'FootstepLeft', fraction: 0.25, attrs: { footprintbone: 'HS Bone Hoof Frnt Lt' } }] } };
  const rider = { anim: 'Attack', variant: 0, clip: clip('r.gr2', 2.0, 60), variantRec: { tags: [
    { type: 'FootstepLeft', fraction: 0.5, attrs: {} }] } };
  const torch = { anim: 'Idle', variant: 0, clip: clip('t.gr2', 0.4, 30), variantRec: { tags: [
    { type: 'Particles', fraction: 0.25, attrs: {} }] } };
  const inst = (index, role, animfile, side, clock, model, parent) => Object.assign({ index, role, animfile, clock,
    model: { id: model }, parent, notes: [], attach: parent >= 0 ? { a: role } : null }, side);
  return {
    anim: 'Attack', variant: 0, duration: 1.5,
    instances: [
      inst(0, 'main', 'h.xml', horse, 'main', 'horse_0.gr2', -1),
      inst(1, 'child', 'r.xml', rider, 'absolute', 'rider_0.gr2', 0),
      inst(2, 'attachment', 't.xml', torch, 'own', 'torch.gr2', 1),
    ],
  };
}
const MANIFEST = { animfiles: {}, composition: { main: 'h.xml', children: [] } };

test('parseAt: tags, keys, fps=N (string or object); anything else is null', () => {
  assert.deepEqual(parseAt('tags'), { kind: 'tags' });
  assert.deepEqual(parseAt(' KEYS '), { kind: 'keys' });
  assert.deepEqual(parseAt('fps=12'), { kind: 'fps', fps: 12 });
  assert.deepEqual(parseAt('fps = 2.5'), { kind: 'fps', fps: 2.5 });
  assert.deepEqual(parseAt({ fps: 30 }), { kind: 'fps', fps: 30 });
  assert.deepEqual(parseAt({ kind: 'tags' }), { kind: 'tags' });
  for (const bad of ['fps=0', 'fps=-1', 'frames', '', null, undefined, { fps: 0 }]) assert.equal(parseAt(bad), null, String(bad));
  assert.throws(() => expandAt('nope', [{ tl: buildTimeline(synthetic(), MANIFEST), subject: 'a' }]), /bad "at"/);
});

test('at tags: one cell per distinct reached tag time; overflow skipped with its reason; labels', () => {
  const tl = buildTimeline(synthetic(), MANIFEST);
  const ex = expandAt('tags', [{ tl, subject: 'a' }]);
  closeAll(ex.frames.map((f) => f.t), [0.1, 0.375, 0.5, 0.81, 0.9, 1.0, 1.3], 1e-12);
  const atk = ex.frames.find((f) => Math.abs(f.t - 0.81) < 1e-9);
  assert.equal(atk.label, 't0.8100_Attack');
  assert.equal(atk.tags.length, 1);
  assert.equal(atk.tags[0].key, 156);
  assert.equal(ex.frames.find((f) => Math.abs(f.t - 1.0) < 1e-9).label, 't1.0000_child_FootstepLeft');
  assert.equal(ex.frames[0].tags[0].role, 'attachment');
  assert.equal(ex.skipped.length, 1);
  assert.equal(ex.skipped[0].type, 'SpecificSoundSet');
  assert.match(ex.skipped[0].reason, /overflow/);
});

test('at keys: every key of the main grid, last at D; at fps=N: i / N up to D', () => {
  const tl = buildTimeline(synthetic(), MANIFEST);
  const k = expandAt('keys', [{ tl, subject: 'a' }]);
  assert.equal(k.frames.length, 289);
  close(k.frames[1].t, 1 / 192);
  close(k.frames[288].t, 1.5);
  assert.equal(k.frames[156].label, 'k156');
  const f = expandAt('fps=10', [{ tl, subject: 'a' }]);
  assert.equal(f.frames.length, 16);
  closeAll(f.frames.map((x) => x.t), Array.from({ length: 16 }, (_, i) => i / 10), 1e-12);
  assert.equal(f.frames[3].label, 'f0003');
  const g = expandAt({ fps: 4 }, [{ tl, subject: 'a' }]);
  closeAll(g.frames.map((x) => x.t), [0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5]);
});

test('two subjects on one clock: tag stops merge, shared times keep both tags, b tags labelled b:', () => {
  const ta = buildTimeline(synthetic(), MANIFEST);
  const rb = synthetic('b_');
  rb.instances = rb.instances.slice(0, 1);                       // b: a horse only
  rb.instances[0].variantRec = { tags: [{ type: 'Attack', fraction: 0.54, attrs: {} }, { type: 'FootstepRight', fraction: 0.6, attrs: {} }] };
  const tb = buildTimeline(rb, MANIFEST);
  const { stops } = tagStopsOf([{ tl: ta, subject: 'a' }, { tl: tb, subject: 'b' }]);
  const at = stops.find((s) => Math.abs(s.t - 0.81) < 1e-9);
  assert.deepEqual(at.tags.map((x) => x.subject), ['a', 'b']);
  assert.equal(tagLabel(at.tags), 'Attack+b:Attack');
  const s09 = stops.find((s) => Math.abs(s.t - 0.9) < 1e-9);
  assert.deepEqual(s09.tags.map((x) => [x.subject, x.type]), [['a', 'Particles'], ['b', 'FootstepRight']],
    'b FootstepRight at 0.6 x 1.5 shares the torch stop 0.1 + 2 x 0.4 (within 1e-6)');
  assert.equal(stops.length, 7, 'b adds no new time: 0.81 and 0.9 already exist');
});

test('sharedClockTime: inside [0, D] kept, later times wrap; no duration -> 0', () => {
  close(sharedClockTime(0.5, 1.0), 0.5);
  close(sharedClockTime(1.0, 1.0), 1.0, 0, 'the end pose, not 0');
  close(sharedClockTime(1.25, 1.0), 0.25, 1e-12);
  close(sharedClockTime(2.5, 1.0), 0.5, 1e-12);
  close(sharedClockTime(-1, 1.0), 0);
  close(sharedClockTime(3, 0), 0);
});

test('cellInfo: anim, variant, main clip, key per side on its clock, tags at t', () => {
  const rig = synthetic();
  const tl = buildTimeline(rig, MANIFEST);
  const c = cellInfo(rig, tl, 0.81);
  assert.equal(c.anim, 'Attack');
  assert.equal(c.clip, 'h.gr2');
  assert.equal(c.key, 156);
  assert.equal(c.keys_of, 289);
  assert.equal(c.tag, 'Attack');
  const rider = c.keys.find((k) => k.role === 'child');
  close(rider.clip_time, 0.81);
  assert.equal(rider.key, Math.round(0.81 * 60));
  const torch = c.keys.find((k) => k.role === 'attachment');
  close(torch.clip_time, 0.81 % 0.4, 1e-12, 'own clock wraps');
  assert.equal(cellInfo(rig, tl, 0.7).tag, null);
  const s = timelineSummary(tl);
  assert.equal(s.sides.length, 3);
  assert.equal(JSON.parse(JSON.stringify(s)).tags.length, 5, 'JSON-able');
});

test('framing and cameras: union bounds; game pitch 47; close pitch 14 aimed high; ortho = render_obj camera', () => {
  const b = unionBounds([{ min: [-1, 0, -1], max: [1, 2, 1] }, null, { min: [-2, 0.5, 0], max: [0, 3, 2] }]);
  assert.deepEqual(b, { min: [-2, 0, -1], max: [1, 3, 2] });
  assert.equal(unionBounds([null]), null);
  const g = cameraFor({}, b, 1);
  assert.equal(g.kind, 'game');
  assert.equal(g.pitch, GAME_PITCH);
  const c = cameraFor({ mode: 'close' }, b, 1);
  assert.equal(c.pitch, CLOSE_PITCH);
  close(c.target[1], 0.62 * 3, 1e-12, 'close target at 62 % of the height');
  assert.ok(c.distance < g.distance, 'closer than the game framing');
  const o = cameraFor({ mode: 'ortho', az: 90, el: 0.05 }, b, 1);
  assert.equal(o.kind, 'render_obj');
});

// a two-bone model: bone 1 translated by +1 y in the posed worlds; vertex 2 bound to bone 1 only
function geoFixture() {
  const I = { position: [0, 0, 0], orientation: [0, 0, 0, 1], scale_shear: [1, 0, 0, 0, 1, 0, 0, 0, 1] };
  const inv = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
  const arr = {
    pos: new Float32Array([0, 0, 0, 1, 0, 0, 0, 0, 1]),
    w: new Uint8Array([255, 0, 0, 0, 128, 127, 0, 0, 255, 0, 0, 0]),
    i: new Uint8Array([0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0]),
    idx: new Uint16Array([0, 1, 2]),
  };
  const mesh = { name: 'm', vertex_count: 3, bone_bindings: [{ name: 'root', bone: 0 }, { name: 'b1', bone: 1 }],
    streams: { Position: { view: { key: 'pos', components: 3 } }, BoneWeights: { view: { key: 'w', components: 4 } },
      BoneIndices: { view: { key: 'i', components: 4 } } }, indices: { key: 'idx', components: 1 } };
  const model = new Model({ id: 'x.gr2', decodable: true, skeleton: { bones: [
    { name: 'root', parent: -1, rest: I, inverse_world: inv }, { name: 'b1', parent: 0, rest: I, inverse_world: inv }] },
  meshes: [mesh] });
  const worlds = new Float64Array(32);
  worlds.set(inv, 0);
  worlds.set([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1], 16);
  const placement = new Float64Array(inv);
  const rig = { instances: [{ index: 0, role: 'main', animfile: 'x.xml', anim: 'Idle', variant: 0, clip: null, clock: 'main',
    time: 0, model, worlds, placement }] };
  return { rig, view: (v) => arr[v.key], mesh };
}

test('geometry: skinned and bind positions, triangles, dominant bones; pack/unpack round trip', () => {
  const { rig, view, mesh } = geoFixture();
  assert.deepEqual(Array.from(dominantBones(mesh, view)), [0, 0, 1], 'the largest weight wins (128 > 127)');
  const g = geometryParts(rig, view, 0.25, { subject: 'a' });
  const bytes = packGeometry(g.header, g.arrays);
  assert.equal(String.fromCharCode(...bytes.subarray(0, 8)), GEOM_MAGIC);
  const u = unpackGeometry(bytes);
  assert.equal(u.header.t, 0.25);
  assert.equal(u.header.meta.subject, 'a');
  const m = u.header.instances[0].meshes[0];
  assert.deepEqual(u.header.instances[0].bones, ['root', 'b1']);
  closeAll(Array.from(u.array(m, 'bind')), [0, 0, 0, 1, 0, 0, 0, 0, 1]);
  const posed = Array.from(u.array(m, 'posed'));
  closeAll(posed.slice(0, 3), [0, 0, 0], 1e-6);
  close(posed[4], 127 / 255, 1e-6, 'vertex 1: half on the moved bone');
  closeAll(posed.slice(6, 9), [0, 1, 1], 1e-6, 'vertex 2 follows bone 1');
  assert.deepEqual(Array.from(u.array(m, 'indices')), [0, 1, 2]);
  assert.deepEqual(Array.from(u.array(m, 'bone')), [0, 0, 1]);
  assert.equal(bytes.length % 4, 0);
});
