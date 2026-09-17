# art / sound XML - the runtime family (plain XML, CRLF, parsed at run time)

Path rule for everything below: backslashes, relative to `art/`, no extension; the engine looks in the mod folder
first, then the archives. A path that resolves to nothing is silently empty (no error, nothing drawn).

## Animfile (`art/<area>/<name>/<name>.xml`, named by the proto's `<animfile>`)

Grammar as used by the working files in this mod (koth.xml, london_basilica.xml, british_palaces.xml, tower_of_london.xml):

```xml
<?xml version='1.0' encoding='utf-8'?>          <!-- optional; vanilla files have none -->
<animfile>
  <definebone>bone_flag_civ</definebone>          <!-- every bone an <attach> names -->
  <attachment>civflag                             <!-- a named attachment = a small sub-animfile -->
    <component>flag
      <assetreference type="ClothFlag"><flag><blending>alphatest_color</blending><specialtexture></specialtexture>
        <width>2.00</width><height>1.50</height></flag></assetreference>
    </component>
    <anim>Idle<component>flag</component></anim>
  </attachment>
  <component>ModelComp                            <!-- what is drawn: one asset, or a logic switch of assets -->
    <logic type="Variation">                      <!-- <unit variation="N"> in an RM / random in the editor -->
      <data><assetreference type="GrannyModel"><file>buildings\spc\x\x</file></assetreference></data>
      <data><assetreference type="GrannyModel"><file>buildings\spc\x\x</file>
            <materialvariant index="1"></materialvariant></assetreference></data>
    </logic>
    <decal>                                       <!-- ground decal + selection box -->
      <effecttype>default</effecttype>            <!-- 'bump' needs <bumptexture> -->
      <selectedtexture>shadows_selections\selection_square_128x128</selectedtexture>
      <width>26.00</width><height>26.00</height><xoffset>0.00</xoffset><zoffset>0.00</zoffset>
    </decal>                                      <!-- <texture> = painted ground decal, optional (524 mod decals omit it) -->
    <attach a="civflag" frombone="bone_flag_civ" tobone="bone_flag_civ" syncanims="0"></attach>
  </component>
  <anim>Idle<component>ModelComp</component></anim>
  <anim>death<component>ModelComp</component>
    <attach a="collapse_smoke" frombone="ATTACHPOINT" tobone="ATTACHPOINT" syncanims="0"></attach></anim>
</animfile>
```

- **Component names are free text on the line after the tag** (`<component>ModelComp`), the same for `<anim>Idle`,
  `<attachment>civflag`, `<submodel>west_fort`. Anim names must cover what the tactics file asks for (Idle at least;
  units: Walk, Attack..., buildings: Idle, death, Build via construction submodels).
- **logic types seen**: `Variation` (`<data>` list), `Tech` (`<none>` + `<techname>` children), `SubCiv`,
  `Destruction` (`<p1>` damaged model, `<p99>` intact), `LowPoly` (`<normal>` / `<lowpoly>`),
  `HomeCityBuildingUnlocked` (home city only). `<submodel>` + `<submodelref ref>` switch whole sub-animfiles.
- **assetreference types**: `GrannyModel` (`<file>` + optional `<materialvariant index="N">` selecting the
  `.material`'s `<parameters variant="N">`; optional `shape="<name>"` collision shape borrowed from another model),
  `GrannyAnim` (`<file>` + `<tag type="Attack">0.45</tag>` / `SpecificSoundSet`), `ClothFlag`, `popcornFx`
  (`smoke\collapse_smoke_fort.pkfx` resolves under `Art\popcornfx\Particles\`), `ParticleSystem`
  (`effects\smoke\factory_smoke.particle`), `CompositeModel`.
- **decal**: with `<texture>` it paints the ground (`buildings\fort\west_fort_decal` + `_BaseColor/_Masks/_Normals`);
  without it only the selection box shows. Width/height in metres; make the box a little larger than the footprint.
- `<simskeleton><model>` pairs an intact model with its `_damaged` skeleton (destruction), see `havok-destruction`.
- Static building minimum: one component with a GrannyModel + decal, `<anim>Idle`. That is `london_basilica.xml`.

## `.material` (next to the gr2, same base name)

```xml
<material>
  <submaterial name="matA">                       <!-- MUST equal the material name inside the gr2 (case as in the file) -->
    <materialdef name="default" />                <!-- default | default_doublesided | default_doublesided_cutout | default_cutout | destructible -->
    <parameters>
      <texture name="BaseColor" override="homecity\british\british_tol\textures\british_tol_matA_BaseColor" />
      <texture name="Normals"   override="..._Normals" />
      <texture name="Masks"     override="..._Masks" />      <!-- optional: <texture name="Details" .../> -->
    </parameters>
    <parameters variant="1"> ...same three lines, other textures... </parameters>   <!-- selected by materialvariant index="1" -->
  </submaterial>
</material>
```

- Textures: `.ddt`, RTS3 header `usage 0, alpha 0, format 4 (DXT1), 10 mips` for 2048 / 512 opaque maps. Masks pack
  **R = ambient occlusion, G = roughness, B = metallic**. Normal maps are **DirectX green** (measured against vanilla
  `british_tol` 2026-09-17; a GL map inverts every joint). Mod-made textures: `scripts/havok/ddt_dxt1.py IN.png OUT.ddt
  --size 512` and `--pack AO ROUGH METAL OUT.ddt`.
- Vanilla textures are referenced by archive path, never copied (invariant 2).
- One `.material` serves several gr2s only if their material names match; every gr2 next to it needs a `.material`
  of its own base name.

## `_snds.xml` (`sound/<proto name lowercase>_snds.xml`, plain, CRLF, no twin)

```xml
<protounitsounddef>
  <protounit name="zpSPCTowerOfLondon">
    <soundtype name="Select"><soundset name="UI_Select_Building_Church"></soundset></soundtype>
    <soundtype name="SelectSecondary"><soundset name="UI_Building_Economic"></soundset></soundtype>
    <soundtype name="Creation"><soundset name="MilitaryBirth"></soundset></soundtype>
    <soundtype name="Death"><soundset name="BuildingDestruction"></soundset></soundtype>
    <soundtype name="Exists"><soundset name="AmbienceChurch"></soundset></soundtype>
  </protounit>
</protounitsounddef>
```

- Discovery is **by file name**: `<proto name>.lower() + "_snds.xml"` in `sound/` (mod) or `Sound/` (archive). The
  `<protounit name>` inside must match the proto exactly. No proto field points at it.
- Soundtypes: buildings `Select`, `SelectSecondary`, `Creation`, `Death`, `Exists` (ambient loop); units `Select`,
  `Acknowledge`, `Grunt`, `Death`, `Creation` (+ attack/move types the tactics call). Per-civ voices use
  `<civlogic><choice name="British">...</choice>` (every civ name listed, empty choice = silent), optionally
  `<techlogic><choice name="none">` / `<choice name="<tech>">` inside a civ.
- Soundset names come from `sound/soundsets.xml`, `soundsetsx.xml`, `soundsetsy.xml`, `soundsetsde.mods.xml` (mod)
  and the vanilla soundset files; the checker verifies each one exists. Reuse existing sets - a new set means new
  `.wav`/`.mp3` files (bytes in the zip).
- **Generation rule for recipes**: a new building or unit gets its `_snds.xml` generated from the nearest vanilla
  archetype (`bar-extract cat Sound/<archetype>_snds.xml.XMB`: church/fort/house for buildings, the matching unit
  class for units), `<protounit name>` swapped, written CRLF. Never ship a proto without one - the checker reports it.

## Path resolution table (what `xmlcheck.py` implements)

| reference | mod location tried | archive location tried |
|---|---|---|
| proto `<animfile>` `a\b\c.xml` | `art/a/b/c.xml` | `Art/a/b/c.xml.xmb` |
| GrannyModel / GrannyAnim `<file>` `a\b\c` | `art/a/b/c.gr2` | `Art/a/b/c.gr2` |
| `.material` `override` / decal `<texture>` / `<bumptexture>` / `<selectedtexture>` | `art/<p>.ddt` (+ `_BaseColor` for decals) | `Art/<p>.ddt`, `Art/<p>_BaseColor.ddt` |
| popcornFx `<file>` | `art/popcornfx/Particles/<p>` | `Art/popcornfx/Particles/<p>` |
| ParticleSystem `<file>` | `art/<p>` | `Art/<p>.xmb` |
| proto `<tactics>` | `data/tactics/<f>` | `Data/tactics/<f>.xmb` |
| proto `<icon>` / `<portraiticon>` `resources\art\x.png` | `data/wpfg/resources/art/x.png` | `Data/wpfg/resources/art/x.png` |
| proto `<minimapicon>` `ui\minimap\x` | `art/ui/minimap/x.ddt` | `Art/ui/minimap/x.ddt` |
| proto sounds | `sound/<proto lower>_snds.xml` | `Sound/<proto lower>_snds.xml.xmb` |
| `<soundset name>` | `sound/soundsets*.xml` | `Sound/soundsets*.xml.xmb` |

## Model notes that belong to the XML author

- A vanilla model reused for a new unit keeps its vertex bytes (in-place edits via `gr2-granny-edit` /
  `scripts/havok/gr2_editmesh.py`); the FBX -> converter route loses every large flat face in game (measured
  2026-09-17). Home-city models (`Art/homecity/...`) work in game once baked Y-up with an identity root.
- **`bone_flag_civ` gets the civ flag automatically** from the engine (the vanilla Town Center animfile only
  `<definebone>`s it, no ClothFlag, no attach). Adding an explicit `civflag` ClothFlag on that bone gives TWO flags on
  one pole (Tower of London 2026-09-17). Explicit `<attach a="civflag">` is only for differently named bones (Fort: `bone_f5`).
- Bones an animfile attaches to must exist in the gr2 (`gr2_dump.py --bones`); `bone_flag_civ` on the flagpole,
  ~1.4-1.8 m below its tip for a 1.5 m civ flag.
