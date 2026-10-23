// THE HOOK: the only place the viewer page (viewer/app/app.js, viewer/app/index.html) talks to the M3 shading module.
// The page calls exactly these three functions; everything else of the game shader stays inside viewer/shading/.
//
//   import { createRenderer, mountShading, applyShading } from '../shading/hook.js';
//   const ren = createRenderer(gl, bundle, job.shading);   // a GameRenderer, or the M2 Renderer when the shader fails
//   await applyShading(ren, job.shading);                    // job options (below); then per frame:
//   await applyShading(ren, frame.shading);                  // the job options with the frame's on top (not cumulative)
//   mountShading($('shading'), ren, { onFidelity: (f) => ..., onChange: () => ... });   // interactive page only
//
// The renderer keeps the M2 interface: draw(rig, cam, {background, bones, grid, gridSize, hidden, bounds}) -> stats,
// setPlayerColour(index), playerIndex, textureLog, ext. Added: fidelity(), describe(), readHdr(), loadPreset(name),
// set(opts), setOverrides(o).
//
// Shading options (job.shading, or a frame's `shading`, all optional):
//   renderer  'game' (default) | 'placeholder'      lighting  a preset name (manifest.lighting.presets) or the bundle's lgt
//   player    player colour index                   shadows   bool (default true)       quant  bool (default true)
//   tonemap   'lut' (default) | 'legacy' | 'off'    debug     'lit' | 'albedo' | 'normal' | 'roughness' | 'metallic' |
//   samples   MSAA samples (default 4; 0 = none)              'ao' | 'shadow' | 'facing' | 'horizon'
//   seed      dither noise seed (default 1)         overrides {sunAz, sunEl, sunScale, exposure, iblIntensity,
//   shadowSize, shadowBias (m), shadowSoft (m)                 iblNormalize, mipBias, hemiScale,
//   frontFace 'cw' (default, D3D) | 'ccw'                         colourDecode 'srgb' | 'linear'}
// Without `lighting` the bundle's own lgt is drawn, from its lighting pack (every cube level) when the bundle lists one.
import { Renderer } from '../lib/render.js';
import { GameRenderer, DEFAULTS } from './renderer.js';
import { mountShadingPanel, PANEL_CSS } from './panel.js';

const RENDER_KEYS = ['shadows', 'quant', 'tonemap', 'debug', 'samples', 'seed', 'shadowSize', 'shadowBias', 'shadowSoft',
  'frontFace'];

export function createRenderer(gl, bundle, shading = {}) {
  const s = shading || {};
  const opts = { mode: s.renderer === 'placeholder' ? 'placeholder' : 'game' };
  for (const k of RENDER_KEYS) if (s[k] !== undefined) opts[k] = s[k];
  try {
    const r = new GameRenderer(gl, bundle, opts);
    r.baseShading = Object.assign({}, s);          // job-level options: every applyShading starts from them
    return r;
  } catch (e) {                                   // a shader that does not compile must not take the page down
    const r = new Renderer(gl, bundle);
    r.shadingError = String(e && e.message ? e.message : e);
    r.fidelity = () => Object.assign({ badge: Object.values((bundle.manifest.fidelity || {}).stages || {}).join('') },
      bundle.manifest.fidelity || {}, { notes_runtime: ['game shader failed: ' + r.shadingError] });
    r.describe = () => ({ mode: 'placeholder', error: r.shadingError });
    return r;
  }
}

export async function applyShading(ren, shading) {
  if (!(ren instanceof GameRenderer)) return ren && ren.describe ? ren.describe() : null;
  const s = Object.assign({}, ren.baseShading || {}, shading || {});
  const o = { mode: s.renderer === 'placeholder' ? 'placeholder' : 'game' };
  for (const k of RENDER_KEYS) o[k] = s[k] !== undefined ? s[k] : DEFAULTS[k];
  ren.set(o);
  await ren.loadPreset(s.lighting || ren.presets()[0].name);    // a pack (full cube) when the bundle lists one
  if (s.player !== undefined) ren.setPlayerColour(s.player);
  ren.setOverrides(s.overrides || {});
  return ren.describe();
}

export function mountShading(container, ren, opts = {}) {
  if (!container) return null;
  if (!document.getElementById('shading-css')) {
    const st = document.createElement('style');
    st.id = 'shading-css';
    st.textContent = PANEL_CSS;
    document.head.append(st);
  }
  if (!(ren instanceof GameRenderer)) {
    container.textContent = 'Game shader unavailable: ' + (ren.shadingError || 'unknown error') + ' (M2 placeholder drawn)';
    return null;
  }
  const panel = mountShadingPanel(container, ren, opts);
  // the bundle's own lgt carries a reflection cube cut at 128 px: switch to its lighting pack (every level) when listed
  const own = ren.presets().find((p) => p.name === ren.lightingName);
  if (own && own.bundle_id && ren.lightingFrom !== own.bundle_id) {
    ren.loadPreset(own.name).then(() => panel.refresh()).catch(() => null);
  }
  return panel;
}
