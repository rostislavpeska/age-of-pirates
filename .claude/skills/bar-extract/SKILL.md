---
name: bar-extract
description: Extract and search original Age of Empires III DE game files from the .bar archives in the Steam install, decompiling XMB to readable XML. Use whenever you need a vanilla/original/stock game file - protoy.xml, techtreey.xml, civs.xml, soundsets, *_snds.xml, *.tactics, *.material, *.lgt, art xml, textures, models - or need to find which archive a file lives in, compare a mod override against the current vanilla version, or refresh snapshots after a game patch or new DLC. Triggers on "extract from bar", "original game file", "vanilla version of", "what does the stock file look like", "unpack the game files", "decompile XMB".
---

# Extracting original game files from .bar archives

The game ships its content in 42 `.bar` archives (~122,000 files, ~49 GB) under the
Steam install. `scripts/bartool.py` reads them directly — standard library only,
no Resource Manager, no GUI.

```bash
python .claude/skills/bar-extract/scripts/bartool.py <command> [pattern...]
```

Run it from the repo root. The Steam path is auto-detected; override with
`--game "<path>\AoE3DE\Game"` or the `AOE3DE_GAME` environment variable.

## Commands

| Command | Purpose |
|---|---|
| `bars` | List the archives and their file counts |
| `list [pattern...]` | Find files across all archives (`-l` for size/codec/archive) |
| `cat <pattern>` | Print one file to stdout |
| `extract [pattern...]` | Write matching files to a directory (`-o`, default `bar_export`) |
| `verify [pattern...]` | Decode matches and report failures — use after a game patch |

## Patterns

Matched case-insensitively against the full path (`Data/tactics/dock.tactics.XMB`).

- **No wildcard → substring.** `soundsetsde`, `data/tactics/`, `protoy`
- **With `*` `?` `[` → glob.** `data/tactics/*.tactics`, `sound/soundsets*.xml`
- **No pattern → everything** (don't do this with `extract` unless you mean 49 GB)

Multiple patterns are OR'd and de-duplicated.

## The one trap: almost everything is XMB

Most logical XML is physically stored as compiled binary **XMB**, and the archive
name usually keeps the *logical* extension with `.XMB` appended:

```
Data/tactics/dock.tactics.XMB      Sound/soundsetsde.xml.XMB
Art/.../castle.xml.XMB             Art/.../port_age4.material.XMB
```

Two consequences:

1. **`extract` and `cat` decompile XMB to indented XML by default** and drop the
   redundant `.XMB` suffix. Output is 2-space-indented **CRLF**, matching
   Resource Manager and this repo, so it diffs cleanly against
   `scripts/source/*.xml` instead of showing every line as changed. Use
   `--eol lf` to override, or `--raw` to get the untouched binary.
2. **Globs match with an implicit trailing `.xmb`.** `*.tactics` finds
   `dock.tactics.XMB`, so write the extension you expect, not the stored one.

`.gr2`, `.ddt`, `.png`, `.wav` and other binaries always come out untouched.

## Examples

```bash
T=.claude/skills/bar-extract/scripts/bartool.py

# Where does a file live, and how big is it?
python $T list -l soundsetsde

# Read a vanilla file without writing anything
python $T cat data/tactics/dock.tactics | head -40

# Refresh the reference snapshots in scripts/source/ after a patch,
# then read the git diff to see exactly what the patch changed
python $T extract protoy.xml techtreey.xml civs.xml -o scripts/source --flat
git diff --stat scripts/source

# Pull every vanilla file the mod overrides in one area
python $T extract "sound/*_snds.xml" "sound/soundsets*.xml" -o /tmp/vanilla-sound

# Check what a patch changed under you (0 failures expected)
python $T verify "*.xmb"
```

Use `-n/--dry-run` on `extract` to see what would be written first. `--flat`
drops the directory structure.

## Comparing a mod override against vanilla

Extract the vanilla counterpart, then diff. The mod ships plain XML while vanilla
ships XMB, so decompiling (the default) is what makes the diff possible at all:

```bash
python $T extract "sound/soundsetsde.xml" -o /tmp/v
diff <(python -c "import re,sys;print(re.sub(r'\s+',' ',open(sys.argv[1]).read()))" /tmp/v/Sound/soundsetsde.xml) \
     <(python -c "import re,sys;print(re.sub(r'\s+',' ',open(sys.argv[1]).read()))" sound/soundsetsde.xml)
```

For override files, a plain line diff is usually too noisy to act on — these are
flat record lists (`<soundset name=>`, `<action><name>`, `<unit name=>`,
`<submaterial name=>`). Compare **by record key** instead, and report three
buckets: records only in vanilla (the mod is dropping new content), records only
in the mod (its additions), and records in both that differ (needs review).

A mod file is an **override** if and only if its path exists in the archive index
(matching `.xml` ⇄ `.xml.xmb`); otherwise it is new content the mod introduced.
That check is exact — prefer it over filename conventions like a `zp` prefix,
which is a reliable *sufficient* signal but covers only a fraction of new files.

## Performance and notes

- Indexing all 42 archives takes ~0.3 s (tail reads only); it happens per run, no cache.
- Decoding runs at ~20 MB/s pure Python — Data.bar in ~17 s, all 16,800 XMB files
  in ~16 s. `pip install lz4` swaps in the C codec for roughly 10×; entirely optional.
- The tool is **read-only**. It never touches the game install and only writes
  under the `-o` directory you name.
- There is no XMB *writer* here. To regenerate a paired `data/**.xml.xmb` after
  editing the `.xml`, use Resource Manager.

## Verified against the current install

Build `24241387` (`open_beta` / Baltic Powers), 42 archives, 122,333 files:
all archives parse with zero leftover bytes and fully contiguous data regions;
16,800/16,800 XMB files decompile with byte-exact stream consumption;
output cross-checked against an independently written reference parser (125/125
identical) and against the mod's own `.xml`/`.xml.xmb` pairs.
