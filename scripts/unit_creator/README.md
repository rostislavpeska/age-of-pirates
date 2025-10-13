# Unit Creator (Python)

This tool implements the spec in `scripts/unit_creator/unit_creator.md`.

## How to run

- Open a terminal in the project root.
- Run:

```bash
python scripts/unit_creator/main.py
```

It will read sources and write cloned data under:
- `scripts/new_data/` (protomods, abilities, tactics)
- `scripts/new_sounds/` (sound XML)
- `scripts/new_art/` (anim files)

## Configuration

Edit `scripts/unit_creator/main.py` `CONFIG` dict:
- `units.proto_name` (required): name of the new unit
- `units.proto_base` (required): existing unit to clone from
- `params`: optional overrides per spec
- `sources`: primary/secondary sources per spec

The script raises the exact exceptions described in the spec when required inputs are missing or sources cannot be found.
