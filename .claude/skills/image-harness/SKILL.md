---
name: image-harness
description: CLAUDE ONLY - GPT, Codex, Astra and Gemini agents must NOT use this skill; they generate images natively and this harness is paid per image. Generate or edit images (texture sources, tiles, decals, icons art, portraits, references) from Claude Code through the owner's n8n workflow "Claude Image Harness (Webhook)" - OpenAI gpt-image by default (what GPT uses natively), OpenAI masked edits (fill or repaint only the transparent area of a mask) and Gemini instruction/reference edits. Use when Claude needs an image made: "generate a texture", "make an image", "create a tile source", "edit this image", "image prompt".
---

# Image harness (Claude only)

**Gate.** Only Claude Code uses this. GPT/Codex/Astra/Gemini agents make images natively
and must never call it: every call is billed to the owner's API accounts (AGENTS.md rule 10).
The client enforces it technically as well: it refuses unless `CLAUDECODE=1` (set only in
Claude Code shells).

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
  result is bad or the icon is complex (a scene, several figures); **unit portraits** (the 512 portrait,
  `iconforge --kind portrait`) use `gpt-image-1` from the start (owner, same day). Everything else keeps
  the default `gpt-image-1`.
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
