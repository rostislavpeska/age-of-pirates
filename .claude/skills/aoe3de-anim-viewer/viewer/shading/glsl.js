// M3 game shader: GLSL ES 3.00 sources. The materialdefault BasePass and the lightingpass PSDirectIndirectLighting fused
// into one forward pass (references/shader-model.md section 2: the game's own forward permutation of materialdefault,
// blob cd8fde98, computes the same lighting in the material shader; the deferred path differs only by its G-buffer
// storage, emulated by gbufferRoundTrip). Shared by the renderer (renderer.js) and the pixel-parity page
// (selftest.js), so the GPU readback test checks exactly the functions the viewer draws with. tests/shading_ref.py is
// the numpy twin of every function here. All lighting runs in the ENGINE frame (the gr2 / game world frame, +Y up,
// left-handed); only gl_Position goes through the display flip (camera.js DISPLAY).

export const COMMON = `
const float PI_INV = 0.318310;
float sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 sat3(vec3 x) { return clamp(x, 0.0, 1.0); }
// x^e as the shaders' log/exp pair; x <= 0 -> 0 (D3D: log(0) = -inf, exp(-inf) = 0)
float safePow(float x, float e) { return x > 0.0 ? exp2(log2(x) * e) : 0.0; }
vec3 safePow3(vec3 x, float e) { return vec3(safePow(x.r, e), safePow(x.g, e), safePow(x.b, e)); }
`;

// ------------------------------------------------------------------------------------------------ materialdefault
// rei0 = (playerColorIndex, aoIntensity, aoGamma, liftMetallic), rei1 = (liftNonMetallic, roughnessMin, roughnessMax,
// roughnessMetallicMin), rei2 = (roughnessMetallicMax, metallicMin, metallicMax, cutoutThreshold) (model.js)
export const MATERIAL = `
struct Surface { vec3 albedo; float metal; float rough; float ao; vec3 n; float horizon; };

// base, lift: linear BaseColor and its 2-mips-finer sample; nrm, masks: raw texels; nv, tv: interpolated vertex
// normal / tangent (already flipped for a back face of a double-sided material), tw: tangent w; pc: player colour
Surface materialdefault(vec3 base, vec3 lift, vec3 nrm, vec3 masks, float details, vec3 nv, vec3 tv, float tw,
                        vec3 pc, vec4 rei0, vec4 rei1, vec4 rei2, vec3 pos, vec3 eye) {
  Surface s;
  vec3 albedo = base + details * (base * pc - base);
  vec3 nts = nrm * 2.0 - 1.0;
  vec3 N = normalize(nv);
  vec3 T = normalize(tv);
  vec3 B = sign(tw) * cross(N, T);
  s.n = normalize(nts.x * T + nts.y * B + nts.z * N);
  s.ao = safePow(max(1.0 - (1.0 - masks.x) * rei0.y, 0.0), max(1.0 + rei0.z, 0.0));
  float maxc = max(max(lift.r, lift.g), lift.b);
  float r1 = rei1.y + masks.y * (rei1.z - rei1.y);
  r1 = r1 + masks.z * (masks.y - r1);
  float rm = rei1.w + r1 * (rei2.x - rei1.w);
  s.rough = r1 + masks.z * (rm - r1);
  s.metal = sat(rei2.y + masks.z * (rei2.z - rei2.y));
  float k = 1.0 + rei1.x * (maxc - 1.0);
  albedo = albedo / (k + s.metal * (1.0 - k));
  s.albedo = sat3(albedo / (1.0 + s.metal * rei0.w * (maxc - 1.0)));
  vec3 V = normalize(pos - eye);
  vec3 R = V - 2.0 * dot(V, s.n) * s.n;
  s.horizon = dot(nv, R) * 1.5 + 1.0;
  return s;
}

float quantise(float x, float m) { return floor(sat(x) * m + 0.5) / m; }
vec3 quantise3(vec3 x, float m) { return floor(sat3(x) * m + 0.5) / m; }

// the deferred storage the lighting pass reads back: albedo pow(1/2.2) (8 bit), normal *0.5+0.5 (10 bit), metal,
// roughness, AO, horizon (8 bit); UNORM targets saturate in both modes (formats inferred: fidelity 'gbuffer' A)
Surface gbufferRoundTrip(Surface s, bool quant) {
  Surface g;
  vec3 enc = safePow3(sat3(s.albedo), 1.0 / 2.2);
  vec3 nenc = s.n * 0.5 + 0.5;
  float metal = s.metal, rough = sat(s.rough), ao = sat(s.ao), hor = sat(s.horizon);
  if (quant) {
    enc = quantise3(enc, 255.0);
    metal = quantise(metal, 255.0); rough = quantise(rough, 255.0); ao = quantise(ao, 255.0); hor = quantise(hor, 255.0);
    nenc = quantise3(nenc, 1023.0);
  }
  g.albedo = safePow3(sat3(enc), 2.2);
  g.metal = metal; g.rough = rough; g.ao = ao; g.horizon = hor;
  g.n = normalize(nenc * 2.0 - 1.0);
  return g;
}
`;

// ------------------------------------------------------------------------------------------------ lightingpass
export const LIGHTING = `
uniform vec3 u_sunDir;          // LightingConstants.sunDirection: the direction sunlight travels (L = -u_sunDir)
uniform vec3 u_sunColor;
uniform vec3 u_shadowColor;
uniform vec3 u_hemiTop;
uniform vec3 u_hemiBottom;
uniform vec2 u_skyRot;          // (sin, cos) of the sky cube rotation about +Y
uniform float u_iblIntensity;   // skyCubeIntensity
uniform float u_iblNormalize;   // skyCubeNormalize
uniform float u_exposure;
uniform float u_envMaxMip;      // (levels - 1) of the game's full cube
uniform float u_envLodOffset;   // file levels missing from the bound cube (GL level 0 = file level u_envLodOffset)
uniform highp samplerCube u_env;
uniform vec2 u_envbrdf[64];     // (scale, bias), index iy * 8 + ix

vec3 rotY(vec3 d) { return vec3(d.x * u_skyRot.y + d.z * u_skyRot.x, d.y, -d.x * u_skyRot.x + d.z * u_skyRot.y); }

vec3 envLit(vec3 d, float lod, float shadow) {
  vec4 e = textureLod(u_env, rotY(d), max(lod - u_envLodOffset, 0.0));
  return (e.rgb * e.a + shadow * (e.rgb - e.rgb * e.a)) * u_iblNormalize;
}

vec3 envbrdf(vec3 f0, float rough, float ndotv) {
  int ix = int(min(floor(sat(rough) * 8.0), 7.0));
  int iy = int(min(floor(sat(ndotv) * 8.0), 7.0));
  vec2 sb = u_envbrdf[iy * 8 + ix];
  return f0 * sb.x + sb.y;
}

// g: the surface as the lighting pass reads it; shadow: sun visibility (0..1); ssao: 1 (not computed)
vec3 lightingpass(Surface g, vec3 pos, vec3 eye, float shadow, float ssao) {
  vec3 albedo = g.albedo;
  float metal = g.metal, rough = g.rough;
  vec3 n = g.n;
  float ao = g.ao * ssao;
  vec3 Lsun = -u_sunDir;
  vec3 Vd = normalize(pos - eye);
  float ndotv = max(dot(n, -Vd), 1e-5);
  vec3 diffuse = albedo - albedo * metal;
  vec3 f0 = 0.04 + metal * (albedo - 0.04);
  float alpha = max(rough, 0.08);
  alpha = alpha * alpha;
  float a2m1 = alpha * alpha - 1.0;
  float k = alpha * 0.5;
  float gv = 1.0 / (ndotv * (1.0 - k) + k);
  vec3 R = Vd - 2.0 * dot(Vd, n) * n;
  // sun disc: the representative point of a 1.72 degree disc (cos 0.99955, sin 0.029995)
  float cosLR = dot(Lsun, R);
  vec3 Ld = R;
  if (cosLR < 0.99955) Ld = normalize(normalize(R - cosLR * Lsun) * 0.029995 + Lsun * 0.99955);
  float ndotl = max(dot(n, Ld), 1e-5);
  vec3 H = normalize(Ld - Vd);
  float vdoth = dot(-Vd, H);
  float ndoth = dot(n, H);
  float d = max(ndoth * ndoth * a2m1 + 1.0, 0.0);
  float D = alpha / d;
  D = D * D * PI_INV;
  vec3 F = f0 + (1.0 - f0) * exp2(vdoth * (-5.55473 * vdoth - 6.98316));
  float vis = gv / (ndotl * (1.0 - k) + k) * 0.25;
  vec3 spec = F * vis * D * ndotl * u_sunColor;
  vec3 diff = ndotl * diffuse * PI_INV * u_sunColor;
  float shAo = shadow * ao;
  vec3 direct = diff * shAo + spec * shAo;
  // image-based light: irradiance from the last mip at N, specular at (levels - 1) r^(1/1.3) along R
  vec3 irr = envLit(n, u_envMaxMip, shadow) * mix(u_hemiBottom, u_hemiTop, 0.5 + 0.5 * n.y) * u_iblIntensity * ao;
  float lod = u_envMaxMip * safePow(sat(rough), 0.769231);
  vec3 senv = envLit(R, lod, shadow) * mix(u_hemiBottom, u_hemiTop, 0.5 + 0.5 * R.y) * u_iblIntensity;
  float occ = sat(safePow(sat(ao + ndotv), rough) + ao - 1.0) * g.horizon;
  vec3 specIbl = occ * senv * envbrdf(f0, rough, sat(ndotv));
  vec3 diffIbl = diffuse * irr;
  float shadowed = max(max(dot(u_sunDir, n), 0.0), 1.0 - shadow);
  vec3 tint = 1.0 + shadowed * (u_shadowColor - 1.0);
  return (tint * diffIbl + tint * specIbl + direct) * u_exposure;
}
`;

// ------------------------------------------------------------------------------------------------ shadow filter
export const SHADOW = `
uniform highp sampler2D u_shadowMap;   // depth texture, compare mode none, NEAREST (read with texelFetch)

// 25 bilinear soft-compare taps / 25 (the game kernel shape: 9 gathers over a 6x6 block, weights [1-f,1,1,1,1,f]);
// lit = 1 - saturate((z - bias - d) * softness); outside the map: 1
float pcf25(vec2 uv, float z, float bias, float softness) {
  if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || z > 1.0) return 1.0;
  ivec2 size = textureSize(u_shadowMap, 0);
  vec2 p = uv * vec2(size);
  vec2 i = floor(p);
  vec2 f = clamp(p - i, 0.0, 1.0);
  float acc = 0.0;
  for (int b = 0; b < 6; b++) {
    float wy = b == 0 ? 1.0 - f.y : (b == 5 ? f.y : 1.0);
    int yi = clamp(int(i.y) - 3 + b, 0, size.y - 1);
    for (int a = 0; a < 6; a++) {
      float wx = a == 0 ? 1.0 - f.x : (a == 5 ? f.x : 1.0);
      int xi = clamp(int(i.x) - 3 + a, 0, size.x - 1);
      float dm = texelFetch(u_shadowMap, ivec2(xi, yi), 0).r;
      acc += wx * wy * (1.0 - sat((z - bias - dm) * softness));
    }
  }
  return acc / 25.0;
}
`;

// ------------------------------------------------------------------------------------------------ post
// fxaacolorgradetonemap PSMain (LUT), tonemap.hlsl PSMain (legacy Hable), or off (saturate + sRGB)
export const POST = `
uniform highp sampler3D u_tonemapLUT;
uniform highp sampler3D u_gradeLUT;
uniform highp sampler2D u_noise;       // 64x64 RGBA8 dither noise (texelFetch, wraps)
uniform float u_gradeEnabled;
uniform float u_gradeSize;
uniform float u_ditherScale;
uniform vec4 u_legacy;                 // (exposure, luminanceBased, influence, noiseIntensity)
uniform float u_legacyWhite;

vec3 noiseAt(ivec2 px) { return texelFetch(u_noise, ivec2(px.x & 63, px.y & 63), 0).rgb; }

vec3 postLUT(vec3 c, vec3 nz) {
  vec3 uvw = sqrt(min(c * 0.5, vec3(1.0))) * 0.96875 + 0.015625;
  vec3 t = texture(u_tonemapLUT, uvw).rgb;
  if (u_gradeEnabled > 0.0) {
    vec3 g = texture(u_gradeLUT, t * ((u_gradeSize - 1.0) / u_gradeSize) + 0.5 / u_gradeSize).rgb;
    t = t + u_gradeEnabled * (g - t);
  }
  return t + (nz * 2.0 - 1.0) * u_ditherScale;
}

float hable(float x) { return (x * (0.15 * x + 0.05) + 0.004) / (x * (0.15 * x + 0.5) + 0.06) - 0.066667; }
vec3 hable3(vec3 x) { return vec3(hable(x.r), hable(x.g), hable(x.b)); }

vec3 postLegacy(vec3 c, vec3 nz) {
  float e2 = 2.0 * u_legacy.x;
  float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
  float ratio = lum > 0.0 ? hable(e2 * lum) / lum : 0.0;
  vec3 per = hable3(c * e2);
  vec3 t = sat3(per + u_legacy.y * (c * ratio - per));
  t = t / hable(u_legacyWhite);
  t = t + (nz * 2.0 - 1.0) * u_legacy.w * 0.1;
  t = sat3(c + u_legacy.z * (t - c));
  return safePow3(t, 1.0 / 2.2);
}

vec3 srgbEncode(vec3 c) {
  c = sat3(c);
  return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

// mode 0 LUT, 1 legacy, 2 off
vec3 postProcess(vec3 c, ivec2 px, int mode) {
  vec3 nz = noiseAt(px);
  if (mode == 0) return postLUT(c, nz);
  if (mode == 1) return postLegacy(c, nz);
  return srgbEncode(c);
}
`;

// ------------------------------------------------------------------------------------------------ renderer programs
// vertex streams as skin.js binds them, plus the tangent at location 5 (renderer.js binds it on each MeshSkin VAO)
export function materialVS(skinGlsl) {
  return `#version 300 es
precision highp float;
precision highp int;
${skinGlsl}
layout(location = 5) in vec4 a_tan;
uniform mat4 u_viewProj;
uniform mat4 u_display;
out vec3 v_pos;
out vec3 v_nrm;
out vec4 v_tan;
out vec2 v_uv;
void main() {
  mat4 S = skinMatrix();
  vec4 pe = S * vec4(a_pos, 1.0);
  v_pos = pe.xyz;
  v_nrm = mat3(S) * a_nrm;
  v_tan = vec4(mat3(S) * a_tan.xyz, a_tan.w);
  v_uv = a_uv;
  gl_Position = u_viewProj * (u_display * pe);
}`;
}

export const MATERIAL_FS = `#version 300 es
precision highp float;
precision highp int;
${COMMON}
${MATERIAL}
${LIGHTING}
${SHADOW}
in vec3 v_pos;
in vec3 v_nrm;
in vec4 v_tan;
in vec2 v_uv;
uniform sampler2D u_base;
uniform sampler2D u_normal;
uniform sampler2D u_masks;
uniform sampler2D u_details;
uniform ivec4 u_has;            // BaseColor, Normals, Masks, Details bound
uniform vec4 u_missingBase;
uniform vec4 u_missingNormal;
uniform vec4 u_missingMasks;
uniform int u_cutout;
uniform int u_doubleSided;
uniform vec4 u_rei[3];
uniform vec3 u_pc;
uniform vec3 u_eye;             // engine frame
uniform float u_mipBias;
uniform int u_quant;
uniform int u_debug;            // 0 lit, 1 albedo, 2 normal, 3 roughness, 4 metallic, 5 AO, 6 shadow, 7 facing, 8 horizon
uniform int u_shadows;
uniform mat4 u_lightViewProj;   // engine frame -> light clip (column-major)
uniform float u_shadowBias;
uniform float u_shadowSoft;
out vec4 o;
void main() {
  vec4 base = u_has.x == 1 ? texture(u_base, v_uv, u_mipBias) : u_missingBase;
  if (u_cutout == 1 && base.a < u_rei[2].w) discard;
  vec3 lift = u_has.x == 1 ? texture(u_base, v_uv, u_mipBias - 2.0).rgb : base.rgb;
  vec3 nrm = u_has.y == 1 ? texture(u_normal, v_uv, u_mipBias).rgb : u_missingNormal.rgb;
  vec3 masks = u_has.z == 1 ? texture(u_masks, v_uv, u_mipBias).rgb : u_missingMasks.rgb;
  float details = u_has.w == 1 ? texture(u_details, v_uv, u_mipBias).r : 0.0;
  float s = (u_doubleSided == 1 && !gl_FrontFacing) ? -1.0 : 1.0;
  vec3 nv = v_nrm * s;
  Surface m = materialdefault(base.rgb, lift, nrm, masks, details, nv, v_tan.xyz * s, v_tan.w, u_pc,
                              u_rei[0], u_rei[1], u_rei[2], v_pos, u_eye);
  Surface g = gbufferRoundTrip(m, u_quant == 1);
  float shadow = 1.0;
  if (u_shadows == 1) {
    vec4 lc = u_lightViewProj * vec4(v_pos, 1.0);
    vec3 ndc = lc.xyz / lc.w;
    shadow = pcf25(ndc.xy * 0.5 + 0.5, ndc.z * 0.5 + 0.5, u_shadowBias, u_shadowSoft);
  }
  vec3 c;
  if (u_debug == 0) c = lightingpass(g, v_pos, u_eye, shadow, 1.0);
  else if (u_debug == 1) c = g.albedo;
  else if (u_debug == 2) c = g.n * 0.5 + 0.5;
  else if (u_debug == 3) c = vec3(g.rough);
  else if (u_debug == 4) c = vec3(g.metal);
  else if (u_debug == 5) c = vec3(g.ao);
  else if (u_debug == 6) c = vec3(shadow);
  else if (u_debug == 7) c = vec3(gl_FrontFacing ? 1.0 : 0.0, dot(v_nrm, u_eye - v_pos) > 0.0 ? 1.0 : 0.0, 0.0);
  else c = vec3(g.horizon);
  o = vec4(c, 1.0);
}`;

// depth-only pass from the sun (engine frame -> light clip), alpha-tested like the game's DepthOnly permutations
export function shadowVS(skinGlsl) {
  return `#version 300 es
precision highp float;
precision highp int;
${skinGlsl}
uniform mat4 u_lightViewProj;
out vec2 v_uv;
void main() {
  mat4 S = skinMatrix();
  v_uv = a_uv;
  gl_Position = u_lightViewProj * (S * vec4(a_pos, 1.0));
}`;
}

export const SHADOW_FS = `#version 300 es
precision highp float;
in vec2 v_uv;
uniform sampler2D u_base;
uniform int u_cutout;
uniform float u_cutoutThreshold;
out vec4 o;
void main() {
  if (u_cutout == 1 && texture(u_base, v_uv).a < u_cutoutThreshold) discard;
  o = vec4(0.0);
}`;

export const FULLSCREEN_VS = `#version 300 es
precision highp float;
void main() {
  vec2 p = vec2(gl_VertexID == 1 ? 3.0 : -1.0, gl_VertexID == 2 ? 3.0 : -1.0);
  gl_Position = vec4(p, 0.0, 1.0);
}`;

export const POST_FS = `#version 300 es
precision highp float;
precision highp int;
${COMMON}
${POST}
uniform highp sampler2D u_hdr;
uniform int u_postMode;
uniform vec4 u_background;      // display rgb; a = 0: transparent output (alpha = coverage)
out vec4 o;
void main() {
  ivec2 px = ivec2(gl_FragCoord.xy);
  vec4 h = texelFetch(u_hdr, px, 0);
  vec3 t = postProcess(h.rgb, px, u_postMode);
  float a = sat(h.a);
  o = u_background.a > 0.0 ? vec4(mix(u_background.rgb, t, a), 1.0) : vec4(t, a);
}`;
