// M3 game shader: the data side, pure (node --test: tests/js/shading.test.mjs). Turns bundle records into the uniforms
// of viewer/shading/glsl.js - the materialdefault REIConstants of a material, the LightingConstants of a lighting
// section (lighting.py shader_constants, with page overrides), player colours, the EnvBRDF table, the dither noise.
// references/shader-model.md has the formulas; every value here says where it came from.

export const SHADER_MODEL = 'v1';

// materialdef parameter name -> REIConstants member, in the cbuffer order of the BasePass permutations (measured:
// materialdefault_PSMain blobs d24973898 / 781ce36f8; the materialdef lists them in the same order). Defaults are the
// default.materialdef values (Render.bar) for a material that does not carry them.
export const REI_PARAMS = [
  ['pixelxformColor', 'playerColorIndex', 0],
  ['AO Intensity', 'aoIntensity', 1],
  ['AO Gamma', 'aoGamma', 0],
  ['Lift Metallic', 'liftMetallic', 0],
  ['Lift Non-Metallic', 'liftNonMetallic', 0],
  ['Roughness Min', 'roughnessMin', 0],
  ['Roughness Max', 'roughnessMax', 1],
  ['Roughness Metallic Min', 'roughnessMetallicMin', 0],
  ['Roughness Metallic Max', 'roughnessMetallicMax', 1],
  ['Metallic Min', 'metallicMin', 0],
  ['Metallic Max', 'metallicMax', 1],
  ['CutoutThreshold', 'cutoutThreshold', 0.5],
];

// Stand-ins for the engine's default textures of an unbound slot (their content is unknown; labelled in the page).
// Details' default is the 'black' texture (default.materialdef: measured) - no player colour.
export const MISSING_SLOT = {
  BaseColor: [0.5, 0.5, 0.5, 1],
  Normals: [0.5, 0.5, 1, 1],
  Masks: [1, 1, 0, 1],
  Details: [0, 0, 0, 1],
};

function num(v, d) { return typeof v === 'number' && Number.isFinite(v) ? v : d; }

// material record -> {rei: Float32Array(12) packed as the GLSL u_rei[3], values {name: v}, sources {name: src}, flags}
export function materialParams(mat) {
  const floats = (mat && mat.floats) || {};
  const src = (mat && mat.float_sources) || {};
  const values = {}, sources = {};
  for (const [name, key, def] of REI_PARAMS) {
    const v = floats[name];
    values[key] = num(v, def);
    sources[key] = typeof v === 'number' ? (src[name] || 'materialdef') : 'default.materialdef (absent)';
  }
  const f = (mat && mat.flags) || {};
  const rei = new Float32Array([
    values.playerColorIndex, values.aoIntensity, values.aoGamma, values.liftMetallic,
    values.liftNonMetallic, values.roughnessMin, values.roughnessMax, values.roughnessMetallicMin,
    values.roughnessMetallicMax, values.metallicMin, values.metallicMax, values.cutoutThreshold,
  ]);
  return { rei, values, sources, cutout: !!f.cutout, doubleSided: !!f.double_sided, materialdef: mat ? mat.materialdef : null };
}

export function srgbToLinear(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }

// the player colour a material receives: playercolors color[k + 1] of the player (k = pixelxformColor, 0..2), decoded
// as sRGB/255 (guess). player: a lighting.player_colors record.
export function playerColour(player, k = 0) {
  if (!player) return [0.2, 0.3, 0.9];
  const rows = [player.rgb, player.color2, player.color3];
  const rgb = rows[Math.max(0, Math.min(2, Math.round(k)))] || player.rgb;
  return rgb ? rgb.map((v) => srgbToLinear(v / 255)) : [0.2, 0.3, 0.9];
}

// toward-the-sun unit vector of an azimuth / elevation pair (degrees; lighting.sun_direction's convention: +Y up,
// azimuth about +Y from +Z toward +X), and back
export function towardSun(azDeg, elDeg) {
  const a = (azDeg * Math.PI) / 180, e = (elDeg * Math.PI) / 180;
  return [Math.cos(e) * Math.sin(a), Math.sin(e), Math.cos(e) * Math.cos(a)];
}

export function azElOf(toward) {
  const [x, y, z] = toward;
  const l = Math.hypot(x, y, z) || 1;
  return { az: (Math.atan2(x / l, z / l) * 180) / Math.PI, el: (Math.asin(Math.max(-1, Math.min(1, y / l))) * 180) / Math.PI };
}

function val(entries, key, d) {
  const e = entries && entries[key];
  return e && e.value !== null && e.value !== undefined ? e.value : d;
}

// a lgt colour under the chosen decode: 'srgb' (the default guess) or 'linear' (x/255, lighting.py alternatives)
function colour(entries, key, d, decode) {
  const e = entries && entries[key];
  const alt = e && e.alternatives && e.alternatives.linear_255;
  return decode === 'linear' && alt ? alt : val(entries, key, d);
}

// lighting section (+ overrides) -> the LightingConstants the shader takes, plus the env cube mapping
// overrides: {sunAz, sunEl (degrees), sunScale, exposure, iblIntensity, iblNormalize, mipBias, hemiScale,
//             colourDecode: 'srgb' (default guess) | 'linear' (lgt colours as x/255: the calibration alternative)}
export function lightingUniforms(section, overrides = {}) {
  const sh = section && section.shader;
  const e = (sh && sh.entries) || null;
  const notes = [];
  if (!e) notes.push('this bundle has no lighting.shader block (built before M3): neutral stand-ins; rebuild the bundle');
  const sunDir0 = val(e, 'sun_direction', null);
  let toward = sunDir0 ? sunDir0.map((x) => -x) : towardSun(35, 50);
  const derived = azElOf(toward);
  if (overrides.sunAz !== undefined || overrides.sunEl !== undefined) {
    toward = towardSun(overrides.sunAz ?? derived.az, overrides.sunEl ?? derived.el);
    notes.push('sun direction overridden in the page');
  }
  const scale = (v, s) => (v ? v.map((x) => x * s) : v);
  const decode = overrides.colourDecode === 'linear' ? 'linear' : 'srgb';
  if (decode === 'linear') notes.push('lgt colours read as x/255 (the alternative to the sRGB-decode guess)');
  const sunScale = overrides.sunScale ?? 1;
  const hemiScale = overrides.hemiScale ?? 1;
  const rot = val(e, 'sky_cube_rotation', { sin: 0, cos: 1 });
  const refl = section && section.refl;
  const mipCount = refl && refl.decodable && refl.mips && refl.mips.length ? refl.mip_count : 1;
  const firstLevel = refl && refl.mips && refl.mips.length ? refl.mips[0].level : 0;
  const legacy = val(e, 'legacy_tonemap', { luminance_based: 0, influence: 1, noise: 0, exposure: 0.5, white_point: 11.2 });
  return {
    sunDir: toward.map((x) => -x),
    sunAzEl: azElOf(toward),
    sunAzElDerived: derived,
    sunColor: scale(colour(e, 'sun_color', [3, 3, 3], decode), sunScale),
    shadowColor: colour(e, 'shadow_color', [1, 1, 1], decode),
    hemiTop: scale(colour(e, 'hemi_top', [0.5, 0.5, 0.5], decode), hemiScale),
    hemiBottom: scale(colour(e, 'hemi_bottom', [0.5, 0.5, 0.5], decode), hemiScale),
    colourDecode: decode,
    rotSin: rot.sin, rotCos: rot.cos,
    intensity: overrides.iblIntensity ?? val(e, 'sky_cube_intensity', 1),
    normalize: overrides.iblNormalize ?? val(e, 'sky_cube_normalize', 1),
    exposure: overrides.exposure ?? val(e, 'exposure', 1),
    mipBias: overrides.mipBias ?? val(e, 'mip_bias', 0),
    whitePoint: val(e, 'white_point', 11.2),
    gradeEnabled: val(e, 'grade_enabled', 0),
    ditherScale: val(e, 'dither_scale', 1 / 256),
    legacy,
    envMaxMip: mipCount - 1,                    // the game's (levels - 1) of the full cube
    envLodOffset: firstLevel,                   // file levels the bundle dropped (GL level 0 = file level firstLevel)
    statuses: e ? Object.fromEntries(Object.entries(e).map(([k, v]) => [k, v.status])) : {},
    notes,
  };
}

// the EnvBRDF table as a Float32Array(128) of (scale, bias) pairs for `uniform vec2 u_envbrdf[64]`; null without it
export function envbrdfPairs(section) {
  const t = section && section.envbrdf;
  if (!t || !t.scale || t.scale.length !== 64 || !t.bias || t.bias.length !== 64) return null;
  const out = new Float32Array(128);
  for (let i = 0; i < 64; i++) { out[2 * i] = t.scale[i]; out[2 * i + 1] = t.bias[i]; }
  return out;
}

// the dither noise: 64x64 RGBA8 from a seeded mulberry32 stream (the game's noise texture is unknown; a fixed seed keeps
// renders and tests repeatable)
export function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function noiseTexture(seed = 1, size = 64) {
  const r = mulberry32(seed);
  const out = new Uint8Array(size * size * 4);
  for (let i = 0; i < out.length; i++) out[i] = Math.floor(r() * 256);
  return out;
}

// float32 -> IEEE half bits (round to nearest even; clamps to +-65504, NaN kept)
export function toHalf(f) {
  const fv = new Float32Array(1), iv = new Uint32Array(fv.buffer);
  fv[0] = f;
  const x = iv[0];
  const sign = (x >>> 16) & 0x8000;
  let e = (x >>> 23) & 0xff, m = x & 0x7fffff;
  if (e === 0xff) return sign | 0x7c00 | (m ? 0x200 : 0);
  e = e - 127 + 15;
  if (e >= 0x1f) return sign | 0x7bff;
  if (e <= 0) {
    if (e < -10) return sign;
    m = (m | 0x800000) >>> (1 - e);
    const half = m >>> 13, rest = m & 0x1fff;
    return sign | (half + (rest > 0x1000 || (rest === 0x1000 && (half & 1)) ? 1 : 0));
  }
  const half = (e << 10) | (m >>> 13), rest = m & 0x1fff;
  return sign | Math.min(half + (rest > 0x1000 || (rest === 0x1000 && (half & 1)) ? 1 : 0), 0x7bff);
}

// fidelity stages of the page as it renders now: the bundle's flags, with the runtime choices applied
// opts: {renderer: 'game'|'placeholder', shadows, tonemap: 'lut'|'legacy'|'off', debug, overridden: bool}
export function runtimeFidelity(bundleFidelity, opts = {}) {
  const stages = Object.assign({}, (bundleFidelity && bundleFidelity.stages) || {});
  const notes = Object.assign({}, (bundleFidelity && bundleFidelity.notes) || {});
  if (opts.renderer === 'placeholder') {
    stages.material = 'A'; notes.material = 'M2 placeholder material selected in the page';
    stages.brdf = 'A'; notes.brdf = 'M2 placeholder: Lambert sun + flat ambient';
    stages.tonemap = 'A'; notes.tonemap = 'placeholder: plain sRGB, no tonemap';
    for (const k of ['ibl', 'envbrdf', 'specular_occlusion', 'gbuffer', 'normal_map']) {
      if (k in stages) { stages[k] = 'A'; notes[k] = 'not drawn by the placeholder'; }
    }
    stages.shadows = 'A'; notes.shadows = 'placeholder: no shadows';
  } else {
    if (opts.shadows === false) { stages.shadows = 'A'; notes.shadows = 'shadows switched off in the page (shadow factor 1)'; }
    if (opts.tonemap === 'off') { stages.tonemap = 'A'; notes.tonemap = 'tonemap switched off in the page: saturate + sRGB'; }
    if (opts.tonemap === 'legacy') notes.tonemap = 'legacy tonemap.hlsl (Hable) selected; which path the game runs is unknown';
    if (opts.overridden) { stages.lgt_mapping = 'U'; notes.lgt_mapping = (notes.lgt_mapping || '') + ' (page overrides active)'; }
    if (opts.debug) notes.debug = 'debug view: ' + opts.debug;
  }
  return { stages, notes, badge: Object.values(stages).join('') };
}
