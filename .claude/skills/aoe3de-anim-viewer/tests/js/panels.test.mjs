// node --test: the data panels' tables (viewer/panels/data.js) from a synthetic manifest - tactics rows (ROF from the
// protoactions, AnimationRate, transitions with length/exit, speedmodifier, maxvelocity), curve formats and decode
// methods, the B-spline vs knots deviation, bone readout marks, material parameters, provenance (layer per file), the
// audit (a declared-but-unattached whip), the pairing view and the fidelity merge. Pure, CI-safe.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  timingView, clipView, curveDeviation, boneView, materialView, materialIdsOf, provenanceView, auditView,
  applyTimelineFidelity, fidelityView, pairingView, TIMELINE_FIDELITY,
} from '../../viewer/panels/data.js';

const close = (a, b, tol = 1e-12, msg = '') => assert.ok(Math.abs(a - b) <= tol, `${msg} ${a} != ${b} (tol ${tol})`);
const f32 = (a) => Float32Array.from(a);

function manifest() {
  return {
    layers: [{ id: 'mod:test-mod', kind: 'mod', title: 'test-mod', priority: 1 }, { id: 'game', kind: 'game', title: 'game archives' }],
    provenance: [
      { layer: 'game', path: 'data/protoy.xml.xmb', sha256: 'a'.repeat(64), size: 10, container: 'Data.bar', note: null },
      { layer: 'game', path: 'data/tactics/x.tactics.xmb', sha256: 'b'.repeat(64), size: 5, container: 'Data.bar' },
      { layer: 'mod:test-mod', path: 'art/u/horse.xml', sha256: 'c'.repeat(64), size: 3, container: null },
      { layer: 'game', path: 'art/u/rider.xml', sha256: 'd'.repeat(64), size: 3, container: 'ArtUnits.bar' },
      { layer: 'game', path: 'art/u/horse_0.gr2', sha256: 'e'.repeat(64), size: 9, container: 'ArtUnits.bar' },
      { layer: 'game', path: 'art/a/horse_attack.gr2', sha256: 'f'.repeat(64), size: 9, container: 'Art.bar' },
      { layer: 'mod:test-mod', path: 'art/u/horse_0.material', sha256: '1'.repeat(64), size: 2, container: null },
      { layer: 'game', path: 'render/materialdefs/default.materialdef', sha256: '2'.repeat(64), size: 2, container: 'Render.bar' },
      { layer: 'game', path: 'art/u/textures/horse_basecolor.ddt', sha256: '3'.repeat(64), size: 2, container: 'ArtUnits.bar' },
      { layer: 'tool', path: 'tonemap_lut', sha256: '4'.repeat(64), size: 1, container: null },
    ],
    proto: { name: 'zpTest', provenance: 0, maxvelocity: 6.5, maxrunvelocity: 8.5, movementtype: 'land',
      protoactions: [{ name: 'MeleeHandAttack', rof: 1.5, damage: 19, maxrange: null },
        { name: 'TrampleHandAttack', rof: 2.0, damage: 17, maxrange: 2.5 }],
      sources: [{ layer: 'game', provenance: 0, rule: 'base' }] },
    tactics: { id: 'data/tactics/x.tactics', provenance: 1, tactics: [
      { name: 'Melee', actions: [{ name: 'MeleeHandAttack', priority: 25 }] },
      { name: 'Trample', actions: [{ name: 'TrampleHandAttack', priority: 25 }] }] },
    timing: {
      status: 'hypothesis',
      rules: ['H1: the protoaction ROF overrides the tactics ROF', 'H2: tags scale with the clip, not with ROF'],
      actions: [
        { action: 'MeleeHandAttack', anim: 'Attack', idleanim: 'Idle', reloadanim: null, rof_effective: 1.5,
          rof_source: 'protoaction', rof_tactics: null, rof_protoaction: 1.5, animationrate: null,
          clip_durations: [1.0, 1.5], tactics: [{ tactic: 'Melee', priority: 25 }], rules: [], notes: [] },
        { action: 'TrampleHandAttack', anim: 'attack', idleanim: 'Idle', reloadanim: null, rof_effective: 2.0,
          rof_source: 'protoaction', rof_tactics: 1.0, rof_protoaction: 2.0, animationrate: 0.5, clip_durations: [1.0, null],
          tactics: [{ tactic: 'Trample', priority: 25 }], rules: [], notes: ['protoaction ROF 2 differs from the tactics ROF 1'] },
        { action: 'Bombard', anim: 'Bombard_attack', rof_effective: null, rof_source: 'none', clip_durations: [], tactics: [] },
      ],
      movement: { maxvelocity: 6.5, maxrunvelocity: 8.5, tactics: [
        { tactic: 'Melee', speedmodifier: null, maxvelocity_effective: 6.5, maxrunvelocity_effective: 8.5,
          anims: { idle: 'Idle', walk: 'Walk' }, transitions: [], rule: null },
        { tactic: 'Trample', speedmodifier: 0.5, maxvelocity_effective: 3.25, maxrunvelocity_effective: 4.25,
          anims: { idle: 'Idle' }, rule: 'H4: a tactic speedmodifier multiplies maxvelocity / maxrunvelocity',
          transitions: [{ tactic: 'Melee', length: 0.3, exit: true, anim: 'Cover_Out', automatic: false }] }] },
      anims_unreferenced: ['Highstep'], anims_missing: [],
    },
    composition: { main: 'u/horse.xml', children: [], pairing: { child: 'u/rider.xml',
      rule: 'same anim name; main variant i -> child variant i mod n', status: 'hypothesis',
      sync_modes: ['absolute-time', 'normalised-phase'], one_sided: [{ anim: 'Highstep', side: 'main' }],
      mismatches: [{ anim: 'Attack', variant: 1, child_variant: 0, main_duration: 1.5, child_duration: 1.0 }],
      pairs: [{ anim: 'Attack', main_variant: 0, child_variant: 0, rule: 'index-mod-1' }], ragdoll: ['Death_by_havoc'] } },
    animfiles: {
      'u/horse.xml': { provenance: 2, anims: {
        Attack: { variants: [{ clip: 'a/horse_attack.gr2' }, { clip: 'a/horse_attack.gr2' }] },
        Highstep: { variants: [{ clip: 'a/horse_attack.gr2' }] } },
      audit: [{ code: 'bone-unresolved', bone: 'HS Bone Hoof Frnt Lt', uses: ['definebone'], models: ['u/horse_0.gr2'] }] },
      'u/rider.xml': { provenance: 3, anims: { Attack: { variants: [{ clip: 'a/rider_attack.gr2' }] } },
        audit: [{ code: 'declared-not-attached', attachment: 'attachment_whip', include: 'u/whip.xml' }] },
    },
    models: {
      'u/horse_0.gr2': { provenance: 4, decodable: true, meshes: [{ groups: [{ material: 'u/horse_0.material#mata' },
        { material: 'u/horse_0.material#mata' }, { material: null }] }] },
      'u/whip.gr2': { provenance: 4, decodable: false, unavailable_reason: 'gr2-compressed-oodle1', meshes: [] },
    },
    materials: {
      'u/horse_0.material#mata': { material_file: 'u/horse_0.material', submaterial: 'mata', provenance: 6,
        materialdef: 'default', materialdef_path: 'render/materialdefs/default.materialdef', materialdef_provenance: 7,
        eol: 'crlf', flags: { cutout: true },
        slots: { BaseColor: { texture: 'u/textures/horse_basecolor.ddt', srgb: true, source: 'override' },
          Masks: { texture: null, srgb: false, source: 'materialdef', default: 'missingmasks', unavailable_reason: 'override-missing' } },
        floats: { 'AO Intensity': 1.0, Lift: [0.1, 0.2] }, float_sources: { 'AO Intensity': 'materialdef', Lift: 'override' },
        unknown_overrides: [] },
    },
    textures: { 'u/textures/horse_basecolor.ddt': { id: 'u/textures/horse_basecolor.ddt', provenance: 8, decodable: true,
      bc: 'BC3', width: 512, height: 256, mip_count: 8, ddt_format: 5 } },
    clips: {
      'a/horse_attack.gr2': { id: 'a/horse_attack.gr2', path: 'a/horse_attack.gr2', provenance: 5, layer: 'game',
        decodable: true, duration: 1.0, timestep: 1 / 186.4, oversampling: 8, fps_declared: 186.4, key_count: 187,
        formats: ['K32fC32f', 'D3Constant32f', 'Identity'], track_group: { name: 'root' },
        tracks: [
          { bone: 'spine', position: { kind: 'constant', dim: 3, format: 'D3Constant32f', value: [0, 1, 0] },
            orientation: { kind: 'bspline', dim: 4, degree: 2, format: 'K32fC32f', knots: f32([0, 0.25, 0.5, 0.75, 1.0]),
              controls: f32([0, 0, 0, 1, 0, 0.7071068, 0, 0.7071068, 0, 1, 0, 0, 0, 0.7071068, 0, 0.7071068, 0, 0, 0, 1]) },
            scale_shear: { kind: 'identity', dim: 9, format: 'Identity', inferred: false } },
          { bone: 'neck', position: { kind: 'bspline', dim: 3, degree: 2, format: 'K32fC32f', knots: f32([0, 0.5, 1.0]),
            controls: f32([0, 0, 0, 0, 1, 0, 0, 0, 0]) },
            orientation: { kind: 'identity', dim: 4, format: 'K32fC32f', inferred: true },
            scale_shear: { kind: 'identity', dim: 9, format: 'Identity', inferred: false } },
        ] },
      'a/linear.gr2': { id: 'a/linear.gr2', decodable: true, duration: 1.0, fps_declared: 60, key_count: 61, formats: ['K32fC32f'],
        tracks: [{ bone: 'x', position: { kind: 'bspline', dim: 3, degree: 1, format: 'K32fC32f', knots: f32([0, 1]),
          controls: f32([0, 0, 0, 1, 1, 1]) }, orientation: { kind: 'identity', dim: 4, format: 'Identity' },
        scale_shear: { kind: 'identity', dim: 9, format: 'Identity' } }] },
      'a/rider_attack.gr2': { id: 'a/rider_attack.gr2', decodable: false, unavailable_reason: 'curve-format-d4nk16uc15u',
        duration: 1.0, fps_declared: 60, key_count: 61, formats: ['D4nK16uC15u'], tracks: [] },
    },
    warnings: [{ code: 'attachment-declared-not-attached', path: 'u/rider.xml', layer: 'game', message: 'attachment_whip ...' },
      { code: 'bone-unresolved', path: 'u/horse.xml', message: 'bone "HS Bone Hoof Frnt Lt" ...' },
      { code: 'bone-unresolved', path: 'u/horse.xml', message: 'bone "HS Bone Hoof Back Lt" ...' }],
    fidelity: { calibration: 'none', shader_model: 'none', viewer: 'm2', stages: { pose: 'M', timing: 'H', key_grid: 'A' },
      notes: { pose: 'p', timing: 't', key_grid: 'bundle note wins' } },
  };
}

test('timing view: ROF from the protoactions, fit, AnimationRate, tactics with transitions, movement and rules', () => {
  const v = timingView(manifest(), 'ATTACK');
  assert.equal(v.status, 'hypothesis');
  assert.equal(v.actions.length, 3);
  assert.deepEqual(v.current.map((r) => r.action), ['MeleeHandAttack', 'TrampleHandAttack'], 'case-insensitive anim match');
  const melee = v.actions[0];
  assert.equal(melee.rof_effective, 1.5);
  assert.equal(melee.rof_source, 'protoaction');
  assert.equal(melee.damage, 19);
  assert.deepEqual(melee.fit.map((x) => +x.toFixed(6)), [0.666667, 1]);
  assert.deepEqual(melee.tactics, ['Melee (25)']);
  const trample = v.actions[1];
  assert.equal(trample.animationrate, 0.5);
  assert.equal(trample.rof_tactics, 1.0);
  assert.deepEqual(trample.fit, [0.5, null]);
  assert.equal(trample.maxrange, 2.5);
  assert.equal(v.actions[2].rof_source, 'none');
  assert.deepEqual(v.actions[2].fit, []);
  const tr = v.tactics.find((t) => t.tactic === 'Trample');
  assert.equal(tr.speedmodifier, 0.5);
  assert.equal(tr.maxvelocity, 3.25);
  assert.equal(tr.maxrunvelocity, 4.25);
  assert.deepEqual(tr.transitions, [{ tactic: 'Melee', length: 0.3, exit: true, anim: 'Cover_Out', action: null, automatic: false }]);
  assert.deepEqual(tr.actions, ['TrampleHandAttack (25)']);
  assert.equal(v.transitions_total, 1);
  assert.deepEqual(v.movement, { maxvelocity: 6.5, maxrunvelocity: 8.5, movementtype: 'land' });
  assert.ok(v.rules.some((r) => r.startsWith('H4')), 'the tactic rule joins the rule list');
  assert.ok(v.viewer_rules.some((r) => r.startsWith('H1 ROF fit')));
  assert.deepEqual(v.unreferenced, ['Highstep']);
  assert.equal(v.tactics_file, 'data/tactics/x.tactics');
  assert.deepEqual(v.actions_for_anim, ['MeleeHandAttack', 'TrampleHandAttack']);
});

test('clip view: key grid flags, formats and the decode method of every curve', () => {
  const c = clipView(manifest(), 'a/horse_attack.gr2');
  assert.equal(c.fps_rounded, 186);
  assert.ok(c.non_integer, 'declared 186.4 fps is flagged');
  assert.equal(c.key_count, 187);
  assert.equal(c.tracks, 2);
  assert.equal(c.inferred_identity, 1);
  const m = Object.fromEntries(c.methods.map((x) => [x.format + '|' + x.kind + '|' + (x.degree ?? ''), x.count]));
  assert.deepEqual(m, { 'K32fC32f|bspline|2': 2, 'D3Constant32f|constant|': 1, 'Identity|identity|': 2, 'K32fC32f|identity|': 1 });
  assert.match(c.methods.find((x) => x.kind === 'bspline').method, /B-spline degree 2/);
  const u = clipView(manifest(), 'a/rider_attack.gr2');
  assert.equal(u.decodable, false);
  assert.equal(u.unavailable_reason, 'curve-format-d4nk16uc15u');
  assert.ok(clipView(manifest(), 'nope.gr2').missing);
});

test('B-spline vs knots deviation: zero for degree <= 1, measured for degree 2, null when undecodable', () => {
  const m = manifest();
  const bundle = { manifest: m, view: (v) => v };
  assert.deepEqual(curveDeviation(bundle, 'a/linear.gr2'), { position: 0, orientation: 0, scale_shear: 0, keys: 61, worst: null });
  const d = curveDeviation(bundle, 'a/horse_attack.gr2');
  assert.equal(d.keys, 187);
  // neck position: degree-2 B-spline over controls 0, 1, 0 on knots 0, 0.5, 1 - its peak at t = 0.5 is 0.5 (the knots
  // view reaches 1 there): max deviation 0.5 on y
  close(d.position, 0.5, 1e-6, 'position deviation');
  assert.ok(d.orientation > 1 && d.orientation < 90, 'orientation deviation in degrees: ' + d.orientation);
  assert.equal(d.scale_shear, 0);
  assert.ok(d.worst && ['neck', 'spine'].includes(d.worst.bone));
  assert.equal(curveDeviation(bundle, 'a/rider_attack.gr2'), null);
});

test('bone view: world readout from the posed instance, track or rest, attach and footprint marks', () => {
  const worlds = new Float64Array(3 * 16);
  for (let i = 0; i < 3; i++) { worlds[i * 16] = worlds[i * 16 + 5] = worlds[i * 16 + 10] = worlds[i * 16 + 15] = 1;
    worlds[i * 16 + 12] = i; worlds[i * 16 + 13] = 2 * i; worlds[i * 16 + 14] = -i; }
  const model = { id: 'h.gr2', names: ['root', 'HS_Bone_Hoof_Frnt_Lt', 'bone_attachpoint'], parents: Int32Array.from([-1, 0, 0]),
    binding: () => Int32Array.from([0, -1, 1]) };
  const rig = { instances: [
    { index: 0, role: 'main', model, clip: { id: 'c' }, worlds, time: 0.4, clock: 'main' },
    { index: 1, role: 'child', model: { id: 'r', names: [], parents: [] }, parent: 0, attach: { a: 'RiderAttachment',
      attachment: 'RiderAttachment', tobone: 'ATTACHPOINT', toIndex: 2, fromIndex: -1 } }] };
  const v = boneView(rig, 0, { footprintBones: ['HS Bone Hoof Frnt Lt'] });
  assert.deepEqual(v.instance, { index: 0, role: 'main', model: 'h.gr2', clip: 'c', time: 0.4, clock: 'main' });
  assert.deepEqual(v.rows.map((r) => r.source), ['track', 'rest', 'track']);
  assert.deepEqual(v.rows[2].world, [2, 4, -2]);
  assert.equal(v.rows[1].parent, 'root');
  assert.deepEqual(v.rows[1].marks, ['footprint'], 'engine name rule: space = underscore, any case');
  assert.deepEqual(v.rows[2].marks, ['attach RiderAttachment (tobone ATTACHPOINT)']);
  assert.deepEqual(boneView(rig, 5), { rows: [], instance: null });
});

test('materials: slots with texture format, merged parameters with their source, layer', () => {
  const m = manifest();
  assert.deepEqual(materialIdsOf(m, ['u/horse_0.gr2', 'u/whip.gr2']), ['u/horse_0.material#mata']);
  const [mat] = materialView(m, ['u/horse_0.gr2']);
  assert.equal(mat.materialdef, 'default');
  assert.equal(mat.layer, 'mod:test-mod');
  const base = mat.slots.find((s) => s.name === 'BaseColor');
  assert.deepEqual([base.bc, base.size, base.mips, base.srgb, base.source], ['BC3', [512, 256], 8, true, 'override']);
  const masks = mat.slots.find((s) => s.name === 'Masks');
  assert.equal(masks.unavailable_reason, 'override-missing');
  assert.deepEqual(mat.floats, [{ name: 'AO Intensity', value: 1.0, source: 'materialdef' }, { name: 'Lift', value: [0.1, 0.2], source: 'override' }]);
  assert.deepEqual(mat.flags, { cutout: true });
});

test('provenance: the layer of every file behind the drawn anim, files per layer', () => {
  const v = provenanceView(manifest(), { animfiles: ['u/horse.xml', 'u/rider.xml'], models: ['u/horse_0.gr2'],
    clips: ['a/horse_attack.gr2'] });
  const by = Object.fromEntries(v.rows.map((r) => [r.kind + ' ' + r.id, r.layer]));
  assert.deepEqual(by, {
    'proto zpTest': 'game', 'tactics data/tactics/x.tactics': 'game', 'animfile u/horse.xml': 'mod:test-mod',
    'animfile u/rider.xml': 'game', 'model u/horse_0.gr2': 'game', 'clip a/horse_attack.gr2': 'game',
    'material u/horse_0.material': 'mod:test-mod', 'materialdef render/materialdefs/default.materialdef': 'game',
    'texture u/textures/horse_basecolor.ddt': 'game',
  }, 'the proto source record is the same file as the proto: listed once');
  assert.equal(v.rows.find((r) => r.kind === 'clip').container, 'Art.bar');
  assert.equal(v.rows[0].sha256, 'aaaaaaaaaaaa');
  assert.deepEqual(v.layers.map((l) => [l.id, l.files, l.here]), [['mod:test-mod', 2, 2], ['game', 7, 7], ['other', 1, 0]]);
  assert.equal(v.total, 10);
});

test('audit: animfile audits (the whip declared but never attached), unavailable records, warnings by code', () => {
  const v = auditView(manifest());
  assert.deepEqual(v.items.map((i) => i.code), ['bone-unresolved', 'declared-not-attached']);
  assert.deepEqual(v.unattached.map((u) => [u.animfile, u.detail]), [['u/rider.xml', { attachment: 'attachment_whip', include: 'u/whip.xml' }]]);
  assert.deepEqual(v.unavailable, [{ kind: 'model', id: 'u/whip.gr2', reason: 'gr2-compressed-oodle1' },
    { kind: 'clip', id: 'a/rider_attack.gr2', reason: 'curve-format-d4nk16uc15u' }]);
  assert.deepEqual(v.byCode, { 'attachment-declared-not-attached': 1, 'bone-unresolved': 2 });
});

test('pairing view: rule and status, i mod n pairs, mismatches, the horse-only fallback, ragdoll', () => {
  const m = manifest();
  const a = pairingView(m, 'Attack');
  assert.equal(a.status, 'hypothesis');
  assert.deepEqual(a.pairs.map((p) => [p.main_variant, p.child_variant, p.rule, p.mismatch]),
    [[0, 0, 'index-mod-1', false], [1, 0, 'index-mod-1', true]]);
  assert.equal(a.pairs[1].child_clip, 'a/rider_attack.gr2');
  assert.equal(a.one_sided, null);
  const hs = pairingView(m, 'highstep');
  assert.deepEqual(hs.one_sided, { anim: 'Highstep', side: 'main' });
  assert.match(hs.fallback, /assumption/);
  assert.equal(pairingView(m, 'Death_by_havoc').ragdoll, true);
});

test('fidelity: the timeline stages join the bundle block without overriding it; badge counts', () => {
  const m = manifest();
  const added = applyTimelineFidelity(m);
  assert.deepEqual(added, Object.keys(TIMELINE_FIDELITY).filter((k) => k !== 'key_grid'));
  assert.equal(m.fidelity.stages.key_grid, 'A', 'a stage the bundle has is never overridden');
  assert.equal(m.fidelity.notes.key_grid, 'bundle note wins');
  assert.equal(m.fidelity.stages.tag_overflow, 'U');
  assert.equal(m.fidelity.stages.tactics_rate, 'H');
  assert.equal(m.fidelity.viewer_stages.footprint, 'm4-timeline');
  assert.deepEqual(applyTimelineFidelity(m), [], 'idempotent');
  const f = fidelityView(m);
  assert.equal(f.rows.length, 2 + Object.keys(TIMELINE_FIDELITY).length);
  assert.deepEqual(f.counts, { M: 1, A: 2, U: 1, H: 4 });
  assert.equal(f.letters, f.rows.map((r) => r.flag).join(''));
  assert.equal(f.rows.find((r) => r.stage === 'footprint').source, 'viewer m4-timeline');
  assert.equal(f.rows.find((r) => r.stage === 'pose').source, 'bundle');
  const fresh = fidelityView(manifest());                   // without apply: merged on the fly, same counts
  assert.deepEqual(fresh.counts, f.counts);
});
