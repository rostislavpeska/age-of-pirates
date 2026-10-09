# Plan: unit voices generated with ElevenLabs

Status: PLAN ONLY (owner 2026-10-09: "keep generic soldier voice, only prepare plan"). Nothing is generated or wired
until the owner gives the go for a named unit. Units keep their current voices meanwhile.

## Why long takes

ElevenLabs reads very short lines badly: "!!!" accents and emotions come out flat or wrong (owner, 2026-10-09). A
longer text gives the model context, so the delivery carries. Plan: generate one long take per kind of line, then
cut it into single lines automatically, check every cut, and let the owner fine-tune the cuts in Audacity.

## Preconditions

1. **API key permissions** (ElevenLabs > API keys, owner only): Text to Speech, Voices read, Models read, User read,
   Speech to Text. Optional: Voice Isolator, Sound Effects. Checked 2026-10-09: the key still lacked `user_read`
   and `models_read` (`check_subscription` and `list_models` returned 401).
2. **Credits**: yearly Creator plan, 100k credits per month. The monthly refill date is not shown in the web app;
   `check_subscription` reports it once `user_read` is granted. Run it before and after every batch.
3. **Owner go per batch**: every generation is a paid call (AGENTS.md rule 12). Before a batch, state the unit, the
   number of takes and the estimated credits; wait for the yes.
4. Tools on the device: ffmpeg (WinGet), numpy. Audacity on the owner's side for review.

## Cost (from the subscription page, 2026-10-09)

| Model | Credits per character | Notes |
|---|---|---|
| v4 | 1 | newest, "most emotive", audio tags, 90+ languages |
| v3 | 1 | expressive, 70+ languages, 5,000 characters per request |
| v2 Multilingual | 1 | stable long-form, 29 languages |
| Flash / Turbo | 0.5 | fast, less expressive; not for voices with emotion |

Estimate for one unit voice set (12-15 lines in 3 takes, about 400 characters per take, up to 3 tries per take):
about 4-5k credits, plus voice-choice previews. 100k credits a month cover roughly 10-15 unit sets. Step 3 measures
the real cost of the first take; replace the estimate with it.

## Pipeline

### 1. Choose the voice (once per voice type, owner decides)

- `search_voice_library` for native speakers of the language (e.g. Korean male, adult, military tone); or design one
  with `text_to_voice` (previews) and keep it with `create_voice_from_preview`.
- Generate the same short test take with 2-3 candidates; the owner listens and picks.
- Record the voice id, model and settings in the provenance ledger (step 3).

### 2. Write the script

One script file per unit (JSON or YAML, kept with the unit's repo, e.g. the Koreans add-on for Korean units):

- every line: soundset type (Select, Acknowledge/Move, Attack, Death...), the text in the unit's language, the
  English meaning, the delivery direction;
- lines grouped into takes by mood (calm Select lines together, shouted Attack lines together), 6-10 lines per take;
- each line on its own paragraph, with a clear pause between lines (verify on the first take which pause markup the
  chosen model honours: paragraph breaks, ellipses, or break tags);
- emotion given as words or audio tags in the take (v3/v4), never as "!!!" alone.

Language and wording follow the unit's civ (historical terms checked, as with the random names). The owner approves
the script before any generation.

### 3. Generate

- `text_to_speech` per take, output to the session scratchpad (never the repo).
- Provenance ledger per call (JSON next to the take): date, voice id, model, settings, the exact text, output file,
  credits before and after. Every report counts the calls (rule 12).

### 4. Cut

`split_takes.py TAKE OUTDIR NAME` (prototype tested 2026-10-09):
- ffmpeg decode to mono 22050 Hz;
- pauses found by short-time RMS with thresholds from the take's own noise floor (hysteresis keeps soft onsets and
  decays);
- each line padded (0.04 s before, 0.12 s after), 10 ms fades, levelled to the same loudness;
- written as PCM 16-bit mono 22050 Hz WAVs (the AoE3 DE voice format);
- plus `NAME_labels.txt`, an Audacity label track of the cuts.

Known-answer test: 6 mod voice lines joined with random pauses and noise; 6/6 lines found, every cut contains its
true line. Tune `--min-pause` when a take has short pauses inside a line.

### 5. Check every cut

- `speech_to_text` (Scribe) on each cut; compare the transcript with the script line.
- Gate: number of cuts = number of script lines, and every cut matches its line. A miss, merge or split is reported
  with its time range; fix it by re-cutting with other parameters, in Audacity, or by regenerating that take.

### 6. Owner review in Audacity

Open the take, File > Import > Labels > `NAME_labels.txt`, listen, drag label edges if needed, then
File > Export > Export Multiple (split by labels) writes the corrected lines. Lines the owner rejects are regenerated.

### 7. Loudness

Match the mod's existing voice imports (the AoE2 Korean soldier lines play at vanilla level): measure their RMS and
peak and level the new lines to them. Vanilla `Sound/ypack/*.wav` cannot be decoded with ffmpeg (skill note).

### 8. Wire into the game

Follow the `aoe3de-soundsets` skill: WAVs under `sound/<language>/` of the repo that owns the unit, soundsets in
the additive `sound/soundsetsde.mods.xml` (or the add-on's soundset file), the unit's `_snds.xml` names them
(`civlogic` when the proto is shared). Checks: `xmlcheck.py`, `check_art_eol.py` (sound XML is CRLF), every
`filename` exists. Game test on the test device, never the owner's main machine; a full restart loads sounds.

## Implementation (when the owner orders it)

1. Add to `.claude/skills/aoe3de-soundsets/`: `scripts/split_takes.py` with its known-answer test,
   `scripts/stt_check.py` (step 5), the ledger format, and a section "Generating voices with ElevenLabs".
2. First unit: the owner names it. One voice choice, one script, one take, measure the cost, then the rest.

## Open decisions (owner)

- Which units get generated voices, and in which order.
- The voice per voice type (step 1).
- The API key permissions (precondition 1).
