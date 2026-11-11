# Assignment: replace SPC Bourbon with vanilla Bourbon plus an extension

Written 2026-10-26 by Claude at repo commit `629e69c1`, for a Gemini Flash agent. The owner is Rostislav.

## How to use this document

1. **Do exactly one work package (WP) per session, and only the one the owner names.** When it ends, write its
   report (section 9) and STOP. Never start the next WP on your own.
2. **Line numbers are hints from commit `629e69c1`.** Find every record by its name (grep). If a name or a count in
   this document does not match the files, STOP and report it. Do not adapt the plan yourself.
3. **Never write a name you have not copied from a file.** Repo names come from the repo. Vanilla names come from
   the vanilla files you extract in WP1. A name marked `VERIFY` is a guess until WP1 confirms it.
4. **Your outputs go to `docs/briefs/bourbon-rework/`:** the manifest, the analysis and one report per WP. Your
   scratch files go to SCRATCH (section 2), never into the repo.
5. AGENTS.md applies in full. Section 2 repeats the rules this job is most likely to break.

## 1. Goal and background

The mod has its own copy of the Bourbon natives:
- the subciv `SPCBourbon`;
- a hub tech `zpSPCNativeBourbon`;
- zp clones of every Bourbon tech;
- clone units `zpNatRoyalMusketeer` and `zpNatRoyalDragoon`;
- a proxy unit `zpNatRoyalHorsemanBourbonProxy`;
- its own socket `zpSocketSPCBourbon`.

On top of that copy sits the mod's extension:
- The Sun King Era (`zpBourbonExpansion` / `zpBourbonExpansionSPC`);
- Captain of the Guards, which brings D'Artagnan;
- Château Royal, which brings the Summer Palace;
- the small Royal March button.

Two of the clone techs are broken. The owner wants the copy gone. **Every map uses vanilla Bourbon, and only the
extension stays.** The extension switches on per map through a shadow tech, the same pattern as the House of
Stuart (`zpExtendedStuart`), which shipped in 7.3.

**Pattern, Stuart → Bourbon** (Stuart records in `data/techtreemods.xml`):

| Role | Stuart record (line) | Bourbon record |
|---|---|---|
| Extension shadow, top of file | `zpExtendedStuart` (420) | NEW `zpExtendedBourbons` |
| Map variant, SPC expansion | `zpExtendedStuartLondon` (444) | NEW `zpExtendedBourbonsSPC` |
| Big gate, OBTAINABLE | `zpStuartAbilityBig` (38836) | NEW `zpBourbonAbilityBig` |
| Small gate, UNOBTAINABLE | `zpStuartAbilitySmall` (38845) | NEW `zpBourbonAbilitySmall` |
| Tech slot of the small ability | `zpNatStuartHighlandCharge` (38854) | KEEP `zpNatBourbonRoyalMarch` (~20142) |
| Vanilla hub override | `DENativeStuart` (38867) | NEW `DENativeBourbon` (the mod has none today) |
| Vanilla colonialize override | `DENativeStuartColonialize` (38880) | NEW `DENativeBourbonColonialize` |
| Disable shadow | `zpNatStuartBigbuttonDisableShadow` (39134) | KEEP `zpNatBourbonBigbuttonDisableShadow` (20192) |
| Fake-button gate | `zpNatStuartoffShadow` (39127) | KEEP `zpNatBigbuttonDisableShadow` (20185) |

**Other files:**
- `data/abilities/abilitymods.xml`:
  - Stuart lines 102, 117, 118 (Bourbon counterparts: 99 and 98; there is no replace line yet).
  - Summer Palace block, line 239.
- `data/protounitcommandmods.xml`:
  - Stuart: `zpNatStuartHighlandChargeSmall` (881), `zpStuartExpansionFake` (906).
  - Bourbon: `zpNatBourbonRoyalMarchSmall` (483), `zpBourbonExpansionFake` (494),
    `zpNatBourbonRoyalMarcUniversal` (520).
- **Tests to copy:** `scripts/mapcheck/tests/test_parliament_natives.py`, class `TestExtendedStuart`
  (line 539). Fixtures are in the root `conftest.py`: `steam_twin`, `xmb_current` and the `local` marker.

**One real difference from Stuart.** The TradingPost (`data/protomods.xml`) lists `zpNatBourbonRoyalMarchSmall`
statically at line 2609. Stuart's small command is added only by its shadow. That static line must go in WP4. The
static fake button `zpBourbonExpansionFake` (2614) stays; Stuart keeps its fake static too (2617).

## 2. Hard rules for this job

**Files and line endings**
- **Shell:** run everything from the repo root. Commands below are Python, so they work in any shell.
- **SCRATCH:** `python -c "import os,tempfile;p=os.path.join(tempfile.gettempdir(),'aop-bourbon');os.makedirs(p,exist_ok=True);print(p)"`.
  Vanilla extracts, backups and scripts go here.
- **CRLF.** Every file under `art data game randmaps sound` is CRLF, and an LF-only runtime file is silently ignored.
  - Edit these files only with a Python script that reads bytes, replaces bytes and writes bytes.
  - Compute the new content and check it **before** opening the file for writing.
  - After every edit, run `python scripts/tools/check_art_eol.py` (with `--fix` if it complains).
  - Write scripts that contain Windows paths as files, and build the backslash with `chr(92)`.
- **The edit-script pattern (use it for every edit):**
  ```python
  from pathlib import Path
  p = Path("data/techtreemods.xml"); raw = p.read_bytes()
  old = b'...exact bytes, with \r\n line ends...'; new = b'...'
  assert raw.count(old) == 1, raw.count(old)       # stop when not exactly one
  out = raw.replace(old, new)
  assert out.count(b"\r\n") > raw.count(b"\r\n") - 50   # sanity: still CRLF
  p.write_bytes(out)
  ```

**Data files**
- **XMB twins.** A `data/*.xml` edit does nothing until its `.xml.xmb` twin is rebuilt. After you edit one of
  `techtreemods.xml`, `protomods.xml`, `civmods.xml`, `protounitcommandmods.xml`, `nuggetmods.xml`,
  `abilities/abilitymods.xml` or `abilities/powermods.xml`, run:
  `python .claude/skills/aoe3de-bar-archives/scripts/xmbc.py check data/<file>.xml`, then the same with `build`.
  Never create a twin for a file that has none.
- **XML check:** `python .claude/skills/aoe-xml/scripts/xmlcheck.py` after any XML edit.
- **New records** go at the end of real content, directly above the first TEST/commented section. In
  techtreemods that is above `<!--TEST TECHS-->`. Shadow techs are the exception: they sit at the top, directly
  after `zpExtendedStuartLondon`.
- **New dbids.** List the 10 highest `<dbid>` values in techtreemods. Ignore `408187`: it is a known typo on
  `zpAncienRegimeNormalizer`. Take the highest real one + 1 and check that nothing else uses it.

**Approvals and deletions**
- **Deletions (AGENTS.md rule 9).** Removing a record, or an effect or line from a production record, needs the
  owner's yes **on the exact list**. Every WP below names its approval package. Delete nothing that is not on an
  approved package.
- **AI (rule 7).** Only `game/ai/core/aipiraterules.xs` may change. Read `.claude/skills/ai-edit/SKILL.md` first.
  Run `python -m pytest scripts/aitest/tests -q` after the change. Change names only, never what the AI contests.

**Places you must not touch**
- The game process. Never launch, close or click the game; in-game tests are run by the owner.
- `Startup\user.cfg`.
- `data/homecity*.xml`.
- Any Steam-root grouping.
- A `.mods.xml` anywhere outside the repo.

**Groupings and map copies**
- **Profile copies.** The game reads groupings from `<profile>/RandMaps/groupings`; in Python that is
  `Path.cwd().parents[2] / "RandMaps" / "groupings"`. Update a profile copy only with byte-identical repo content,
  and only when it matched the repo copy before your edit.
- **Steam-root map copies** (`<Steam>/AoE3DE/Game/RandMaps/00000_zpparis.xs` and others): read them only; copy to
  them only when the owner names the file.
- **Vanilla files:**
  - Read them with `bartool cat`, or extract them with `bartool extract ... -o <SCRATCH>/vanilla`.
  - Never extract into the repo.
  - Never load a whole data file into your context. Use `record.py` (section 3).

**Git**
- No commit or push unless the owner says "commit". Then make one commit per WP, on the branch the owner names.

**When to stop and report**
- Two failed fix attempts on the same problem.
- Anything this document does not cover.

## 3. Helper scripts (copy them into SCRATCH)

`record.py`: print one record with its line number.

```python
import re, sys
path, kind, name = sys.argv[1:4]          # kind: tech | unit | power | civ | protounitcommand
s = open(path, encoding="utf-8", errors="replace").read()
if kind in ("tech", "unit", "power"):
    pat = r'<%s\b[^>]*\bname="%s"[^>]*>.*?</%s>' % (kind, re.escape(name), kind)
else:
    pat = r'<%s>\s*<name>%s</name>.*?</%s>' % (kind, re.escape(name), kind)
found = list(re.finditer(pat, s, re.S | re.I))
print("%d match(es) for %s %s in %s" % (len(found), kind, name, path))
for m in found:
    print("--- line %d" % (s.count("\n", 0, m.start()) + 1)); print(m.group(0))
```

`census.py`: a read-only reference census. Run it from the repo root as `python <SCRATCH>/census.py <SCRATCH>`.

```python
import json, os, re, sys
from pathlib import Path
REPO, OUT = Path.cwd(), Path(sys.argv[1])
PROFILE_GROUPINGS = REPO.parents[2] / "RandMaps" / "groupings"
STEAM_RANDMAPS = Path(os.environ.get("AOE3DE_GAME", "C:/Program Files (x86)/Steam/steamapps/common/AoE3DE/Game")) / "RandMaps"
DELETE_CANDIDATES = """zpSPCNativeBourbon zpSPCNativeBourbonColonialize zpVeteranBourbon zpGuardBourbon zpNatBourbonReforms
 zpNatBourbonRoyalTax zpNatBourbonChouannerie zpNatBourbonMaisonDuRoi zpNativeTreatyBourbon zpIndianFriendshipBourbon
 zpNativeTradeTreatyBourbon zpUnknownAllianceBourbon zpUnknownAllianceBourbonEnabler zpNatRoyalMusketeer zpNatRoyalDragoon
 zpNatRoyalHorsemanBourbonProxy zpSocketSPCBourbon""".split()
WATCH = """zpNatBourbonRoyalMarch zpNatPowerRoyalMarch zpNatBourbonRoyalMarchSmall zpNatBourbonRoyalMarcUniversal zpBonusBourbon
 zpBourbonExpansion zpBourbonExpansionSPC zpBourbonExpansionFake zpPowerBourbonExpansion zpNatBourbonBigbuttonDisableShadow
 zpNatBigbuttonDisableShadow zpChateauRoyalShadow zpNatChateauRoyal zpNatNightWatch zpBourbonSummerPalace
 zpBourbonSummerPalaceWagon zpSPCDartagnan zpMilitaryCampBuildLimit zpParisSetup zpVerseillesAttackerSetup
 zpVerseillesDefenderSetup zpAncienRegimeAddTechsToEmbassy zpAncienRegimeNormalizer zpRevolutionFranceNE zpNapoleonicEraIcons
 zpNapoleonicEraNames zpNapoleonicEraNamesLegendary zpConsulateRevNapoleon zpSansculotteBrricades zpNativeEmbassyParisReward
 zpAbstractHeroMusketeer DEHCAncienRegime DERevolutionFranceNE""".split()
pats = {n: re.compile(r"(?<![A-Za-z0-9_])(?:cTech|cUnitType|cPower)?%s(?![A-Za-z0-9_])" % n) for n in DELETE_CANDIDATES + WATCH}
pats["SPCBourbon(any case)"] = re.compile(r"spcbourbon", re.I)
ROOTS = [REPO / d for d in ("data", "game", "randmaps", "sound", "art", "scripts", ".claude/skills")]
def files():
    for root in ROOTS:
        for dp, dn, fn in os.walk(root):
            dn[:] = [d for d in dn if d not in (".git", "__pycache__")]
            for f in fn:
                if not f.lower().endswith((".xmb", ".png", ".ddt", ".gr2", ".wav", ".tga", ".pyc")):
                    yield Path(dp) / f
    for extra in (PROFILE_GROUPINGS, STEAM_RANDMAPS):
        if extra.is_dir():
            for f in sorted(extra.glob("*.x*")):
                if f.suffix.lower() in (".xml", ".xs"):
                    yield f
hits = {n: [] for n in pats}
for f in files():
    b = f.read_bytes()
    if b"\0" in b[:4096]:
        continue
    for i, line in enumerate(b.decode("utf-8", "replace").splitlines(), 1):
        for n, p in pats.items():
            if p.search(line):
                hits[n].append({"file": str(f), "line": i, "text": line.strip()[:200]})
(OUT / "census.json").write_text(json.dumps(hits, indent=1), encoding="utf-8")
for n in pats:
    per = {}
    for h in hits[n]:
        per[h["file"]] = per.get(h["file"], 0) + 1
    print("%-40s %4d hits in %3d files" % (n, len(hits[n]), len(per)))
```

## 4. Old → new name map (WP1 confirms every row)

| Old (mod) | New | Status |
|---|---|---|
| civ `SPCBourbon` | `Bourbon` | VERIFY in vanilla `civs.xml` |
| `zpSocketSPCBourbon` | `deSocketBourbon` | the stock AI uses it (`aitechs.xs`); VERIFY in protoy |
| `zpNatRoyalMusketeer` | `deNatRoyalMusketeer` | the mod already overrides it (protomods ~40507) |
| `zpNatRoyalDragoon` | `deNatRoyalDragoon` | the mod already overrides it (~40693) |
| `zpNatRoyalHorsemanBourbonProxy` | find the vanilla Royal Horseman train at the TradingPost | VERIFY; civmods multipleblocktrain maps proxy → `deMercRoyalHorseman` |
| `zpSPCNativeBourbon` | `DENativeBourbon` | VERIFY |
| `zpSPCNativeBourbonColonialize` | `DENativeBourbonColonialize` | VERIFY |
| `zpVeteranBourbon` / `zpGuardBourbon` | `DEVeteranBourbon` / `DEGuardBourbon` | VERIFY; Napoleonic chain, WP2 |
| `zpNatBourbonReforms` / `zpNatBourbonRoyalTax` | `DENatBourbonReforms` / `DENatBourbonRoyalTax` | both zp valuetexts already read these names |
| `zpNatBourbonChouannerie` / `zpNatBourbonMaisonDuRoi` | `DENatBourbon...` | VERIFY |
| `zpNativeTreatyBourbon`, `zpIndianFriendshipBourbon`, `zpNativeTradeTreatyBourbon` | find the vanilla treaty techs for Bourbon (grep Treaty / Friendship and Bourbon) | VERIFY; "none" is a valid answer |
| `zpUnknownAllianceBourbon` / `...Enabler` | `DEUnknownAllianceBourbon` / `DEUnknownAllianceBourbonEnabler` | the Enabler is commented out at `game/randmaps/zpunknown.xs:15448`; VERIFY both |
| `zpNatBourbonRoyalMarch` | KEEP: the tech slot (see section 1) | |
| `zpNatPowerRoyalMarch` | KEEP: the clone power | must equal the vanilla power except its name (WP1 diff) |
| vanilla Royal March ability, command, tech | find in vanilla abilities, protounitcommands and the TradingPost of protoy | VERIFY; the shadow removes them |

## 5. Decisions only the owner makes (list them in your reports; never decide them)

| # | Decision |
|---|---|
| D1 | WP0: are the two broken techs Bourbon Reforms and Taille Royale? |
| D2 | Approve the Ancien Régime / Napoleonic target design from WP2. |
| D3 | The profile-only legacy groupings `Verseilles v2.xml` and `Verseilles v3.xml`: update or leave. |
| D4 | `randmaps/performance_test.xs`: rework like Paris, or another decision. It cannot keep deleted names. |
| D5 | Which Steam-root map copies to refresh: `00000_zpparis.xs`, `00000_zpverseilles.xs`, `0zpunknown.xs`, other copies. |
| D6 | The flag: if vanilla `Bourbon`'s `homecityflagtexture` differs from SPCBourbon's (`objects\flags\natives\bourbon_french`), whether to add a civmods override (Stuart precedent, `data/civmods.xml` ~1341). |
| D7 | Approval packages A (WP4), B (WP5), C (WP6) and D (WP7). |
| D8 | With the vanilla socket, the stock AI also researches Taille Royale on Paris and Versailles. Accept or not. |

## 6. Work packages

### WP0: valuetext hot-fix (only if the owner confirms D1)

In `data/techtreemods.xml`, two zp techs show a tooltip value read from the vanilla tech:
- `zpNatBourbonReforms` (~line 20009): `<valuetext>{techResourceAmount(DENatBourbonReforms)}</valuetext>`
  becomes `...(zpNatBourbonReforms)...`.
- `zpNatBourbonRoyalTax` (~line 20032): `...(DENatBourbonRoyalTax)...` becomes `...(zpNatBourbonRoyalTax)...`.

**Steps:** edit with the edit-script pattern (`count == 1` each), then xmbc `check` and `build` techtreemods, then
all checks (section 8).

**Owner test T0:** research Taille Royale with N buildings. Gold should rise by 35×N, and the tooltip should show
the same amount.

### WP1: inventory and manifest (read-only: no repo file changes except the outputs)

1. **Baseline.** Run the three test suites and record the pass, fail and skip counts plus the failing test names:
   `python -m pytest scripts/mapcheck/tests -q`, `python -m pytest scripts/aitest/tests -q`,
   `python -m pytest scripts/tools/tests -q`. Later WPs compare against this.
2. **Vanilla files.**
   - Run `python .claude/skills/aoe3de-bar-archives/scripts/bartool.py list techtreey protoy civs abilities powers protounitcommands`.
   - Extract the listed `data/` files: `bartool.py extract <paths> -o <SCRATCH>/vanilla --flat`.
3. **Fill section 4.** Use `record.py` and grep on the vanilla files. For every row, record the exact vanilla name,
   or `NONE`. Also record verbatim:
   - the vanilla `DENativeBourbon` and `DENativeBourbonColonialize` records;
   - the vanilla Royal March ability line, power, command and tech;
   - every TradingPost `<command>`, `<tech>` and `<train>` line that names Bourbon or RoyalMarch;
   - the vanilla `Bourbon` civ block.
4. **Hub diffs.**
   - Diff `zpSPCNativeBourbon` against `DENativeBourbon`, and `zpSPCNativeBourbonColonialize` against
     `DENativeBourbonColonialize`, effect by effect.
   - Put every zp-only effect into one of two buckets: (a) concerns a zp clone that will be deleted, or (b) anything
     else, for example `deMercBattleship`, the extension techs, `zpNatPowerRoyalMarch`. Bucket (b) is what WP4 must
     carry over.
5. **Clone diffs.** Diff, field by field and action by action:
   - `zpNatRoyalMusketeer` against `deNatRoyalMusketeer`;
   - `zpNatRoyalDragoon` against `deNatRoyalDragoon`;
   - `zpNatPowerRoyalMarch` against the vanilla power.

   List every difference. Mark each capability the extension needs, for example a Build action for the Military Camp.
6. **Run `census.py`.** Copy `census.json` and the printed summary into the manifest.
7. **Grouping table.** List every grouping that contains `zpSocketSPCBourbon` or `zpNatRoyalMusketeer`, in the repo
   and in the profile copies. The expected repo list is 14 files:

   | Grouping | Old names | Count |
   |---|---|---|
   | `EU_Natives_Block_Bourbon_1`, `_2`, `_3` | socket | 1 each |
   | `Natives_SPCBourbon_01`, `_02`, `_03` | socket | 1 each |
   | `Verseilles_2v2` | socket | 2 |
   | `Verseilles_4v4` | socket | 4 |
   | `Verseilles_Mega`, `Verseilles_Mega2`, `Verseilles_Mega3`, `EU_Verseilles_2v2` | socket | 2 each |
   | `EU_Wall_NE_socketable`, `EU_Wall_SW_socketable` | `zpNatRoyalMusketeer` | 6 each |

   For each file record:
   - the repo count and the profile count;
   - whether the profile copy matches the repo copy with CRLF normalised;
   - whether either new name (`deSocketBourbon`, `deNatRoyalMusketeer`) already occurs (expected: no);
   - the sha256 of the repo file content with CRLF normalised (WP3 needs it).
8. **Maps, AI, data.** From the census, list every line in:
   - `randmaps/zpparis.xs`, `randmaps/zpverseilles.xs`, `game/randmaps/zpunknown.xs`, `randmaps/performance_test.xs`
     and any other map;
   - `game/ai/core/aipiraterules.xs`, especially rule `zpBourbonTechMonitor`, ~6072-6103;
   - every data file.

   Give each line a proposed new text (from section 4), or `DELETE` (goes to package D), or `WP2`
   (Ancien Régime / Napoleonic, not yours to decide).
9. **Deletion candidates.** Write the full list for package D: every record, line and file the rework would delete.
10. **Output:** `docs/briefs/bourbon-rework/manifest.md` (tables) and `manifest.json` (the same data).
    STOP for owner review.

### WP2: Ancien Régime and Napoleonic Era reverse engineering (read-only)

This is the riskiest part of the rework. Analyse; change nothing. Output:
`docs/briefs/bourbon-rework/ancien-regime-analysis.md`.

**Read every record below, in full, with `record.py`:**
- Mod, in `data/techtreemods.xml` unless stated:
  - `DEHCAncienRegime` (override ~21248) and `DERevolutionFranceNE` (override ~20800);
  - `zpAncienRegimeAddTechsToEmbassy` (~21269), `zpAncienRegimeNormalizer` (~20988), `zpBonusBourbon` (~21167);
  - `zpRevolutionFranceNE` (~20717, sets DEHCAncienRegime active ~20796);
  - `zpNapoleonicEraIcons` (~21172), `zpNapoleonicEraNames` (~21227), `zpNapoleonicEraNamesLegendary` (~21292);
  - `zpConsulateRevNapoleon` (~19036), `zpSansculotteBrricades` (~19756);
  - `ImpLegendaryNativesShadow` (~5757; zp names ~5895-5897);
  - `zpMilitaryCampBuildLimit` (~20962, sets DEHCAncienRegime active), `zpBourbonExpansionSPC` (~20920);
  - `zpVeteranBourbon` (~19914), `zpGuardBourbon` (~19951), `DESPCNapoleonicSetup` (~6568; confirm it is unrelated);
  - protos `zpNativeEmbassyParisReward` (~43309) and `NativeEmbassy` (any mod override);
  - the four hero musketeers with unittype `zpAbstractHeroMusketeer` (`data/unittypes.xml:38`; protomods ~42531,
    ~42716, ~42894, ~43067).
- Vanilla, from SCRATCH:
  - `DEHCAncienRegime`, `DERevolutionFranceNE`, `DENatBourbonFencingSchool`, `DEVeteranBourbon`, `DEGuardBourbon`,
    `DENativeBourbon`, `deEUMapUpdateVisuals`;
  - the `NativeEmbassy` proto;
  - every tech or unit those records name (follow one level).
  - Grep vanilla techtreey for `AncienRegime`, `RevolutionFranceNE` and `Napoleon`, and read what you find.
- Usage: grep `randmaps/`, `game/randmaps/` and `game/ai/` for every name above.

**Answer each question with record names and line numbers.** Write `unknown` where the files do not tell you.
- Q1. Vanilla `DEHCAncienRegime`, effect by effect: which effects need Bourbon natives or the Embassy?
- Q2. The mod override of it: what it removes (`mergemode="remove"`) and adds, effect by effect, and what replaces
  each removed effect.
- Q3. `zpAncienRegimeAddTechsToEmbassy`: what it does, its prereqs, who activates it.
- Q4. `zpAncienRegimeNormalizer`: what it does, and what happens on a vanilla map where `zpBonusBourbon` is never
  active.
- Q5. Which maps activate `zpBonusBourbon`, and which of them have an Embassy?
- Q6. Vanilla `DERevolutionFranceNE` against the mod's additions: which units would be buffed twice if both the DE
  effect and the zp effect hit the same unit after the rework?
- Q7. The Sansculotte chain, from `zpConsulateRevNapoleon` through `zpRevolutionFranceNE` to Names, Icons and
  Legendary: prereqs, who can reach it, what it activates.
- Q8. Why `zpMilitaryCampBuildLimit` sets `DEHCAncienRegime` active, and what that does after the rework.
- Q9. Names and icons depend on `zpVeteranBourbon` / `zpGuardBourbon`. What breaks when those become
  `DEVeteranBourbon` / `DEGuardBourbon`, and what the replacement is.
- Q10. Which techs buff `zpAbstractHeroMusketeer` today, and where those buffs must move.
- Q11. `DENatBourbonFencingSchool` is in the vanilla card but not in the mod override. What happens today on Paris?
- Q12. What each Embassy (`NativeEmbassy`, `zpNativeEmbassyParisReward`) shows today in each case of the truth table.

**Truth table, today.** One row per case; columns:
- AR card available;
- AR effects that apply;
- Embassy content;
- Napoleonic Era reachable;
- buffs per unit, as counts;
- names and icons.

| Case | Situation |
|---|---|
| C1 | French on a vanilla map, no Bourbon TP |
| C2 | French on a vanilla map with a vanilla Bourbon TP |
| C3 | Paris royalist |
| C4 | Paris revolutionary |
| C5 | Versailles attacker |
| C6 | Versailles defender |
| C7 | Unknown with the Bourbon alliance |
| C8 | French revolution → Napoleonic France with a Bourbon TP |
| C9 | A non-French civ with a Bourbon TP on Paris |

**Target design on vanilla Bourbon.**
- Rules:
  1. Vanilla maps behave exactly like vanilla.
  2. Paris, Versailles and Unknown keep today's player-visible behaviour.
  3. Prefer removing mod overrides to adding new ones.
  4. Every buff applies exactly once.
  5. No new map-name branches.
- Give a record-level change list: record | file | keep, edit, delete or new | exact change | reason.
- Repeat the truth table as it will be **after** the change.

**Risks and tests.** List each risk with its mitigation. For every truth-table row, give one guard-test spec (what to
assert, in which file) and one owner in-game check.

**Limits:** read-only; at most 60 tool calls. At 50, write what you have plus
`docs/briefs/bourbon-rework/WP2-handoff.md` (what is done, what is left), then STOP.

### WP3: guard tests (test code only; game data untouched)

New file `scripts/mapcheck/tests/test_bourbon_extension.py`.

**Before writing:**
- Copy the helpers from `test_parliament_natives.py`: `REPO`, `_read`, `_techs`, `_c`.
- Read the root `conftest.py` for the `steam_twin`, `xmb_current` and `local` fixtures.
- Check whether `scripts/aitest/tests` already resolves AI constants. If it does, extend it instead of writing G2.

**Rules:**
- No test reads an image.
- No mtime asserts.
- Hash after normalising CRLF.
- Tests that read the owner's machine carry `@pytest.mark.local("profile")` or `local("steam")`.
- A guard that must fail until a later WP is marked `@pytest.mark.xfail(strict=True, reason="until WP<n>")`. When
  that WP is done, the marker is removed. With strict, a passing xfail fails the run.

| Guard | Asserts | xfail until |
|---|---|---|
| G1 | No name from approved package D appears in `data/`, `game/ai/core/`, `randmaps/`, `game/randmaps/` (including groupings), `sound/`. Local tests check the profile groupings and named root copies. | WP7 |
| G2 | Every `cTech\w+` / `cUnitType\w+` in `aipiraterules.xs` resolves to a mod name (techtreemods, protomods, unittypes) or a vanilla name. Vanilla names come from the `scripts/source/` snapshot, plus an explicit `VANILLA_SINCE_SNAPSHOT` list. Names unresolved at baseline go into `KNOWN_UNRESOLVED` with a comment; the test fails only on new ones. | none |
| G3 | Same for every `"cTech…"` string passed as `TechID` in `randmaps/*.xs` and `game/randmaps/*.xs`. | none |
| G4 | For each of the 14 groupings: 0 `zpSocketSPCBourbon` and 0 `zpNatRoyalMusketeer`. Content with `>deSocketBourbon<` → `>zpSocketSPCBourbon<` and `>deNatRoyalMusketeer<` → `>zpNatRoyalMusketeer<` replaced back hashes to the WP1 sha256. That proves nothing else changed. Local: each profile copy equals the repo copy. | WP5 |
| G5 | The protomods TradingPost has no static `zpNatBourbonRoyalMarchSmall` line. The `deNatPowerRoyalMarch` replace line in the `<tradingpost>` section of abilitymods equals the vanilla line (WP1, verbatim) except `<tech>zpBourbonAbilityBig</tech>`. `zpBourbonAbilityBig` is OBTAINABLE. | WP4 |
| G6 | `TestExtendedStuart` adapted, one method each: power clone, big/small ability lines, small command flags, gates and overrides, shadows at the top (after `zpExtendedStuartLondon`, before line 30000). Use the effect count your WP4 design has, not Stuart's 7. | WP4 |
| G7 | Paris and Versailles have `rmSetSubCiv(…,"Bourbon")` and no `SPCbourbon` in any case. `"cTechzpExtendedBourbonsSPC"` is fired for every player before the side blocks. The revolutionary or attacker block keeps `zpNatBourbonBigbuttonDisableShadow`. Unknown has `rmGetTechID("zpExtendedBourbons")` in the extended-natives block and the vanilla Enabler. The flag override names `Bourbon`. Root copies use `steam_twin` (only the ones the owner names in D5). | WP5 |
| G8 | Specified by WP2, as approved. | WP6 |
| G9 | The hero-musketeer buffs sit where WP2 decided. | WP6 |
| G10 | `xmb_current` for every data file the rework touches. | none |

**Exit:** the new file runs with all its xfails "xfailed" and nothing failing. The three suites match the WP1
baseline. STOP.

### WP4: the extension on vanilla Bourbon (additive; the SPC records still exist)

**Approval package A (needs the owner's yes before you start):**
- Remove `<command page="0" column="4">zpNatBourbonRoyalMarchSmall</command>` from the TradingPost in
  `data/protomods.xml` (~2609).
- The subciv edits below. They are edits, not deletions; list them anyway.

**Changes, each copied from its Stuart twin:**
1. **`zpExtendedBourbons`**, directly after `zpExtendedStuartLondon`, new dbid. It is `zpExtendedStuart` with these
   effects:
   - `CommandRemove command=<vanilla Royal March command>`;
   - `CommandAdd command="zpNatBourbonRoyalMarchSmall" page="0" column="4"`;
   - `CommandRemove tech=<vanilla Royal March tech>` and `CommandAdd tech="zpNatBourbonRoyalMarch" page="0" column="4"`,
     only if WP1 found a vanilla tech; otherwise leave this pair out and report it;
   - `CommandAdd tech="zpBourbonExpansion" page="1" column="1"`;
   - `TechStatus unobtainable zpBourbonAbilityBig`;
   - `TechStatus obtainable zpBourbonAbilitySmall`.

   Every CommandAdd/CommandRemove targets `ProtoUnit TradingPost`.
2. **`zpExtendedBourbonsSPC`**: the same, but `zpBourbonExpansionSPC` at page 1, column 1.
3. **`zpBourbonAbilityBig` / `zpBourbonAbilitySmall`**: copies of the Stuart gates (OBTAINABLE / UNOBTAINABLE,
   Shadow, prereq Colonialize active), new dbids, above `<!--TEST TECHS-->`.
4. **`zpNatBourbonRoyalMarch`** must look like `zpNatStuartHighlandCharge`:
   - UNOBTAINABLE;
   - prereq Colonialize;
   - no `DEUseMediumButton3`.

   Report any difference; change only what makes it match.
5. **`DENativeBourbon` override:**
   - `mergemode="add"` TechStatus obtainable `zpNatBourbonRoyalMarch`;
   - the `GrantsPowerDuration` effect for `zpNatPowerRoyalMarch` (copy line 38870);
   - obtainable `zpBourbonExpansion`, `zpBourbonExpansionSPC`, `zpNatNightWatch`, `zpNatChateauRoyal`;
   - every bucket-(b) effect from WP1 step 4.

   **`DENativeBourbonColonialize` override:**
   - `mergemode="add"` TechStatus active `zpNatBourbonRoyalMarch`;
   - `CommandRemove tech="zpNatBourbonRoyalMarch"` on TradingPost (no mergemode, exactly like 38883);
   - the bucket-(b) effects.

   No `mergeMode` spelling anywhere.
6. **`data/abilities/abilitymods.xml`, `<tradingpost>` section:**
   - New line `<ability mergemode="replace">deNatPowerRoyalMarch<tech>zpBourbonAbilityBig</tech>…</ability>`. After
     the tech, use the vanilla line's content verbatim.
   - Line 98 (`zpNatPowerRoyalMarch`): `<tech>zpBourbonAbilitySmall</tech>` and `<subciv>Bourbon</subciv>`. All other
     tags are the vanilla line's, minus `usebigabilitybutton3` and `subcivstartincooldown`.
   - Line 99 (`zpPowerBourbonExpansion`): `<subciv>Bourbon</subciv>`.
   - The Summer Palace block (239) stays.
7. **`data/protounitcommandmods.xml`:** `<subciv>Bourbon</subciv>` on `zpNatBourbonRoyalMarchSmall`,
   `zpBourbonExpansionFake` and `zpNatBourbonRoyalMarcUniversal` (if it has a subciv). The small command must match
   `zpNatStuartHighlandChargeSmall`: associatedtech `zpNatBourbonRoyalMarch`, associatedpower `zpNatPowerRoyalMarch`,
   no `usemediumbutton3`.
8. **`zpNatPowerRoyalMarch` in powermods:** report the WP1 diff against vanilla. Do not change it without the
   owner's word.
9. **Finish:**
   - remove the `xfail` from G5 and G6;
   - rebuild the twins of techtreemods, protomods, abilitymods and protounitcommandmods;
   - `python .claude/skills/native-ability-minify/scripts/abilitytool.py` (read its `--help`; run its verify mode
     on Bourbon);
   - all checks.

Paris and Versailles lose the small Royal March until WP5; that is expected.

**Owner test M1 (1 run):** a vanilla map with vanilla Bourbon settlements, the owner's choice of map.
- Expected: exactly vanilla: the big Royal March button, no Sun King Era, no small button.
- Watch for the AI error dialog.

### WP5: repoint every consumer (SPC names still exist, but nothing uses them)

**Approval package B:** remove the TradingPost swap effects (`CommandRemove zpBourbonExpansion` and
`CommandAdd zpBourbonExpansionSPC` on `TradingPost`) from `zpParisSetup` (~20582), `zpVerseillesDefenderSetup`
(~21331) and `zpVerseillesAttackerSetup` (~21375). The shadow now places the button; keeping the swap would show it
twice. The `zpBourbonSummerPalace` swap lines in those setups **stay**. Show the exact lines.

**5a. Groupings.**
- Back up every file you touch to `SCRATCH/backup/repo/` and `SCRATCH/backup/profile/`.
- Replace, as bytes: `>zpSocketSPCBourbon<` → `>deSocketBourbon<` and `>zpNatRoyalMusketeer<` → `>deNatRoyalMusketeer<`.
- Assert each count equals the WP1 count. Write the repo copy, then the identical bytes to the profile copy (only if
  they matched before).
- The legacy files follow D3. Never reorder units, and change nothing else.
- G4 must pass afterwards.
- Tell the owner the game needs a restart (it caches groupings by name).

**5b. Maps.**
- **Paris** (`randmaps/zpparis.xs`):
  - `rmSetSubCiv(2,"SPCbourbon")` (~90) → `"Bourbon"`.
  - Copy the existing all-players `cTechzpBonusBourbon` block (~2038) directly below itself, with
    `cTechzpExtendedBourbonsSPC`. This fires the extension for every player before the team blocks.
  - Why not inside `zpParisSetup`: see the London note at `test_parliament_natives.py:595-597`.
  - Flag `"SPCBourbon"` (~2077) → `"Bourbon"`; apply D6.
  - Guardian `"zpNatRoyalMusketeer"` (~2005) → `"deNatRoyalMusketeer"`.
- **Versailles** (`randmaps/zpverseilles.xs`):
  - subciv (~73) → `"Bourbon"`.
  - The same extension block below `cTechzpBonusBourbon` (~1834); it must come before the attacker and defender
    blocks.
  - Flag (~1884) → `"Bourbon"`.
  - Leave the commented test block (~2549).
- **Unknown** (`game/randmaps/zpunknown.xs`):
  - `rmGetCivID("SPCBourbon")` (~292) and `rmSetSubCiv(32,"SPCBourbon")` (~356) → `"Bourbon"`.
  - At ~15448/15449, switch to the vanilla Enabler: uncomment one line, comment the other.
  - Add a `zpExtendedBourbons` loop after the Stuart loop (~16954), the same 6 lines.
  - The grouping names `Natives_SPCBourbon_0x` stay (file names, not protos).
- **`performance_test.xs`** follows D4. **Root copies** follow D5 (copy repo → root, then check by content).

**5c. AI** (`ai-edit` skill first):
- In `aipiraterules.xs`, `cUnitTypezpSocketSPCBourbon` → `cUnitTypedeSocketBourbon`.
- Every `cTechzp…Bourbon` in rule `zpBourbonTechMonitor` → its section 4 name. If a name maps to `NONE`, STOP
  and report.
- Change nothing else; run pytest aitest.

**5d. Data repoint.** Use the WP1 manifest lines marked with a new name:
- the `zpBourbonSummerPalace` train and tech lists (~40915; also the stray `n` after a tag at ~40971: report it, do
  not fix it unasked);
- `zpChateauRoyalShadow` (~468: civ `Bourbon`, `deNat…` units);
- the Military Camp lines in `zpBourbonExpansionSPC`;
- `zpSansculotteBrricades` (~19808-19814);
- the 11 nugget guardians (`data/nuggetmods.xml` ~2340-2370);
- the shared-selection overrides;
- the `zpNativeEmbassyParisReward` trains;
- anything the manifest marks.

Everything marked `WP2` waits for WP6. If a capability from WP1 step 5 (for example a Build action) is missing on
the vanilla unit, report it with a proposal; do not add tactics unasked.

**Finish:**
- remove the `xfail` from G4 and G7;
- rebuild every touched twin;
- run all checks;
- confirm by census that the delete candidates remain only in their own records and in WP2-marked lines.

**Owner tests:**
- **M2 (2 runs), Paris.**
  - Both sides: settlements in all blocks, the right city flag.
  - Royalist: small Royal March, The Sun King Era, Captain of the Guards (D'Artagnan), Château Royal (the wagon
    builds the Summer Palace), Military Camps.
  - Revolutionary: no Sun King Era; the Sansculottes work as before.
- **M3 (2 runs), Versailles,** attacker and defender, with AI. The AI echo works and no error dialog appears.
- **M4 (1 run), Unknown,** with a Bourbon village (the owner forces it if needed).

### WP6: Ancien Régime and Napoleonic Era (only the design the owner approved in D2)

**Approval package C** is the deletion part of the approved WP2 change list.
- Apply the change list record by record and nothing else.
- Remove the `xfail` from G8 and G9.
- Rebuild the twins and run all checks.

**Owner test M5 (3 runs):**
- (a) A French player on a vanilla map plays Ancien Régime: the Embassy shows the vanilla content, with no duplicate
  buttons.
- (b) A Paris revolutionary takes the Napoleonic Era: names and icons are correct, and merc royals train.
- (c) A French revolution to Napoleonic France next to a Bourbon TP: every buff applies once. Compare the musketeer
  HP with the WP2 expectation.

### WP7: strip (approval package D only)

- The owner approves the final list from WP1 step 9, plus WP2 additions.
- Delete exactly those records, lines and files: the zp clone techs, the 4 clone units, the static TradingPost
  entries, the `SPCBourbon` civ, the two unit soundsets, and the `SPCBourbon` branches in
  `sound/zpspcregalship_snds.xml` (~380) and `sound/zpspcostindedr_snds.xml`.
- **Keep** `zpBonusBourbon`, `zpNatBourbonBigbuttonDisableShadow` and `zpNatBigbuttonDisableShadow`: maps and
  `test_london_revolt.py:93` use them. String 501941 stays.
- **Finish:**
  - remove the `xfail` from G1;
  - rebuild every twin;
  - run all checks;
  - `python .claude/skills/mod-deploy-check/scripts/prezip_check.py` must exit 0 or 2.

**Owner test M6 (5 runs):** Paris, Versailles, Unknown, a vanilla Bourbon map, and a standard map with AI. Also a
smoke test of London (Stuart) and Istanbul (Phanar).

### WP8: documentation

- Update the SPC Bourbon examples in `.claude/skills/extended-native/SKILL.md`,
  `.claude/skills/native-ability-minify/SKILL.md` and `.claude/skills/native-ability-minify/scripts/abilitytool.py`
  (~419-422; run its tests if any).
- Add a changelog entry to a new `docs/changelog_v7.4.md` if the owner wants one.

## 7. Approval packages, summary

| Package | WP | Contents |
|---|---|---|
| A | WP4 | the static `zpNatBourbonRoyalMarchSmall` TradingPost line, plus the subciv edits |
| B | WP5 | the TradingPost swap effects in the three Paris/Versailles setup techs |
| C | WP6 | the deletions in the approved WP2 change list |
| D | WP7 | the final strip list |

Each package is shown to the owner as an exact list (file, line, text) and waits for an explicit yes.

## 8. Checks after every WP

```
python scripts/tools/check_art_eol.py
python .claude/skills/aoe-xml/scripts/xmlcheck.py
python .claude/skills/aoe3de-bar-archives/scripts/xmbc.py check data/<each edited file>.xml
python -m pytest scripts/mapcheck/tests -q
python -m pytest scripts/aitest/tests -q
python -m pytest scripts/tools/tests -q
git status --short
git diff --stat
```

Any test that passed in the WP1 baseline and now fails is a STOP. `git status` must show no stray files: no vanilla
extracts, no `__pycache__`, no images.

## 9. Report format: `docs/briefs/bourbon-rework/WP<n>-report.md`

1. **Status:** done, partial or stopped, with the reason.
2. **Files changed:** file, what changed, line ranges.
3. **Commands run:** the exact command, its exit code and the key output (pass, fail and skip counts against the
   baseline).
4. **Twins rebuilt.**
5. **Deviations from this document**, and why. This should be "none".
6. **Open questions and decisions for the owner** (by D-number or package).
7. **The owner's in-game checklist for this WP**, copied from section 6 and completed.
8. **Notes applied:** if the owner gave a task ID, the `tasks.py inbox` note numbers you applied; otherwise `none`.
