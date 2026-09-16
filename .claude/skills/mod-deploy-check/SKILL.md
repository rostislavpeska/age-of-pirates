---
name: mod-deploy-check
description: Pre-zip audit and deployment protocol for publishing the Age of Pirates mod to the ageofempires.com mod portal. Use before every zip/upload, when asked "is the mod folder clean", "check before I zip", "anything weird in the mod files", "deployment protocol", "how do I publish/update the mod", or after a session that touched data/*.xml (stale XMB twins). Deployment is from LOCAL FILES, never from git.
---

# Deploying Age of Pirates - protocol and pre-zip check

**Deployment is from the local mod folder, not from git.** What sits on disk in
the five game folders is what gets zipped and what players download. Git is the
history and the backup; it is not the source of the upload. Consequences:

- `git status` cannot find strays: `.gitignore` hides `*.tga`, `*.zip`, `*.psd`,
  `*.fbx`, `__pycache__`, `*.stackdump`. Only a disk walk sees them.
- A file can be committed and still be wrong for the portal (`*.prev` twins were).
- An `.xml` edited after its `.xml.xmb` was built is INERT in game - the engine
  reads the XMB. Every data edit ends with a twin rebuild in Resource Manager.

## The check

```bash
# from the mod root (the folder that holds art/ data/ game/ sound/ randmaps/)
python .claude/skills/mod-deploy-check/scripts/prezip_check.py            # audit the folders
python .claude/skills/mod-deploy-check/scripts/prezip_check.py --zip age-of-pirates.zip
```

Read-only, standard library. Exit 0 = clean, 1 = blocking findings, 2 = warnings
only. It walks only `art data game sound randmaps` and reports:

| blocking | why |
|---|---|
| anything outside the five game folders | must not be in the zip |
| `*.prev *.bak *.orig *.tmp`, `_backups/`, `__pycache__/`, `.claude/`, `sandbox/`, `scripts/`, `docs/`, `Thumbs.db`, `.DS_Store` | backups, tooling, repo leftovers |
| `.md .py .ps1 .zip .psd .fbx .blend .log .csv .stackdump .mp4 ...` | documentation, code, sources, archives |
| any extension the game does not ship | the whitelist is what the vanilla `.bar` archives contain (`.xml .xmb .xs .png .ddt .gr2 .material .wav .tactics .hkt .precomp .dmg .lgt .pkfx .particle .xaml .tga .set ...`) |
| `( ) [ ] { } , ; ' " ! @ # $ % ^ & = +` or non-ASCII in a name | e.g. `texture.(0,0,4,9).tga` - exports, and what validators choke on |
| zero-byte files, hidden files, case-insensitive duplicate paths | unfinished or platform traps |
| **`.xml.xmb` whose CONTENT differs from its `.xml`** | STALE TWIN - the game will load the old data. Decoded with bar-extract's `bartool.py` and compared as element trees (whitespace collapsed, so a CRLF stored as LF is not a difference). mtimes are NOT used - a git checkout rewrites them. Without bartool the check degrades to an mtime warning. |

| warning | why |
|---|---|
| on disk but not tracked in git | a new file or a gitignored stray - decide which |
| tracked in git but missing on disk | the zip will lack it |
| double extension, paths > 200 chars, paths with spaces | counted; usually fine |

The portal limit is **2 GB compressed** (user, 2026-09-02). The 2026-09-02 build
was 6,295 files, 2.78 GB on disk, 1.89 GB zipped (ratio 0.68); the check prints
an estimate from that ratio.

## Deployment protocol

1. **Root twins -> repo folder.** Istanbul is edited in the Game root
   (`AoE3DE\Game\RandMaps\000_istanbul.xs`, `.mods.xml`); the mod ships
   `randmaps\zpistanbulb.xs` / `.mods.xml`. Copy root over repo and `cmp` them
   (identity `.xml` files stay different on purpose - two lobby names). Any other
   map with a root working copy: same rule.
2. **Rebuild every edited XMB twin** in Resource Manager (protomods, techtreemods,
   nuggetmods, stringmods, protounitcommandmods ...). The check flags stale ones.
2b. **Build the string twins for all fifteen languages:**
   `python scripts/tools/stringsync.py --build` (no flag = dry audit, `--vanilla` = also
   verify the split). Only `english/stringmods.xml` is edited; the other fourteen folders
   ship the `.xmb` alone, which the twin check cannot see, so the check runs the tool.
   The English file has two marked sections and the tool builds each language as:
   - `<!-- ===== REWRITES` block: overrides of VANILLA ids (today: 64988, the consulate
     headline "Choose an Ally"). Every other language keeps its own translation of exactly
     these ids in `data/strings/_rewrites/<language>.xml`, static, in that language; the
     tool swaps the English block for that file. A language whose fragment is missing or
     lacks an id is INCOMPLETE and is NOT written - add the translation, never English.
   - `<!-- ===== NEW STRINGS` block: mod-own ids (400001-400290, 500001+; vanilla tops out
     at 300366). Copied 1:1 into every language. New strings go here.
   So a release replaces only the NEW STRINGS part of each language; its rewrites survive.
   Adding a rewrite = one line in English + fourteen fragment lines, once, then never again.
3. **Run the check.** Fix blocking items in the FOLDERS (delete strays, move
   backups out of the game dirs), never by editing the zip. Re-run until clean.
4. **Zip the five folders at the archive root** - `art data game sound randmaps`
   directly inside the zip, no wrapper folder, nothing else. Write the zip
   OUTSIDE the game folders (the mod root is fine; `*.zip` is gitignored).
   `info.json` is optional in a zipped submission.
   **The zip is made by the user, by hand, as the final deployment step.** Scripted zip
   export has proven less reliable than the manual one (2026-09-17). Never create a zip
   unprompted or as a side effect of the check; do it only when the user explicitly asks
   for the export, and then audit the result with `--zip` before they upload it.
5. **Size**: compressed zip <= 2 GB.
6. **Upload** at https://www.ageofempires.com/mods/create/ (new) or the mod's own
   page (update). The portal refuses a mod without **tags**; set thumbnail and
   description; note the version in the changelog.
7. **Verify** on a clean profile or the second device: subscribe in the in-game
   Mod Manager, load a map that depends on the newest data (strings, protos), and
   compare the game process start time against the XMB mtimes before judging
   anything (the engine loads XMBs at process start).
8. **Then** commit and push - git records what was shipped; it does not ship it.

## Known history

- 2026-09-02 audit of `age-of-pirates.zip`: 6,298 files; only three non-game
  entries - `game/randmaps/README.md`, two `IS_Shore_Pirates_0x.xml.prev` twins,
  and a stray `full_wall3_mata_basecolor.(0,0,4,9).tga` next to its real `.ddt`.
  The `.prev` twins and the `.tga` were removed from the folders; the README stays
  (harmless, the user keeps it).
- Official sources reachable in 2026-09: no page lists allowed file types; the
  only "Publishing" support article is AoE IV only. The whitelist above is
  derived from the vanilla archives, not from a portal rule.
