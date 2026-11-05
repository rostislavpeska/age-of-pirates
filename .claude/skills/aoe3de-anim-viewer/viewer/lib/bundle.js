// Bundle reader (references/bundle-schema.md): manifest checks and typed-array views into the binary buffers.
// Pure except loadBundle's fetch; tests/js/bundle.test.mjs checks it on a fixture written by scripts/av_common.py.

export const SCHEMA_NAME = 'aop-anim-viewer/bundle';
export const SCHEMA_VERSION = 0;
export const ALIGN = 16;

// f16 stays raw (Uint16Array): it is uploaded as gl.HALF_FLOAT; halfToFloat reads one value on the CPU
export const DTYPES = {
  f32: Float32Array, f16: Uint16Array, u8: Uint8Array, i8: Int8Array,
  u16: Uint16Array, i16: Int16Array, u32: Uint32Array, i32: Int32Array,
};

export function littleEndianHost() {
  return new Uint8Array(new Uint16Array([1]).buffer)[0] === 1;
}

export function checkManifest(m) {
  if (!m || m.schema !== SCHEMA_NAME) throw new Error('not a viewer bundle: schema ' + (m && m.schema));
  if (m.schema_version !== SCHEMA_VERSION) {
    throw new Error('bundle schema_version ' + m.schema_version + ', this viewer reads ' + SCHEMA_VERSION);
  }
  return m;
}

// view {buffer, byteOffset, byteLength, dtype, count, components} -> typed array over buffers[view.buffer]
export function viewArray(buffers, view) {
  const T = DTYPES[view.dtype];
  if (!T) throw new Error('unknown dtype ' + view.dtype);
  const buf = buffers[view.buffer];
  if (!buf) throw new Error('missing buffer ' + view.buffer);
  if (view.byteOffset % ALIGN) throw new Error('view not 16-byte aligned: ' + view.byteOffset);
  const n = view.count * view.components;
  if (view.byteLength !== n * T.BYTES_PER_ELEMENT) throw new Error('view byteLength does not match count');
  if (view.byteOffset + view.byteLength > buf.byteLength) throw new Error('view runs past its buffer');
  return new T(buf, view.byteOffset, n);
}

export function halfToFloat(h) {
  const s = h & 0x8000 ? -1 : 1, e = (h >> 10) & 31, f = h & 1023;
  if (e === 0) return s * Math.pow(2, -14) * (f / 1024);
  if (e === 31) return f ? NaN : s * Infinity;
  return s * Math.pow(2, e - 15) * (1 + f / 1024);
}

// fetch manifest.json and every buffer below baseUrl ('/bundle/<id>/'); returns {manifest, buffers, view}
export async function loadBundle(baseUrl, fetchFn = globalThis.fetch) {
  if (!littleEndianHost()) throw new Error('bundle buffers are little-endian; this host is not');
  const manifest = checkManifest(await (await fetchFn(baseUrl + 'manifest.json')).json());
  const buffers = {};
  for (const b of manifest.buffers || []) {
    const ab = await (await fetchFn(baseUrl + b.uri)).arrayBuffer();
    if (ab.byteLength !== b.byteLength) throw new Error('buffer ' + b.id + ': ' + ab.byteLength + ' bytes, manifest says ' + b.byteLength);
    buffers[b.id] = ab;
  }
  return { manifest, buffers, view: (v) => viewArray(buffers, v) };
}
