# Test-suite audit report - 2026-09-23

Brief: `docs/briefs/2026-09-23-test-suite-audit.md`. Running notes; every phase appends.
Branch `Pirate-rework`, baseline commit `749da70b`. Python 3.12.10, pytest 9.0.3, Windows.

## 1. Baseline

### 1.1 Test configuration

| Item | Found |
|---|---|
| pytest config | `pytest.ini` (repo root) only; no `pyproject.toml` / `setup.cfg` / `tox.ini` |
| registered markers | `slow` ("full-map mapcheck runs (may need the game install; skip with -m "not slow")") |
| `conftest.py` | none anywhere in the repository |
| markers in use | `parametrize` x36, `skipif` x4, `slow` x3 (`test_gunsocket_lock.py::TestTrigtempOracle`, `test_profile.py` x2) |

### 1.2 Suites

Runtime = wall clock of `python -m pytest <path> -q -rA --durations=15` on 2026-09-23, this machine
(game installed, profile folders present).

| Suite | Path | Tests | Result (local) | Runtime | Runs in CI |
|---|---|---|---|---|---|
| mapsim | `scripts/mapsim/tests/` (9 files) | 189 | 187 passed, **2 failed** | 62 s | yes - `mapsim.yml` (only on pushes touching `scripts/mapsim/**` or the workflow) |
| mapcheck | `scripts/mapcheck/tests/` (13 files) | 392 | 379 passed, **13 failed** | 57 s | **no** |
| refdata | `scripts/refdata/tests/` | 21 | 20 passed, **1 failed** | 1 s | no |
| rm tools | `scripts/tools/tests/test_rm_tools.py` | 9 | 9 passed | <1 s | no |
| agent setup | `scripts/tools/test_agent_setup.py` | 2 | 2 passed | <1 s | no |
| public skill sync | `scripts/tools/test_public_skill_sync.py` | 8 | 8 passed | <1 s | no |
| skill layout | `scripts/tools/test_skill_layout.py` | 7 | 7 passed | <1 s | no |
| aoe3de-reference | `.claude/skills/aoe3de-reference/tests/` | 2 | 2 passed | <1 s | no |
| grouping-centering | `.claude/skills/grouping-centering/tests/` | 12 | 12 passed | 1 s | no |
| rm-trigger-testing | `.claude/skills/rm-trigger-testing/tests/` | 9 | 9 passed | <1 s | no |
| skill-library-audit | `.claude/skills/skill-library-audit/tests/` | 21 | 21 passed | <1 s | no |
| census (sandbox) | `sandbox/census/tests/test_gamewin.py` | 14 | 14 passed | <1 s | no |
| **total pytest** | | **686** | 670 passed, 16 failed, 0 skipped | ~2 min | 189 of 686 |

Non-pytest validators run by workflows (root scripts; run locally with `PYTHONIOENCODING=utf-8`,
because the emoji output crashes the Windows cp1250 console - irrelevant on ubuntu CI):

| Workflow file | GitHub name / job | Command | Trigger | Local result | Runtime |
|---|---|---|---|---|---|
| `mapsim.yml` | Mapsim Tests / Mapsim Test Suite | `python -m pytest scripts/mapsim/tests -q` | push, paths `scripts/mapsim/**`, the workflow | 2 failed (above) | 62 s |
| `proto.yml` | Proto Validation / Validating Proto | `python _proto.py` (dup name / id / dbid in `data/protomods.xml`) | every push | pass | 0.2 s |
| `stringtables.yml` | StringTable Validation / Validating StringTables | `python _stringtables.py` (locid / dup / empty in `data/strings/*/stringmods.xml`; only `english/` has one) | every push | pass | 0.2 s |
| `techtree.yml` | TechTree Validation / Validating TechTree | `python _techtree.py` (dup name / dbid in `data/techtreemods.xml`) | every push | pass | 0.2 s |
| `xml_malformations.yml` | XML Malformation Check / Parsing XML files | `python _all_xmls.py` (every `.xml/.tactics/.material/.dmg` parses) | every push | pass | 2.2 s |

### 1.3 Slowest tests

| Suite | Test | Time |
|---|---|---|
| mapcheck | `test_universal.py::TestGoldenSmoke::test_independence_war_digest[8-8]` | 12.07 s |
| mapsim | `test_render.py::test_render_real_scene_smoke[sc1]` | 10.43 s |
| mapsim | `test_checks.py::TestRealSceneSmoke::test_no_hard_failures_on_real_map[sc4]` | 6.50 s |
| mapcheck | `test_gunsocket_lock.py::TestModel::test_every_event_sequence_up_to_length_5[3-True]` / `[3-False]` | 5.98 / 5.95 s |
| mapsim | `test_checks.py::TestRealSceneSmoke::...[sc3]` / `[sc2]` / `[sc5]` | 5.97 / 5.11 / 4.64 s |
| mapcheck | `test_profile.py::TestPilotProfiles::test_civilwar_expectations_hold` | 5.55 s |
| mapcheck | `test_gunsocket_lock.py::TestModel::...[2-True]` / `[2-False]` | 4.34 / 4.22 s |
| mapsim | `test_field.py::TestRealScene::test_feasibility_check_runs_clean_of_errors` | 4.29 s |
| mapsim | `test_render.py::test_render_real_scene_smoke[sc0]` | 4.05 s |
| mapsim | `test_terrain_state.py::TestGoldenGrids::test_fixture_grid_matches_golden[8-8]` | 4.01 s |
| mapcheck | `test_universal.py::TestGoldenSmoke::test_independence_war_digest[2-2]` | 3.91 s |
| mapsim | `test_checks.py::TestRealSceneSmoke::...[sc1]` / `[sc0]` | 3.31 / 2.54 s |
| mapsim | `test_field.py::TestTerrainGrid::test_channel_carves_between_islands` (setup) | 2.14 s |

Every other suite's slowest test is under 1.1 s.

### 1.4 Failing and skipped tests (local run, 2026-09-23)

No test skipped locally (all game/profile paths exist here). On a machine without them the four
`skipif` guards fire (`test_extract.py` x3, `test_xs_scope.py` module) - see 1.5.

| Test | Assertion message (first line) | Cause class | Evidence |
|---|---|---|---|
| `scripts/mapsim/tests/test_geometry.py::TestBoxes::test_malformed_box_raises` | `Failed: DID NOT RAISE <class 'ValueError'>` | stale-baseline (contract changed on purpose) | `5d130aa5` (2026-08-10) message: "dist_range_to_box now NORMALISES corner order instead of rejecting z0>z1 -- the engine forms the box from either corner order (zpverseilles:391 authors z0>z1)" |
| `scripts/mapsim/tests/test_scene.py::TestSnapshot::test_snapshot_hash_matches_recorded` | `vendored snapshot changed - re-baseline the scene (plan section 1.3)` recorded `d1511d08...`, actual `81f780a1...` | stale-baseline | `e948b4f5` (2026-09-11) moved every mod string id +200000 and rewrote `scripts/mapsim/tests/fixtures/independence_war.snapshot.xs` (6 lines) without updating `snapshot.sha256` in `independence_war.scene.json` |
| `scripts/refdata/tests/test_catalogs.py::TestGroupingFootprint::test_pirate_village_footprint` | `assert (-8.2 < -9.7797)` | stale-baseline | test pins numbers read from `game/randmaps/groupings/pirate_village05.xml` on 2026-08-10; the file was re-exported in `0f8639db` (2026-09-11, "pirate village groupings") |
| `scripts/mapcheck/tests/test_gunsocket_lock.py::TestTrigtempOracle::test_rules_use_the_same_socket_id_as_the_ai_family[NW/NE/SW/SE]` (4) | `ASGunNW_ON_Plr1 not in trigtemp` | newest-file | reads the profile `Trigger/trigtemp.xs`, which the game rewrites on every generation; today's (2026-09-23 10:20) is from another map, and the mtime guard (`trigtemp older than the map -> skip`) cannot tell |
| `scripts/mapcheck/tests/test_jones_captain.py::TestProtos::test_flagship_is_a_black_pearl_on_the_ostinder_hull_without_pirate_training` | `assert '<train ' not in ...<train row="0" page="1" column="1">zpPirateGunboat</train>` | stale-baseline | `31344a7d` (2026-09-11): "zpPirateGunboat ... trained on the JPJ flagships (AllowTrainingOnWater + train entry, Trinidad shape)" |
| `scripts/mapcheck/tests/test_jones_captain.py::TestProtos::test_serapis_follows_the_prau_b_pattern` | same `<train ` assertion | stale-baseline | `31344a7d`, same |
| `scripts/mapcheck/tests/test_jones_captain.py::TestSideRecords::test_voice_lines_are_the_american_frigate[zpSPCBonhommeRichard/zpSPCSerapis]` (2) | `'SPCAmericanSelect' == 'DEAmericanFrigateSelect'` | stale-baseline | `31344a7d`: "JPJ flagships voiced with the campaign SPCAmerican crew sets" (`sound/zpspcbonhommerichard_snds.xml`, `sound/zpspcserapis_snds.xml`) |
| `scripts/mapcheck/tests/test_jones_captain.py::TestPlacement::test_protos_sit_above_the_test_section_in_id_order` | `the new protos must be the last real units before the test section` (found `zpPropWaterTowerFlatten` 21163 after) | other (assertion expires by design) | the house rule puts every NEW record last, so "Jones is last" was only true until the next record |
| `scripts/mapcheck/tests/test_jones_captain.py::TestPlacement::test_techs_sit_last_before_the_test_techs` | `nothing after the new techs but the test marker` (found `DEChampionInuit`) | other (assertion expires by design) | same |
| `scripts/mapcheck/tests/test_jones_captain.py::TestPlacement::test_side_records_are_last` | found `<zpconsulateparliamentcromwell portraitfilename` after Jones | other (assertion expires by design) | same (Parliament records added 2026-09-18) |
| `scripts/mapcheck/tests/test_roster.py::test_static_tier[zpcoldwar]` | `S4: unknown proto 'Walrus'`, `'deFishingHole'` | stale-baseline (vanilla snapshot) | `scripts/source/protoy.xml` is the 2025-10-10 snapshot (`51d5e044`); with `MAPCHECK_LIVE_PROTO=1` (live Data.bar names) both maps pass |
| `scripts/mapcheck/tests/test_roster.py::test_static_tier[zpunknown]` | `S4: unknown proto 'Walrus'`, `'deFeralSheep'`, `'deRMWoodCabin'` | stale-baseline (vanilla snapshot) | same |

Not failing today but known to fail on the same cause: `scripts/mapcheck/tests/test_xs_scope.py`
(newest-file: 18 maps failed on 2026-09-23 when an Istanbul dump became newest, per the brief;
passes right now because the newest dump is again one that includes `mercenaries.xs`).

### 1.5 Machine dependencies (grep of every test file)

Patterns: `Program Files`, `76561198347905238`, `st_mtime`, `getmtime`, `.dmp.txt`, `Steam`, `RandMaps`,
`APPDATA`, `USERPROFILE`, `Path.home`, `expanduser`. `.claude/skills/*/tests`, `sandbox/census/tests`,
`scripts/tools/**` have no hit.

| File:line | Dependency | Guarded today? |
|---|---|---|
| `scripts/mapsim/tests/test_extract.py:19` | `GAME` = Steam `Game\RandMaps` (vanilla `amazonia.xs`, `Cascade Range.xs`, `000_Elbe.xs`) | yes, `skipif` per test |
| `scripts/mapcheck/tests/test_xs_scope.py:14-16` | profile folder, **newest** `Age3DERM*.dmp.txt` by `st_mtime` | only "no dump at all" -> skip; newest-file not guarded |
| `scripts/mapcheck/tests/test_gunsocket_lock.py:36` | Steam `000_istanbul.xs` (byte identity with `randmaps/zpistanbulb.xs`) | yes, skip |
| `scripts/mapcheck/tests/test_gunsocket_lock.py:38,216` | profile `Trigger/trigtemp.xs`, mtime vs map | partial (mtime), fails when trigtemp is from another map |
| `scripts/mapcheck/tests/test_jones_captain.py:27` | Steam `000_independence_war.xs` | yes, skip (line 320) |
| `scripts/mapcheck/tests/test_jones_captain.py:326` | XMB twin fresh by `getmtime` | no |
| `scripts/mapcheck/tests/test_london_roles.py:18` | Steam `00000_zplondon.xs` byte identity | to be counted in Phase C |
| `scripts/mapcheck/tests/test_london_roles.py:793,847` | XMB twin fresh by `st_mtime` | no |
| `scripts/mapcheck/tests/test_london_revolt.py:16` | Steam `Game\RandMaps` | to be counted in Phase C |
| `scripts/mapcheck/tests/test_london_revolt.py:176` | XMB twin fresh by `st_mtime` | no |
| `scripts/mapcheck/tests/test_parliament_natives.py:17,382` | Steam `Game\RandMaps` (asserts no `*.mods.xml` there) | no (on a machine without the folder the glob is empty -> passes vacuously) |
| `scripts/mapcheck/tests/test_parliament_natives.py:435,440` | XMB twin fresh by `st_mtime` (incl. 14 language tables vs English) | no |
| `scripts/refdata/tests/test_catalogs.py:100` | literal `c:/users/rosti/...` string | not a dependency - the test asserts such a path never resolves |
| `scripts/refdata/catalogs.py` (code, not test) | `_install_groupings_dir()` = Steam groupings; `_live_proto_path()` = Data.bar under `MAPCHECK_LIVE_PROTO=1` | code-level fallback; results differ per machine |

### 1.6 CI history (Phase B.1, read 2026-09-23 on github.com)

Access note: the built-in browser is not signed in to GitHub; job logs are sign-in / admin only
(`api.github.com/.../jobs/<id>/logs` -> 403 "Must have admin rights"). Run states, dates and commits
come from the public Actions pages; the first failing assertion of each red run was reproduced
locally from `git archive <sha>` (section 1.7), not read from the log.

| Workflow | Branch | Runs shown | Result | First run / first red |
|---|---|---|---|---|
| Mapsim Tests | Pirate-rework | #1 `8720cb7` 2026-08-01, #2 `0670970` 2026-08-03, #20 `22f25ec` 2026-09-11, #27 `4b691f1` 2026-09-23 (all 4 on this branch) | **failed x4** | red from run #1, the commit that added the workflow and the tests |
| Mapsim Tests | all branches | #1-#28 (pre-BalticDLC, Christmas-Release, istanbul_ai, v7.2, treasureship-*, tower-of-london, Pirate-rework-to-main) | **failed x28** - it has never passed | #1 `8720cb7` |
| Mapsim Tests | main | none - `mapsim.yml` does not exist on `main` | - | - |
| Proto Validation | Pirate-rework | #1136 `6089011` 2026-09-15 ... #1197 `4b691f1` 2026-09-23 (last 10) | success x10 | - |
| StringTable Validation | Pirate-rework | same 10 commits | success x10 | - |
| TechTree Validation | Pirate-rework | same 10 commits | success x10 | - |
| XML Malformation Check | Pirate-rework | same 10 commits | success x10 | - |
| Proto / StringTable / TechTree / XML Malformation | main | #831 `ad755c9` 2025-10-09 (the only run the branch filter shows; `main` has had no push since) | success | - |

Other checks on PR #33 (head `4b691f1`; local `Pirate-rework` is 3 commits ahead: `f03aeee9`, `2f318d88`, `749da70b`):

| Check | State |
|---|---|
| XML Malformation Check / Proto Validation / StringTable Validation / TechTree Validation (runs from both the `Pirate-rework` and the `inuit-harpooner` push of the same commit) | succeeded (8 jobs) |
| Mapsim Tests / Mapsim Test Suite | failed |
| Cursor / Cursor Bugbot | neutral - "Bugbot couldn't run - usage limit reached" |
| every job | warning "Node.js 20 is deprecated ... actions/checkout@v4, actions/setup-python@v4" |

### 1.7 First failure of the red check, reproduced

`git archive <sha> scripts/mapsim` into the scratchpad, `python -m pytest scripts/mapsim/tests -q`:

| Commit (run) | Local result on the extract | Why CI was red anyway |
|---|---|---|
| `8720cb7` (Mapsim #1, 2026-08-01) | 164 passed | `TestSnapshot::test_snapshot_hash_matches_recorded`: the recorded sha256 `d1511d08...` is the hash of the **CRLF** file; git stores the snapshot LF (blob hash `948baab2...`) and, before `.gitattributes` existed, the ubuntu runner checked it out LF -> mismatch. Red on CI from the first run, green on Windows. |
| `0670970` (Mapsim #2) | 164 passed | same |
| `22f25ec` (Mapsim #20, 2026-09-11) | extract incomplete (tests read `scripts/source`, not extracted) | from `5d130aa5` on also `TestBoxes::test_malformed_box_raises`; from `e948b4f5` the snapshot content itself changed (LF blob `88261599...`, CRLF `81f780a1...`) |
| `4b691f1` (Mapsim #27, 2026-09-23) | = today's local run: the same 2 failures | `.gitattributes` (`12dab92c`, 2026-09-17) now gives `*.xs` `eol=crlf`, so CI hashes the CRLF file `81f780a1...` like Windows; the two failures are now the same everywhere |

So the Mapsim check went red for a line-ending reason on day one and stayed red for two real
stale baselines added later (`5d130aa5`, `e948b4f5`). Nobody could see the later ones in CI
because the check was already red.

## 2. GitHub issues (Phase B.3)

`api.github.com/repos/rostislavpeska/age-of-pirates/issues?state=all` returns 33 numbers; 31 are
pull requests. The two issues:

| # | Title | State | Created | Closed | Labels | Summary (incl. comments) | Test today? |
|---|---|---|---|---|---|---|---|
| 31 | Mod doesn't work properly. | closed | 2025-03-29 | 2025-03-29 | - | A user installing from a GitHub checkout (branches Christmas Release, Pirate Rework, TransformUnitBugBackup; game 100.15.3007.0, later updated) sees new models not appearing (Tsar Cannon), an AI xml error on Australia, and the Penal Colony big button doing nothing. Owner: install from the portal, GitHub is internal; thinotmandresy: dev branches deliberately exclude files. No root cause stated. | **Models not appearing on a git checkout = the LF-animfile failure mode** (AGENTS.md rule 1): the art XML was committed LF-normalised and a checkout without CRLF conversion leaves it LF, which the engine ignores. Not covered by any test or workflow today; could be covered (P1 in section 5). The AI error and the Penal Colony button: not testable offline (need the game). |
| 10 | Trigger rework | closed | 2023-05-29 | 2023-06-15 | enhancement | Design goal: move trigger logic out of maps into the mod so scenario designers insert a few triggers. No comments. | Not a regression; not a test subject. |

PRs with test/CI relevance (no bodies, no comments): #19 "Added xml and stringtable validation
workflow", #20 "Workflow update", #21 "Fixed validation logic error" (all 2024-04-30), #28 "Updated
workflows" (2024-09-03) - the origin of the four validator workflows. #33 (open) carries one Cursor
Bugbot summary comment; Bugbot's check is neutral (usage limit).

### 2.1 Regressions the current suites would not catch (Phase B.4)

The issue tracker is thin, so the git history is the main source. Past regressions, the fix
commit, and whether any test or workflow would catch a repeat today:

| Regression | Fix / evidence | Caught today? |
|---|---|---|
| LF-only art XML silently ignored, model never renders (issue #31; Tower of London "ten restarts"; ostinder materials) | `5b98edc1`, `29c8a064`, `12dab92c`, `b7cf6b00` "CRLF restored on the ostinder materials" | **no** - `check_art_eol.py` exists but no test or workflow runs it, and nothing asserts that `.gitattributes` covers every runtime extension |
| XMB twin not rebuilt -> the game loads the old `.xmb` | AGENTS.md rule 4; `mod-deploy-check` exists for it | only by **mtime** inside a few mapcheck tests (London, Parliament, Jones), none in CI - by content since `922b6c35`; all 27 twins: proposal E2 |
| Language string twins stale ("ten ids missing from every non-English player's game", 2026-09-17) | `scripts/tools/stringsync.py` audit; `prezip_check.py` calls it | **no** test, no workflow |
| Mod string ids colliding with the DLC's 300000 row | `e948b4f5` | **no** - `_stringtables.py` checks format / duplicates / empties only |
| DLC-only `tacticdisplay` entries crash the retail build (the Capitol crash) | `2451aa57` | **no** |
| A typo'd reference in a tech effect (`Spawnprivateer`) | `215ed4f1` | **no** in CI; `xmlcheck.py` checks proto references but needs the archive index (24 183 errors with `--no-archive`) |
| Merge dropped every `zpNatInuitHarpooner` effect | `aug7` memory, `test_inuit_harpooner.py` | yes, locally (mapcheck, not in CI) |
| A bad splice deleted two tests (`c5f15253`) | `5e8adb17` | no (a test file can lose tests silently) |
| XS reserved word used as an identifier -> "Random Map failed to load" (2026-09-17, zplondon `cityBlock(string label = "")`) | memory "XS reserved words" | **no** - verified: `xs_scope_check.py` skips keywords where they are used but never flags a declaration named with one (proposal E6) |
| Test self-bug: `chr(92)` join written inside a string, the regex matched nothing | `749da70b` | n/a - shows why tests must be run once red before trusting them green |

## 3. Classification (Phase C)

Method: every class read; machine-bound tests found by running all suites under a CI simulation
(scratchpad `sim_ci.py`: every path under the Steam install candidates, the LOCALAPPDATA mapcheck
cache and the profile folder except `mods/` raises FileNotFoundError). Simulation result:
633 passed, 23 failed, 30 skipped - the 16 known failures minus the 4 trigtemp ones (now skipped),
plus 1 mapsim and 10 mapcheck tests that only fail without the owner's machine, plus 30 skips that
never show locally.

Where a class mixes portable and machine-bound methods, the method is named.

| Suite / file / class | Verdict | Reason | Action |
|---|---|---|---|
| mapsim `test_checks.py` TestRegression1PirateHeadlands, TestRegression2PirateVillageMaxDistance, TestRegression3HarbourSockets | KEEP | the three historical regressions, deterministic | - |
| mapsim `test_checks.py` TestVerdictTaxonomy, TestSceneLevelChecks, TestRealSceneSmoke | KEEP | deterministic; RealSceneSmoke is 28 s of the 62 s | - |
| mapsim `test_extract.py` TestHazardMicrocases, TestGoldenGate | KEEP | deterministic extractor gates | - |
| mapsim `test_extract.py` TestBiasGuard | QUARANTINE | reads vanilla `amazonia.xs`, `Cascade Range.xs`, `000_Elbe.xs` from the Steam install; already `skipif` per test | mark `local("steam")` |
| mapsim `test_field.py` all 6 classes | KEEP | analytic + real-scene field runs, repo-only | - |
| mapsim `test_geometry.py` TestBoxes | FIX | `test_malformed_box_raises` asserts the pre-`5d130aa5` contract (reject z0>z1); the code now normalises on purpose (the engine accepts either corner order) | assert the normalisation instead |
| mapsim `test_geometry.py` other 8 classes | KEEP | pure geometry | - |
| mapsim `test_gsolve.py` TestRingSampleOrder, TestNominalRoll, TestTortugaInArea | KEEP | repo-only (Tortuga passes in the simulation) | - |
| mapsim `test_gsolve.py` TestWWCanyonScatter | QUARANTINE | the Sufi mosque groupings are vanilla, read from the Steam install; without them `test_mosques_placed_and_spread` fails ("solved villages must register their sockets") and `test_min_distance_ring_honored` passes vacuously - **a third red Mapsim test on CI, hidden until the other two are fixed** | mark class `local("steam")` |
| mapsim `test_render.py` | KEEP | guarded by `importorskip("matplotlib")`; CI installs only pytest, so CI never runs it (proposal) | - |
| mapsim `test_scene.py` TestSnapshot | FIX | `test_snapshot_hash_matches_recorded`: hash recorded on a CRLF checkout (red on CI from run #1), and the content changed in `e948b4f5` (string ids +200000) | hash the LF-normalised bytes, re-baseline to the `e948b4f5` content |
| mapsim `test_scene.py` other 8 classes | KEEP | curated golden scene | - |
| mapsim `test_terrain_state.py` all 4 classes | KEEP | incl. the byte-for-byte golden grids | - |
| mapsim `test_units.py` all 5 classes | KEEP | known values + invariants | - |
| refdata `test_catalogs.py` TestProto, TestGrouping, TestWater, TestKindDispatch | KEEP | repo snapshot + repo files | - |
| refdata `test_catalogs.py` TestGroupingFootprint | FIX | `test_pirate_village_footprint` pins numbers of an art file the owner re-exports (`0f8639db`); the rule it guards (footprint = unit bounds, not the header canvas) does not depend on that file | pin the rule on a synthetic grouping written to `tmp_path` |
| mapcheck `test_gunsocket_lock.py` TestStatic, TestModel | KEEP | text + exhaustive model, repo-only | - |
| mapcheck `test_gunsocket_lock.py` TestTrigtempOracle | QUARANTINE + FIX | profile `Trigger/trigtemp.xs` is rewritten by every generation; the mtime guard lets another map's trigtemp through and all 4 fail | mark `local("profile")`; skip when the trigtemp holds no `GunSocketLock` rule (generated from another map) |
| mapcheck `test_gunsocket_lock.py` TestDeploy `test_repo_map_is_one_to_one_with_the_game_root_copy` | QUARANTINE | Steam `000_istanbul.xs` twin; already skips | mark `local("steam")` |
| mapcheck `test_gunsocket_lock.py` TestDeploy `test_triggerdata_untouched` | PROPOSE-DELETE | asserts `git status --short -- data/trigger` is empty: tests the shared working tree, not the repository - fails whenever any session has an uncommitted trigger edit, passes vacuously on every clean checkout | decision in section 5 |
| mapcheck `test_gunsocket_lock_harness.py` both classes | KEEP | tests of the tests (mutants must fail) | - |
| mapcheck `test_inuit_harpooner.py` both classes | KEEP | guards the Aug-7 merge regression | - |
| mapcheck `test_jones_captain.py` TestProtos | FIX | the `<train ` absence asserts predate `31344a7d` (Pirate Gunboat trained on the flagships) | assert the new contract |
| mapcheck `test_jones_captain.py` TestSideRecords | FIX | `test_voice_lines_are_the_american_frigate` predates `31344a7d` (SPCAmerican crew sets) | assert the SPCAmerican sets |
| mapcheck `test_jones_captain.py` TestPlacement `test_protos_sit_above_...`, `test_techs_sit_last_...` | FIX | "Jones is LAST" expires by design the moment the next record is appended (house rule); the durable invariant is "above the TEST section, only later (higher id / dbid) records after it" | assert that |
| mapcheck `test_jones_captain.py` TestPlacement `test_side_records_are_last` | PROPOSE-DELETE | the same expired "last" for politicianmods / abilitymods / randomnamemods / civmods, whose records carry no id, so there is no durable order to assert; their content is TestSideRecords' | decision 2 |
| mapcheck `test_jones_captain.py` TestTechs, TestSettlementTraining | KEEP | repo data | - |
| mapcheck `test_jones_captain.py` TestMapAndDeploy `test_root_map_mirrors_repo` | QUARANTINE | Steam `000_independence_war.xs`; already skips | mark `local("steam")` |
| mapcheck `test_jones_captain.py` TestMapAndDeploy `test_twin_fresh` (7) | FIX | XMB freshness by mtime | content comparison |
| mapcheck `test_london_revolt.py` TestStartingTechsByTeam, TestBigButtonsGreyed, TestLondonExtension, TestAICommonwealthGate | KEEP | repo data + map text | - |
| mapcheck `test_london_revolt.py` TestMapMods `test_twins_built_and_twin_identical` | FIX + QUARANTINE (tail) | mtime twins; the last line reads the Steam twin (fails off-machine) | content twins; the Steam comparison through a skip-if-absent fixture after the repo checks |
| mapcheck `test_london_roles.py` TestHelper, TestLandmarkCoin, TestRoles, TestSeats, TestStripSeats, TestWalls, TestGateOrder, TestCountryside, TestVictory, TestTowerOwnership, TestMapInfo, TestNewEnglandGroupings | KEEP | map text + repo data | - |
| mapcheck `test_london_roles.py` TestKeepGuards | FIX + QUARANTINE (tail) | mtime twin (nuggetmods); Steam twin as the last line | as TestMapMods |
| mapcheck `test_london_roles.py` TestBridgeOwnership | FIX + QUARANTINE | `test_venice_tower_family` mtime twins; `test_twin_identical_and_crlf` Steam twin | content twins; the CRLF check keeps running everywhere, the Steam part through the fixture |
| mapcheck `test_london_roles.py` TestWaterFlags, TestFish, TestScope | QUARANTINE (tail) | Steam twin as the last assertion (TestScope's CRLF check is portable) | the Steam part through the fixture |
| mapcheck `test_parliament_natives.py` TestProtos, TestTechs, TestSideRecords, TestTeamIronsides, TestArmedMerchantman, TestSovereignOfTheSeas | KEEP | repo data | - |
| mapcheck `test_parliament_natives.py` TestLondon | FIX + QUARANTINE (tail) | `test_twins_are_fresh` mtime (4 data twins + 14 language twins against the English .xml); `test_map_switched_..._root_equals_repo` reads the Steam twin first, so the whole test fails off-machine; the `.mods.xml` root guard passes vacuously off-machine (harmless) | content twins (+ the `stringsync.py` audit for the languages); the Steam comparison moved to the end, through the fixture |
| mapcheck `test_parliament_natives.py` TestFlags, TestCommonwealth, TestExtendedStuart | QUARANTINE (tail) | Steam twin as the last assertion | fixture |
| mapcheck `test_profile.py` TestValidation, TestKnownIssueDemotion, TestOverridePlumbing | KEEP | | - |
| mapcheck `test_profile.py` TestPilotProfiles | KEEP + QUARANTINE (1) | `test_civilwar_expectations_hold` resolves `zp_z_z_zcivilwar2` from the game install; already skips | mark that method `local("steam")` |
| mapcheck `test_roster.py` `test_static_tier` (33 maps) | FIX | 2 maps red on the 2025-10-10 vanilla snapshot `scripts/source/protoy.xml` (Walrus, deFishingHole, deFeralSheep, deRMWoodCabin exist in the live game); the other 31 guard real map bugs | test side: an S4 "unknown proto" that the LIVE game has (when reachable) is snapshot lag, not a map bug. Off-machine it stays red until the snapshot is refreshed - decision in section 5 |
| mapcheck `test_socket_chains.py` | KEEP | the cherry-orchard regression | - |
| mapcheck `test_templates.py` all 4 classes | KEEP | | - |
| mapcheck `test_universal.py` all 5 classes | KEEP | incl. the 16 s golden digest | - |
| mapcheck `test_xs_scope.py` | FIX (+ QUARANTINE of the dump cross-check) | builtins from the **newest** dump by mtime: 18 false failures on 2026-09-23; skipped off-machine. Measured: of a dump's 421 functions + 206 constants the checker needs 19 names - the 12 unprefixed math syscalls (`abs acos asin atan atan2 ceil cos pow round sin sqrt tan`) and the 7 functions of the three vanilla includes every map uses; every other syscall is `rm/xs/tr/ai/kb`-prefixed and every constant `c[A-Z]`, both exempt in the checker | pin the 19 names in the test (runs everywhere, no dump, no masking by the dumped map's own functions); a `local("profile")` test checks the pin against the newest dump that has all three includes |
| tools `test_rm_tools.py`, `test_agent_setup.py`, `test_public_skill_sync.py`, `test_skill_layout.py` | KEEP | tmp fixtures, portable | - |
| skills `aoe3de-reference`, `grouping-centering`, `rm-trigger-testing`, `skill-library-audit` | KEEP | offline fixtures | - |
| sandbox `census/tests/test_gamewin.py` | KEEP | dry-run, inputs faked; never touches the game | - |

No test was found that tests a component that no longer exists; the two PROPOSE-DELETE rows
are the working-tree check and the expired side-record placement check.

## 4. What was changed (Phase D)

Every commit names only its own files (`git add <path>`), was run before and after, and says the
verdict and the reason in its message. Pushed in three groups; CI results read on github.com.

| Commit | Change | Verdict | CI after the push |
|---|---|---|---|
| `e343d6ba` | this report, phases A-C | - | pushed with `6059d1d7` |
| `7954455b` | `local(*needs)` marker in `pytest.ini`; new root `conftest.py` skips a marked test where the Steam install / profile folder is missing; marked TestBiasGuard, TestWWCanyonScatter, TestTrigtempOracle, the two Game-root twin tests, `test_civilwar_expectations_hold`; `mapsim.yml` runs `-m "not local"` and triggers on `conftest.py` / `pytest.ini` | QUARANTINE | pushed with `6059d1d7` |
| `509cadf8` | TestTrigtempOracle skips a trigtemp.xs without Istanbul's `rule _PalaceSUnlock` (generated from another map) | QUARANTINE + FIX | pushed with `6059d1d7` |
| `6059d1d7` | `test_xs_scope.py`: the 19 builtins pinned, no dump read; + UNKNOWN_FN injection (one-line extension of the existing injected-error test); + `local("profile")` cross-check of the pin | FIX | Mapsim #29 **failed** (the two known mapsim failures, not yet fixed); Proto / StringTable / TechTree / XML #1200 success |
| `0719122a` | `steam_twin` fixture: the ten London / Parliament Steam-twin comparisons run after the repo checks and skip where the twin is absent | QUARANTINE (tail) | pushed with `d4172f14` |
| `922b6c35` | `xmb_current` / `language_twins_current` fixtures: every mtime twin assertion (Jones x7, London roles x2, London revolt, Parliament) is now a content comparison / the stringsync audit | FIX | pushed with `d4172f14` |
| `a8774da4` | mapsim TestBoxes: `test_malformed_box_raises` -> `test_reversed_corners_normalise_and_non_finite_raises` (the `5d130aa5` contract) | FIX | pushed with `d4172f14` |
| `d4172f14` | mapsim TestSnapshot: hash of the LF-normalised bytes, re-baselined to the `e948b4f5` content | FIX | **Mapsim #30 success - the first green Mapsim run in the workflow's 30-run history**; Proto / StringTable / TechTree / XML #1201 success; PR #33: all 5 checks green |
| `4f779191` | refdata TestGroupingFootprint: the unit-bounds rule pinned on a fixture grouping in `tmp_path` | FIX | Mapsim not triggered (paths); Proto / StringTable / TechTree / XML #1202 at `b06ff441` success |
| `ee29cc8d` | Jones TestProtos / TestSideRecords: flagships train exactly `zpPirateGunboat` + AllowTrainingOnWater; voices `SPCAmericanSelect` / `SPCAmericanBoatAcknowledge` (the `31344a7d` contract); voice test renamed | FIX | as above |
| `489ba7c6` | Jones TestPlacement: "only later (higher id / dbid) records follow the Jones block", not "Jones is last" (2 of 3 tests; `test_side_records_are_last` untouched - decision 2) | FIX | as above |
| `b06ff441` | roster: an S4 "unknown proto" the live game has is snapshot lag (only where the install is reachable) | FIX | as above |

### 4.1 Result after the changes (2026-09-23, `b06ff441`)

| Run | Before (`749da70b`) | After |
|---|---|---|
| all suites, this machine | 670 passed, 16 failed | 681 passed, 1 failed (`test_side_records_are_last`, decision 2), 4 skipped (trigtemp from another map) |
| all suites, CI simulation (Steam + profile hidden) | 633 passed, 23 failed, 30 skipped | 661 passed, 3 failed (`test_side_records_are_last`; roster `zpcoldwar`, `zpunknown` = snapshot lag, decision 3), 23 skipped |
| `mapsim` as CI runs it (`-m "not local"`) | 2 failed on every run since #1 | 184 passed locally; Mapsim #30 green on GitHub |

Every skip now names its cause: `local (steam): needs <path>`, `local (profile): needs <path>`,
`local (steam): no <twin> - every repo-side assertion before this line passed`, `trigtemp.xs was
generated from another map`, `no lz4 package ...`.

Observed during the final local run: `TestLondon::test_twins_are_fresh` failed once and passed on
the rerun - another session saved `data/civmods.xml` at 10:21:58 and rebuilt its `.xmb` at
10:22:06, and the run hit that eight-second stale window. That is the content check working; the
old mtime check would have passed it too, but only by accident of timestamps.

## 5. Proposals needing the owner's decision

### 5.1 New tests (Phase E)

Measured on today's tree; "passes today" means it would be green if merged now.

| # | Name | Asserts | Regression it would have caught | Cost | Today |
|---|---|---|---|---|---|
| E1 | `test_runtime_xml_is_crlf` | `.gitattributes` gives `eol=crlf` to every runtime extension (`git check-attr` on `*.xml *.material *.lgt *.tactics *.xs`, none marked binary / `-text`), and `scripts/tools/check_art_eol.py` finds 0 LF-only files | issue #31 (models not appearing on a git checkout); Tower of London 10 restarts (`5b98edc1`, `29c8a064`); ostinder materials (`b7cf6b00`) | < 1 s, repo only | passes |
| E2 | `test_every_data_twin_is_current` | every `data/**/*.xml.xmb` with a `.xml` decodes to the same tree (the `xmb_current` fixture over all 27) | AGENTS.md rule 4 (edits inert until rebuilt); today's 8-second window | 0.7 s, stdlib only, CI-capable | passes |
| E3 | `test_language_twins_are_current` | `scripts/tools/stringsync.py` audit exits 0 (all 15 languages) | 2026-09-17: ten ids missing from every non-English player's game | 1.2 s; CI needs `pip install lz4` | passes |
| E4 | `test_mod_string_ids_stay_in_mod_rows` | every `_locid` in the NEW STRINGS block of `english/stringmods.xml` is in 400001-400290 or >= 500001; every REWRITES id <= 300366 | `e948b4f5`: 363 mod ids collided with the DLC's 300000 row (DLC lines showed mod strings) | < 0.1 s | passes (3808 new ids, 1 rewrite) |
| E5 | `test_techtree_references_resolve` | every `TechStatus` target and `<target type="ProtoUnit">` in `techtreemods.xml` exists in the mod, the vanilla snapshot, the live game (when reachable) or the unit-type list; an allowlist like the roster's OPEN_STATIC for triaged cases | `215ed4f1` (the `Spawnprivateer` typo) | 0.4 s | **fails today** - finds real bugs, see decision 17 |
| E6 | `test_no_reserved_word_identifiers` | no variable, parameter or function in `randmaps/*.xs` + `game/randmaps/*.xs` is named with an XS reserved word (`label`, `goto`, `rule`, `group`, ...) | 2026-09-17 zplondon `cityBlock(string label = "")` -> "Random Map: zplondon failed to load", no log, clean mapcheck (memory `xs-reserved-words`) | 1 s (52 maps) | passes |
| E7 | roster over `randmaps/*.xs` too | `test_static_tier` also parametrised over the 19 maps in `randmaps/` (it only globs `game/randmaps/`, 33 maps - London, Paris, Istanbul are not covered) | any S4/S5 map bug in the maps under active work | +1.8 s | fails today on 2 dev maps (decision 18) |
| E8 | `test_protomods_ids_append_only` | after the first mod id of the current sequence (21160), no real unit with a higher id sits above one with a lower id | the house rule "new records at the end" (memory `new-content-placement`) | < 0.2 s | fails today: `zpNatLord` 21182 and `zpNatMercInuitHarpooner` 21192 sit mid-file (decision 19) |

Recommended top five: E1, E2, E3, E4, E6 (all green today, all under 1.2 s, all CI-capable).
E5 is the most valuable once decision 17 is answered. Nothing here was written yet except the
one-line extension noted in commit `6059d1d7` (the UNKNOWN_FN injection).

### 5.2 CI (Phase F)

| Workflow | Runs something that matters? | Status on `Pirate-rework` |
|---|---|---|
| Mapsim Tests | yes - but only on pushes that touch `scripts/mapsim/**` (+ the workflow, `conftest.py`, `pytest.ini`), while the suite also reads `scripts/refdata/`, `scripts/source/`, `game/randmaps/`; matplotlib is not installed, so the 2 render smoke tests never run in CI | green since #30 |
| Proto Validation | yes - duplicate name / id / dbid in `protomods.xml` (edited daily) | green |
| StringTable Validation | partly - checks the English table only; the 14 other languages are `.xmb`-only and unchecked (E3) | green |
| TechTree Validation | yes - duplicate name / dbid in `techtreemods.xml`; references unchecked (E5) | green |
| XML Malformation Check | yes - every `.xml/.tactics/.material/.dmg` parses (2 s) | green |
| (none) | the mapcheck, refdata, tools, skills and census suites (497 tests) run in no workflow | - |

Every job warns "Node.js 20 is deprecated ... actions/checkout@v4, actions/setup-python@v4" and
"ubuntu-latest will migrate to Ubuntu 26 beginning October 19, 2026". No workflow validates a file
nobody edits; none is noise.

### 5.3 Decisions

Answer as "1 yes, 2 no, 3 later".

1. Delete `test_gunsocket_lock.py::TestDeploy::test_triggerdata_untouched` - it asserts `git status` of `data/trigger` is clean, i.e. it tests the shared working tree, not the repository (fails whenever any session has an uncommitted trigger edit, vacuous on every clean checkout).
2. Delete `test_jones_captain.py::TestPlacement::test_side_records_are_last` - "Jones is the last record" in politicianmods / abilitymods / randomnamemods / civmods expired by design with the next append, those records have no ids to state a durable order, and their content is covered by TestSideRecords. It is the one failing test left on this machine.
3. Replace the 8 MB vanilla `scripts/source/protoy.xml` (2025-10-10 snapshot, tracked since `51d5e044`, a vanilla file in the repo against AGENTS.md rule 3) by a names-only index refreshed from the live Data.bar, the way `groupings_index.txt` works (small change in `scripts/refdata/catalogs.py`). Makes roster `zpcoldwar` / `zpunknown` green off-machine and shrinks the repo. Alternative: refresh the 8 MB file.
4. One-line fix in `scripts/refdata/catalogs.py::_live_proto_path`: `except Exception` -> also `SystemExit` (bartool.find_game_dir exits without an install, so `mapcheck --live` crashes off-machine instead of returning None as documented).
5. New workflow "Repo Tests": `pip install pytest lz4`, `python -m pytest scripts/mapcheck/tests scripts/refdata/tests scripts/tools .claude/skills/aoe3de-reference/tests .claude/skills/grouping-centering/tests .claude/skills/rm-trigger-testing/tests .claude/skills/skill-library-audit/tests sandbox/census/tests -m "not local"` on every push (~70 s). Green once 2 and 3 are done.
6. `mapsim.yml`: install matplotlib so the render smoke tests run (+~15 s), or keep them skipped in CI.
7. `mapsim.yml`: widen `paths` to `scripts/refdata/**`, `scripts/source/**`, `game/randmaps/**` (what the suite reads), or drop the filter (~60 s per push).
8. All five workflows: `actions/checkout@v4` -> v5, `actions/setup-python@v4` -> v5 (Node 20 deprecation warning on every job).
9. Write E1 (runtime XML CRLF).
10. Write E2 (all data twins by content).
11. Write E3 (language twins; needs lz4 in CI).
12. Write E4 (string id rows).
13. Write E5 (techtree references) with an allowlist for what decision 17 keeps.
14. Write E6 (XS reserved words).
15. Write E7 (roster over `randmaps/`).
16. Write E8 (protomods append-only ids).
17. Data bugs E5 found today, who fixes them: `data/techtreemods.xml:23574` `<effect type="TechStatus" status="unobtainable">"zpPirateLockCitystateTechs</effect>` (stray quote since `1066ebba`, 2025-01-17 - the effect is a no-op); ProtoUnit targets `zzpNatMercVeniceGuard`, `deREVBarbaryMarksmant`, `None`; TechStatus targets defined nowhere (not in the mod, not in the live game): `zpBigButtonResearchDone`, `zpChampionInuit`, `zpGuardHansa`, `zpIndianFriendshipSansculottes`, `zpNatMalteseFishCuisineFrench`, `zpNativeTradeTreatySansculottes`, `zpScientistsActive`, `zpTurnConsulateOnKhmer`, `zpUnknownAllianceInuits`, `zpVeteranHansa`, `zpWarriorSocietyInuit`, `ypBigConsulateJapaneseAllies`, `ypBigSequesterInitial`, `ypBigSequesterRemove`. (`DERevolutionLivonia` / `DERevolutionWarsaw` exist in the live game - snapshot lag only.)
18. `randmaps/performance_test.xs` (no `.xml`, never in the lobby) and `randmaps/zpvenicecit_test.xs` (groupings `EU_Island_Venice_Academia`, `_SanGiorgi`, `_SanMarco`, ... match no file) ship in the zip folder: keep (allowlist them for E7), move out of `randmaps/`, or delete.
19. `zpNatLord` (21182) and `zpNatMercInuitHarpooner` (21192) sit above the Jones block (21160-21162) in `protomods.xml`, against the append rule: move them to the end, or accept and start E8 after them.

## 6. What could not be determined

| Item | Why | Cheapest decisive check |
|---|---|---|
| The literal first failing assertion of Mapsim runs #1-#29 on GitHub | job logs need a signed-in admin (browser not signed in; API 403 "Must have admin rights"); reproduced locally instead (section 1.7) | open run #1's log once while signed in |
| That `rule _PalaceSUnlock` is how the engine names Istanbul's PalaceSUnlock trigger in trigtemp.xs | inferred from the `rule _<name>` form the same test already matches; no Istanbul trigtemp on disk today | next Istanbul generation, then `python -m pytest scripts/mapcheck/tests/test_gunsocket_lock.py -m local` |
| Issue #31's AI xml error and the Penal Colony big button | need the game | - |
| Whether the 14 undefined TechStatus targets (decision 17) break anything in game | the engine ignores an unknown tech name silently, so probably a no-op each | in game, the tech that carries each effect behaves as intended |
