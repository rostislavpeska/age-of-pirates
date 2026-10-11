// S3TC (BC1 / DXT1, BC3 / DXT5) helpers: GL format enums, sizes, block builders and a CPU reference decoder.
// Pure module (no DOM): the M0 spike uses it in the page, tests/js/s3tc.test.mjs runs it under `node --test`.
// The decoder follows the D3D10+ BC rules the game's textures are authored for: a BC1 block whose colour0 <= colour1
// is in 3-colour mode with index 3 = transparent black (RGBA_DXT1, i.e. D3D11 BC1); a BC3 colour block is always
// 4-colour. 565 colours expand by bit replication; interpolation is done in float without rounding, so a GPU result
// may differ by about 1/255 (the D3D spec allows a small interpolation error).

export const RGB_DXT1 = 0x83f0;
export const RGBA_DXT1 = 0x83f1;
export const RGBA_DXT3 = 0x83f2;
export const RGBA_DXT5 = 0x83f3;
export const SRGB_DXT1 = 0x8c4c;
export const SRGB_ALPHA_DXT1 = 0x8c4d;
export const SRGB_ALPHA_DXT3 = 0x8c4e;
export const SRGB_ALPHA_DXT5 = 0x8c4f;

export const FORMAT_NAMES = {
  [RGB_DXT1]: 'COMPRESSED_RGB_S3TC_DXT1_EXT',
  [RGBA_DXT1]: 'COMPRESSED_RGBA_S3TC_DXT1_EXT',
  [RGBA_DXT3]: 'COMPRESSED_RGBA_S3TC_DXT3_EXT',
  [RGBA_DXT5]: 'COMPRESSED_RGBA_S3TC_DXT5_EXT',
  [SRGB_DXT1]: 'COMPRESSED_SRGB_S3TC_DXT1_EXT',
  [SRGB_ALPHA_DXT1]: 'COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT',
  [SRGB_ALPHA_DXT3]: 'COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT',
  [SRGB_ALPHA_DXT5]: 'COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT',
};

const BC1_FORMATS = new Set([RGB_DXT1, RGBA_DXT1, SRGB_DXT1, SRGB_ALPHA_DXT1]);
const BC3_FORMATS = new Set([RGBA_DXT5, SRGB_ALPHA_DXT5]);
const SRGB_FORMATS = new Set([SRGB_DXT1, SRGB_ALPHA_DXT1, SRGB_ALPHA_DXT3, SRGB_ALPHA_DXT5]);

export function isSrgb(format) { return SRGB_FORMATS.has(format); }

export function blockBytes(format) {
  if (BC1_FORMATS.has(format)) return 8;
  if (BC3_FORMATS.has(format) || format === RGBA_DXT3 || format === SRGB_ALPHA_DXT3) return 16;
  throw new Error('not an S3TC format: 0x' + format.toString(16));
}

// bytes of one mip level: whole 4x4 blocks, at least one
export function levelByteLength(format, width, height) {
  return Math.max(1, Math.ceil(width / 4)) * Math.max(1, Math.ceil(height / 4)) * blockBytes(format);
}

// 8-bit r, g, b -> 565 word (truncating, as an encoder that keeps the high bits)
export function pack565(r, g, b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}

// 565 word -> [r, g, b] in 0..255 by bit replication
export function unpack565(c) {
  const r = (c >> 11) & 31, g = (c >> 5) & 63, b = c & 31;
  return [(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)];
}

// one BC1 block: colour words c0, c1 and 16 two-bit indices (texel i = row i>>2, column i&3)
export function makeBC1Block(c0, c1, indices) {
  if (indices.length !== 16) throw new Error('a BC1 block needs 16 indices');
  const out = new Uint8Array(8);
  out[0] = c0 & 255; out[1] = c0 >> 8; out[2] = c1 & 255; out[3] = c1 >> 8;
  for (let i = 0; i < 16; i++) out[4 + (i >> 2)] |= (indices[i] & 3) << ((i & 3) * 2);
  return out;
}

// one BC3 block: alpha endpoints a0, a1, 16 three-bit alpha indices, then the BC1 colour block
export function makeBC3Block(a0, a1, alphaIndices, c0, c1, colorIndices) {
  if (alphaIndices.length !== 16) throw new Error('a BC3 block needs 16 alpha indices');
  const out = new Uint8Array(16);
  out[0] = a0; out[1] = a1;
  for (let i = 0; i < 16; i++) {
    const v = alphaIndices[i] & 7;
    for (let b = 0; b < 3; b++) {
      if (v & (1 << b)) { const bit = 3 * i + b; out[2 + (bit >> 3)] |= 1 << (bit & 7); }
    }
  }
  out.set(makeBC1Block(c0, c1, colorIndices), 8);
  return out;
}

export function concatBytes(parts) {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}

// NVIDIA's hardware BC1 interpolation: integer maths on the 5-bit red/blue and the expanded 8-bit green, in the form
// of the NVIDIA mode of bc7enc's rgbcx (Rich Geldreich; written from that description, no code copied). Verified only
// on the M0 spike's blocks, RTX 4070 Ti SUPER through ANGLE D3D11, 2026-10-11: green 175 / 80 where the exact thirds
// are 170 / 85, the 3-colour half 127 for 127.5 - every colour texel within half-float rounding.
function nvThird5(a, b) { return Math.floor(((2 * a + b) * 22) / 8); }            // (2a + b) / 3, 5-bit inputs
function nvThird6(g0, g1) { const d = g1 - g0; return Math.floor((256 * g0 + Math.trunc(d / 4) + 128 + d * 80) / 256); }
function nvHalf5(a, b) { return Math.floor(((a + b) * 33) / 8); }
function nvHalf6(g0, g1) { const d = g1 - g0; return Math.floor((256 * g0 + Math.trunc(d / 4) + 128 + d * 128) / 256); }

function bc1Palette(w0, w1, fourColour, punchThrough, model) {
  const e0 = unpack565(w0), e1 = unpack565(w1);
  const pal = [[...e0.map((v) => v / 255), 1], [...e1.map((v) => v / 255), 1]];
  const four = fourColour || w0 > w1;
  if (model === 'nvidia') {
    const r0 = (w0 >> 11) & 31, b0 = w0 & 31, r1 = (w1 >> 11) & 31, b1 = w1 & 31;
    if (four) {
      pal.push([nvThird5(r0, r1), nvThird6(e0[1], e1[1]), nvThird5(b0, b1)].map((v) => v / 255).concat(1));
      pal.push([nvThird5(r1, r0), nvThird6(e1[1], e0[1]), nvThird5(b1, b0)].map((v) => v / 255).concat(1));
    } else {
      pal.push([nvHalf5(r0, r1), nvHalf6(e0[1], e1[1]), nvHalf5(b0, b1)].map((v) => v / 255).concat(1));
    }
  } else if (model === 'exact') {
    const c0 = pal[0], c1 = pal[1];
    if (four) {
      pal.push([0, 1, 2].map((k) => (2 * c0[k] + c1[k]) / 3).concat(1));
      pal.push([0, 1, 2].map((k) => (c0[k] + 2 * c1[k]) / 3).concat(1));
    } else {
      pal.push([0, 1, 2].map((k) => (c0[k] + c1[k]) / 2).concat(1));
    }
  } else {
    throw new Error('BC1 model: exact or nvidia, not ' + model);
  }
  if (!four) pal.push(punchThrough ? [0, 0, 0, 0] : [0, 0, 0, 1]);
  return pal;
}

// BC1 block at `offset` -> 16 RGBA texels as floats 0..1 (row-major). fourColour forces 4-colour mode (BC2/BC3);
// punchThrough = index 3 of 3-colour mode is transparent black (RGBA_DXT1 / D3D11 BC1), else opaque black.
// model 'exact' = float interpolation (SwiftShader matches it within 0.5/255), 'nvidia' = NVIDIA's hardware rounding.
export function decodeBC1Block(bytes, offset = 0, { fourColour = false, punchThrough = true, model = 'exact' } = {}) {
  const w0 = bytes[offset] | (bytes[offset + 1] << 8);
  const w1 = bytes[offset + 2] | (bytes[offset + 3] << 8);
  const pal = bc1Palette(w0, w1, fourColour, punchThrough, model);
  const out = new Float32Array(64);
  for (let i = 0; i < 16; i++) {
    const idx = (bytes[offset + 4 + (i >> 2)] >> ((i & 3) * 2)) & 3;
    out.set(pal[idx], 4 * i);
  }
  return out;
}

// BC3 alpha block at `offset` -> 16 alphas 0..1
export function decodeBC3Alpha(bytes, offset = 0) {
  const a0 = bytes[offset], a1 = bytes[offset + 1];
  const pal = [a0, a1];
  if (a0 > a1) for (let i = 1; i <= 6; i++) pal.push(((7 - i) * a0 + i * a1) / 7);
  else {
    for (let i = 1; i <= 4; i++) pal.push(((5 - i) * a0 + i * a1) / 5);
    pal.push(0, 255);
  }
  const out = new Float32Array(16);
  for (let i = 0; i < 16; i++) {
    let v = 0;
    for (let b = 0; b < 3; b++) {
      const bit = 3 * i + b;
      if (bytes[offset + 2 + (bit >> 3)] & (1 << (bit & 7))) v |= 1 << b;
    }
    out[i] = pal[v] / 255;
  }
  return out;
}

// BC3 block: the colour part with the given BC1 model; the alpha part always exact (NVIDIA's alpha rounding is not
// modelled: the M0 spike measured up to 6/255 there).
export function decodeBC3Block(bytes, offset = 0, { model = 'exact' } = {}) {
  const rgba = decodeBC1Block(bytes, offset + 8, { fourColour: true, model });
  const alpha = decodeBC3Alpha(bytes, offset);
  for (let i = 0; i < 16; i++) rgba[4 * i + 3] = alpha[i];
  return rgba;
}

export function srgbToLinear(c) {
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

// a whole BC1 / BC3 level -> Float32Array RGBA (row 0 = the first block row of the data). sRGB formats are returned
// as stored (gamma-encoded); apply srgbToLinear to compare with what the GPU samples. model: see decodeBC1Block.
export function decodeLevel(format, width, height, bytes, { model = 'exact' } = {}) {
  const bc3 = BC3_FORMATS.has(format);
  if (!bc3 && !BC1_FORMATS.has(format)) throw new Error('decodeLevel: BC1 or BC3 only');
  const bpb = blockBytes(format), bw = Math.max(1, Math.ceil(width / 4)), bh = Math.max(1, Math.ceil(height / 4));
  if (bytes.length < bw * bh * bpb) throw new Error('decodeLevel: data too short');
  const out = new Float32Array(width * height * 4);
  for (let by = 0; by < bh; by++) {
    for (let bx = 0; bx < bw; bx++) {
      const off = (by * bw + bx) * bpb;
      const px = bc3 ? decodeBC3Block(bytes, off, { model })
        : decodeBC1Block(bytes, off, { punchThrough: format !== RGB_DXT1 && format !== SRGB_DXT1, model });
      for (let i = 0; i < 16; i++) {
        const x = 4 * bx + (i & 3), y = 4 * by + (i >> 2);
        if (x < width && y < height) out.set(px.subarray(4 * i, 4 * i + 4), 4 * (y * width + x));
      }
    }
  }
  return out;
}

// RGBA float -> RGBA8 bytes (the CPU fallback upload when the S3TC extension is missing)
export function toRGBA8(f32) {
  const out = new Uint8Array(f32.length);
  for (let i = 0; i < f32.length; i++) out[i] = Math.max(0, Math.min(255, Math.round(f32[i] * 255)));
  return out;
}

export function toHex(bytes) {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}
