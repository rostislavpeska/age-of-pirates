---
name: aoe3de-soundsets
description: How unit and building sounds work in Age of Empires III DE and how to add or wire them - the two layers (soundset definitions in Sound/soundsets*.xml and the mod's additive soundsetsde.mods.xml; per-proto sound files sound/<proto>_snds.xml with variationlogic / targetlogic / civlogic / techlogic), per-civ voices on a shared proto, the WAV format, importing voices from Age of Empires II (wiki downloads, ffmpeg), and the checks. Use when a unit is silent, speaks the wrong language, needs new voice lines, a new civ needs its own villager or soldier voices, or when asked to "define soundsets", "add sounds", "voice lines", "settler sounds", "_snds", "soundset".
---

# AoE3DE soundsets and unit sounds

Two layers. A **soundset** is a named list of WAV files; a **sound file** (`<proto>_snds.xml`) says which soundset
a unit plays for each event. Defining a soundset changes nothing in game until a sound file names it.

| Layer | Vanilla | In the mod |
|---|---|---|
| soundset definitions | `Sound/soundsets.xml`, `soundsetsde.xml`, `soundsetsx.xml`, `soundsetsy.xml` (Sound.bar) | additive `sound/soundsetsde.mods.xml`, root `<soundsetdefmods>` - add new sets here |
| per-proto sound file | `Sound/<proto lower case>_snds.xml` | `sound/<proto lower case>_snds.xml`: a full copy replaces vanilla's |
| audio | `Sound/<folder>/<name>.wav` in Sound.bar (e.g. `ypack\JapaneseVillagerM_Select1.wav`) | `sound/<folder>/<name>.wav` |

Read vanilla with the `bar-extract` skill: `bartool.py cat Sound/ypsettlerjapanese_snds.xml.XMB`,
`bartool.py cat Sound/soundsetsy.xml.XMB`. Never copy a vanilla WAV into the mod: name it by its path.

## Soundset definition

```xml
<soundset name="zpKoreanVillagerM_Select" volume="0.7000" maxnum="4" distance="1.0000">
  <sound filename="korean\Koreans_Villager_Male_Select_1_AoE2.wav" volume="1.0000">
  </sound>
</soundset>
```
- `filename` is relative to `sound/`, backslashes, extension included. One `<sound>` per variant; the game picks one.
- Copy the attributes of the vanilla family you mirror. Vanilla villager voices (`JapaneseVillagerM_*`) use
  volume 0.7, maxnum 4, distance 1.
- New sets go to `sound/soundsetsde.mods.xml` (additive). AoP's full copies of `soundsets.xml`, `soundsetsx.xml`
  and `soundsetsy.xml` are legacy overrides that go stale with every patch (the `vanilla-merge` skill): do not
  add to them. The additive file holds AoP's `American_Estate` (played by a power in game) and
  `zpGermanTankAcknowledge`.
- Names are case-exact and unique across all soundset files; prefix mod sets with `zp`.

## Sound file (`<proto>_snds.xml`)

```xml
<protounitsounddef>
  <protounit name="ypSettlerJapanese">
    <soundtype name="Select">
      <variationlogic>            <!-- the unit's model variation: villagers 0 = male, 1 = female -->
        <choice name="0"><soundset name="JapaneseVillagerM_Select" /></choice>
        <choice name="1"><soundset name="JapaneseVillagerF_Select" /></choice>
      </variationlogic>
    </soundtype>
    <soundtype name="Acknowledge">
      ... <targetlogic>           <!-- what the order targets -->
            <choice name="default">...</choice>   <choice name="enemy">...</choice>
            <choice name="build">...</choice>     <choice name="Huntable">...</choice>
            <choice name="Tree">...</choice>      <choice name="AbstractMine">...</choice>
            <choice name="AbstractFarm">...</choice> <choice name="AbstractFruit">...</choice>
            <choice name="AbstractResourceCrate">...</choice>
          </targetlogic>
```
- Sound types seen: `Select`, `Acknowledge`, `Grunt`, `Death`, `Creation`, `Exists`, `SelectSecondary`.
- Logic nodes nest freely: `variationlogic`, `targetlogic`, `civlogic`, `techlogic`.
- **`civlogic`** picks by the owner's civ name (`<choice name="Japanese">`). `<choice name="none">` is the
  fallback for every unlisted civ (vanilla `degunboat_snds.xml`); an empty `<choice name="Nature" />` is silence.
  This is how one shared proto speaks per civ: vanilla `settler_snds.xml` gives the `Settler` French, British,
  Swedish ... voices; `ypfishingboatasian_snds.xml` splits Japanese / Chinese / Indian boats.
- **`techlogic`**: `<choice name="none">` plus tech names, last active wins (vanilla Mexican settlers switch to
  American voices with `DEHCREVMXEmpresarioContracts`).

### Give a new civ its own voices on a shared proto

1. Define the civ's soundsets in `sound/soundsetsde.mods.xml` (mirror the vanilla family name by name).
2. Copy the vanilla `<proto>_snds.xml` into `sound/` unchanged, then wrap each leaf soundset in
   `<civlogic><choice name="none">vanilla</choice><choice name="<civ>">new</choice></civlogic>`. Every other civ
   keeps the vanilla voice through `none`.
3. A full copy shadows vanilla: after a DE patch, diff it against the new vanilla file. An additive
   `<proto>_snds.mods.xml` (root `<protounitsounddefmods>`) is reported on the official forum but NOT verified in
   this project - test one file in game before relying on it.

## Audio format

- PCM WAV, 16-bit, mono, 22050 Hz: every voice the mod imported (`sound/korean`, `sound/aboriginal`, ...).
- ffmpeg 9.0 could not decode vanilla's `Sound/ypack/*.wav` (2026-10-08), so match loudness against an
  existing mod import, not vanilla. The AoE2 DE voices need no gain change: the AoP Korean soldier lines (2024)
  are plain conversions and play at vanilla level.

## Importing voices from Age of Empires II DE

1. The civ's page on the Age of Empires wiki (`ageofempires.fandom.com/wiki/<Civ>`), section "In-game dialogue
   language", embeds the AoE2 DE lines as `.ogg` on `static.wikia.nocookie.net`. Fandom pages block plain HTTP
   clients: read the page in a browser and collect the `audio`/`a[href]` URLs ending in `.ogg`; the CDN files
   download with `curl -A "Mozilla/5.0"`. Downloads go to their own new folder in the session scratchpad.
2. Convert: `ffmpeg -i X_AoE2.ogg -ac 1 -ar 22050 -c:a pcm_s16le -map_metadata -1 -fflags +bitexact sound/<lang>/X_AoE2.wav`.
3. Keep the wiki file name (`Koreans_Villager_Male_Select_1_AoE2.wav`) under `sound/<language>/`.
4. Map AoE2 lines to AoE3 soundsets:

| AoE2 villager line | AoE3 soundset (vanilla family) | AoE3 target |
|---|---|---|
| Select 1-4 | `*_Select` | Select |
| Task 1-4 | `*_Acknowledge` | default, crate |
| Attack | `*_Attack` | enemy |
| Build, Repair | `*_Build` | build |
| Hunt | `*_GatherMeat` | Huntable |
| Chop | `*_GatherWood` | Tree |
| Mine | `*_GatherCoin` | AbstractMine |
| Farm | `*_Farm` | AbstractFarm |
| Forage | `*_GatherFruit` | AbstractFruit |
| Fish | `*_Fish` (no vanilla villager target; fishing boats) | - |
| Soldier Select / Move / Attack | `<Civ>_Soldier_Select` ... | Select / Acknowledge / enemy |

Provenance: AoE2 DE and AoE3 DE are Microsoft titles; record the source page in the commit message.

## Checks

```
python .claude/skills/aoe-xml/scripts/xmlcheck.py sound/soundsetsde.mods.xml sound/<proto>_snds.xml
python scripts/tools/check_art_eol.py          # sound XML is runtime XML: CRLF or it is ignored
```
`xmlcheck` verifies that every soundset a `_snds` file names exists (mod or vanilla); check that every
`filename` exists yourself. Sound XML has no `.xmb` twin. A full game restart loads sound changes.

## Examples in AoP

| What | Where |
|---|---|
| AoE2 Korean soldier voices, used by the Korean bombard native | `sound/korean/Koreans_Soldier_*_AoE2.wav`, sets `Korean_Soldier_*` in `sound/soundsetsy.xml` (2024, legacy full copy) |
| AoE2 Korean villager voices, 22 sets, defined only | `koreans/sound/` (Korean civ add-on), sets `zpKoreanVillager{M,F}_*`, `zpKoreanFishingBoat*` |
| Power start sound | `American_Estate` in `sound/soundsetsde.mods.xml`, used by `data/abilities/powermods.xml` |
