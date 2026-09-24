---
name: grouping-centering
description: Detect and fix out-centred city block groupings (EU_ / IT_ / IS_ blocks and lots in game/randmaps/groupings) whose units were displaced against their own ground by a Scenario Editor re-export - street poles off the block edge in one or two directions. Whole-metre fixes (+1 / +2 m only), evidence from edge poles, EU/IT/IS twins and edge units; a verification set of test maps on flat Great Plains ground with every grouping at least 20 m apart; apply only after the user approved in game. Triggers on "outcentered", "out-centred block", "poles off the edge", "grouping not centered", "block shifted", "center the groupings", "fix the city blocks".
---

# grouping-centering: whole-metre fixes, verified in game before they land

The game, the editor and every test map run ONLY on the user's word. Groupings load at game START: after any
build or apply the game must restart before a test means anything (`workflow.py status` says so). Never write
into the Steam `Game\RandMaps\groupings` folder; the repo is the source of truth and what the game reads, the
profile `RandMaps\groupings` is only a mirror (`rm-groupings-deploy`, corrected 2026-09-24). `workflow.py` still
writes the profile copy too, and its restart check keys on the profile's mtimes - treat the repo file's mtime as
the one that counts.

## 1. What "out-centred" is

The Scenario Editor re-export moves every unit of a grouping by whole metres against its own ground: (-1, -1) m,
or -1 m on one axis (memory `grouping-editor-export-shift`; git: `EU_House_Block_Embassy` 8f7a5d7b centred ->
9bd1d2bd all units -1, -1). The ground (tiles, heights) stays put, so the street poles land off the block edge on
the low side and the buildings off their paint. The displacement is ALWAYS negative.

## 2. The method (scripts/centering.py)

| Step | Rule |
|---|---|
| Area | the grouping's real rectangle: `<width>` x `<height>` tiles, 2 m each, centred on the origin (measured over every repo grouping: tiles run from -size//2, centred blocks' poles average -0.02 m) |
| Edge poles | `PropsPoles` within 3 m of a side of that rectangle; poles further in are middle poles and never count |
| Pole centre | per axis: midpoint of the mean pole on the low side and the mean pole on the high side (both sides needed) |
| Twin | the EU_/IT_/IS_ version of the same lot; if one is the other moved by a whole-metre vector for >= 60 % of the units, the one further in -x/-z is displaced (IT/IS_SPC_PlayerFood = EU_SPC_PlayerFood + (-1, -1), 83 %) |
| Edge units | city lots (`Block`, `SPC_Player` in the name) without poles on both sides: every unit in the 3 m edge band, same midpoint |
| Fix | minus the offset rounded half up to whole metres, **+1 or +2 m only**; no fix for a positive offset (uneven poles), under 0.5 m, or beyond 2 m (a different layout) |
| Apply | every unit's posx / posz moves; ground, heights, unit order, CRLF stay byte-identical |

Evidence order: twin, then edge poles, then edge units. `EXCLUDE` (`EU_SPC_Player_London`) is never touched.

What the rules came from (2026-09-22, each a user verdict in game): fractional moves are invisible and wrong
(whole metres); a -1 m "fix" of `EU_SPC_Player_London` and poles-only fixes of IS blocks with POSITIVE offsets
(Phanar, Menagerie, Military, SPC Lombard) were regressions (negative only); lots without poles were missed until
twins and edge units were added (14 fixes, not 8).

## 3. The workflow (scripts/workflow.py)

```bash
python .claude/skills/grouping-centering/scripts/workflow.py scan     # decision table, writes nothing
python .claude/skills/grouping-centering/scripts/workflow.py build    # verification set
python .claude/skills/grouping-centering/scripts/workflow.py status   # restart needed?
python .claude/skills/grouping-centering/scripts/workflow.py apply    # ONLY after the user approved
python -m pytest .claude/skills/grouping-centering/tests -q
```

1. **scan** - show the table (grouping, fix, evidence) to the user.
2. **build** - writes `<stem>_Centered.xml` (repo + profile) for every fix and two test maps in the Steam
   `Game\RandMaps` folder, plus review files in `sandbox/grouping-centering/review/`:
   - `000_zpblockfix` - PAIRS: each fixed grouping, original LEFT, `_Centered` RIGHT (`pairs_legend.png`)
   - `000_zpblockset` - SET: every city block as it will be after the change, fixed ones as `_Centered`
     (`set_legend.png`, fixed = green)
   - `sheet.png` - top view of every pair (frame = real size, red = poles) with its evidence line
   Both maps: flat Great Plains ground (`great_plains\ground1_gp`, `GreatPlains_Skirmish`, as vanilla
   `great plains.xs`) and **at least 20 m between any two groupings** - never side by side, so each block is
   judged on its own ground. Centres sit on even metres.
3. **The user restarts the game, generates both maps and judges.** Send the legends and the sheet FIRST; the
   first line of the hand-over says "restart the game" (memory `grouping-test-copies-need-restart`: copies written
   into a running game never spawn, the user sees only the originals and reads it as a regression).
4. A block the user calls worse: add it to `EXCLUDE` (or fix the rule), `build` again. Never argue from the numbers.
5. **apply** - only on the user's explicit approval: writes each fix into the original (repo + profile), deletes
   the `_Centered` copies and the pairs map, rebuilds the set map from the fixed originals, rescans (must find
   nothing) and ends with the restart check. Back up the profile copies first when they differ from the repo.
6. Commit only on request, the groupings together with any skill change.

## 4. Pitfalls

- A grouping whose profile copy differs from the repo (another session's edit): the fix is computed from the
  repo; say so before apply, the deploy overwrites the profile copy.
- Uneven poles are common (IS blocks, Player London): an offset alone is not a displacement - that is why
  positive offsets are never fixed.
- Test-map ground: a crowded map with many distinct ground types may render some of them flat brown
  (unverified limit, 2026-09-22 `EU_SPC_Player_London` diagonal streets); the Great Plains base keeps the count low.
- Never write the Steam `groupings` folder, never rotate a grouping (`grouping-no-rotated-copies`), never touch
  a working file the user has not named.

Related: `grouping-terrain` (tile maps, `shift` of named protos), `rm-groupings-deploy`, `rm-census`.
