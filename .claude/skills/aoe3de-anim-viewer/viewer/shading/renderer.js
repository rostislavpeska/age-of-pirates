// M3 game shader renderer (browser-only). Extends the M2 Renderer (lib/render.js: texture uploads, mesh VAOs, grid,
// bones, the placeholder material - still selectable for before/after comparisons) with:
//   1. a sun shadow map (depth only, alpha-tested, both faces) fitted to the unit;
//   2. the fused materialdefault + lightingpass forward pass (glsl.js) into an RGBA16F target (MSAA x4, resolved),
//      single-sided materials culled (front = clockwise on screen, as D3D), double-sided ones flipped by gl_FrontFacing;
//   3. the post pass (tonemap LUT + grade LUT + dither, or the legacy Hable path, or off) onto the canvas.
// Lighting comes from the bundle's own lighting section or a lighting pack (manifest.lighting.presets, built by
// lighting.py build_presets) - setLighting / loadPreset. Fidelity: fidelity() (model.runtimeFidelity).
import { Renderer } from '../lib/render.js';
import { createProgram, drainErrors } from '../lib/gl.js';
import { DISPLAY, lookAt, ortho, mulCM } from '../lib/camera.js';
import { SKIN_GLSL } from '../lib/skin.js';
import { loadBundle } from '../lib/bundle.js';
import * as G from './glsl.js';
import * as M from './model.js';

export const TANGENT_LOC = 5;
export const UNIT = { pal: 0, base: 1, normal: 2, masks: 3, details: 4, env: 5, shadow: 6, hdr: 8, tonemap: 9, grade: 10,
  noise: 11 };
const GL_TYPE = { f32: 'FLOAT', f16: 'HALF_FLOAT', i8: 'BYTE', u8: 'UNSIGNED_BYTE', i16: 'SHORT', u16: 'UNSIGNED_SHORT' };
export const DEBUG_VIEWS = ['lit', 'albedo', 'normal', 'roughness', 'metallic', 'ao', 'shadow', 'facing', 'horizon'];
export const TONEMAPS = ['lut', 'legacy', 'off'];
export const DEFAULTS = { mode: 'game', shadows: true, quant: true, tonemap: 'lut', debug: 'lit', samples: 4,
  shadowSize: 2048, shadowBias: 0.02, shadowSoft: 0.03, seed: 1, frontFace: 'cw', grid: true };

function uniforms(gl, prog, names) {
  const u = {};
  for (const n of names) u[n] = gl.getUniformLocation(prog, n);
  return u;
}

export class GameRenderer extends Renderer {
  constructor(gl, bundle, opts = {}) {
    super(gl, bundle);
    this.ext.cbf = gl.getExtension('EXT_color_buffer_float');
    this.ext.floatLinear = gl.getExtension('OES_texture_float_linear');
    this.opts = Object.assign({}, DEFAULTS, opts || {});
    this.overrides = {};
    this.notes = [];
    this.matCache = new Map();
    this.progMat = createProgram(gl, G.materialVS(SKIN_GLSL), G.MATERIAL_FS);
    this.uMat = uniforms(gl, this.progMat, ['u_viewProj', 'u_display', 'u_pal', 'u_base', 'u_normal', 'u_masks',
      'u_details', 'u_has', 'u_missingBase', 'u_missingNormal', 'u_missingMasks', 'u_cutout', 'u_doubleSided', 'u_rei',
      'u_pc', 'u_eye', 'u_mipBias', 'u_quant', 'u_debug', 'u_shadows', 'u_lightViewProj', 'u_shadowBias',
      'u_shadowSoft', 'u_shadowMap', 'u_sunDir', 'u_sunColor', 'u_shadowColor', 'u_hemiTop', 'u_hemiBottom',
      'u_skyRot', 'u_iblIntensity', 'u_iblNormalize', 'u_exposure', 'u_envMaxMip', 'u_envLodOffset', 'u_env',
      'u_envbrdf']);
    this.progShadow = createProgram(gl, G.shadowVS(SKIN_GLSL), G.SHADOW_FS);
    this.uShadow = uniforms(gl, this.progShadow, ['u_pal', 'u_lightViewProj', 'u_base', 'u_cutout', 'u_cutoutThreshold']);
    this.progPost = createProgram(gl, G.FULLSCREEN_VS, G.POST_FS);
    this.uPost = uniforms(gl, this.progPost, ['u_hdr', 'u_postMode', 'u_background', 'u_tonemapLUT', 'u_gradeLUT',
      'u_noise', 'u_gradeEnabled', 'u_gradeSize', 'u_ditherScale', 'u_legacy', 'u_legacyWhite']);
    this.emptyVao = gl.createVertexArray();
    this.noise = this.texture2D(M.noiseTexture(this.opts.seed), 64, 64, gl.RGBA8, gl.RGBA, gl.UNSIGNED_BYTE, gl.NEAREST,
      gl.REPEAT);
    this.targets = null;
    this.shadow = null;
    this.lightingName = 'bundle';
    this.packs = new Map();
    this.setLighting(bundle.manifest.lighting || {}, bundle, (bundle.manifest.lighting && bundle.manifest.lighting.lgt &&
      bundle.manifest.lighting.lgt.name) || 'bundle');
    this.playerIndex = (bundle.manifest.lighting || {}).player_color_index ?? 1;
    this.ready = true;
    drainErrors(gl);
  }

  // ------------------------------------------------------------------------------------------ options
  set(opts) { Object.assign(this.opts, opts); if ('seed' in opts) this.reseed(opts.seed); }
  setOverrides(o) { this.overrides = Object.assign({}, o); this.refreshUniforms(); }
  reseed(seed) {
    const gl = this.gl;
    gl.deleteTexture(this.noise);
    this.noise = this.texture2D(M.noiseTexture(seed), 64, 64, gl.RGBA8, gl.RGBA, gl.UNSIGNED_BYTE, gl.NEAREST, gl.REPEAT);
  }

  setPlayerColour(index) {
    super.setPlayerColour(index);
    this.playerIndex = index;
  }

  player() {
    const pcs = (this.bundle.manifest.lighting || {}).player_colors || [];
    return pcs.find((p) => p.index === this.playerIndex) || pcs[0] || null;
  }

  texture2D(data, w, h, internal, format, type, filter, wrap) {
    const gl = this.gl;
    const t = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0 + 7);
    gl.bindTexture(gl.TEXTURE_2D, t);
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    gl.texImage2D(gl.TEXTURE_2D, 0, internal, w, h, 0, format, type, data);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, wrap);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, wrap);
    return t;
  }

  texture3D(data, n, filterLinear = true) {
    const gl = this.gl;
    const t = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0 + 7);
    gl.bindTexture(gl.TEXTURE_3D, t);
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    const internal = this.ext.floatLinear ? gl.RGBA32F : gl.RGBA16F;     // RGBA16F accepts FLOAT data and filters
    gl.texImage3D(gl.TEXTURE_3D, 0, internal, n, n, n, 0, gl.RGBA, gl.FLOAT, data);
    const f = filterLinear ? gl.LINEAR : gl.NEAREST;
    gl.texParameteri(gl.TEXTURE_3D, gl.TEXTURE_MIN_FILTER, f);
    gl.texParameteri(gl.TEXTURE_3D, gl.TEXTURE_MAG_FILTER, f);
    for (const w of [gl.TEXTURE_WRAP_S, gl.TEXTURE_WRAP_T, gl.TEXTURE_WRAP_R]) gl.texParameteri(gl.TEXTURE_3D, w, gl.CLAMP_TO_EDGE);
    return t;
  }

  // ------------------------------------------------------------------------------------------ lighting
  // section: a manifest.lighting; src: {view} of the bundle or pack holding its buffers
  setLighting(section, src, name, from = 'bundle') {
    const gl = this.gl;
    this.lightingFrom = from;                       // 'bundle' or the lighting pack's bundle id
    for (const k of ['env', 'tonemapLUT', 'gradeLUT']) if (this[k]) gl.deleteTexture(this[k]);
    this.section = section || {};
    this.lightingName = name || 'bundle';
    this.lightNotes = [];
    // environment cube: the kept refl levels, faces in file order (+X -X +Y -Y +Z -Z: a guess), rows as stored
    const refl = this.section.refl;
    this.env = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0 + 7);
    gl.bindTexture(gl.TEXTURE_CUBE_MAP, this.env);
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    if (refl && refl.decodable && refl.mips && refl.mips.length) {
      refl.mips.forEach((mip, i) => {
        const all = src.view(mip.view);
        const per = mip.size * mip.size * 4;
        for (let f = 0; f < 6; f++) {
          const face = all.subarray(f * per, (f + 1) * per);
          gl.texImage2D(gl.TEXTURE_CUBE_MAP_POSITIVE_X + f, i, gl.RGBA16F, mip.size, mip.size, 0, gl.RGBA,
            mip.view.dtype === 'f16' ? gl.HALF_FLOAT : gl.FLOAT, face);
        }
      });
      gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAX_LEVEL, refl.mips.length - 1);
      gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
      if (refl.levels_skipped && refl.levels_skipped.length) {
        this.lightNotes.push('reflection cube: file levels ' + refl.levels_skipped.join(', ') + ' are not in this bundle ' +
          '(sharper reflections clamp to level ' + refl.mips[0].level + '); a lighting pack keeps every level');
      }
    } else {
      for (let f = 0; f < 6; f++) {
        gl.texImage2D(gl.TEXTURE_CUBE_MAP_POSITIVE_X + f, 0, gl.RGBA16F, 1, 1, 0, gl.RGBA, gl.FLOAT,
          new Float32Array([1, 1, 1, 1]));
      }
      gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAX_LEVEL, 0);
      gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
      this.lightNotes.push('no reflection cube: a white 1x1 stand-in');
    }
    gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    for (const w of [gl.TEXTURE_WRAP_S, gl.TEXTURE_WRAP_T]) gl.texParameteri(gl.TEXTURE_CUBE_MAP, w, gl.CLAMP_TO_EDGE);
    // LUTs
    const tl = this.section.tonemap_lut;
    this.hasTonemapLUT = !!(tl && tl.view);
    this.tonemapLUT = this.hasTonemapLUT ? this.texture3D(src.view(tl.view), tl.size) :
      this.texture3D(new Float32Array([0, 0, 0, 1]), 1);
    if (!this.hasTonemapLUT) this.lightNotes.push('no tonemap LUT in this lighting: the LUT path falls back to off');
    const gr = this.section.grade_lut;
    this.hasGradeLUT = !!(gr && gr.view);
    this.gradeSize = this.hasGradeLUT ? gr.size : 1;
    this.gradeLUT = this.hasGradeLUT ? this.texture3D(src.view(gr.view), gr.size) :
      this.texture3D(new Float32Array([0, 0, 0, 1]), 1);
    this.envbrdf = M.envbrdfPairs(this.section);
    if (!this.envbrdf) {
      this.lightNotes.push('no EnvBRDF table in this bundle (built before M3): specular IBL uses scale 1, bias 0');
      this.envbrdf = new Float32Array(128).map((_, i) => (i % 2 ? 0 : 1));
    }
    this.refreshUniforms();
    drainErrors(gl);
  }

  // the LightingConstants of the current lighting (+ page overrides). NOT `this.lu`: the M2 Renderer keeps the line
  // program's uniform locations there (grid, bones)
  refreshUniforms() {
    this.light = M.lightingUniforms(this.section, this.overrides);
  }

  presets() {
    const own = this.bundle.manifest.lighting || {};
    const list = [{ name: (own.lgt && own.lgt.name) || 'bundle', source: 'bundle', bundle_id: null, status: 'ok' }];
    for (const p of own.presets || []) {
      const same = list.find((x) => x.name === p.name);
      if (same) {
        if (p.status === 'ok' && p.bundle_id) same.bundle_id = p.bundle_id;   // the pack has the full cube: prefer it
        continue;
      }
      if (p.status === 'ok' && p.bundle_id) {
        list.push({ name: p.name, source: 'pack', bundle_id: p.bundle_id, status: p.status, title: p.title });
      }
    }
    return list;
  }

  // switch to a lgt by name: its lighting pack when the bundle lists one, else the bundle's own lighting
  async loadPreset(name, fetchFn) {
    const p = this.presets().find((x) => x.name === name);
    if (!p) throw new Error('no lighting preset ' + name + ' (presets: ' + this.presets().map((x) => x.name).join(', ') + ')');
    if ((p.bundle_id || 'bundle') === this.lightingFrom && name === this.lightingName) return p;   // already drawn
    if (!p.bundle_id) { this.setLighting(this.bundle.manifest.lighting || {}, this.bundle, name, 'bundle'); return p; }
    let pack = this.packs.get(p.bundle_id);
    if (!pack) {
      pack = await loadBundle('/bundle/' + p.bundle_id + '/', fetchFn);
      this.packs.set(p.bundle_id, pack);
    }
    this.setLighting(pack.manifest.lighting, pack, name, p.bundle_id);
    this.packFidelity = pack.manifest.fidelity;
    return p;
  }

  // ------------------------------------------------------------------------------------------ targets
  ensureTargets(w, h) {
    const gl = this.gl;
    const samples = Math.min(this.opts.samples | 0, gl.getParameter(gl.MAX_SAMPLES) | 0);
    const t = this.targets;
    if (t && t.w === w && t.h === h && t.samples === samples) return t;
    if (t) {
      for (const k of ['msFbo', 'fbo']) if (t[k]) gl.deleteFramebuffer(t[k]);
      for (const k of ['msColor', 'msDepth', 'depth']) if (t[k]) gl.deleteRenderbuffer(t[k]);
      if (t.color) gl.deleteTexture(t.color);
    }
    const n = { w, h, samples };
    n.color = this.texture2D(null, w, h, gl.RGBA16F, gl.RGBA, gl.HALF_FLOAT, gl.NEAREST, gl.CLAMP_TO_EDGE);
    n.fbo = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, n.fbo);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, n.color, 0);
    n.depth = gl.createRenderbuffer();
    gl.bindRenderbuffer(gl.RENDERBUFFER, n.depth);
    gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT24, w, h);
    gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, n.depth);
    n.status = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
    if (samples > 1) {
      n.msFbo = gl.createFramebuffer();
      gl.bindFramebuffer(gl.FRAMEBUFFER, n.msFbo);
      n.msColor = gl.createRenderbuffer();
      gl.bindRenderbuffer(gl.RENDERBUFFER, n.msColor);
      gl.renderbufferStorageMultisample(gl.RENDERBUFFER, samples, gl.RGBA16F, w, h);
      gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.RENDERBUFFER, n.msColor);
      n.msDepth = gl.createRenderbuffer();
      gl.bindRenderbuffer(gl.RENDERBUFFER, n.msDepth);
      gl.renderbufferStorageMultisample(gl.RENDERBUFFER, samples, gl.DEPTH_COMPONENT24, w, h);
      gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, n.msDepth);
      if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE) {
        gl.deleteFramebuffer(n.msFbo);
        n.msFbo = null;
        n.samples = 0;
        this.notes.push('multisampled RGBA16F target unavailable: no MSAA');
      }
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    this.targets = n;
    return n;
  }

  ensureShadow(size) {
    const gl = this.gl;
    if (this.shadow && this.shadow.size === size) return this.shadow;
    if (this.shadow) { gl.deleteTexture(this.shadow.tex); gl.deleteFramebuffer(this.shadow.fbo); }
    const tex = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0 + 7);
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texStorage2D(gl.TEXTURE_2D, 1, gl.DEPTH_COMPONENT32F, size, size);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    const fbo = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, tex, 0);
    gl.drawBuffers([gl.NONE]);
    gl.readBuffer(gl.NONE);
    const status = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    this.shadow = { size, tex, fbo, status };
    return this.shadow;
  }

  // engine-frame sphere around the posed bones (plus a margin for the skin beyond the bones)
  shadowSphere(rig, bounds) {
    let lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
    if (bounds) { lo = bounds.min.slice(); hi = bounds.max.slice(); } else {
      for (const inst of rig.instances) {
        if (!inst.worlds) continue;
        for (let i = 0; i < inst.model.boneCount; i++) {
          for (let k = 0; k < 3; k++) {
            const v = inst.worlds[i * 16 + 12 + k];
            lo[k] = Math.min(lo[k], v); hi[k] = Math.max(hi[k], v);
          }
        }
      }
    }
    if (!Number.isFinite(lo[0])) { lo = [-1, 0, -1]; hi = [1, 2, 1]; }
    const c = [0, 1, 2].map((k) => (lo[k] + hi[k]) / 2);
    const r = 0.5 * Math.hypot(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]) + (bounds ? 0.15 : 1.0);
    return { c, r };
  }

  lightViewProj(sphere) {
    const toward = this.light.sunDir.map((x) => -x);
    const { c, r } = sphere;
    const eye = [c[0] + toward[0] * 2 * r, c[1] + toward[1] * 2 * r, c[2] + toward[2] * 2 * r];
    const view = lookAt(eye, c, [0, 1, 0]);
    const proj = ortho(-r, r, -r, r, 0.0, 4 * r);
    return { viewProj: mulCM(proj, view), depthRange: 4 * r };
  }

  // the M2 grid, its grey levels decoded to linear radiance: drawn into the HDR target it reads as in M2 after the post
  drawGrid(cam, size) {
    if (this.opts.mode === 'placeholder') return super.drawGrid(cam, size);
    const v = [];
    for (let i = -size; i <= size; i++) {
      const c = (i === 0 ? [0.42, 0.44, 0.48] : [0.26, 0.27, 0.3]).map(M.srgbToLinear);
      v.push(i, 0, -size, ...c, i, 0, size, ...c, -size, 0, i, ...c, size, 0, i, ...c);
    }
    return this.drawLines(v, cam, this.gl.LINES, true);
  }

  // ------------------------------------------------------------------------------------------ material cache
  matParams(id) {
    if (!this.matCache.has(id)) this.matCache.set(id, M.materialParams(this.materialOf(id)));
    return this.matCache.get(id);
  }

  bindTangent(m, meshRec) {
    const gl = this.gl;
    if (m.tangentBound === undefined) {
      const s = meshRec.streams && meshRec.streams.Tangent;
      gl.bindVertexArray(m.vao);
      if (s && s.view && GL_TYPE[s.view.dtype]) {
        gl.bindBuffer(gl.ARRAY_BUFFER, this.arrayBuffer(s.view.buffer));
        gl.enableVertexAttribArray(TANGENT_LOC);
        gl.vertexAttribPointer(TANGENT_LOC, Math.min(s.view.components, 4), gl[GL_TYPE[s.view.dtype]], !!s.view.normalized,
          0, s.view.byteOffset);
        m.tangentBound = true;
      } else {
        gl.disableVertexAttribArray(TANGENT_LOC);
        m.tangentBound = false;
      }
      gl.bindVertexArray(null);
    }
    if (!m.tangentBound) gl.vertexAttrib4f(TANGENT_LOC, 1, 0, 0, 1);     // generic value: shared state, set per draw
  }

  // ------------------------------------------------------------------------------------------ drawing
  // opts: {background, bones, grid, gridSize, hidden: Set, bounds (engine frame, for the shadow fit)}
  draw(rig, cam, opts = {}) {
    if (this.opts.mode === 'placeholder' || !this.ready) {
      const s = super.draw(rig, cam, opts);
      s.renderer = 'placeholder';
      return s;
    }
    const gl = this.gl;
    const W = gl.drawingBufferWidth, H = gl.drawingBufferHeight;
    const t = this.ensureTargets(W, H);
    const lu = this.light;
    const stats = { draws: 0, triangles: 0, untextured: 0, renderer: 'game', lighting: this.lightingName,
      samples: t.samples, shadow: null };
    const visible = rig.instances.filter((inst) => inst.worlds && inst.model.decodable &&
      !(opts.hidden && opts.hidden.has(inst.index)));
    // 1. shadow map
    let light = null;
    if (this.opts.shadows && this.opts.debug !== 'facing') {
      const sh = this.ensureShadow(this.opts.shadowSize);
      light = this.lightViewProj(this.shadowSphere(rig, opts.bounds));
      gl.bindFramebuffer(gl.FRAMEBUFFER, sh.fbo);
      gl.viewport(0, 0, sh.size, sh.size);
      gl.clearDepth(1);
      gl.clear(gl.DEPTH_BUFFER_BIT);
      gl.enable(gl.DEPTH_TEST);
      gl.depthFunc(gl.LESS);
      gl.disable(gl.CULL_FACE);
      gl.enable(gl.POLYGON_OFFSET_FILL);
      gl.polygonOffset(1.5, 2.0);
      gl.useProgram(this.progShadow);
      gl.uniformMatrix4fv(this.uShadow.u_lightViewProj, false, light.viewProj);
      gl.uniform1i(this.uShadow.u_pal, UNIT.pal);
      gl.uniform1i(this.uShadow.u_base, UNIT.base);
      this.eachGroup(visible, (m, meshRec, g, mat, mp) => {
        const base = this.slotTexture(mat, 'BaseColor');
        gl.activeTexture(gl.TEXTURE0 + UNIT.base);
        gl.bindTexture(gl.TEXTURE_2D, base ? base.tex : null);
        gl.uniform1i(this.uShadow.u_cutout, mp.cutout && base ? 1 : 0);
        gl.uniform1f(this.uShadow.u_cutoutThreshold, mp.values.cutoutThreshold);
        m.drawGroup(g);
      });
      gl.disable(gl.POLYGON_OFFSET_FILL);
      stats.shadow = { size: sh.size, depth_range_m: light.depthRange, bias_m: this.opts.shadowBias,
        soft_m: this.opts.shadowSoft };
    }
    // 2. HDR pass
    gl.bindFramebuffer(gl.FRAMEBUFFER, t.msFbo || t.fbo);
    gl.viewport(0, 0, W, H);
    gl.clearColor(0, 0, 0, 0);
    gl.clearDepth(1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.enable(gl.DEPTH_TEST);
    gl.depthFunc(gl.LESS);
    if (opts.grid !== false && this.opts.grid !== false) this.drawGrid(cam, opts.gridSize || 6);
    gl.useProgram(this.progMat);
    const u = this.uMat;
    gl.uniformMatrix4fv(u.u_viewProj, false, cam.viewProj);
    gl.uniformMatrix4fv(u.u_display, false, DISPLAY);
    gl.uniform1i(u.u_pal, UNIT.pal);
    gl.uniform1i(u.u_base, UNIT.base);
    gl.uniform1i(u.u_normal, UNIT.normal);
    gl.uniform1i(u.u_masks, UNIT.masks);
    gl.uniform1i(u.u_details, UNIT.details);
    gl.uniform1i(u.u_env, UNIT.env);
    gl.uniform1i(u.u_shadowMap, UNIT.shadow);
    gl.uniform3fv(u.u_eye, [-cam.eye[0], cam.eye[1], cam.eye[2]]);           // display -> engine frame
    gl.uniform1f(u.u_mipBias, lu.mipBias);
    gl.uniform1i(u.u_quant, this.opts.quant ? 1 : 0);
    gl.uniform1i(u.u_debug, Math.max(0, DEBUG_VIEWS.indexOf(this.opts.debug)));
    gl.uniform1i(u.u_shadows, light ? 1 : 0);
    if (light) {
      gl.uniformMatrix4fv(u.u_lightViewProj, false, light.viewProj);
      gl.uniform1f(u.u_shadowBias, this.opts.shadowBias / light.depthRange);
      gl.uniform1f(u.u_shadowSoft, light.depthRange / this.opts.shadowSoft);
    }
    gl.uniform3fv(u.u_sunDir, lu.sunDir);
    gl.uniform3fv(u.u_sunColor, lu.sunColor);
    gl.uniform3fv(u.u_shadowColor, lu.shadowColor);
    gl.uniform3fv(u.u_hemiTop, lu.hemiTop);
    gl.uniform3fv(u.u_hemiBottom, lu.hemiBottom);
    gl.uniform2f(u.u_skyRot, lu.rotSin, lu.rotCos);
    gl.uniform1f(u.u_iblIntensity, lu.intensity);
    gl.uniform1f(u.u_iblNormalize, lu.normalize);
    gl.uniform1f(u.u_exposure, lu.exposure);
    gl.uniform1f(u.u_envMaxMip, lu.envMaxMip);
    gl.uniform1f(u.u_envLodOffset, lu.envLodOffset);
    gl.uniform2fv(u.u_envbrdf, this.envbrdf);
    gl.uniform4fv(u.u_missingBase, M.MISSING_SLOT.BaseColor);
    gl.uniform4fv(u.u_missingNormal, M.MISSING_SLOT.Normals);
    gl.uniform4fv(u.u_missingMasks, M.MISSING_SLOT.Masks);
    gl.activeTexture(gl.TEXTURE0 + UNIT.env);
    gl.bindTexture(gl.TEXTURE_CUBE_MAP, this.env);
    gl.activeTexture(gl.TEXTURE0 + UNIT.shadow);
    gl.bindTexture(gl.TEXTURE_2D, light ? this.shadow.tex : null);
    gl.frontFace(this.opts.frontFace === 'ccw' ? gl.CCW : gl.CW);
    gl.cullFace(gl.BACK);
    const player = this.player();
    this.eachGroup(visible, (m, meshRec, g, mat, mp) => {
      const tex = ['BaseColor', 'Normals', 'Masks', 'Details'].map((s) => this.slotTexture(mat, s));
      tex.forEach((x, i) => { gl.activeTexture(gl.TEXTURE0 + UNIT.base + i); gl.bindTexture(gl.TEXTURE_2D, x ? x.tex : null); });
      gl.uniform4i(u.u_has, ...tex.map((x) => (x ? 1 : 0)));
      gl.uniform4fv(u.u_rei, mp.rei);
      gl.uniform3fv(u.u_pc, M.playerColour(player, mp.values.playerColorIndex));
      gl.uniform1i(u.u_cutout, mp.cutout ? 1 : 0);
      gl.uniform1i(u.u_doubleSided, mp.doubleSided ? 1 : 0);
      if (mp.doubleSided || this.opts.debug === 'facing') gl.disable(gl.CULL_FACE); else gl.enable(gl.CULL_FACE);
      if (!tex[0]) stats.untextured++;
      m.drawGroup(g);
      stats.draws++;
      stats.triangles += g.triangle_count;
    });
    gl.disable(gl.CULL_FACE);
    gl.bindVertexArray(null);
    // 3. resolve
    if (t.msFbo) {
      gl.bindFramebuffer(gl.READ_FRAMEBUFFER, t.msFbo);
      gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, t.fbo);
      gl.blitFramebuffer(0, 0, W, H, 0, 0, W, H, gl.COLOR_BUFFER_BIT, gl.NEAREST);
      gl.bindFramebuffer(gl.READ_FRAMEBUFFER, null);
      gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, null);
    }
    // 4. post onto the canvas
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.viewport(0, 0, W, H);
    gl.disable(gl.DEPTH_TEST);
    gl.useProgram(this.progPost);
    const p = this.uPost;
    let mode = Math.max(0, TONEMAPS.indexOf(this.opts.tonemap));
    if (mode === 0 && !this.hasTonemapLUT) mode = 2;
    if (this.opts.debug !== 'lit') mode = 2;
    stats.post = TONEMAPS[mode];
    gl.uniform1i(p.u_postMode, mode);
    const bg = opts.background || [0.16, 0.17, 0.19, 1];
    gl.uniform4fv(p.u_background, bg);
    gl.uniform1i(p.u_hdr, UNIT.hdr);
    gl.uniform1i(p.u_tonemapLUT, UNIT.tonemap);
    gl.uniform1i(p.u_gradeLUT, UNIT.grade);
    gl.uniform1i(p.u_noise, UNIT.noise);
    gl.uniform1f(p.u_gradeEnabled, this.hasGradeLUT ? lu.gradeEnabled : 0);
    gl.uniform1f(p.u_gradeSize, this.gradeSize);
    gl.uniform1f(p.u_ditherScale, lu.ditherScale);
    gl.uniform4f(p.u_legacy, lu.legacy.exposure, lu.legacy.luminance_based, lu.legacy.influence, lu.legacy.noise);
    gl.uniform1f(p.u_legacyWhite, lu.legacy.white_point);
    const bind = (unit, target, tex) => { gl.activeTexture(gl.TEXTURE0 + unit); gl.bindTexture(target, tex); };
    bind(UNIT.hdr, gl.TEXTURE_2D, t.color);
    bind(UNIT.tonemap, gl.TEXTURE_3D, this.tonemapLUT);
    bind(UNIT.grade, gl.TEXTURE_3D, this.gradeLUT);
    bind(UNIT.noise, gl.TEXTURE_2D, this.noise);
    gl.bindVertexArray(this.emptyVao);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    gl.bindVertexArray(null);
    bind(UNIT.hdr, gl.TEXTURE_2D, null);                    // the HDR texture is a render target next frame
    gl.enable(gl.DEPTH_TEST);
    if (opts.bones) this.drawBones(rig, cam);
    stats.errors = drainErrors(gl);
    this.lastStats = stats;
    return stats;
  }

  // calls fn(meshSkin, meshRec, group, material, materialParams) for every drawable group, palette and VAO bound
  eachGroup(instances, fn) {
    const gl = this.gl;
    for (const inst of instances) {
      inst.model.meshes.forEach((meshRec, mi) => {
        const m = this.mesh(inst.model, mi);
        m.updatePalette(inst);
        gl.activeTexture(gl.TEXTURE0 + UNIT.pal);
        gl.bindTexture(gl.TEXTURE_2D, m.palette);
        this.bindTangent(m, meshRec);
        gl.bindVertexArray(m.vao);
        for (const g of meshRec.groups) {
          const mat = this.materialOf(g.material);
          fn(m, meshRec, g, mat, this.matParams(g.material));
        }
      });
    }
    gl.bindVertexArray(null);
  }

  // the resolved HDR image of the last draw as RGBA float (rows bottom-up, GL order)
  readHdr() {
    const gl = this.gl, t = this.targets;
    if (!t) return null;
    const out = new Float32Array(t.w * t.h * 4);
    gl.bindFramebuffer(gl.FRAMEBUFFER, t.fbo);
    gl.readPixels(0, 0, t.w, t.h, gl.RGBA, gl.FLOAT, out);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    return out;
  }

  fidelity() {
    const base = this.bundle.manifest.fidelity || {};
    const fid = M.runtimeFidelity(base, { renderer: this.opts.mode, shadows: this.opts.shadows, tonemap: this.opts.tonemap,
      debug: this.opts.debug !== 'lit' ? this.opts.debug : null,
      overridden: Object.keys(this.overrides).some((k) => this.overrides[k] !== undefined) });
    fid.lighting = this.lightingName;
    fid.notes_runtime = [...this.lightNotes, ...this.light.notes, ...this.notes];
    return fid;
  }

  // a JSON-able summary of what this renderer draws with (job reports, the panel)
  describe() {
    return { mode: this.opts.mode, lighting: this.lightingName, options: Object.assign({}, this.opts),
      overrides: Object.assign({}, this.overrides), player_index: this.playerIndex,
      uniforms: { sunDir: this.light.sunDir, sunAzEl: this.light.sunAzEl, sunColor: this.light.sunColor,
        shadowColor: this.light.shadowColor, hemiTop: this.light.hemiTop, hemiBottom: this.light.hemiBottom,
        intensity: this.light.intensity, normalize: this.light.normalize, exposure: this.light.exposure,
        mipBias: this.light.mipBias, envMaxMip: this.light.envMaxMip, envLodOffset: this.light.envLodOffset,
        gradeEnabled: this.hasGradeLUT ? this.light.gradeEnabled : 0, whitePoint: this.light.whitePoint },
      statuses: this.light.statuses, extensions: { color_buffer_float: !!this.ext.cbf, float_linear: !!this.ext.floatLinear },
      notes: [...this.lightNotes, ...this.light.notes, ...this.notes] };
  }
}
