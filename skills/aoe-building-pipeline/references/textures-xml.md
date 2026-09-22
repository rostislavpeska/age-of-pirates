# AoP texture/XML profile and worked examples

Use [aoe3de-building-export](../../aoe3de-building-export/SKILL.md) for the shared texture workflow and validator. Read [aoe-xml](../../aoe-xml/SKILL.md) for all AoP loading, path, line-ending and XMB rules.

## St Pauls texture profile

The tested maps are 2048x2048 RGB TGA without alpha, exported to RTS3 DXT1 with ten mip levels (`.(0,0,4,10).tga`). This building's mask uses R=AO, G=roughness, B=metallic; verify that packing for any other shader. The validator is `skills/aoe3de-building-export/scripts/validate_opaque_textures.py`.

The session used Resource Manager `Ddt.FromPicture` through PowerShell 7; Windows PowerShell could not load its .NET dependencies. Keep the installation path local. Phase39's masked stone change (RGB factors 0.96/0.94/0.90) was an artistic checkpoint, not a reusable preset.

## AoP conventions and references

- Reference stock textures by archive path, e.g. `homecity\british\british_tol\textures\british_tol_03_matA_BaseColor`. Do not place extracted stock copies under runtime art. Custom images can be converted with Resource Manager or `scripts/havok/ddt_dxt1.py`.
- For a minimal static structure inspect Trade Harbour. When Basilica behavior/decal/sound is requested, read the actual Great Basilica definitions. The London example is `art/buildings/london_basilica/london_basilica.xml`; confirm its current component/model relationships.
- `default_doublesided` exists in the London materials. Reuse the actual bell material for `matc` when requested. Resolve slots and archive paths from current files.
- Art/material and `_snds` files remain plain editable **CRLF** XML. LF-only XML produced an invisible placeable model in the Tower of London incident. Run `python scripts/tools/check_art_eol.py` before a game test. Data-XMB rules do not authorize art/sound twins.
- A Great Basilica proto clone retains the requested techs, abilities, commands, costs, behavior and sound events. Allocate unique ids/names and check referenced tech targets. Consult `docs/data_xml_guide.md` and string synchronization tools for data definitions.
- Use `skills/mod-deploy-check/SKILL.md` for packaging and `skills/game-startup/SKILL.md` for game testing. Keep BLEND/PSD/FBX, logs, scripts and backups outside runtime distributions.
