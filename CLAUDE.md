# age-of-pirates - rules every agent follows

This folder IS the live mod: the game loads it directly. Every byte here ships in the portal zip.

## Hard rules

1. **Runtime XML is CRLF.** Any XML the engine parses from this folder at run time - animfiles (`art/**/*.xml`),
   `*.material`, `sound/**/*_snds.xml`, `*.lgt`, `*.tactics` - must have CRLF line endings. An LF-only file is
   **silently ignored**: the unit places, the decal draws, the model never renders, no error anywhere
   (2026-09-17, ten game restarts lost). The Write tool writes LF. After writing any such file run
   `python scripts/tools/check_art_eol.py` (`--fix` converts); the PostToolUse hook in `.claude/settings.json`
   converts automatically, `.gitattributes` keeps checkouts CRLF. When a model "does not appear" in game,
   check line endings **first**.
2. **Never duplicate game assets.** Textures, models, decals, particles, sounds the game already ships are
   referenced by their archive path (`homecity\british\british_tol\textures\british_tol_matA_BaseColor` in a
   `.material`, `buildings\fort\west_fort_decal` in an animfile) - never copied under `art/` or `sound/`, not
   even renamed. Only content the mod itself made is a file here.
3. **Vanilla extractions never enter the repo.** `bartool extract` only into the session scratchpad
   (skill `bar-extract`); the tool refuses in-repo targets.
4. **`data/*.xml` edits are inert until the `.xml.xmb` twin is rebuilt**
   (`python .claude/skills/bar-extract/scripts/xmbc.py check|build data/<file>.xml`); commit both.
   Art and sound XML stay plain - no twins there.
5. **New records go at the end of real content**, directly above the file's first long TEST/commented
   section, ids continuing the real sequence (protomods 21160+).
6. **Backslashes in the Bash tool collapse** (`\\` loses a level even in quoted heredocs). Write scripts that
   contain Windows paths with the Write tool and build the character from `chr(92)`.

## Where things are

- Skills: `.claude/skills/` - `bar-extract` (vanilla files, XML<->XMB), `aoe-building-pipeline` (buildings,
  materials, textures), `gr2-granny-edit` (byte-level .gr2 edits: `scripts/havok/gr2_*.py`), `mod-deploy-check`
  (pre-zip audit), `game-startup` (never kill the game; launch only on instruction).
- Tools: `scripts/tools/check_art_eol.py`, `scripts/havok/ddt_dxt1.py` (DXT1 .ddt with mips),
  `scripts/havok/gr2_editmesh.py` (in-place vanilla model edits - the converter route loses large faces in game).
