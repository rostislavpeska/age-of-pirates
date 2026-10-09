# Harness workflow v2: the edit route

The n8n side of `generate.py --image/--mask`. Sanitized: no workflow id, credential id, host or webhook path (the repo
is public); the live ids come from the n8n MCP (`n8n_list_workflows`, name "Claude Image Harness (Webhook)").
Generate requests behave exactly as in v1 (generate only); v2 adds one route for OpenAI edits next to them.

```
When Called -> Check API Key -> Normalize Request -> Route --invalid------> Respond Invalid
                                 (v2 code below)        --openai-------> OpenAI Images  -> Shape Response -> Respond Result
                                                        --gemini-------> Gemini Image   -/                \-> Respond Provider Error
                                                        --openai_edit--> Build Multipart -> OpenAI Edit -/
```

## Request (client -> webhook, JSON)

| Field | generate | edit |
| --- | --- | --- |
| `operation` | `generate` (default) | `edit` |
| `provider` | `openai` / `gemini` (default gemini when `references` are given) | `openai` (default with a mask) / `gemini` |
| `prompt` | the image description | the edit instruction |
| `references` | Gemini style references `[{b64, mime}]` | input images, max 16 for OpenAI; the first gets the mask |
| `mask` | refused | `{b64}` PNG, same size as the first image, alpha 0 = editable (OpenAI only) |
| `input_fidelity` | - | `high` / `low` (gpt-image-1, -1.5; `low` only on mini; omit on gpt-image-2) |
| openai params | `model n size quality background output_format` | same; `size` defaults to `auto` |
| gemini params | `model aspect_ratio image_size` | same |

Response: `{provider, operation, model, images: [{b64, mime, revised_prompt}], usage}`; 400 `{error}` for an invalid
request (nothing billed), 401 wrong key, 502 provider error with its message.

## Why a Code node builds the multipart body

`/v1/images/edits` accepts only `multipart/form-data`, with one `image[]` part per input image. The HTTP Request node's
form-data mode cannot repeat one binary field name, so "Build Multipart" assembles the body (boundary, text fields,
`image`/`image[]` parts, optional `mask`) and "OpenAI Edit" posts it as one raw binary with the matching
`Content-Type` header. The provider key stays in the n8n credential; nothing secret is in the code.

## Changes (apply with `n8n_update_partial_workflow`, `validateOnly: true` first)

1. **Normalize Request** - replace `parameters.jsCode` with the v2 code below (v1 refused every OpenAI request with
   references; v2 checks `operation`, inputs, mask and input_fidelity and returns actionable errors).
2. **Route** (Switch) - rule `openai` gets a second condition `{{ $json.operation }} != edit`; a 4th rule
   `openai_edit` = provider `openai` AND operation `edit` (output index 3).
3. **Build Multipart** (Code, new) - code below.
4. **OpenAI Edit** (HTTP Request 4.2, new) - settings below; `onError: continueErrorOutput`.
5. Connections: Route[3] -> Build Multipart -> OpenAI Edit; OpenAI Edit[0] -> Shape Response; OpenAI Edit[1] ->
   Respond Provider Error.
6. **Shape Response** - add `operation` to the result: `return [{ json: { provider: req.provider, model: req.model, images, usage: j.usage || j.usageMetadata || null } }];` becomes `return [{ json: { provider: req.provider, operation: req.operation || 'generate', model: req.model, images, usage: j.usage || j.usageMetadata || null } }];`.
7. Publish (`activateWorkflow`). Rollback: `n8n_workflow_versions` keeps the previous version.

After publishing: `generate.py --ping` (free), one `--quality low` generate (regression, ~$0.011), one masked OpenAI
edit and one Gemini edit at the lowest settings. Count every call (`--ledger`).

## Normalize Request (v2)

```js
// Universal image request -> provider call. Harness v2 (2026-10-09): operation 'generate' (default, unchanged) | 'edit'.
// generate: OpenAI /images/generations or Gemini (references = style/edit inputs, no mask).
// edit:     OpenAI /images/edits (references = input images, optional PNG mask whose fully transparent pixels are the
//           editable area, applied to the first image) or Gemini (references + instruction, no mask).
const b = $json.body || {};
const fail = (m) => [{ json: { error: m } }];
const prompt = String(b.prompt || '').trim();
if (!prompt) return fail('prompt is required: the full instruction text');
const op = String(b.operation || 'generate').toLowerCase();
if (!['generate', 'edit'].includes(op)) return fail("operation must be 'generate' or 'edit'");
const refs = Array.isArray(b.references) ? b.references : [];
for (let i = 0; i < refs.length; i++) {
  if (!refs[i] || typeof refs[i].b64 !== 'string' || !refs[i].b64) return fail('references[' + i + '].b64 must be a base64 image (png, jpeg or webp)');
}
const mask = (b.mask && typeof b.mask.b64 === 'string' && b.mask.b64) ? { b64: b.mask.b64, mime: 'image/png' } : null;
const provider = String(b.provider || ((op === 'edit' && mask) ? 'openai' : (refs.length ? 'gemini' : 'openai'))).toLowerCase();
if (!['openai', 'gemini'].includes(provider)) return fail('provider must be openai or gemini');
if (op === 'generate' && provider === 'openai' && refs.length) return fail("input images with provider openai need operation 'edit' (OpenAI /images/edits), or use provider gemini");
if (op === 'edit' && !refs.length) return fail("operation 'edit' needs at least one input image in references");
if (mask && !(provider === 'openai' && op === 'edit')) return fail('mask needs provider openai and operation edit (Gemini edits by instruction only, no mask)');
if (provider === 'openai' && refs.length > 16) return fail('OpenAI edits accept at most 16 input images');
const out = { provider, operation: op, prompt, references: refs, mask };
if (provider === 'openai') {
  const model = b.model || 'gpt-image-1';
  Object.assign(out, {
    model,
    n: Math.min(Math.max(parseInt(b.n || 1, 10) || 1, 1), 4),
    size: b.size || (op === 'edit' ? 'auto' : '1024x1024'),
    quality: b.quality || 'medium',
    background: b.background || 'auto',
    output_format: b.output_format || 'png'
  });
  if (op === 'edit' && b.input_fidelity) {
    const fid = String(b.input_fidelity).toLowerCase();
    if (!['high', 'low'].includes(fid)) return fail("input_fidelity must be 'high' or 'low'");
    if (fid === 'high' && /mini/.test(model)) return fail('input_fidelity high is not available on gpt-image-1-mini');
    if (/^gpt-image-2/.test(model)) return fail('omit input_fidelity for gpt-image-2 models');
    out.input_fidelity = fid;
  }
} else {
  Object.assign(out, {
    model: b.model || 'gemini-3.1-flash-image-preview',
    aspect_ratio: b.aspect_ratio || '1:1',
    image_size: b.image_size || '1K'
  });
}
return [{ json: out }];
```

## Build Multipart

```js
// OpenAI /images/edits accepts only multipart/form-data with several image[] parts: the HTTP node cannot repeat one
// binary field name, so the body is assembled here and sent as one raw binary.
const j = $json;
const boundary = '----aop-image-harness-' + Date.now().toString(16) + Math.random().toString(16).slice(2);
const CRLF = '\r\n';
const parts = [];
const field = (name, value) => parts.push(Buffer.from('--' + boundary + CRLF + 'Content-Disposition: form-data; name="' + name + '"' + CRLF + CRLF + value + CRLF, 'utf8'));
const file = (name, filename, mime, b64) => {
  parts.push(Buffer.from('--' + boundary + CRLF + 'Content-Disposition: form-data; name="' + name + '"; filename="' + filename + '"' + CRLF + 'Content-Type: ' + mime + CRLF + CRLF, 'utf8'));
  parts.push(Buffer.from(b64, 'base64'));
  parts.push(Buffer.from(CRLF, 'utf8'));
};
for (const k of ['model', 'prompt', 'n', 'size', 'quality', 'background', 'output_format', 'input_fidelity']) {
  if (j[k] !== undefined && j[k] !== null && j[k] !== '') field(k, String(j[k]));
}
const ext = (m) => String(m || 'image/png').split('/')[1].replace('jpeg', 'jpg');
const imgName = j.references.length > 1 ? 'image[]' : 'image';
j.references.forEach((r, i) => file(imgName, 'image' + i + '.' + ext(r.mime), r.mime || 'image/png', r.b64));
if (j.mask) file('mask', 'mask.png', 'image/png', j.mask.b64);
parts.push(Buffer.from('--' + boundary + '--' + CRLF, 'utf8'));
const body = Buffer.concat(parts);
const ct = 'multipart/form-data; boundary=' + boundary;
return [{ json: { content_type: ct, bytes: body.length, images: j.references.length, mask: !!j.mask }, binary: { body: { data: body.toString('base64'), mimeType: ct, fileName: 'edit.multipart' } } }];
```

## OpenAI Edit (HTTP Request)

```json
{
 "type": "n8n-nodes-base.httpRequest",
 "typeVersion": 4.2,
 "parameters": {
  "method": "POST",
  "url": "https://api.openai.com/v1/images/edits",
  "authentication": "predefinedCredentialType",
  "nodeCredentialType": "openAiApi",
  "sendHeaders": true,
  "headerParameters": {
   "parameters": [
    {
     "name": "Content-Type",
     "value": "={{ $json.content_type }}"
    }
   ]
  },
  "sendBody": true,
  "contentType": "binaryData",
  "inputDataFieldName": "body",
  "options": {
   "timeout": 290000,
   "response": {
    "response": {
     "responseFormat": "json"
    }
   }
  }
 },
 "credentials": {
  "openAiApi": "<the existing OpenAI credential of the \"OpenAI Images\" node>"
 },
 "onError": "continueErrorOutput"
}
```
