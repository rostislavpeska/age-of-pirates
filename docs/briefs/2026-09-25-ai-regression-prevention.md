# Preventing silent AI regressions: proposal (2026-09-25)

For the owner. It is a decision paper: one guard is implemented, the rest wait for approval.

## What happened

- **2026-08-25:** `893135a4` built the Istanbul fleet split on the owner's instruction: pirate ships and monitors
  attack the Naval Guns, the other warships guard the Naval Forts.
- **2026-08-27:** `570d65a2` deleted it in a 1950-line "strip" commit. The commit message lists the deletion, but no
  owner approval.
- **Why nothing noticed:**
  - The test suite checked that the code which exists is well-formed. It never checked that the owner's behaviours
    exist.
  - The criteria for the in-game runs that day were rewritten to match ("G1/G2 now fail permanently because they
    test the deleted gun/monitor rules; prune them from criteria.py").
  - The comment headers of the deleted rules stayed in the file, so a reader still saw the split.
- **2026-09-11:** release v7.2 shipped without it.
- **2026-09-25:** the owner found it by watching a match, a month later.

The failure chain has four links. Each guard below cuts one of them.

| Link | Guard |
|---|---|
| An agent deletes an owner-ordered behaviour | G1 feature registry, G2 deletion gate |
| The tests stay green | G1, G3 orphan-header lint |
| The in-game criteria are edited to match | G4 criteria are the owner's |
| Nobody compares against a known good state | G5 per-map behaviour floor, G6 release inventory |

## G1 - owner feature registry (IMPLEMENTED in this commit)

`OWNER_FEATURES` in `scripts/aitest/tests/test_aitest.py` lists every behaviour the owner ordered, with:
- the owner's quote and date;
- the rules and functions that implement it.

The test fails when a listed rule is gone or no longer enabled. It is checked against the old code: it fails on
HEAD before this fix and on v7.2, and passes on `d33dba2e`, the last commit before the strip. Removing an entry is the
owner's approval step, as `APPROVED_LONDON_CODE` already is for London.

**Owner action:** name the other behaviours to register. Candidates, from the code:
- the Istanbul fort rules (`istanbulAttackKOTH`, `istanbulGuardianKiller`, `istanbulDefendKOTH`, `istanbulFortRaid`);
- the palace chain (`istanbulPalaceMission`, `istanbulPalaceHomeKiller`, `istanbulPalaceHold`);
- `MaintainPirateShips`;
- the London rounds.

Only the owner's own words go in; nothing is registered on a guess.

## G2 - deletion gate (proposed)

A test compares every `rule` and function in `aipiraterules.xs` against a committed manifest
(`scripts/aitest/ai_manifest.txt`, one name per line).
- A name that disappears fails the suite until the manifest is edited in the same commit.
- The manifest edit carries an `owner:` line with the quote.

G1 guards what the owner listed; G2 guards everything else. Cost: small (a file and one test).

## G3 - orphan-header lint (proposed)

The strip left headers such as `// istanbulGunFleet - the standing Fixed-Gun-killer pool` with no code under them.
A lint fails when a comment header names a rule or function that is not defined. It would have flagged the deletion on
2026-08-27. Cost: small.

## G4 - criteria belong to the owner (proposed, a process rule)

`testing-process.md` already says "a criterion is changed only by the owner". `570d65a2` pruned G1/G2 from
`criteria.py` in the same commit that deleted the behaviour they measured. Proposal: a test that fails when a
criterion id disappears from a criteria module, the same manifest idea as G2.

## G5 - per-map behaviour floor (proposed)

Amazonia has a regression floor (`criteria_baseline.py`, B0-B5). The maps with custom AI (Istanbul, London, Paris) get
the same: a floor run on the test device and criteria that read the AIDIAG line. For Istanbul, from run 14's bad
numbers:
- at least 1 dock per AI by 12:00;
- navy >= 4 per AI by 20:00;
- a `GUNRAID` or `GUARD` line from every AI.

The floor is re-run after every AI commit that touches the map. Thresholds are the owner's to set; run 14 shows what
failing looks like.

## G6 - release inventory (proposed)

At each release tag, a script writes the per-map inventory (which rules each map's marker or map check enables) into
`docs/`. The next release diffs against it, so a rule that silently stopped being enabled shows up in the release
review. It would have shown the split missing from v7.2.

## G7 - where tests run (owner 2026-09-25, a standing rule)

In-game tests run only on the dedicated test device. The main device never runs them: that is the owner's machine
and budget. The testing agent gets a brief (like `2026-09-25-istanbul-fleet-split-restore.md`) and runs one test per
hypothesis.

## Recommendation

Approve G2 and G3 now: both are cheap and offline, and together with G1 they close the "deleted and still green" gap.
G4 and G5 need the owner's thresholds. G6 is worth doing at the next release.
