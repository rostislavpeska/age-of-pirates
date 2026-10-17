// Pixel-parity page of the M3 game shader (headless only: tests/test_shading_gpu.py runs it through headless.py).
// It loads a synthetic fixture written by the test (a bundle-schema folder, ?bundle=<id>: textures, env cubes, a depth
// map, an HDR image, LUTs, noise and every parameter), runs the glsl.js functions the viewer draws with on three
// kernels and posts float / 8-bit readbacks for tests/shading_ref.py to recompute pixel by pixel:
//   material_<tile>: an analytic sphere per pixel -> materialdefault -> G-buffer round trip -> lightingpass (HDR f32)
//   shadow:          pcf25 on the fixture depth map at dyadic coordinates (f32)
//   post_<mode>:     the post pass (LUT + grade + dither, legacy Hable, off) on the fixture HDR image (f32 and u8)
// No game bytes: the fixture is synthetic.
import { loadBundle } from '../lib/bundle.js';
import { createProgram, drainErrors, rendererInfo, classifyGpuPath } from '../lib/gl.js';
import { postJSON, postFile, log, reportError, installErrorHooks, PARAMS } from '../lib/host.js';
import * as G from './glsl.js';

const $ = (id) => document.getElementById(id);

const MATERIAL_KERNEL = `#version 300 es
precision highp float;
precision highp int;
${G.COMMON}
${G.MATERIAL}
${G.LIGHTING}
uniform highp sampler2D t_base;
uniform highp sampler2D t_lift;
uniform highp sampler2D t_normal;
uniform highp sampler2D t_masks;
uniform highp sampler2D t_details;
uniform ivec2 u_size;
uniform ivec2 u_texSize;
uniform vec3 u_eye;
uniform vec3 u_pcol;
uniform vec4 u_rei[3];
uniform int u_doubleSided;
uniform int u_quant;
out vec4 o;
void main() {
  ivec2 px = ivec2(gl_FragCoord.xy);
  float x = (float(px.x) + 0.5) / float(u_size.x) * 2.0 - 1.0;
  float y = (float(px.y) + 0.5) / float(u_size.y) * 2.0 - 1.0;
  float r2 = x * x + y * y;
  if (r2 > 0.98) { o = vec4(0.0); return; }
  float z = sqrt(1.0 - r2);
  vec3 N = vec3(x, y, z);
  vec3 nv = N * (1.0 + 0.25 * x);
  vec3 tv = vec3(z, 0.0, -x) * 1.1;
  float tw = (((px.x >> 4) + (px.y >> 4)) & 1) == 0 ? 1.0 : -1.0;
  ivec2 tc = ivec2(px.x * u_texSize.x / u_size.x, px.y * u_texSize.y / u_size.y);
  vec3 base = texelFetch(t_base, tc, 0).rgb;
  vec3 lift = texelFetch(t_lift, tc, 0).rgb;
  vec3 nrm = texelFetch(t_normal, tc, 0).rgb;
  vec3 masks = texelFetch(t_masks, tc, 0).rgb;
  float details = texelFetch(t_details, tc, 0).r;
  float s = (u_doubleSided == 1 && x < 0.0) ? -1.0 : 1.0;
  Surface m = materialdefault(base, lift, nrm, masks, details, nv * s, tv * s, tw, u_pcol, u_rei[0], u_rei[1], u_rei[2],
                              N, u_eye);
  Surface g = gbufferRoundTrip(m, u_quant == 1);
  float shadow = (((px.x >> 3) + (px.y >> 3)) & 1) == 0 ? 1.0 : 0.3;
  o = vec4(lightingpass(g, N, u_eye, shadow, 1.0), 1.0);
}`;

const SHADOW_KERNEL = `#version 300 es
precision highp float;
precision highp int;
${G.COMMON}
${G.SHADOW}
uniform float u_bias;
uniform float u_soft;
out vec4 o;
void main() {
  ivec2 px = ivec2(gl_FragCoord.xy);
  vec2 uv = (vec2(px) * 0.0078125 + 0.00390625) * 1.25 - 0.125;
  float z = float((px.x * 7 + px.y * 13) & 63) / 64.0 * 1.125;
  o = vec4(pcf25(uv, z, u_bias, u_soft), uv, z);
}`;

function uniformsOf(gl, prog, names) {
  const u = {};
  for (const n of names) u[n] = gl.getUniformLocation(prog, n);
  return u;
}

function b64(f32) {
  const u8 = new Uint8Array(f32.buffer, f32.byteOffset, f32.byteLength);
  let s = '';
  for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
  return btoa(s);
}

function target(gl, w, h, internal, type) {
  const tex = gl.createTexture();
  gl.activeTexture(gl.TEXTURE0 + 15);               // a unit no kernel samples: never replace an input binding
  gl.bindTexture(gl.TEXTURE_2D, tex);
  gl.texImage2D(gl.TEXTURE_2D, 0, internal, w, h, 0, gl.RGBA, type, null);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  const fbo = gl.createFramebuffer();
  gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
  const ok = gl.checkFramebufferStatus(gl.FRAMEBUFFER) === gl.FRAMEBUFFER_COMPLETE;
  return { tex, fbo, ok, w, h };
}

function tex2D(gl, unit, w, h, internal, format, type, data) {
  const t = gl.createTexture();
  gl.activeTexture(gl.TEXTURE0 + unit);
  gl.bindTexture(gl.TEXTURE_2D, t);
  gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
  gl.texImage2D(gl.TEXTURE_2D, 0, internal, w, h, 0, format, type, data);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
  return t;
}

// env: {levels: [{size, faces: [[r,g,b,a] x 6]}]} constant faces per level
function envCube(gl, unit, env, floatLinear) {
  const t = gl.createTexture();
  gl.activeTexture(gl.TEXTURE0 + unit);
  gl.bindTexture(gl.TEXTURE_CUBE_MAP, t);
  const internal = floatLinear ? gl.RGBA32F : gl.RGBA16F;
  env.levels.forEach((lv, k) => {
    for (let f = 0; f < 6; f++) {
      const px = new Float32Array(lv.size * lv.size * 4);
      for (let i = 0; i < lv.size * lv.size; i++) px.set(lv.faces[f], i * 4);
      gl.texImage2D(gl.TEXTURE_CUBE_MAP_POSITIVE_X + f, k, internal, lv.size, lv.size, 0, gl.RGBA, gl.FLOAT, px);
    }
  });
  gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAX_LEVEL, env.levels.length - 1);
  gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, env.levels.length > 1 ? gl.LINEAR_MIPMAP_LINEAR : gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  return t;
}

function tex3D(gl, unit, n, data, floatLinear) {
  const t = gl.createTexture();
  gl.activeTexture(gl.TEXTURE0 + unit);
  gl.bindTexture(gl.TEXTURE_3D, t);
  gl.texImage3D(gl.TEXTURE_3D, 0, floatLinear ? gl.RGBA32F : gl.RGBA16F, n, n, n, 0, gl.RGBA, gl.FLOAT, data);
  gl.texParameteri(gl.TEXTURE_3D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_3D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  for (const w of [gl.TEXTURE_WRAP_S, gl.TEXTURE_WRAP_T, gl.TEXTURE_WRAP_R]) gl.texParameteri(gl.TEXTURE_3D, w, gl.CLAMP_TO_EDGE);
  return t;
}

async function run() {
  installErrorHooks();
  const id = PARAMS.get('bundle');
  if (!id || !/^[0-9a-f]{16}$/.test(id)) throw new Error('selftest needs ?bundle=<fixture id>');
  const fx = await loadBundle('/bundle/' + id + '/');
  const S = fx.manifest.shading_selftest;
  const canvas = $('view');
  canvas.width = S.size[0];
  canvas.height = S.size[1];
  const gl = canvas.getContext('webgl2', { antialias: false, premultipliedAlpha: false, preserveDrawingBuffer: true });
  if (!gl) throw new Error('no WebGL2');
  const ext = { cbf: !!gl.getExtension('EXT_color_buffer_float'), floatLinear: !!gl.getExtension('OES_texture_float_linear') };
  const info = rendererInfo(gl);
  const W = S.size[0], H = S.size[1];
  const files = [];
  const vao = gl.createVertexArray();
  gl.bindVertexArray(vao);
  const readF32 = (t) => {
    const out = new Float32Array(t.w * t.h * 4);
    gl.bindFramebuffer(gl.FRAMEBUFFER, t.fbo);
    gl.readPixels(0, 0, t.w, t.h, gl.RGBA, gl.FLOAT, out);
    return out;
  };
  const send = async (name, obj) => {
    await postFile(name, new Blob([JSON.stringify(obj)], { type: 'application/json' }));
    files.push(name);
  };

  // ---------------------------------------------------------------- the GPU's own sRGB decode of every byte value
  // (the material kernel's BaseColor goes through it; the reference uses this table, and the test reports how far it
  // is from the exact sRGB formula)
  {
    const bytes = new Uint8Array(256 * 4);
    for (let i = 0; i < 256; i++) bytes.set([i, i, i, i], i * 4);
    tex2D(gl, 12, 256, 1, gl.SRGB8_ALPHA8, gl.RGBA, gl.UNSIGNED_BYTE, bytes);
    const fs = `#version 300 es
precision highp float;
uniform highp sampler2D t;
out vec4 o;
void main() { o = texelFetch(t, ivec2(gl_FragCoord.xy), 0); }`;
    const tp = createProgram(gl, G.FULLSCREEN_VS, fs);
    const tt = target(gl, 256, 1, gl.RGBA32F, gl.FLOAT);
    gl.bindFramebuffer(gl.FRAMEBUFFER, tt.fbo);
    gl.viewport(0, 0, 256, 1);
    gl.useProgram(tp);
    gl.uniform1i(gl.getUniformLocation(tp, 't'), 12);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    await send('srgb_table.json', { w: 256, h: 1, rows: 'bottom-up', data: b64(readF32(tt)) });
  }

  // ---------------------------------------------------------------- material + lighting kernel
  const T = S.textures;
  const units = { t_base: 1, t_lift: 2, t_normal: 3, t_masks: 4, t_details: 5 };
  tex2D(gl, 1, T.size[0], T.size[1], gl.SRGB8_ALPHA8, gl.RGBA, gl.UNSIGNED_BYTE, fx.view(T.base));
  tex2D(gl, 2, T.size[0], T.size[1], gl.SRGB8_ALPHA8, gl.RGBA, gl.UNSIGNED_BYTE, fx.view(T.lift));
  tex2D(gl, 3, T.size[0], T.size[1], gl.RGBA8, gl.RGBA, gl.UNSIGNED_BYTE, fx.view(T.normal));
  tex2D(gl, 4, T.size[0], T.size[1], gl.RGBA8, gl.RGBA, gl.UNSIGNED_BYTE, fx.view(T.masks));
  tex2D(gl, 5, T.size[0], T.size[1], gl.RGBA8, gl.RGBA, gl.UNSIGNED_BYTE, fx.view(T.details));
  const envs = {};
  for (const [name, env] of Object.entries(S.envs)) envs[name] = envCube(gl, 6, env, ext.floatLinear);
  const prog = createProgram(gl, G.FULLSCREEN_VS, MATERIAL_KERNEL);
  const u = uniformsOf(gl, prog, ['t_base', 't_lift', 't_normal', 't_masks', 't_details', 'u_size', 'u_texSize', 'u_eye',
    'u_pcol', 'u_rei', 'u_doubleSided', 'u_quant', 'u_sunDir', 'u_sunColor', 'u_shadowColor', 'u_hemiTop', 'u_hemiBottom',
    'u_skyRot', 'u_iblIntensity', 'u_iblNormalize', 'u_exposure', 'u_envMaxMip', 'u_envLodOffset', 'u_env', 'u_envbrdf']);
  const hdr = target(gl, W, H, gl.RGBA32F, gl.FLOAT);
  for (const tile of S.tiles) {
    const lc = tile.lighting;
    gl.bindFramebuffer(gl.FRAMEBUFFER, hdr.fbo);
    gl.viewport(0, 0, W, H);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.useProgram(prog);
    for (const [k, unit] of Object.entries(units)) gl.uniform1i(u[k], unit);
    gl.uniform1i(u.u_env, 6);
    gl.activeTexture(gl.TEXTURE0 + 6);
    gl.bindTexture(gl.TEXTURE_CUBE_MAP, envs[tile.env]);
    gl.uniform2i(u.u_size, W, H);
    gl.uniform2i(u.u_texSize, T.size[0], T.size[1]);
    gl.uniform3fv(u.u_eye, S.eye);
    gl.uniform3fv(u.u_pcol, tile.pc);
    gl.uniform4fv(u.u_rei, new Float32Array(tile.rei));
    gl.uniform1i(u.u_doubleSided, tile.double_sided ? 1 : 0);
    gl.uniform1i(u.u_quant, tile.quant ? 1 : 0);
    gl.uniform3fv(u.u_sunDir, lc.sun_direction);
    gl.uniform3fv(u.u_sunColor, lc.sun_color);
    gl.uniform3fv(u.u_shadowColor, lc.shadow_color);
    gl.uniform3fv(u.u_hemiTop, lc.hemi_top);
    gl.uniform3fv(u.u_hemiBottom, lc.hemi_bottom);
    gl.uniform2f(u.u_skyRot, lc.rot_sin, lc.rot_cos);
    gl.uniform1f(u.u_iblIntensity, lc.intensity);
    gl.uniform1f(u.u_iblNormalize, lc.normalize);
    gl.uniform1f(u.u_exposure, lc.exposure);
    gl.uniform1f(u.u_envMaxMip, S.envs[tile.env].levels.length - 1);
    gl.uniform1f(u.u_envLodOffset, 0);
    const eb = new Float32Array(128);
    for (let i = 0; i < 64; i++) { eb[2 * i] = S.envbrdf.scale[i]; eb[2 * i + 1] = S.envbrdf.bias[i]; }
    gl.uniform2fv(u.u_envbrdf, eb);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    await send('material_' + tile.name + '.json', { w: W, h: H, rows: 'bottom-up', data: b64(readF32(hdr)) });
    log('material tile ' + tile.name);
  }

  // ---------------------------------------------------------------- shadow kernel
  const SH = S.shadow;
  const depth = gl.createTexture();
  gl.activeTexture(gl.TEXTURE0 + 7);
  gl.bindTexture(gl.TEXTURE_2D, depth);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT32F, SH.size, SH.size, 0, gl.DEPTH_COMPONENT, gl.FLOAT, fx.view(SH.depth));
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  const sprog = createProgram(gl, G.FULLSCREEN_VS, SHADOW_KERNEL);
  const su = uniformsOf(gl, sprog, ['u_shadowMap', 'u_bias', 'u_soft']);
  const st = target(gl, SH.kernel[0], SH.kernel[1], gl.RGBA32F, gl.FLOAT);
  gl.bindFramebuffer(gl.FRAMEBUFFER, st.fbo);
  gl.viewport(0, 0, st.w, st.h);
  gl.useProgram(sprog);
  gl.uniform1i(su.u_shadowMap, 7);
  gl.uniform1f(su.u_bias, SH.bias);
  gl.uniform1f(su.u_soft, SH.softness);
  gl.drawArrays(gl.TRIANGLES, 0, 3);
  await send('shadow.json', { w: st.w, h: st.h, rows: 'bottom-up', data: b64(readF32(st)) });

  // ---------------------------------------------------------------- post kernel
  const P = S.post;
  const hin = gl.createTexture();
  gl.activeTexture(gl.TEXTURE0 + 8);
  gl.bindTexture(gl.TEXTURE_2D, hin);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, P.size[0], P.size[1], 0, gl.RGBA, gl.FLOAT, fx.view(P.hdr));
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  tex3D(gl, 9, P.tonemap_size, fx.view(P.tonemap_lut), ext.floatLinear);
  tex3D(gl, 10, P.grade_size, fx.view(P.grade_lut), ext.floatLinear);
  tex2D(gl, 11, 64, 64, gl.RGBA8, gl.RGBA, gl.UNSIGNED_BYTE, fx.view(P.noise));
  const pprog = createProgram(gl, G.FULLSCREEN_VS, G.POST_FS);
  const pu = uniformsOf(gl, pprog, ['u_hdr', 'u_postMode', 'u_background', 'u_tonemapLUT', 'u_gradeLUT', 'u_noise',
    'u_gradeEnabled', 'u_gradeSize', 'u_ditherScale', 'u_legacy', 'u_legacyWhite']);
  const pf = target(gl, P.size[0], P.size[1], gl.RGBA32F, gl.FLOAT);
  const p8 = target(gl, P.size[0], P.size[1], gl.RGBA8, gl.UNSIGNED_BYTE);
  for (const [mode, name] of [[0, 'lut'], [1, 'legacy'], [2, 'off']]) {
    for (const t of [pf, p8]) {
      gl.bindFramebuffer(gl.FRAMEBUFFER, t.fbo);
      gl.viewport(0, 0, t.w, t.h);
      gl.useProgram(pprog);
      gl.uniform1i(pu.u_hdr, 8);
      gl.uniform1i(pu.u_tonemapLUT, 9);
      gl.uniform1i(pu.u_gradeLUT, 10);
      gl.uniform1i(pu.u_noise, 11);
      gl.uniform1i(pu.u_postMode, mode);
      gl.uniform4fv(pu.u_background, P.background);
      gl.uniform1f(pu.u_gradeEnabled, P.grade_enabled);
      gl.uniform1f(pu.u_gradeSize, P.grade_size);
      gl.uniform1f(pu.u_ditherScale, P.dither_scale);
      gl.uniform4f(pu.u_legacy, P.legacy.exposure, P.legacy.luminance_based, P.legacy.influence, P.legacy.noise);
      gl.uniform1f(pu.u_legacyWhite, P.legacy.white_point);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    }
    const u8 = new Uint8Array(p8.w * p8.h * 4);
    gl.bindFramebuffer(gl.FRAMEBUFFER, p8.fbo);
    gl.readPixels(0, 0, p8.w, p8.h, gl.RGBA, gl.UNSIGNED_BYTE, u8);
    let s8 = '';
    for (let i = 0; i < u8.length; i += 0x8000) s8 += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
    await send('post_' + name + '.json', { w: pf.w, h: pf.h, rows: 'bottom-up', f32: b64(readF32(pf)), u8: btoa(s8) });
  }
  const errors = drainErrors(gl);
  await postJSON('/api/done', { status: errors.length ? 'gl-errors' : 'ok', errors, files, renderer: info,
    gpu_path: classifyGpuPath(info.unmasked_renderer || info.renderer), extensions: ext,
    targets: { hdr: hdr.ok, shadow: st.ok, post_f32: pf.ok, post_u8: p8.ok } });
}

run().catch((e) => { $('status').textContent = String(e && e.message ? e.message : e); reportError(e); });
