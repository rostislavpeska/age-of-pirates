// M0 spike: can this browser render the viewer's texture path headless?
// One WebGL2 triangle per region samples a synthetic S3TC texture (texels uploaded raw, as the game's DDT blocks will
// be) into an RGBA16F target; the target is read back as floats, compared texel by texel with the CPU reference
// decoder, encoded as a PNG and posted to the local server together with the GPU path and extension report.
//   region dxt1       (bottom left)  COMPRESSED_RGBA_S3TC_DXT1 (D3D11 BC1 with punch-through alpha)
//   region dxt5       (bottom right) COMPRESSED_RGBA_S3TC_DXT5
//   region dxt1_srgb  (top left)     COMPRESSED_SRGB_ALPHA_S3TC_DXT1: the sampler must return linear values
//   region dxt1_hdr   (top right)    DXT1 x 4.0: the float target must keep values above 1
// PNG: rgb (the HDR region divided by 4) over a grey checker by alpha, linear values written as 8-bit, top row first.
import { log, postJSON, postFile, reportError, installErrorHooks, TEST_MODE } from '../lib/host.js';
import * as S3 from '../lib/s3tc.js';
import { createProgram, rendererInfo, classifyGpuPath, drainErrors } from '../lib/gl.js';
import { spikeTextures } from './textures.js';

const SIZE = 512, REGION = 256, TEX = 8, TEXEL = REGION / TEX;
// per channel, x the region's scale: colour against the closer decoder model (exact float maths, or NVIDIA's
// hardware rounding), alpha against the exact model (NVIDIA's BC3 alpha rounding is not modelled: up to 6/255)
const TOL_RGB = 0.006, TOL_ALPHA = 0.03;

const VS = `#version 300 es
const vec2 P[3] = vec2[3](vec2(-1.0, -1.0), vec2(3.0, -1.0), vec2(-1.0, 3.0));
void main() { gl_Position = vec4(P[gl_VertexID], 0.0, 1.0); }`;

const FS = `#version 300 es
precision highp float;
uniform sampler2D u_tex;
uniform vec4 u_vp;
uniform float u_scale;
out vec4 o;
void main() {
  vec2 uv = (gl_FragCoord.xy - u_vp.xy) / u_vp.zw;
  vec4 c = texture(u_tex, uv);
  o = vec4(c.rgb * u_scale, c.a);
}`;

const REGIONS = [
  { id: 'dxt1', x: 0, y: 0, format: S3.RGBA_DXT1, data: 'dxt1', scale: 1, need: 's3tc' },
  { id: 'dxt5', x: REGION, y: 0, format: S3.RGBA_DXT5, data: 'dxt5', scale: 1, need: 's3tc' },
  { id: 'dxt1_srgb', x: 0, y: REGION, format: S3.SRGB_ALPHA_DXT1, data: 'dxt1', scale: 1, need: 's3tc_srgb' },
  { id: 'dxt1_hdr', x: REGION, y: REGION, format: S3.RGBA_DXT1, data: 'dxt1', scale: 4, need: 's3tc' },
];

function makeTexture(gl, region, tex, ext) {
  const t = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, t);
  gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAX_LEVEL, 0);          // one level: the texture is complete
  const bytes = tex[region.data];
  if (ext[region.need]) {
    gl.compressedTexImage2D(gl.TEXTURE_2D, 0, region.format, tex.width, tex.height, 0, bytes);
    region.path = 's3tc';
  } else {                                                            // the planned fallback: decode on the CPU
    const srgb = S3.isSrgb(region.format);
    const rgba8 = S3.toRGBA8(S3.decodeLevel(region.format, tex.width, tex.height, bytes));
    gl.texImage2D(gl.TEXTURE_2D, 0, srgb ? gl.SRGB8_ALPHA8 : gl.RGBA8, tex.width, tex.height, 0, gl.RGBA,
      gl.UNSIGNED_BYTE, rgba8);
    region.path = 'cpu-rgba8-fallback';
  }
  region.upload_errors = drainErrors(gl);
  return t;
}

function expected(region, tex, model = 'exact') {
  const ref = S3.decodeLevel(region.format, tex.width, tex.height, tex[region.data], { model });
  const srgb = S3.isSrgb(region.format);
  for (let i = 0; i < ref.length; i += 4) {
    for (let k = 0; k < 3; k++) ref[i + k] = (srgb ? S3.srgbToLinear(ref[i + k]) : ref[i + k]) * region.scale;
  }
  return ref;
}

// the value at each texel centre of a region (rows from the bottom, as GL reads them)
function samplesOf(px, region) {
  const out = new Float32Array(TEX * TEX * 4);
  for (let ty = 0; ty < TEX; ty++) {
    for (let tx = 0; tx < TEX; tx++) {
      const x = region.x + tx * TEXEL + TEXEL / 2, y = region.y + ty * TEXEL + TEXEL / 2;
      out.set(px.subarray(4 * (y * SIZE + x), 4 * (y * SIZE + x) + 4), 4 * (ty * TEX + tx));
    }
  }
  return out;
}

// NEAREST sampling: every pixel of a texel's square equals its centre; the largest deviation found
function uniformity(px, region) {
  let dev = 0;
  for (let y = region.y; y < region.y + REGION; y++) {
    for (let x = region.x; x < region.x + REGION; x++) {
      const cx = region.x + Math.floor((x - region.x) / TEXEL) * TEXEL + TEXEL / 2;
      const cy = region.y + Math.floor((y - region.y) / TEXEL) * TEXEL + TEXEL / 2;
      const a = 4 * (y * SIZE + x), c = 4 * (cy * SIZE + cx);
      for (let k = 0; k < 4; k++) dev = Math.max(dev, Math.abs(px[a + k] - px[c + k]));
    }
  }
  return dev;
}

async function toPng(px) {
  const img = new Uint8ClampedArray(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const s = 4 * (y * SIZE + x), d = 4 * ((SIZE - 1 - y) * SIZE + x);
      const scale = REGIONS[(y >= REGION ? 2 : 0) + (x >= REGION ? 1 : 0)].scale;
      const chk = ((x >> 4) + (y >> 4)) & 1 ? 0.35 : 0.2;
      const a = Math.min(1, Math.max(0, px[s + 3]));
      for (let k = 0; k < 3; k++) img[d + k] = Math.round(255 * Math.min(1, Math.max(0, (px[s + k] / scale) * a + chk * (1 - a))));
      img[d + 3] = 255;
    }
  }
  const c = document.createElement('canvas');
  c.width = SIZE; c.height = SIZE;
  c.getContext('2d').putImageData(new ImageData(img, SIZE, SIZE), 0, 0);
  return new Promise((res, rej) => c.toBlob((b) => (b ? res(b) : rej(new Error('toBlob failed'))), 'image/png'));
}

function show(report) {
  const el = document.getElementById('out');
  if (el) el.textContent = JSON.stringify({ status: report.status, gpu_path: report.gpu_path, extensions: report.extensions,
    target: report.target, problems: report.problems, fallbacks: report.fallbacks }, null, 1);
}

async function finish(report, t0) {
  report.elapsed_ms = Math.round(performance.now() - t0);
  if (report.status !== 'ok' && report.status !== 'degraded') report.status = 'fail';
  show(report);
  await postJSON('/api/done', report);
}

async function run() {
  installErrorHooks();
  const t0 = performance.now();
  const report = { page: 'm0', report_version: 1, user_agent: navigator.userAgent, test_mode: TEST_MODE, size: SIZE,
    status: 'fail', problems: [], fallbacks: [] };
  await log('m0: page loaded');
  const canvas = document.getElementById('gl');
  const gl = canvas.getContext('webgl2', { antialias: false, premultipliedAlpha: false, preserveDrawingBuffer: true,
    powerPreference: 'high-performance' });
  report.webgl2 = !!gl;
  if (!gl) {
    report.problems.push('no WebGL2 context');
    return finish(report, t0);
  }
  report.renderer = rendererInfo(gl);
  report.gpu_path = classifyGpuPath(report.renderer.unmasked_renderer || report.renderer.renderer);
  report.extensions_all = gl.getSupportedExtensions() || [];
  const ext = {
    color_buffer_float: gl.getExtension('EXT_color_buffer_float'),
    s3tc: gl.getExtension('WEBGL_compressed_texture_s3tc'),
    s3tc_srgb: gl.getExtension('WEBGL_compressed_texture_s3tc_srgb'),
  };
  report.extensions = {
    EXT_color_buffer_float: !!ext.color_buffer_float,
    WEBGL_compressed_texture_s3tc: !!ext.s3tc,
    WEBGL_compressed_texture_s3tc_srgb: !!ext.s3tc_srgb,
    EXT_color_buffer_half_float: !!gl.getExtension('EXT_color_buffer_half_float'),
    OES_texture_float_linear: !!gl.getExtension('OES_texture_float_linear'),
    EXT_texture_filter_anisotropic: !!gl.getExtension('EXT_texture_filter_anisotropic'),
  };
  report.limits = {
    MAX_TEXTURE_SIZE: gl.getParameter(gl.MAX_TEXTURE_SIZE),
    MAX_RENDERBUFFER_SIZE: gl.getParameter(gl.MAX_RENDERBUFFER_SIZE),
    MAX_SAMPLES: gl.getParameter(gl.MAX_SAMPLES),
    MAX_VERTEX_TEXTURE_IMAGE_UNITS: gl.getParameter(gl.MAX_VERTEX_TEXTURE_IMAGE_UNITS),
  };
  await log('m0: ' + report.gpu_path + ' | ' + (report.renderer.unmasked_renderer || report.renderer.renderer));
  for (const [name, have] of Object.entries(report.extensions).slice(0, 3)) {
    if (!have) report.fallbacks.push(name + ' missing');
  }

  // the render target: RGBA16F (EXT_color_buffer_float), else RGBA8 as a reported fallback
  const targetFormat = ext.color_buffer_float ? 'RGBA16F' : 'RGBA8';
  const target = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, target);
  gl.texStorage2D(gl.TEXTURE_2D, 1, targetFormat === 'RGBA16F' ? gl.RGBA16F : gl.RGBA8, SIZE, SIZE);
  const fb = gl.createFramebuffer();
  gl.bindFramebuffer(gl.FRAMEBUFFER, fb);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, target, 0);
  const fbStatus = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
  report.target = { format: targetFormat, complete: fbStatus === gl.FRAMEBUFFER_COMPLETE, status: '0x' + fbStatus.toString(16) };
  if (!report.target.complete) {
    report.problems.push('render target ' + targetFormat + ' incomplete');
    return finish(report, t0);
  }
  gl.disable(gl.BLEND);
  gl.clearColor(0, 0, 0, 0);
  gl.clear(gl.COLOR_BUFFER_BIT);
  const prog = createProgram(gl, VS, FS);
  gl.useProgram(prog);
  gl.uniform1i(gl.getUniformLocation(prog, 'u_tex'), 0);
  gl.activeTexture(gl.TEXTURE0);
  const uVp = gl.getUniformLocation(prog, 'u_vp'), uScale = gl.getUniformLocation(prog, 'u_scale');
  const tex = spikeTextures();
  for (const r of REGIONS) {
    makeTexture(gl, r, tex, ext);
    gl.viewport(r.x, r.y, REGION, REGION);
    gl.uniform4f(uVp, r.x, r.y, REGION, REGION);
    gl.uniform1f(uScale, r.scale);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    r.draw_errors = drainErrors(gl);
  }
  gl.finish();

  // read back as floats
  const px = new Float32Array(SIZE * SIZE * 4);
  report.read = {
    implementation_format: '0x' + gl.getParameter(gl.IMPLEMENTATION_COLOR_READ_FORMAT).toString(16),
    implementation_type: '0x' + gl.getParameter(gl.IMPLEMENTATION_COLOR_READ_TYPE).toString(16),
  };
  if (targetFormat === 'RGBA16F') {
    gl.readPixels(0, 0, SIZE, SIZE, gl.RGBA, gl.FLOAT, px);
    report.read.as = 'RGBA/FLOAT';
  } else {
    const u8 = new Uint8Array(SIZE * SIZE * 4);
    gl.readPixels(0, 0, SIZE, SIZE, gl.RGBA, gl.UNSIGNED_BYTE, u8);
    for (let i = 0; i < u8.length; i++) px[i] = u8[i] / 255;
    report.read.as = 'RGBA/UNSIGNED_BYTE';
  }
  report.read.errors = drainErrors(gl);
  if (report.read.errors.length) report.problems.push('readPixels: ' + report.read.errors.join(', '));

  report.regions = REGIONS.map((r) => {
    const got = samplesOf(px, r), want = expected(r, tex), errors = {};
    let maxVal = 0;
    for (let i = 0; i < got.length; i++) if (i % 4 !== 3) maxVal = Math.max(maxVal, got[i]);
    for (const model of ['exact', 'nvidia']) {
      const ref = model === 'exact' ? want : expected(r, tex, model);
      const e = { rgb: 0, alpha: 0 };
      for (let i = 0; i < got.length; i++) {
        const k = i % 4 === 3 ? 'alpha' : 'rgb';
        e[k] = Math.max(e[k], Math.abs(got[i] - ref[i]));
      }
      errors[model] = e;
    }
    // which decoder the GPU behaves like (the spike's blocks tell the two apart by up to 5/255 on green)
    const tight = 0.004 * r.scale;
    const decoder = errors.exact.rgb <= tight && errors.nvidia.rgb > tight ? 'exact'
      : errors.nvidia.rgb <= tight && errors.exact.rgb > tight ? 'nvidia-hardware'
        : errors.exact.rgb <= tight ? 'exact (models agree here)' : 'unknown';
    const rgbErr = Math.min(errors.exact.rgb, errors.nvidia.rgb);
    const out = { id: r.id, format: S3.FORMAT_NAMES[r.format], format_enum: r.format, path: r.path, srgb: S3.isSrgb(r.format),
      scale: r.scale, x: r.x, y: r.y, size: REGION, texels: TEX, texel_px: TEXEL, errors, decoder_match: decoder,
      max_abs_error: Math.max(rgbErr, errors.exact.alpha), tolerance_rgb: TOL_RGB * r.scale, tolerance_alpha: TOL_ALPHA,
      max_value: maxVal, uniformity_max_dev: uniformity(px, r),
      upload_errors: r.upload_errors, draw_errors: r.draw_errors, blocks_hex: S3.toHex(tex[r.data]),
      samples: Array.from(got), expected: Array.from(want) };
    if (r.upload_errors.length || r.draw_errors.length) report.problems.push(r.id + ': GL ' + r.upload_errors.concat(r.draw_errors).join(', '));
    if (rgbErr > out.tolerance_rgb) report.problems.push(r.id + ': colour error ' + rgbErr.toFixed(4) + ' > ' + out.tolerance_rgb);
    if (errors.exact.alpha > TOL_ALPHA) report.problems.push(r.id + ': alpha error ' + errors.exact.alpha.toFixed(4) + ' > ' + TOL_ALPHA);
    if (out.uniformity_max_dev > 1e-3) report.problems.push(r.id + ': texel squares not uniform (' + out.uniformity_max_dev + ')');
    return out;
  });
  const decoders = new Set(report.regions.map((g) => g.decoder_match).filter((d) => !d.startsWith('exact (')));
  report.texture_decoder = decoders.size === 1 ? [...decoders][0] : [...decoders].join(' / ') || 'exact';
  const hdr = report.regions.find((r) => r.id === 'dxt1_hdr');
  report.hdr_kept = hdr.max_value > 1.5;
  if (targetFormat === 'RGBA16F' && !report.hdr_kept) report.problems.push('RGBA16F target clamped values to ' + hdr.max_value);
  await log('m0: regions ' + report.regions.map((r) => r.id + ' ' + r.path + ' ' + r.decoder_match + ' err '
    + r.max_abs_error.toFixed(4)).join(' | '));

  const png = await toPng(px);
  await postFile('m0_readback.png', png);
  report.png = 'm0_readback.png';
  report.status = report.problems.length ? 'fail' : report.fallbacks.length ? 'degraded' : 'ok';
  return finish(report, t0);
}

run().catch((e) => reportError(e));
