// Shared by the parity tests: a bundle folder on disk read with viewer/lib/bundle.js (no server, no browser), and the
// fixture JSON that tests/test_parity_js.py writes.
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { loadBundle } from '../../../viewer/lib/bundle.js';

export async function loadBundleDir(dir) {
  const fetchFn = async (rel) => {
    const data = await readFile(join(dir, rel));
    return {
      json: async () => JSON.parse(data.toString('utf8')),
      arrayBuffer: async () => data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength),
    };
  };
  return loadBundle('', fetchFn);
}

export async function readFixture(envName) {
  const p = process.env[envName];
  if (!p) return null;
  return JSON.parse((await readFile(p)).toString('utf8'));
}

export function maxAbsDiff(a, b) {
  if (a.length !== b.length) return Infinity;
  let m = 0;
  for (let i = 0; i < a.length; i++) m = Math.max(m, Math.abs(a[i] - b[i]));
  return m;
}
