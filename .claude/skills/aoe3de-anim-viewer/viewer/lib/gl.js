// Small WebGL2 helpers shared by the viewer pages. classifyGpuPath is pure (tests/js run it under node --test).

export function compileShader(gl, type, source) {
  const sh = gl.createShader(type);
  gl.shaderSource(sh, source);
  gl.compileShader(sh);
  if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
    const log = gl.getShaderInfoLog(sh);
    gl.deleteShader(sh);
    throw new Error((type === gl.VERTEX_SHADER ? 'vertex' : 'fragment') + ' shader: ' + log);
  }
  return sh;
}

export function createProgram(gl, vsSource, fsSource) {
  const prog = gl.createProgram();
  gl.attachShader(prog, compileShader(gl, gl.VERTEX_SHADER, vsSource));
  gl.attachShader(prog, compileShader(gl, gl.FRAGMENT_SHADER, fsSource));
  gl.linkProgram(prog);
  if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error('link: ' + gl.getProgramInfoLog(prog));
  return prog;
}

// VENDOR / RENDERER strings; the unmasked pair through WEBGL_debug_renderer_info where the browser still offers it
// (newer Chrome already returns the unmasked strings from RENDERER).
export function rendererInfo(gl) {
  const info = {
    vendor: gl.getParameter(gl.VENDOR),
    renderer: gl.getParameter(gl.RENDERER),
    version: gl.getParameter(gl.VERSION),
    glsl: gl.getParameter(gl.SHADING_LANGUAGE_VERSION),
    unmasked_vendor: null,
    unmasked_renderer: null,
  };
  const dbg = gl.getExtension('WEBGL_debug_renderer_info');
  if (dbg) {
    info.unmasked_vendor = gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL);
    info.unmasked_renderer = gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL);
  }
  return info;
}

// renderer string -> which ANGLE back end ran: 'swiftshader' (CPU), 'angle-d3d11', 'angle-d3d9', 'angle-vulkan',
// 'angle-metal', 'angle-opengl', 'other'. SwiftShader reports itself through Vulkan, so it is tested first.
export function classifyGpuPath(renderer) {
  const r = String(renderer || '').toLowerCase();
  if (r.includes('swiftshader')) return 'swiftshader';
  if (r.includes('direct3d11') || r.includes('d3d11')) return 'angle-d3d11';
  if (r.includes('direct3d9') || r.includes('d3d9')) return 'angle-d3d9';
  if (r.includes('vulkan')) return 'angle-vulkan';
  if (r.includes('metal')) return 'angle-metal';
  if (r.includes('opengl')) return 'angle-opengl';
  return 'other';
}

export function glErrorName(gl, code) {
  for (const k of ['INVALID_ENUM', 'INVALID_VALUE', 'INVALID_OPERATION', 'INVALID_FRAMEBUFFER_OPERATION',
    'OUT_OF_MEMORY', 'CONTEXT_LOST_WEBGL']) if (gl[k] === code) return k;
  return code === 0 ? null : '0x' + code.toString(16);
}

// all pending GL errors as names (empty list = none)
export function drainErrors(gl) {
  const out = [];
  for (let i = 0; i < 16; i++) {
    const e = gl.getError();
    if (e === gl.NO_ERROR) break;
    out.push(glErrorName(gl, e));
  }
  return out;
}
