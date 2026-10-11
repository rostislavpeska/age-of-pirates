# Route: Blendify generate_3d -> n8n -> fal TRELLIS-2

Facts as read on 2026-10-11 from the owner's Blendify MCP code and one execution of each mode. Hosts, paths, ids and
keys are deliberately absent: the MCP server reads its webhook base and key from its own environment (or its ignored
`.env`), and nothing in this library may name them.

## Tools

| Tool | Does | Paid |
| --- | --- | --- |
| `generate_3d(prompt="", image_model="", image="")` | Starts a job (text mode needs `prompt`; with `image`, `prompt` is an optional label), returns `job_id`, `status_url`, `response_url` at once | yes: one TRELLIS job; text mode also one image generation |
| `wait_for_3d_job(status_url, response_url, timeout_seconds=300, poll_interval=6)` | Polls until `{"status": "completed", "glb_url": ...}`, `failed` or `timeout` | no |
| `import_canonical_model(source, target_size=1, pivot="center", collection_name="")` | Imports into the LIVE Blender scene: joins to one mesh, applies transforms, scales the largest side to `target_size`, sets the origin, places it at the world origin | no, but it is screen control and loses the metric size |

The server name in the client configuration varies (the tools appear under the Blendify server's name). The image
parameter exists only in the image-mode code; a server started before that update shows `prompt` and `image_model`
only (seen in this session's schema on 2026-10-11): ask the owner to restart it.

## Request body (what the tool posts)

| Mode | Body | Server side |
| --- | --- | --- |
| text | `{"prompt": str, "image_model": str}` | the workflow "3D Model Generator" wraps the prompt ("Product shot of {OBJ}. One single object only, centered and fully in frame, isolated on a flat monochromatic light-grey background, soft even studio lighting, no shadows, no floor or ground plane, no other objects or props, no text." - read from the Blendify repository's workflow export; the live node was not read), generates the image with OpenRouter (empty `image_model` = google/gemini-2.5-flash-image) and sends it to fal TRELLIS-2; the image is not kept or returned |
| image | `{"prompt": str, "image_url": str}` | branch "Has Input Image?" -> "Use Input Image" -> fal TRELLIS-2; no prompt composition, no image generation; `prompt` is only a label |

`image` accepted by the tool:

- a local `.png`, `.jpg`/`.jpeg` or `.webp`, at most 8 MiB, content-checked (a renamed file is refused), sent inline
  as a `data:` URI (the n8n webhook payload cap is 16 MiB; 8 MiB of image is about 10.7 MiB of base64);
- an `http(s)` URL that fal can fetch without authentication;
- a `data:image/png|jpeg|webp;base64,...` URI.

Best input: one whole object, centred, plain light background, no other objects, nothing cropped.

## Failure modes

| Symptom | Cause | Action |
| --- | --- | --- |
| The model ignores the image and looks like the label | workflow without the image branch: the image is dropped and the label runs as a **paid text job** | stop; the owner updates the workflow; check the next execution runs "Use Input Image" and not the prompt and image nodes |
| `generate_3d` has no `image` parameter | MCP server started before the image-mode code | owner restarts the server; never put the path into `prompt` |
| `wait_for_3d_job` returns `timeout` or the client times out | long job | poll again with the same handles (free); E1 completed on the second poll |
| `error`: base not set | the MCP server's environment lacks its webhook configuration | owner fixes the server environment; never paste values into the session |
| 502/504 | n8n or fal down | report; do not retry in a loop (each successful retry pays) |

The n8n instance is the owner's production server (other pipelines run there). One job at a time, short timeouts,
and any workflow change is the owner's decision.

## Download and import

1. Download `glb_url` right away into a work folder outside every repository (it is a provider media URL; how long it
   stays valid is unverified). Record bytes and sha256.
2. Inspect in background Blender with the bundled tools (`scripts/preview_glb.py`, `scripts/mesh_stats.py`,
   `scripts/render_ortho.py`): the GLB stays untouched and its metric proportions are measurable.
3. Bring it into a working `.blend` with a background script (`bpy.ops.import_scene.gltf`), parented to an empty for
   the uniform landmark scale ([fitting](fitting.md)). `import_canonical_model` only when the owner wants it in his
   live scene, announced first, and knowing it normalises the size.

## Provenance

One JSON per experiment next to its outputs (outside the repo), for example `PROVENANCE_<experiment>.json`:

| Field | Content |
| --- | --- |
| `experiment`, `date`, `paid_cap`, `paid_calls`, `paid_calls_detail` | what was tried, the agreed cap and the count, with which call paid for what (a text job = TRELLIS + one image) |
| per call: `id`, `paid`, `time`, `tool`, `route` | e.g. `generate_3d (image mode)` or `image-harness generate.py (gemini edit)` |
| `prompt` or `label`, `image_model`, `settings` | the exact text sent; the image-harness record carries its own settings and usage |
| `input_images` | path and sha256 of every input |
| `job_id`, `status` | the provider job handle (not secret, but never a webhook host, path or workflow id) |
| `output`, `output_sha256`, `output_bytes` | the downloaded GLB or image |
| `measured` | the numbers that settle the question, with the measurement file |
| `journal` | the journal record id |

The image harness writes its own JSON per call and appends to its device ledger; reference those, do not copy them.
