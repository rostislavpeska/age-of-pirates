// The M0 spike's synthetic 8x8 textures (2x2 blocks, block order row-major). No game bytes: every block is built here.
//   DXT1: (0,0) red > blue, 4-colour ramp | (1,0) green < white, 3-colour mode, index 3 transparent
//         (0,1) solid 565 grey 0x8410 (sRGB decode check: 132/255 -> 0.2307 linear) | (1,1) yellow > black diagonal
//   DXT5: the same colour blocks (always 4-colour in BC3, so block (1,0) has no transparent texel) with an 8-value
//         alpha ramp, a 6-value ramp (indices 6 and 7 = 0 and 255), a solid 128 and a 200..40 diagonal.
import { makeBC1Block, makeBC3Block, concatBytes } from '../lib/s3tc.js';

const RAMP = [0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3];
const DIAG = [0, 1, 2, 3, 1, 2, 3, 0, 2, 3, 0, 1, 3, 0, 1, 2];
const ZERO = new Array(16).fill(0);
const COLOURS = [
  [0xf800, 0x001f, RAMP],   // red, blue
  [0x07e0, 0xffff, RAMP],   // green, white
  [0x8410, 0x8410, ZERO],   // grey
  [0xffe0, 0x0000, DIAG],   // yellow, black
];
const ALPHAS = [
  [255, 0, [0, 2, 3, 4, 5, 6, 7, 1, 0, 2, 3, 4, 5, 6, 7, 1]],
  [0, 255, [0, 1, 2, 3, 4, 5, 6, 7, 7, 6, 5, 4, 3, 2, 1, 0]],
  [128, 128, ZERO],
  [200, 40, [0, 2, 4, 6, 1, 3, 5, 7, 7, 5, 3, 1, 6, 4, 2, 0]],
];

export function spikeTextures() {
  return {
    width: 8,
    height: 8,
    dxt1: concatBytes(COLOURS.map(([c0, c1, idx]) => makeBC1Block(c0, c1, idx))),
    dxt5: concatBytes(COLOURS.map(([c0, c1, idx], i) => makeBC3Block(ALPHAS[i][0], ALPHAS[i][1], ALPHAS[i][2], c0, c1, idx))),
  };
}
