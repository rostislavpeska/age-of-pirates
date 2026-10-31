// M3 shading panel (browser-only): renderer (game shader / M2 placeholder), lighting preset, player colour swatches,
// shadows, G-buffer quantisation, tonemap path, debug view, sun / exposure / IBL overrides, the shading fidelity
// table and the derived lighting constants with their status words. Mounted by hook.js into one container element;
// it never touches other parts of the page (the page's own badge is updated through the onFidelity callback).
import { DEBUG_VIEWS, TONEMAPS } from './renderer.js';

const FLAG_TITLE = { M: 'measured', A: 'approximated', U: 'unknown', H: 'labelled hypothesis' };

function el(tag, attrs = {}, text) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  if (text !== undefined) e.textContent = text;
  return e;
}

function label(text, input, title) {
  const l = el('label', title ? { title } : {}, text + ' ');
  l.append(input);
  return l;
}

function select(options, value) {
  const s = el('select');
  for (const [v, t] of options) s.append(el('option', { value: v }, t));
  s.value = value;
  return s;
}

function slider(min, max, step, value) {
  return el('input', { type: 'range', min, max, step, value });
}

function fmt(v) {
  if (v === null || v === undefined) return '-';
  if (Array.isArray(v)) return '[' + v.map((x) => (typeof x === 'number' ? x.toFixed(3) : x)).join(', ') + ']';
  return typeof v === 'number' ? v.toFixed(3) : String(v);
}

// container: an element; ren: GameRenderer; opts: {onFidelity(fid), onChange()}
export function mountShadingPanel(container, ren, opts = {}) {
  container.innerHTML = '';
  const changed = () => {
    if (opts.onChange) opts.onChange();
    refresh();
  };
  const head = el('div', { class: 'sh-head' });
  head.append(el('b', {}, 'Shading '), el('span', { class: 'sh-badge', title: 'shading stages: M measured, A approximated, U unknown, H hypothesis' }));
  container.append(head);

  const row1 = el('div');
  const mode = select([['game', 'game shader (M3)'], ['placeholder', 'placeholder (M2)']], ren.opts.mode);
  mode.onchange = () => { ren.set({ mode: mode.value }); changed(); };
  const presets = ren.presets();
  const lgt = select(presets.map((p) => [p.name, p.name + (p.bundle_id ? '' : ' (bundle, cube <= 128 px)')]), ren.lightingName);
  lgt.onchange = async () => {
    lgt.disabled = true;
    try { await ren.loadPreset(lgt.value); syncSun(); } catch (e) { msg.textContent = String(e.message || e); }
    lgt.disabled = false;
    changed();
  };
  row1.append(label('Renderer', mode), label('Lighting', lgt, 'lgt set: the lighting pack carries the full reflection cube'));
  container.append(row1);

  // player colours: one swatch per player (playercolors color1)
  const sw = el('div', { class: 'sh-swatches' });
  const pcs = (ren.bundle.manifest.lighting || {}).player_colors || [];
  for (const p of pcs) {
    const b = el('button', { class: 'sh-swatch', title: 'player ' + p.index + ': ' + (p.rgb || []).join(' ') + ' (color1, sRGB/255 decoded: guess)' });
    b.style.background = p.rgb ? 'rgb(' + p.rgb.join(',') + ')' : '#888';
    b.onclick = () => { ren.setPlayerColour(p.index); changed(); };
    b.dataset.index = p.index;
    sw.append(b);
  }
  container.append(label('Player colour', sw));

  const row2 = el('div');
  const shadows = el('input', { type: 'checkbox' });
  shadows.checked = !!ren.opts.shadows;
  shadows.onchange = () => { ren.set({ shadows: shadows.checked }); changed(); };
  const quant = el('input', { type: 'checkbox' });
  quant.checked = !!ren.opts.quant;
  quant.onchange = () => { ren.set({ quant: quant.checked }); changed(); };
  const tone = select(TONEMAPS.map((t) => [t, { lut: 'LUT (fxaacolorgradetonemap)', legacy: 'legacy Hable (tonemap.hlsl)', off: 'off (sRGB)' }[t]]), ren.opts.tonemap);
  tone.onchange = () => { ren.set({ tonemap: tone.value }); changed(); };
  const dbg = select(DEBUG_VIEWS.map((d) => [d, d]), ren.opts.debug);
  dbg.onchange = () => { ren.set({ debug: dbg.value }); changed(); };
  row2.append(label('shadows', shadows), label('G-buffer 8/10 bit', quant, 'emulate the deferred storage (formats inferred)'),
    label('Tonemap', tone, 'which path the game runs is unknown'), label('View', dbg));
  container.append(row2);

  // overrides: sun azimuth / elevation, exposure, IBL intensity
  const row3 = el('div');
  const az = slider(-180, 180, 1, 0), elv = slider(-10, 90, 1, 45);
  const expo = slider(0.25, 4, 0.05, 1), ibl = slider(0, 3, 0.05, 1);
  const azv = el('span'), elvv = el('span'), expov = el('span'), iblv = el('span');
  const decode = select([['srgb', 'sRGB decode (guess)'], ['linear', 'x/255 (alternative)']], 'srgb');
  const apply = () => {          // any control moved: all values become page overrides (badge: lgt_mapping U)
    ren.setOverrides({ sunAz: +az.value, sunEl: +elv.value, exposure: +expo.value, iblIntensity: +ibl.value,
      colourDecode: decode.value });
    changed();
  };
  for (const s of [az, elv, expo, ibl]) s.oninput = apply;
  decode.onchange = apply;
  const reset = el('button', {}, 'reset to lgt');
  reset.onclick = () => { ren.setOverrides({}); decode.value = 'srgb'; syncSun(); changed(); };
  row3.append(label('sun az', az), azv, label(' el', elv), elvv, el('br'), label('exposure', expo), expov,
    label(' IBL', ibl), iblv, el('br'), label('lgt colours', decode, 'how the 0..255 lgt colours become shader colours: unknown until calibration'),
    ' ', reset);
  container.append(row3);
  function syncSun() {
    const d = ren.light.sunAzEl;
    az.value = String(Math.round(d.az)); elv.value = String(Math.round(d.el));
    expo.value = String(ren.light.exposure); ibl.value = String(ren.light.intensity);
  }
  syncSun();

  const msg = el('div', { class: 'note' });
  container.append(msg);
  const fidBox = el('details');
  fidBox.append(el('summary', {}, 'Shading fidelity and lighting constants'));
  const ftable = el('table');
  const ctable = el('table');
  fidBox.append(ftable, el('div', { class: 'note' }, 'lgt -> shader constants (status as derived by lighting.py):'), ctable);
  container.append(fidBox);

  function refresh() {
    const fid = ren.fidelity();
    head.querySelector('.sh-badge').textContent = ' ' + fid.badge;
    ftable.innerHTML = '';
    for (const [k, v] of Object.entries(fid.stages)) {
      const tr = el('tr');
      tr.append(el('td', { class: 'f-' + v, title: FLAG_TITLE[v] || '' }, v), el('td', {}, k), el('td', { class: 'note' }, fid.notes[k] || ''));
      ftable.append(tr);
    }
    const d = ren.describe();
    ctable.innerHTML = '';
    for (const [k, v] of Object.entries(d.uniforms)) {
      const tr = el('tr');
      const st = { sunDir: 'sun_direction', sunAzEl: 'sun_direction', sunColor: 'sun_color', shadowColor: 'shadow_color',
        hemiTop: 'hemi_top', hemiBottom: 'hemi_bottom', intensity: 'sky_cube_intensity', normalize: 'sky_cube_normalize',
        exposure: 'exposure', mipBias: 'mip_bias', whitePoint: 'white_point', gradeEnabled: 'grade_enabled' }[k];
      tr.append(el('td', {}, k), el('td', {}, typeof v === 'object' && v && !Array.isArray(v) ? JSON.stringify(v) : fmt(v)),
        el('td', { class: 'note' }, st ? (d.statuses[st] || '-') : ''));
      ctable.append(tr);
    }
    azv.textContent = ' ' + Math.round(+az.value); elvv.textContent = ' ' + Math.round(+elv.value);
    expov.textContent = ' ' + (+expo.value).toFixed(2); iblv.textContent = ' ' + (+ibl.value).toFixed(2);
    msg.textContent = (fid.notes_runtime || []).join(' | ');
    for (const b of sw.querySelectorAll('.sh-swatch')) b.classList.toggle('on', +b.dataset.index === ren.playerIndex);
    if (opts.onFidelity) opts.onFidelity(fid);
  }
  refresh();
  return { refresh, elements: { mode, lgt, shadows, quant, tone, dbg, az, elv, expo, ibl, swatches: sw } };
}

export const PANEL_CSS = `
.sh-head { margin-bottom: 4px; }
.sh-badge { letter-spacing: 1px; color: var(--dim, #8b919b); }
.sh-swatches { display: inline-flex; flex-wrap: wrap; gap: 3px; vertical-align: middle; }
.sh-swatch { width: 16px; height: 16px; padding: 0; border: 1px solid #000; border-radius: 2px; cursor: pointer; }
.sh-swatch.on { outline: 2px solid var(--acc, #e0b44a); }
`;
