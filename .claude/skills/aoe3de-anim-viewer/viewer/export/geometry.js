// M5 geometry dump: the posed, CPU-skinned meshes of a rig at one time, packed into one binary file that
// scripts/metrics.py reads (rider-horse penetration, hoof height). Pure: no DOM, no GL (node --test packs and parses
// it in tests/js/export.test.mjs; metrics.py has the matching reader).
//
// File layout (little-endian):
//   bytes 0..7    magic 'AVGEOM1\0'
//   bytes 8..11   u32 header length H (bytes, a multiple of 4: the JSON is padded with spaces)
//   12 .. 12+H    header JSON (utf-8)
//   then          the arrays, each starting on a 4-byte boundary; header offsets count from the end of the header
// header: {version: 1, t, meta, instances: [{index, role, model, animfile, anim, variant, clip, clock, bones [names],
//          meshes: [{name, vertex_count, triangle_count, arrays: {posed, bind, indices, bone}}]}]}
//   posed    f32 x3  skinned positions in the engine frame (the viewer pose: rig.js skinPositions)
//   bind     f32 x3  the stored (bind) positions
//   indices  u32 x3  triangles as stored
//   bone     i16 x1  the bone (index into `bones`) with the largest weight of each vertex; -1 when none
import { skinPositions } from '../lib/rig.js';

export const GEOM_MAGIC = 'AVGEOM1\0';
export const GEOM_VERSION = 1;

// the dominant bone of every vertex of a mesh (bone index of the model, -1 when the mesh has no binding)
export function dominantBones(mesh, view) {
  const n = mesh.vertex_count;
  const out = new Int16Array(n).fill(-1);
  const binds = mesh.bone_bindings || [];
  const wv = mesh.streams.BoneWeights && mesh.streams.BoneWeights.view ? view(mesh.streams.BoneWeights.view) : null;
  const iv = mesh.streams.BoneIndices && mesh.streams.BoneIndices.view ? view(mesh.streams.BoneIndices.view) : null;
  const first = binds[0] ? binds[0].bone : -1;
  for (let v = 0; v < n; v++) {
    let best = -1, bw = 0;
    if (wv && iv) {
      for (let k = 0; k < 4; k++) {
        const w = wv[v * 4 + k];
        if (w > bw) { bw = w; best = iv[v * 4 + k]; }
      }
    }
    const slot = best >= 0 ? best : 0;
    out[v] = binds[slot] ? binds[slot].bone : first;
  }
  return out;
}

function bindPositions(mesh, view) {
  const pv = mesh.streams.Position && mesh.streams.Position.view;
  if (!pv) return new Float32Array(0);
  const src = view(pv), c = pv.components, n = mesh.vertex_count;
  const out = new Float32Array(n * 3);
  for (let v = 0; v < n; v++) { out[v * 3] = src[v * c]; out[v * 3 + 1] = src[v * c + 1]; out[v * 3 + 2] = src[v * c + 2]; }
  return out;
}

// {header, arrays} of a posed rig (call rig.pose(t) first); meta: any JSON the caller wants recorded
export function geometryParts(rig, view, t, meta = {}) {
  const arrays = [];
  let offset = 0;
  const put = (arr, dtype, components) => {
    const rec = { offset, dtype, count: components ? arr.length / components : arr.length, components };
    arrays.push(arr);
    offset += arr.byteLength;
    offset += (4 - (offset % 4)) % 4;
    return rec;
  };
  const instances = [];
  for (const inst of rig.instances) {
    if (!inst.worlds || !inst.model || !inst.model.decodable) continue;
    const meshes = [];
    for (const mesh of inst.model.meshes) {
      const posed = Float32Array.from(skinPositions(inst, mesh, view));
      const bind = bindPositions(mesh, view);
      const idx = mesh.indices ? Uint32Array.from(view(mesh.indices)) : new Uint32Array(0);
      const bone = dominantBones(mesh, view);
      meshes.push({ name: mesh.name || null, vertex_count: mesh.vertex_count, triangle_count: idx.length / 3,
        arrays: { posed: put(posed, 'f32', 3), bind: put(bind, 'f32', 3), indices: put(idx, 'u32', 3),
          bone: put(bone, 'i16', 1) } });
    }
    instances.push({ index: inst.index, role: inst.role, model: inst.model.id, animfile: inst.animfile, anim: inst.anim,
      variant: inst.variant, clip: inst.clip ? inst.clip.id : null, clock: inst.clock, clip_time: inst.time ?? null,
      bones: inst.model.names, meshes });
  }
  return { header: { version: GEOM_VERSION, t, meta, frame: 'engine (gr2), +Y up, the unit standing on y = 0',
    instances }, arrays };
}

// one Uint8Array in the layout above
export function packGeometry(header, arrays) {
  let json = JSON.stringify(header);
  const enc = new TextEncoder();
  let hb = enc.encode(json);
  const padN = (4 - (hb.length % 4)) % 4;
  if (padN) { json += ' '.repeat(padN); hb = enc.encode(json); }
  let dataLen = 0;
  for (const a of arrays) { dataLen += a.byteLength; dataLen += (4 - (dataLen % 4)) % 4; }
  const out = new Uint8Array(12 + hb.length + dataLen);
  for (let i = 0; i < 8; i++) out[i] = GEOM_MAGIC.charCodeAt(i);
  new DataView(out.buffer).setUint32(8, hb.length, true);
  out.set(hb, 12);
  let o = 12 + hb.length;
  for (const a of arrays) {
    out.set(new Uint8Array(a.buffer, a.byteOffset, a.byteLength), o);
    o += a.byteLength;
    o += (4 - ((o - 12 - hb.length) % 4)) % 4;
  }
  return out;
}

// the reader (node tests; metrics.py has its own): {header, array(meshRec, name) -> TypedArray}
export function unpackGeometry(bytes) {
  const u8 = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const magic = String.fromCharCode(...u8.subarray(0, 8));
  if (magic !== GEOM_MAGIC) throw new Error('not an AVGEOM1 file');
  const hl = new DataView(u8.buffer, u8.byteOffset, u8.byteLength).getUint32(8, true);
  const header = JSON.parse(new TextDecoder().decode(u8.subarray(12, 12 + hl)));
  const base = u8.byteOffset + 12 + hl;
  const T = { f32: Float32Array, u32: Uint32Array, i16: Int16Array };
  const array = (mesh, name) => {
    const r = mesh.arrays[name];
    const n = r.count * (r.components || 1);
    const C = T[r.dtype];
    const copy = u8.buffer.slice(base + r.offset, base + r.offset + n * C.BYTES_PER_ELEMENT);
    return new C(copy);
  };
  return { header, array };
}
