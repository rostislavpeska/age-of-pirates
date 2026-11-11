# Headless browser GPU path (M0 spike)

Re-run on any device with `python scripts/headless.py m0`. It writes `m0_result.json`, `run.json` and `browser.log`
per mode, plus the readback PNG, into a cache folder outside every repository. The page is `viewer/m0/`.

## What the spike checks

- **WebGL2 context:** the page needs one.
- **Raw texture upload:** a synthetic 8x8 texture (2x2 blocks, built in `viewer/m0/textures.js`, no game bytes) is
  uploaded raw with `compressedTexImage2D` in three forms:
  - DXT1 (`COMPRESSED_RGBA_S3TC_DXT1`): includes a 3-colour block with a transparent index 3;
  - DXT5: includes both alpha modes;
  - sRGB DXT1 (`COMPRESSED_SRGB_ALPHA_S3TC_DXT1`): sampling must return linear values.
- **Float target:** one triangle per region draws into a 512x512 RGBA16F target (`EXT_color_buffer_float`). A
  fourth region multiplies by 4, to prove values above 1 survive.
- **Float readback:** `readPixels(RGBA, FLOAT)`.
- **Per-texel comparison:** each texel centre is compared with two CPU decoders: exact float interpolation, and
  NVIDIA's integer rounding. The test suite cross-checks with an independent Python decoder.
- **Uniform texels:** with NEAREST sampling, every pixel of a texel's square must match its centre.
- **Result:** the PNG and the JSON report go to the local server, which writes them only into the output folder.

## Result on the owner's PC, 2026-10-11

HeadlessChrome 154 (`--headless=new`, throwaway profile), Windows 11, RTX 4070 Ti SUPER. Each run took 1.5 to 6 s.
Chrome never opened a window. The forced `d3d11` mode gave the same result as `auto`.

| GPU mode | Renderer | Path | EXT_color_buffer_float | s3tc | s3tc_srgb | Texture decoder | Max colour error |
| --- | --- | --- | --- | --- | --- | --- | --- |
| auto (no flag) | ANGLE (NVIDIA, RTX 4070 Ti SUPER, Direct3D11 vs_5_0 ps_5_0, D3D11) | angle-d3d11 | yes | yes | yes | NVIDIA hardware rounding | 0.00024 against the NVIDIA model (0.0196 against exact) |
| swiftshader | ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero)), SwiftShader driver) | swiftshader | yes | yes | yes | exact | 0.0020 (0.5/255) |

Both modes also offer EXT_color_buffer_half_float, OES_texture_float_linear and EXT_texture_filter_anisotropic.
The RGBA16F target kept 4.0, and the sRGB region returned linear values (grey 132/255 -> 0.2307).

## Findings

1. **The default headless path is the hardware GPU.** It runs ANGLE on D3D11, the same API the game uses. On this
   PC the browser's BC1 sampling therefore uses the GPU's own decoder: green 175/80 where the exact thirds are
   170/85, and the 3-colour half 127 for 127.5. A raw S3TC upload thus gives the same texels and the same rounding
   as the game on the same GPU. That supports the design's "measured by construction" claim for texture decoding;
   for this GPU it is now measured.
2. **NVIDIA's BC3 alpha rounding is not modelled.** It differs from exact by up to 6/255. The 6-value weights look
   like 3/16, 6/16, 10/16 and 13/16 (inferred from four values).
3. **SwiftShader is a full fallback for agents without a GPU.** It has the same extensions and decodes exactly
   (`--use-angle=swiftshader --enable-unsafe-swiftshader`). Its images differ from the game by up to about 5/255
   on BC1 midpoints, so a pixel-parity test has to name the decoder it expects.
4. **No CPU fallback was needed.** The page still carries one (S3TC decoded to RGBA8, uploaded as RGBA8 or SRGB8_ALPHA8)
   and reports it as `cpu-rgba8-fallback` when an extension is missing.
5. **Ending the browser resets its keep-alive connections.** The server ignores those resets. headless.py ends only
   the process tree it started (`taskkill /T` on its own PID) and reports any same-name process that appeared during
   a run and is still alive; it never ends those.

6. **Edge is not a safe fallback on this PC (INC-237, 2026-10-11 12:28).**
   - What happened: `msedge.exe --headless=new --user-data-dir=<temp>` exited with code 0 after 1.0 s and never loaded
     the page. The same second, 23 msedge.exe processes started, and a visible window "New tab - Personal -
     Microsoft Edge" opened 15 s later on the owner's own profile. The throwaway profile was deleted cleanly, so
     the started Edge did not use it.
   - Likely cause (inferred): a pending Edge update. `Application` held 154.0.4258.62 and 155.0.4283.45, and
     `msedge.exe` was already 155, so the launcher relaunched itself without the arguments.
   - Consequences in the tool:
     - Edge runs only when named (`--browser edge`).
     - A `new_<exe>` swap file beside a browser refuses the launch.
     - A launcher that exits within 8 s without contacting the server is reported as `browser-handoff`. The run
       lists the same-name processes that appeared and launches nothing more.
   - The window was left open: it is the owner's browser.

Not checked:
- AMD and Intel decoders.
- Mip chains and anisotropic filtering.
- Edge headless after its update completes.
