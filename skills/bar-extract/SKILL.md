---
name: bar-extract
description: AoP entry point for archive lookup, extraction and XMB rebuilding. Start here in Age of Pirates; applies this mod's policies, then uses aoe3de-bar-archives for the shared tools and commands.
---

# AoP archive and XMB conventions

Read [aoe3de-bar-archives](../aoe3de-bar-archives/SKILL.md) for the reusable commands, formats and implementation. Its `scripts/bartool.py` and `scripts/xmbc.py` are the only maintained BAR/XMB helpers. Commands below run from the AoP root.

## AoP conventions

- Prefer `cat`; extract to the session scratch directory outside this repository. The only approved in-repo vanilla snapshot is `scripts/source/`, intentionally refreshed with `--in-repo` after a patch. An extraction once deposited 432 tactics files into the working tree: check changed paths before delivery.
- Refer to unchanged stock assets by archive path. Only mod-made assets belong in runtime folders. Keep extracted vanilla data and Python bytecode out of commits.
- Read [aoe-xml](../aoe-xml/SKILL.md) before editing XML. Build data XMB twins that already exist; create a new twin only deliberately or when requested. Art and sound stay plain XML. Commit rebuilt data twins with their edited sources.
- Rebuild changed data with `check` then `build`. English string changes go through `python scripts/tools/stringsync.py --build`, which handles the other languages.
- Game reload testing follows [game-startup](../game-startup/SKILL.md). Do not close the game without authorization.

```bash
python skills/aoe3de-bar-archives/scripts/bartool.py cat data/tactics/dock.tactics
python skills/aoe3de-bar-archives/scripts/bartool.py extract protoy.xml techtreey.xml civs.xml -o scripts/source --flat --in-repo
python skills/aoe3de-bar-archives/scripts/xmbc.py check data/protomods.xml
python skills/aoe3de-bar-archives/scripts/xmbc.py build data/protomods.xml
```

## Recorded verification

AoP's original helper was verified against install build 24241387 (open_beta/Baltic Powers): 42 archives, 122,333 files and 16,800 XMB files decoded; 125 samples matched an independent parser. XMB output was checked against Resource Manager on 2026-09-13. These are historical observations, not assertions about every current installation.
