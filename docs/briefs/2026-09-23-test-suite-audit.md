# Brief: make the test suite serve us - audit, GitHub issues, polish, new tests

Written 2026-09-23 for a fresh agent running in Claude Desktop with a browser and file access to
this repository. The author of this brief did no exploration for it: every fact below was
established in the session that wrote it, everything else is yours to find. Where this brief and
the repository disagree, the repository wins - say so in your report.

## 0. The one-paragraph mission

The repository carries several pytest suites and five GitHub Actions workflows. Some tests guard
real behaviour, some fail for reasons that have nothing to do with the mod (machine paths, the
newest file in a folder, modification times), and two mapsim tests have been red for weeks. The
owner's words: the suite must be *"actually serving, not mobbing us"*. Your job: inventory every
test and workflow, read every GitHub issue, classify each test as keep / fix / quarantine /
propose-delete, make the CI checks green without hiding real regressions, propose (and, once
approved, write) new tests that catch the regressions the issues and the git history show
actually happen, and hand back a report the owner can act on in ten minutes.

## 1. Environment - read before touching anything

- Repository = the live mod folder the game loads:
  `C:\Users\TIGO\Games\Age of Empires 3 DE\76561198347905238\mods\local\age-of-pirates`.
  Every byte here ships. Git remote: `https://github.com/rostislavpeska/age-of-pirates`.
- **The working tree is shared.** Other Claude Code sessions commit in this same folder while
  you work, and the game may be running and reading it. Therefore:
  - never `git checkout`, `git switch`, `git stash`, `git reset`, `git rebase`, `git clean`,
    never `git add -A` / `git add .`, never `git commit -a`. Commit only files you changed,
    named explicitly: `git add <path> <path>` then `git commit`.
  - never force-push, never delete branches, never touch `main` (it is a protected branch that
    only accepts pull requests).
  - the current branch is `Pirate-rework` (checked out 2026-09-23 01:30, identical to
    `inuit-harpooner`). Commit there. If `git branch --show-current` says something else, stop
    and ask.
- Pull request #33 (`Pirate-rework` -> `main`) is open on GitHub. Its checks run on every push
  to `Pirate-rework`, so each of your commits gets a free CI run. It has one merge conflict
  (`.gitignore`, deleted on `main` in 2024, kept on the branch) - that conflict is **not yours**
  to resolve; leave it.
- Read `AGENTS.md` at the repository root first. Its hard rules bind you. The ones that bite a
  test-suite job:
  1. Runtime XML must be CRLF (`art/**/*.xml`, `*.material`, `sound/**/*_snds.xml`, `*.lgt`,
     `*.tactics`). Any file you write there gets checked with
     `python scripts/tools/check_art_eol.py`.
  2. `data/*.xml` edits are inert until the `.xml.xmb` twin is rebuilt
     (`python .claude/skills/aoe3de-bar-archives/scripts/xmbc.py check|build data/<file>.xml`).
     You should not need to edit data XML at all; if a test needs a fixture, build the fixture
     in the tests folder, not in `data/`.
  3. Vanilla game files never enter the repository. If you need one, read it with
     `python .claude/skills/aoe3de-bar-archives/scripts/bartool.py cat <path>` or extract into a
     temporary folder outside the repository. `git status --short` must show no stray `Data/`,
     `Art/`, `Sound/`, `bar_export/` or `__pycache__` before you commit.
  4. New records go at the end of real content, never beside a related old record.
- **Never start, click, or kill the game.** In-game verification is the owner's and costs real
  money. Nothing you build may depend on an in-game run to pass.
- Python is available; run every suite from the repository root.
- Windows. Line-ending traps: `sed -i` strips CR from files; prefer Python for edits to files
  that must stay CRLF. Do not assume `/tmp`.

## 2. Facts established on 2026-09-23 (your baseline - verify, do not trust)

### 2.1 Workflows (`.github/workflows/`)

| File | Name on GitHub | What it runs (from the file) |
|---|---|---|
| `mapsim.yml` | Mapsim Tests / Mapsim Test Suite | `pip install pytest`, `python -m pytest scripts/mapsim/tests -q` on ubuntu |
| `proto.yml` | Proto Validation | `python _proto.py` |
| `stringtables.yml` | (read it) | (read it) |
| `techtree.yml` | (read it) | (read it) |
| `xml_malformations.yml` | (read it) | (read it) |

On PR #33 at 01:20 the page showed: 1 failing check (Mapsim Tests), 1 in progress,
3 successful. Which one was still in progress and whether it passed is for you to read on the
Checks tab.

### 2.2 Local run of the CI suite, 2026-09-23 01:25, on `4b691f18`

`python -m pytest scripts/mapsim/tests -q` -> **187 passed, 2 failed**, about 60 s:

1. `scripts/mapsim/tests/test_geometry.py::TestBoxes::test_malformed_box_raises` -
   `Failed: DID NOT RAISE <class 'ValueError'>`. The code accepts a malformed box that the test
   expects to be rejected.
2. `scripts/mapsim/tests/test_scene.py::TestSnapshot::test_snapshot_hash_matches_recorded` -
   `AssertionError: vendored snapshot changed - re-baseline the scene (plan section 1.3)`;
   recorded `d1511d08...`, actual `81f780a1...`.

Both test files were last changed in commit `8720cb78` (2026-08-02). The mapsim code was last
changed in `3c23d3c9` (2026-09-17, "RM skill library + unit bench ...") and `e948b4f5`
(2026-09-11, "Strings: move the mod's 300000 row to the 500000 row"). Those two commits are the
suspects; `git log -p` on the relevant files decides. For each failure decide with evidence
whether the **code** regressed (fix the code) or the **change was intended** (fix the test /
re-baseline), and write the reason in the commit message.

### 2.3 The other suite: `scripts/mapcheck/tests/`

Not run by any workflow (verify). It holds the map-script regression tests
(`test_london_roles.py`, `test_london_revolt.py`, `test_parliament_natives.py`,
`test_xs_scope.py`, `test_jones_captain.py`, `test_inuit_harpooner.py`, and more - list them).
Known properties that make parts of it machine-bound:

- Many London tests assert byte identity between `randmaps/zplondon.xs` and a copy in the Steam
  install (`C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game\RandMaps\00000_zplondon.xs`).
  On any other machine they fail.
- `test_xs_scope.py` runs `scripts/mapcheck/xs_scope_check.py`, which takes its list of known
  engine functions from the **newest** `Age3DERM*.dmp.txt` in the profile folder
  (`C:\Users\TIGO\Games\Age of Empires 3 DE\76561198347905238\RandMaps`). The game rewrites
  those on every map generation. On 2026-09-23 an Istanbul dump became newest, it lacks the
  `mercenaries.xs` include functions, and 18 maps failed on `[UNKNOWN_FN] chooseMercs()` with no
  change to any map. `--dump <file>` overrides the choice. This is the textbook "mobbing" test.
- XMB twin freshness is asserted by modification time (`.xml.xmb` mtime >= `.xml` mtime) in
  several tests. mtime is not content; a checkout, a copy, or a touch flips it either way.
  The `mod-deploy-check` skill (`.claude/skills/mod-deploy-check/`) already audits stale twins
  **by content** - see whether the tests can share that.
- Some tests read the profile groupings folder or the Steam `Game\RandMaps` folder. Those paths
  exist only on the owner's machine.

### 2.4 Test-related material already in the repository

- `.claude/skills/rm-trigger-testing/SKILL.md` and `.claude/skills/rm-census/SKILL.md` - the
  trigger-testing approach built on 2026-09-22 (read them; they define what "a trigger test"
  means here).
- `.claude/skills/mapcheck/SKILL.md` - the map checker the tests wrap.
- `docs/briefs/2026-09-22-trigger-testing-skills.md` - the brief that produced those skills.
- `docs/briefs/2026-09-22-london-debug-list.md` - the London in-game checklist; shows what the
  owner verifies by hand and therefore what a test could take off his plate.
- `docs/skill-system-architecture.md` - how skills are organised, if you need to add one.

## 3. Method - do it in this order, write as you go

Keep a running notes file at `docs/briefs/2026-09-23-test-suite-audit-report.md` from the first
step. Every phase appends to it. If you are cut off, the file is the handover.

### Phase A - inventory (repository only, no browser yet)

1. `find` every `tests/` folder, every `conftest.py`, every `pytest.ini` / `pyproject.toml` /
   `setup.cfg` pytest section, every marker. Table: suite, path, test count, runtime, runs in CI
   (which workflow) yes/no.
2. Run each suite locally once: `python -m pytest <path> -q -rA --durations=15`. Record the
   pass/fail/skip counts and the 15 slowest tests. Do not fix anything yet.
3. For every failing or skipped test: one line - name, the assertion message, the suspected
   cause class: `code-regression` / `stale-baseline` / `machine-path` / `newest-file` /
   `mtime` / `other`.
4. `grep` the suites for the machine dependencies: `Program Files`, `76561198347905238`,
   `st_mtime`, `getmtime`, `.dmp.txt`, `Steam`, `RandMaps`. Every hit is a candidate for a
   `local` marker (see Phase D).

### Phase B - GitHub, in the browser

You can see the GitHub UI; the sessions that wrote this brief cannot. Read, do not click
anything that changes state (no merge, no close, no label edits, no re-runs unless asked).

1. **Actions**: for each of the five workflows, open the last 10 runs on `Pirate-rework` and
   the last 5 on `main`. Table: workflow, run date, branch, commit, result, the first failing
   assertion (open the log). Find the first run where each currently-red check went red and the
   commit that did it.
2. **Pull request #33**: Checks tab - every check's state and log. Files tab is 1893 files, do
   not read it; you only need the checks.
3. **Issues** (`/issues?q=is%3Aissue` - open AND closed, every page): for each issue record
   number, title, state, created, closed, labels, one-line summary, and a column "covered by a
   test today?" (name the test) / "could be covered by a test" (how) / "not testable offline"
   (why - usually needs the game). Read the comments, they often contain the actual root cause.
4. Cross-reference: which issues describe regressions that the current suites would NOT catch
   if they happened again? That list is the seed of Phase E.

### Phase C - classification

One table, every test class (not every test method - classes are the right grain here):

| suite / file / class | verdict | reason | action |
|---|---|---|---|

Verdicts, exactly these four:

- **KEEP** - guards real behaviour, deterministic, runs anywhere. No action.
- **FIX** - guards real behaviour but is currently wrong (stale baseline, changed contract,
  brittle assertion). Action = the fix, one commit each.
- **QUARANTINE** - only meaningful on the owner's machine (Steam twin, profile dumps, mtime).
  Action = mark it `local` and skip it with a clear reason where the path is missing; it keeps
  running for the owner, CI ignores it. Never delete it.
- **PROPOSE-DELETE** - tests nothing, or tests a thing that no longer exists. Action = a line in
  the report. **You do not delete tests.** The owner decides.

### Phase D - the fixes, one commit each, smallest first

1. A `local` pytest marker registered in the pytest config, plus a `conftest.py` helper that
   skips `local` tests when the Steam or profile path is absent, with the reason in the skip
   message. Then `-m "not local"` in the workflows if a workflow ever runs those suites.
2. `test_xs_scope.py`: stop depending on the newest dump. Options, pick with evidence: pin a
   dump committed under the tests folder (check its size first - do not commit megabytes), or
   pass `--dump` to a known-good dump, or merge the function lists of all dumps present. Keep
   the checker's CLI behaviour for the owner's interactive use; change the test, not the tool,
   unless the tool's author (the `rm-skill-library` session) is consulted through the owner.
3. mtime-based twin checks: replace with a content check (compile the `.xml` in memory with
   `xmbc.py`'s functions and compare to the `.xmb`) or reuse `mod-deploy-check`'s audit.
   Measure the runtime; if a content check is slow, keep it `local` or cache by file hash.
4. The two mapsim failures (section 2.2), each with the evidence in the commit message.
5. Anything else from the FIX rows.

Every commit: `git add <the files you changed>`, a message that names the test, the verdict
and the reason. Run the suite you touched before and after. Push `Pirate-rework` after each
commit, or after each group, and read the resulting CI run in the browser - that is your
integration test, and it is free.

### Phase E - new tests that make sense

Rules for proposals:

- A proposed test must name the regression it would catch, ideally a GitHub issue number or a
  commit hash of a past fix. "It would be good to test X" without a past failure is not a
  proposal.
- Prefer tests that run in under a second and need no game data outside the repository.
- Map scripts are "literal dirty working code" by the owner's explicit choice; do not propose
  tests that force abstraction on them. Test the outputs and invariants (ids, order, CRLF,
  twin content, string ids exist, protos referenced exist in `protomods.xml` or the vanilla
  list), not the style.
- Write the proposals as a table (name, what it asserts, which regression, cost). Write the
  top five only after the owner approves the list, unless a proposal is a one-line extension of
  an existing test class - then just do it and say so.

### Phase F - CI

Goal: every workflow green on `Pirate-rework` without a single real regression hidden. If a
workflow is red for a reason that is a real regression, the fix is in the code and goes to the
owner as a decision if it is more than a few lines. Also check: does every workflow still run
something that matters? A workflow that validates a file nobody edits any more is noise -
propose, do not delete.

### Phase G - the report

`docs/briefs/2026-09-23-test-suite-audit-report.md`, sections in this order, tables not prose:

1. Baseline (Phase A tables) and the CI history (Phase B.1).
2. The issues table (Phase B.3) and the uncovered-regression list (Phase B.4).
3. The classification table (Phase C).
4. What was changed - commit hash, one line each, and the CI result after.
5. Proposals needing the owner's decision - deletions, new tests, workflow changes - as a
   numbered list he can answer with "1 yes, 2 no, 3 later".
6. What you could not determine and why, in one line each.

Commit the report on `Pirate-rework` like everything else.

## 4. Budget and manners

- Ask questions as a numbered list at the end of a phase, never as a blocker in the middle.
  Assume, state the assumption, continue.
- If something cannot be fixed from your seat (needs the game, needs an in-game run, needs the
  owner's GitHub click), write one sentence and the single cheapest decisive check, then move
  on. Research spirals are failures here.
- Copy names exactly (test ids, workflow names, issue titles, proto names). Never invent a
  file, function or flag - if you did not see it, say "not found".
- Do not rewrite passing tests for style. Do not reformat files. Diffs must be the change and
  nothing else.
- When done, the last message to the owner is: the report path, the list of commits, the
  numbered decisions. Nothing else.
