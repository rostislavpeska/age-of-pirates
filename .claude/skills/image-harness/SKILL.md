---
name: image-harness
description: Generate texture sources and paint geometry-locked UV or unrolled layout sheets, then validate and map them onto existing atlases. GPT/Codex/Astra use their native image-generation tool; Claude Code alone may use the billed webhook/CLI. Use for custom material images, ornaments, decals, or model textures generated from a layout.
---

# Image generation and geometry-locked texture painting

## Choose the provider before generating

Owner clarification, 12 October 2026: the texture-painting method also applies to GPT using native generation.

- **GPT/Codex/Astra:** use the available native image-generation tool and its imagegen instructions. Do not run
  this package's webhook client, probe its credentials, set `CLAUDECODE`, or switch to a separately billed API.
- **Claude Code:** use the existing CLI/webhook route below. Its technical Claude-only guard stays enabled.
- **Other agents:** use an explicitly available native generator; otherwise report it unavailable. No implicit
  permission to use the billed Claude route.

Both routes follow the layout, structure, scope and map-back checks below. A generated bitmap is a source,
not a certified atlas, normal, AO, alpha or player-colour mask. Keep those geometry/semantic-derived channels.
For native results save the original output, exact prompt, input roles and hashes, output hash/dimensions,
provider route, call count and the gate results with the external checkpoint. Record unknown usage/cost as
unknown; do not fabricate a provider receipt. Copy the output into the project asset package before handoff.

## Claude-only CLI/webhook

The remaining CLI commands are for Claude Code only. Every webhook call is billed to the owner's API accounts
(AGENTS.md rule 10). The client refuses unless `CLAUDECODE=1`, set by Claude Code itself.

## Secrets (the repo is PUBLIC)

URL and key come from `IMAGE_HARNESS_URL` / `IMAGE_HARNESS_KEY`: real environment variables first,
else `config/image-harness.local.env` (gitignored; copy `config/image-harness.example.env` on a new
device and ask the owner for the values). Never write the URL, host, webhook path, workflow id or key
into any tracked file, command line, log or message; the client never prints them and refuses a non-https
URL. `python .claude/skills/image-harness/scripts/generate.py --ping` checks URL + key for free (no image,
no bill). `scripts/test_no_secrets.py` fails if the local file is tracked or unignored, or if its values
appear in any tracked file.

**New device, Claude Code in auto mode (2026-10-08):** the permission classifier refuses an agent
reading the n8n webhook URL from the Claude config or writing `config/image-harness.local.env`
("Credential Exploration"), and may then refuse even `test -f` on that file. Do not work around it:
write a small self-deleting helper into the session scratchpad that composes the file from the
owner's own config, give the owner the one-line command to run it, and verify with `--ping`
afterwards. Until then the harness is unavailable; plan the work without paid image edits.

## Generate

```bash
python .claude/skills/image-harness/scripts/generate.py "PROMPT" --out "<scratchpad or OneDrive checkpoint>" --name giwa_tile --quality medium
```

| Option | Values (default) |
| --- | --- |
| `--provider` | `openai` (default) / `gemini` (default when `--ref` is given) |
| `--model` | openai `gpt-image-1` (default), `gpt-image-1-mini` (cheaper; **always for icons**, see Budget rules), `gpt-image-1.5`; gemini `gemini-3.1-flash-image-preview` (`gemini-2.5-flash-image` fallback). The workflow forwards any model name to the provider |
| openai | `--size 1024x1024` / `1536x1024` / `1024x1536`, `--quality low\|medium\|high\|auto` (medium), `--background transparent\|opaque\|auto`, `--n 1..4`, `--format png\|jpeg\|webp` |
| gemini | `--aspect 1:1` (e.g. 16:9), `--image-size 1K\|2K\|4K`, `--ref img.png` (repeatable: style references for a new image; to change a picture use Edit below), one image per call |

Output: `DIR/NAME_1.png ...` plus `DIR/NAME.json` (operation, prompt, inputs with sha256, provider,
model, settings, usage, estimate, revised prompt, time) - the provenance record texture work requires.
It prints paths only; never read image data into the conversation except to look at a result.

## Paint a model's textures from its UV layout

The main texture use, and the one agents missed while it lived only in a masonry skill (owner 2026-10-10: "More custom
GPT or Gemini generated textures ... These can be generated from UV maps already. Check the skill. Maybe needs better
description"). **The geometry owns the structure, the image model only paints the surface.** Full method, gates and
compose rules: [masonry-texturing](../masonry-texturing/SKILL.md) section 7 and its
[AI paint gate](../masonry-texturing/references/ai-paint-gate.md); it applies to any geometry-locked sheet, not only stone.

1. **Layout sheet** in the model's own unrolled frame, at a scale above the final page density: lit layout colours
   measured from the vanilla counterpart, joints and openings drawn, flat 0.5 grey outside, plus every detail the paint
   must carry (rivets, nail heads, bung hole, rope twist). Props: lay the charts out like a vanilla prop atlas (barrel
   staves side by side, heads as discs, long strips stacked as rows). Packed fragments of a building do not work.
2. **One native or Claude edit per sheet.** GPT uses its native tool with the layout as the edit target and the
   appearance image as reference only. Claude uses `--image LAYOUT.png --image STYLE_REF.png --provider gemini --image-size 1K` with the
   vanilla counterpart as the "style reference only" image (barrel: `TNT_Barrel_matb`, wheel: `organ_gun_wheel_matA`,
   crates: `nat_wood_crates_small_b_mata`). 1K is enough when the sheet's px/m exceeds the page's texels/m.
3. **Gate before use.** Masonry: the joint F1 gate. **Wood:** grain cracks are dark lines too, so a correct wood painting
   scores joint F1 0.25-0.41; gate wood with silhouette IoU >= 0.90 against the layout plus joint recall >= 0.70 at a
   shift <= 4 px (Korean props 2026-10-10: 5/5 paintings IoU 0.988-0.996 at zero shift, recall 0.76-0.95).
4. **Compose and map back:** luminance pulled toward the vanilla measurement, the painting's colour mostly kept (chroma
   0.85; 0.6 plus layout-mean luminance washed a good keg painting grey), joints from the layout; every page texel samples
   the sheet through the same layout coordinates. Normals: structure from the layout, surface detail from the painting
   (masonry-texturing `paint_relief.py`). Then edge wear, rust and dirt generators from the bake's EDGE/CAV masks.
   **Map-back rules (Korean Market 2026-10-11):** re-express the sheet's normal xy in each island's UV tangent frame (islands
   are rotated or mirrored on the page; writing sheet-frame normals lights the relief from the wrong side); box-prefilter the
   sheet to the page texel footprint before sampling (a 400-1500 px/m sheet point-sampled at ~105 texels/m aliases); compose
   gated paintings only, after the role-based finish pass (onto the final maps), and make a compose that reads its tone
   target from the maps it writes a no-op on maps it already composed.
5. **Register, then gate what was asked.** Gemini returns its own aspect (21:9 asked, 33:14 returned): register the painted
   board by its bounding box against the flat grey surround instead of stretching the canvas (a 1 % drift cost 0.05 glyph IoU).
   A best shift on the edge of the search window is no optimum. Gate the property the owner asked for, measured on the
   painting: thatch courses "in different directions" = the structure-tensor straw angle of every course within 6 degrees of
   its layout angle and alternating (a painting that ignored the slants failed; one that followed +-4..8 degree slants passed
   but did not read - draw the requested property boldly enough to be seen).
   **Multi-item sheets (Market stall goods):** Gemini repaints the "flat grey" surround (lighter, vignetted): measure the
   background from the painting's border. Score each rect's silhouette in its own window. Test item presence by colour
   contrast to the ring around it (dark items fail a "brighter centre" test) and item kind by brightness-free
   chromaticity. Gemini keeps large distinct shapes but regroups small repeated items: mark each small item's kind in the
   layout, gate per crate, and compose each crate from the painting that passed for it.
   **Every composed face declares its grain intent and is validated** (Korean Market stall thatch, owner: "wrong texture
   orientation", "side textures ... flawed"). Strands follow the fall line on tops, undersides and end profiles. Derive
   each face's strand axis in 3D from its corners and the sheet coordinates it actually sampled, and validate with
   `blender-architecture-texturing/scripts/check_material_direction.py`. A vertical end-profile frame failed by 70 degrees
   (keep it as the negative control). A THICK alpha part (a thatch slab) takes one folded parameterisation, and its cut
   runs through every face. Per-face frames and opaque end-grain edges gave seams and a leftover rim under the fringe
   (owner: "the corner is redundant"); see `alpha-cutout-texturing`.

Reference implementation (Korean props, outside AoP): `korean-market-dock/recipes/props_ai_sheet.py` (layout, gates,
compose) and `props_sheet_apply.py` (map back, relief, edge generators).

**Re-posing a character for 3D** (a Gemini edit that puts a design into a skeleton's bind pose before TRELLIS): the
separate `image-to-3d-reference` skill holds the wording, the 2D check and the route.

## Edit one UV island with any generator (GPT native included)

Owner, 12 October 2026: "Astra can't use the harness ... the edit image based on UV island ... The feature is great!
Should work also for GPT native image generation (without harness)". `scripts/uv_island_paint.py` prepares the
edit and applies the result. It never calls a generator, so GPT/Codex/Astra use their native image editing, Claude
may use the harness, and a manual edit works too.

1. **Extract (free, local):**

   ```bash
   python .claude/skills/image-harness/scripts/uv_island_paint.py extract --page X_BaseColor.png --gr2 X.gr2 --mat mata --at U,V --out DIR
   ```

   - Islands: `--at u,v` (page fraction, repeatable), `--island N`, or `--all`.
   - Raw GR2 UVs are page image coordinates.
   - **Before game export / Blender source:** use `--uv-json selected_uv.json` instead of `--gr2/--mat`.
     JSON is `{origin:"top-left", source_id:"blend-hash:object:page", uv_layer:"name", triangles:[[[u,1-v],...],...]}`.
     Export selected faces of the intended page only; triangulation is a read-only view of Blender's loop triangles.
     The helper records the JSON hash. Never export a temporary game model just to extract a paint island.
   - Writes `EDIT_INPUT.png`: the island crop on a neutral grey canvas of a generator aspect (1:1, 2:3, 3:2).
   - Writes `EDIT_MASK.png`: alpha 0 = the island = editable.
   - Writes `GUIDE.png` (magenta outlines) and `ISLAND.json`, which holds a prompt template.
2. **Paint, with one call per island set:**
   - **GPT native:** edit `EDIT_INPUT.png` and attach `EDIT_MASK.png` if the tool takes a mask. Use the template
     from `ISLAND.json`: keep every edge, joint and opening in place; flat light; no text; no new objects.
     In Codex, inspect the input with `view_image`, then call native `image_gen` with `referenced_image_paths`.
     The current native tool has no binary-mask argument: treat the guide as visual guidance and enforce the
     exact mask locally during `apply`. Do not imply the generator obeyed a hard mask. Preserve its original
     result and prompt; apply to a new candidate page, inspect the mapped model, and retain failed gates.
   - **Claude:** `generate.py --image EDIT_INPUT.png --provider gemini`.
   - Save the result as `PAINTED.png`. Save the exact prompt, too.
3. **Apply (free, local):**

   ```bash
   python .claude/skills/image-harness/scripts/uv_island_paint.py apply --dir DIR --painted PAINTED.png --route native-gpt --prompt-file PROMPT.txt --out-page NEW.png [--ddt X.ddt --ddt-out NEW.ddt]
   ```

   - A returned size with the same aspect works: resize to the canvas and take the crop from its placement.
     An aspect mismatch above 2% is rejected; register it rather than stretching the texture.
   - **Gate:** the edge correlation inside the island must be ≥ 0.35. Pass `--restyle` only when a new structure was
     asked for. A random image scores 0.00; a faithful repaint scores 0.997.
   - Only island texels change. Alpha is never repainted.
     `APPLY.json` explicitly reports zero changed protected texels and zero changed alpha texels.
   - `APPLY.json` records the route, prompt, call count, hashes and cost. Cost is `unknown` unless known; never a
     made-up receipt.
   - `--ddt` patches the game DDT block-wise.

Use it for a part repaint on an existing page, such as one post, one sign or one door. For whole models, follow
"Paint a model's textures from its UV layout" above. The same rule applies: a generated bitmap is a colour source,
not a normal, AO, alpha or player-colour map.

## Edit (harness v2)

Change an existing picture instead of starting from nothing: fill a placeholder region, repaint one
area, restyle a layout, combine inputs.

```bash
# 1. free: mark the editable area (alpha 0) and look at the magenta preview before paying
python .claude/skills/image-harness/scripts/make_mask.py layout.png mask.png --key FF00FF --grow 4 --preview mask_preview.png
# 2. free: validate + estimate
python .claude/skills/image-harness/scripts/generate.py "Fill the transparent area with ..." --out "<scratchpad>" --name fill --image layout.png --mask mask.png --quality low --dry-run
# 3. paid: the same command without --dry-run
```

| Route | How | Notes |
| --- | --- | --- |
| OpenAI masked edit | `--image IN.png --mask MASK.png` | only alpha-0 pixels change; the mask is applied to the FIRST image, same size, PNG < 4 MB (checked locally before paying) |
| OpenAI edit, no mask | `--image A.png [--image B.png ...] --provider openai` | up to 16 inputs, the model redraws the whole picture; `--input-fidelity high` keeps faces/details of the inputs (gpt-image-1/1.5) |
| Gemini edit | `--image IN.png --provider gemini` | instruction-only edits, no mask; also the route for "paint in the style of this reference" |

`make_mask.py` takes `--rect x0,y0,x1,y1` (repeatable), `--paint BW.png [--edit-black]` or `--key RRGGBB
[--tol]`; `--grow PX` lets the model blend into the surroundings, `--feather PX` softens the border.
An OpenAI edit still regenerates the whole image and mask edges are soft, not pixel exact: composite
the result back over the original through the mask when the kept area must stay identical.

**Status (2026-10-09, INC-203): OpenAI edits are disabled.** The multipart edit route
(`references/workflow-v2.md`) was published on the owner's word; its first call hung the owner's
production n8n (it also runs the AI Founders pipelines) inside the "OpenAI Edit" HTTP node, until the owner
restarted the server 35 min later. The client refuses to send an OpenAI edit (masks still validate with
`--dry-run`); Gemini edits (`--provider gemini`, no mask) use the route that has run since 2026-09-28.
Rolling the route back needs the owner (the permission classifier refused the agent). A redesign keeps
binary bytes out of n8n Code/HTTP binary handling (see "Workflow").

## Agent safety (paid tool, agent-only)

- `--dry-run` validates everything locally and prints the request summary with an estimate; nothing is
  sent. Use it before every new kind of request.
- Duplicate guard: an identical request (prompt, settings, input and mask hashes) within 10 minutes is
  refused, so an agent's retry never pays twice. `--allow-repeat` only when a second sample is really wanted.
- Ledger: every paid call is appended to `~/.image-harness/ledger.jsonl` (device-local; `IMAGE_HARNESS_LEDGER`
  overrides). `--ledger` prints calls and estimated USD per day, model and operation: the count every report
  needs (AGENTS.md rule 12).
- Errors are actionable and arrive before any spending: mask size, alpha or format, a missing input, a
  wrong provider for a mask or reference all exit with the fix in the message.
- Offline tests: `python -m pytest .claude/skills/image-harness/scripts -q` (no network, nothing billed).

## Budget rules

- Start with `--quality low` (openai) or `1K` (gemini) to check composition; spend `high` or
  `2K/4K` only on the chosen prompt. One test image per idea, not batches.
- `--out` must be outside the repository (the client refuses otherwise; AGENTS.md rule 8).
  Texture sources go to the model's OneDrive checkpoint, trials to the session scratchpad.
- For textures follow `blender-architecture-texturing/references/sources-seamless.md`:
  orthographic, neutral light, no baked shadows or lettering, physical scale in the prompt,
  tile check after. A generated RGB image is never a normal map; relief comes from geometry bakes.
- For game icons follow `icon-forge/references/visual-language.md` (form by tech, colour across the set,
  rendering, prompt template) and use **`--model gpt-image-1-mini --quality low`** unless the owner asks
  otherwise (owner 2026-10-09: "for icons we always use mini if not requested differently"; tested the
  same day: at 128 and 64 px as good as gpt-image-1). Fall back to the default `gpt-image-1` when mini's
  result is bad or the icon is complex (a scene, several figures). **Unit portraits** (the 512 portrait and the
  unit icon made from it): the Gemini route with two vanilla portraits as `--ref`, one call per portrait, then
  `icon-forge` `portrait_compose.py` (icon-forge "Unit portraits"; tested 2026-10-09: closest to vanilla;
  gpt-image-1 came out cartoon-like). Everything else keeps the default `gpt-image-1`.
  One icon per call: a grid of icons in one image splits one image's detail between the cells (low
  1024 = 272 output tokens, 1536x1024 = 400) and comes back crude.
- Cost per 1024x1024 image (OpenAI list prices, checked 2026-10-09): gpt-image-1 low ~$0.011, medium
  ~$0.042, high ~$0.167; gpt-image-1-mini low ~$0.005; gpt-image-1.5 low ~$0.009. OpenAI marks
  gpt-image-1 deprecated (a third-party guide gives 23 October 2026 for its retirement): when it stops,
  the workflow default needs a new model, on the owner's word (`gpt-image-2` takes any size divisible by 16
  up to 3840x2160 and no `input_fidelity`; `--model` passes it through today). Edits add the input
  images' tokens to the price; the client's estimate covers the output image only.

## Workflow (owner's n8n, "Claude Image Harness (Webhook)")

Webhook `POST` -> `x-api-key` check (the Character Generator harness pattern) -> normalise
request -> route openai / gemini / openai_edit -> provider HTTP call (provider keys stay in n8n
credentials, never in this repo) -> images as base64 JSON. The edit route and the request contract are in
`references/workflow-v2.md` (sanitized: no ids, host or path).
Synchronous: the response carries the images (tested 2026-09-28: openai low 1024 and gemini 1K
with a reference image). Errors: 400 invalid request, 401 wrong key, 502 provider error with its
message, and 502/504 from the proxy when n8n itself is down (`--ping` says so).

**It is the owner's production n8n** (the AI Founders pipelines run there): one hung execution stops all of
them (INC-203). The workflow saves successful executions too (`saveDataSuccessExecution: all`, read
2026-10-09; the earlier note "none" was wrong), so every image's base64 lands in the instance's SQLite
store until pruning. The AI Founders house skill `n8n-webhook-key-gate` (ai-founders-bot repo) forbids
image bytes through webhooks for exactly that reason: pass URLs. Any change to this workflow is
validated, applied by the owner's word, followed at once by `--ping`, and every paid test after it runs
alone with a short `--timeout`.
