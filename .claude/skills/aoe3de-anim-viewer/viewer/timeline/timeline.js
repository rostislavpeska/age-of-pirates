// The timeline dock (M4, browser only): transport bar, ruler with the declared key rate, length bars (clip and
// animlengthoverride), one lane per side (horse, rider, each attachment clip, declared-but-unattached attachments),
// the tag lanes by type with every attribute in a tooltip, the playhead; plus the footprint dots over the 3D view.
// All numbers come from model.js (pure, node-tested); this file only places them.
import { h, svg, clear, fmt, base } from './dom.js';
import { tagLanes, roleLabel, SPEEDS, OVERFLOW_LANE, OTHER_LANE, VIEWER_RULES } from './model.js';
import { FOOTPRINT_NOTES } from './footprint.js';
import { engineToDisplay, projectCM } from '../lib/camera.js';

const LANE_LABELS = {
  Attack: 'Attack', FootstepLeft: 'FootstepLeft', FootstepRight: 'FootstepRight', SpecificSoundSet: 'SpecificSoundSet',
  Particles: 'Particles', WindEffect: 'WindEffect', CameraShake: 'CameraShake', [OTHER_LANE]: 'other tag types',
  [OVERFLOW_LANE]: 'past clip end: meaning unknown',
};
const MAJOR_STEPS = [0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.25, 0.5, 1, 2, 5, 10];
const CLOCK_TEXT = {
  main: 'main clock: clip time = t',
  absolute: 'absolute time (hypothesis): clip time = t, the child holds its last key past its end',
  phase: 'normalised phase (hypothesis): clip time = t / D x d',
  own: 'own clock (syncanims=0): clip time = t mod d, looping',
};

function esc(s) {
  return String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

export class TimelineView {
  // stage: the element around the canvas; on: handlers {scrub(t), play(), start(), stepKey(d), stepTag(d), loop(b),
  // speed(x), tacticsRate(b), action(name), badge()}
  constructor(stage, on) {
    this.on = on;
    this.dock = h('div', { id: 'tl-dock' });
    this.bar = h('div', { class: 'tl-bar' });
    this.body = h('div', { class: 'tl-body' });
    this.rows = h('div', { class: 'tl-rows' });
    this.phWrap = h('div', { class: 'tl-ph-wrap' });
    this.ph = h('div', { class: 'tl-ph' });
    this.phWrap.append(this.ph);
    this.body.append(this.rows, this.phWrap);
    this.tip = h('div', { class: 'tl-tip' });
    this.dock.append(this.bar, this.body);
    stage.append(this.dock);
    document.body.append(this.tip);
    this.buildBar();
    this.markers = [];                                   // {el, tag, occurrence}
    this.tEnd = 1;
    this.bindScrub();
    this.lastW = 0;
    window.addEventListener('resize', () => { if (this.model) this.render(this.model); });
  }

  buildBar() {
    const b = (act, text, title) => h('button', { 'data-act': act, title, onclick: () => this.act(act) }, text);
    this.playBtn = b('play', 'Pause', 'play / pause (space)');
    this.loopBox = h('input', { type: 'checkbox', 'data-act': 'loop', onchange: () => this.on.loop(this.loopBox.checked) });
    this.speedSel = h('select', { 'data-act': 'speed', title: 'playback speed (x the tactics rate when that is on)',
      onchange: () => this.on.speed(+this.speedSel.value) }, SPEEDS.map((s) => h('option', { value: s }, s + 'x')));
    this.rateBox = h('input', { type: 'checkbox', 'data-act': 'trate', onchange: () => this.on.tacticsRate(this.rateBox.checked) });
    this.actionSel = h('select', { 'data-act': 'action', title: 'the tactics action whose ROF / AnimationRate the preset uses',
      onchange: () => this.on.action(this.actionSel.value) });
    this.rateOut = h('span', { class: 'tl-rate' });
    this.timeOut = h('span', { class: 'tl-time' });
    this.badge = h('span', { class: 'tl-badge', title: 'fidelity per stage: M measured, A approximated, U unknown, ' +
      'H labelled hypothesis (click: the Fidelity panel)', onclick: () => this.on.badge() });
    this.bar.append(
      b('start', '|<', 'to the start'), b('prevkey', '< key', 'previous key of the main clip (arrow left)'), this.playBtn,
      b('nextkey', 'key >', 'next key of the main clip (arrow right)'), b('prevtag', '< tag', 'previous tag ( [ )'),
      b('nexttag', 'tag >', 'next tag ( ] )'),
      h('label', { title: 'loop the main clip' }, this.loopBox, ' loop'),
      h('label', {}, 'speed ', this.speedSel), h('span', { class: 'tl-sep' }),
      h('label', { title: 'tactics rate preset: AnimationRate (H3) x clip / ROF (H1 ROF fit), both labelled hypotheses' },
        this.rateBox, ' tactics rate'), this.actionSel, this.rateOut, this.timeOut, this.badge);
  }

  act(a) {
    if (a === 'play') this.on.play();
    else if (a === 'start') this.on.start();
    else if (a === 'prevkey') this.on.stepKey(-1);
    else if (a === 'nextkey') this.on.stepKey(1);
    else if (a === 'prevtag') this.on.stepTag(-1);
    else if (a === 'nexttag') this.on.stepTag(1);
  }

  bindScrub() {
    let drag = false;
    const tAt = (e) => {
      const r = this.phWrap.getBoundingClientRect();
      const x = Math.min(Math.max((e.clientX - r.left) / Math.max(r.width, 1), 0), 1);
      return x * this.tEnd;
    };
    this.body.addEventListener('pointerdown', (e) => {
      if (e.target.closest('.tl-label')) return;
      const m = e.target.closest('.tl-tag');
      if (m && m._tlTime !== undefined) { this.on.scrub(m._tlTime); return; }
      drag = true;
      this.body.setPointerCapture(e.pointerId);
      this.on.scrub(tAt(e));
    });
    this.body.addEventListener('pointermove', (e) => { if (drag) this.on.scrub(tAt(e)); });
    this.body.addEventListener('pointerup', () => { drag = false; });
    this.body.addEventListener('mouseover', (e) => {
      const m = e.target.closest('[data-tip]');
      if (m && m._tlTip) this.showTipAt(m._tlTip(), e.clientX, e.clientY);
    });
    this.body.addEventListener('mousemove', (e) => {
      if (this.tip.classList.contains('on') && !this.pinned) this.placeTip(e.clientX, e.clientY);
    });
    this.body.addEventListener('mouseout', (e) => {
      if (e.target.closest('[data-tip]') && !this.pinned) this.tip.classList.remove('on');
    });
  }

  // ------------------------------------------------------------------------------------------- tooltip
  showTipAt(html, x, y) {
    this.tip.innerHTML = html;
    this.tip.classList.add('on');
    this.placeTip(x, y);
  }

  placeTip(x, y) {
    const r = this.tip.getBoundingClientRect();
    const left = Math.min(x + 14, window.innerWidth - r.width - 6);
    const top = y - r.height - 12 < 4 ? y + 16 : y - r.height - 12;
    this.tip.style.left = Math.max(4, left) + 'px';
    this.tip.style.top = Math.max(4, top) + 'px';
  }

  // pin the tooltip of the first marker matching pred (the UI screenshot shows one open); returns the tag or null
  pinTip(pred) {
    const mk = this.markers.find((m) => pred(m.tag));
    if (!mk) return null;
    const r = mk.el.getBoundingClientRect();
    this.pinned = true;
    mk.el.classList.add('hot');
    this.showTipAt(this.tagTip(mk.tag, mk.occurrence), r.left + r.width / 2, r.top);
    return mk.tag;
  }

  tagTip(tag, occ = 0) {
    const L = [];
    const row = (k, v, cls = '') => L.push('<div' + (cls ? ' class="' + cls + '"' : '') + '><span class="k">' + esc(k) +
      '</span>' + esc(v) + '</div>');
    L.push('<div class="h">' + esc(tag.type) + ' @ ' + fmt(tag.fraction, 3) + ' (' + esc(roleLabel(tag.role, tag.animfile)) + ')</div>');
    row('clip', base(tag.clip));
    row('fraction', fmt(tag.fraction, 4) + (tag.overflow ? '  (> 1: past the clip end, meaning unknown)' : ''),
      tag.overflow ? 'warn' : '');
    row('clip time', fmt(tag.clipTime, 4) + ' s = fraction x clip duration (H2)');
    row('key', String(tag.key) + ' (nearest, clip_decode grid)');
    row('main time', tag.times.map((m) => fmt(m, 4)).join(', ') + ' s' + (tag.times.length > 1 ? ' (own loop, #' + occ + ')' : ''));
    row('clock', CLOCK_TEXT[tag.clock] || tag.clock, tag.clock === 'absolute' || tag.clock === 'phase' ? 'hyp' : '');
    if (!tag.reached.length) row('reached', 'never while the main clip loops (main time past D)', 'warn');
    for (const [k, v] of Object.entries(tag.attrs || {})) row(k, v);
    if (!Object.keys(tag.attrs || {}).length) row('attributes', 'none');
    if (tag.ghost !== null && tag.ghost !== undefined) row('if stretched', fmt(tag.ghost, 4) + ' s by animlengthoverride (unknown)', 'hyp');
    const ti = this.model ? this.model.tl.tags.indexOf(tag) : -1;
    const dot = ((this.model && this.model.footprints) || []).find((d) => d.tag === ti);
    if (dot) {
      row('footprint', dot.status + (dot.boneName ? ' ' + dot.boneName + ' #' + dot.index : '') +
        (dot.position ? '  (' + dot.position.map((v) => fmt(v, 3)).join(', ') + ')' : ''),
      dot.status === 'bone' ? '' : 'warn');
      row('', FOOTPRINT_NOTES[dot.status] || '', dot.status === 'bone' ? '' : 'hyp');
    }
    return L.join('');
  }

  sideTip(s, D) {
    const L = [];
    const row = (k, v, cls = '') => L.push('<div' + (cls ? ' class="' + cls + '"' : '') + '><span class="k">' + esc(k) +
      '</span>' + esc(v) + '</div>');
    L.push('<div class="h">' + esc(roleLabel(s.role, s.animfile)) + '</div>');
    row('animfile', s.animfile);
    row('anim / variant', (s.anim || '-') + ' v' + s.variant);
    row('clip', s.clip ? s.clip.id : 'none');
    if (s.grid) {
      row('duration', fmt(s.d, 4) + ' s, ' + s.grid.count + ' keys');
      row('declared rate', fmt(s.grid.fps, 4) + ' fps -> grid ' + s.grid.rounded + ' fps' +
        (s.grid.nonInteger ? '  NON-INTEGER: keys on the rounded grid' : ''), s.grid.nonInteger ? 'warn' : '');
      if (s.grid.lastOffGrid) row('last key', 'off the grid (duration not a whole number of steps)', 'warn');
    }
    row('clock', CLOCK_TEXT[s.clock] || s.clock, s.clock === 'absolute' || s.clock === 'phase' ? 'hyp' : '');
    if (s.pastMainEnd) row('end', 'clip ' + fmt(s.d) + ' s > main ' + fmt(D) + ' s: its end is never reached', 'warn');
    if (s.holdsLastKey) row('end', 'clip ' + fmt(s.d) + ' s < main ' + fmt(D) + ' s: holds its last key', 'warn');
    if (s.attach) row('attach', (s.attach.attachment || s.attach.a) + ': ' + s.attach.frombone + ' -> ' + s.attach.tobone +
      ', syncanims=' + (s.attach.syncanims ? 1 : 0));
    row('models', s.models.map(base).join(', '));
    for (const n of s.notes || []) row('note', n, /hypothesis|assumption/.test(n) ? 'hyp' : '');
    return L.join('');
  }

  // ------------------------------------------------------------------------------------------- render
  // model: {tl, footprints, actions [{action}], selectedAction, rateInfo, trate, speed, loop, playing, fidelity,
  //         subjectLabel}
  render(model) {
    this.model = model;
    const tl = model.tl;
    this.tEnd = tl.tEnd * 1.02;
    const X = (t) => (t / this.tEnd) * 100 + '%';
    clear(this.rows);
    this.markers = [];
    const trackW = Math.max(200, (this.body.getBoundingClientRect().width || 900) - 176);
    this.lastW = trackW;
    const pxs = trackW / this.tEnd;
    // ruler
    const ruler = this.row('ruler', this.rulerLabel(tl), null);
    const rt = ruler.track;
    const step = MAJOR_STEPS.find((s) => s * pxs >= 56) || 10;
    for (let k = 0; k * step <= this.tEnd + 1e-9; k++) {
      rt.append(h('div', { class: 'tl-major', style: { left: X(k * step) } }, h('span', {}, fmt(k * step, step < 0.1 ? 3 : step < 1 ? 2 : 1))));
    }
    const mainSide = tl.sides.find((s) => s.key === tl.main);
    if (mainSide && mainSide.grid) rt.append(this.keyTicks(mainSide, 0, pxs, 0.55, 1));
    // length bars: the main clip and every animlengthoverride
    const len = this.row('length', 'length (s)<br><span class="tl-small">clip / animlengthoverride</span>', null);
    len.track.append(h('div', { class: 'tl-span length', style: { left: X(0), width: X(tl.D) } }, h('span', {}, 'clip ' + fmt(tl.D) + ' s')));
    for (const o of tl.overrides) {
      const el = h('div', { class: 'tl-span override', 'data-tip': '', style: { left: X(0), width: X(o.mainLength) } },
        h('span', {}, 'animlengthoverride ' + fmt(o.length) + ' s (' + o.role + ')'));
      el._tlTip = () => '<div class="h">animlengthoverride</div><div><span class="k">length</span>' + fmt(o.length, 4) +
        ' s against the clip ' + fmt(o.clipDuration, 4) + ' s</div><div class="hyp">' + esc(VIEWER_RULES.override) + '</div>';
      len.track.append(el);
    }
    for (const tag of tl.tags) {
      if (tag.ghost === null || tag.ghost === undefined) continue;
      const g = h('div', { class: 'tl-tag ghost', 'data-tip': '', style: { left: X(tag.ghost) } });
      g._tlTip = () => '<div class="h">' + esc(tag.type) + ' if animlengthoverride stretches tags</div><div class="hyp">' +
        fmt(tag.ghost, 4) + ' s = fraction x override (unknown)</div>';
      len.track.append(g);
    }
    // one lane per side
    for (const s of tl.sides) {
      const lab = '<b>' + esc(s.role === 'main' ? 'main' : s.role === 'child' ? 'rider/child' : 'attach') + '</b> ' +
        esc(s.clip ? base(s.clip.id) : base(s.animfile).replace(/\.xml$/i, '') + ' (no clip)') + (s.grid ? ' <span class="tl-small">' + s.grid.rounded + ' fps</span>' : '') +
        (s.grid && s.grid.nonInteger ? ' <span class="flag">non-int fps</span>' : '');
      const r = this.row('side', lab, this.sideTip(s, tl.D));
      const cls = 'tl-span s-' + s.role;
      if (!s.clip) {
        r.track.append(h('span', { class: 'tl-small', style: { position: 'absolute', left: '6px', lineHeight: '18px' } },
          'no clip (' + (s.anim || 'no anim') + ')' + (s.clock === 'own' ? ', own clock' : '')));
      } else if (s.clock === 'own') {
        for (const t0 of s.repeats) {
          const w = Math.min(s.d, Math.max(tl.D - t0, 0));
          const el = h('div', { class: cls, 'data-tip': '', style: { left: X(t0), width: X(w) } });
          el._tlTip = () => this.sideTip(s, tl.D);
          r.track.append(el, this.keyTicks(s, t0, pxs, 0, 1, Math.min(s.d, tl.D - t0)));
        }
      } else {
        const end = s.clock === 'phase' ? tl.D : s.d;
        const el = h('div', { class: cls, 'data-tip': '', style: { left: X(0), width: X(Math.min(end, Math.max(tl.D, end))) } });
        el._tlTip = () => this.sideTip(s, tl.D);
        r.track.append(el, this.keyTicks(s, 0, pxs, 0, s.clock === 'phase' && s.d > 0 ? tl.D / s.d : 1));
        if (s.pastMainEnd) r.track.append(h('div', { class: 'tl-hatch', title: 'never reached: the main clip loops at ' + fmt(tl.D) + ' s',
          style: { left: X(tl.D), width: X(s.d - tl.D) } }));
        if (s.holdsLastKey) r.track.append(h('div', { class: 'tl-hatch', title: 'holds its last key (absolute time)',
          style: { left: X(s.d), width: X(tl.D - s.d) } }));
      }
    }
    for (const u of tl.unattached) {
      const r = this.row('unattached', esc(u.name), '<div class="h">' + esc(u.name) + '</div><div class="warn">declared ' +
        'in ' + esc(base(u.animfile)) + ', never attached by any &lt;attach&gt; (audit: declared-not-attached)</div><div>' +
        '<span class="k">include</span>' + esc(u.include || '-') + '</div>');
      r.track.append(h('span', {}, 'declared, never attached (audit)'));
    }
    for (const fx of tl.effects || []) {
      const r = this.row('unattached effect', esc(fx.name) + ' <span class="tl-small">(' + esc(base(fx.animfile)) + ')</span>',
        '<div class="h">' + esc(fx.name) + '</div><div class="warn">' + esc(fx.reason) + '</div><div><span class="k">animfile' +
        '</span>' + esc(fx.animfile) + '</div><div><span class="k">syncanims</span>' + (fx.syncanims ? 1 : 0) + '</div>');
      r.track.append(h('span', {}, fx.reason));
    }
    // tag lanes
    for (const lane of tagLanes(tl.tags)) {
      const r = this.row('lane lane-' + lane.name + (lane.tags.length ? '' : ' empty'),
        esc(LANE_LABELS[lane.name] || lane.name) + (lane.tags.length ? ' <span class="tl-small">' + lane.tags.length + '</span>' : ''),
        lane.name === OVERFLOW_LANE ? '<div class="h">overflow lane</div><div class="warn">' + esc(VIEWER_RULES.overflow) +
          ' (202 vanilla tags, up to 1.6)</div>' : null);
      for (const tag of lane.tags) {
        tag.times.forEach((m, occ) => {
          const reached = m <= tl.D + 1e-6;
          const cls = ['tl-tag', 't-' + String(tag.type).toLowerCase(), 's-' + tag.role, tag.footstep ? 'foot' : '',
            reached ? '' : 'unreached'].join(' ');
          const el = h('div', { class: cls, 'data-tip': '', style: { left: X(m) } });
          el._tlTime = Math.min(m, tl.D);
          el._tlTip = () => this.tagTip(tag, occ);
          r.track.append(el);
          this.markers.push({ el, tag, occurrence: occ });
        });
      }
    }
    // the main clip end, where the main clock loops
    const dend = h('div', { class: 'tl-dend', style: { left: 'calc(var(--tl-label-w) + (100% - var(--tl-label-w)) * ' +
      (tl.D / this.tEnd) + ')' } }, h('span', {}, 'D ' + fmt(tl.D) + ' s'));
    this.rows.append(dend);
    this.rows.style.position = 'relative';
    this.renderBar(model);
  }

  rulerLabel(tl) {
    const g = tl.keyGrid;
    if (!g) return 'time (s)';
    return 'time (s) <span class="tl-small">main ' + g.rounded + ' fps, ' + g.count + ' keys</span>' +
      (g.nonInteger ? '<br><span class="flag">declared ' + fmt(g.fps, 3) + ' fps: non-integer</span>' : '') +
      (g.lastOffGrid ? '<br><span class="flag">last key off-grid</span>' : '');
  }

  // key ticks of a side: keys k at t0 + k / fps * scale, thinned to >= 2.5 px apart
  keyTicks(s, t0, pxs, top = 0, scale = 1, limit = Infinity) {
    const g = s.grid;
    const e = svg('svg', { viewBox: '0 0 1000 10', preserveAspectRatio: 'none' });
    if (!g || !g.rounded) return e;
    const spacing = (g.step * scale) * pxs;
    const stride = spacing < 2.5 ? Math.ceil(2.5 / Math.max(spacing, 1e-6)) : 1;
    let d = '';
    for (let k = 0; k < g.count; k += stride) {
      const tc = g.time(k);
      if (tc > limit + 1e-9) break;
      const x = ((t0 + tc * scale) / this.tEnd) * 1000;
      d += 'M' + x.toFixed(2) + ' ' + (top * 10).toFixed(1) + 'V10';
    }
    e.append(svg('path', { d, stroke: s.role === 'main' ? '#8a7a50' : s.role === 'child' ? '#5a7a98' : '#7a6a98',
      'stroke-width': 1, 'vector-effect': 'non-scaling-stroke', fill: 'none' }));
    if (stride > 1) {
      const title = svg('title', {});
      title.textContent = 'every ' + stride + 'th key drawn (' + g.count + ' keys)';
      e.append(title);
    }
    return e;
  }

  row(kind, labelHtml, tipHtml) {
    const label = h('div', { class: 'tl-label' });
    label.innerHTML = labelHtml;
    if (tipHtml) { label.setAttribute('data-tip', ''); label._tlTip = () => tipHtml; }
    const track = h('div', { class: 'tl-track' });
    const r = h('div', { class: 'tl-row ' + kind }, label, track);
    this.rows.append(r);
    return { row: r, label, track };
  }

  renderBar(model) {
    this.loopBox.checked = !!model.loop;
    const sp = SPEEDS.includes(model.speed) ? model.speed : 1;
    this.speedSel.value = String(sp);
    this.rateBox.checked = !!model.trate;
    clear(this.actionSel);
    if (!model.actions.length) this.actionSel.append(h('option', { value: '' }, 'no tactics action plays this anim'));
    for (const a of model.actions) {
      this.actionSel.append(h('option', { value: a.action }, a.action + ' (ROF ' + fmt(a.rof_effective, 2) + ', ' + a.rof_source + ')'));
    }
    this.actionSel.value = model.selectedAction || '';
    this.actionSel.disabled = !model.actions.length;
    const ri = model.rateInfo;
    this.rateOut.className = 'tl-rate' + (model.trate ? ' on' : '');
    this.rateOut.textContent = ri ? 'x' + fmt(ri.rate, 3) + ' ' + (ri.parts.map((p) => p.rule + ' ' + fmt(p.value, 3)).join(' * ') || 'no rule applies') +
      (ri.cycle ? ', cycle ' + fmt(ri.cycle) + ' s' : '') : '';
    this.rateOut.title = ri ? ri.parts.map((p) => p.rule + ': ' + p.label + ' ' + fmt(p.value, 4) +
      (p.rof ? ' (clip ' + fmt(p.clip) + ' s / ROF ' + fmt(p.rof) + ' s, ' + p.source + ')' : '')).concat(ri.notes).join('\n') : '';
    const f = model.fidelity;
    clear(this.badge);
    if (f) {
      for (const k of ['M', 'A', 'U', 'H']) this.badge.append(h('span', { class: 'chip f-' + k, title: f.rows.filter((r) => r.flag === k).map((r) => r.stage).join(', ') }, k + ' ' + f.counts[k]));
    }
  }

  // per frame: playhead, play button, time readout
  update(t, playing, rig) {
    const tl = this.model && this.model.tl;
    if (!tl) return;
    this.ph.style.left = (Math.min(t, this.tEnd) / this.tEnd) * 100 + '%';
    this.playBtn.textContent = playing ? 'Pause' : 'Play';
    const parts = ['t ' + fmt(t) + ' / ' + fmt(tl.D) + ' s'];
    const main = tl.sides.find((s) => s.key === tl.main);
    if (main && main.grid) parts.push('key ' + main.grid.keyAt(t) + '/' + (main.grid.count - 1) + ' @' + main.grid.rounded);
    for (const inst of (rig && rig.instances) || []) {
      if (inst.role === 'child' && inst.clip) {
        const g = tl.sides.find((s) => s.role === 'child' && s.animfile === inst.animfile);
        if (g && g.grid) { parts.push('child key ' + g.grid.keyAt(inst.time) + '/' + (g.grid.count - 1) + ' @' + g.grid.rounded); break; }
      }
    }
    this.timeOut.textContent = parts.join('  ');
    for (const mk of this.markers) {
      const m = mk.tag.times[mk.occurrence];
      const on = Math.abs(m - t) < 0.02;
      if (on !== mk.el.classList.contains('hot') && !this.pinned) mk.el.classList.toggle('hot', on);
    }
  }
}

// footprint dots over the 3D view: projected with the camera of the frame just drawn
export class FootOverlay {
  constructor(stage, canvas) {
    this.canvas = h('canvas', { id: 'tl-overlay' });
    this.view = canvas;
    stage.append(this.canvas);
    this.dots = [];
  }

  set(dots) { this.dots = dots || []; }

  draw(cam, t) {
    const c = this.canvas, v = this.view;
    const w = v.clientWidth, hh = v.clientHeight, dpr = window.devicePixelRatio || 1;
    if (c.width !== Math.round(w * dpr) || c.height !== Math.round(hh * dpr)) {
      c.width = Math.round(w * dpr); c.height = Math.round(hh * dpr);
      c.style.width = w + 'px'; c.style.height = hh + 'px';
    }
    const g = c.getContext('2d');
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, w, hh);
    if (!cam || !cam.viewProj) return;
    g.font = '10px ui-monospace, Consolas, monospace';
    const groups = new Map();                            // dots on the same pixel (all at the origin) share a label
    for (const d of this.dots) {
      if (!d.position) continue;
      const p = projectCM(cam.viewProj, engineToDisplay(d.position));
      if (p[3] <= 0) continue;
      const x = (p[0] / p[3] * 0.5 + 0.5) * w, y = (1 - (p[1] / p[3] * 0.5 + 0.5)) * hh;
      const key = Math.round(x) + ',' + Math.round(y);
      if (!groups.has(key)) groups.set(key, { x, y, dots: [] });
      groups.get(key).dots.push(d);
    }
    for (const { x, y, dots } of groups.values()) {
      let hot = null;
      for (const d of dots) { const dt = t - d.time; if (dt >= -0.02 && dt < 0.3) hot = d; }
      const show = hot || dots[0];
      const left = /left/i.test(show.type);
      g.beginPath();
      g.arc(x, y, hot ? 6 : 4, 0, Math.PI * 2);
      g.lineWidth = 1.5;
      g.strokeStyle = left ? '#6ad0ff' : '#ffd34a';
      g.setLineDash(dots.some((d) => d.status !== 'bone') ? [2, 2] : []);
      if (hot) { g.fillStyle = g.strokeStyle; g.fill(); }
      g.stroke();
      g.setLineDash([]);
      const label = dots.map((d) => (/left/i.test(d.type) ? 'L' : 'R') + d.fraction.toFixed(2)).join(' ') +
        (dots.some((d) => d.status !== 'bone') ? '  ? origin assumed' : '');
      g.fillStyle = '#d8dbe0';
      g.fillText(label, x + 8, y - 6);
    }
  }
}
