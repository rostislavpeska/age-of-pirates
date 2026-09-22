---
name: aoe3de-bar-archives
description: Reusable cross-mod BAR/XMB tools for Age of Empires III DE. Find, inspect and extract vanilla assets, compare archives and decompile or compile XML/XMB. Apply a consuming project's archive-policy entry skill first when one is provided.
---

# AoE3DE BAR archives and XMB

Use the included scripts instead of copying utilities from a consuming mod.

```bash
python scripts/bartool.py list -l <pattern>
python scripts/bartool.py cat <pattern>
python scripts/bartool.py extract <pattern> -o <scratch-directory>
python scripts/xmbc.py check <file.xml>
python scripts/xmbc.py build <file.xml>
```

Paths above are relative to this skill folder. Set `AOE3DE_GAME` or pass `--game` when the Steam install is not auto-detected.

Read [command and format reference](references/commands.md) for pattern matching, raw output, dependencies and XML/XMB comparison behavior.

## Local prerequisites

Follow the [local-tool readiness guidance](../skill-library-audit/references/local-tools.md).

Use an installed Python interpreter. Archive operations need a readable local game
installation; `bars` is a read-only discovery check. The Python `lz4` distribution
is required for compressed XMB output, but optional for archive reading. Inspect
the selected interpreter's dependencies before building. Missing game archives do
not prevent checking a supplied XML file.

A GUI Resource Manager is not required by these bundled helpers. If the task calls
for a specific Resource Manager, identify its product/version and format capability
before choosing a local automation or manual route. Do not install applications,
fetch game assets or change the environment as an incidental archive check.

## Engine and tool rules

- **Tool behavior:** prefer `cat` for inspection because it writes nothing.
- **Tool behavior:** extraction defaults to a temporary directory and refuses targets inside a Git working tree unless `--in-repo` is explicitly passed. Use `--in-repo` only for an intentionally maintained vanilla snapshot.
- **Engine invariant:** most logical XML, tactics, material and art XML files are stored as XMB in BAR archives. The tool decompiles them by default and removes the redundant `.xmb` suffix.
- **Engine invariant:** when a mod's data XML has an `.xml.xmb` twin, editing only the XML does not update that twin. Compile and validate the pair according to the consuming mod's loading rules.
- **Consumer convention:** whether extracted vanilla files may be committed, and where snapshots live, belongs to the consuming mod. Default to scratch storage.
- **Consumer convention:** copying stock assets into a distributable mod may increase size or violate that mod's policy. Prefer archive references when the engine and target file type support them.

Use `--dry-run` before a broad extraction. After game patches, use `verify` on the formats needed by the current task rather than decoding every archive without cause.
