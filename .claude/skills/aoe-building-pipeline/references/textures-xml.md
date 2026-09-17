# Textures and game definitions
## Opaque texture profile
This building uses 2048x2048 **24-bit RGB TGA without alpha** for basecolor, normals and masks. Source suffix `.(0,0,4,10).tga` feeds the verified Resource Manager RTS3 DXT1 profile with 10 mip levels. This is not a universal transparent-asset profile. Check a working target material when other channels/alpha are needed.
Basecolor is sRGB; normals/masks are non-color data. Here R=AO, G=roughness, B=metallic; verify the shader convention before reuse elsewhere. Preserve normal handedness, tangent vectors and the user's source/strength. Arbitrary normal RGB contrast is not equivalent to valid stronger normals.
The session used Resource Manager `Ddt.FromPicture` via PowerShell 7; Windows PowerShell failed loading its .NET dependencies. Parameterize tool paths and do not redistribute proprietary binaries. Decode all mips, check dimensions/channels/error against source, then stage and hash-verify installation. Backups belong outside runtime art folders.
`scripts/validate_opaque_textures.py` checks TGA header and complete DXT1 mip ranges/decoding. It does not certify artistic quality, shader packing or tangent handedness. Phase39's masked 0.96/0.94/0.90 stone RGB change is an artistic revision, not a universal tone preset. Texture-only changes normally do not require FBX/GR2 re-export; geometry, UV, rig and material-binding edits do.

## HARD RULE: reuse in-game textures, never copy them
A `.material` that needs a vanilla texture (also for a colour variant via `<parameters variant="N">`) points at the archive path,
e.g. `override="homecity\british\british_tol\textures\british_tol_03_matA_BaseColor"`. Never extract a game texture and write it
under `art/` - not under its own name, not renamed. Only textures the mod made (from licensed, downloaded or generated images,
converted with Resource Manager or `scripts/havok/ddt_dxt1.py`) are files in the mod. Every extra byte ships in the portal zip.

## Material and XML
Read a working `.material` and resolve every exported slot to intended maps. Reuse the existing bell material/texture reference for matc when requested; do not guess paths. `default_doublesided` exists in current London and other repo materials; use deliberately, not to mask geometry defects.
For static animation XML use a simple building such as Trade Harbour as the structural reference; Great Basilica supplies requested behavior/decal/sound. Do not copy irrelevant animations, attachments, bones or state machines. Read actual files and resolve components and paths. The London example is `art/buildings/london_basilica/london_basilica.xml`; verify it against the current GR2 instead of assuming previous generated XML is correct.
Minimal static relationship: Idle references a component containing the intended GrannyModel. Follow the working grammar, including names stored as element text. Add Basilica decal from its actual definition and verify size/offset. Keep art and `_snds` **plain editable XML**, without new `.xml.xmb` twins masking edits. **Line endings must be CRLF** - LF-only files are silently ignored (invisible model); `python scripts/tools/check_art_eol.py` audits, `--fix` converts.
For a Great Basilica protounit clone preserve requested techs, abilities, commands, costs and behavior. Allocate unique IDs and intended internal/editor/display names. Verify tech targets and referenced abilities, not just copied text. Reuse actual Great Basilica sound events. Read `docs/data_xml_guide.md` and existing tooling for data/string XML-XMB synchronization; that rule does not extend to art/sound.

## Diagnose and deliver
Distinguish missing editor entry, placeable-but-invisible model, exploding geometry and surface artifacts. Check respectively definitions/references, paths/bounds/scale/bindings, buffers/rig and shading/UV/geometry. Do not cycle unrelated settings. Test the same unit, file version and view.
Preserve manual game testing; do not start/restart/close the game without authorization. Report actual game-test state separately from file validation.
Read `.claude/skills/mod-deploy-check/SKILL.md` for package checks. Exclude FBX/PSD/BLEND, logs, scripts and backups from distribution. Keep conversion staging outside runtime art directories.
