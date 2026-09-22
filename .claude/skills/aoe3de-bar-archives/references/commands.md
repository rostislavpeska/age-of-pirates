# BAR and XMB command reference

Commands here run from this skill's directory. `bartool.py` needs only Python's standard library; optional `lz4` speeds reading, and `xmbc.py` requires `lz4` for compressed output. Supply the install through `AOE3DE_GAME` or `bartool.py --game <Game-directory>`.

| Command | Behavior |
|---|---|
| `bars` | Lists discovered archives and entry counts |
| `list -l <pattern>` | Reports matching archive paths, stored formats, sizes and archive names |
| `cat <pattern>` | Prints a single decoded file without extraction; refuses ambiguity unless `--all` is given |
| `extract <pattern> -o <scratch>` | Writes matched files; `-n` previews, `--flat` drops directory structure |
| `verify <pattern>` | Decodes matches and reports failures |

Patterns match full paths case-insensitively, with multiple patterns ORed and deduplicated. A plain pattern is a substring; `*`, `?`, `[` enable glob matching. Globs also match an implicit trailing `.xmb`, so `*.tactics` finds `dock.tactics.XMB`. Omitting patterns matches everything: preview before broad extraction.

XMB decompilation defaults to UTF-8 XML with CRLF endings and removes the redundant `.xmb` suffix. Use global `--eol lf` for a different text convention. `--raw` retains the compiled XMB. Other binaries (GR2, DDT, PNG, WAV) are returned unchanged.

`xmbc.py check file.xml` compiles in memory, decodes back and compares the trees. `build` performs the same check then writes `file.xml.xmb`. `probe` inspects an existing XMB structure. It supports X1/XR v4 inside the alz4 wrapper; validate other format versions separately.

For override comparisons, compare keyed records (such as unit names or soundset names), reporting vanilla-only, mod-only and differing common records. An archive-path match, including the XML/XMB suffix alternative, identifies an override more reliably than a naming prefix.
