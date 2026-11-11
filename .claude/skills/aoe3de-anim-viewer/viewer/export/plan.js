// M5 export planning: which main-clock times a job renders (at tags, at every key, at N fps), what each rendered cell
// is (anim, variant, clip, key, time, tags), the export cameras and the fixed per-clip framing. Pure: no DOM, no GL,
// so node --test checks it (tests/js/export.test.mjs). viewer/export/job.js runs it in the headless page.
//
// Rules (bundle-schema section 18, "M5 export"):
// - times come from the M4 timeline (viewer/timeline/model.js buildTimeline), the single source of tag times:
//   'tags' = every reached tag stop in [0, D] (one cell per distinct time, every tag at that time listed; overflow
//   tags and child tags past D are never reached and are reported as skipped); 'keys' = every key of the main clip's
//   grid (k / round(fps), the last at D); 'fps=N' = t = i / N for i = 0 .. floor(D * N).
// - compare / side-by-side (two subjects on one clock): subject b is posed at the same main time t; t inside [0, D_b]
//   is kept, a later t wraps (t mod D_b): each unit loops its own main clip from a shared start (hypothesis H,
//   fidelity stage compare_clock).
// - framing: 'frame' fits the camera to the pose of that frame (M2/M3 jobs); 'clip' fits it once to the union of the
//   posed bounds over the clip (24 even samples plus every tag stop), so a sheet or a video keeps one camera.
import { buildTimeline, clipTimeAt, keyGrid } from '../timeline/model.js';
import { boundsOf } from '../lib/rig.js';
import { gameCamera, renderObjCamera, boundsToGxo, GAME_PITCH, DEFAULT_FOV, engineToDisplay } from '../lib/camera.js';

export const EPS_T = 1e-6;
export const CLIP_BOUNDS_SAMPLES = 24;
export const CLOSE_PITCH = 14;            // degrees: the close camera (M3 renders); a viewer choice, not a game camera

const lower = (s) => String(s ?? '').toLowerCase();
const r4 = (x) => Math.round(Number(x) * 1e4) / 1e4;

// 'tags' | 'keys' | 'fps=N' | {fps: N} | {kind, fps} -> {kind, fps?}; null for anything else
export function parseAt(at) {
  if (at === null || at === undefined || at === '') return null;
  if (typeof at === 'object') {
    const fps = Number(at.fps);
    if ((at.kind === 'fps' || at.kind === undefined) && fps > 0) return { kind: 'fps', fps };
    if (at.kind === 'tags' || at.kind === 'keys') return { kind: at.kind };
    return null;
  }
  const s = lower(at).trim();
  if (s === 'tags' || s === 'keys') return { kind: s };
  const m = /^fps\s*=\s*([0-9]*\.?[0-9]+)$/.exec(s);
  if (m && Number(m[1]) > 0) return { kind: 'fps', fps: Number(m[1]) };
  return null;
}

// the JSON-able view of an M4 timeline that reports carry (video overlays, sheet captions, compare metrics)
export function timelineSummary(tl) {
  return {
    D: tl.D, tEnd: tl.tEnd, main: tl.main,
    sides: tl.sides.map((s) => ({ key: s.key, role: s.role, animfile: s.animfile, anim: s.anim, variant: s.variant,
      clip: s.clip ? s.clip.id : null, clock: s.clock, d: s.d, fps: s.grid ? s.grid.fps : null,
      rounded: s.grid ? s.grid.rounded : null, keys: s.grid ? s.grid.count : null,
      nonInteger: s.grid ? s.grid.nonInteger : null, lastOffGrid: s.grid ? s.grid.lastOffGrid : null,
      holdsLastKey: !!s.holdsLastKey, pastMainEnd: !!s.pastMainEnd })),
    tags: tl.tags.map((x) => ({ side: x.side, role: x.role, type: x.type, lane: x.lane, fraction: x.fraction,
      clipTime: x.clipTime, times: x.times, reached: x.reached, overflow: x.overflow, key: x.key, attrs: x.attrs,
      footstep: x.footstep, footprintbone: x.footprintbone })),
    overrides: tl.overrides, effects: tl.effects, unattached: tl.unattached,
  };
}

function tagRef(x, subject, t) {
  return { subject, type: x.type, lane: x.lane, role: x.role, side: x.side, fraction: x.fraction, time: t,
    clipTime: x.clipTime, key: x.key, attrs: x.attrs, footstep: !!x.footstep, footprintbone: x.footprintbone || null };
}

// [{t, tags}] the distinct reached tag times in [0, D] of one or more timelines ({tl, subject}); skipped: the tags no
// time in [0, D] reaches (overflow, a child tag past the main end), each with its reason
export function tagStopsOf(entries) {
  const stops = [];
  const skipped = [];
  for (const { tl, subject } of entries) {
    for (const x of tl.tags) {
      const reached = (x.reached || []).filter((m) => m >= -EPS_T && m <= tl.D + EPS_T);
      if (!reached.length) {
        skipped.push({ subject, type: x.type, role: x.role, fraction: x.fraction, time: x.time,
          reason: x.overflow ? 'overflow: fraction > 1, meaning unknown' : 'past the main clip end: never reached while it loops' });
        continue;
      }
      for (const m0 of reached) {
        const m = Math.min(Math.max(m0, 0), tl.D);
        let s = stops.find((y) => Math.abs(y.t - m) <= EPS_T);
        if (!s) { s = { t: m, tags: [] }; stops.push(s); }
        s.tags.push(tagRef(x, subject, m));
      }
    }
  }
  stops.sort((a, b) => a.t - b.t);
  return { stops, skipped };
}

export function tagLabel(tags) {
  if (!tags || !tags.length) return null;
  const names = [];
  for (const g of tags) {
    const n = (g.subject && g.subject !== 'a' ? g.subject + ':' : '') + (g.role === 'main' ? '' : g.role + ' ') + g.type;
    if (!names.includes(n)) names.push(n);
  }
  return names.join('+');
}

// the times of one `at` spec: [{t, label, kind, tags}] plus skipped tags. entries: [{tl, subject}] (first = the clock)
export function expandAt(at, entries) {
  const spec = parseAt(at);
  if (!spec) throw new Error('bad "at" value ' + JSON.stringify(at) + ' (tags, keys or fps=N)');
  const tl = entries[0].tl;
  const D = tl.D;
  if (spec.kind === 'tags') {
    const { stops, skipped } = tagStopsOf(entries);
    return { kind: 'tags', frames: stops.map((s) => ({ t: s.t, kind: 'tags', tags: s.tags,
      label: 't' + s.t.toFixed(4) + '_' + safeLabel(tagLabel(s.tags)) })), skipped };
  }
  if (spec.kind === 'keys') {
    const main = tl.sides.find((s) => s.key === tl.main);
    const g = main && main.grid ? main.grid : keyGrid({ duration: D, fps: 0 });
    const frames = [];
    for (let k = 0; k < g.count; k++) frames.push({ t: g.time(k), kind: 'keys', key: k, tags: [], label: 'k' + pad(k, 3) });
    return { kind: 'keys', frames, skipped: [] };
  }
  const n = Math.floor(D * spec.fps + 1e-9);
  const frames = [];
  for (let i = 0; i <= n; i++) frames.push({ t: Math.min(i / spec.fps, D), kind: 'fps', index: i, tags: [], label: 'f' + pad(i, 4) });
  return { kind: 'fps', fps: spec.fps, frames, skipped: [] };
}

export function pad(n, w) { return String(n).padStart(w, '0'); }
export function safeLabel(s) { return String(s || '').replace(/[^A-Za-z0-9_-]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 60); }

// subject b's main time for the shared clock t: t inside [0, D_b] is kept, a later t wraps (each loops its own clip)
export function sharedClockTime(t, D) {
  if (!(D > 0)) return 0;
  if (t <= D + EPS_T) return Math.min(Math.max(t, 0), D);
  const w = t % D;
  return w < 0 ? w + D : w;
}

// what a rendered cell is: {anim, variant, clip, key, time, tag, tags, keys [{role, side, clip, clock, clip_time, key}]}
//   tags: the expansion's tags when given, else every timeline tag reached at t (within 1e-6)
export function cellInfo(rig, tl, t, tags = null) {
  const main = tl.sides.find((s) => s.key === tl.main) || null;
  const keys = tl.sides.filter((s) => s.clip).map((s) => {
    const ct = clipTimeAt(s.clock, t, s.d, tl.D);
    return { role: s.role, side: s.key, clip: s.clip.id, clock: s.clock, clip_time: ct,
      key: s.grid ? s.grid.keyAt(ct) : 0, of: s.grid ? s.grid.count : 1 };
  });
  const at = tags || tl.tags.filter((x) => (x.reached || []).some((m) => Math.abs(m - t) <= EPS_T)).map((x) => tagRef(x, 'a', t));
  const mk = keys.find((k) => k.side === tl.main);
  return { anim: rig.anim, variant: rig.variant, clip: main && main.clip ? main.clip.id : null,
    key: mk ? mk.key : 0, keys_of: mk ? mk.of : 1, time: t, D: tl.D, tag: tagLabel(at), tags: at, keys };
}

export function unionBounds(list) {
  const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
  for (const b of list) {
    if (!b) continue;
    for (let k = 0; k < 3; k++) { lo[k] = Math.min(lo[k], b.min[k]); hi[k] = Math.max(hi[k], b.max[k]); }
  }
  return lo[0] === Infinity ? null : { min: lo, max: hi };
}

// the union of the posed bounds over a clip: CLIP_BOUNDS_SAMPLES even times in [0, D] plus every tag stop
export function clipBounds(rig, view, tl, samples = CLIP_BOUNDS_SAMPLES) {
  const D = tl.D;
  const times = [];
  for (let i = 0; i < samples; i++) times.push(samples > 1 ? (D * i) / (samples - 1) : 0);
  for (const s of tagStopsOf([{ tl, subject: 'a' }]).stops) times.push(s.t);
  const list = [];
  for (const t of times) { rig.pose(t); list.push(boundsOf(rig, view)); }
  return unionBounds(list);
}

// the export cameras. c: {mode: 'game' (default) | 'close' | 'ortho' | 'render_obj', yaw, pitch, fov, distance,
// target, az, el, lo, hi, units}; bounds: engine-frame {min, max}
export function cameraFor(c = {}, bounds, aspect) {
  if (c.mode === 'render_obj') return renderObjCamera({ lo: c.lo, hi: c.hi, az: c.az, el: c.el, units: c.units || 1, aspect });
  if (c.mode === 'ortho') {
    const g = boundsToGxo(bounds);
    return renderObjCamera({ lo: g.lo, hi: g.hi, az: c.az ?? 35, el: c.el ?? 0.2, units: 1, aspect });
  }
  if (c.mode === 'close') {
    const lo = engineToDisplay(bounds.min), hi = engineToDisplay(bounds.max);
    const target = c.target || [(lo[0] + hi[0]) / 2, lo[1] + 0.62 * (hi[1] - lo[1]), (lo[2] + hi[2]) / 2];
    return gameCamera({ bounds, yaw: c.yaw ?? 35, pitch: c.pitch ?? CLOSE_PITCH, fov: c.fov ?? DEFAULT_FOV, aspect,
      distance: c.distance, target, fit: c.fit ?? 0.55 });
  }
  return gameCamera({ bounds, yaw: c.yaw ?? 35, pitch: c.pitch ?? GAME_PITCH, fov: c.fov ?? DEFAULT_FOV, aspect,
    distance: c.distance, target: c.target });
}

// a timeline for (bundle, anim, variant, sync, method) through a throwaway Rig (the caller passes the Rig class)
export function timelineFor(RigClass, bundle, opts) {
  const rig = new RigClass(bundle, opts);
  return { rig, tl: buildTimeline(rig, bundle.manifest) };
}

export { r4 };
