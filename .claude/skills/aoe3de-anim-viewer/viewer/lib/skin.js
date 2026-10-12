// GPU skinning: the bone palette of a mesh in an RGBA32F data texture (4 texels per bone = the 4 rows of the row-major
// skin matrix inverse_world @ world), 4 influences, linear blend - the equivalent of the game's structured bone buffer
// (materialdefault_VSMain, VERTEX_FORMAT_SkinnedPackedVertex: measured). Vertex streams are bound straight from the
// bundle's geo buffer, byte for byte (f32 position, snorm int8 normal, f32 or f16 UV, unorm u8 weights, u8 indices).
// A mesh without BoneWeights (a rigid mesh: the horse's 39-vertex piece, the torch) takes palette slot 0 = its first
// bone binding, or the instance placement when it has none (rig.skinPalette).
import { skinPalette } from './rig.js';

// texture unit for uploads (render.js binds the palette on unit 0, BaseColor 1, Details 2 at draw time)
export const UPLOAD_UNIT = 7;

// attribute locations
export const ATTRIB = { Position: 0, Normal: 1, TextureCoordinates0: 2, BoneWeights: 3, BoneIndices: 4 };

// GLSL: attributes plus skinMatrix(); the texel rows of bone i rebuild M^T as a GLSL mat4, so S * p = p @ M
export const SKIN_GLSL = `
layout(location = 0) in vec3 a_pos;
layout(location = 1) in vec3 a_nrm;
layout(location = 2) in vec2 a_uv;
layout(location = 3) in vec4 a_w;
layout(location = 4) in uvec4 a_i;
uniform highp sampler2D u_pal;
mat4 bone(uint i) {
  int x = int(i) * 4;
  return mat4(texelFetch(u_pal, ivec2(x, 0), 0), texelFetch(u_pal, ivec2(x + 1, 0), 0),
              texelFetch(u_pal, ivec2(x + 2, 0), 0), texelFetch(u_pal, ivec2(x + 3, 0), 0));
}
mat4 skinMatrix() {
  float ws = a_w.x + a_w.y + a_w.z + a_w.w;
  if (ws <= 0.0) return bone(0u);
  return a_w.x * bone(a_i.x) + a_w.y * bone(a_i.y) + a_w.z * bone(a_i.z) + a_w.w * bone(a_i.w);
}`;

// bundle dtype -> GL type name
const GL_TYPE = { f32: 'FLOAT', f16: 'HALF_FLOAT', i8: 'BYTE', u8: 'UNSIGNED_BYTE', i16: 'SHORT', u16: 'UNSIGNED_SHORT',
  i32: 'INT', u32: 'UNSIGNED_INT' };
const INDEX_BYTES = { u16: 2, u32: 4 };

export class MeshSkin {
  constructor(gl, bufferFor, mesh, view) {
    this.gl = gl;
    this.mesh = mesh;
    this.vao = gl.createVertexArray();
    gl.bindVertexArray(this.vao);
    this.bound = [];
    for (const [name, loc] of Object.entries(ATTRIB)) {
      const s = mesh.streams[name];
      const v = s && s.view;
      if (!v) {
        gl.disableVertexAttribArray(loc);
        if (name === 'BoneIndices') gl.vertexAttribI4ui(loc, 0, 0, 0, 0);
        else if (name === 'Normal') gl.vertexAttrib4f(loc, 0, 1, 0, 0);
        else gl.vertexAttrib4f(loc, 0, 0, 0, 0);
        continue;
      }
      gl.enableVertexAttribArray(loc);
      gl.bindBuffer(gl.ARRAY_BUFFER, bufferFor(v.buffer));
      const type = gl[GL_TYPE[v.dtype]];
      if (name === 'BoneIndices') gl.vertexAttribIPointer(loc, Math.min(v.components, 4), type, 0, v.byteOffset);
      else gl.vertexAttribPointer(loc, Math.min(v.components, 4), type, !!v.normalized, 0, v.byteOffset);
      this.bound.push(name);
    }
    this.indexType = mesh.indices.dtype === 'u32' ? gl.UNSIGNED_INT : gl.UNSIGNED_SHORT;
    this.indexBytes = INDEX_BYTES[mesh.indices.dtype] || 2;
    this.ibo = gl.createBuffer();                       // WebGL: an index buffer cannot share the vertex buffer
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.ibo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, view(mesh.indices), gl.STATIC_DRAW);
    gl.bindVertexArray(null);
    this.slots = Math.max((mesh.bone_bindings || []).length, 1);
    this.palette = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0 + UPLOAD_UNIT);
    gl.bindTexture(gl.TEXTURE_2D, this.palette);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texStorage2D(gl.TEXTURE_2D, 1, gl.RGBA32F, this.slots * 4, 1);
  }

  updatePalette(inst) {
    const gl = this.gl;
    const pal = skinPalette(inst.model, this.mesh, inst.worlds, inst.placement);
    gl.activeTexture(gl.TEXTURE0 + UPLOAD_UNIT);
    gl.bindTexture(gl.TEXTURE_2D, this.palette);
    gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, this.slots * 4, 1, gl.RGBA, gl.FLOAT, pal);
  }

  drawGroup(g) {
    this.gl.drawElements(this.gl.TRIANGLES, g.triangle_count * 3, this.indexType, g.first_triangle * 3 * this.indexBytes);
  }
}
