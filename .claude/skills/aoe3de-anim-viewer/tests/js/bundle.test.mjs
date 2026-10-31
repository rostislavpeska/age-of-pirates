// node --test: viewer/lib/bundle.js. The fixture case reads a bundle written by scripts/av_common.py
// (tests/test_viewer_js.py writes it and passes its folder in AV_BUNDLE_FIXTURE); run alone, that case is skipped.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { viewArray, halfToFloat, checkManifest, loadBundle, littleEndianHost, SCHEMA_NAME, SCHEMA_VERSION } from '../../viewer/lib/bundle.js';

test('half floats', () => {
  assert.equal(halfToFloat(0x3c00), 1);
  assert.equal(halfToFloat(0xc000), -2);
  assert.equal(halfToFloat(0x7bff), 65504);
  assert.equal(halfToFloat(0x0001), 2 ** -24);
  assert.equal(halfToFloat(0x7c00), Infinity);
  assert.ok(Number.isNaN(halfToFloat(0x7e00)));
});

test('views are checked against alignment, length and the buffer end', () => {
  const buffers = { geo: new ArrayBuffer(64) };
  const ok = { buffer: 'geo', byteOffset: 16, byteLength: 24, dtype: 'f32', count: 2, components: 3 };
  assert.equal(viewArray(buffers, ok).length, 6);
  assert.ok(viewArray(buffers, ok) instanceof Float32Array);
  assert.throws(() => viewArray(buffers, { ...ok, byteOffset: 4 }), /aligned/);
  assert.throws(() => viewArray(buffers, { ...ok, byteLength: 20 }), /byteLength/);
  assert.throws(() => viewArray(buffers, { ...ok, byteOffset: 48 }), /past/);
  assert.throws(() => viewArray(buffers, { ...ok, dtype: 'f64' }), /dtype/);
  assert.throws(() => viewArray(buffers, { ...ok, buffer: 'tex' }), /missing/);
  assert.ok(viewArray(buffers, { ...ok, dtype: 'f16', byteLength: 12 }) instanceof Uint16Array);
});

test('manifest schema and version are enforced', () => {
  assert.throws(() => checkManifest({ schema: 'other', schema_version: 0 }), /not a viewer bundle/);
  assert.throws(() => checkManifest({ schema: SCHEMA_NAME, schema_version: SCHEMA_VERSION + 1 }), /schema_version/);
  assert.ok(checkManifest({ schema: SCHEMA_NAME, schema_version: SCHEMA_VERSION }));
  assert.ok(littleEndianHost());
});

test('a bundle written by av_common.BufferWriter reads back value for value', async (t) => {
  const dir = process.env.AV_BUNDLE_FIXTURE;
  if (!dir) return t.skip('AV_BUNDLE_FIXTURE not set (run through tests/test_viewer_js.py)');
  const fetchFn = async (url) => {
    const data = await readFile(join(dir, url.replace(/^fixture\//, '')));
    return { json: async () => JSON.parse(data.toString('utf8')), arrayBuffer: async () => data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) };
  };
  const b = await loadBundle('fixture/', fetchFn);
  const expect = b.manifest.test_expect;
  for (const [name, view] of Object.entries(b.manifest.test_views)) {
    const arr = Array.from(b.view(view));
    const want = expect[name];
    if (view.dtype === 'f16') assert.deepEqual(arr.map(halfToFloat), want, name);
    else if (view.dtype === 'f32') arr.forEach((v, i) => assert.ok(Math.abs(v - want[i]) < 1e-6, name));
    else assert.deepEqual(arr, want, name);
  }
});
