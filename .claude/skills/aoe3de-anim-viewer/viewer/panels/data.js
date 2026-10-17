// Data panels of the viewer (M4), the pure half: every table the page shows is built here from the bundle manifest
// and the posed rig, so node --test checks the numbers (tests/js/panels.test.mjs on a synthetic manifest,
// tests/js/m4/*.test.mjs on a bundle that bundle.py writes from the synthetic unit). panels.js only renders them.
import { prepareCurve } from '../lib/rig.js';
import { evalCurve, nm } from '../lib/skeleton.js';
import { keyGrid, actionsFor, VIEWER_RULES } from '../timeline/model.js';

const lower = (s) => String(s ?? '').toLowerCase();
export function base(id) { return id ? String(id).split('/').pop() : '-'; }

// ------------------------------------------------------------------------------------------------ fidelity
// the timeline's own decisions, merged into the bundle's fidelity block when the bundle does not carry them yet
// (bundle.py FIDELITY_STAGES is the authority: a stage the bundle has is never overridden here)
export const TIMELINE_FIDELITY = {
  key_grid: ['M', 'key ticks at k / round(1 / timestep) s, the clip_decode grid; a non-integer declared rate is ' +
    'flagged on the ruler'],
  tag_timing: ['H', 'tags at fraction x clip duration on the clip\'s own clock (H2); whether animlengthoverride ' +
    'stretches them is unknown (ghost markers)'],
  tag_overflow: ['U', 'fraction > 1 drawn past the clip end in the overflow lane: meaning unknown'],
  variant_choice: ['H', 'the roll is one draw over the normalised weights; anims without <weight> are uniform ' +
    '(hypothesis); when and how the engine draws is not measured'],
  tactics_rate: ['H', 'tactics-rate preset = AnimationRate (H3) x clip / ROF (H1 ROF fit), labelled until the ' +
    'timing run (design section 8 item 9)'],
  footprint: ['A', 'dot at the footprintbone\'s world position at the tag time (viewer pose); a bone only declared ' +
    'by <definebone> sits at the model origin (verified for attaches, assumed for footprints)'],
};

export const FLAG_NAMES = { M: 'measured', A: 'approximated', U: 'unknown', H: 'hypothesis' };

// adds the timeline stages the bundle lacks to manifest.fidelity (in memory, so every in-page consumer - the badge,
// export captions - sees them); returns the stage names added
export function applyTimelineFidelity(manifest) {
  const fid = manifest.fidelity || (manifest.fidelity = {});
  fid.stages = fid.stages || {};
  fid.notes = fid.notes || {};
  const added = [];
  for (const [k, [flag, note]] of Object.entries(TIMELINE_FIDELITY)) {
    if (fid.stages[k] === undefined) {
      fid.stages[k] = flag;
      fid.notes[k] = note;
      added.push(k);
    }
  }
  fid.viewer_stages = Object.assign({}, fid.viewer_stages || {}, Object.fromEntries(added.map((k) => [k, 'm4-timeline'])));
  return added;
}

// rows [{stage, flag, name, note, source}], counts per letter and the letter string of the badge
export function fidelityView(manifest) {
  const fid = manifest.fidelity || {};
  const stages = Object.assign({}, fid.stages || {});
  const notes = Object.assign({}, fid.notes || {});
  const viewer = fid.viewer_stages || {};
  for (const [k, [flag, note]] of Object.entries(TIMELINE_FIDELITY)) {
    if (stages[k] === undefined) { stages[k] = flag; notes[k] = note; viewer[k] = viewer[k] || 'm4-timeline'; }
  }
  const rows = Object.entries(stages).map(([stage, flag]) => ({ stage, flag, name: FLAG_NAMES[flag] || 'unavailable',
    note: notes[stage] || '', source: viewer[stage] ? 'viewer ' + viewer[stage] : 'bundle' }));
  const counts = { M: 0, A: 0, U: 0, H: 0 };
  for (const r of rows) counts[r.flag] = (counts[r.flag] || 0) + 1;
  return { rows, counts, letters: rows.map((r) => r.flag).join(''), calibration: fid.calibration || 'none',
    shader_model: fid.shader_model || 'none', viewer: fid.viewer || null };
}

// ------------------------------------------------------------------------------------------------ timing / tactics
// the tactics rows (one per timing action), the tactics with their transitions, movement and the labelled rules
export function timingView(manifest, anim) {
  const timing = manifest.timing || {};
  const proto = manifest.proto || null;
  const pas = new Map(((proto && proto.protoactions) || []).map((p) => [lower(p.name), p]));
  const tacticsById = new Map((((manifest.tactics || {}).tactics) || []).map((t) => [lower(t.name), t]));
  const actions = (timing.actions || []).map((r) => {
    const pa = pas.get(lower(r.action)) || null;
    const durs = r.clip_durations || [];
    const rof = r.rof_effective;
    return {
      action: r.action, anim: r.anim, current: !!(anim && r.anim && lower(r.anim) === lower(anim)),
      rof_effective: rof ?? null, rof_source: r.rof_source || 'none', rof_protoaction: r.rof_protoaction ?? null,
      rof_tactics: r.rof_tactics ?? null, animationrate: r.animationrate ?? null, idleanim: r.idleanim || null,
      reloadanim: r.reloadanim || null, clip_durations: durs,
      fit: durs.map((d) => (d && rof ? d / rof : null)),
      damage: pa ? pa.damage ?? null : null, maxrange: pa ? pa.maxrange ?? null : null,
      tactics: (r.tactics || []).map((x) => x.tactic + (x.priority !== null && x.priority !== undefined ? ' (' + x.priority + ')' : '')),
      rules: r.rules || [], notes: r.notes || [],
    };
  });
  const mv = timing.movement || {};
  const tactics = (mv.tactics || []).map((t) => {
    const raw = tacticsById.get(lower(t.tactic)) || {};
    return {
      tactic: t.tactic, speedmodifier: t.speedmodifier ?? null, maxvelocity: t.maxvelocity_effective ?? null,
      maxrunvelocity: t.maxrunvelocity_effective ?? null, anims: t.anims || {}, rule: t.rule || null,
      transitions: (t.transitions || []).map((x) => ({ tactic: x.tactic, length: x.length ?? null, exit: x.exit ?? null,
        anim: x.anim || null, action: x.action || null, automatic: x.automatic ?? null })),
      actions: (raw.actions || []).map((a) => a.name + (a.priority !== null && a.priority !== undefined ? ' (' + a.priority + ')' : '')),
    };
  });
  const rules = (timing.rules || []).slice();
  for (const t of tactics) if (t.rule && !rules.includes(t.rule)) rules.push(t.rule);
  return {
    status: timing.status || 'none', actions, current: actions.filter((a) => a.current), tactics,
    movement: { maxvelocity: mv.maxvelocity ?? (proto ? proto.maxvelocity : null) ?? null,
      maxrunvelocity: mv.maxrunvelocity ?? (proto ? proto.maxrunvelocity : null) ?? null,
      movementtype: proto ? proto.movementtype || null : null },
    rules, viewer_rules: Object.values(VIEWER_RULES),
    unreferenced: timing.anims_unreferenced || [], missing: timing.anims_missing || [],
    tactics_file: (manifest.tactics && manifest.tactics.id) || (proto && proto.tactics_file) || null,
    transitions_total: tactics.reduce((n, t) => n + t.transitions.length, 0),
    actions_for_anim: actionsFor(timing, anim).map((r) => r.action),
  };
}

// ------------------------------------------------------------------------------------------------ clips
export const DECODE_METHODS = {
  bspline: (deg) => 'B-spline degree ' + deg + ' (knots + controls, clip_decode Cox-de Boor in JS' +
    (deg > 1 ? '; knots-linear = degree 1 debug view' : '') + ')',
  constant: () => 'constant',
  identity: () => 'identity',
  unavailable: () => 'unavailable: codec not ported, evaluated as the identity',
};

// one clip: timing numbers, key grid flags, formats and how each curve is decoded (counts per format/kind/degree)
export function clipView(manifest, clipId) {
  const c = (manifest.clips || {})[clipId];
  if (!c) return { id: clipId, base: base(clipId), missing: true };
  const grid = keyGrid(c);
  const methods = new Map();
  let inferred = 0;
  for (const tr of c.tracks || []) {
    for (const part of ['position', 'orientation', 'scale_shear']) {
      const cv = tr[part];
      if (!cv) continue;
      if (cv.inferred) inferred++;
      const deg = cv.kind === 'bspline' ? cv.degree : null;
      const key = (cv.format || 'none') + '|' + cv.kind + '|' + (deg ?? '');
      const m = methods.get(key) || { format: cv.format || 'none', kind: cv.kind, degree: deg, count: 0,
        method: (DECODE_METHODS[cv.kind] || DECODE_METHODS.unavailable)(deg), reason: cv.reason || null };
      m.count++;
      methods.set(key, m);
    }
  }
  return {
    id: clipId, base: base(clipId), path: c.path, layer: c.layer || null, decodable: !!c.decodable,
    unavailable_reason: c.unavailable_reason || null, duration: c.duration, timestep: c.timestep,
    oversampling: c.oversampling ?? null, fps_declared: c.fps_declared, fps_rounded: grid.rounded,
    non_integer: grid.nonInteger, last_off_grid: grid.lastOffGrid, key_count: c.key_count, formats: c.formats || [],
    tracks: (c.tracks || []).length, track_group: c.track_group ? c.track_group.name : null, inferred_identity: inferred,
    methods: Array.from(methods.values()).sort((a, b) => b.count - a.count),
  };
}

function quatAngleDeg(a, b) {
  const la = Math.hypot(a[0], a[1], a[2], a[3]) || 1, lb = Math.hypot(b[0], b[1], b[2], b[3]) || 1;
  const d = Math.min(1, Math.abs((a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]) / (la * lb)));
  return (2 * Math.acos(d) * 180) / Math.PI;
}

// the B-spline (contract) against the knots-linear debug view at every key: max deviation per channel
// {position (units), orientation (degrees), scale_shear, keys, worst: {bone, part, time}}
export function curveDeviation(bundle, clipId) {
  const c = bundle.manifest.clips[clipId];
  if (!c || !c.decodable) return null;
  const grid = keyGrid(c);
  const out = { position: 0, orientation: 0, scale_shear: 0, keys: grid.count, worst: null };
  let worstScore = -1;
  for (const tr of c.tracks || []) {
    for (const part of ['position', 'orientation', 'scale_shear']) {
      const rec = tr[part];
      if (!rec || rec.kind !== 'bspline' || rec.degree <= 1) continue;
      const cv = prepareCurve(rec, bundle.view);
      for (let k = 0; k < grid.count; k++) {
        const t = grid.time(k);
        const a = evalCurve(cv, t, 'bspline');
        const b = evalCurve(cv, t, 'knots');
        let dev;
        if (part === 'orientation') dev = quatAngleDeg(a, b);
        else { dev = 0; for (let i = 0; i < a.length; i++) dev = Math.max(dev, Math.abs(a[i] - b[i])); }
        if (dev > out[part]) out[part] = dev;
        const score = part === 'orientation' ? dev / 10 : dev;
        if (score > worstScore && dev > 0) { worstScore = score; out.worst = { bone: tr.bone, part, time: t, value: dev }; }
      }
    }
  }
  return out;
}

// ------------------------------------------------------------------------------------------------ bones
// one instance's bones with the world readout at the rig's current pose: [{index, name, parent, source, world [3],
// marks}]; marks: attach (to/from), footprint, engine alias
export function boneView(rig, instIndex, { footprintBones = [] } = {}) {
  const inst = rig.instances[instIndex];
  if (!inst || !inst.model) return { rows: [], instance: null };
  const m = inst.model;
  const bind = inst.clip ? m.binding(inst.clip) : null;
  const fp = new Set(footprintBones.map((b) => nm(b).trim()));
  const childAttach = rig.instances.filter((x) => x.parent === inst.index && x.attach);
  const rows = m.names.map((name, i) => {
    const w = inst.worlds;
    const marks = [];
    for (const ch of childAttach) if (ch.attach.toIndex === i) marks.push('attach ' + (ch.attach.attachment || ch.attach.a) + ' (tobone ' + ch.attach.tobone + ')');
    if (inst.attach && inst.attach.fromIndex === i) marks.push('frombone of ' + (inst.attach.attachment || inst.attach.a));
    if (fp.has(nm(name).trim())) marks.push('footprint');
    return {
      index: i, name, parent: m.parents[i] >= 0 ? m.names[m.parents[i]] : null,
      source: bind ? (bind[i] >= 0 ? 'track' : 'rest') : 'rest (no clip)',
      world: w ? [w[i * 16 + 12], w[i * 16 + 13], w[i * 16 + 14]] : null, marks,
    };
  });
  return { rows, instance: { index: inst.index, role: inst.role, model: m.id, clip: inst.clip ? inst.clip.id : null,
    time: inst.time ?? null, clock: inst.clock } };
}

// ------------------------------------------------------------------------------------------------ materials
export function materialIdsOf(manifest, modelIds) {
  const out = [];
  for (const mid of modelIds) {
    const m = (manifest.models || {})[mid];
    for (const mesh of (m && m.meshes) || []) {
      for (const g of mesh.groups || []) if (g.material && !out.includes(g.material)) out.push(g.material);
    }
  }
  return out;
}

export function materialView(manifest, modelIds) {
  const prov = manifest.provenance || [];
  return materialIdsOf(manifest, modelIds).map((id) => {
    const mat = (manifest.materials || {})[id];
    if (!mat) return { id, missing: true };
    const slots = Object.entries(mat.slots || {}).map(([name, s]) => {
      const tex = s.texture ? (manifest.textures || {})[s.texture] : null;
      return { name, texture: s.texture || null, srgb: !!s.srgb, source: s.source || null,
        unavailable_reason: s.unavailable_reason || (tex && tex.decodable === false ? tex.unavailable_reason : null),
        bc: tex ? tex.bc || null : null, size: tex ? [tex.width, tex.height] : null, mips: tex ? tex.mip_count : null,
        ddt_format: tex ? tex.ddt_format ?? null : null, default: s.default || null };
    });
    const floats = Object.entries(mat.floats || {}).map(([name, value]) => ({ name, value,
      source: (mat.float_sources || {})[name] || null }));
    const p = prov[mat.provenance];
    return { id, material_file: mat.material_file, submaterial: mat.submaterial, materialdef: mat.materialdef,
      materialdef_path: mat.materialdef_path || null, eol: mat.eol || null, flags: mat.flags || {}, slots, floats,
      unknown_overrides: mat.unknown_overrides || [], layer: p ? p.layer : null };
  });
}

// ------------------------------------------------------------------------------------------------ provenance
// the files behind what is drawn now (kind, id, layer, container, sha256), plus every layer with its file count
export function provenanceView(manifest, { animfiles = [], models = [], clips = [] } = {}) {
  const prov = manifest.provenance || [];
  const rows = [];
  const seen = new Set();
  const add = (kind, id, idx, extra = {}) => {
    if (idx === null || idx === undefined || seen.has(kind + '|' + id)) return;
    seen.add(kind + '|' + id);
    const p = prov[idx] || {};
    rows.push(Object.assign({ kind, id, layer: p.layer || null, path: p.path || null, container: p.container || null,
      sha256: p.sha256 ? p.sha256.slice(0, 12) : null, size: p.size ?? null, note: p.note || null }, extra));
  };
  if (manifest.proto) add('proto', manifest.proto.name, manifest.proto.provenance);
  for (const s of (manifest.proto && manifest.proto.sources) || []) {   // protomods merges; the base is the proto row
    if (s.provenance !== manifest.proto.provenance) add('proto ' + (s.rule || 'source'), s.layer + ' ' + (s.rule || ''), s.provenance);
  }
  if (manifest.tactics) add('tactics', manifest.tactics.id, manifest.tactics.provenance);
  for (const id of animfiles) { const a = (manifest.animfiles || {})[id]; if (a) add('animfile', id, a.provenance); }
  for (const id of models) { const m = (manifest.models || {})[id]; if (m) add('model', id, m.provenance); }
  for (const id of clips) { const c = (manifest.clips || {})[id]; if (c) add('clip', id, c.provenance); }
  for (const mid of materialIdsOf(manifest, models)) {
    const mat = (manifest.materials || {})[mid];
    if (!mat) continue;
    add('material', mat.material_file, mat.provenance);
    if (mat.materialdef_path) add('materialdef', mat.materialdef_path, mat.materialdef_provenance);
    for (const s of Object.values(mat.slots || {})) {
      const tex = s.texture ? (manifest.textures || {})[s.texture] : null;
      if (tex) add('texture', tex.id, tex.provenance);
    }
  }
  const layers = (manifest.layers || []).map((l) => ({ id: l.id, kind: l.kind, title: l.title, priority: l.priority ?? null,
    files: prov.filter((p) => p.layer === l.id).length, here: rows.filter((r) => r.layer === l.id).length }));
  const other = prov.filter((p) => !(manifest.layers || []).some((l) => l.id === p.layer));
  if (other.length) layers.push({ id: 'other', kind: 'synthetic/tool', title: 'synthetic or tool records', priority: null,
    files: other.length, here: rows.filter((r) => !(manifest.layers || []).some((l) => l.id === r.layer)).length });
  return { rows, layers, total: prov.length };
}

// ------------------------------------------------------------------------------------------------ audit
// animfile audits, unavailable records and the warnings, never hidden (bundle-schema sections 5 and 13)
export function auditView(manifest) {
  const items = [];
  for (const [afid, af] of Object.entries(manifest.animfiles || {})) {
    for (const a of af.audit || []) {
      const { code, ...rest } = a;
      items.push({ code, animfile: afid, detail: rest });
    }
  }
  const unavailable = [];
  for (const kind of ['models', 'clips', 'textures']) {
    for (const [id, r] of Object.entries(manifest[kind] || {})) {
      if (r && r.decodable === false) unavailable.push({ kind: kind.slice(0, -1), id, reason: r.unavailable_reason || null });
    }
  }
  const warnings = (manifest.warnings || []).map((w) => ({ code: w.code, path: w.path || null, layer: w.layer || null,
    message: w.message || '' }));
  const byCode = {};
  for (const w of warnings) byCode[w.code] = (byCode[w.code] || 0) + 1;
  const unattached = items.filter((i) => i.code === 'declared-not-attached');
  return { items, unavailable, warnings, byCode, unattached };
}

// ------------------------------------------------------------------------------------------------ pairing
// the pairing the picker shows for one anim: rule and status, pairs with both clips and durations, mismatches,
// one-sided anims (the rider fallback is an assumption)
export function pairingView(manifest, anim) {
  const comp = manifest.composition || {};
  const p = comp.pairing || {};
  const main = (manifest.animfiles || {})[comp.main] || {};
  const child = p.child ? (manifest.animfiles || {})[p.child] || {} : null;
  const findAnim = (af, name) => {
    if (!af || !af.anims) return null;
    const k = Object.keys(af.anims).find((x) => lower(x) === lower(name));
    return k ? af.anims[k] : null;
  };
  const ma = findAnim(main, anim);
  const ca = child ? findAnim(child, anim) : null;
  const dur = (id) => (id && (manifest.clips || {})[id] ? manifest.clips[id].duration : null);
  const oneSided = (p.one_sided || []).find((o) => lower(o.anim) === lower(anim)) || null;
  const pairs = ((ma && ma.variants) || []).map((v, i) => {
    const n = ca ? ca.variants.length : 0;
    const j = n ? i % n : -1;
    const cv = j >= 0 ? ca.variants[j] : null;
    const mism = (p.mismatches || []).find((x) => lower(x.anim) === lower(anim) && x.variant === i) || null;
    const bp = (p.pairs || []).find((x) => lower(x.anim) === lower(anim) && x.main_variant === i) || null;
    return { main_variant: i, main_clip: v.clip, main_duration: dur(v.clip), child_variant: bp ? bp.child_variant : j,
      child_clip: cv ? cv.clip : null, child_duration: cv ? dur(cv.clip) : null,
      rule: bp ? bp.rule : (j < 0 ? 'none' : (n === ((ma && ma.variants.length) || 0) ? 'index' : 'index-mod-' + n)),
      mismatch: !!mism };
  });
  const ragdoll = Array.isArray(p.ragdoll) ? p.ragdoll.some((a) => lower(a) === lower(anim))
    : (manifest.warnings || []).some((w) => w.code === 'ragdoll-not-simulated' && lower(w.message).includes('anim ' + lower(anim) + ':'));
  return { rule: p.rule || null, status: p.status || null, child: p.child || null, sync_modes: p.sync_modes || [],
    one_sided: oneSided, fallback: oneSided ? 'the rider falls back to its Idle (assumption)' : null, pairs, ragdoll };
}
