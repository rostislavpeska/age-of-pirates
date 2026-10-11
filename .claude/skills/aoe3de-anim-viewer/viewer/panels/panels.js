// Data panels (M4, browser only): Timing (tactics rows, ROF from the protoactions, AnimationRate, transitions with
// length/exit, speedmodifier, maxvelocity, the labelled rules), Clips (curve formats and decode method per clip, the
// B-spline vs knots deviation), Bones (live world readout), Materials, Provenance (layer per file), Audit and
// Fidelity. Tables come from data.js (pure, node-tested).
import { h, clear, fmt, base, table } from '../timeline/dom.js';
import {
  timingView, clipView, curveDeviation, boneView, materialView, provenanceView, auditView, fidelityView,
} from './data.js';

export const TABS = ['timing', 'clips', 'bones', 'materials', 'provenance', 'audit', 'fidelity'];
const TITLES = { timing: 'Timing', clips: 'Clips', bones: 'Bones', materials: 'Materials', provenance: 'Provenance',
  audit: 'Audit', fidelity: 'Fidelity' };

const list = (items) => h('ul', {}, items.map((x) => h('li', {}, x)));
// an array as one value when all equal ('1.50 x4'), else the values
function collapse(arr, n = 2) {
  if (!arr || !arr.length) return '-';
  const s = arr.map((x) => fmt(x, n));
  return s.every((x) => x === s[0]) ? s[0] + (s.length > 1 ? ' x' + s.length : '') : s.join(' ');
}
const yes = (b) => (b === null || b === undefined ? '-' : b ? 'yes' : 'no');

export class Panels {
  constructor(aside, before) {
    this.root = h('section', { id: 'tl-panels' });
    this.tabs = h('div', { class: 'tl-tabs' });
    this.pane = h('div', { class: 'tl-pane' });
    this.root.append(h('div', { class: 'tl-h' }, 'Data'), this.tabs, this.pane);
    aside.insertBefore(this.root, before || null);
    this.tab = 'timing';
    this.buttons = {};
    for (const t of TABS) {
      const b = h('button', { 'data-tab': t, onclick: () => this.show(t) }, TITLES[t]);
      this.buttons[t] = b;
      this.tabs.append(b);
    }
    this.devCache = new Map();
    this.lastTick = 0;
  }

  // ctx: {bundle, manifest, rig, anim, timeline, footprints}
  setContext(ctx) { this.ctx = ctx; this.render(); }

  show(tab) {
    if (!TABS.includes(tab)) return;
    this.tab = tab;
    this.render();
  }

  render() {
    for (const [t, b] of Object.entries(this.buttons)) b.classList.toggle('on', t === this.tab);
    clear(this.pane);
    if (!this.ctx) return;
    const fn = { timing: this.timing, clips: this.clips, bones: this.bones, materials: this.materials,
      provenance: this.provenance, audit: this.audit, fidelity: this.fidelity }[this.tab];
    this.counts = {};
    fn.call(this, this.ctx);
  }

  // live parts (the bone readout) at most 5 times a second
  tick(now) {
    if (this.tab !== 'bones' || !this.ctx || now - this.lastTick < 200) return;
    this.lastTick = now;
    this.render();
  }

  // ------------------------------------------------------------------------------------------- timing
  timing({ manifest, anim }) {
    const v = timingView(manifest, anim);
    this.counts.actions = v.actions.length;
    this.pane.append(h('div', { class: 'tl-small' }, 'status: ' + v.status + ' - tactics ' + (v.tactics_file || 'none')));
    this.pane.append(h('h4', {}, 'Actions (ROF from the protoactions; current anim highlighted)'));
    this.pane.append(h('div', { class: 'tl-wrap' }, table([
      { h: 'action', f: (r) => r.action, tip: (r) => 'damage ' + fmt(r.damage, 1) + (r.maxrange !== null ? ', max range ' + fmt(r.maxrange, 1) : '') +
        (r.idleanim ? ', idle ' + r.idleanim : '') + (r.reloadanim ? ', reload ' + r.reloadanim : '') },
      { h: 'anim', f: (r) => r.anim || '-' },
      { h: 'ROF', f: (r) => fmt(r.rof_effective, 2) + ' ' + (r.rof_source === 'protoaction' ? 'proto' : r.rof_source), cls: 'num',
        tip: (r) => 'H1: source ' + r.rof_source + '; protoaction ' + fmt(r.rof_protoaction, 2) + ', tactics ' + fmt(r.rof_tactics, 2) },
      { h: 'tac', f: (r) => fmt(r.rof_tactics, 2), cls: 'num', title: 'the tactics file ROF (H1: overridden by the protoaction)' },
      { h: 'AnimRate', f: (r) => fmt(r.animationrate, 3), cls: 'num', title: 'tactics AnimationRate (H3)' },
      { h: 'clip s', f: (r) => collapse(r.clip_durations, 2), cls: 'num', title: 'clip duration per variant' },
      { h: 'fit', f: (r) => collapse(r.fit, 2), cls: 'num', title: 'H1 ROF fit: clip duration / ROF (the tactics-rate preset)' },
      { h: 'tactics (priority)', f: (r) => r.tactics.join(', ') || '-' },
    ], v.actions, { rowClass: (r) => (r.current ? 'cur' : '') })));
    const notes = v.actions.flatMap((r) => r.notes.map((n) => r.action + ': ' + n));
    if (notes.length) this.pane.append(h('div', { class: 'tl-warn' }, list(notes)));
    this.pane.append(h('h4', {}, 'Tactics (speedmodifier, maxvelocity, transitions)'));
    this.pane.append(h('div', { class: 'tl-wrap' }, table([
      { h: 'tactic', f: (r) => r.tactic },
      { h: 'speedmod', f: (r) => fmt(r.speedmodifier, 2), cls: 'num' },
      { h: 'maxvel', f: (r) => fmt(r.maxvelocity, 2), cls: 'num', tip: (r) => r.rule || '' },
      { h: 'maxrun', f: (r) => fmt(r.maxrunvelocity, 2), cls: 'num' },
      { h: 'transitions (len, exit)', f: (r) => r.transitions.map((x) => x.tactic + ' ' + fmt(x.length, 2) + 's exit ' +
        yes(x.exit) + (x.anim ? ' ' + x.anim : '')).join('; ') || 'none', cls: 'wrap' },
      { h: 'actions (priority)', f: (r) => r.actions.join(', '), cls: 'wrap' },
    ], v.tactics)));
    this.pane.append(h('div', { class: 'tl-small' }, 'transitions in this tactics file: ' + v.transitions_total +
      ' - anims (idle/walk/...): ' + (v.tactics[0] ? Object.entries(v.tactics[0].anims).map(([k, x]) => k + ' ' + x).join(', ') : '-')));
    this.pane.append(h('h4', {}, 'Movement'), h('div', {}, 'maxvelocity ' + fmt(v.movement.maxvelocity, 2) +
      ', maxrunvelocity ' + fmt(v.movement.maxrunvelocity, 2) + ', movementtype ' + (v.movement.movementtype || '-')));
    this.pane.append(h('h4', {}, 'Rules (labelled hypotheses)'), h('div', { class: 'tl-hyp' }, list(v.rules.concat(v.viewer_rules))));
    if (v.unreferenced.length) this.pane.append(h('div', { class: 'tl-small' }, 'anims no tactics names (engine logic): ' + v.unreferenced.join(', ')));
    if (v.missing.length) this.pane.append(h('div', { class: 'tl-warn' }, 'anims the tactics name but the animfile lacks: ' + v.missing.join(', ')));
  }

  // ------------------------------------------------------------------------------------------- clips
  clips({ bundle, manifest, rig }) {
    const ids = [];
    for (const inst of rig.instances) if (inst.clip && !ids.includes(inst.clip.id)) ids.push(inst.clip.id);
    this.counts.clips = ids.length;
    for (const id of ids) {
      const c = clipView(manifest, id);
      if (!this.devCache.has(id)) this.devCache.set(id, curveDeviation(bundle, id));
      const dev = this.devCache.get(id);
      this.pane.append(h('h4', {}, base(id)));
      this.pane.append(h('div', { class: 'tl-small' }, id + (c.layer ? '  [' + c.layer + ']' : '')));
      this.pane.append(h('div', {}, fmt(c.duration, 4) + ' s, timestep ' + fmt(c.timestep, 6) + ' (declared ' +
        fmt(c.fps_declared, 3) + ' fps -> grid ' + c.fps_rounded + '), ' + c.key_count + ' keys, oversampling ' +
        fmt(c.oversampling, 1) + ', ' + c.tracks + ' tracks (group ' + (c.track_group || '-') + ')'));
      if (c.non_integer) this.pane.append(h('div', { class: 'tl-warn' }, 'non-integer declared rate: keys on the rounded grid'));
      if (c.last_off_grid) this.pane.append(h('div', { class: 'tl-warn' }, 'the last key is off the grid'));
      if (!c.decodable) this.pane.append(h('div', { class: 'tl-warn' }, 'unavailable: ' + c.unavailable_reason));
      this.pane.append(h('div', {}, 'formats: ', h('span', { class: 'tl-code' }, c.formats.join(', ') || '-')));
      this.pane.append(table([
        { h: 'format', f: (r) => r.format }, { h: 'kind', f: (r) => r.kind }, { h: 'n', f: (r) => String(r.count), cls: 'num' },
        { h: 'decode method', f: (r) => r.method, cls: 'wrap' },
      ], c.methods));
      if (c.inferred_identity) this.pane.append(h('div', { class: 'tl-small' }, c.inferred_identity + ' curve(s) inferred identity (empty or no data)'));
      if (dev) {
        this.pane.append(h('div', { class: 'tl-small' }, 'B-spline vs knots-linear at every key: position ' +
          fmt(dev.position, 5) + ', orientation ' + fmt(dev.orientation, 3) + ' deg, scale-shear ' + fmt(dev.scale_shear, 5) +
          (dev.worst ? ' (worst ' + dev.worst.bone + ' ' + dev.worst.part + ' @ ' + fmt(dev.worst.time) + ' s)' : '')));
      }
    }
  }

  // ------------------------------------------------------------------------------------------- bones
  bones({ rig, footprints }) {
    const fpBones = (footprints || []).map((d) => d.bone).filter(Boolean);
    let n = 0;
    for (const inst of rig.instances) {
      const v = boneView(rig, inst.index, { footprintBones: fpBones });
      if (!v.instance) continue;
      n += v.rows.length;
      this.pane.append(h('h4', {}, inst.role + ' ' + base(v.instance.model) + '  t ' + fmt(v.instance.time) + ' [' + v.instance.clock + ']'));
      this.pane.append(h('div', { class: 'tl-wrap' }, table([
        { h: '#', f: (r) => String(r.index), cls: 'num' }, { h: 'bone', f: (r) => r.name },
        { h: 'parent', f: (r) => r.parent || '-' }, { h: 'src', f: (r) => r.source },
        { h: 'x', f: (r) => fmt(r.world && r.world[0]), cls: 'num' }, { h: 'y', f: (r) => fmt(r.world && r.world[1]), cls: 'num' },
        { h: 'z', f: (r) => fmt(r.world && r.world[2]), cls: 'num' }, { h: 'marks', f: (r) => r.marks.join('; '), cls: 'wrap' },
      ], v.rows)));
    }
    this.counts.bones = n;
    this.pane.append(h('div', { class: 'tl-small' }, 'world positions in the gr2 frame (+Y up), units as stored; the page draws x negated'));
  }

  // ------------------------------------------------------------------------------------------- materials
  materials({ manifest, rig }) {
    const models = [...new Set(rig.instances.map((x) => x.model.id))];
    const mats = materialView(manifest, models);
    this.counts.materials = mats.length;
    if (!mats.length) this.pane.append(h('div', { class: 'tl-note' }, 'no material bound (see the audit: material-file-missing)'));
    for (const m of mats) {
      this.pane.append(h('h4', {}, base(m.material_file || m.id) + '#' + (m.submaterial || '?')));
      if (m.missing) { this.pane.append(h('div', { class: 'tl-warn' }, 'material record missing')); continue; }
      this.pane.append(h('div', { class: 'tl-small' }, 'materialdef ' + m.materialdef + (m.materialdef_path ? ' (' + m.materialdef_path + ')' : '') +
        ', eol ' + (m.eol || '-') + ', layer ' + (m.layer || '-')));
      if (m.eol === 'lf') this.pane.append(h('div', { class: 'tl-warn' }, 'LF-only: the game ignores this file (AGENTS.md rule 1)'));
      this.pane.append(table([
        { h: 'slot', f: (r) => r.name }, { h: 'texture', f: (r) => base(r.texture), tip: (r) => r.texture || r.default || '' },
        { h: 'srgb', f: (r) => yes(r.srgb) }, { h: 'src', f: (r) => r.source || '-' },
        { h: 'fmt', f: (r) => (r.bc ? r.bc + ' ' + (r.size ? r.size.join('x') : '') + ' m' + r.mips : r.unavailable_reason || '-') },
      ], m.slots));
      if (m.floats.length) {
        this.pane.append(table([{ h: 'parameter', f: (r) => r.name },
          { h: 'value', f: (r) => (Array.isArray(r.value) ? r.value.map((x) => fmt(x, 3)).join(', ') : typeof r.value === 'number' ? fmt(r.value, 4) : String(r.value)), cls: 'num' },
          { h: 'from', f: (r) => r.source || '-' }], m.floats));
      }
      const flags = Object.entries(m.flags || {});
      if (flags.length) this.pane.append(h('div', { class: 'tl-small' }, 'flags: ' + flags.map(([k, x]) => k + '=' + x).join(', ')));
      if (m.unknown_overrides.length) this.pane.append(h('div', { class: 'tl-warn' }, 'unknown overrides: ' + JSON.stringify(m.unknown_overrides)));
    }
  }

  // ------------------------------------------------------------------------------------------- provenance
  provenance({ manifest, rig }) {
    const animfiles = [...new Set(rig.instances.map((x) => x.animfile))];
    const models = [...new Set(rig.instances.map((x) => x.model.id))];
    const clips = [...new Set(rig.instances.filter((x) => x.clip).map((x) => x.clip.id))];
    const v = provenanceView(manifest, { animfiles, models, clips });
    this.counts.provenance = v.rows.length;
    this.pane.append(h('h4', {}, 'Layers (lookup order: the first layer holding a file wins)'));
    this.pane.append(table([{ h: 'layer', f: (r) => r.id }, { h: 'kind', f: (r) => r.kind },
      { h: 'prio', f: (r) => (r.priority === null ? '-' : String(r.priority)), cls: 'num' },
      { h: 'files', f: (r) => String(r.files), cls: 'num' }, { h: 'drawn now', f: (r) => String(r.here), cls: 'num' }], v.layers));
    this.pane.append(h('h4', {}, 'Files behind this anim (' + v.rows.length + ' of ' + v.total + ')'));
    this.pane.append(h('div', { class: 'tl-wrap' }, table([
      { h: 'kind', f: (r) => r.kind }, { h: 'file', f: (r) => base(r.id), tip: (r) => r.id + (r.note ? ' - ' + r.note : '') },
      { h: 'layer', f: (r) => r.layer || '-' }, { h: 'container', f: (r) => r.container || '-' },
      { h: 'sha256', f: (r) => r.sha256 || '-' },
    ], v.rows, { rowClass: (r) => (r.layer && r.layer.startsWith('mod:') ? 'cur' : '') })));
    this.pane.append(h('div', { class: 'tl-small' }, 'highlighted: a file a mod layer supplies (it wins over the game archives)'));
  }

  // ------------------------------------------------------------------------------------------- audit
  audit({ manifest }) {
    const v = auditView(manifest);
    this.counts.audit = v.items.length;
    this.counts.warnings = v.warnings.length;
    if (v.unattached.length) {
      this.pane.append(h('h4', {}, 'Declared but never attached'), h('div', { class: 'tl-warn' }, list(v.unattached.map((u) =>
        u.detail.attachment + ' in ' + base(u.animfile) + ' (include ' + (u.detail.include || '-') + ')'))));
    }
    this.pane.append(h('h4', {}, 'Animfile audit (' + v.items.length + ')'));
    this.pane.append(h('div', { class: 'tl-wrap' }, table([{ h: 'code', f: (r) => r.code }, { h: 'animfile', f: (r) => base(r.animfile) },
      { h: 'detail', cls: 'wrap', f: (r) => Object.entries(r.detail).map(([k, x]) => k + ': ' + (Array.isArray(x) ? x.join(', ') : typeof x === 'object' ? JSON.stringify(x) : x)).join('; ') }],
    v.items)));
    if (v.unavailable.length) {
      this.pane.append(h('h4', {}, 'Unavailable records (drawn as placeholders)'));
      this.pane.append(table([{ h: 'kind', f: (r) => r.kind }, { h: 'id', f: (r) => base(r.id), tip: (r) => r.id },
        { h: 'reason', f: (r) => r.reason || '-', cls: 'wrap' }], v.unavailable));
    }
    this.pane.append(h('h4', {}, 'Warnings (' + v.warnings.length + ')'));
    this.pane.append(h('div', {}, list(v.warnings.map((w) => h('span', {}, h('b', {}, w.code), ' ' + (w.path || '') + ': ' + w.message)))));
  }

  // ------------------------------------------------------------------------------------------- fidelity
  fidelity({ manifest, fidelity }) {
    const f = fidelityView(fidelity ? fidelity() : manifest);
    this.counts.fidelity = f.rows.length;
    this.pane.append(h('div', {}, ['M', 'A', 'U', 'H'].map((k) => h('span', { class: 'chip f-' + k, style: { marginRight: '4px', padding: '0 4px', border: '1px solid #444', borderRadius: '3px' } }, k + ' ' + f.counts[k]))));
    this.pane.append(h('div', { class: 'tl-small' }, 'shader model ' + f.shader_model + ', calibration ' + f.calibration +
      ', viewer ' + (f.viewer || '-') + ' - M measured, A approximated, U unknown, H labelled hypothesis'));
    this.pane.append(table([{ h: '', f: (r) => h('span', { class: 'f-' + r.flag }, r.flag) }, { h: 'stage', f: (r) => r.stage },
      { h: 'note', f: (r) => r.note, cls: 'wrap' }, { h: 'from', f: (r) => r.source }], f.rows));
  }
}
