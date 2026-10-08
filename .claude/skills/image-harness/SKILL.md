---
name: image-harness
description: CLAUDE ONLY - GPT, Codex, Astra and Gemini agents must NOT use this skill; they generate images natively and this harness is paid per image. Generate or edit images (texture sources, tiles, decals, icons art, portraits, references) from Claude Code through the owner's n8n workflow "Claude Image Harness (Webhook)" - OpenAI gpt-image by default (what GPT uses natively), Gemini image models for edits with reference images. Use when Claude needs an image made: "generate a texture", "make an image", "create a tile source", "edit this image", "image prompt".
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
| `--model` | openai `gpt-image-1`; gemini `gemini-3.1-flash-image-preview` (`gemini-2.5-flash-image` fallback) |
| openai | `--size 1024x1024` / `1536x1024` / `1024x1536`, `--quality low\|medium\|high\|auto` (medium), `--background transparent\|opaque\|auto`, `--n 1..4`, `--format png\|jpeg\|webp` |
| gemini | `--aspect 1:1` (e.g. 16:9), `--image-size 1K\|2K\|4K`, `--ref img.png` (repeatable: edit/reference images), one image per call |

Output: `DIR/NAME_1.png ...` plus `DIR/NAME.json` (prompt, provider, model, settings, usage,
revised prompt, time) - the provenance record texture work requires. It prints paths only;
never read image data into the conversation except to look at a result.

## Budget rules

- Start with `--quality low` (openai) or `1K` (gemini) to check composition; spend `high` or
  `2K/4K` only on the chosen prompt. One test image per idea, not batches.
- `--out` must be outside the repository (the client refuses otherwise; AGENTS.md rule 8).
  Texture sources go to the model's OneDrive checkpoint, trials to the session scratchpad.
- For textures follow `blender-architecture-texturing/references/sources-seamless.md`:
  orthographic, neutral light, no baked shadows or lettering, physical scale in the prompt,
  tile check after. A generated RGB image is never a normal map; relief comes from geometry bakes.

## Workflow (owner's n8n, "Claude Image Harness (Webhook)")

Webhook `POST` -> `x-api-key` check (the Character Generator harness pattern) -> normalise
request -> route openai / gemini -> provider HTTP call (provider keys stay in n8n credentials,
never in this repo) -> images as base64 JSON.
Synchronous: the response carries the images (tested 2026-09-28: openai low 1024 and gemini 1K
with a reference image). Successful executions are not stored (`saveDataSuccessExecution: none`),
so images do not accumulate on the server; errors are stored for debugging. Errors: 400 invalid
request, 401 wrong key, 502 provider error with its message.
