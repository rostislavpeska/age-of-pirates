// The clip picker (M4, browser only): anim -> variants with their normalised weights ('uniform (hypothesis)' when no
// variant declares one), a weighted roll, the rider/horse pairing with its rule, and the horse-only fallback labelled
// as an assumption. Numbers come from model.variantWeights and panels/data.pairingView.
import { h, clear, fmt, base, table } from './dom.js';
import { SYNC_MODES } from '../lib/rig.js';

const short = (id) => base(id).replace(/\.gr2$/i, '');

export class ClipPicker {
  // aside: the side panel; before: the element to insert in front of; on: {anim(name), variant(i), roll(), sync(mode)}
  constructor(aside, before, on) {
    this.on = on;
    this.root = h('section', { id: 'tl-picker' });
    this.animSel = h('select', { id: 'tl-anim', onchange: () => this.on.anim(this.animSel.value) });
    this.rollBtn = h('button', { id: 'tl-roll', title: 'draw a variant by the normalised weights (hypothesis: how and when ' +
      'the engine draws is not measured)', onclick: () => this.on.roll() }, 'roll');
    this.rollMsg = h('span', { class: 'tl-note' });
    this.syncSel = h('select', { id: 'tl-sync', onchange: () => this.on.sync(this.syncSel.value) },
      SYNC_MODES.map((k) => h('option', { value: k }, k === 'absolute' ? 'absolute time' : 'normalised phase')));
    this.body = h('div');
    this.root.append(h('div', { class: 'tl-h' }, 'Clip'),
      h('div', {}, h('label', {}, 'Anim ', this.animSel), ' ', this.rollBtn, ' ', this.rollMsg), this.body);
    aside.insertBefore(this.root, before || null);
  }

  // ctx: {manifest, anims [{name, variants, rule, oneSided}], anim, variant, weights, pairing, rig, sync, rollMsg}
  render(ctx) {
    clear(this.animSel);
    for (const a of ctx.anims) {
      this.animSel.append(h('option', { value: a.name }, a.name + '  (' + a.variants + ' var, ' +
        (a.rule === 'declared' ? 'weights' : a.rule === 'none' ? 'none' : 'uniform H') + ')' + (a.oneSided ? '  horse only' : '')));
    }
    this.animSel.value = ctx.anim;
    this.syncSel.value = ctx.sync;
    this.rollMsg.textContent = ctx.rollMsg || '';
    clear(this.body);
    const m = ctx.manifest;
    const w = ctx.weights;
    this.body.append(h('div', { class: 'tl-wrule' + (w.hypothesis ? ' hyp' : '') },
      'weights: ' + w.label + (w.rule === 'declared' ? ' (sum ' + w.sum + ')' : '')));
    const main = m.animfiles[m.composition.main];
    const key = Object.keys(main.anims).find((k) => k.toLowerCase() === String(ctx.anim).toLowerCase());
    const animRec = key ? main.anims[key] : null;
    const pairs = new Map((ctx.pairing.pairs || []).map((p) => [p.main_variant, p]));
    const rows = ((animRec && animRec.variants) || []).map((v, i) => ({ v, i, p: pairs.get(i) || null,
      clip: v.clip ? m.clips[v.clip] : null }));
    const cols = [
      { h: '#', f: (r) => String(r.i), cls: 'num' },
      { h: 'clip', f: (r) => short(r.v.clip || r.v.file), tip: (r) => r.v.clip || ('file-missing: ' + r.v.file) },
      { h: 's', f: (r) => (r.clip ? fmt(r.clip.duration) : 'missing'), cls: 'num' },
      { h: 'fps', f: (r) => (r.clip ? String(Math.round(r.clip.fps_declared)) : '-'), cls: 'num',
        tip: (r) => (r.clip ? 'declared ' + r.clip.fps_declared : '') },
      { h: 'w', f: (r) => (w.raw[r.i] === null ? '-' : String(w.raw[r.i])), cls: 'num', title: 'raw <weight>' },
      { h: 'p', f: (r) => h('span', {}, h('span', { class: 'tl-wbar' + (w.hypothesis ? ' hyp' : ''),
        style: { width: Math.max(1, Math.round(w.normalized[r.i] * 60)) + 'px' } }), (w.normalized[r.i] * 100).toFixed(1) + '%'),
      title: 'normalised weight' },
      { h: 'rider (rule)', f: (r) => (r.p && r.p.child_clip ? h('span', { class: r.p.mismatch ? 'tl-warn' : '' },
        'v' + r.p.child_variant + ' ' + short(r.p.child_clip) + ' ' + fmt(r.p.child_duration) + 's' + (r.p.mismatch ? ' !=' : '')) : '-'),
      tip: (r) => (r.p ? 'pairing ' + r.p.rule + (r.p.mismatch ? ': durations differ (main ' + fmt(r.p.main_duration) +
        ' s, child ' + fmt(r.p.child_duration) + ' s)' : '') : '') },
    ];
    this.body.append(h('div', { class: 'tl-wrap' }, table(cols, rows, { rowClass: (r) => (r.i === ctx.variant ? 'cur' : ''),
      onRow: (r) => this.on.variant(r.i) })));
    // pairing
    const p = ctx.pairing;
    const pr = h('div', { class: 'tl-pairing' });
    if (p.child) {
      pr.append(h('div', { class: 'tl-hyp' }, 'pairing (' + (p.status || '?') + '): ' + (p.rule || '-')),
        h('div', {}, h('label', { title: 'how the synced rider runs against the horse clock (hypothesis)' }, 'rider sync ', this.syncSel)));
      if (p.one_sided) pr.append(h('div', { class: 'tl-warn' }, ctx.anim + ' exists only in the ' + p.one_sided.side +
        ' animfile: ' + p.fallback));
      if (p.pairs.some((x) => x.mismatch)) pr.append(h('div', { class: 'tl-warn' }, 'durations differ on ' +
        p.pairs.filter((x) => x.mismatch).map((x) => 'v' + x.main_variant).join(', ') + ' (absolute time: the shorter side holds ' +
        'its last key; normalised phase: stretched)'));
      if (p.ragdoll) pr.append(h('div', { class: 'tl-warn' }, 'ragdoll not simulated: the shorter side probably hands over to a ' +
        'Havok ragdoll'));
    } else {
      pr.append(h('div', { class: 'tl-note' }, 'no synced child (no rider pairing)'));
    }
    this.body.append(pr);
    // the rig as composed now
    const rig = h('div', { class: 'tl-rig' });
    for (const inst of ctx.rig.instances) {
      rig.append(h('div', {}, h('b', {}, inst.role + ' '), base(inst.model.id) + '  ' + (inst.anim || '-') +
        (inst.variant >= 0 ? ' v' + inst.variant : '') + '  ' + base(inst.clip && inst.clip.id) + '  [' + inst.clock + ']'));
      for (const n of inst.notes || []) rig.append(h('div', { class: /hypothesis|assumption/.test(n) ? 'tl-hyp tl-small' : 'tl-small' }, '  ' + n));
    }
    for (const n of ctx.rig.notes || []) rig.append(h('div', { class: 'tl-small' }, n));
    this.body.append(rig);
  }
}
