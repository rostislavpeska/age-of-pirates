// node --test: viewer/lib/s3tc.js and the M0 spike textures (pure functions, no browser).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as S3 from '../../viewer/lib/s3tc.js';
import { spikeTextures } from '../../viewer/m0/textures.js';

const RAMP = [0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3];
const close = (a, b, eps = 1e-6) => assert.ok(Math.abs(a - b) <= eps, `${a} != ${b}`);
const texel = (rgba, i) => Array.from(rgba.subarray(4 * i, 4 * i + 4));

test('565 packing and bit replication', () => {
  assert.equal(S3.pack565(255, 0, 0), 0xf800);
  assert.equal(S3.pack565(0, 255, 0), 0x07e0);
  assert.deepEqual(S3.unpack565(0x8410), [132, 130, 132]);
  assert.deepEqual(S3.unpack565(0xffff), [255, 255, 255]);
});

test('BC1 block layout: little-endian colours, 2-bit indices row by row', () => {
  assert.deepEqual(Array.from(S3.makeBC1Block(0xf800, 0x001f, RAMP)), [0x00, 0xf8, 0x1f, 0x00, 0xe4, 0xe4, 0xe4, 0xe4]);
});

test('BC1 exact decode: 4-colour ramp and 3-colour punch-through', () => {
  const ramp = S3.decodeBC1Block(S3.makeBC1Block(0xf800, 0x001f, RAMP));
  assert.deepEqual(texel(ramp, 0), [1, 0, 0, 1]);
  assert.deepEqual(texel(ramp, 1), [0, 0, 1, 1]);
  texel(ramp, 2).forEach((v, k) => close(v, [2 / 3, 0, 1 / 3, 1][k]));
  texel(ramp, 3).forEach((v, k) => close(v, [1 / 3, 0, 2 / 3, 1][k]));
  const punch = S3.makeBC1Block(0x07e0, 0xffff, RAMP);
  assert.deepEqual(texel(S3.decodeBC1Block(punch), 3), [0, 0, 0, 0]);
  assert.deepEqual(texel(S3.decodeBC1Block(punch, 0, { punchThrough: false }), 3), [0, 0, 0, 1]);
  texel(S3.decodeBC1Block(punch), 2).forEach((v, k) => close(v, [0.5, 1, 0.5, 1][k], 1e-3));
  // in BC3 the colour block is always 4-colour: no transparent texel
  assert.equal(S3.decodeBC1Block(punch, 0, { fourColour: true })[15], 1);
});

test('BC1 NVIDIA model: green 175 / 80, red 170 / 85, half 127', () => {
  const yb = S3.decodeBC1Block(S3.makeBC1Block(0xffe0, 0x0000, RAMP), 0, { model: 'nvidia' });
  assert.equal(Math.round(yb[4 * 2 + 1] * 255), 175);
  assert.equal(Math.round(yb[4 * 3 + 1] * 255), 80);
  assert.equal(Math.round(yb[4 * 2] * 255), 170);
  assert.equal(Math.round(yb[4 * 3] * 255), 85);
  const gw = S3.decodeBC1Block(S3.makeBC1Block(0x07e0, 0xffff, RAMP), 0, { model: 'nvidia' });
  assert.equal(Math.round(gw[4 * 2] * 255), 127);
  assert.throws(() => S3.decodeBC1Block(S3.makeBC1Block(0, 0, RAMP), 0, { model: 'amd' }));
});

test('BC3 alpha: 8-value and 6-value modes, bit packing round trip', () => {
  const idx = [0, 1, 2, 3, 4, 5, 6, 7, 7, 6, 5, 4, 3, 2, 1, 0];
  const eight = S3.decodeBC3Alpha(S3.makeBC3Block(255, 0, idx, 0, 0, RAMP));
  close(eight[2], (6 * 255) / 7 / 255);
  close(eight[7], 255 / 7 / 255);
  close(eight[8], 255 / 7 / 255);
  const six = S3.decodeBC3Alpha(S3.makeBC3Block(0, 255, idx, 0, 0, RAMP));
  close(six[2], 0.2);
  close(six[5], 0.8);
  assert.equal(six[6], 0);
  assert.equal(six[7], 1);
});

test('sizes and formats', () => {
  assert.equal(S3.blockBytes(S3.RGBA_DXT1), 8);
  assert.equal(S3.blockBytes(S3.SRGB_ALPHA_DXT5), 16);
  assert.equal(S3.levelByteLength(S3.RGBA_DXT5, 8, 8), 64);
  assert.equal(S3.levelByteLength(S3.RGBA_DXT1, 1, 1), 8);
  assert.equal(S3.levelByteLength(S3.RGBA_DXT1, 1024, 512), 256 * 128 * 8);
  assert.throws(() => S3.blockBytes(0x1234));
  assert.ok(S3.isSrgb(S3.SRGB_ALPHA_DXT1) && !S3.isSrgb(S3.RGBA_DXT1));
  assert.equal(S3.FORMAT_NAMES[S3.RGBA_DXT1], 'COMPRESSED_RGBA_S3TC_DXT1_EXT');
  close(S3.srgbToLinear(132 / 255), 0.2307, 1e-4);
  assert.equal(S3.toHex(new Uint8Array([0, 15, 255])), '000fff');
});

test('the spike textures decode as their comment says', () => {
  const t = spikeTextures();
  assert.equal(t.dxt1.length, 32);
  assert.equal(t.dxt5.length, 64);
  const d1 = S3.decodeLevel(S3.RGBA_DXT1, 8, 8, t.dxt1);
  assert.deepEqual(texel(d1, 0), [1, 0, 0, 1]);                        // block (0,0): red
  assert.deepEqual(texel(d1, 7), [0, 0, 0, 0]);                        // block (1,0) texel col 3: transparent
  assert.deepEqual(texel(d1, 8 * 4).map((v) => Math.round(v * 255)), [132, 130, 132, 255]);   // grey block
  const d5 = S3.decodeLevel(S3.RGBA_DXT5, 8, 8, t.dxt5);
  close(d5[4 * 7 + 3], 0.4);                                           // 6-value alpha index 3 = 102/255
  assert.ok(d5[4 * 7 + 1] > 0.9);                                      // 4-colour in BC3: (c0 + 2 c1) / 3, opaque
});
