// Timeline maths of the viewer (M4): where every clip, key and tag of the composed unit sits on the main clock, the
// variant weights and the weighted roll, the key grid, the tactics-rate preset and tag stepping. Pure: no DOM, no GL,
// no bundle reads beyond the records handed in, so node --test runs it (tests/js/timeline.test.mjs).
//
// Clocks (rig.js; bundle-schema section 18): main time t runs from 0 to the main clip's duration D.
//   main      the main clip itself                       clip time = t
//   absolute  a synced child (syncanims=1)               clip time = t, the child holds its last key past its end
//   phase     a synced child in normalised phase         clip time = t / D * d
//   own       a syncanims=0 attachment, looping          clip time = t mod d
// A tag at fraction f of a clip of duration d happens at clip time f * d (bundle-schema section 9: the viewer's
// rule; H2 "tags scale with the clip, not with ROF"). Its main times follow from the clock; an `own` clip repeats
// inside [0, D]. A main time past D is never reached while the main clip loops (shown, flagged). f > 1 (202 vanilla
// tags, up to 1.6) goes to the overflow lane: meaning unknown. animlengthoverride is a second length; whether it
// stretches the tags is unknown, so the stretched times are only ghosts (hypothesis).

export const TAG_LANES = ['Attack', 'FootstepLeft', 'FootstepRight', 'SpecificSoundSet', 'Particles', 'WindEffect',
  'CameraShake'];
export const OTHER_LANE = 'other';
export const OVERFLOW_LANE = 'overflow';
export const FOOTSTEP_TYPES = ['footstepleft', 'footstepright'];
export const SPEEDS = [0.1, 0.25, 0.5, 0.75, 1, 1.5, 2];
export const EPS = 1e-9;
const REPEAT_LIMIT = 256;

// hypotheses the timeline adds to the bundle's timing rules (tactics.py RULES H1..H4); shown in the timing panel
export const VIEWER_RULES = {
  'H1 ROF fit': 'H1 ROF fit (viewer): one cycle of the action\'s anim lasts the effective ROF (the ROF H1 picks: the ' +
    'protoaction over the tactics value); playback rate = clip duration / ROF',
  'H3': 'H3: AnimationRate multiplies the clip playback rate',
  'tags': 'tags at fraction x clip duration on the clip\'s own clock (bundle-schema section 9; H2)',
  'override': 'animlengthoverride: a second length; whether it stretches tags is unknown (ghost markers only)',
  'overflow': 'fraction > 1: drawn past the clip end, meaning unknown',
  'roll': 'roll: one weighted draw over the normalised weights; how and when the engine draws is not measured',
};

const lower = (s) => String(s ?? '').toLowerCase();

export function laneOf(tag) {
  if (tag.overflow || Number(tag.fraction) > 1) return OVERFLOW_LANE;
  const k = TAG_LANES.find((l) => lower(l) === lower(tag.type));
  return k || OTHER_LANE;
}

export function isFootstep(tag) { return FOOTSTEP_TYPES.includes(lower(tag.type)); }

// ------------------------------------------------------------------------------------------------ variants, weights
// animfile.weights_of, value for value: declared | uniform-hypothesis | mixed (a variant without <weight> counts 1)
export function weightsOf(variants) {
  if (!variants || !variants.length) return { rule: 'none', normalized: [] };
  const ws = variants.map((v) => (v.weight === null || v.weight === undefined ? null : Number(v.weight)));
  const have = ws.map((w) => w !== null);
  let rule, vals;
  if (have.every(Boolean)) { rule = 'declared'; vals = ws.slice(); }
  else if (!have.some(Boolean)) { rule = 'uniform-hypothesis'; vals = ws.map(() => 1); }
  else { rule = 'mixed'; vals = ws.map((w) => (w === null ? 1 : w)); }
  let tot = vals.reduce((a, b) => a + b, 0);
  if (!(tot > 0)) { vals = vals.map(() => 1); tot = vals.length; }
  return { rule, normalized: vals.map((x) => x / tot) };
}

export const WEIGHT_LABELS = {
  declared: 'declared weights',
  'uniform-hypothesis': 'uniform (hypothesis): no variant declares a <weight>',
  mixed: 'mixed (hypothesis): a variant without <weight> counts 1',
  none: 'no variants',
};

// the picker's view of an anim: the bundle's normalised weights (recomputed when absent), raw weights, the label
export function variantWeights(animRec) {
  const variants = (animRec && animRec.variants) || [];
  const own = weightsOf(variants);
  const b = animRec && animRec.weights;
  const normalized = b && Array.isArray(b.normalized) && b.normalized.length === variants.length ? b.normalized
    : own.normalized;
  const rule = (b && b.rule) || own.rule;
  return {
    rule, label: WEIGHT_LABELS[rule] || rule, hypothesis: rule !== 'declared', normalized,
    raw: variants.map((v) => (v.weight === null || v.weight === undefined ? null : Number(v.weight))),
    sum: variants.reduce((a, v) => a + (v.weight === null || v.weight === undefined ? 0 : Number(v.weight)), 0),
  };
}

// a small deterministic generator (test mode uses a fixed seed; the page seeds it from the clock)
export function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// one weighted draw: the first index whose cumulative weight passes u in [0, 1)
export function rollVariant(normalized, rng = Math.random) {
  const n = (normalized || []).length;
  if (!n) return -1;
  const tot = normalized.reduce((a, b) => a + b, 0) || 1;
  const u = rng() * tot;
  let acc = 0;
  for (let i = 0; i < n; i++) {
    acc += normalized[i];
    if (u < acc) return i;
  }
  return n - 1;
}

// ------------------------------------------------------------------------------------------------ key grid
// the clip_decode key grid: key k at k / round(fps) s, the last key at the duration; fps from the stored timestep.
// nonInteger: fps_declared is not an integer (184-191 in vanilla): the grid uses the rounded rate (flagged).
// lastOffGrid: the duration is not a whole number of steps (the last key is shorter).
export function keyGrid(clip) {
  const duration = clip ? Number(clip.duration) || 0 : 0;
  const fps = clip ? Number(clip.fps ?? clip.fps_declared) || 0 : 0;
  const rounded = Math.round(fps);
  const steps = duration * rounded;
  const count = clip && (clip.keyCount ?? clip.key_count) ? Number(clip.keyCount ?? clip.key_count)
    : (rounded ? Math.round(steps) + 1 : 1);
  return {
    duration, fps, rounded, count, step: rounded ? 1 / rounded : 0,
    nonInteger: fps > 0 && Math.abs(fps - rounded) > 1e-3,
    lastOffGrid: rounded > 0 && Math.abs(steps - Math.round(steps)) > 1e-3,
    time: (k) => (rounded ? Math.min(k / rounded, duration) : 0),
    keyAt: (t) => (rounded ? Math.max(0, Math.min(count - 1, Math.round(t * rounded))) : 0),
  };
}

// ------------------------------------------------------------------------------------------------ clocks
// clip time of a clock at main time t (rig.js Rig.clipTime, repeated here so the timeline is checkable alone)
export function clipTimeAt(clock, t, d, D) {
  if (clock === 'phase') return D > 0 ? Math.min(Math.max(t / D, 0), 1) * d : 0;
  if (clock === 'own') return d > 0 ? ((t % d) + d) % d : 0;
  return Math.min(Math.max(t, 0), d);
}

// main times at which clip time c (seconds) happens, within [0, horizon]; the first one even when past horizon
export function mainTimesOf(clock, c, d, D, horizon = D) {
  if (clock === 'phase') return [d > 0 ? (c / d) * D : 0];
  if (clock === 'own') {
    if (!(d > 0)) return [c];
    if (c > d + EPS) return [c];                          // overflow past its own clip end: once, meaning unknown
    const out = [];
    for (let k = 0; k < REPEAT_LIMIT; k++) {
      const m = c + k * d;
      if (m > horizon + EPS && out.length) break;
      out.push(m);
      if (m > horizon + EPS) break;
    }
    return out;
  }
  return [c];                                             // main, absolute
}

// ------------------------------------------------------------------------------------------------ the timeline
function base(id) { return id ? String(id).split('/').pop() : '-'; }

export function roleLabel(role, animfile) {
  const f = base(animfile).replace(/\.xml$/i, '');
  if (role === 'main') return 'main ' + f;
  if (role === 'child') return 'child ' + f;
  return 'attach ' + f;
}

// one side per (role, animfile): its models, clip and clock (several models of one side share the clip)
export function sidesOf(rig) {
  const sides = [];
  for (const inst of rig.instances || []) {
    let s = sides.find((x) => x.role === inst.role && x.animfile === inst.animfile && x.parent === inst.parent);
    if (!s) {
      s = { key: inst.role + ':' + inst.animfile, role: inst.role, animfile: inst.animfile, anim: inst.anim,
        variant: inst.variant, variantRec: inst.variantRec, clip: inst.clip, clock: inst.clock, parent: inst.parent,
        attach: inst.attach, notes: inst.notes || [], models: [], instances: [] };
      sides.push(s);
    }
    s.models.push(inst.model ? inst.model.id : null);
    s.instances.push(inst.index);
  }
  return sides;
}

// the whole timeline of a rig: {D, tEnd, sides, tags, overrides, unattached, keyGrid, warnings}
//   rig: {duration, instances [{index, role, animfile, anim, variant, variantRec, clip {id, duration, fps, keyCount},
//         clock, model {id}, parent, attach, notes}]}  (rig.js Rig, or the same shape in tests)
//   manifest: the bundle manifest (animfiles for the declared-but-unattached lanes); optional
export function buildTimeline(rig, manifest = null) {
  const D = Number(rig.duration) || 0;
  const sides = sidesOf(rig);
  const tags = [];
  const overrides = [];
  let tEnd = D;
  for (const s of sides) {
    const d = s.clip ? Number(s.clip.duration) || 0 : 0;
    s.grid = s.clip ? keyGrid(s.clip) : null;
    s.d = d;
    // the clip's span on the main clock and, for an own clock, its loop starts
    if (s.clock === 'phase') { s.span = [0, D]; s.repeats = [0]; }
    else if (s.clock === 'own') { s.span = [0, D]; s.repeats = d > 0 ? mainTimesOf('own', 0, d, D, D - EPS) : [0]; }
    else { s.span = [0, d]; s.repeats = [0]; }
    s.pastMainEnd = s.clock === 'absolute' && d > D + 1e-6;   // the child's end is never reached while the main loops
    s.holdsLastKey = s.clock === 'absolute' && d + 1e-6 < D;
    if (s.clock !== 'own') tEnd = Math.max(tEnd, s.span[1]);
    const v = s.variantRec;
    const alo = v && v.animlengthoverride !== null && v.animlengthoverride !== undefined ? Number(v.animlengthoverride)
      : null;
    if (alo !== null) {
      const len = s.clock === 'phase' && d > 0 ? (alo / d) * D : alo;
      overrides.push({ side: s.key, role: s.role, length: alo, mainLength: len, clipDuration: d });
      tEnd = Math.max(tEnd, len);
    }
    for (const tag of (v && v.tags) || []) {
      const f = Number(tag.fraction);
      const c = f * d;
      const times = mainTimesOf(s.clock, c, d, D, D);
      const reached = times.filter((m) => m <= D + 1e-6);
      const rec = {
        side: s.key, role: s.role, animfile: s.animfile, clip: s.clip ? s.clip.id : null, clock: s.clock,
        type: tag.type, lane: laneOf(tag), fraction: f, attrs: tag.attrs || {}, overflow: !!tag.overflow || f > 1,
        clipTime: c, times, reached, time: times[0], footstep: isFootstep(tag),
        footprintbone: tag.attrs && tag.attrs.footprintbone ? tag.attrs.footprintbone : null,
        key: s.grid ? s.grid.keyAt(Math.min(c, d)) : 0,
        ghost: alo !== null ? (s.clock === 'phase' && d > 0 ? (f * alo / d) * D : f * alo) : null,
      };
      tags.push(rec);
      tEnd = Math.max(tEnd, times[0]);
      if (rec.ghost !== null) tEnd = Math.max(tEnd, rec.ghost);
    }
  }
  const unattached = [];
  for (const [afid, af] of Object.entries((manifest && manifest.animfiles) || {})) {
    for (const att of af.attachments || []) {
      if ((att.audit || []).includes('declared-not-attached')) {
        unattached.push({ animfile: afid, name: att.name, include: att.include || att.body || null });
      }
    }
  }
  // attachments in scope that draw nothing (no model: a popcornFx / particle item such as the torch's fire)
  const effects = [];
  for (const ch of ((manifest && manifest.composition) || {}).children || []) {
    const parent = sides.find((s) => s.animfile === (ch.declared_in || {}).animfile);
    if (!parent || sides.some((s) => s.animfile === ch.animfile)) continue;
    if (ch.scope === 'anim' && !((ch.declared_in || {}).anims || []).some((a) => lower(a) === lower(parent.anim))) continue;
    const af = (manifest.animfiles || {})[ch.animfile];
    const fx = ((af && af.audit) || []).filter((a) => a.code === 'effect-not-rendered');
    effects.push({ name: ch.attachment, animfile: ch.animfile, parent: parent.key,
      syncanims: !!(ch.attach && ch.attach.syncanims),
      reason: fx.length ? 'effect not rendered: ' + fx.map((a) => a.type + ' ' + a.file).join(', ') : 'no model in this logic state' });
  }
  const main = sides.find((s) => s.role === 'main' && s.clip) || sides[0] || null;
  return { D, tEnd: tEnd > 0 ? tEnd : 1, sides, tags, overrides, unattached, effects,
    keyGrid: main ? main.grid : null, main: main ? main.key : null };
}

// lanes in display order: the seven tag types always (empty ones dimmed), 'other' when present, overflow always
export function tagLanes(tags) {
  const lanes = TAG_LANES.map((name) => ({ name, tags: tags.filter((t) => t.lane === name) }));
  const other = tags.filter((t) => t.lane === OTHER_LANE);
  if (other.length) lanes.push({ name: OTHER_LANE, tags: other });
  lanes.push({ name: OVERFLOW_LANE, tags: tags.filter((t) => t.lane === OVERFLOW_LANE) });
  return lanes;
}

// sorted unique main times a tag step can land on: every reached occurrence in [0, D]
export function tagStops(tags, D) {
  const out = [];
  for (const t of tags) for (const m of t.reached || []) if (m >= -EPS && m <= D + 1e-6) out.push(Math.min(Math.max(m, 0), D));
  out.sort((a, b) => a - b);
  return out.filter((m, i) => i === 0 || m - out[i - 1] > 1e-6);
}

// the next (dir > 0) or previous tag stop from t, wrapping around; null when there is none
export function nextTagTime(stops, t, dir = 1) {
  if (!stops.length) return null;
  if (dir > 0) {
    for (const m of stops) if (m > t + 1e-6) return m;
    return stops[0];
  }
  for (let i = stops.length - 1; i >= 0; i--) if (stops[i] < t - 1e-6) return stops[i];
  return stops[stops.length - 1];
}

// ------------------------------------------------------------------------------------------------ playback rate
// the 'tactics rate' preset for one timing row (bundle timing.actions) and the clip being played:
//   H3       AnimationRate multiplies the playback rate (only when the tactics action declares one)
//   H1 fit   one cycle lasts the effective ROF: rate = clip duration / ROF (only when both are known)
// Both are labelled hypotheses; when both apply they multiply. {rate, cycle, parts, notes}
export function tacticsRate(row, clipDuration, { animationRate = true, rofFit = true } = {}) {
  const parts = [];
  const notes = [];
  let rate = 1;
  const ar = row && row.animationrate !== null && row.animationrate !== undefined ? Number(row.animationrate) : null;
  if (ar !== null && animationRate) {
    rate *= ar;
    parts.push({ rule: 'H3', label: 'AnimationRate', value: ar });
  } else if (ar === null) {
    notes.push('no AnimationRate in the tactics action: x1');
  }
  const rof = row && row.rof_effective !== null && row.rof_effective !== undefined ? Number(row.rof_effective) : null;
  const d = Number(clipDuration) || 0;
  if (rof && rof > 0 && d > 0 && rofFit) {
    const fit = d / rof;
    rate *= fit;
    parts.push({ rule: 'H1 ROF fit', label: 'clip / ROF', value: fit, rof, clip: d, source: row.rof_source });
  } else if (!(rof > 0)) {
    notes.push('no ROF for this action: no fit');
  }
  return { rate, cycle: rate > 0 && d > 0 ? d / rate : null, parts, notes };
}

// the timing rows that play an anim (case-insensitive), in bundle order
export function actionsFor(timing, anim) {
  return ((timing && timing.actions) || []).filter((r) => r.anim && lower(r.anim) === lower(anim));
}

export function fmtS(x, n = 3) {
  return x === null || x === undefined || Number.isNaN(Number(x)) ? '-' : Number(x).toFixed(n);
}
