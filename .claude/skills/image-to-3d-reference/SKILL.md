---
name: image-to-3d-reference
description: Generate a 3D reference / concept model from an image or text with TRELLIS-2 (the owner's Blendify MCP tool generate_3d -> n8n -> fal) and use it safely - re-pose a character for 3D with a Gemini image edit, check the pose in 2D before paying, measure the generated model's pose, fit it to a skeleton on landmarks and keep it unposed as the design and bake reference. Use for "image to 3D", "TRELLIS", "generate_3d", "generate a 3D reference / concept model from an image or text", "re-pose a character for 3D". Not the game mesh, not topology, not UVs.
---

# Image to 3D reference (TRELLIS-2)

A generated model is a **reference**: a 3D concept to look at from every side, measure and bake from. It is never
the game mesh. Rules are marked **must**, **should** or **may**. Evidence comes from one armoured rider character
(2026-10-11: two text-mode generations, then a pose test of 3 paid calls; journal records below); a single case, so
every number is an example, not a law.

## What it is for

| Use | Not for |
| --- | --- |
| Design reference from every side: volumes, hems, panel splits, headgear, colours | The game mesh: 485,754 triangles, non-manifold, fragments; the low-poly is modelled by hand ([organic modeling](../blender-organic-modeling/SKILL.md) for characters) |
| Landmark source for a fit to a skeleton (chin, neck, ankles, hems) | Topology, edge flow, UVs or weights: none of it is usable |
| High-poly bake source (colour, cavity), unposed, after a landmark fit | Joints hidden under clothing (shoulder, hip, knee): inferred at best, +-2 to +-5 cm; seated or deformed drape |
| Re-posing a design into a skeleton's bind pose (image route below) | Weapons or props the input image does not show clearly: generate a separate reference or build them from the rig |

## Hard rules

- **Paid calls.** Every TRELLIS job is paid (fal); text mode also pays one image generation (OpenRouter); every
  re-pose edit is a paid image-harness call. Polls and dry runs are free. Agree the cap before the first call,
  count every call in every report (AGENTS.md rule 12) and keep a provenance JSON per output
  ([route reference](references/route.md), "Provenance"). Image-harness calls are Claude-only (AGENTS.md rule 10).
- **Secrets.** The MCP server holds the webhook base and key in its own environment; the image harness reads its own
  ignored local file. Never read, print or write a webhook host, URL base, workflow id, API key or gate value into
  a tracked file, a command line, a log or a message: the repository is public.
- **Silent fallback.** An image sent to a workflow without the image branch runs a **paid text job on the label**
  and returns a model that ignores your image. After any workflow change, check the first image-mode job: its
  execution runs the image branch only (no prompt composition, no image generation), and the model shows your design.
- **MCP restart.** If the `generate_3d` schema has no `image` parameter, the running server is older than the
  image-mode code: ask the owner to restart it. Never put an image path into `prompt` (that is a text job).
- **Live scene.** `import_canonical_model` drives the owner's LIVE Blender (screen control: announce first, AGENTS.md
  rule 11; [live-session safety](../blender-mcp-safety/SKILL.md)) and it joins the model into one mesh, applies
  transforms and scales its largest side to `target_size` (default 1): the metric size is lost. Download the GLB and
  use the background tools below instead.
- **Images and models stay out of the repo** (AGENTS.md rule 8; a generated model is work data, never a mod file):
  work folder or session scratchpad; the bundled tools refuse output inside any git work tree.

## The route

```
generate_3d(prompt)            text mode:  prompt -> server prefix ("product shot of ..., one single object,
                                            light-grey background, no shadows") -> OpenRouter image (default
                                            google/gemini-2.5-flash-image; the image is NOT returned) -> TRELLIS-2
generate_3d(image=..., prompt=label)  image mode: your image -> TRELLIS-2; no image generation, label only logged
   -> {job_id, status_url, response_url} -> wait_for_3d_job(status_url, response_url) -> glb_url -> download
```

`image` takes a local .png/.jpg/.webp of at most 8 MiB (sent inline as a data URI), a public http(s) URL fal can
fetch without auth, or a `data:image/...;base64,` URI. Image mode has been live since 2026-10-11. A
`wait_for_3d_job` that hits the client timeout is not a failure: poll again (polls are free). Request contract,
download, import routes and the provenance fields: [route reference](references/route.md).

## Character route: design image -> re-pose -> 2D check -> 3D -> measure -> fit -> use unposed

Words do not set a pose in TRELLIS: a text prompt that only said "A-pose" gave arms hanging (-25 deg), the pose in
words and degrees gave a near T-pose (+53 deg) and a drifted design. TRELLIS keeps the pose of the image it gets, so
the pose **must** be set in a cheap 2D edit and checked before the paid 3D job.

1. **Target.** Read the bind-pose angles from the target skeleton: upper arm from straight down, elbow bend, leg
   spread (the game layer owns the skeleton). Start from an existing image of the approved design - a render of the
   current model or the concept art - front view, full body with the feet, plain light background.
2. **Re-pose edit** (paid, one call): image-harness Gemini edit, `--provider gemini --image-size 1K`, `--dry-run`
   first. Describe the pose with body landmarks and negatives, not degrees alone: "NOT a T-pose, wrists at hip
   height, each hand a hand-span outside the skirt", and "keep the costume ... exactly identical; change only the
   pose and the background". Wording that worked and failed: [prompting](references/prompting.md).
3. **2D check** (free): `grid.py` on the edited image, joint picks into a JSON, `pose_angles.py`. Off target: one
   corrected edit with sharper landmarks; do not pay for 3D on an image that misses the pose.
4. **3D job** (paid, one call): `generate_3d(image=<edited image>, prompt=<short label>)`, poll, download the GLB at
   once, record its sha256 in the provenance JSON.
5. **Preview and stats** in background Blender: `preview_glb.py` (beside the reference body), `mesh_stats.py`
   (welded parts and fragments). Look at the renders before measuring.
6. **Measure the 3D pose**: `render_ortho.py` (normalised front and side ortho renders with the pixel mapping),
   `grid.py`, `pose_angles.py` with front and side picks. Method and pick uncertainty:
   [measurement](references/measurement.md).
7. **Fit by eye on landmarks**, never by bounding box: chin, neck, shoulder line, hips, knees, ankles on metric
   orthographic overlays; one uniform scale; residuals recorded. [Fitting](references/fitting.md).
8. **Use it unposed** as the design and bake reference; cross-sections show hidden landmarks and the panel layout.
   **Never** deform the generated high-poly into the bind pose with transferred weights: skirts take arm weights and
   flare like wings. Model the low-poly with the organic skill; the gates there apply.
9. **Report and record**: pictures of each step to the owner as they land, paid-call count, provenance paths, and a
   [journal](../workflow-journal/SKILL.md) record for every measurement or failure.

Non-character objects follow steps 4-5 and 7: text mode for a quick look, image mode when the look must match.

## Evidence (2026-10-11, one armoured rider; target bind pose: upper arm 26.2 deg from down, elbow 26.5, legs 16.4)

| Run | Route | Upper arm from down | Elbow bend | Leg spread | Design | Paid |
| --- | --- | --- | --- | --- | --- | --- |
| text, "A-pose" named only | text mode | ~1 deg (-25) | 10 (3D) | 12.6 | as prompted | 1 TRELLIS + its image |
| E1 text, pose in words and degrees | text mode | 79 (+53, near T-pose) | 0 front / 35 3D | 12.5 | drifted: helmet, plume, added panels | 1 TRELLIS + its image |
| E2 Gemini edit of our own render | image harness, gemini-3.1-flash-image-preview, 1K | 28 / 29 2D (+2..+3) | 6 / 4 front | 14 | kept | 1 edit |
| E3 TRELLIS-2 from E2 | image mode | 23.2 3D (-3); 21.6 / 22.8 2D | 19.5 3D | 13.0 | kept | 1 TRELLIS, no image generation |

- E3 mesh: 485,754 triangles, two 2048 maps, 90 % of the welded vertices in one part plus 377 fragments (plume,
  hands); 11,924 non-manifold edges (re-measured with the bundled `mesh_stats.py`, identical counts).
- Pick uncertainty: the E3 elbow is fused to the coat; the same picks give 24.6 / 26.6 deg 2D and 26.6 deg 3D with
  the elbow kept as picked, so the upper-arm error lies between -3 and +0.4 deg and the elbow came out 7-10.5 deg
  under-bent ([measurement](references/measurement.md), "Uncertainty").
- Fit: landmark scale 2.31 against 2.01 from the bounding box (a head too short with the plume included); residuals
  chin +0.5 cm, neck -0.8, shoulder -4.6, ankle +0.7; a weighted least squares gave 2.318.
- Journal: `2026-10-11-claude-opus-01` (do not pose the high-poly), `2026-10-11-trellis-pose-test-01` (text pose
  fails, image edit holds), `2026-10-11-claude-opus-02` (image -> image -> 3D holds the pose), the fit records
  `2026-10-11-claude-opus-fit-01` to `-05`, `2026-10-11-claude-opus-flail-04` (weapon) and
  `2026-10-11-claude-i3d-skill-01` (pick uncertainty on a fused elbow), the body and helmet records
  `2026-10-11-claude-opus-body-01`, `-helmet-02` and the summary `2026-10-11-claude-opus-03`.

**Usefulness: interim verdict, final pending.** The remodel that measures TRELLIS's value (journal project
`pyeongon-rider`) has recorded its geometry stages (`2026-10-11-claude-opus-03`, 2026-10-11): **shape high** - every
pose-independent dimension (coat, belt, skirt panels, neck guard, helmet, hems, splits, colour regions) came from the
reference within about 1 cm (median 0.1-0.3 cm, p90 up to 2.7 cm); **joints, proportions, deformation none** - arms
fused to the coat, hips and knees hidden, different anatomy, and a standing figure's A-line coat lies like a board
over a flexed thigh when seated; **weapon zero** (generated without one, by its prompt). It saved guesswork rather
than wall-clock time (about 10-15 min of tooling per agent for fused, seam-split geometry). Net so far: worth it for
the silhouette and costume layout of a new unit, with a bind-pose input image. Texturing and bake use are not measured
yet; update this paragraph when the remodel's final record lands.

## Bundled tools (background Blender or host Python; details in [scripts/README.md](scripts/README.md))

| Script | Does |
| --- | --- |
| `scripts/preview_glb.py` | Solo and beside-reference renders with the model's own textures, mesh and texture stats |
| `scripts/render_ortho.py` | Normalised orthographic front and side renders and the pixel <-> metre mapping |
| `scripts/mesh_stats.py` | Welded parts, fragments by height band, open and non-manifold edges, texture sizes |
| `scripts/grid.py` | Pixel grid in source coordinates for picking joints |
| `scripts/pose_angles.py` | Pose angles from a picks JSON: 2D, 3D from front + side, errors to a target, overlays |

Blender is found as in the organic skill (`--blender-exe`, `--local-config`, `BLENDER`, PATH, standard folder);
tests: `python -B -m pytest .claude/skills/image-to-3d-reference/tests -q -p no:cacheprovider` (Blender suites
skip without Blender).

## Related

- [image-harness](../image-harness/SKILL.md): the paid re-pose edit (Gemini route), its dry run, ledger and budget.
- [blender-organic-modeling](../blender-organic-modeling/SKILL.md): the character low-poly, skinning and gates; the
  generated model is only its reference.
- [workflow-journal](../workflow-journal/SKILL.md): record measurements and failures the moment they happen.
