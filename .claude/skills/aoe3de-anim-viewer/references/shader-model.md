# Game shader model v1 (M3)

The viewer's game shader re-implements how AoE3 DE lights an opaque unit. It is written from the formulas below.
They were read from the game's compiled shaders. The table at the end says, for every stage, whether it is measured,
approximated, unknown or a hypothesis.

Where it lives:

- GLSL: `viewer/shading/glsl.js`
- numpy twin: `tests/shading_ref.py`
- parameter mapping: `viewer/shading/model.js`
- constants: `scripts/lighting.py` (`shader_constants`, `ENVBRDF_*`, `SHADING_FIDELITY`)

No game shader bytes or disassembly are in this skill. The disassembly is a local, untracked scratch output only:
`D3DDisassemble` over the `.hlslc` blobs of the game's `Game/Render/RenderCache.bar` (see "Re-reading the shaders"
below).

## 1. Sources

All of these are precompiled blobs shipped in `Game/Render/RenderCache.bar`. Each blob name gives the shader file, the
entry point and a hash.

| Blob (RenderCache) | Defines | Used for |
| --- | --- | --- |
| `materialdefault_PSMain_ps_d24973898` | COLOR_ADJUSTMENTS, RENDER_PASS_BasePass | the material: G-buffer outputs |
| `materialdefault_PSMain_ps_781ce36f8` | + DOUBLESIDED, CUTOUT | cutout threshold, front-face flip |
| `materialdefault_PSMain_ps_cd8fde98` | ALPHATOCOVERAGE, CUTOUT, RENDER_PASS_Forward | the game's own fused forward path (section 2) |
| `materialdefault_VSMain_vs_d579270d8` | VERTEX_FORMAT_SkinnedPackedVertex | normal and tangent transform |
| `lightingpass_PSDirectIndirectLighting_ps_7b3db7808` | (none) | the deferred lighting, the EnvBRDF table |
| `fxaacolorgradetonemap_BuildTonemapLUT_cs_ef962edb8` | | the 32^3 tonemap LUT (`lighting.bake_tonemap_lut`) |
| `fxaacolorgradetonemap_PSMain_ps_10fee4c48` | | LUT lookup, colour grade, dither |
| `tonemap_PSMain` (two blobs) | | the legacy Hable path |
| `Render/materialdefs/default*.materialdef` | | parameter order and defaults |

`fxaacolorgradetonemap` and the legacy `tonemap` both ship in RenderCache.bar. Which one draws a normal match is
unknown.

## 2. Deferred in the game, one forward pass here

The game draws opaque units in two passes:

1. The BasePass writes a G-buffer:
   - albedo `pow(base, 1/2.2)` and metallic;
   - normal `n * 0.5 + 0.5` and a material id (1/12, which selects the unit lighting class);
   - roughness, AO and a horizon term;
   - motion vectors and an additive "flat colour".
2. A full-screen `lightingpass` lights every pixel from that G-buffer.

The viewer fuses both into one forward pass, `MATERIAL_FS`:

```
materialdefault(...) -> gbufferRoundTrip(...) -> lightingpass(...)
```

This is equivalent for these reasons:

- The lighting pass is per pixel. Its only inputs are the G-buffer, the depth (for the world position), the shadow
  maps, SSAO and the constant buffers. The fused pass hands it the same values directly.
- `gbufferRoundTrip` reproduces what the storage does to those values: albedo through `pow(1/2.2)` and back,
  saturation of the UNORM data channels, and optionally their quantisation (8-bit albedo and data, 10-bit normal).
  The target formats are not known: the encodings point to UNORM targets (fidelity `gbuffer` A).
- The game ships a forward permutation of the same material (`cd8fde98`). It runs the identical lighting code (same
  BRDF, IBL, EnvBRDF table and shadow tint) inside the material shader. It differs from the deferred path only where
  deferred storage is involved:
  - no `pow(2.2)` round trip;
  - no horizon factor;
  - material AO only, no SSAO;
  - distance fog applied in place;
  - the flat colour added after the exposure.

  The viewer follows the deferred path: units are opaque and drawn deferred. The forward one serves alpha-to-coverage
  materials.

## 3. Vertex stage

Everything is lit in the engine frame: the gr2 and world frame, +Y up, left-handed. Only `gl_Position` takes the
display flip (`camera.js DISPLAY`).

- Position: `p = sum w_i (p_rest @ M_i)`. The skin palette is `inverse_world @ world` (skin.js).
- Normal and tangent: `n = sum w_i (n_rest @ M_i[3x3])`. This is the bone 3x3 itself, not an inverse transpose. The
  tangent is transformed the same way, and `Tangent.w` passes through unchanged. The shader normalises both per pixel.
- UV: passed as stored (raw D3D UV, no flip).
- Vertex colour: present in the stream, but materialdefault's pixel shader does not read it.

## 4. Material (materialdefault BasePass)

REIConstants are taken in the materialdef's parameter order. The cbuffer order matches it, so the order of the names
below is measured:

```
pixelxformColor, [CutoutThreshold], AO Intensity, AO Gamma, Lift Metallic, Lift Non-Metallic,
Roughness Min, Roughness Max, Roughness Metallic Min, Roughness Metallic Max, Metallic Min, Metallic Max
```

Defaults (default.materialdef): 0, 0.5, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1. Unbound slot textures:

- Details uses `black` (measured), so there is no player colour.
- `missingnormal` and `missingmasks` are unknown. They are replaced by a flat normal and masks (1, 1, 0).

Per pixel, with `base` = BaseColor (sRGB-decoded by the sampler), `m` = Masks rgb, `d` = Details.r:

```
cutout:      discard if base.a < CutoutThreshold                         (CUTOUT permutations)
double-sided: s = front ? 1 : -1; N_v *= s; T_v *= s                     (DOUBLESIDED; B is unchanged by the flip)
albedo     = base + d (base * PC - base)                                 PC = playercolors color[k+1], k = pixelxformColor
TBN        = N = normalize(N_v), T = normalize(T_v), B = sign(T.w) cross(N, T)
n          = normalize(t.x T + t.y B + t.z N),  t = Normals.rgb * 2 - 1
ao         = max(1 - (1 - m.r) aoIntensity, 0) ^ max(1 + aoGamma, 0)
r1         = lerp(roughMin, roughMax, m.g);  r1 = lerp(r1, m.g, m.b)
roughness  = lerp(r1, lerp(roughMetalMin, roughMetalMax, r1), m.b)
metallic   = saturate(lerp(metalMin, metalMax, m.b))
c          = max channel of BaseColor sampled 2 mips finer (bias -2), before the player colour
albedo    /= lerp(1 + liftNonMetallic (c - 1), 1, metallic)
albedo     = saturate(albedo / (1 + metallic liftMetallic (c - 1)))
horizon    = 1 + 1.5 dot(N_v, reflect(normalize(P - eye), n))           (raw interpolated N_v, flipped)
```

The screen-door fade discards when the instance alpha is below a blue-noise value. At alpha 1 it never fires, so the
viewer leaves it out.

## 5. Lighting (lightingpass PSDirectIndirectLighting, unit class)

The input is the G-buffer read-back:

- `albedo = pow(saturate(enc), 2.2)`;
- `n = normalize(enc * 2 - 1)`;
- `metallic` from the albedo target's alpha (unit class: the material id `1/12 * 3` gives class 0; the wrap term is 0);
- roughness, AO and horizon from the data target.

`AO = material AO x SSAO`; SSAO is not computed here, so it is 1. The constants come from `LightingConstants` (cb4).

```
V  = normalize(P - eye);  NdotV = max(dot(n, -V), 1e-5)
diffuse = albedo (1 - metallic);  F0 = lerp(0.04, albedo, metallic)
alpha = max(roughness, 0.08)^2;  k = alpha / 2
R  = reflect(V, n);  L = -sunDirection
sun disc: Ld = R when dot(L, R) >= 0.99955, else normalize(0.99955 L + 0.029995 normalize(R - dot(L,R) L))
NdotL = max(dot(n, Ld), 1e-5);  H = normalize(Ld - V)
D   = alpha^2 / (pi (NdotH^2 (alpha^2 - 1) + 1)^2)
F   = F0 + (1 - F0) exp2((-5.55473 VdotH - 6.98316) VdotH)
Vis = 1 / (4 (NdotV (1 - k) + k) (NdotL (1 - k) + k))
direct = (NdotL diffuse / pi + F Vis D NdotL) sunColor x shadow x AO
env(dir, lod) = cube(rotY(dir), lod).rgb x (a + shadow (1 - a)) x skyCubeNormalize
        rotY(d) = (d.x cos + d.z sin, d.y, -d.x sin + d.z cos)
irradiance = env(n, levels - 1) x lerp(hemiBottom, hemiTop, 0.5 + 0.5 n.y) x skyCubeIntensity x AO
specEnv    = env(R, (levels - 1) saturate(r)^(1/1.3)) x lerp(hemiBottom, hemiTop, 0.5 + 0.5 R.y) x skyCubeIntensity
specOcc    = saturate(saturate(AO + NdotV)^r + AO - 1) x horizon
EnvBRDF    = table[iy][ix], ix = min(floor(saturate(r) 8), 7), iy = min(floor(saturate(NdotV) 8), 7) (nearest)
ambient    = tint (diffuse x irradiance + specOcc x specEnv x (F0 scale + bias))
        tint = lerp(1, shadowColor, max(max(dot(sunDirection, n), 0), 1 - shadow))
HDR = (ambient + direct) x exposure
```

Notes:

- The ambient diffuse has no 1/pi.
- The cube's alpha holds the share of each texel that the sun does not occlude. In shadow, only that share remains.
- The EnvBRDF table is 8x8, row = NdotV bin, column = roughness bin, value at the bin's lower edge. Column 0 is Schlick
  exactly. `lighting.ENVBRDF_SCALE` / `ENVBRDF_BIAS` hold it as numbers, re-entered from the shader's immediate
  constant buffer (entry `4 + 16 iy + 2 ix`, components x and z).

Left out for a lone unit:

- tiled point lights;
- contact shadows: the unit class never gets them (measured);
- the fill light: read by no shader (measured);
- height fog;
- terrain height shading `1 + i (smoothstep(minH, maxH, y) - 0.5)`;
- cloud shadows;
- distance fog `x/(1+x)`.

## 6. Shadows

The game uses up to four cascades from `shadowMatrix[]`. Each cascade gets a bias, and a soft compare
`lit = 1 - saturate((d_map - (bias + z)) transition)` with reversed depth. Nine `gather4` reads cover a 6x6 texel
block. Bilinear weights `[1 - f, 1, 1, 1, 1, f]` per axis turn it into 25 bilinear taps, divided by 25.

The viewer keeps the same kernel shape and soft compare (`pcf25`, standard depth). The rest differs:

- one directional depth map fitted to the posed unit;
- alpha-tested casters, both faces;
- polygon offset, a 2 cm bias and a 3 cm softness.

The game's resolution, cascade splits, bias and softness are unknown.

## 7. Post

- **LUT path (default, `fxaacolorgradetonemap_PSMain`):**

  ```
  t = tonemapLUT(sqrt(min(c/2, 1)) 31/32 + 1/64)
  t = lerp(t, gradeLUT(t (N-1)/N + 0.5/N), colorGradingEnabled)
  out = t + (2 noise - 1) / 256
  ```

  - The LUT already outputs sRGB.
  - The LUT is baked by `lighting.bake_tonemap_lut` (ICtCp/PQ shoulder, white point).
  - The grade LUT is the lgt's custom `.cube`. The generator from the `colorgrade*` parameters is not ported; those
    parameters are neutral in both presets.
- **Legacy path (`tonemap.hlsl`, selectable):** Hable / Uncharted 2 with A..F = 0.15, 0.5, 0.1, 0.2, 0.02, 0.3:
  - the input is scaled by 2 x exposure;
  - per-channel and luminance-scaled results are blended by `luminanceBased`, then divided by `hable(whitePoint)`;
  - noise is added: 0.1 x noiseIntensity x (2n - 1);
  - the result is lerped from the untonemapped colour by `influence`, saturated and raised to `^(1/2.2)`.
- **Off:** saturate, then the sRGB encode.
- **Dither noise:** a 64x64 RGBA8 texture from a seeded mulberry32 stream (seed 1). The game's noise texture is
  unknown.
- **The viewer's own background composite** comes after the post pass. It has no game counterpart.

## 8. lgt -> constants (lighting.shader_constants)

Every entry carries `{value, target, status, rule}`.

| Constant | Rule (status) |
| --- | --- |
| sunDirection | the lgt angles read as a line; the sun sits at the end above the horizon (guess). 311 of 513 vanilla sets have a negative inclination and are daylight |
| sunColor | sRGB decode of suncolor/255 x sunintensity (guess; alternative x/255) |
| shadowColor | sRGB decode (guess; alternative x/255). White when the field is absent |
| hemiTop/Bottom | sRGB decode x hemiintensity (guess; alternative x/255) |
| skyCubeRotation | skycubemaprotation read as radians (guess) |
| skyCubeIntensity | 1 (unknown: no lgt field; lightingbalance is a candidate) |
| skyCubeNormalize | 1 / mean Rec.709 luminance of the last refl mip (guess) |
| exposure | lgt exposure (name match; the lighting pass multiplies by it) |
| whitePoint | lgt whitepoint (name match) |
| mip bias | lgt mipmapbias on material lookups (guess); the Lift lookup adds -2 (measured) |

The page can override the sun, exposure and IBL intensity, and switch the colour decode to x/255. While any override
is set, the badge keeps `lgt_mapping` at U and says so.

## 9. Fidelity (manifest.fidelity, lighting.SHADING_FIDELITY)

M = measured, A = approximated, U = unknown, H = labelled hypothesis.

| Stage | Flag | Why |
| --- | --- | --- |
| material, normal_map, brdf, envbrdf, specular_occlusion | M | ported from the shaders above |
| ibl | A | formulas measured; the refl face order is a guess |
| gbuffer, shadows, ssao, colour_grade, dither, fog, antialiasing | A | emulated, simplified, or off for a lone unit |
| lgt_mapping, sun_direction, player_colour, tonemap | U | values or path unknown until calibration |

The page badge comes from `GameRenderer.fidelity()`. That is the bundle block with the page's choices applied:
placeholder, shadows off, tonemap off, overrides.

## 10. Verification (tests)

`tests/test_shading_gpu.py` (local) runs `viewer/shading/selftest.html` in headless Chrome on a synthetic fixture.
The page calls the same `glsl.js` functions. `tests/shading_ref.py` recomputes every pixel.

Measured 2026-10-11 on the RTX 4070 Ti SUPER (ANGLE D3D11) and SwiftShader:

| Kernel | Result |
| --- | --- |
| material + lighting, 3 tiles (relative error, p99.5) | 2.2e-4 on the GPU, 1.5e-6 on SwiftShader |
| 25-tap shadow filter | max 1.7e-7 |
| post, LUT path | float max 8e-4 on the GPU (fixed-point trilinear weights), 1.5e-7 on SwiftShader; 8-bit within 1 step |
| post, legacy and off | float max 1.6e-6; 8-bit within 1 step |
| GPU sRGB decode of SRGB8 texels | up to 3.75e-3 absolute from the exact formula on NVIDIA, 8e-6 on SwiftShader |

On the sRGB decode row: the reference therefore decodes BaseColor through the GPU's own measured table. The game on
the same GPU decodes the same way.

The other tests:

- `tests/test_shading.py` checks by hand:
  - the table's Schlick column;
  - GGX normalisation;
  - one fully hand-computed lighting pixel;
  - the material remaps;
  - the LUT at its texel centres;
  - the Hable curve;
  - the shadow filter on a step edge;
  - lgt parsing and the lighting packs.
- `tests/test_shading_local.py` renders the Iron Flail under both presets, checks the front-face convention (99 % of
  the visible fragments are clockwise-front with outward normals) and runs the interactive page.

## 11. Calibration still open

These need one RenderDoc capture or a screenshot fit on the test device (design section 8 items 1-6). Each would turn
a U into an M:

- the LightingConstants of a known lgt: sun colour and direction, hemi colours, skyCubeIntensity and skyCubeNormalize,
  shadow colour;
- which tonemap path runs;
- the cPlayerColors values;
- the shadow-map setup;
- the camera.

## Re-reading the shaders

Extract the `.hlslc` entries of `Game/Render/RenderCache.bar` (skill `bar-extract`, into a scratchpad only). Then
disassemble them with the scratch tool `render/tools/hlslc_dis.py` (Windows `d3dcompiler_47` `D3DDisassemble`). Write
the output only to a scratchpad, never to a repository.

A game patch that changes these blobs changes their hash suffix. When that happens, re-check sections 4-7 against the
new blobs.
