// The viewer page: one unit bundle, its anims and variants, the rider on the horse, the torch in the rider's hand, a
// game-like camera, drawn by the M3 game shader (viewer/shading), with the M4 timeline dock, clip picker and data
// panels mounted on top (viewer/timeline/mount.js). Two modes:
// - interactive (the owner's own browser): /viewer/app/index.html?token=..&bundle=<id>
// - job (headless.py, no window): &test=1&job=<JSON> (or job=@server: the job comes from GET /api/job) renders the
//   listed frames through viewer/export/job.js (M5: tags / keys / fps expansion, compare subject, geometry dumps).
// The App's state is the single source of truth; M3 and M4 attach through their own hooks (shading/hook.js,
// timeline/mount.js) and never require each other.
import { postJSON, postFile, reportError, installErrorHooks, TOKEN, TEST_MODE, PARAMS } from '../lib/host.js';
import { loadBundle } from '../lib/bundle.js';
import { rendererInfo, classifyGpuPath } from '../lib/gl.js';
import { Rig, boundsOf, defaultLogic, SYNC_MODES } from '../lib/rig.js';
import { gameCamera, GAME_PITCH, DEFAULT_FOV } from '../lib/camera.js';
// M3 game shader: the only entry points this page uses (viewer/shading/hook.js documents them)
import { createRenderer, mountShading } from '../shading/hook.js';
// M5 job runner (headless exports)
import { runJob } from '../export/job.js';

const $ = (id) => document.getElementById(id);

async function apiGet(path) {
  const r = await fetch(path, { headers: { 'X-AV-Token': TOKEN } });
  if (!r.ok) throw new Error('GET ' + path + ' -> ' + r.status);
  return r.json();
}

function el(tag, attrs = {}, text) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  if (text !== undefined) e.textContent = text;
  return e;
}

function fmt(x, n = 3) { return x === null || x === undefined ? '-' : Number(x).toFixed(n); }
function base(id) { return id ? String(id).split('/').pop() : '-'; }

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

// --------------------------------------------------------------------------------------------- interactive mode
class App {
  constructor(bundle) {
    this.bundle = bundle;
    this.m = bundle.manifest;
    this.canvas = $('view');
    const { gl, info, gpuPath } = setupGL(this.canvas);
    this.gl = gl;
    this.gpu = { info, gpuPath };
    this.ren = createRenderer(gl, bundle, {});                              // M3 hook (hook.js)
    const main = this.m.animfiles[this.m.composition.main];
    this.anims = Object.keys(main.anims);
    this.state = { logic: defaultLogic(this.m), anim: this.anims.includes('Idle') ? 'Idle' : this.anims[0], variant: 0,
      sync: 'absolute', method: 'bspline', t: 0, playing: true, speed: 1, loop: true, bones: false, grid: true,
      cam: 'game', yaw: 35, pitch: GAME_PITCH, fov: DEFAULT_FOV, zoom: 1 };
    this.buildUI();
    this.rebuild();
    this.last = performance.now();
    requestAnimationFrame((ts) => this.frame(ts));
  }

  rebuild() {
    const s = this.state;
    this.rig = new Rig(this.bundle, { anim: s.anim, variant: s.variant, logic: s.logic, sync: s.sync, method: s.method });
    this.rig.pose(0);
    this.bounds = boundsOf(this.rig, this.bundle.view);
    s.t = Math.min(s.t, this.rig.duration);
    this.fillVariants();
    this.drawTicks();
    this.showNotes();
  }

  buildUI() {
    const s = this.state, m = this.m;
    $('subject').textContent = (m.subject.proto || '') + '  ' + m.subject.animfile;
    $('bundleid').textContent = 'bundle ' + m.bundle_id + ', ' + m.created;
    const logicBox = $('logic');
    for (const [type, states] of Object.entries(m.logic.types || {})) {
      const sel = el('select', { 'data-logic': type });
      for (const st of states) sel.append(el('option', { value: st }, st));
      sel.value = s.logic[type];
      sel.onchange = () => { s.logic[type] = sel.value; this.rebuild(); };
      const lab = el('label', {}, type + ' ');
      lab.append(sel);
      logicBox.append(lab);
    }
    const animSel = $('anim');
    const pairing = (m.composition && m.composition.pairing) || {};
    const oneSided = new Set((pairing.one_sided || []).map((o) => o.anim));
    for (const a of this.anims) animSel.append(el('option', { value: a }, a + (oneSided.has(a) ? ' (horse only)' : '')));
    animSel.value = s.anim;
    animSel.onchange = () => { s.anim = animSel.value; s.variant = 0; s.t = 0; this.rebuild(); };
    $('variant').onchange = () => { s.variant = +$('variant').value; s.t = 0; this.rebuild(); };
    const sync = $('sync');
    for (const k of SYNC_MODES) sync.append(el('option', { value: k }, k === 'absolute' ? 'absolute time' : 'normalised phase'));
    sync.onchange = () => { s.sync = sync.value; this.rebuild(); };
    $('method').onchange = () => { s.method = $('method').value; this.rebuild(); };
    $('play').onclick = () => { s.playing = !s.playing; this.updateButtons(); };
    $('prev').onclick = () => this.stepKey(-1);
    $('next').onclick = () => this.stepKey(1);
    $('speed').onchange = () => { s.speed = +$('speed').value; };
    $('loop').onchange = () => { s.loop = $('loop').checked; };
    $('bones').onchange = () => { s.bones = $('bones').checked; };
    $('grid').onchange = () => { s.grid = $('grid').checked; };
    $('cam').onchange = () => { s.cam = $('cam').value; if (s.cam === 'game') s.pitch = GAME_PITCH; };
    $('fov').oninput = () => { s.fov = +$('fov').value; $('fovval').textContent = s.fov; };
    $('fovval').textContent = s.fov;
    $('export').onclick = () => this.exportPng();
    $('reset').onclick = () => { s.yaw = 35; s.pitch = GAME_PITCH; s.zoom = 1; s.fov = DEFAULT_FOV; $('fov').value = s.fov; };
    const pcs = (m.lighting && m.lighting.player_colors) || [];
    const pcSel = $('pc');
    for (const p of pcs) pcSel.append(el('option', { value: p.index }, 'player ' + p.index));
    pcSel.value = this.ren.playerIndex;
    pcSel.onchange = () => this.ren.setPlayerColour(+pcSel.value);
    const scrub = $('scrub');
    scrub.oninput = () => { s.playing = false; s.t = (+scrub.value / 10000) * this.rig.duration; this.updateButtons(); };
    // camera drag and wheel
    let drag = null;
    this.canvas.addEventListener('pointerdown', (e) => { drag = { x: e.clientX, y: e.clientY, yaw: s.yaw, pitch: s.pitch };
      this.canvas.setPointerCapture(e.pointerId); });
    this.canvas.addEventListener('pointermove', (e) => {
      if (!drag) return;
      s.yaw = drag.yaw - (e.clientX - drag.x) * 0.4;
      if (s.cam === 'free') s.pitch = Math.max(-5, Math.min(89, drag.pitch + (e.clientY - drag.y) * 0.3));
    });
    this.canvas.addEventListener('pointerup', () => { drag = null; });
    this.canvas.addEventListener('wheel', (e) => { e.preventDefault(); s.zoom *= Math.exp(e.deltaY * 0.001); }, { passive: false });
    window.addEventListener('keydown', (e) => {
      if (e.target && e.target.tagName === 'INPUT' && e.target.type === 'text') return;
      if (e.key === ' ') { s.playing = !s.playing; this.updateButtons(); e.preventDefault(); }
      if (e.key === 'ArrowLeft') this.stepKey(-1);
      if (e.key === 'ArrowRight') this.stepKey(1);
    });
    // fidelity and warnings
    const fid = m.fidelity || {};
    $('badge').textContent = Object.entries(fid.stages || {}).map(([k, v]) => v).join('');
    const table = $('fidelity');
    for (const [k, v] of Object.entries(fid.stages || {})) {
      const tr = el('tr');
      tr.append(el('td', { class: 'f-' + v }, v), el('td', {}, k), el('td', { class: 'note' }, (fid.notes || {})[k] || ''));
      table.append(tr);
    }
    $('wcount').textContent = String((m.warnings || []).length);
    const ul = $('warnings');
    for (const w of m.warnings || []) {
      const li = el('li');
      li.append(el('b', {}, w.code), document.createTextNode(' ' + (w.path || '') + ': ' + w.message));
      ul.append(li);
    }
    // unit search (server API, token-protected)
    $('unitgo').onclick = () => this.searchUnits();
    $('unitq').addEventListener('keydown', (e) => { if (e.key === 'Enter') this.searchUnits(); });
    $('unitbuild').onclick = () => this.buildUnit();
    this.updateButtons();
  }

  async searchUnits() {
    const q = $('unitq').value.trim();
    const box = $('unitlist');
    box.innerHTML = '';
    try {
      const r = await apiGet('/api/units?q=' + encodeURIComponent(q));
      for (const u of r.units) box.append(el('option', { value: u.name }, u.name));
      $('unitmsg').textContent = r.units.length + ' match(es)' + (r.truncated ? ' (first ' + r.units.length + ')' : '');
    } catch (e) { $('unitmsg').textContent = String(e.message || e); }
  }

  async buildUnit() {
    const name = $('unitlist').value || $('unitq').value.trim();
    if (!name) return;
    $('unitmsg').textContent = 'building ' + name + '...';
    try {
      const r = await postJSON('/api/build', { proto: name });
      if (!r.ok) throw new Error(r.error || 'build failed');
      const u = new URL(location.href);
      u.searchParams.set('bundle', r.bundle_id);
      location.href = u.toString();
    } catch (e) { $('unitmsg').textContent = String(e.message || e); }
  }

  // the current frame as a PNG into the server's output folder (never a repository: server.py / av_common)
  async exportPng() {
    const s = this.state;
    const name = [this.m.subject.proto || 'unit', s.anim, 'v' + s.variant, 't' + s.t.toFixed(3).replace('.', 'p')]
      .join('_').replace(/[^A-Za-z0-9_-]+/g, '_') + '.png';
    try {
      const blob = await canvasPng(this.canvas);
      const r = await fetch('/api/export?name=' + encodeURIComponent(name), { method: 'POST',
        headers: { 'X-AV-Token': TOKEN, 'Content-Type': 'image/png' }, body: blob });
      const j = await r.json();
      $('exportmsg').textContent = r.ok ? 'saved ' + j.name + ' in the server output folder' : 'export refused: ' + j.error;
    } catch (e) { $('exportmsg').textContent = String(e.message || e); }
  }

  // headless check of the interactive page (?test=1&selftest=1): drive the controls as a user would, then post the
  // state, a PNG and the export result. No window: headless.py runs it.
  async selfTest() {
    const frames = (n) => new Promise((res) => { let k = 0; const f = () => (++k >= n ? res() : requestAnimationFrame(f)); requestAnimationFrame(f); });
    const pick = (id, value) => { const e = $(id); e.value = String(value); e.dispatchEvent(new Event('change')); };
    const steps = [];
    await frames(5);
    const t0 = this.state.t;
    await frames(20);
    steps.push({ step: 'playing', advanced: this.state.t !== t0, t: this.state.t });
    pick('anim', 'Attack_melee');
    pick('variant', 1);
    $('play').click();                                 // pause
    for (let i = 0; i < 3; i++) $('next').click();
    await frames(3);
    const c = this.rig.mainClip;
    steps.push({ step: 'attack v1 +3 keys', anim: this.rig.anim, variant: this.rig.variant, key: c.keyAt(this.state.t),
      t: this.state.t, playing: this.state.playing });
    $('bones').checked = true; $('bones').dispatchEvent(new Event('change'));
    pick('sync', 'phase');
    const lp = document.querySelector('select[data-logic="LowPoly"]');
    if (lp && lp.options.length > 1) { lp.value = lp.options[1].value; lp.dispatchEvent(new Event('change')); }
    pick('method', 'knots');
    await frames(3);
    steps.push({ step: 'bones, phase, logic, knots', logic: this.state.logic, sync: this.state.sync,
      method: this.state.method, instances: this.rig.instances.map((x) => [x.role, x.model.id, x.clip && x.clip.id, x.clock]) });
    await postFile('selftest.png', await canvasPng(this.canvas));
    await this.exportPng();
    steps.push({ step: 'export', message: $('exportmsg').textContent });
    await postJSON('/api/done', { status: this.stats && !this.stats.errors.length ? 'ok' : 'gl-errors', steps,
      stats: this.stats, gpu_path: this.gpu.gpuPath, readout: $('readout').textContent,
      textures: this.ren.textureLog, warnings: (this.m.warnings || []).length });
  }

  fillVariants() {
    const s = this.state;
    const sel = $('variant');
    sel.innerHTML = '';
    const main = this.m.animfiles[this.m.composition.main];
    const a = main.anims[this.rig.anim];
    const w = (a && a.weights && a.weights.normalized) || [];
    (a ? a.variants : []).forEach((v, i) => sel.append(el('option', { value: i },
      i + ': ' + base(v.clip) + (w[i] !== undefined ? '  ' + Math.round(w[i] * 100) + '%' : ''))));
    sel.value = String(s.variant);
    $('weights').textContent = a && a.weights ? 'weights: ' + a.weights.rule : '';
  }

  drawTicks() {
    const box = $('ticks');
    box.innerHTML = '';
    for (const inst of this.rig.instances) {
      if (!inst.variantRec || !inst.clip || inst.role === 'attachment') continue;
      for (const tag of inst.variantRec.tags || []) {
        const d = inst.clip.duration;
        const tt = inst.clock === 'phase' ? tag.fraction * this.rig.duration : tag.fraction * d;
        const x = this.rig.duration ? Math.min(tt / this.rig.duration, 1.04) : 0;
        const t = el('span', { class: 'tick ' + inst.role + ' t-' + tag.type.toLowerCase(),
          title: inst.role + ' ' + tag.type + ' @ ' + fmt(tag.fraction, 2) + ' (' + fmt(tt) + ' s) ' + JSON.stringify(tag.attrs) +
            (tag.overflow ? ' OVERFLOW (fraction > 1, meaning unknown)' : '') });
        t.style.left = (x * 100) + '%';
        box.append(t);
      }
    }
  }

  showNotes() {
    const box = $('notes');
    box.innerHTML = '';
    for (const inst of this.rig.instances) {
      const line = el('div');
      line.append(el('b', {}, inst.role + ' '), document.createTextNode(base(inst.model.id) + '  ' + (inst.anim || '-') +
        (inst.variant >= 0 ? ' v' + inst.variant : '') + '  ' + base(inst.clip && inst.clip.id) +
        (inst.clip ? '  ' + fmt(inst.clip.duration) + ' s @ ' + fmt(inst.clip.fps, 1) + ' fps, ' + inst.clip.keyCount + ' keys' : '')));
      box.append(line);
      for (const n of inst.notes) box.append(el('div', { class: 'note' }, '  ' + n));
    }
    for (const n of this.rig.notes) box.append(el('div', { class: 'note' }, n));
  }

  stepKey(dir) {
    const s = this.state;
    s.playing = false;
    const c = this.rig.mainClip;
    if (!c) return;
    const k = Math.max(0, Math.min(c.keyCount - 1, c.keyAt(s.t) + dir));
    s.t = c.keyTime(k);
    this.updateButtons();
  }

  updateButtons() {
    $('play').textContent = this.state.playing ? 'Pause' : 'Play';
  }

  frame(ts) {
    const s = this.state;
    const dt = Math.min((ts - this.last) / 1000, 0.1);
    this.last = ts;
    const d = this.rig.duration;
    if (s.playing && d > 0) {
      s.t += dt * s.speed;
      if (s.t > d) s.t = s.loop ? s.t % d : d;
    }
    this.resize();
    this.rig.pose(s.t, { method: s.method });
    const aspect = this.canvas.width / this.canvas.height;
    const cam = gameCamera({ bounds: this.bounds, yaw: s.yaw, pitch: s.pitch, fov: s.fov, aspect });
    if (s.zoom !== 1) {
      const c2 = gameCamera({ bounds: this.bounds, yaw: s.yaw, pitch: s.pitch, fov: s.fov, aspect,
        distance: cam.distance * s.zoom });
      this.stats = this.ren.draw(this.rig, c2, { bones: s.bones, grid: s.grid });
    } else {
      this.stats = this.ren.draw(this.rig, cam, { bones: s.bones, grid: s.grid });
    }
    this.readout();
    requestAnimationFrame((t2) => this.frame(t2));
  }

  resize() {
    const c = this.canvas, r = c.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
    const w = Math.max(1, Math.round(r.width * dpr)), h = Math.max(1, Math.round(r.height * dpr));
    if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
  }

  readout() {
    const s = this.state, d = this.rig.duration;
    $('scrub').value = d ? String(Math.round((s.t / d) * 10000)) : '0';
    const parts = ['t ' + fmt(s.t) + ' / ' + fmt(d) + ' s'];
    for (const inst of this.rig.instances) {
      if (!inst.clip || inst.role === 'attachment') continue;
      parts.push(inst.role + ' key ' + inst.clip.keyAt(inst.time) + '/' + (inst.clip.keyCount - 1) + ' @' +
        Math.round(inst.clip.fps) + ' (clip t ' + fmt(inst.time) + ')');
    }
    parts.push(this.gpu.gpuPath + ', ' + this.stats.draws + ' draws, ' + this.stats.triangles + ' tris' +
      (this.stats.errors.length ? ', GL errors ' + this.stats.errors.join(',') : ''));
    $('readout').textContent = parts.join('   ');
  }
}

async function main() {
  installErrorHooks();
  const id = PARAMS.get('bundle');
  let jobText = PARAMS.get('job');
  if (!id) {
    $('status').textContent = 'no bundle: open the URL that `anim_viewer.py serve` prints (it names ?bundle=<id>)';
    if (TEST_MODE) await postJSON('/api/error', { msg: 'no bundle id in the URL' });
    return;
  }
  if (!/^[0-9a-f]{16}$/.test(id)) throw new Error('bad bundle id ' + id);
  $('status').textContent = 'loading bundle ' + id + '...';
  const bundle = await loadBundle('/bundle/' + id + '/');
  $('status').textContent = '';
  if (jobText) {
    document.body.classList.add('job');
    if (jobText === '@server') jobText = JSON.stringify(await apiGet('/api/job'));    // a job too long for the URL
    await runJob(bundle, JSON.parse(jobText), $('view'));
    return;
  }
  window.viewer = new App(bundle);
  // M3 shading panel (viewer/shading/hook.js): its own section; the page badge follows the renderer's fidelity
  try {
    mountShading($('shading'), window.viewer.ren, { onFidelity: (fid) => {
      const st = window.viewer._studio;                                     // M4 owns the badge once it is mounted
      if (st && st.refreshFidelity) st.refreshFidelity(); else if ($('badge')) $('badge').textContent = fid.badge;
    } });
  } catch (e) { reportError(e); }
  // M4 timeline + panels (viewer/timeline/mount.js): mounted on the App, never required by it
  try { (await import('../timeline/mount.js')).mountStudio(window.viewer); } catch (e) { reportError(e); }
  if (TEST_MODE && PARAMS.get('selftest') === '1') await window.viewer.selfTest();
}

main().catch((e) => { $('status').textContent = String(e && e.message ? e.message : e); reportError(e); });
