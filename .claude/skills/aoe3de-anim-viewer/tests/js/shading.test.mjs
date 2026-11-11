// viewer/shading/model.js and glsl.js under node --test (pure parts of the M3 game shader; no browser).
import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../viewer/shading/model.js';
import * as G from '../../viewer/shading/glsl.js';

const close = (a, b, eps = 1e-9) => assert.ok(Math.abs(a - b) <= eps, `${a} != ${b}`);

test('materialParams packs the REIConstants in cbuffer order, with materialdef defaults', () => {
  const mat = { materialdef: 'default_doublesided_cutout', floats: { pixelxformColor: 2, 'AO Intensity': 1.5,
    'Roughness Max': 0.7, CutoutThreshold: 0.25 }, float_sources: { 'AO Intensity': 'override' },
  flags: { cutout: true, double_sided: true } };
  const p = M.materialParams(mat);
  assert.deepEqual(Array.from(p.rei), [2, 1.5, 0, 0, 0, 0, Math.fround(0.7), 0, 1, 0, 1, 0.25]);
  assert.equal(p.sources.aoIntensity, 'override');
  assert.equal(p.sources.aoGamma, 'default.materialdef (absent)');
  assert.ok(p.cutout && p.doubleSided);
  const d = M.materialParams(null);
  assert.deepEqual(Array.from(d.rei), [0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0.5]);
  assert.ok(!d.cutout && !d.doubleSided);
  assert.equal(M.REI_PARAMS.length, 12);
});

test('playerColour picks color1..3 by pixelxformColor and decodes sRGB', () => {
  const p = { index: 1, rgb: [255, 0, 0], color2: [0, 255, 0], color3: [0, 0, 255] };
  assert.deepEqual(M.playerColour(p, 0), [1, 0, 0]);
  assert.deepEqual(M.playerColour(p, 1), [0, 1, 0]);
  assert.deepEqual(M.playerColour(p, 7), [0, 0, 1]);
  close(M.playerColour({ rgb: [128, 128, 128] })[0], Math.pow((128 / 255 + 0.055) / 1.055, 2.4));
  assert.equal(M.playerColour(null).length, 3);
});

test('towardSun and azElOf invert each other (lighting.sun_direction convention)', () => {
  const v = M.towardSun(90, 0);
  close(v[0], 1); close(v[1], 0); close(v[2], 0, 1e-12);
  const up = M.towardSun(12, 90);
  close(up[1], 1);
  const ae = M.azElOf(M.towardSun(-130, 35));
  close(ae.az, -130, 1e-9); close(ae.el, 35, 1e-9);
});

const SECTION = {
  shader: { version: 'v1', entries: {
    sun_direction: { value: [0, -0.6, -0.8], status: 'guess' }, sun_color: { value: [2, 2, 2], status: 'guess' },
    shadow_color: { value: [0.5, 0.5, 0.6], status: 'guess' }, hemi_top: { value: [1, 1, 1], status: 'guess' },
    hemi_bottom: { value: [0.2, 0.2, 0.2], status: 'guess' }, sky_cube_rotation: { value: { sin: 0.5, cos: 0.75 } },
    sky_cube_intensity: { value: 1, status: 'unknown' }, sky_cube_normalize: { value: 1.7, status: 'guess' },
    exposure: { value: 2, status: 'name-match' }, mip_bias: { value: -1 }, white_point: { value: 11.2 },
    grade_enabled: { value: 1 }, dither_scale: { value: 1 / 256 },
    legacy_tonemap: { value: { luminance_based: 1, influence: 0, noise: 0.04, exposure: 0.5, white_point: 11.2 } } } },
  refl: { decodable: true, mip_count: 7, mips: [{ level: 2, size: 128 }, { level: 3, size: 64 }] },
  envbrdf: { scale: Array.from({ length: 64 }, (_, i) => i / 64), bias: Array.from({ length: 64 }, (_, i) => 1 - i / 64) },
};

test('lightingUniforms reads the shader block and the cube mapping', () => {
  const u = M.lightingUniforms(SECTION);
  assert.deepEqual(u.sunDir, [0, -0.6, -0.8]);
  close(u.sunAzEl.el, 36.86989764584402, 1e-9);
  assert.equal(u.exposure, 2);
  assert.equal(u.normalize, 1.7);
  assert.equal(u.envMaxMip, 6);                  // the game's (levels - 1) of the full cube
  assert.equal(u.envLodOffset, 2);               // the bundle dropped file levels 0 and 1
  assert.equal(u.rotSin, 0.5);
  assert.equal(u.statuses.sky_cube_intensity, 'unknown');
  assert.equal(u.legacy.influence, 0);
  assert.deepEqual(u.notes, []);
});

test('lightingUniforms overrides and the pre-M3 fallback', () => {
  const u = M.lightingUniforms(SECTION, { sunAz: 90, sunEl: 30, exposure: 1.25, iblIntensity: 0.5, sunScale: 2 });
  close(u.sunDir[0], -Math.cos(Math.PI / 6)); close(u.sunDir[1], -0.5);
  assert.equal(u.exposure, 1.25);
  assert.equal(u.intensity, 0.5);
  assert.deepEqual(u.sunColor, [4, 4, 4]);
  assert.ok(u.notes.some((n) => n.includes('overridden')));
  const old = M.lightingUniforms({ lgt: {} });
  assert.ok(old.notes[0].includes('rebuild'));
  assert.equal(old.envMaxMip, 0);
  assert.ok(old.sunDir[1] < 0);
});

test('envbrdfPairs interleaves scale and bias', () => {
  const p = M.envbrdfPairs(SECTION);
  assert.equal(p.length, 128);
  close(p[2 * 10], 10 / 64, 1e-7); close(p[2 * 10 + 1], 1 - 10 / 64, 1e-7);
  assert.equal(M.envbrdfPairs({}), null);
});

test('the dither noise is seeded and repeatable', () => {
  const a = M.noiseTexture(1), b = M.noiseTexture(1), c = M.noiseTexture(2);
  assert.equal(a.length, 64 * 64 * 4);
  assert.deepEqual(a, b);
  assert.notDeepEqual(a, c);
  const r = M.mulberry32(1);
  close(r(), 0.6270739405881613, 0);             // mulberry32's published first value for seed 1
  const mean = a.reduce((s, x) => s + x, 0) / a.length;
  assert.ok(mean > 120 && mean < 135, String(mean));
});

test('toHalf rounds like IEEE half', () => {
  assert.equal(M.toHalf(1), 0x3c00);
  assert.equal(M.toHalf(-2), 0xc000);
  assert.equal(M.toHalf(0.5), 0x3800);
  assert.equal(M.toHalf(65504), 0x7bff);
  assert.equal(M.toHalf(1e6), 0x7bff);
  assert.equal(M.toHalf(0), 0);
  assert.equal(M.toHalf(5.960464477539063e-8), 1);
  assert.equal(M.toHalf(NaN) & 0x7c00, 0x7c00);
});

test('runtimeFidelity marks the placeholder and switched-off stages', () => {
  const base = { stages: { material: 'M', brdf: 'M', shadows: 'A', tonemap: 'U', ibl: 'A', lgt_mapping: 'U' }, notes: {} };
  const g = M.runtimeFidelity(base, { renderer: 'game', shadows: true, tonemap: 'lut' });
  assert.equal(g.badge, 'MMAUAU');
  const p = M.runtimeFidelity(base, { renderer: 'placeholder' });
  assert.equal(p.stages.material, 'A');
  assert.equal(p.stages.brdf, 'A');
  const off = M.runtimeFidelity(base, { renderer: 'game', shadows: false, tonemap: 'off', overridden: true });
  assert.ok(off.notes.shadows.includes('off') && off.notes.tonemap.includes('off'));
});

test('glsl sources carry the measured constants and the shared functions', () => {
  for (const k of ['0.99955', '0.029995', '-5.55473', '6.98316', '0.769231', '0.08', '1.5 + 1.0', '0.318310']) {
    assert.ok((G.LIGHTING + G.MATERIAL + G.COMMON).includes(k), k);
  }
  for (const k of ['0.96875', '0.015625', '0.066667']) assert.ok(G.POST.includes(k), k);
  assert.ok(G.MATERIAL_FS.includes('materialdefault(') && G.MATERIAL_FS.includes('lightingpass('));
  assert.ok(G.MATERIAL_FS.includes('gbufferRoundTrip(') && G.MATERIAL_FS.includes('pcf25('));
  assert.equal((G.MATERIAL_FS.match(/#version/g) || []).length, 1);
  assert.equal((G.POST_FS.match(/#version/g) || []).length, 1);
  assert.ok(G.materialVS('/*skin*/').includes('layout(location = 5) in vec4 a_tan;'));
  assert.ok(M.SHADER_MODEL === 'v1');
});
