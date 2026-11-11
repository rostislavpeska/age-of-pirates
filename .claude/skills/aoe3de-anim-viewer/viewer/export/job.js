// The viewer page in job mode (headless.py, no window): render the listed frames of one bundle - or of two, a compare /
// side-by-side job - post one PNG per frame and subject, optional bone matrices and geometry dumps, then 'done'.
// Moved here from viewer/app/app.js in M5; the frame record of M2/M3 jobs is unchanged, M5 adds fields to it.
//
// Job keys (all optional but frames):
//   width, height, background [r,g,b,a], grid, readback, player_color_index, shading {...} (viewer/shading/hook.js)
//   bounds      'frame' (default: the camera fits each frame's pose, as in M2/M3) | 'clip' (one framing per clip:
//               the union of the posed bounds over the clip; with two subjects, over both, so both share one camera)
//   timeline    true: the done record carries the M4 timeline of every (subject, anim, variant) rendered
//   geometry    true: every frame also posts <png stem>.geom.bin (viewer/export/geometry.js) for scripts/metrics.py
//   other       {bundle, anim, variant, shading, sync}: subject b, rendered after subject a at the same main time
//               (export/plan.js sharedClockTime); its files carry the suffix __b
//   frames      [{name, anim, variant, logic, sync, method, bones, camera, shading, background, grid, bounds, geometry,
//                 time | key (+ key_of main|child) | times [t...] | at 'tags'|'keys'|'fps=N',
//                 other {anim, variant, time} (subject b's anim, variant and main time for this frame; default the
//                 job's, else a's anim and the shared-clock time)}]
//     times  expands to one frame per time, named <name>_<index 5 digits>; other_times (same length) gives subject
//            b's own main time per frame (a video's global clock: t mod D_b) instead of the shared-clock rule
//     at     expands to one frame per tag stop / key / 1/N s, named <name>_<label> (export/plan.js expandAt); with
//            two subjects the tag stops of both timelines are merged (subject b's tags are labelled b:)
// Frame records: name, png, t, anim, variant, stats, bounds, shading, fidelity, camera, instances (M2/M3), plus
//   subject 'a'|'b', bundle_id, cell (export/plan.js cellInfo), expand {kind, label}, clock (b only), geom.
import { log, postJSON, postFile } from '../lib/host.js';
import { loadBundle } from '../lib/bundle.js';
import { rendererInfo, classifyGpuPath } from '../lib/gl.js';
import { Rig, boundsOf } from '../lib/rig.js';
import { buildTimeline } from '../timeline/model.js';
import { createRenderer, applyShading } from '../shading/hook.js';
import { expandAt, cellInfo, timelineSummary, clipBounds, unionBounds, cameraFor, sharedClockTime, pad } from './plan.js';
import { geometryParts, packGeometry } from './geometry.js';

const BG = [0.16, 0.17, 0.19, 1];

function canvasPng(canvas) {
  return new Promise((res, rej) => canvas.toBlob((b) => (b ? res(b) : rej(new Error('toBlob failed'))), 'image/png'));
}

function setupGL(canvas) {
  const gl = canvas.getContext('webgl2', { antialias: true, premultipliedAlpha: false, preserveDrawingBuffer: true,
    alpha: true });
  if (!gl) throw new Error('WebGL2 is not available in this browser');
  const info = rendererInfo(gl);
  return { gl, info, gpuPath: classifyGpuPath(info.unmasked_renderer || info.renderer) };
}

function findAnim(manifest, name) {
  const main = manifest.animfiles[manifest.composition.main];
  const key = String(name || '').toLowerCase();
  return Object.keys(main.anims).find((k) => k.toLowerCase() === key) || null;
}

// one subject: its bundle, renderer and per-(anim, variant) caches
class Subject {
  constructor(id, bundle, ren) {
    this.id = id;
    this.bundle = bundle;
    this.ren = ren;
    this.timelines = new Map();
    this.clipBoxes = new Map();
  }

  rigOpts(f, o = {}) {
    return { anim: o.anim ?? f.anim, variant: o.variant ?? f.variant ?? 0, logic: f.logic || {}, sync: o.sync || f.sync || 'absolute',
      method: f.method || 'bspline' };
  }

  key(opts) { return [opts.anim, opts.variant, opts.sync, opts.method, JSON.stringify(opts.logic)].join('|'); }

  timeline(opts) {
    const k = this.key(opts);
    let e = this.timelines.get(k);
    if (!e) {
      const rig = new Rig(this.bundle, opts);
      e = { rig, tl: buildTimeline(rig, this.bundle.manifest), opts };
      this.timelines.set(k, e);
    }
    return e;
  }

  clipBox(opts) {
    const k = this.key(opts);
    let b = this.clipBoxes.get(k);
    if (!b) {
      const { tl } = this.timeline(opts);
      b = clipBounds(new Rig(this.bundle, opts), this.bundle.view, tl);
      this.clipBoxes.set(k, b);
    }
    return b;
  }
}

// the job's frames with `times` and `at` expanded; each gets _t (main time of subject a) or key fields as given
function expandFrames(job, a, b) {
  const out = [];
  const skipped = [];
  for (const f of job.frames || []) {
    if (Array.isArray(f.times)) {
      f.times.forEach((t, i) => {
        const other = Array.isArray(f.other_times) ? Object.assign({}, f.other || {}, { time: f.other_times[i] }) : f.other;
        out.push(Object.assign({}, f, { times: undefined, other_times: undefined, other, time: t,
          name: (f.name || 'frame') + '_' + pad(i, 5), expand: { kind: 'times', index: i } }));
      });
      continue;
    }
    if (f.at !== undefined && f.at !== null) {
      const ea = a.timeline(a.rigOpts(f));
      const entries = [{ tl: ea.tl, subject: 'a' }];
      if (b) entries.push({ tl: b.timeline(b.rigOpts(f, otherOpts(job, f, b))).tl, subject: 'b' });
      const ex = expandAt(f.at, entries);
      for (const s of ex.skipped) skipped.push(Object.assign({ frame: f.name || null }, s));
      for (const x of ex.frames) {
        out.push(Object.assign({}, f, { at: undefined, time: x.t, name: (f.name || 'frame') + '_' + x.label,
          expand: { kind: ex.kind, label: x.label, key: x.key ?? null, index: x.index ?? null, tags: x.tags } }));
      }
      continue;
    }
    out.push(f);
  }
  return { frames: out, skipped };
}

// subject b's anim / variant / sync for a frame: frame.other, else job.other, else subject a's when b has that anim
function otherOpts(job, f, b) {
  const jo = job.other || {}, fo = f.other || {};
  let anim = fo.anim ?? jo.anim ?? f.anim;
  if (!findAnim(b.bundle.manifest, anim)) anim = findAnim(b.bundle.manifest, 'Idle') || anim;
  return { anim, variant: fo.variant ?? jo.variant ?? f.variant ?? 0, sync: fo.sync || jo.sync };
}

export async function runJob(bundle, job, canvas) {
  canvas.width = job.width || 800;
  canvas.height = job.height || 800;
  canvas.style.width = canvas.width + 'px';
  canvas.style.height = canvas.height + 'px';
  const { gl, info, gpuPath } = setupGL(canvas);
  const ren = createRenderer(gl, bundle, job.shading);                     // M3 hook: job.shading (hook.js)
  if (job.player_color_index !== undefined) ren.setPlayerColour(job.player_color_index);
  await applyShading(ren, job.shading);
  const a = new Subject('a', bundle, ren);
  let b = null;
  if (job.other && job.other.bundle) {
    if (!/^[0-9a-f]{16}$/.test(job.other.bundle)) throw new Error('bad other bundle id ' + job.other.bundle);
    const bb = await loadBundle('/bundle/' + job.other.bundle + '/');
    const shB = Object.assign({}, job.shading || {}, job.other.shading || {});
    const renB = createRenderer(gl, bb, shB);
    if (job.player_color_index !== undefined) renB.setPlayerColour(job.player_color_index);
    await applyShading(renB, shB);
    b = new Subject('b', bb, renB);
  }
  const { frames: list, skipped } = expandFrames(job, a, b);
  const frames = [];
  const aspect = canvas.width / canvas.height;
  for (const f of list) {
    if (f.shading) { await applyShading(ren, f.shading); if (b) await applyShading(b.ren, f.shading); }
    const subjects = b ? [[a, a.rigOpts(f)], [b, b.rigOpts(f, otherOpts(job, f, b))]] : [[a, a.rigOpts(f)]];
    const rigs = subjects.map(([s, o]) => ({ s, o, rig: new Rig(s.bundle, o) }));
    // the main time of subject a; subject b runs on the same clock (looping its own clip past its end)
    let t = f.time;
    if (t === undefined || t === null) {
      const r0 = rigs[0].rig;
      const side = f.key_of === 'child' ? r0.instances.find((x) => x.role === 'child' && x.clip) : null;
      const clip = side ? side.clip : r0.mainClip;
      t = clip ? clip.keyTime(f.key || 0) : 0;
    }
    const mode = f.bounds || job.bounds || 'frame';
    let shared = null;
    if (mode === 'clip') shared = unionBounds(rigs.map(({ s, o }) => s.clipBox(o)));
    for (const { s, o, rig } of rigs) {
      const ot = f.other && f.other.time !== undefined && f.other.time !== null ? Number(f.other.time) : null;
      const tt = s.id === 'a' ? t : (ot !== null ? ot : sharedClockTime(t, rig.duration));
      rig.pose(tt);
      const bounds = shared || boundsOf(rig, s.bundle.view);
      const cam = cameraFor(f.camera || {}, bounds, aspect);
      const stats = s.ren.draw(rig, cam, { background: f.background || job.background || BG, bones: !!f.bones,
        grid: f.grid ?? job.grid ?? true, bounds });
      const name = (f.name || ('frame' + frames.length)) + (s.id === 'b' ? '__b' : '');
      await postFile(name + '.png', await canvasPng(canvas));
      const { tl } = s.timeline(o);
      const ownTags = s.id === 'a' && f.expand && f.expand.tags ? f.expand.tags.filter((x) => x.subject === 'a') :
        s.id === 'b' && f.expand && f.expand.tags ? f.expand.tags.filter((x) => x.subject === 'b') : null;
      const rec = { name, png: name + '.png', t: tt, anim: rig.anim, variant: rig.variant, stats, bounds,
        shading: s.ren.describe ? s.ren.describe() : null, fidelity: s.ren.fidelity ? s.ren.fidelity() : null,
        camera: { kind: cam.kind, eye: cam.eye, target: cam.target, mode: (f.camera && f.camera.mode) || 'game' },
        instances: rig.instances.map((x) => ({ role: x.role, model: x.model.id, animfile: x.animfile, anim: x.anim,
          variant: x.variant, clip: x.clip ? x.clip.id : null, time: x.time, clock: x.clock, notes: x.notes,
          to_index: x.attach ? x.attach.toIndex : null, from_index: x.attach ? x.attach.fromIndex : null })),
        subject: s.id, bundle_id: s.bundle.manifest.bundle_id, framing: mode,
        cell: cellInfo(rig, tl, tt, ownTags && ownTags.length ? ownTags : null),
        expand: f.expand ? { kind: f.expand.kind, label: f.expand.label ?? null, key: f.expand.key ?? null,
          index: f.expand.index ?? null } : null };
      if (s.id === 'b') rec.clock = { shared_t: t, t: tt, D: rig.duration, rule: 'shared clock: t kept inside [0, D], wraps past D (H)' };
      if (job.readback) {
        const worlds = rig.instances.map((x) => ({ role: x.role, model: x.model.id, bones: x.model.names,
          worlds: Array.from(x.worlds) }));
        await postFile(name + '.json', new Blob([JSON.stringify({ t: tt, worlds })], { type: 'application/json' }));
        rec.readback = name + '.json';
      }
      if (f.geometry || job.geometry) {
        const g = geometryParts(rig, s.bundle.view, tt, { subject: s.id, bundle_id: rec.bundle_id, frame: name });
        await postFile(name + '.geom.bin', new Blob([packGeometry(g.header, g.arrays)], { type: 'application/octet-stream' }));
        rec.geom = name + '.geom.bin';
      }
      frames.push(rec);
      log('frame ' + name + ': ' + rig.anim + ' v' + rig.variant + ' t=' + tt.toFixed(4) + ' draws ' + stats.draws +
        (stats.errors.length ? ' GL errors ' + stats.errors.join(',') : ''));
    }
  }
  const done = { status: frames.every((x) => !x.stats.errors.length) ? 'ok' : 'gl-errors',
    renderer: info, gpu_path: gpuPath, textures: ren.textureLog, frames, bundle_id: bundle.manifest.bundle_id,
    fidelity: ren.fidelity ? ren.fidelity() : bundle.manifest.fidelity, shading_error: ren.shadingError || null,
    extensions: { s3tc: !!ren.ext.s3tc, s3tc_srgb: !!ren.ext.s3tc_srgb }, skipped };
  if (b) {
    done.other = { bundle_id: b.bundle.manifest.bundle_id, subject: b.bundle.manifest.subject,
      fidelity: b.ren.fidelity ? b.ren.fidelity() : b.bundle.manifest.fidelity, shading_error: b.ren.shadingError || null };
  }
  if (job.timeline) {
    done.timelines = {};
    for (const s of b ? [a, b] : [a]) {
      for (const e of s.timelines.values()) {
        done.timelines[s.id + '|' + e.rig.anim + '|' + e.rig.variant + '|' + e.opts.sync] = Object.assign(
          { subject: s.id, anim: e.rig.anim, variant: e.rig.variant, sync: e.opts.sync }, timelineSummary(e.tl));
      }
    }
  }
  await postJSON('/api/done', done);
}
