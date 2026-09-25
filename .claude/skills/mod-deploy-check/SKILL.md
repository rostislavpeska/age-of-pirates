---
name: mod-deploy-check
description: Pre-zip audit, deployment protocol and the zip builder for the Age of Pirates mod portal. Use before every zip/upload, when asked to "compile/export prod", "production zip", "beta zip", "strip <map> from the release", "is the mod folder clean", "check before I zip", "deployment protocol", "how do I publish/update the mod", or after a session that touched data/*.xml (stale XMB twins). Deployment is from LOCAL FILES, never from git.
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
   (`AoE3DE\Game\RandMaps\000_istanbul.xs`); the mod ships
   `randmaps\zpistanbulb.xs` + `randmaps\zpistanbulb.mods.xml`. Copy the root `.xs`
   over the repo `.xs` and `cmp` them (identity `.xml` files stay different on
   purpose - two lobby names). Any other map with a root working copy: same rule.
   **A `.mods.xml` exists in the repo ONLY - never in the Game root; a root copy
   crashes the game (2026-09-19, four stripped, 10 USD).** The audit fails on any
   `Game\RandMaps\*.mods.xml`.
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
   The owner usually zips by hand. Build one only when the owner asks for the export
   ("compile prod", "export the zip"), never unprompted or as a side effect of the check,
   and always with `make_zip.py` (next section), then audit the result with `--zip`.
5. **Size**: compressed zip <= 2 GB.
6. **Upload** at https://www.ageofempires.com/mods/create/ (new) or the mod's own
   page (update). The portal refuses a mod without **tags**; set thumbnail and
   description; note the version in the changelog.
7. **Verify** on a clean profile or the second device: subscribe in the in-game
   Mod Manager, load a map that depends on the newest data (strings, protos), and
   compare the game process start time against the XMB mtimes before judging
   anything (the engine loads XMBs at process start).
8. **Then** commit and push - git records what was shipped; it does not ship it.

## Building the zip: beta or production

```bash
Z=.claude/skills/mod-deploy-check/scripts/make_zip.py
python $Z age-of-pirates-beta-<date>.zip                                           # beta, nothing stripped
python $Z age-of-pirates-prod-<date>.zip --strip-map istanbul --strip-map london   # prod without two maps
python .claude/skills/mod-deploy-check/scripts/prezip_check.py --zip <that zip>    # then the audit
```

Both kinds use the same script, and both can strip maps. What differs is who decides (owner 2026-09-25):

| build | strip |
|---|---|
| **beta** | full content by default; strip only the maps the owner names in the request |
| **prod** | **ask first, every time:** "Which maps should I strip from prod?" Often the answer is none. Build only after the answer; never reuse an earlier strip list, never assume one |

**Stripping means maps, nothing else.** `--strip-map NAME` leaves out every file whose name
contains NAME directly in `randmaps/` or `game/randmaps/`: the `.xs`, the `.xml` (lobby descriptor) and the
`.mods.xml`. Groupings, protos, art, sounds and icons stay (owner 2026-09-25: no special stripping of units or art).
Read the printed `STRIP` lines: they must name exactly the maps the owner asked for (a short NAME can match more).
A NAME matching no `.xs` stops the build.

- **Never strip by changing the repo** (no move, delete or `git mv` of map files). The script leaves them out of
  the zip only; the folders and git stay as they are.
- **Why:** on 2026-09-11 a production build moved only `zpistanbulb.xml` out of the folder (a `git mv` to
  `playground/release-hold`); `zpistanbulb.xs` and `zpistanbulb.mods.xml` shipped, and Istanbul still appeared in
  the lobby. All files of the map go, and the script checks the finished zip for leftovers.
- **Always left out:** files in a `backup` folder and gitignored files (the untracked `.tga` exports).
- **Temp name:** the zip is written as `<name>.part.zip`, which the `*.zip` gitignore rule covers, so a commit in
  the meantime cannot pick it up. It is renamed only after the check passes (CRC of every entry, the five folders
  only, no stripped map left). A failed check keeps the `.part.zip` name.
- **Speed:** deflate level 6, `.png` stored. 2026-09-25 prod: 6,563 files, 2.82 GB -> 1.929 GB in 80 s (the level-9
  beta took 181 s for 1.896 GB). Headroom to the 2 GB limit is ~70 MB: if a build prints OVER THE LIMIT, the fix is
  content, not a compression flag.
- **Checking in game:** the owner's own machine also lists the Steam-root test copies (`000_istanbul`,
  `00000_zplondon` ...), which never ship. Check a stripped zip's lobby on the test device, not by the root
  test maps.
- **Report** the zip name, the `STRIP` lines (or "nothing stripped"), files, size against 2 GB, and the `--zip`
  audit.

## Known history

- 2026-09-02 audit of `age-of-pirates.zip`: 6,298 files; only three non-game
  entries - `game/randmaps/README.md`, two `IS_Shore_Pirates_0x.xml.prev` twins,
  and a stray `full_wall3_mata_basecolor.(0,0,4,9).tga` next to its real `.ddt`.
  The `.prev` twins and the `.tga` were removed from the folders; the README stays
  (harmless, the user keeps it).
- Official sources reachable in 2026-09: no page lists allowed file types; the
  only "Publishing" support article is AoE IV only. The whitelist above is
  derived from the vanilla archives, not from a portal rule.
