---
name: aoe3de-anim-viewer
description: "Preview and compare AoE3 DE animations, attachments and event timing in the local viewer or headless captures. Use for animation inspection; game-lighting fidelity remains separately qualified."
---

# AoE3 DE animation viewer

**Status: M0-M5 done (2026-10-11); calibration is next.**
- M0: scaffold, local server, headless runner, texture-path spike.
- M1: the backend that writes the unit bundle - vfs, proto_resolve, animfile, tactics, gr2_model, gr2_curves, material,
  ddt, lighting, bundle.
- M2: the page - skeleton, rig (rider seat, torch attach, horse/rider clock), GPU skinning, game-like camera, parity
  with Python and pose_sim; side-by-side with Blender.
- M3: the game shader (`viewer/shading/`, [references/shader-model.md](references/shader-model.md)): materialdefault
  BasePass + lightingpass in one forward pass, 25-tap shadow map, tonemap LUT, grade LUT, dither, sRGB; lighting
  presets as lighting packs; numpy pixel parity on the GPU and on SwiftShader.
- M4: the timeline dock, clip picker and data panels (`viewer/timeline/`, `viewer/panels/`); full-UI screenshots.
- M5: exports (`viewer/export/`, `scripts/sheets.py`, `video.py`, `metrics.py`) - render at tags / keys / fps, sheets
  with JSON sidecars, MP4 / WebP videos with a timeline overlay, compare mode with penetration and hoof metrics; M3 and
  M4 integrated in the page (the job runner moved to `viewer/export/job.js`).
- First unit: the Iron Flail (ypIronFlail), the rider on its horse. Also checked: Oprichnik, ypSowar, ypSteppeRider,
  Cossack build with every model readable.

## Rules

| Rule | How this skill keeps it |
| --- | --- |
| The game and the mods are read-only; no vanilla extraction in a repository (AGENTS.md rule 3) | Bundles, lighting packs, archive copies, outputs and browser profiles live under `%TEMP%/aop-anim-viewer` (`AOP_ANIM_VIEWER_CACHE`) or an explicit folder. Every write goes through `av_common.refuse_repo_path`, which refuses git work trees, an AoE3 profile or mods folder and the install |
| No images in a repository (rule 8) | PNGs, sheets and videos go only to the output folder (`<cache>/out/...`); the server and every writer refuse other targets. Results reach the owner with SendUserFile |
| No screen control (rule 11) | Agents use `headless.py` only: `--headless=new` with a throwaway profile under the cache, so no window appears and the owner's browser profile is never touched; every run ends its own browser tree and deletes its profile (run.json `profile_deleted`, `profile_holders`). The owner's own Chrome is never ended. `crosscheck.py` runs Blender as `blender -b`. The owner opens the `serve` URL in his own browser himself. Driving a visible browser or the Browser pane is screen control and is announced first |
| Edge only when named | Its launcher, with an update pending, dropped `--headless` and the throwaway profile and opened a visible window on the owner's own Edge profile (INC-237). Chrome is the only automatic choice. A browser with a pending update swap is refused, and a launch that hands off is reported as `browser-handoff` and stops the run |
| No downloads or installs | Raw WebGL2 and plain ES modules, no three.js, no build step. Python uses the standard library, numpy and Pillow; JS tests use Node's built-in `node --test`. ffmpeg comes ONLY from the device config (`config/tool-paths.local.json` `tools.ffmpeg.path`, the key is in `skill-library-audit/assets/tool-paths.example.json`) or `--ffmpeg`: never searched on PATH, never installed |
| No game bytes in tests | Synthetic fixtures are built inside the tests (`tests/av_unit_fixture.py`: a mounted unit in a fake profile). Game-dependent tests carry the `local` marker and read the live install |
| Hypotheses are labelled | Every measured / approximated / unknown / hypothesis decision is a fidelity flag in the bundle (`fidelity.stages` + `notes`), shown in the page badge and Fidelity tab and copied into every sidecar, sheet header and video overlay |
| Not for public export | M3 holds a port of disassembled game shader maths (formulas only, never shader bytes). Keep this package off the public allowlist |
| Pending owner decision | The LF-only animfile and two-root gr2 policy stays at `warn` (the bundle warns, the viewer still draws) |

## Commands

From the AoP root (`S=.claude/skills/aoe3de-anim-viewer/scripts`):

```
python $S/anim_viewer.py serve   --proto ypIronFlail                    # builds the bundle, prints the URL for your browser
python $S/anim_viewer.py build   --proto ypIronFlail [--json]           # the bundle only (%TEMP%/aop-anim-viewer/<id>)
python $S/anim_viewer.py render  --proto ypIronFlail --anim Attack_melee --at tags [--variant all] [--cam game,close,ortho3]
                                 [--lgt NewEngland_Skirmish] [--transparent] [--metrics] [--size 640] [--out DIR]
python $S/anim_viewer.py render  --proto ypIronFlail --anim all --variant all --at fps=8     # batch: one sheet per anim
python $S/anim_viewer.py render  --proto ypIronFlail --anim Attack_melee --key 133 --key-of child [--cam side]
python $S/anim_viewer.py video   --proto ypIronFlail --anim Attack_melee --variant 0 --fps 30 --loops 3 --timeline-overlay
                                 [--side-by-side Oprichnik] [--webp] [--cam close] [--no-mp4] [--ffmpeg PATH]
python $S/anim_viewer.py compare --proto ypIronFlail --other Oprichnik --anim Walk [--at tags] [--cam game,side]
python $S/anim_viewer.py compare --proto ypIronFlail --anim Attack_melee           # no --other: variant 0 vs variant 1
python $S/anim_viewer.py crosscheck --frame idle_k0:Idle:0:0 --frame attack_k133:Attack_melee:0:133
python $S/metrics.py <out>/<frame>.geom.bin                              # penetration + hoof heights of one dump
python $S/headless.py job <bundle id> job.json                           # any job (viewer/export/job.js lists the keys)
python $S/ui_shot.py --proto ypIronFlail --shot '{"name":"attack","anim":"Attack_melee","tag":"Attack","tab":"timing"}'
python -m pytest .claude/skills/aoe3de-anim-viewer/tests -q              # CI: add -m "not local"
node --test ".claude/skills/aoe3de-anim-viewer/tests/js/*.test.mjs"      # the pure JS suites (a glob: the folder
                                                                         # form fails on Node 24; parity/ and m4/
                                                                         # run through their pytest wrappers)
```

`--lgt`: a preset (`lighting.PRESETS`: Tantalus Viewer, NewEngland_Skirmish) is drawn from its lighting pack (every
reflection-cube level) with the default bundle; any other lgt set rebuilds the bundle with it as its own lighting.
`--bundle <id>` reuses a built bundle; `--other` / `--side-by-side` take a proto name or a bundle id.

### Exports (M5)

- **Exact times, not captures.** The page poses every frame at an exact main-clock time from the bundle clips; a video
  frame i shows t = (i / fps) mod D. Distinct poses are rendered once (Attack_melee at 30 fps x 3 loops: 45 poses for
  135 frames). The same time gives the same pixels (local test).
- **Times.** `--at tags` = every distinct reached tag time of the main and child clips (and attachments on their own
  clock); overflow tags (fraction > 1) and child tags past the main end are listed as skipped. `--at keys` = the main
  key grid; `--at fps=N` = i / N. The expansion runs in the page from the M4 timeline (one source of tag times).
- **Cameras.** `game` (pitch 47, FOV 30: unknown until calibration), `close` (pitch 14, aimed at 62 % of the height: a
  viewer choice), `ortho3` = front, side, top orthographic, `side` / `threequarter` / `otherside`. Sheets and videos
  keep one framing per clip (`bounds: clip`); a compare frames both units with one camera.
- **Sidecars.** Every cell PNG has `<png>.cell.json` (anim, variant, clip, key, time, tag, the keys of every side,
  camera, lighting, the full fidelity block, metrics); every sheet has `<sheet>.json`; every run has `report.json` /
  `video.json` / `compare.json` (bundle-schema section 18, "M5 exports").
- **Video.** H.264 High, yuv420p, BT.709 tags, `+faststart` (moov before mdat, checked by `video.mp4_boxes`), ffprobe
  readback in `video.json`; `--webp` adds an animated WebP (Pillow, durations in whole ms). `--timeline-overlay`
  burns in the title (unit, anim, variant, clip), the fidelity counts, time / key / loop / frame, the rider's key, a
  tag bar with the playhead, and a flash (border + `ATTACK @ 0.810 s`) on the frame that covers a tag, fading over
  0.1 s. A tag counts on the frame whose interval (t_prev, t] holds it, so it may show up to 1/fps late; its own time
  is printed. Missing ffmpeg: a clear error before any render (or `--no-mp4`).
- **Compare.** Two units (or one unit's two variants) on one clock: both at every tag stop of either, one sheet with
  A and B side by side (red frame: penetration deeper than `--flag-depth`, 0.10 m), and per cell the rider-horse
  penetration and, at each unit's own footstep tags, the height of the hoof the footprintbone names.

### In the page

Drag turns the camera, the wheel zooms, space plays/pauses, the arrow keys step one key, `[` `]` step to the previous /
next tag. The aside holds the unit search, the logic state, the clip picker (anims, variants with normalised weights,
a weighted roll, the pairing rule), the data tabs (Timing, Clips, Bones, Materials, Provenance, Audit, Fidelity), the
camera, the Shading section (renderer, lighting preset, tonemap, debug views, the lighting guesses and their
alternatives) and the export-PNG button. The timeline dock under the 3D view has the transport (tactics-rate preset:
AnimationRate H3 x clip / ROF "H1 ROF fit"), the ruler at the declared key rate, one lane per side and attachment, the
tag lanes with every attribute in a tooltip, footprint dots over the 3D view. The badge shows one letter per fidelity
stage; the Fidelity tab names them.

Device setup goes in the ignored local config only: `config/tool-paths.local.json` - `tools.chrome.path` (and
`tools.edge.path` if wanted), `tools.ffmpeg.path` for videos, `tools.blender.path` for the crosscheck - or
`AOP_ANIM_VIEWER_BROWSER`. `python <consumer-root>/scripts/tools/local_env.py` checks them.

## Fidelity: what is measured, approximated, unknown

Every stage is a flag in `manifest.fidelity` (bundle.py `FIDELITY_STAGES`, `TIMELINE_STAGES`, `EXPORT_STAGES`;
lighting.py `SHADING_FIDELITY`), with its note. 2026-10-11 (Iron Flail, 36 stages): M 11, A 13, U 6, H 6.

| Flag | Stages | Basis |
| --- | --- | --- |
| M measured | skinning, pose, vertex_input, texture_decode, material, normal_map, brdf, envbrdf, specular_occlusion, key_grid, export_frame_times | parity tests: JS = Python = pose_sim (1e-15 matrices, 1.5e-7 vertices); the shader port against a numpy reference (p99.5 2.2e-4 on the GPU); clip_decode's key grid; exact sample times by construction |
| A approximated | curve_sampling, ibl, gbuffer, shadows, ssao, colour_grade, dither, fog, antialiasing, footprint, video_encode, metric_penetration, metric_hoof_height | the formula is known but the setup is simplified or inferred (Granny index alignment, refl face order, one shadow map, no SSAO, MSAA for TAA); footprint dots of bones only declared by `<definebone>` at the origin; yuv420p; mesh metrics on open triangle soups |
| U unknown | camera, lgt_mapping, sun_direction, player_colour, tonemap, tag_overflow | values or the engine path are not known: FOV/distance, lgt -> LightingConstants, sun convention, player-colour decode, which tonemap runs, tag fractions > 1 |
| H hypothesis | rider_sync, timing, tag_timing, variant_choice, tactics_rate, compare_clock | labelled rules: rider variant i -> i mod n on the main clock, ROF from the protoactions, tags at fraction x clip, the weighted roll, AnimationRate x clip / ROF, two units starting together |

A page choice changes the flags it affects (placeholder renderer, shadows or tonemap off, overrides). Sheets show the
counts in their header, videos in the title band, sidecars carry every stage.

## Calibration (later, needs the owner)

Six U flags (design section 8 items 1-6) wait for one measurement on the **test device** (owner rule: no in-game tests
on the main machine; launching the game or attaching a tool needs the owner's approval):
1. **Screenshot fit (no install):** a frame of a vanilla unit or building at default zoom under a known lgt. A numpy
   PnP on six or more known model corners gives the camera (FOV, pitch, distance); a fit of the unit's pixels gives
   the sun direction and the lgt scalars (approximated afterwards, not measured).
2. **RenderDoc capture (MIT, needs the owner's approval to install and attach on the test device):** one frame reads
   the projection matrix, `LightingConstants` (cb4: sun colour and direction, hemi, skyCubeIntensity / Normalize,
   shadow colour), `cPlayerColors`, the final-pass shader (which tonemap runs) and the shadow-map setup exactly: U -> M
   for camera, lgt_mapping, sun_direction, player_colour, tonemap, and shadows' setup.
3. **Timing run** (design item 9, test device): a unit with a known ROF recorded at a fixed fps; the frames between
   Attack tags settle tag_timing, tactics_rate and the rider clock (H -> M), and audio timing the overflow tags.
Then: set the measured constants in `lighting.shader_constants` (status `measured`), the camera in `camera.js`, flip
the flags in bundle.py / lighting.py, and add an overlay test against the capture or screenshot (golden image).
Until then compare renders with each other, never with the game's absolute look.

## Layout

| Path | What |
| --- | --- |
| `scripts/av_common.py` | Shared helpers: repository refusal, cache, provenance, atomic writes, binary buffers, the device tool config |
| `scripts/vfs.py`, `proto_resolve.py`, `animfile.py`, `tactics.py` | M1 data: layered read-only file system (mods from `mods/age3-mod-status.json`, then the archives), proto + protomods, animfile resolver and audit, tactics + timing view |
| `scripts/gr2_model.py`, `gr2_curves.py` | M1 gr2: models (raw vertex streams) and clips (curves normalised to knots + controls); compressed or 32-bit files kept as unavailable |
| `scripts/material.py`, `ddt.py`, `lighting.py` | M1/M3 look: `.material` + materialdef, raw BC mips, lgt / refl / tonemap LUT / playercolors, shader constants, EnvBRDF table, lighting packs, `SHADING_FIDELITY` |
| `scripts/bundle.py` | Writes the bundle; `fidelity` per stage (incl. timeline and export stages), `build` per module |
| `scripts/server.py` | Local server: 127.0.0.1, token, Host/Origin checks; `/viewer`, `/bundle/<id>`, `/api/units`, `/api/bundles`, `/api/bundle/<id>`, `/api/job`, `POST /api/build`, `/api/file` (png/json/txt/bin), `/api/export`, page messages |
| `scripts/headless.py` | Headless Chrome runner: `run_page`, `run_job` (long jobs over `/api/job`), the M0 spike |
| `scripts/anim_viewer.py` | The CLI: build, serve, render, video, compare, crosscheck |
| `scripts/sheets.py`, `video.py`, `metrics.py` | M5: contact sheets + sidecars; frame schedule, tag hits, flash, overlay, ffmpeg MP4, WebP, MP4 box check; geometry-dump reader, winding-number penetration, hoof heights |
| `scripts/crosscheck.py` | The viewer against pose_sim + background Blender: sheet + silhouette IoU |
| `scripts/ui_shot.py` | Full-UI screenshots through a stdlib DevTools client (`--remote-debugging-port=0`, throwaway profile) |
| `viewer/lib/` | `skeleton.js` (curves, Newton quaternion step, R@S locals), `rig.js` (models per logic state, attaches, clocks, CPU skinning), `skin.js`, `render.js` (M2 placeholder), `camera.js`, M0 helpers `s3tc.js`, `gl.js`, `host.js`, `bundle.js` |
| `viewer/shading/` | M3 game shader: `glsl.js` (fused forward pass), `model.js` (pure maths, runtime fidelity), `renderer.js` (GameRenderer), `panel.js`, `hook.js` (the only entry points the page uses), `selftest.*` (GPU parity page) |
| `viewer/timeline/`, `viewer/panels/` | M4: timeline maths (`model.js`, `footprint.js`), the dock, overlay and picker (`timeline.js`, `picker.js`, `mount.js`, `dom.js`, `timeline.css`), data tables (`data.js`, `panels.js`) |
| `viewer/export/` | M5: `plan.js` (pure: tags / keys / fps expansion, cells, cameras, clip framing), `geometry.js` (pure: AVGEOM1 dumps), `job.js` (the job runner: two subjects, timelines, geometry) |
| `viewer/app/` | The page: interactive App (state = single source of truth), M3 + M4 mounted through their hooks, job mode through `export/job.js` |
| `tests/` | pytest suites (`test_export*.py` for M5); `tests/js/*.test.mjs` (pure), `tests/js/parity/`, `tests/js/m4/` (fixtures from Python) |
| [references/bundle-schema.md](references/bundle-schema.md) | The bundle v0, the job keys, the export files (section 18) |
| [references/shader-model.md](references/shader-model.md) | The M3 shader formulas, verification and open calibration |
| [references/headless-gpu.md](references/headless-gpu.md) | The M0 result: GPU path, extensions, texture decoder |

## Measured (2026-10-11)

Bound-mesh correction, 2026-10-12 (INC-279): the model reader follows
`Models.MeshBindings` by pointer. Unreferenced file-table meshes are excluded and
reported. Append-style exports can retain an unused donor mesh in `Meshes`;
drawing the entire table superimposed Japanese donor parts on the Korean castle.
Regression fixtures include same-named bound/unbound meshes and empty bindings.
Built submodels behind a construction wrapper still need an explicit diagnostic
selection; this does not certify engine routing or physics.

Static-building render regressions fixed, 2026-10-12 (INC-270/271):
`render --anim Idle --time 0` renders one rest pose when the component has no
GrannyAnim variants; `--variant all` also renders it once, without inventing a
clip. Vertex and tangent streams bind their declared buffer ids, including
mixed-buffer bundles. The CLI and GPU-binding regression tests cover both cases.
An explicitly converted Blender diagnostic bundle remains an approximation of
the exported geometry/frame/tangents; it is not a GR2 or an engine export pass.
Label its provenance and retain the lighting/calibration limitations above.

- Bundle (ypIronFlail): 5 animfiles, 9 models, 64 clips (62 decodable K32fC32f; the 2 quantized whip clips kept as
  unavailable - the whip is declared but never attached), 9 materials, 22 textures, about 21 MB, 2.6 s.
- Parity: B-spline within 1e-15 of Python; world matrices = gr2_model + gr2_curves = pose_sim (1e-15), CPU-skinned
  vertices 1.5e-7; silhouette IoU against pose_sim + Blender 0.95-0.96. Shader port: see shader-model.md section 10.
- Exports: render at tags of Attack_melee = 2 stops (SpecificSoundSet 0.60 s key 115, Attack 0.81 s key 156 of 289);
  video Attack_melee v0 30 fps x 3 loops: 45 poses, 135 frames, rendered in 3 s, H.264 High yuv420p 640x776, the Attack
  flash on frames 25, 70 and 115. At the Attack tag the flail strikes down on the horse's far (right, +X) side, so the
  game camera shows an empty fist there; use `--cam otherside` to see the strike.
- Compare Walk, ypIronFlail vs Oprichnik (two different 0.583 s clips: the Iron Flail's own iron_flail_horse_walk00 +
  iron_flail_rider_walk00, the Oprichnik's library horse_canter + oprichnik_canter): the Iron Flail rider's inner
  thighs and calves sit up to **0.286 m** inside its barded horse (Bip01_L_Calf, 2-3 % of the rider's vertices,
  |x| < 0.26 m under the saddle), the Oprichnik rider at most 0.042 m. Not a seat offset: the lowest pelvis vertex lies
  on the horse's top surface (gap 0.000 m) and the spine sits 5 cm lower than the Oprichnik's, so the 22-31 cm
  question of the design (item 8) is the legs inside the wider barded barrel, measured on the viewer pose; whether
  the game hides it the same way is a calibration question. The Iron Flail front-left hoof
  is 0.010 m above the ground at its FootstepLeft (FRNT LT) tag, the back-right -0.024 m at BACK RT, while FR and BL sit
  0.05-0.06 m up at theirs. Oprichnik footsteps carry no footprintbone (side legs only).

## Open

| Item | Content |
| --- | --- |
| Calibration (S2) | See "Calibration" above; the precomp oracle (posed bounds and engine bone samples, critic P1-4) |
| Timeline | Transitions are listed, not played (the Iron Flail tactics have none); turntable exports |
| Coverage (S3) | Quantized curve codecs, Oodle1 and 32-bit gr2 (most AoP mod models), materialvariant, the LowPoly models' material lookup (no `.material` beside `*_lp.gr2`: drawn untextured, warning `material-file-missing`) |
| Events (S6) | SpecificSoundSet -> soundset -> audio in the video; particle effects are not rendered (the torch fire is a lane only) |

The backend reuses other skills by importing them, never by copying:
- `aoe3de-unit-model`: `unit_gr2.py`, `clip_decode.py` (and through them `<consumer-root>/scripts/havok/gr2_read.py`);
- `aoe3de-bar-archives`: `bartool.py`, `xmbc.py`;
- `aoe3-texture-weathering`: `ddt2png.py`;
- `aoe3de-unit-animation`: `pose_sim.py` (parity, crosscheck), `render_obj.py` (crosscheck, background Blender).
