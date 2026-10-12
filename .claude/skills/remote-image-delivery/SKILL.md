---
name: remote-image-delivery
description: Deliver existing screenshots, renders and preview images to a user on another device when local file links or cloud page images do not display. Upload authorized previews, verify the hosted bytes and provide direct HTTPS links with inline images.
---

# Remote image delivery

Deliver the pictures promptly. Reuse the requested existing images; do not render
again, generate replacements, build a website or create a Page just to show them.
Local filesystem links cannot serve a user on another device.

## Select and publish

1. Identify the exact pictures and their revision. State whether each is an old
   baseline, current WIP, finished result or diagnostic. Sending a baseline is
   not evidence that the requested asset edit has been completed.
2. Reuse working hosted URLs when available. Otherwise use an existing suitable
   private destination, or a public image host when the user has authorized web
   publication of these previews. Check existing authorization before asking
   again. This skill itself grants no upload permission. Do not upload unrelated
   files, source models, private screenshots or credentials.
3. For non-sensitive previews authorized for public hosting, the tested fallback
   is Catbox. It returns a direct image URL without an account or a gallery page.
   Public links can be viewed by anyone who has them; use a private destination
   when that audience is unsuitable. No paid image generation is involved.

   ```powershell
   curl.exe --fail --silent --show-error --max-time 45 -F 'reqtype=fileupload' -F 'fileToUpload=@C:/scratch/preview.png' https://catbox.moe/user/api.php
   ```

   On other systems use `curl` and the actual file path. Supply an explicit file,
   not a directory or wildcard. Keep successful URLs. An upload timeout has an
   uncertain outcome: do not repeatedly upload the same file blindly.

## Verify and show

- Fetch each returned HTTPS URL without the uploader's credentials. Confirm it
  returns image bytes, not an HTML page or sign-in screen, and compare SHA-256
  against the local original. `curl --fail --silent --show-error --max-time 30`
  worked for both upload and readback in the measured Windows case; Python
  `urllib` was disconnected by the same host. A failed client is not proof that
  the image was not uploaded. Retain the URL while checking it another way.
- Keep a small delivery receipt in scratch: image purpose/revision, URL, original
  hash, downloaded hash, verification result. Never put image bytes/base64 into
  chat tool logs. Do not put preview files in a runtime repository.
- Send BOTH an ordinary link and an inline embed for each image:

  ```markdown
  [Barracks — open full image](https://host/actual-returned-image.png)

  ![Barracks — current WIP](https://host/actual-returned-image.png)
  ```

  Use only returned, verified URLs. The link remains useful if the chat client
  cannot render the embed. Do not present a local Windows path as the fallback.
- Cloud upload success or API pixel readback does not prove the user can see an
  image. If the user reports blank images, treat delivery as failed and switch
  to direct links. Do not ask them to revisit the same blank Page repeatedly.
- Report verification and user acceptance separately. Do not claim a newer
  texture, a changed pixel, or a visible result solely because files exist.

Measured 2026-10-12: two PNG renders uploaded and downloaded through Catbox had
identical SHA-256 hashes. Native Page images had passed backend readback but were
blank for the remote operator. Host availability and retention are not guaranteed;
keep local originals and use the user's persistent asset storage for archiving.
