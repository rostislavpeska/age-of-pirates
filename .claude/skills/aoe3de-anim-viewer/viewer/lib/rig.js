// A unit as the bundle composes it: the main animfile's models, the children attached to them (the rider on the horse,
// the torch in the rider's hand), the clip each one plays and the clock it runs on. Pure (no DOM, no GL): node --test
// checks it against pose_sim (tests/js/parity), the browser draws what pose() returns.
//
// Rules (bundle-schema sections 9 and 10; every inferred one is labelled in instance.notes):
// - models: per animfile, the components the anim names (all when it names none), the resolved entry that matches
//   the chosen logic state (first branch of each logic type by default).
// - tracks bind to bones by the engine's name rule (nm); untracked bones keep their rest local.
// - an attach seats the child: child root = inverse(child frombone world) @ parent tobone world. tobone is looked up
//   in the declaring side's models by name (exact, then the engine alias); a frombone that is in none of the child's
//   bones (hotspot, ATTACHPOINT on the torch) is engine-defined: the model origin is assumed (engine-bone-assumed).
// - syncanims=1 (the rider): the same anim name, main variant i -> child variant i mod n, on the main clock, either in
//   absolute time or in normalised phase (HYPOTHESIS, critic P1-6). An anim the child lacks (Highstep) falls back to
//   the child's Idle (ASSUMPTION). syncanims=0 (the torch): the attachment's own anim (same name, else Idle, else the
//   first) on its own clock, looping.
import {
  IDENTITY, nm, evalCurve, normalizeQuat, localMatrix, transformMatrix, mul4, identity4, invert4, composeWorld,
  transformPoint, matchBone,
} from './skeleton.js';

export const SYNC_MODES = ['absolute', 'phase'];
const MAX_DEPTH = 4;
const IDENTITY4 = identity4();

function lower(s) { return String(s || '').toLowerCase(); }

export function prepareCurve(rec, view) {
  if (rec.kind === 'bspline') {
    return { kind: 'bspline', dim: rec.dim, degree: rec.degree, format: rec.format,
      knots: view(rec.knots), controls: view(rec.controls) };
  }
  if (rec.kind === 'constant') return { kind: 'constant', dim: rec.dim, format: rec.format, value: rec.value };
  if (rec.kind === 'identity') return { kind: 'identity', dim: rec.dim, format: rec.format };
  return { kind: 'unavailable', dim: rec.dim, format: rec.format, reason: rec.reason };
}

export class Clip {
  constructor(rec, view) {
    this.id = rec.id;
    this.rec = rec;
    this.decodable = !!rec.decodable;
    this.duration = rec.duration || 0;
    this.fps = rec.fps_declared || 0;
    this.keyCount = rec.key_count || 1;
    this.tracks = (rec.tracks || []).map((tr) => ({
      bone: tr.bone, key: nm(tr.bone),
      position: prepareCurve(tr.position, view), orientation: prepareCurve(tr.orientation, view),
      scale_shear: prepareCurve(tr.scale_shear, view),
    }));
    this.unavailableCurves = this.tracks.reduce((n, tr) =>
      n + ['position', 'orientation', 'scale_shear'].filter((k) => tr[k].kind === 'unavailable').length, 0);
  }

  // the clip_decode key grid: key k at k / round(fps) s, the last key at the duration
  keyTime(k) {
    const f = Math.round(this.fps);
    return f ? Math.min(k / f, this.duration) : 0;
  }

  keyAt(t) {
    const f = Math.round(this.fps);
    return f ? Math.max(0, Math.min(this.keyCount - 1, Math.round(t * f))) : 0;
  }
}

export class Model {
  constructor(rec) {
    this.id = rec.id;
    this.rec = rec;
    this.decodable = !!rec.decodable && !!rec.skeleton;
    const bones = this.decodable ? rec.skeleton.bones : [];
    this.names = bones.map((b) => b.name);
    this.parents = Int32Array.from(bones.map((b) => b.parent));
    this.restLocal = new Float64Array(bones.length * 16);
    this.inverseWorld = new Float64Array(bones.length * 16);
    const tmp = new Float64Array(16);
    bones.forEach((b, i) => {
      transformMatrix(b.rest, tmp);
      this.restLocal.set(tmp, i * 16);
      this.inverseWorld.set(b.inverse_world, i * 16);
    });
    this.root = Float64Array.from(rec.root || IDENTITY4);
    this.meshes = this.decodable ? rec.meshes : [];
    this._bindings = new Map();
  }

  get boneCount() { return this.names.length; }

  boneIndex(name) {
    const m = matchBone(name, this.names);
    return m ? m.index : -1;
  }

  // track index per bone for a clip (-1 = untracked: the bone keeps its rest local)
  binding(clip) {
    let b = this._bindings.get(clip.id);
    if (!b) {
      const byKey = new Map();
      clip.tracks.forEach((tr, i) => { if (!byKey.has(tr.key)) byKey.set(tr.key, i); });
      b = Int32Array.from(this.names.map((n) => (byKey.has(nm(n)) ? byKey.get(nm(n)) : -1)));
      this._bindings.set(clip.id, b);
    }
    return b;
  }
}


// local matrices (n * 16) of a model posed by a clip at clip time t (seconds)
export function poseLocals(model, clip, t, { method = 'bspline', normalize = 'newton1' } = {}, out) {
  const n = model.boneCount;
  out = out || new Float64Array(n * 16);
  out.set(model.restLocal);
  if (!clip) return out;
  const bind = model.binding(clip);
  const p = new Float64Array(3), q = new Float64Array(4), s = new Float64Array(9), m = new Float64Array(16);
  for (let i = 0; i < n; i++) {
    const ti = bind[i];
    if (ti < 0) continue;
    const tr = clip.tracks[ti];
    evalCurve(tr.position, t, method, p);
    evalCurve(tr.orientation, t, method, q);
    normalizeQuat(q, normalize);
    evalCurve(tr.scale_shear, t, method, s);
    localMatrix(p, q, s, m);
    out.set(m, i * 16);
  }
  return out;
}

// world matrices of a posed model under a placement (root bones: L @ model.root @ placement)
export function poseWorld(model, clip, t, opts = {}, placement = IDENTITY4) {
  const L = poseLocals(model, clip, t, opts);
  const root = mul4(model.root, placement);
  return composeWorld(L, model.parents, root);
}

// skin matrices of one mesh: palette slot k -> inverse_world(bone) @ world(bone); an unresolved binding or a mesh
// without bindings uses the instance placement (rigid at the model origin)
export function skinPalette(model, mesh, worlds, placement = IDENTITY4) {
  const binds = mesh.bone_bindings || [];
  const n = Math.max(binds.length, 1);
  const out = new Float32Array(n * 16);
  const tmp = new Float64Array(16);
  for (let k = 0; k < n; k++) {
    const b = binds[k] ? binds[k].bone : -1;
    if (b >= 0 && b < model.boneCount) mul4(model.inverseWorld, worlds, tmp, b * 16, b * 16, 0);
    else tmp.set(placement);
    out.set(tmp, k * 16);
  }
  return out;
}

// the models of an animfile for a logic state: the named components (all when none), the matching resolved entry
export function modelsFor(animfileRec, logic, componentNames) {
  if (!animfileRec) return [];
  const comps = (animfileRec.components || []).filter((c) =>
    !componentNames || !componentNames.length || componentNames.some((n) => lower(n) === lower(c.name)));
  const out = [];
  for (const comp of comps) {
    const rs = comp.resolved || [];
    const hit = rs.find((r) => Object.entries(r.state || {}).every(([k, v]) => !(k in logic) || logic[k] === v))
      || rs[0];
    for (const m of (hit ? hit.models : [])) if (!out.includes(m)) out.push(m);
  }
  return out;
}

function findAnim(animfileRec, name) {
  if (!animfileRec || !name) return null;
  const key = lower(name);
  for (const k of Object.keys(animfileRec.anims || {})) if (lower(k) === key) return k;
  return null;
}

// default logic state: the first branch of each logic type (bundle logic.default)
export function defaultLogic(manifest) {
  return Object.assign({}, (manifest.logic && manifest.logic.default) || {});
}

export class Rig {
  // bundle: {manifest, view}; opts: {logic, anim, variant, sync ('absolute'|'phase'), method, normalize}
  constructor(bundle, opts = {}) {
    this.manifest = bundle.manifest;
    this.view = bundle.view;
    this.opts = Object.assign({ sync: 'absolute', method: 'bspline', normalize: 'newton1', variant: 0 }, opts);
    this.logic = Object.assign(defaultLogic(this.manifest), this.opts.logic || {});
    this._clips = bundle._clips || (bundle._clips = new Map());
    this._models = bundle._models || (bundle._models = new Map());
    this.instances = [];
    this.notes = [];
    const main = this.manifest.composition && this.manifest.composition.main;
    const mainRec = this.manifest.animfiles[main];
    const anim = findAnim(mainRec, this.opts.anim) || findAnim(mainRec, 'Idle') || Object.keys(mainRec.anims || {})[0];
    this.anim = anim;
    this.variant = this.opts.variant || 0;
    this._addSide({ animfile: main, anim, variant: this.variant, parent: -1, attach: null, clock: 'main', depth: 0,
      role: 'main', notes: [] });
    const m = this.instances.find((x) => x.role === 'main' && x.clip);
    this.duration = m ? m.clip.duration : 0;
    this.mainClip = m ? m.clip : null;
  }

  clip(id) {
    if (!id) return null;
    let c = this._clips.get(id);
    if (c === undefined) {
      const rec = this.manifest.clips[id];
      c = rec ? new Clip(rec, this.view) : null;
      this._clips.set(id, c);
    }
    return c;
  }

  model(id) {
    let m = this._models.get(id);
    if (m === undefined) {
      const rec = this.manifest.models[id];
      m = rec ? new Model(rec) : null;
      this._models.set(id, m);
    }
    return m;
  }

  _addSide(side) {
    const rec = this.manifest.animfiles[side.animfile];
    if (!rec) { this.notes.push('animfile ' + side.animfile + ' is not in the bundle'); return; }
    const animRec = side.anim ? rec.anims[side.anim] : null;
    const variants = animRec ? animRec.variants : [];
    const vi = variants.length ? side.variant % variants.length : -1;
    const variant = vi >= 0 ? variants[vi] : null;
    const clip = variant ? this.clip(variant.clip) : null;
    const notes = side.notes.slice();
    if (variant && !variant.clip) notes.push('clip file-missing: ' + variant.file);
    if (clip && !clip.decodable) notes.push('clip unavailable (' + clip.rec.unavailable_reason + '): undecodable curves keep the identity');
    const comps = animRec && animRec.components && animRec.components.length ? animRec.components : null;
    const first = this.instances.length;
    for (const mid of modelsFor(rec, this.logic, comps)) {
      const model = this.model(mid);
      if (!model) continue;
      if (!model.decodable) notes.push('model ' + mid + ' unavailable (' + model.rec.unavailable_reason + ')');
      this.instances.push({
        index: this.instances.length, role: side.role, animfile: side.animfile, anim: side.anim, variant: vi,
        variantRec: variant, clip, model, parent: side.parent, attach: side.attach ? Object.assign({}, side.attach) : null,
        clock: side.clock,
        notes, worlds: null, placement: identity4(),
      });
    }
    if (side.depth >= MAX_DEPTH) return;
    const mine = this.instances.slice(first);
    for (const ch of (this.manifest.composition.children || [])) {
      if (ch.declared_in.animfile !== side.animfile) continue;
      if (ch.scope === 'anim' && !(ch.declared_in.anims || []).some((a) => lower(a) === lower(side.anim))) continue;
      if (!ch.animfile || !this.manifest.animfiles[ch.animfile]) {
        this.notes.push('attach ' + ch.attachment + ': animfile ' + ch.animfile + ' not in the bundle');
        continue;
      }
      // the parent instance holding the tobone (by name), else the first model of this side
      let parent = mine.find((x) => x.model.boneIndex(ch.attach.tobone) >= 0) || mine[0];
      if (!parent) continue;
      const toIndex = parent.model.boneIndex(ch.attach.tobone);
      const childRec = this.manifest.animfiles[ch.animfile];
      const cnotes = [];
      if (toIndex < 0) cnotes.push('tobone ' + ch.attach.tobone + ' unresolved: seated at the parent origin');
      let anim, variant, clock;
      if (ch.attach.syncanims) {
        anim = findAnim(childRec, side.anim);
        variant = Math.max(parent.variant, 0);              // the parent's resolved variant i -> child i mod n
        clock = this.opts.sync === 'phase' ? 'phase' : 'absolute';
        cnotes.push('rider sync: ' + (clock === 'phase' ? 'normalised phase' : 'absolute time') +
          ', variant i -> i mod n (hypothesis)');
        if (!anim) {
          anim = findAnim(childRec, 'Idle');
          cnotes.push('anim ' + side.anim + ' is not in ' + ch.animfile + ': fallback ' + (anim || 'rest pose') +
            ' (assumption)');
          variant = 0;
        }
      } else {
        anim = findAnim(childRec, side.anim) || findAnim(childRec, 'Idle') || Object.keys(childRec.anims || {})[0];
        variant = 0;
        clock = 'own';
        cnotes.push('syncanims=0: own anim ' + (anim || '-') + ' on its own clock');
      }
      this._addSide({
        animfile: ch.animfile, anim, variant, parent: parent.index, clock, depth: side.depth + 1,
        role: ch.scope === 'anim' ? 'attachment' : 'child', notes: cnotes,
        attach: Object.assign({}, ch.attach, { attachment: ch.attachment, scope: ch.scope, toIndex }),
      });
    }
  }

  // clip time of an instance at main time t (seconds since the anim started)
  clipTime(inst, t) {
    const d = inst.clip ? inst.clip.duration : 0;
    if (inst.clock === 'main') return Math.min(Math.max(t, 0), d);
    if (inst.clock === 'phase') return this.duration > 0 ? Math.min(Math.max(t / this.duration, 0), 1) * d : 0;
    if (inst.clock === 'own') return d > 0 ? ((t % d) + d) % d : 0;
    return Math.min(Math.max(t, 0), d);                // absolute: the child holds its last key past its end
  }

  // pose every instance at main time t; returns the instances with .worlds (n * 16) and .placement set
  pose(t, opts = {}) {
    const o = { method: opts.method || this.opts.method, normalize: opts.normalize || this.opts.normalize };
    for (const inst of this.instances) {
      const ct = this.clipTime(inst, t);
      inst.time = ct;
      const L = poseLocals(inst.model, inst.clip, ct, o);
      const W = composeWorld(L, inst.model.parents, inst.model.root);       // placement identity first
      let place = identity4();
      if (inst.parent >= 0) {
        const par = this.instances[inst.parent];
        const to = new Float64Array(16);
        if (inst.attach.toIndex >= 0) to.set(par.worlds.subarray(inst.attach.toIndex * 16, inst.attach.toIndex * 16 + 16));
        else to.set(par.placement);
        const fi = inst.model.boneIndex(inst.attach.frombone);
        inst.attach.fromIndex = fi;
        if (fi >= 0) {
          const inv = invert4(W.subarray(fi * 16, fi * 16 + 16)) || identity4();
          place = mul4(inv, to);
        } else {
          place = to;                                                          // engine-defined bone: model origin
        }
      }
      inst.placement = place;
      const out = new Float64Array(W.length);
      for (let i = 0; i < inst.model.boneCount; i++) mul4(W, place, out, i * 16, 0, i * 16);
      inst.worlds = out;
    }
    return this.instances;
  }

  // every clip key time of the main clip (for stepping)
  keyTimes() {
    const c = this.mainClip;
    if (!c) return [0];
    return Array.from({ length: c.keyCount }, (_, k) => c.keyTime(k));
  }
}

// CPU linear-blend skinning of one mesh (positions only): for bounds, picking and parity checks
export function skinPositions(inst, mesh, view) {
  const pos = mesh.streams.Position && mesh.streams.Position.view ? view(mesh.streams.Position.view) : null;
  if (!pos) return new Float64Array(0);
  const comps = mesh.streams.Position.view.components;
  const n = mesh.vertex_count;
  const pal = skinPalette(inst.model, mesh, inst.worlds, inst.placement);
  const wv = mesh.streams.BoneWeights && mesh.streams.BoneWeights.view ? view(mesh.streams.BoneWeights.view) : null;
  const iv = mesh.streams.BoneIndices && mesh.streams.BoneIndices.view ? view(mesh.streams.BoneIndices.view) : null;
  const out = new Float64Array(n * 3);
  const p = new Float64Array(3), r = new Float64Array(3);
  for (let v = 0; v < n; v++) {
    p[0] = pos[v * comps]; p[1] = pos[v * comps + 1]; p[2] = pos[v * comps + 2];
    let x = 0, y = 0, z = 0;
    if (wv && iv) {
      let wsum = 0;
      for (let k = 0; k < 4; k++) {
        const w = wv[v * 4 + k] / 255;
        if (!w) continue;
        wsum += w;
        transformPoint(p, pal, iv[v * 4 + k] * 16, r);
        x += w * r[0]; y += w * r[1]; z += w * r[2];
      }
      if (!wsum) { transformPoint(p, pal, 0, r); x = r[0]; y = r[1]; z = r[2]; }
    } else {
      transformPoint(p, pal, 0, r); x = r[0]; y = r[1]; z = r[2];
    }
    out[v * 3] = x; out[v * 3 + 1] = y; out[v * 3 + 2] = z;
  }
  return out;
}

export function boundsOf(rig, view) {
  const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
  for (const inst of rig.instances) {
    if (!inst.worlds) continue;
    for (const mesh of inst.model.meshes) {
      const P = skinPositions(inst, mesh, view);
      for (let i = 0; i < P.length; i += 3) {
        for (let k = 0; k < 3; k++) { lo[k] = Math.min(lo[k], P[i + k]); hi[k] = Math.max(hi[k], P[i + k]); }
      }
    }
  }
  return lo[0] === Infinity ? { min: [-1, 0, -1], max: [1, 2, 1] } : { min: lo, max: hi };
}
