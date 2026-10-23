// M4 mount: the timeline dock, the clip picker and the data panels on top of the M2 viewer page (viewer/app/app.js),
// without changing it: the App's state ({anim, variant, t, playing, speed, loop, sync, ...}) is the single source of
// truth; this module wraps App.rebuild (to refresh after any change) and the renderer's draw (per frame, with the
// camera of that frame), and drives the App only through its state and rebuild().
//
// Test mode (?test=1&uishot=<JSON>): for each shot {name, anim, variant, tag | time, tab, tip, trate, action, sync}
// the page sets the state, waits a few frames, posts 'uishot:<name>' to /api/log and waits for the reply, while
// scripts/ui_shot.py captures the whole page through the DevTools protocol; then it runs the interaction checks and
// posts 'done' with its report (lanes, tags, rates, fidelity, panel row counts).
import { TEST_MODE, PARAMS, postJSON, reportError } from '../lib/host.js';
import {
  buildTimeline, variantWeights, rollVariant, mulberry32, tagStops, nextTagTime, tacticsRate, actionsFor, tagLanes,
} from './model.js';
import { footprintDots } from './footprint.js';
import { TimelineView, FootOverlay } from './timeline.js';
import { ClipPicker } from './picker.js';
import { Panels, TABS } from '../panels/panels.js';
import { applyTimelineFidelity, fidelityView, pairingView, auditView } from '../panels/data.js';

const lower = (s) => String(s ?? '').toLowerCase();
const frames = (n) => new Promise((res) => {
  let k = 0;
  const f = () => (++k >= n ? res() : requestAnimationFrame(f));
  requestAnimationFrame(f);
});

export function mountStudio(app) {
  if (app._studio) return app._studio;
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = new URL('./timeline.css', import.meta.url).href;
  document.head.append(link);
  document.body.classList.add('av-tl');
  const s = new Studio(app);
  app._studio = s;
  globalThis.studio = s;
  if (TEST_MODE && PARAMS.get('uishot')) {
    let shots;
    try { shots = JSON.parse(PARAMS.get('uishot')); } catch (e) { reportError(e); return s; }
    let started = false;
    const go = () => { if (!started) { started = true; s.uiShots(Array.isArray(shots) ? shots : [shots]).catch(reportError); } };
    link.addEventListener('load', go, { once: true });
    link.addEventListener('error', go, { once: true });     // a missing stylesheet must not hang the run
  }
  return s;
}

export class Studio {
  constructor(app) {
    this.app = app;
    this.m = app.m;
    this.added = applyTimelineFidelity(this.m);
    const badge = document.getElementById('badge');
    if (badge) badge.textContent = fidelityView(this.m).letters;
    this.userSpeed = app.state.speed || 1;
    this.trate = false;
    this.action = null;
    this.rollMsg = '';
    this.rng = mulberry32(TEST_MODE ? 20261011 : (Date.now() ^ Math.floor(performance.now() * 1000)) >>> 0);
    const stage = document.getElementById('stage');
    const aside = document.querySelector('aside');
    const anchor = Array.from(aside.children).find((c) => c.querySelector && c.querySelector('#anim')) || null;
    this.picker = new ClipPicker(aside, anchor, {
      anim: (a) => this.setAnim(a), variant: (i) => this.setVariant(i), roll: () => this.roll(), sync: (k) => this.setSync(k),
    });
    this.panels = new Panels(aside, anchor);
    this.timeline = new TimelineView(stage, {
      scrub: (t) => this.scrub(t), play: () => this.togglePlay(), start: () => this.scrub(0),
      stepKey: (d) => this.stepKey(d), stepTag: (d) => this.stepTag(d), loop: (b) => this.setLoop(b),
      speed: (x) => { this.userSpeed = x; this.applySpeed(); }, tacticsRate: (b) => { this.trate = b; this.applySpeed(); this.renderBar(); },
      action: (a) => this.setAction(a), badge: () => { this.panels.show('fidelity'); this.panels.root.scrollIntoView({ block: 'start' }); },
    });
    this.overlay = new FootOverlay(stage, app.canvas);
    const rebuild = app.rebuild.bind(app);
    app.rebuild = () => { rebuild(); this.refresh(); };
    window.addEventListener('keydown', (e) => {
      if (e.target && (e.target.tagName === 'INPUT' && e.target.type === 'text')) return;
      if (e.key === ']') this.stepTag(1);
      if (e.key === '[') this.stepTag(-1);
    });
    this.refresh();
    const loop = () => { this.wrapDraw(); requestAnimationFrame(loop); };
    loop();
  }

  // the renderer's draw, wrapped once per renderer object (M3 may replace the renderer): one hook per drawn frame
  wrapDraw() {
    const ren = this.app.ren;
    if (!ren || ren._tlWrapped) return;
    const orig = ren.draw.bind(ren);
    ren.draw = (rig, cam, opts) => {
      const r = orig(rig, cam, opts);
      try { this.onFrame(rig, cam); } catch (e) { if (!this.frameError) { this.frameError = true; reportError(e); } }
      return r;
    };
    ren._tlWrapped = true;
  }

  onFrame(rig, cam) {
    this.lastCam = cam;
    const s = this.app.state;
    this.timeline.update(s.t, s.playing, rig);
    this.overlay.draw(cam, s.t);
    const now = performance.now();
    this.panels.tick(now);
    if (now - (this.fidAt || 0) > 1000) { this.fidAt = now; this.refreshFidelity(); }
  }

  // the fidelity shown: the renderer's runtime block when it has one (M3 GameRenderer.fidelity(), built from the same
  // manifest block, so the timeline stages are in it), else the bundle's; badge and panel follow it
  fidelitySource() {
    const ren = this.app.ren;
    let rf = null;
    try { rf = ren && typeof ren.fidelity === 'function' ? ren.fidelity() : null; } catch (e) { rf = null; }
    return rf && rf.stages ? { fidelity: Object.assign({}, this.m.fidelity || {}, rf) } : this.m;
  }

  refreshFidelity() {
    const f = fidelityView(this.fidelitySource());
    if (this.fid && f.letters === this.fid.letters) return;
    this.fid = f;
    const badge = document.getElementById('badge');
    if (badge) badge.textContent = f.letters;
    this.renderBar();
    if (this.panels.tab === 'fidelity') this.panels.render();
  }

  // ------------------------------------------------------------------------------------------- state -> views
  animRec(name) {
    const main = this.m.animfiles[this.m.composition.main];
    const k = Object.keys(main.anims).find((x) => lower(x) === lower(name));
    return k ? main.anims[k] : null;
  }

  refresh() {
    const app = this.app, rig = app.rig, m = this.m;
    this.tl = buildTimeline(rig, m);
    const opts = { anim: rig.anim, variant: app.state.variant, logic: app.state.logic, sync: app.state.sync,
      method: app.state.method };
    try { this.footprints = footprintDots(app.bundle, opts, this.tl); } catch (e) { this.footprints = []; reportError(e); }
    this.overlay.set(this.footprints);
    this.stops = tagStops(this.tl.tags, this.tl.D);
    this.actions = actionsFor(m.timing, rig.anim);
    if (!this.actions.some((a) => a.action === this.action)) this.action = this.actions[0] ? this.actions[0].action : null;
    this.updateRate();
    this.fid = fidelityView(this.fidelitySource());
    this.timeline.render(this.viewModel());
    this.renderPicker();
    this.panels.setContext({ bundle: app.bundle, manifest: m, rig, anim: rig.anim, timeline: this.tl,
      footprints: this.footprints, fidelity: () => this.fidelitySource() });
  }

  viewModel() {
    return { tl: this.tl, footprints: this.footprints, actions: this.actions, selectedAction: this.action,
      rateInfo: this.rateInfo, trate: this.trate, speed: this.userSpeed, loop: this.app.state.loop,
      playing: this.app.state.playing, fidelity: this.fid };
  }

  renderBar() { this.timeline.renderBar(this.viewModel()); }

  renderPicker() {
    const m = this.m, rig = this.app.rig;
    const main = m.animfiles[m.composition.main];
    const oneSided = new Set(((m.composition.pairing || {}).one_sided || []).map((o) => lower(o.anim)));
    const anims = Object.entries(main.anims).map(([name, a]) => ({ name, variants: a.variants.length,
      rule: (a.weights && a.weights.rule) || variantWeights(a).rule, oneSided: oneSided.has(lower(name)) }));
    this.picker.render({ manifest: m, anims, anim: rig.anim, variant: rig.variant, weights: variantWeights(this.animRec(rig.anim)),
      pairing: pairingView(m, rig.anim), rig, sync: this.app.state.sync, rollMsg: this.rollMsg });
  }

  updateRate() {
    const row = this.actions.find((a) => a.action === this.action) || null;
    this.rateInfo = row ? tacticsRate(row, this.app.rig.duration) : null;
    this.applySpeed();
  }

  applySpeed() {
    this.app.state.speed = this.userSpeed * (this.trate && this.rateInfo ? this.rateInfo.rate : 1);
  }

  // ------------------------------------------------------------------------------------------- controls
  syncOld(id, value, prop = 'value') {
    const e = document.getElementById(id);
    if (e) e[prop] = value;
  }

  setAnim(name) {
    const s = this.app.state;
    s.anim = name; s.variant = 0; s.t = 0;
    this.rollMsg = '';
    this.syncOld('anim', name);
    this.app.rebuild();
  }

  setVariant(i) {
    const s = this.app.state;
    s.variant = i; s.t = 0;
    this.app.rebuild();
    this.syncOld('variant', String(i));
  }

  roll() {
    const w = variantWeights(this.animRec(this.app.rig.anim));
    const i = rollVariant(w.normalized, this.rng);
    if (i < 0) return -1;
    this.rollMsg = 'rolled v' + i + ' (p ' + (w.normalized[i] * 100).toFixed(1) + '%' + (w.hypothesis ? ', ' + w.rule : '') + ')';
    this.setVariant(i);
    return i;
  }

  setSync(k) {
    this.app.state.sync = k;
    this.syncOld('sync', k);
    this.app.rebuild();
  }

  setLoop(b) {
    this.app.state.loop = b;
    this.syncOld('loop', b, 'checked');
  }

  setAction(a) {
    this.action = a || null;
    this.updateRate();
    this.renderBar();
  }

  togglePlay() {
    this.app.state.playing = !this.app.state.playing;
    this.app.updateButtons();
  }

  scrub(t) {
    const s = this.app.state;
    s.playing = false;
    s.t = Math.min(Math.max(t, 0), this.tl.D);
    this.app.updateButtons();
  }

  stepKey(dir) {
    const main = this.tl.sides.find((x) => x.key === this.tl.main);
    if (!main || !main.grid) return;
    const g = main.grid;
    const k = Math.max(0, Math.min(g.count - 1, g.keyAt(this.app.state.t) + dir));
    this.scrub(g.time(k));
  }

  stepTag(dir) {
    const t = nextTagTime(this.stops, this.app.state.t, dir);
    if (t !== null) this.scrub(t);
    return t;
  }

  // ------------------------------------------------------------------------------------------- test mode
  report() {
    const app = this.app, tl = this.tl;
    const counts = {};
    const tab = this.panels.tab;
    for (const t of TABS) { this.panels.show(t); counts[t] = Object.assign({}, this.panels.counts); }
    this.panels.show(tab);
    return {
      anim: app.rig.anim, variant: app.rig.variant, t: app.state.t, D: tl.D, tEnd: tl.tEnd, speed: app.state.speed,
      userSpeed: this.userSpeed, trate: this.trate, action: this.action, rate: this.rateInfo,
      sides: tl.sides.map((x) => ({ key: x.key, role: x.role, clip: x.clip ? x.clip.id : null, clock: x.clock, d: x.d,
        fps: x.grid ? x.grid.fps : null, rounded: x.grid ? x.grid.rounded : null, keys: x.grid ? x.grid.count : null,
        nonInteger: x.grid ? x.grid.nonInteger : null, repeats: x.repeats, pastMainEnd: x.pastMainEnd, models: x.models })),
      tags: tl.tags.map((x) => ({ type: x.type, lane: x.lane, role: x.role, fraction: x.fraction, clipTime: x.clipTime,
        times: x.times, reached: x.reached, overflow: x.overflow, attrs: x.attrs, ghost: x.ghost, key: x.key })),
      lanes: tagLanes(tl.tags).map((l) => ({ name: l.name, n: l.tags.length })), overrides: tl.overrides,
      unattached: tl.unattached, effects: tl.effects, stops: this.stops, actions: this.actions.map((a) => a.action),
      footprints: this.footprints.map(({ tag, ...rest }) => rest),
      fidelity: { letters: this.fid.letters, counts: this.fid.counts, added: this.added,
        stages: Object.fromEntries(this.fid.rows.map((r) => [r.stage, r.flag])) },
      panels: counts, audit: auditView(this.m).items.map((i) => i.code), rows: document.querySelectorAll('#tl-dock .tl-row').length,
      markers: document.querySelectorAll('#tl-dock .tl-tag:not(.ghost)').length,
      viewport: [window.innerWidth, window.innerHeight], tip: this.timeline.tip.classList.contains('on') ?
        this.timeline.tip.textContent : null,
      stats: app.stats ? { draws: app.stats.draws, triangles: app.stats.triangles, errors: app.stats.errors } : null,
    };
  }

  async uiShots(shots) {
    await frames(6);
    const done = [];
    for (const sh of shots) {
      if (sh.anim) this.setAnim(sh.anim);
      if (sh.variant !== undefined) this.setVariant(sh.variant);
      if (sh.sync) this.setSync(sh.sync);
      if (sh.action) this.setAction(sh.action);
      if (sh.trate !== undefined) { this.trate = !!sh.trate; this.applySpeed(); this.renderBar(); }
      let t = sh.time ?? 0;
      if (sh.tag) {
        const tag = this.tl.tags.find((x) => lower(x.type) === lower(sh.tag) && x.reached.length);
        if (tag) t = tag.reached[0];
      }
      this.scrub(t);
      this.panels.show(sh.tab || 'timing');
      this.timeline.pinned = false;
      this.timeline.tip.classList.remove('on');
      await frames(8);
      const pinned = sh.tip ? this.timeline.pinTip((x) => lower(x.type) === lower(sh.tip)) : null;
      await frames(4);
      const tip = this.timeline.tip.classList.contains('on') ? this.timeline.tip.innerText : null;
      const r = await postJSON('/api/log', { level: 'uishot', msg: 'uishot:' + (sh.name || 'ui') });
      done.push({ name: sh.name || 'ui', anim: this.app.rig.anim, variant: this.app.rig.variant, t: this.app.state.t,
        tab: this.panels.tab, tip, pinned: pinned ? { type: pinned.type, fraction: pinned.fraction, time: pinned.time } : null,
        speed: this.app.state.speed, reply: r, ui: this.report() });
      this.timeline.pinned = false;
      this.timeline.tip.classList.remove('on');
    }
    const report = this.report();
    // interaction checks, after the shots (they move the playhead)
    const checks = {};
    this.setAnim(shots[0] && shots[0].anim ? shots[0].anim : this.app.rig.anim);
    this.scrub(0);
    checks.next_tag = [this.stepTag(1), this.stepTag(1)];
    checks.prev_tag = this.stepTag(-1);
    this.scrub(0);
    this.stepKey(1); this.stepKey(1); this.stepKey(1);
    checks.key3_t = this.app.state.t;
    this.userSpeed = 1;
    const rof = this.actions.find((a) => a.rof_effective && Math.abs(a.rof_effective - this.app.rig.duration) > 1e-6) || this.actions[0];
    if (rof) {
      this.setAction(rof.action);
      this.trate = true; this.applySpeed();
      checks.trate = { action: rof.action, rof: rof.rof_effective, D: this.app.rig.duration, speed: this.app.state.speed };
      this.trate = false; this.applySpeed();
      checks.trate.speed_off = this.app.state.speed;
    }
    checks.roll = [this.roll(), this.roll(), this.roll()];
    checks.roll_msg = this.rollMsg;
    await frames(3);
    await postJSON('/api/done', { status: this.app.stats && !this.app.stats.errors.length ? 'ok' : 'gl-errors', shots: done,
      ui: report, checks, gpu_path: this.app.gpu ? this.app.gpu.gpuPath : null });
  }
}
