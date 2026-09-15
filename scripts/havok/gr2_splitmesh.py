"""Granny-level sail split: cut the sail cloth/bar triangles out of the vanilla meshes into new rigid meshes bound
to the rig's sail bones, WITHOUT touching a single vertex byte (the converter re-encodes vertex data and the engine
shades its output dark). Works on the uncompressed vanilla gr2 that gr2_addbones.py already gave the rig bones.

What is written (all appended at the end of the sections, nothing existing moves):
  section 1: a copy of each sail's vertex bytes (exact 24-byte vanilla vertices)     section 2: new int32 index lists
  section 0: per sail a VertexData record (same vertex type, same component names), a TriTopology (one group), a
             BoneBinding (bone from the rig, OBB from the vertices) and a Mesh record sharing the source mesh's
             material binding; per source mesh a replacement TriTopology with the remaining triangles;
             new pointer arrays for root.Meshes / root.TriTopologies / root.VertexDatas and Model.MeshBindings.
Labels come from the rig build's GXO (converter dump of the Blender rig): a vanilla vertex is a sail vertex when it
coincides with a vertex of a rig sail mesh (frame: engine = MIRROR . gxo, the appender's map).

usage: python gr2_splitmesh.py bones.gr2 rig.gxo out.gr2
"""
import sys, struct, zlib, itertools, collections
import numpy as np
from gr2_read import Gr2
from gr2_dump import refs
from gxo_sails import parse
from gr2_addbones import MAPS

P = 8                                                        # pointer size (64-bit file, 4-byte aligned)


class Builder:
    """append-only writer for the three sections + relocation bookkeeping"""
    def __init__(self, g):
        self.g = g; self.sec = [bytearray(p) for p in g.payload]
        self.relocs = {i: [] for i in range(g.sec_count)}
        d = g.data
        for i, s in enumerate(g.sections):
            for k in range(s['reloc_count']):
                self.relocs[i].append(list(struct.unpack_from('<III', d, s['reloc_off'] + 12 * k)))
    def alloc(self, sec, data, align=4):
        while len(self.sec[sec]) % align: self.sec[sec].append(0)
        off = len(self.sec[sec]); self.sec[sec].extend(data); return off
    def string(self, s): return (0, self.alloc(0, s.encode() + b'\0', 1))
    def ptr(self, sec, off, target):                          # pointer field at (sec, off) -> target (tsec, toff)
        if target is None: return
        self.relocs[sec].append([off, target[0], target[1]])
    def repoint(self, sec, off, target):                      # change an existing pointer field's target
        for r in self.relocs[sec]:
            if r[0] == off: r[1], r[2] = target; return
        raise KeyError((sec, off))
    def i32(self, sec, off, v): struct.pack_into('<i', self.sec[sec], off, v)
    def write(self, out):
        g = self.g; d = g.data
        marsh = [bytes(d[s['marsh_off']:s['marsh_off'] + 16 * s['marsh_count']]) if s['marsh_count'] else b'' for s in g.sections]
        o = bytearray(d[:g.sec_table + 44 * g.sec_count]); hdr = []
        for i, s in enumerate(g.sections):
            while len(o) % 4: o.append(0)
            data_off = len(o); o.extend(self.sec[i])
            hdr.append([0, data_off, len(self.sec[i]), len(self.sec[i]), s['align'], s['first16'], s['first8'], 0, len(self.relocs[i]), 0, s['marsh_count']])
        for i in range(g.sec_count):
            while len(o) % 4: o.append(0)
            hdr[i][7] = len(o)
            for so, ts, to in sorted(self.relocs[i]): o.extend(struct.pack('<III', so, ts, to))
            while len(o) % 4: o.append(0)
            hdr[i][9] = len(o); o.extend(marsh[i])
        for i, h in enumerate(hdr): struct.pack_into('<11I', o, g.sec_table + 44 * i, *h)
        struct.pack_into('<I', o, 32 + 4, len(o))
        struct.pack_into('<I', o, 32 + 8, zlib.crc32(bytes(o[g.sec_table:])) & 0xffffffff)
        open(out, 'wb').write(o)


def member_offsets(g, tref, names):
    lay = {m['name']: off for m, off in g.layout(*tref)[0]}
    return [lay[n] for n in names]


def main():
    src, rigp, outp = sys.argv[1:4]
    g = Gr2(src); assert g.ptr == 8 and g.crc_check(); r = g.root()
    rh, rb, rm = parse(rigp)
    M = MAPS['mirror']                                       # engine = M . gxo  ->  gxo = M.T . engine
    grid = {}; rig_mb = {}
    for m in rm:
        if m['name'].startswith('sail_'):
            rig_mb[m['name']] = m['mb'][0]
            for p in m['v']: grid[tuple(np.round(np.array(p) / 0.01).astype(int))] = m['name']
    def look(p):
        k = tuple(np.round(p / 0.01).astype(int))
        if k in grid: return grid[k]
        for dd in itertools.product((-1, 0, 1), repeat=3):
            kk = (k[0] + dd[0], k[1] + dd[1], k[2] + dd[2])
            if kk in grid: return grid[kk]
        return None

    # layouts (asserted against the file's own type definitions)
    mesh_t = r['Meshes'][3]; topo_t = None; vd_t = None; model_t = r['Models'][3]
    MESH = dict(zip(['Name', 'PrimaryVertexData', 'MorphTargets', 'PrimaryTopology', 'MaterialBindings', 'BoneBindings', 'ExtendedData'],
                    member_offsets(g, mesh_t, ['Name', 'PrimaryVertexData', 'MorphTargets', 'PrimaryTopology', 'MaterialBindings', 'BoneBindings', 'ExtendedData'])))
    assert MESH == {'Name': 0, 'PrimaryVertexData': 8, 'MorphTargets': 16, 'PrimaryTopology': 28, 'MaterialBindings': 36, 'BoneBindings': 48, 'ExtendedData': 60}
    ROOT_MESHES, ROOT_TOPOS, ROOT_VDS = member_offsets(g, (g.root_type_sec, g.root_type_off), ['Meshes', 'TriTopologies', 'VertexDatas'])
    B = Builder(g)
    meshes = refs(g, r['Meshes']); model, model_loc = refs(g, r['Models'])[0]
    MODEL_MB = member_offsets(g, model_t, ['MeshBindings'])[0]

    new_mesh_ptrs = []; new_topo_ptrs = []; new_vd_ptrs = []; report = []
    for mrec, mloc in meshes:
        vd = mrec['PrimaryVertexData']; vloc = vd[1]; vrec = g.read(*vd[2], *vloc); va = vrec['Vertices']
        vtype, nverts, vdata = va[1], va[2], va[3]; stride = g.struct_size(*vtype); assert stride == 24
        vbuf = g.payload[vdata[0]]; vbase = vdata[1]
        pos = np.array([struct.unpack_from('<3f', vbuf, vbase + i * stride) for i in range(nverts)])
        labels = [look(p) for p in (pos @ M)]                # engine -> gxo frame (M orthogonal: M.T applied as pos @ M)
        tt = mrec['PrimaryTopology']; top = g.read(*tt[2], *tt[1]); topo_t = tt[2]; vd_t = vd[2]
        idx = top['Indices']; assert idx[0] == 'array' and idx[1] and top['Indices16'][1] == 0
        ibuf = g.payload[idx[2][0]]; ind = np.frombuffer(bytes(ibuf[idx[2][1]:idx[2][1] + 4 * idx[1]]), dtype='<i4').reshape(-1, 3)
        groups = g.array(top['Groups']); assert len(groups) == 1 and groups[0]['TriFirst'][0] == 0 and groups[0]['TriCount'][0] == len(ind)
        by = collections.defaultdict(list); hull = []
        for tri in ind:
            ls = {labels[i] for i in tri}
            if len(ls) == 1 and None not in ls: by[ls.pop()].append(tri)
            else: hull.append(tri)
        # --- new sail meshes from this source mesh
        for name in sorted(by):
            tris = np.array(by[name]); used = []; remap = {}
            for i in tris.flatten():
                if i not in remap: remap[i] = len(used); used.append(i)
            vbytes = b''.join(bytes(vbuf[vbase + i * stride: vbase + (i + 1) * stride]) for i in used)
            voff = B.alloc(1, vbytes, 4)
            new_ind = np.vectorize(remap.get)(tris).astype('<i4').tobytes(); ioff = B.alloc(2, new_ind, 4)
            # VertexData record: Vertices (type ptr, count, data ptr) + VertexComponentNames (shared) + VertexAnnotationSets (none)
            vdo = B.alloc(0, bytes(44)); B.ptr(0, vdo, vtype); B.i32(0, vdo + 8, len(used)); B.ptr(0, vdo + 12, (1, voff))
            vcn = vrec['VertexComponentNames']; B.i32(0, vdo + 20, vcn[1]); B.ptr(0, vdo + 24, vcn[2])
            # TriTopology record: one group, int32 indices
            grp = B.alloc(0, struct.pack('<3i', 0, 0, len(tris)))
            tpo = B.alloc(0, bytes(132)); B.i32(0, tpo, 1); B.ptr(0, tpo + 4, (0, grp)); B.i32(0, tpo + 12, 3 * len(tris)); B.ptr(0, tpo + 16, (2, ioff))
            # BoneBinding: bone name, OBB, no triangle list (as vanilla)
            sub = pos[used]; bbo = B.alloc(0, bytes(44)); B.ptr(0, bbo, B.string(rig_mb[name]))
            struct.pack_into('<6f', B.sec[0], bbo + 8, *sub.min(0), *sub.max(0))
            # Mesh record
            mo = B.alloc(0, bytes(76)); B.ptr(0, mo, B.string(name)); B.ptr(0, mo + 8, (0, vdo)); B.ptr(0, mo + 28, (0, tpo))
            mb = mrec['MaterialBindings']; B.i32(0, mo + 36, mb[1]); B.ptr(0, mo + 40, mb[2])
            B.i32(0, mo + 48, 1); B.ptr(0, mo + 52, (0, bbo))
            ext = mrec['ExtendedData']
            if ext and ext[0] == 'variant': B.ptr(0, mo + 60, ext[1]); B.ptr(0, mo + 68, ext[2])
            new_mesh_ptrs.append((0, mo)); new_topo_ptrs.append((0, tpo)); new_vd_ptrs.append((0, vdo))
            report.append((name, rig_mb[name], len(used), len(tris)))
        # --- the source mesh keeps its vertex data, gets a topology with the remaining triangles
        hull = np.array(hull); ioff = B.alloc(2, hull.astype('<i4').tobytes(), 4)
        grp = B.alloc(0, struct.pack('<3i', 0, 0, len(hull)))
        tpo = B.alloc(0, bytes(132)); B.i32(0, tpo, 1); B.ptr(0, tpo + 4, (0, grp)); B.i32(0, tpo + 12, 3 * len(hull)); B.ptr(0, tpo + 16, (2, ioff))
        B.repoint(mloc[0], mloc[1] + 28, (0, tpo)); new_topo_ptrs.append((0, tpo))
        report.append((mrec['Name'], mrec['BoneBindings'] and g.array(mrec['BoneBindings'])[0]['BoneName'], nverts, len(hull)))

    # --- root arrays and the model's mesh bindings
    def refarray(field_sec, field_off, old, new_ptrs):
        n = old[1]; ptrs = [g.deref(old[2][0], old[2][1] + i * P) for i in range(n)] + new_ptrs
        arr = B.alloc(0, bytes(P * len(ptrs)))
        for i, tp in enumerate(ptrs): B.ptr(0, arr + i * P, tp)
        B.i32(field_sec, field_off, len(ptrs)); B.repoint(field_sec, field_off + 4, (0, arr))
        return ptrs
    all_meshes = refarray(g.root_sec, g.root_off + ROOT_MESHES, r['Meshes'], new_mesh_ptrs)
    refarray(g.root_sec, g.root_off + ROOT_TOPOS, r['TriTopologies'], new_topo_ptrs)
    refarray(g.root_sec, g.root_off + ROOT_VDS, r['VertexDatas'], new_vd_ptrs)
    mbs = B.alloc(0, bytes(P * len(all_meshes)))
    for i, tp in enumerate(all_meshes): B.ptr(0, mbs + i * P, tp)
    B.i32(model_loc[0], model_loc[1] + MODEL_MB, len(all_meshes)); B.repoint(model_loc[0], model_loc[1] + MODEL_MB + 4, (0, mbs))
    B.write(outp)
    for n, bone, nv, nt in report: print(f'   {n:40} bone={bone:34} verts={nv:6d} tris={nt:6d}')
    g2 = Gr2(outp); r2 = g2.root()
    print(f'wrote {outp}: crc ok {g2.crc_check()}, meshes {r2["Meshes"][1]}, topologies {r2["TriTopologies"][1]}, vertexdatas {r2["VertexDatas"][1]}, sections', [(i, s["data_size"]) for i, s in enumerate(g2.sections) if s["data_size"]])


if __name__ == '__main__':
    main()
