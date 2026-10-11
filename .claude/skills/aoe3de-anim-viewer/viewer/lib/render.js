// WebGL2 drawing of a posed rig: skinned meshes (skin.js palette), the M2 placeholder material, bones and a ground grid.
// Browser-only. The game shader (materialdefault + lightingpass, design section 2) replaces the placeholder in M3.
//
// Placeholder material (fidelity 'A', labelled in the page): BaseColor sampled through the raw S3TC upload (sRGB slot ->
// the sRGB S3TC format, so the GPU decodes and linearises as the game does), player colour lerp(base, base*pc,
// Details.R) (the measured materialdefault rule; pc = playercolors color1 as sRGB/255, a guess), cutout at 0.5 when the
// materialdef says so, Lambert sun + flat ambient, sRGB encoding at the end. Both faces are drawn (the display frame
// flips the winding; double-sided materials need it anyway).
import { createProgram, drainErrors } from './gl.js';
import * as S3 from './s3tc.js';
import { DISPLAY } from './camera.js';
import { MeshSkin, SKIN_GLSL, UPLOAD_UNIT } from './skin.js';
// Uploads use their own texture unit (UPLOAD_UNIT): creating a texture on the active unit once replaced the bone
// palette bound on unit 0 in the middle of the first draw, and that frame skinned with BC blocks read as floats.

const VS = `#version 300 es
precision highp float;
precision highp int;
${SKIN_GLSL}
uniform mat4 u_viewProj;
uniform mat4 u_display;
out vec3 v_nrm;
out vec2 v_uv;
out vec3 v_pos;
void main() {
  mat4 S = skinMatrix();
  vec4 p = u_display * (S * vec4(a_pos, 1.0));
  v_pos = p.xyz;
  v_nrm = mat3(u_display) * (mat3(S) * a_nrm);
  v_uv = a_uv;
  gl_Position = u_viewProj * p;
}`;

const FS = `#version 300 es
precision highp float;
in vec3 v_nrm;
in vec2 v_uv;
in vec3 v_pos;
uniform sampler2D u_base;
uniform sampler2D u_details;
uniform int u_hasBase;
uniform int u_hasDetails;
uniform int u_cutout;
uniform vec3 u_sun;
uniform vec3 u_eye;
uniform vec3 u_pc;
uniform vec3 u_fallback;
uniform float u_ambient;
out vec4 o;
vec3 srgbEncode(vec3 c) {
  c = clamp(c, 0.0, 1.0);
  return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}
void main() {
  vec4 base = u_hasBase == 1 ? texture(u_base, v_uv) : vec4(u_fallback, 1.0);
  if (u_cutout == 1 && base.a < 0.5) discard;
  if (u_hasDetails == 1) base.rgb = mix(base.rgb, base.rgb * u_pc, texture(u_details, v_uv).r);
  vec3 n = normalize(v_nrm);
  if (dot(n, u_eye - v_pos) < 0.0) n = -n;
  float lam = max(dot(n, normalize(u_sun)), 0.0);
  o = vec4(srgbEncode(base.rgb * (u_ambient + (1.0 - u_ambient) * lam)), 1.0);
}`;

const LINE_VS = `#version 300 es
precision highp float;
layout(location = 0) in vec3 a_p;
layout(location = 1) in vec3 a_c;
uniform mat4 u_viewProj;
out vec3 v_c;
void main() { v_c = a_c; gl_Position = u_viewProj * vec4(a_p, 1.0); gl_PointSize = 5.0; }`;

const LINE_FS = `#version 300 es
precision highp float;
in vec3 v_c;
out vec4 o;
void main() { o = vec4(v_c, 1.0); }`;

const BC_FORMATS = {
  BC1: [S3.RGBA_DXT1, S3.SRGB_ALPHA_DXT1],
  BC2: [S3.RGBA_DXT3, S3.SRGB_ALPHA_DXT3],
  BC3: [S3.RGBA_DXT5, S3.SRGB_ALPHA_DXT5],
};

function srgbToLinear(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }

export class Renderer {
  constructor(gl, bundle) {
    this.gl = gl;
    this.bundle = bundle;
    this.ext = {
      s3tc: gl.getExtension('WEBGL_compressed_texture_s3tc'),
      s3tc_srgb: gl.getExtension('WEBGL_compressed_texture_s3tc_srgb'),
    };
    this.prog = createProgram(gl, VS, FS);
    this.lineProg = createProgram(gl, LINE_VS, LINE_FS);
    this.u = {};
    for (const name of ['u_viewProj', 'u_display', 'u_pal', 'u_base', 'u_details', 'u_hasBase', 'u_hasDetails',
      'u_cutout', 'u_sun', 'u_eye', 'u_pc', 'u_fallback', 'u_ambient']) {
      this.u[name] = gl.getUniformLocation(this.prog, name);
    }
    this.lu = { u_viewProj: gl.getUniformLocation(this.lineProg, 'u_viewProj') };
    // one ARRAY_BUFFER holds the whole geo buffer; each stream is a view into it
    const geo = bundle.buffers.geo;
    this.geoBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, this.geoBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, geo ? new Uint8Array(geo) : new Uint8Array(16), gl.STATIC_DRAW);
    this.meshes = new Map();         // `${model id}#${mesh index}` -> MeshSkin
    this.textures = new Map();       // `${texture id}|${srgb}` -> {tex, path} | null
    this.textureLog = [];
    this.lineBuffer = gl.createBuffer();
    this.lineVao = gl.createVertexArray();
    gl.bindVertexArray(this.lineVao);
    gl.bindBuffer(gl.ARRAY_BUFFER, this.lineBuffer);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 24, 0);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 3, gl.FLOAT, false, 24, 12);
    gl.bindVertexArray(null);
    const lighting = bundle.manifest.lighting || {};
    const sun = lighting.lgt && lighting.lgt.derived && lighting.lgt.derived.sun_direction &&
      lighting.lgt.derived.sun_direction.value;
    this.sunEngine = sun && sun.length === 3 ? sun : [0.45, 0.8, 0.4];
    this.setPlayerColour(lighting.player_color_index ?? 1);
    this.ambient = 0.38;
  }

  setPlayerColour(index) {
    const pcs = (this.bundle.manifest.lighting || {}).player_colors || [];
    const pc = pcs.find((p) => p.index === index) || pcs[0];
    this.playerIndex = pc ? pc.index : null;
    this.pc = pc && pc.rgb ? pc.rgb.map((v) => srgbToLinear(v / 255)) : [0.2, 0.3, 0.9];
  }

  mesh(model, mi) {
    const key = model.id + '#' + mi;
    let m = this.meshes.get(key);
    if (!m) {
      m = new MeshSkin(this.gl, this.geoBuffer, model.meshes[mi], this.bundle.view);
      this.meshes.set(key, m);
    }
    return m;
  }

  // GL texture of a bundle texture for an sRGB or a linear slot (uploaded once per pair); null when undecodable
  texture(id, srgb) {
    const key = id + '|' + (srgb ? 1 : 0);
    if (this.textures.has(key)) return this.textures.get(key);
    const gl = this.gl;
    const rec = (this.bundle.manifest.textures || {})[id];
    let out = null;
    if (rec && rec.decodable && BC_FORMATS[rec.bc] && rec.mips.length) {
      const tex = gl.createTexture();
      gl.activeTexture(gl.TEXTURE0 + UPLOAD_UNIT);       // never the units a draw has bound (palette, base, details)
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
      const mips = rec.mips.filter((m) => !m.face);
      const fmt = BC_FORMATS[rec.bc][srgb ? 1 : 0];
      const raw = srgb ? this.ext.s3tc_srgb : this.ext.s3tc;
      let path;
      if (raw) {
        for (const m of mips) gl.compressedTexImage2D(gl.TEXTURE_2D, m.level, fmt, m.width, m.height, 0, this.bundle.view(m.view));
        path = 's3tc';
      } else {                                         // CPU decode fallback (s3tc.js exact model)
        for (const m of mips) {
          const rgba = S3.toRGBA8(S3.decodeLevel(fmt, m.width, m.height, this.bundle.view(m.view)));
          gl.texImage2D(gl.TEXTURE_2D, m.level, srgb ? gl.SRGB8_ALPHA8 : gl.RGBA8, m.width, m.height, 0, gl.RGBA,
            gl.UNSIGNED_BYTE, rgba);
        }
        path = 'cpu-rgba8';
      }
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAX_LEVEL, mips.length - 1);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
      const errors = drainErrors(gl);
      this.textureLog.push({ id, srgb, bc: rec.bc, path, mips: mips.length, errors });
      out = errors.length ? null : { tex, path };
    }
    this.textures.set(key, out);
    return out;
  }

  materialOf(id) {
    return id ? (this.bundle.manifest.materials || {})[id] || null : null;
  }

  slotTexture(mat, slot) {
    const s = mat && mat.slots ? mat.slots[slot] : null;
    return s && s.texture ? this.texture(s.texture, !!s.srgb) : null;
  }

  // draw the posed instances with camera {viewProj, eye}; opts {background, bones, grid, hidden: Set(instance index)}
  draw(rig, cam, opts = {}) {
    const gl = this.gl;
    const bg = opts.background || [0.16, 0.17, 0.19, 1];
    gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
    gl.clearColor(bg[0], bg[1], bg[2], bg[3]);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.enable(gl.DEPTH_TEST);
    gl.disable(gl.CULL_FACE);
    if (opts.grid !== false) this.drawGrid(cam, opts.gridSize || 6);
    gl.useProgram(this.prog);
    gl.uniformMatrix4fv(this.u.u_viewProj, false, cam.viewProj);
    gl.uniformMatrix4fv(this.u.u_display, false, DISPLAY);
    gl.uniform3fv(this.u.u_sun, [-this.sunEngine[0], this.sunEngine[1], this.sunEngine[2]]);
    gl.uniform3fv(this.u.u_eye, cam.eye);
    gl.uniform3fv(this.u.u_pc, this.pc);
    gl.uniform1f(this.u.u_ambient, this.ambient);
    gl.uniform1i(this.u.u_pal, 0);
    gl.uniform1i(this.u.u_base, 1);
    gl.uniform1i(this.u.u_details, 2);
    const stats = { draws: 0, triangles: 0, untextured: 0 };
    for (const inst of rig.instances) {
      if (!inst.worlds || !inst.model.decodable || (opts.hidden && opts.hidden.has(inst.index))) continue;
      inst.model.meshes.forEach((meshRec, mi) => {
        const m = this.mesh(inst.model, mi);
        m.updatePalette(inst);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, m.palette);
        gl.bindVertexArray(m.vao);
        for (const g of meshRec.groups) {
          const mat = this.materialOf(g.material);
          const base = this.slotTexture(mat, 'BaseColor');
          const det = this.slotTexture(mat, 'Details');
          gl.activeTexture(gl.TEXTURE1);
          gl.bindTexture(gl.TEXTURE_2D, base ? base.tex : null);
          gl.activeTexture(gl.TEXTURE2);
          gl.bindTexture(gl.TEXTURE_2D, det ? det.tex : null);
          gl.uniform1i(this.u.u_hasBase, base ? 1 : 0);
          gl.uniform1i(this.u.u_hasDetails, det ? 1 : 0);
          gl.uniform1i(this.u.u_cutout, mat && mat.flags && mat.flags.cutout ? 1 : 0);
          gl.uniform3fv(this.u.u_fallback, inst.role === 'attachment' ? [0.75, 0.55, 0.3] : [0.62, 0.62, 0.62]);
          if (!base) stats.untextured++;
          m.drawGroup(g);
          stats.draws++;
          stats.triangles += g.triangle_count;
        }
      });
    }
    gl.bindVertexArray(null);
    if (opts.bones) this.drawBones(rig, cam);
    stats.errors = drainErrors(gl);
    return stats;
  }

  drawLines(verts, cam, mode, depth) {
    const gl = this.gl;
    gl.useProgram(this.lineProg);
    gl.uniformMatrix4fv(this.lu.u_viewProj, false, cam.viewProj);
    gl.bindVertexArray(this.lineVao);
    gl.bindBuffer(gl.ARRAY_BUFFER, this.lineBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(verts), gl.DYNAMIC_DRAW);
    if (!depth) gl.disable(gl.DEPTH_TEST);
    gl.drawArrays(mode, 0, verts.length / 6);
    gl.enable(gl.DEPTH_TEST);
    gl.bindVertexArray(null);
  }

  drawGrid(cam, size) {
    const v = [];
    for (let i = -size; i <= size; i++) {
      const c = i === 0 ? [0.42, 0.44, 0.48] : [0.26, 0.27, 0.3];
      v.push(i, 0, -size, ...c, i, 0, size, ...c, -size, 0, i, ...c, size, 0, i, ...c);
    }
    this.drawLines(v, cam, this.gl.LINES, true);
  }

  // bones as lines to their parents (display frame); colour by role
  drawBones(rig, cam) {
    const colours = { main: [1, 0.8, 0.2], child: [0.3, 0.9, 1], attachment: [1, 0.4, 0.3] };
    const v = [];
    for (const inst of rig.instances) {
      if (!inst.worlds) continue;
      const c = colours[inst.role] || [1, 1, 1];
      const W = inst.worlds;
      for (let i = 0; i < inst.model.boneCount; i++) {
        const p = inst.model.parents[i];
        if (p < 0) continue;
        v.push(-W[i * 16 + 12], W[i * 16 + 13], W[i * 16 + 14], ...c, -W[p * 16 + 12], W[p * 16 + 13], W[p * 16 + 14], ...c);
      }
    }
    if (v.length) this.drawLines(v, cam, this.gl.LINES, false);
  }
}
