---
name: aoe3de-soundsets
description: "Wire and diagnose AoE3 DE soundsets, per-unit sounds and civilization voices. Use for silent units, wrong voices or importing and checking new sound assets."
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
- A generated or trimmed line is not a conversion. Its loudness is in the WAV samples. Do not
  raise a soundset `volume` to make a generated line catch an AoE2 line: that turns both up and the
  gap stays. The Korean monk sets were left at 0.88 after a file gain could not pass the revived
  peak (2026-10-13). The owner rejected that and required the rest of the gain in the file
  (2026-10-14).
  Peak-matching and integrated LUFS both failed on that voice. A linear gain on every monk line,
  AoE2 and generated, also failed: the loudest 200 ms moved together and the words stayed behind.
  On the generated lines the loudest 200 ms was already near the AoE2 monk lines, while the median
  of the speech windows sat 4 to 8 dB lower (Attack 1: loudest 200 ms −15.7, speech body −27.2).
  Lift that body in the generated file only. Leave the AoE2 file at the level a plain conversion
  already has. Hold the peak at or under −1 dBFS with a limiter, because a linear gain clips the
  revived line (peak −0.1 dB) before the words get there. Do not run `loudnorm`. The 2026-10-14
  pass used `compand` then `alimiter` and brought the eleven generated bodies from about −20 to
  −27 dB into −17 to −20 dB, with the loudest 200 ms rising only about 1 dB.
- A ritual voice stays one calm sentence, with no exclamation. Two Korean monk passes were rejected (2026-10-13). Brian at speed 0.95, stability 0.4 and style 0.35 on shouted phrases sounded fast and angry. Bill at speed 0.76, stability 0.75 and style 0 sounded mechanical: high stability flattens the voice, style 0 removes the breath, and a low speed time-stretches it. An English premade voice speaking Korean adds to that. This key cannot clone the AoE2 monk or add a Korean library voice (`voices_write` is missing). Leave stability near the middle and speed near 1. Style carried too far on a shouted phrase sounded angry (0.35). Style held at 0.18, so the prepared claim line would land cleanly, left it with no feeling (owner, 2026-10-13). The feeling and the cut are different controls: style around 0.3, plus the unspoken sentence, carries the feeling; the pause after the sentence is what makes the cut clean. Play the take beside the AoE2 monk lines before treating the setting as the voice. Leave the AoE2 recording itself unchanged.

## Prepare a generated line

The feeling is in the sentence. The cut is in the pause after it. Lowering the style does not make a cleaner cut; it only flattens the line. A short line with no context also comes out flat (owner, 2026-10-09).

1. `text` is one finished sentence, ending in a period. No second sentence in the same request, and no exclamation. On a calm sentence, style around 0.3 leaves the feeling in the voice. The angry pass was that same region on a shouted phrase.
2. `previous_text` is the unspoken sentence that came before it. It is not spoken, and it is what gives a short line the weight of a longer take. For a weary line, that unspoken sentence is the weary one, so the spoken line can fall away.
3. Do not send `next_text`. A following sentence makes this one rise, and the ending sounds cut off even when the file has already gone quiet.
4. On `eleven_multilingual_v2`, end the text with a break of about 0.8 s. The model finishes the pitch into that pause, and the cut stays inside the pause. Eleven v3 and v4 do not support the break tag; use punctuation there. The weary or moved ending is the emotion, so the trim has to keep it.

```
가만히, 받아들이겠네.<break time="0.7s" />
```

5. Detect speech down to about −50 dB, so a quiet last syllable still counts. Keep about 180 ms after it. Fade that silence for about 30 ms. Do not fade the syllable.
6. Two ffmpeg passes. Put `-ss` and `-to` before `-i` and write the raw WAV, then a second pass for the fade and `volume`. One pass that seeks and fades together writes silence.
7. Lift the speech body of this line in the WAV until it matches the AoE2 lines in that voice, as in Audio format. Limit the peak. Do not match integrated LUFS, do not gain the AoE2 lines, and do not put the difference on the soundset volume.

Claim 3, review row 6 (`가만히 받아들이겠네`, 2026-10-13), was prepared so the ending would land, and the owner heard no feeling. KnockOut 1, row 7 (`숨이 잦아들겠네`), was cut wrong in the same set: the fade of that line is the feeling, and a trim into it removes both.

## Inspect a trimmed line

Run this on every generated or trimmed WAV before it is wired, and again after a recut:

```
python .claude/skills/aoe3de-soundsets/scripts/inspect_wav.py path\to\line.wav
```

It prints one row per file: duration, `ok` or `LEADING FRAGMENT`, and a 20 ms loudness shape (`#` loud, `+` speech, `.` quiet). Exit 1 means a speech burst of 160 ms or less is separated from the rest of the line by a pause of 120 ms or more. That burst is the tail of the previous sentence. A syllable gap inside one phrase is shorter than 120 ms and is left alone.

When the owner has to hear the lines separately and name one by number, serve them with the [artifact page](../artifact-page/SKILL.md) instead of playing the folder in one sequence.

The Korean monk KnockOut 1 line (2026-10-13) was a different failure. The long take ended `힘이 빠지는군. 쓰러지겠네.` Silence detection required 80 ms of quiet, and the pause before the last word was 70 ms, so the two sentences stayed one span. That span was longer than 1.15 s, and the cut kept its last 0.95 s, which began inside the previous sentence. A new line is prepared as one sentence, above. Do not repair a merged span by keeping its last N seconds.

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
python .claude/skills/aoe3de-soundsets/scripts/inspect_wav.py sound/<folder>
```
`xmlcheck` verifies that every soundset a `_snds` file names exists (mod or vanilla); check that every
`filename` exists yourself. Sound XML has no `.xmb` twin. A full game restart loads sound changes.

## Examples in AoP

| What | Where |
|---|---|
| AoE2 Korean soldier voices, used by the Korean bombard native | `sound/korean/Koreans_Soldier_*_AoE2.wav`, sets `Korean_Soldier_*` in `sound/soundsetsy.xml` (2024, legacy full copy) |
| AoE2 Korean villager voices, 22 sets, defined only | the Koreans add-on repo `age-of-pirates-koreans`: files `sound/korean/`, sets `zpKoreanVillager{M,F}_*`, `zpKoreanFishingBoat*` in its `tools/korean_soundsets.xml` |
| Power start sound | `American_Estate` in `sound/soundsetsde.mods.xml`, used by `data/abilities/powermods.xml` |
