# An own second Painter instance (9.1.2), and generator masks for a compositor

Verified 2026-10-09 on Painter 9.1.2 / Python API 0.2.11 while another agent's hidden instance held the built-in
endpoint with its project open (Korean House texture pass; evidence in the Korean art repo, `house_states_r1`
`evidence/r15/`). The other instance was probed read-only before and after and stayed on its file, saved.

## Why and how

The built-in remote scripting port is fixed (60041; `netstat` shows it bound on `[::1]`, so query it via
`localhost`, not `127.0.0.1`). A second `--enable-remote-scripting` process cannot get its own port. Instead:

1. `scripts/launch_second_instance.py --report OUT.json` starts Painter hidden, **without**
   `--enable-remote-scripting`, with `SUBSTANCE_PAINTER_PLUGINS_PATH` -> `scripts/second_instance` for that process only.
   Its `startup/rpc_endpoint.py` (a PySide `QTcpServer` on the main thread) serves the same `/run.json` protocol on
   `127.0.0.1:60042`. Startup to endpoint: 6.4 s.
2. Client: `PAINTER_HOST=127.0.0.1`, `PAINTER_PORT=60042`, `PAINTER_EXPECT_PID=<endpoint_pid>`. `sp_remote.py`,
   `later()` and `LegacySession` work unchanged (hidden window included: 300+ bounded steps, no crash).
3. Work only on a **copy** of the other person's `.spp` in your own folder; never open, save over or close their file.
4. The startup modules need `start_plugin()` / `close_plugin()` (see Painter's `substance_painter_plugins.py`).

## Mesh maps on a copied master

`BakingParameters.set_enabled_bakers([WorldSpaceNormal, Curvature, Position, Thickness])` on every set re-bakes only
those slots; the bound AO / Normal images stay (assert the slot URLs before and after). `MeshMapUsage` is a pybind
enum and is **not iterable** - list the names. After the bake: `ui.switch_to_mode(UIMode.Edition)`.

## Generator masks for a compositor (probe-channel rounds)

Above the composed material: one black baseline fill (color/rough/metal bound to a black 8x8 image), then per effect a
fill with a white texture on **one** channel + black mask + generator (`select_mask` immediately before
`ensure_generator_effect`, then `bind_generator`, values, `inspect_generator`). Export color / roughness / metallic as
grayscale; more effects than channels -> `set_channels` toggles per export round. The colour export is sRGB
(linearize before use), roughness/metallic are linear. Generators on 9.1.2 starter assets: `mg_dirt`,
`mg_dripping_rust`, `mg_metal_edge_wear`, `mg_mask_builder`, `mg_position`, `3d_linear_gradient`, ... Parameter names
(read back): Dirt `dirt_level, dirt_contrast, grunge_amount, Grunge_Scale (int), edges_masking`; Dripping Rust
`Rust_Spreading, Rust_Contrast, Spreading_Smoothness, Drips_Intensity, Drips_Smoothness, Drips_Samples_Amount`;
Metal Edge Wear `Wear_Level, Wear_Contrast, Grunge_Amount, grunge_scale, Edges_Smoothness,
Ambient_Occlusion_Masking, Curvature_Weight`.

Measured pitfalls:

- **Dirt is strongly non-linear in `dirt_level`:** on the same page 0.55 covered 87-99 % (> 0.5), 0.25 left 1-9 %,
  0.40 gave a usable mid-range (mean 0.24-0.49, std 0.21-0.24). Measure each mask's mean / std / coverage inside its
  material before using it; a saturated mask is no breakup.
- **AO-driven masks carry the model's own rhythm** (e.g. one dash per roof tile course from the course-lip AO). For
  growth that should ignore it, use the blurred mask plus a large-scale cluster mask and per-lane noise.
- Edge Wear follows UV-chart borders on an owners-only mesh (open edges read as convex): gate it with a geometric
  distance to the material edge.

## Compositor hygiene

- A smoothstep whose two edges coincide (a threshold fitted to 0 on a sparse mask) divides by zero: NaN -> black after
  the uint8 cast. Guard the denominator and refuse a coverage target the mask cannot reach.
- Directional effects (rain runs, moss along a slope) must use the texel's world down direction (affine fit of each
  face's UV -> 3D), not the image axis: charts are rotated freely in UV.
- Bind the final maps back into the copy as a top fill (`color` + `rough`), save, close, reopen, export and compare
  with the shipped maps: the `.spp` then holds the generators and the result (measured mean delta 0.00002, p99 0).
