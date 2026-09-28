"""Destruction bench: an unattended, repeatable in-game run that damages ONE building through every damage stage to
its destruction, captures it, and reports. Plan and rationale: docs/briefs/2026-09-28-destruction-bench-plan.md.

    python scripts/aitest/destruction_bench.py gen --proto zpKoreanTownCenterTest --tag korean
    python scripts/aitest/destruction_bench.py gen --proto zpChineseTownCenterControl --tag control
    python scripts/aitest/destruction_bench.py run --tag korean [--launch] [--out DIR]
    python scripts/aitest/destruction_bench.py sheet RUN_DIR [RUN_DIR ...] --out DIR

gen   writes <Steam>/Game/RandMaps/000000_destrbench_<tag>.xs/.xml (never the mod folder: a test map must not ship),
      runs unitbench's offline pre-flight (proto, animfile, models, materials, textures, CRLF, mapcheck static) and the
      S6 scope check. The subject stands on player 1's start location (the map centre, where the camera opens); two
      gaia Mortars wait 36 m away, outside the Town Center's 32 m guns. Damage modes: both (Mortars ordered at 20/35/50
      s, fallback steps at 60/90/120/150 s force any stage not yet reached), steps (exact 25 % steps at 20/40/60/80 s,
      no artillery), artillery.
      Unit parameters: a trigger needs the subject's scenario INDEX = rmGetUnitPlaced + a per-map shift that is only
      known after a measurement (rm-trigger-testing section 4). Instead the script builds one trigger family per
      candidate shift 0..5; a gate per family (the subject's own proto within 2 m of that index) enables the one
      family whose index really is the subject. The death marker needs no index (Player Unit Count == 0).
run   drives one match from the home menu (or launches the game through Steam with --launch): Skirmish -> map picker
      -> Play -> markers -> capture -> quit through the in-match menu. Markers are large on-screen texts (chat line
      and counter line, "ZPMARK <NAME>"); the harness reads its own screenshots with Windows OCR (ocr_server.ps1), so
      it needs no log channel. Captures: a JPEG every second, a 4-frame burst after every marker, the 10 fps ddagrab
      video, close-angle stills (mouse-wheel zoom) of the intact and the settled building. Machine checks: process
      alive, no new crash dump, no model/hkt/gr2 error in the Age3Log slice, trigtemp.xs clean, markers complete.
      The game process is NEVER killed; a crash or an unknown screen stops the run and reports.
sheet builds the owner's keyframe sheet (one row per run, one column per marker) and a short clip around DEAD.

Outputs are images and videos: they go to a folder OUTSIDE the repository (AGENTS.md rule 8); the tool refuses a
folder inside it.
"""
from __future__ import annotations

import argparse
import ctypes
import datetime
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
PROFILE = REPO.parents[2]                      # <profile>\mods\local\age-of-pirates -> <profile>
STEAM_RANDMAPS = Path(r"C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game\RandMaps")
DEFAULT_OUT = Path(tempfile.gettempdir()) / "aop_destruction_bench"
MARKERS = ["START", "HP75", "HP50", "HP25", "DEAD", "PLUS5", "PLUS15", "END"]
SHIFTS = range(0, 6)
BS = chr(92)
CRLF = "\r\n"


# =========================================================================== gen
def proto_hp(proto: str) -> float:
    pm = (REPO / "data" / "protomods.xml").read_text(encoding="utf-8", errors="ignore")
    m = re.search(r'<unit id="\d+" name="' + re.escape(proto) + r'">(.*?)</unit>', pm, re.S)
    if m:
        hp = re.search(r"<maxhitpoints>([\d.]+)", m.group(1))
        if hp:
            return float(hp.group(1))
    return 6500.0


class Trig:
    """One RM trigger, written literally (map scripts are literal, rm-triggers). Names carry no spaces, so the
    create/lookup space-underscore law (rm-triggers law 3) cannot bite."""

    def __init__(self, name, active=True, loop=False, prio=4):
        self.name, self.active, self.loop, self.prio = name, active, loop, prio
        self.lines = []

    def cond(self, kind, *params):
        self.lines.append(f'   rmAddTriggerCondition("{kind}");')
        self.lines += [_param("Condition", p) for p in params]
        return self

    def eff(self, kind, *params):
        self.lines.append(f'   rmAddTriggerEffect("{kind}");')
        self.lines += [_param("Effect", p) for p in params]
        return self

    def marker(self, label):
        """The two on-screen channels: a large chat line and the persistent counter line."""
        self.eff("Send Chat", ("PlayerID", 0), ("Message", f"<font=largeingame 30>ZPMARK {label}"))
        self.eff("FakeCounter Set Text", ("Text", f"ZPMARK {label}"))
        return self

    def fire(self, target):
        return self.eff("Fire Event", ("EventID", ("xs", f'rmTriggerID("{target}")')))

    def body(self):
        return ([f'   rmSwitchToTrigger(rmTriggerID("{self.name}"));'] + self.lines +
                [f"   rmSetTriggerPriority({self.prio});",
                 f"   rmSetTriggerActive({'true' if self.active else 'false'});",
                 "   rmSetTriggerRunImmediately(true);",
                 f"   rmSetTriggerLoop({'true' if self.loop else 'false'});", ""])


def _param(kind, p):
    name, value = p
    if isinstance(value, tuple) and value[0] == "xs":        # an XS expression (an index, a trigger id)
        return f'   rmSetTrigger{kind}ParamInt("{name}", {value[1]});'
    if isinstance(value, tuple) and value[0] == "unit":      # a unit parameter: the index as a string
        return f'   rmSetTrigger{kind}Param("{name}", ""+({value[1]}));'
    if isinstance(value, bool):
        return f'   rmSetTrigger{kind}Param("{name}", "{"true" if value else "false"}");'
    if isinstance(value, int):
        return f'   rmSetTrigger{kind}ParamInt("{name}", {value});'
    if isinstance(value, float):
        return f'   rmSetTrigger{kind}ParamFloat("{name}", {value:.1f});'
    return f'   rmSetTrigger{kind}Param("{name}", "{value}");'


def build_triggers(proto, damage, hp, mortars, camlock):
    step = round(hp * 0.25, 1)
    trigs = []
    trigs.append(Trig("DB_Reveal").eff("Render Fog/Black Map", ("Black", False), ("Fog", False)))
    trigs.append(Trig("DB_Clock").eff("Counter:Add Timer", ("Name", "ZPCLOCK"), ("Start", 900), ("Stop", 0),
                                      ("Msg", "ZPCLOCK"), ("Event", -1)))
    dead = Trig("DB_Dead").cond("Player Unit Count", ("PlayerID", 1), ("ProtoUnit", proto), ("Op", "=="), ("Count", 0))
    dead.marker("DEAD").fire("DB_Plus5").fire("DB_Plus15").fire("DB_End")
    trigs.append(dead)
    trigs.append(Trig("DB_Plus5", active=False).cond("Timer", ("Param1", 5)).marker("PLUS5"))
    trigs.append(Trig("DB_Plus15", active=False).cond("Timer", ("Param1", 15)).marker("PLUS15"))
    trigs.append(Trig("DB_End", active=False).cond("Timer", ("Param1", 30)).marker("END"))
    if damage == "steps":
        steps = [(20, 1), (40, 2), (60, 3), (80, 4)]
    else:
        steps = [(60, 1), (90, 2), (120, 3), (150, 4)]
    art_times = [20, 35, 50] if damage in ("both", "artillery") else []
    for s in SHIFTS:
        tc = f"dbTC+{s}"
        gate = Trig(f"DB_Gate{s}").cond("Units in Area", ("DstObject", ("unit", tc)), ("Player", 1), ("UnitType", proto),
                                         ("Dist", 2), ("Op", ">="), ("Count", 1))
        gate.fire(f"DB_Setup{s}")
        trigs.append(gate)
        setup = Trig(f"DB_Setup{s}", active=False)
        for action in ("RangedAttack", "CannonAttack", "AntiShipAttack"):
            setup.eff("Unit Action Suspend", ("SrcObject", ("unit", tc)), ("ActionName", action), ("Suspend", True))
        if camlock:
            setup.eff("Camera Face Unit", ("DstObject", ("unit", tc)), ("Timer_ms", 600000), ("Enable", True), ("EventID", -1))
        setup.marker(f"START S{s}")
        for pct, label in ((25, "HP75"), (50, "HP50"), (75, "HP25")):
            setup.fire(f"DB_{label}_{s}")
            trigs.append(Trig(f"DB_{label}_{s}", active=False)
                         .cond("Percent Damaged", ("SrcObject", ("unit", tc)), ("Op", ">="), ("Percent", pct))
                         .marker(label))
        if damage in ("both", "steps"):
            for t, k in steps:
                setup.fire(f"DB_Step{k}_{s}")
                st = Trig(f"DB_Step{k}_{s}", active=False).cond("Timer", ("Param1", t))
                if damage == "both":      # a fallback: only a stage the artillery has not reached yet is forced
                    st.cond("Percent Damaged", ("SrcObject", ("unit", tc)), ("Op", "<"), ("Percent", 25 * k))
                st.eff("Damage Unit", ("SrcObject", ("unit", tc)), ("DamageAmt", 999999.0 if k == 4 else step))
                trigs.append(st)
        for j, t in enumerate(art_times, 1):
            setup.fire(f"DB_Art{j}_{s}")
            art = Trig(f"DB_Art{j}_{s}", active=False).cond("Timer", ("Param1", t))
            for m in range(1, mortars + 1):
                art.eff("Move to Unit", ("SrcObject", ("unit", f"dbM{m}+{s}")), ("DstObject", ("unit", tc)),
                        ("EventID", -1), ("AttackMove", True), ("Run", False), ("RunSpeed", 1.0))
            trigs.append(art)
        trigs.append(setup)
    return trigs


XS_HEAD = """// {STEM} - destruction bench. GENERATED by scripts/aitest/destruction_bench.py - do not edit by hand.
// Subject {PROTO} stands on player 1's start location (the map centre, where the camera opens); {MORTARS} gaia
// Mortars wait {DIST} m away (the Town Center's guns reach 32 m). Damage mode: {DAMAGE}. Markers "ZPMARK <NAME>"
// appear as a chat line and the counter line. Plan: docs/briefs/2026-09-28-destruction-bench-plan.md.
// The spine (includes, chooseMercs, rmSetMapSize, rmTerrainInitialize, rmSetMapType, player placement, TC) is
// rm-unit-bench's frozen one (scripts/tools/unitbench.py): without it generation crashes (+0x7E9D2D) or aborts
// (+0xA7508D).

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

void main(void)
{
   rmSetStatusText("", 0.01);
   rmSetMapSize(200, 200);
   rmSetMapElevationHeightBlend(1);
   rmSetSeaLevel(0.0);
   rmSetLightingSet("sonora_skirmish");
   rmSetMapElevationParameters(cElevTurbulence, 0.02, 2, 0.5, 1.0);
   rmSetBaseTerrainMix("africa desert rock");
   rmTerrainInitialize("deccan{BS}ground_grass3_deccan", 1.0);
   rmSetMapType("arabia");
   rmSetMapType("desert");
   chooseMercs();
   rmSetWorldCircleConstraint(true);
   rmDefineClass("player");
   rmSetStatusText("", 0.30);

   // players on a 0.40 ring, then player 1 moves to the centre: the camera opens on the subject
   rmSetPlacementSection(0.0, 1.0);
   rmPlacePlayersCircular(0.40, 0.40, 0.0);
   rmPlacePlayer(1, 0.5, 0.5);
   rmSetStatusText("", 0.50);

   int tcID = rmCreateObjectDef("player TC");
   rmAddObjectDefItem(tcID, "TownCenter", 1, 0.0);
   rmSetObjectDefMinDistance(tcID, 0.0);
   rmSetObjectDefMaxDistance(tcID, 0.0);
   for(i=2; <= cNumberNonGaiaPlayers)
   {
      rmPlaceObjectDefAtLoc(tcID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   }

   // the subject on player 1's start location; a Settler at the south edge keeps player 1 alive after it falls
   int subjectDef = rmCreateObjectDef("bench subject");
   rmAddObjectDefItem(subjectDef, "{PROTO}", 1, 0.0);
   rmSetObjectDefMinDistance(subjectDef, 0.0);
   rmSetObjectDefMaxDistance(subjectDef, 0.0);
   rmPlaceObjectDefAtLoc(subjectDef, 1, 0.5, 0.5);
   int keeperDef = rmCreateObjectDef("player 1 keeper");
   rmAddObjectDefItem(keeperDef, "Settler", 1, 0.0);
   rmSetObjectDefMinDistance(keeperDef, 0.0);
   rmSetObjectDefMaxDistance(keeperDef, 0.0);
   rmPlaceObjectDefAtLoc(keeperDef, 1, 0.5, 0.06);
{MORTAR_DEFS}
   // unit indices (rmGetUnitPlaced; the per-map shift is resolved by the gates below)
   int dbTC = rmGetUnitPlaced(subjectDef, 0);
{MORTAR_IDS}
   rmSetStatusText("", 0.80);

   // ---- triggers: all created first, so every Fire Event lookup finds its target
{CREATES}

{BODIES}
   rmSetStatusText("", 1.0);
}
"""

MORTAR_DEF = """   int mortarDef{M} = rmCreateObjectDef("bench mortar {M}");
   rmAddObjectDefItem(mortarDef{M}, "Mortar", 1, 0.0);
   rmSetObjectDefMinDistance(mortarDef{M}, 0.0);
   rmSetObjectDefMaxDistance(mortarDef{M}, 0.0);
   rmPlaceObjectDefAtLoc(mortarDef{M}, 0, {X}, {Z});"""

XML_TEMPLATE = """<?xml version = "1.0" encoding = "UTF-8"?>
<mapinfo displayName = "{TITLE}" detailsText = "Destruction bench for {PROTO}. Generated by scripts/aitest/destruction_bench.py."
    imagepath = "ui{BS}random_map{BS}atols{BS}atols_mini" cannotReplace = "" loadBackground = "ui{BS}random_map{BS}atols{BS}atols_map">
   <loadss>ui{BS}random_map{BS}atols{BS}atols_01</loadss>
</mapinfo>
"""


def fill(template: str, **kw) -> str:
    """Substitute {KEY} for the given keys only: the XS text carries its own braces, so str.format cannot be used."""
    for k, v in kw.items():
        template = template.replace("{" + k + "}", str(v))
    left = re.findall(r"\{[A-Z_]+\}", template)
    if left:
        raise ValueError(f"unfilled placeholders {left}")
    return template


def render(stem, title, proto, damage="both", mortars=2, dist=36.0, camlock=False):
    hp = proto_hp(proto)
    frac = dist / 200.0
    spots = [(0.5 - frac, 0.5), (0.5 + frac, 0.5), (0.5, 0.5 + frac), (0.5, 0.5 - frac)]
    if damage == "steps":
        mortars = 0
    mdefs = "\n".join(fill(MORTAR_DEF, M=m, X=f"{spots[m - 1][0]:.3f}", Z=f"{spots[m - 1][1]:.3f}")
                      for m in range(1, mortars + 1))
    mids = "\n".join(f"   int dbM{m} = rmGetUnitPlaced(mortarDef{m}, 0);" for m in range(1, mortars + 1))
    trigs = build_triggers(proto, damage, hp, mortars, camlock)
    creates = "\n".join(f'   rmCreateTrigger("{t.name}");' for t in trigs)
    bodies = "\n".join("\n".join(t.body()) for t in trigs)
    xs = fill(XS_HEAD, STEM=stem, PROTO=proto, MORTARS=mortars, DIST=dist, DAMAGE=damage, BS=BS,
              MORTAR_DEFS=("\n" + mdefs) if mdefs else "", MORTAR_IDS=mids, CREATES=creates, BODIES=bodies)
    xml = fill(XML_TEMPLATE, TITLE=title, PROTO=proto, BS=BS)
    return xs, xml, trigs


def newest_rm_dump():
    """This device's newest CXSDump (<profile>/RandMaps/Age3DERM*.dmp.txt): the builtin catalogue S6 needs. Passed
    explicitly because xs_scope_check.py's default profile path belongs to another device."""
    cands = sorted((PROFILE / "RandMaps").glob("Age3DERM*.dmp.txt"), key=lambda p: p.stat().st_mtime)
    return cands[-1] if cands else None


def scope_check(xs_path: Path):
    dump = newest_rm_dump()
    if dump is None:
        return 0, "skipped (no RM dump on this device yet)"
    r = subprocess.run([sys.executable, str(REPO / "scripts" / "mapcheck" / "xs_scope_check.py"), str(xs_path),
                        "--dump", str(dump)], capture_output=True, text=True, cwd=str(REPO))
    return r.returncode, ((r.stdout + r.stderr).strip().splitlines() or ["(no output)"])[-1]


def write_crlf(path: Path, text: str):
    path.write_bytes(text.replace("\r\n", "\n").replace("\n", CRLF).encode("utf-8"))


def cmd_gen(a):
    stem = a.stem or f"000000_destrbench_{a.tag}"
    title = a.title or f"DESTRBENCH {a.tag.upper()}"
    xs, xml, trigs = render(stem, title, a.proto, a.damage, a.mortars, a.dist, a.camlock)
    out = Path(a.out) if a.out else STEAM_RANDMAPS
    if not out.is_dir():
        sys.exit(f"output folder {out} does not exist")
    if REPO == out.resolve() or REPO in out.resolve().parents:
        sys.exit("REFUSED: a test map never goes into the mod folder (it would ship); use the Steam RandMaps folder")
    xs_path, xml_path = out / f"{stem}.xs", out / f"{stem}.xml"
    write_crlf(xs_path, xs)
    write_crlf(xml_path, xml)
    print(f"wrote {xs_path} ({len(trigs)} triggers, damage {a.damage}) and {xml_path.name}; title '{title}'")
    ok = True
    if not a.no_preflight:
        sys.path.insert(0, str(REPO / "scripts" / "tools"))
        import unitbench
        rep = unitbench.preflight([a.proto], "Mortar", 36.0, xs_path)
        ok = rep["fail"] == 0
    rc, msg = scope_check(xs_path)
    print("  S6 scope check:", msg)
    ok = ok and rc == 0
    meta = {"stem": stem, "title": title, "proto": a.proto, "damage": a.damage, "mortars": a.mortars, "dist": a.dist,
            "camlock": a.camlock, "hp": proto_hp(a.proto), "triggers": len(trigs), "written": str(xs_path)}
    (out / f"{stem}.bench.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    return 0 if ok else 1


# =========================================================================== OCR
class Ocr:
    """scripts/aitest/ocr_server.ps1 kept alive: one JSON line per image path (absolute paths only)."""

    def __init__(self):
        self.p = subprocess.Popen(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                                   str(HERE / "ocr_server.ps1")], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, text=True, encoding="utf-8")
        ready = self.p.stdout.readline()
        if "ready" not in ready:
            raise RuntimeError("OCR server did not start: " + ready)
        self.lock = threading.Lock()

    def read(self, path) -> list:
        with self.lock:
            self.p.stdin.write(str(Path(path).resolve()) + "\n")
            self.p.stdin.flush()
            r = json.loads(self.p.stdout.readline())
        return [ln["text"] for ln in r.get("lines", [])]

    def close(self):
        try:
            self.p.stdin.write("\n"); self.p.stdin.flush(); self.p.wait(timeout=10)
        except Exception:
            self.p.kill()


_FOLD = str.maketrans({"S": "5", "O": "0", "Q": "0", "I": "1", "L": "1", "|": "1", "Z": "2", "B": "8"})


def _canon(s: str) -> str:
    """Upper case, only letters and digits, OCR-confusable characters folded to one form (S/5, O/0, I/L/1, Z/2, B/8).
    Applied to the OCR text and to the tokens alike, so a confusion cannot make a marker unreadable."""
    return re.sub(r"[^A-Z0-9|]", "", s.upper()).translate(_FOLD)


# longest first: PLUS15 before PLUS5
_TOKENS = sorted(MARKERS, key=len, reverse=True)
_MARK = _canon("ZPMARK")


def parse_markers(lines) -> tuple:
    """-> (set of marker names, sim seconds from the ZPCLOCK counter or None)."""
    found, clock = set(), None
    for ln in lines:
        t = _canon(ln)
        i = t.find(_MARK)
        while i >= 0:
            rest = t[i + len(_MARK):]
            for tok in _TOKENS:
                if rest.startswith(_canon(tok)):
                    found.add(tok)
                    break
            i = t.find(_MARK, i + 1)
        c = re.search(r"ZPC[L1I][O0]CK\D*(\d{1,2})\s*[:.;]\s*(\d{2})", ln.upper())
        if c:
            clock = 900 - (int(c.group(1)) * 60 + int(c.group(2)))
    return found, clock


def parse_shift(text: str):
    """The gate's shift from the START marker text ('ZPMARK START S3')."""
    t = _canon(text)
    j = t.find(_canon("START"))
    m = re.match(r"5?(\d)", t[j + 5:]) if j >= 0 else None
    return int(m.group(1)) if m else None


# =========================================================================== screen
def shot(path: Path, quality=88):
    """Full-resolution JPEG of the screen; None when the screen cannot be read (screen saver, lock) - never raises."""
    from PIL import ImageGrab
    try:
        img = ImageGrab.grab()
    except OSError:
        return None
    img.convert("RGB").save(path, quality=quality)
    return path


def mouse_to(d, x, y):
    mv = d.INPUT(type=0)
    mv.u.mi = d.MOUSEINPUT(int(x * 65535 / d.SW), int(y * 65535 / d.SH), 0, 0x0001 | 0x8000, 0, None)
    d.send([mv])


def wheel(d, notches):
    for _ in range(abs(notches)):
        w = d.INPUT(type=0)
        w.u.mi = d.MOUSEINPUT(0, 0, ctypes.c_ulong(120 if notches > 0 else -120).value, 0x0800, 0, None)
        d.send([w])
        time.sleep(0.12)


def input_desktop() -> str:
    """Name of the desktop that receives input: 'Default' when the harness can see and click the game. A screen saver
    ('Screen-saver'), a UAC prompt or the lock screen ('Winlogon') hides it: every pixel then reads CLR_INVALID and the
    cursor (0, 0), so probes never match and the corner guard fires as a false abort (2026-09-28: the OLED Care screen
    saver cost two runs). '?' when the desktop cannot even be opened - also not Default."""
    u = ctypes.windll.user32
    u.OpenInputDesktop.restype = ctypes.c_void_p
    h = u.OpenInputDesktop(0, False, 0x0001)
    if not h:
        return "?"
    buf = ctypes.create_unicode_buffer(256)
    need = ctypes.c_ulong(0)
    u.GetUserObjectInformationW(ctypes.c_void_p(h), 2, buf, ctypes.sizeof(buf), ctypes.byref(need))
    u.CloseDesktop(ctypes.c_void_p(h))
    return buf.value


def keep_display(on: bool):
    """SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED): what a video player does, so
    the screen saver does not start mid-run. Only with --keep-display (the owner's OLED protection is theirs to waive)."""
    ctypes.windll.kernel32.SetThreadExecutionState(0x80000000 | (0x00000002 | 0x00000001 if on else 0))


def wait_home_booting(d, nav, timeout_s, ev):
    """driver.wait_home_with_skip plus the input-desktop check: a screen saver or lock screen stops the wait at once
    with its name instead of timing out on probes that cannot read the screen."""
    t0 = time.time()
    cycle = 0
    while time.time() - t0 < timeout_s:
        if d.stop_requested():
            return False
        desk = input_desktop()
        if desk != "Default":
            ev(f"the input desktop is '{desk}' (screen saver / lock / UAC): the harness can neither see nor click")
            return False
        mouse_to(d, nav["mouse_park"]["x"], nav["mouse_park"]["y"])
        if d.probe_ok(nav["home_skirmish"]):
            return True
        if d.game_running():
            d.key_esc()                                     # skip the intro videos
            if cycle % 2 == 1 and "popup_close" in nav:     # weekly-reward popups ignore Escape
                d.click(nav["popup_close"]["x"], nav["popup_close"]["y"])
        cycle += 1
        time.sleep(10)
    return False


def dumps_now():
    pats = [os.path.join(os.path.expanduser("~"), "Games", "Age of Empires 3 DE", "CrashDumps", "*.dmp"),
            os.path.join(tempfile.gettempdir(), "AoE3DE_s*.dmp")]
    return {p: os.path.getmtime(p) for pat in pats for p in glob.glob(pat)}


# =========================================================================== run
def cmd_run(a):
    sys.path.insert(0, str(HERE))
    import driver as d
    meta_path = STEAM_RANDMAPS / f"000000_destrbench_{a.tag}.bench.json"
    if not meta_path.exists():
        sys.exit(f"no generated bench for tag '{a.tag}' ({meta_path.name}) - run gen first")
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    out_root = Path(a.out) if a.out else DEFAULT_OUT
    if REPO == out_root.resolve() or REPO in out_root.resolve().parents:
        sys.exit("REFUSED: captures are images/videos and never go inside the repository (AGENTS.md rule 8)")
    rd = out_root / f"{datetime.datetime.now():%Y%m%d_%H%M%S}_{a.tag}"
    frames = rd / "frames"
    frames.mkdir(parents=True, exist_ok=True)
    log = {"tag": a.tag, "bench": meta, "events": [], "markers": {}, "frames": [], "checks": {}}

    def ev(msg):
        stamp = time.time()
        log["events"].append([round(stamp, 2), msg])
        print(f"   [{datetime.datetime.now():%H:%M:%S}] {msg}")

    def save():
        (rd / "run.json").write_text(json.dumps(log, indent=1), encoding="utf-8")

    nav = d.load_coords()
    desk = input_desktop()
    if desk != "Default":
        ev(f"STOP before touching anything: the input desktop is '{desk}' (screen saver / lock / UAC) - "
           "the harness can neither see nor click the game; wake the screen and rerun")
        save(); return 7
    if a.keep_display:
        keep_display(True)
        ev("display kept awake for this run (--keep-display)")
    if not d.game_running():
        if not a.launch:
            sys.exit("the game is not running - start it (or pass --launch, owner-authorised); never killed")
        ev("launching through Steam (owner-authorised for this test)")
        os.startfile(d.STEAM_URL)
        time.sleep(5)
    if not d.probe_ok(nav["home_skirmish"]):
        ev("waiting for the home menu (boot / intro videos)")
        if not wait_home_booting(d, nav, 420, ev):
            shot(rd / "no_home.jpg")
            ev("the home menu did not appear within 420 s - STOP for the owner (screenshot no_home.jpg)")
            save(); return 3
        time.sleep(5)
    if not d.probe_ok(nav["home_skirmish"]):
        shot(rd / "not_home.jpg")
        ev("not at the home menu - STOP (screenshot not_home.jpg); the game is untouched")
        save(); return 3
    d.focus_game()
    d.guard(); d.click(nav["home_skirmish"]["x"], nav["home_skirmish"]["y"]); time.sleep(4)
    if not d.wait_probe(nav["lobby_probe"], 30):
        shot(rd / "no_lobby.jpg"); ev("lobby not detected - STOP"); save(); return 3
    shot(rd / "lobby_before.jpg")
    picked = False
    for custom in (False, True):
        if d.select_map(nav, meta["title"], str(rd / "lobby_selected.png"), custom):
            picked = True
            log["picker_category"] = "custom" if custom else "all"
            break
    if not picked:
        shot(rd / "picker_failed.jpg")
        ev(f"the map picker did not find '{meta['title']}' in All Maps nor Custom Maps - STOP")
        save(); return 4
    ev(f"map selected ({log['picker_category']})")
    before_dumps = dumps_now()
    log_pos = d.log_size()
    d.focus_game(); d.guard(); d.click(nav["lobby_play"]["x"], nav["lobby_play"]["y"]); time.sleep(6)
    if d.probe_ok(nav["lobby_play"]):
        d.guard(); d.click(nav["lobby_play"]["x"], nav["lobby_play"]["y"])
    ev("Play pressed")
    t_play = time.time()

    # ---- load: MAP CODE in the log, then the START marker on screen
    ocr = Ocr()
    code_ok = False
    while time.time() - t_play < 300:
        d.guard(); time.sleep(3)
        if not d.game_running():
            ev("GAME PROCESS DIED during the load"); log["checks"]["no_crash"] = "FAIL (died during load)"
            break
        _, chunk = d.new_log_content(log_pos)
        codes = re.findall(r"MAP CODE: '([^/']+)/", chunk)
        if codes:
            if codes[-1].lower() != meta["stem"].lower():
                ev(f"WRONG MAP generated: {codes[-1]} - quitting it"); d.end_match(nav); save(); ocr.close(); return 5
            if not code_ok:
                ev(f"map confirmed by the log: {codes[-1]}")
            code_ok = True
            break
    if not d.game_running():
        save(); ocr.close(); return 6
    mouse_to(d, nav["mouse_park"]["x"], nav["mouse_park"]["y"])
    t_start = None
    seen = {}
    rec = None
    close_done = {"intact": False, "final": False}
    t_cap = time.time() + a.cap_s + 300
    n = 0
    burst_until = 0.0
    while time.time() < t_cap:
        desk = input_desktop()
        if desk != "Default":
            ev(f"the input desktop became '{desk}' mid-run - STOP (nothing clicked; the game is untouched)")
            log["checks"]["desktop"] = f"FAIL ({desk} mid-run)"
            break
        d.guard()
        if d.stop_requested():
            ev("STOP file - ending the run"); break
        if not d.game_running():
            ev("GAME PROCESS DIED"); log["checks"]["no_crash"] = "FAIL (process died mid-run)"
            break
        t = time.time()
        n += 1
        fp = frames / f"f{n:05d}.jpg"
        shot(fp)
        lines = ocr.read(fp)
        found, clock = parse_markers(lines)
        new = [m for m in MARKERS if m in found and m not in seen]
        log["frames"].append({"n": n, "file": fp.name, "t": round(t, 2), "sim": clock, "markers": sorted(found)})
        for m in new:
            seen[m] = t
            log["markers"][m] = {"t": round(t, 2), "frame": fp.name, "sim": clock,
                                 "text": next((ln for ln in lines if "ZPMARK" in ln.upper().replace(" ", "")), "")}
            ev(f"marker {m} (frame {n}, sim {clock})")
            burst_until = t + 1.1
        if "START" in seen and t_start is None:
            t_start = seen["START"]
            t_cap = t_start + a.cap_s
            rec = d.start_recording(str(rd / "match.mp4"), a.cap_s + 60)
            log["video_started"] = round(time.time(), 2)
            ev("recording started" if rec else "recording FAILED to start")
        if t_start is None and time.time() - t_play > 300:
            ev("no START marker within 300 s of Play - the gate or the markers failed; STOP")
            break
        # an AI's resignation offer is a modal dialog that pauses the game: accept it (driver.watch_verdict)
        if d.yes_no_dialog_up(nav):
            d.focus_game(); d.click(nav["quit_yes"]["x"], nav["quit_yes"]["y"]); time.sleep(1.5)
            ev("a Yes/No dialog was up (AI resignation) - accepted")
            mouse_to(d, nav["mouse_park"]["x"], nav["mouse_park"]["y"])
        # close angle: the intact building before the first damage, the settled debris after PLUS15
        for key, after, delay in (("intact", "START", 3.0), ("final", "PLUS15", 1.5)):
            if not close_done[key] and after in seen and time.time() - seen[after] > delay:
                close_done[key] = True
                d.focus_game()
                mouse_to(d, d.SW // 2, d.SH // 2); time.sleep(0.3)
                wheel(d, a.zoom); time.sleep(1.2)
                for k in range(3):
                    shot(rd / f"close_{key}_{k}.jpg"); time.sleep(0.4)
                wheel(d, -a.zoom); time.sleep(0.8)
                mouse_to(d, nav["mouse_park"]["x"], nav["mouse_park"]["y"])
                ev(f"close-angle stills: {key}")
        if "END" in seen and time.time() - seen["END"] > 2.0:
            break
        if time.time() < burst_until:
            time.sleep(0.25)
        else:
            time.sleep(max(0.0, 1.0 - (time.time() - t)))
    d.stop_recording(rec)
    if a.keep_display:
        keep_display(False)
    alive = d.game_running()
    if alive and input_desktop() == "Default":
        shot(rd / "end.jpg")
        quit_ok = d.end_match(nav)
        ev("quit through the menu: " + ("home menu reached" if quit_ok else "FAILED - the game is untouched, owner needed"))
    elif alive:
        ev("the match was LEFT RUNNING: the screen is hidden (screen saver / lock), nothing can be clicked - owner needed")
    ocr.close()

    # ---- machine checks
    ch = log["checks"]
    ch.setdefault("no_crash", "PASS" if alive else "FAIL")
    new_dumps = sorted(p for p, m in dumps_now().items() if before_dumps.get(p) != m)
    ch["no_new_crash_dump"] = "PASS" if not new_dumps else f"FAIL {new_dumps}"
    _, chunk = d.new_log_content(log_pos)
    (rd / "Age3Log_slice.txt").write_text(chunk, encoding="utf-8")
    bad = [ln.strip()[-220:] for ln in chunk.splitlines()
           if re.search(r"(?i)error|fail|exception|assert|missing|could not|unable", ln)
           and re.search(r"(?i)korean|chinese_tc|china_towncenter|\.hkt|\.gr2|havok|destruct|zpKorean|zpChinese|XS:", ln)]
    ch["log_clean"] = "PASS" if not bad else "FAIL: " + " | ".join(bad[:5])
    ch["log_markers"] = ("seen in Age3Log" if "ZPMARK" in chunk else "not in Age3Log") + \
                        (", trigger echo lines present" if "Trigger disabling rule" in chunk else ", no trigger echo lines")
    tt = PROFILE / "Trigger" / "trigtemp.xs"
    if tt.exists() and tt.stat().st_mtime > t_play - 5:
        shutil.copy(tt, rd / "trigtemp.xs")
        r = subprocess.run([sys.executable, str(REPO / ".claude" / "skills" / "rm-trigger-testing" / "scripts" /
                                                "trigtemp_check.py"), str(rd / "trigtemp.xs")],
                           capture_output=True, text=True)
        ch["trigtemp"] = ("PASS" if r.returncode == 0 else "FAIL") + ": " + (r.stdout.strip().splitlines() or [""])[-1]
    else:
        ch["trigtemp"] = "n/a (no fresh trigtemp.xs)"
    shift = parse_shift(log["markers"].get("START", {}).get("text", ""))
    ch["gate"] = f"PASS (shift {shift})" if shift is not None else ("PASS (shift unread)" if "START" in seen else "FAIL (no START)")
    missing = [m for m in MARKERS if m not in seen]
    order = [m for m in MARKERS if m in seen]
    in_order = all(seen[x] <= seen[y] for x, y in zip(order, order[1:]))
    ch["markers"] = ("PASS" if not missing and in_order else "FAIL") + \
                    (f" missing {missing}" if missing else "") + ("" if in_order else " (out of order)")
    ch["video"] = "PASS" if (rd / "match.mp4").exists() and (rd / "match.mp4").stat().st_size > 100000 else "FAIL"
    ch["close_stills"] = "PASS" if all(close_done.values()) else f"partial {close_done}"
    log["timeline"] = {m: round(seen[m] - seen.get("START", seen[m]), 2) for m in order}
    save()
    write_report(rd, log)
    print(f"run folder: {rd}")
    return 0


def write_report(rd: Path, log: dict):
    lines = [f"# Destruction bench run: {log['tag']} ({log['bench']['proto']}, damage {log['bench']['damage']})", "",
             "| Check | Result |", "|---|---|"]
    lines += [f"| {k} | {v} |" for k, v in log["checks"].items()]
    lines += ["", "| Marker | wall s after START | sim s (clock) | frame |", "|---|---|---|---|"]
    for m in MARKERS:
        mk = log["markers"].get(m)
        if mk:
            lines.append(f"| {m} | {log['timeline'].get(m, '')} | {mk.get('sim')} | {mk['frame']} |")
        else:
            lines.append(f"| {m} | not seen | | |")
    lines += ["", "Events:", ""] + [f"- {time.strftime('%H:%M:%S', time.localtime(t))} {msg}" for t, msg in log["events"]]
    (rd / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


# =========================================================================== sheet
SHEET_COLS = [("close_intact", None, "intact (close)"), ("START", 0.5, "intact"), ("HP75", 1.0, "HP 75 %"),
              ("HP75", 3.0, "HP 75 % +3 s"), ("HP50", 1.0, "HP 50 %"), ("HP50", 3.0, "HP 50 % +3 s"),
              ("HP25", 1.0, "HP 25 %"), ("HP25", 3.0, "HP 25 % +3 s"), ("DEAD", 0.3, "destroyed"),
              ("DEAD", 2.0, "+2 s"), ("PLUS5", 0.3, "+5 s"), ("PLUS15", 0.3, "+15 s"), ("close_final", None, "final (close)")]


def pick_frame(run, marker, offset):
    mk = run["markers"].get(marker)
    if not mk:
        return None
    target = mk["t"] + offset
    best = min(run["frames"], key=lambda f: abs(f["t"] - target), default=None)
    return best["file"] if best else None


def cmd_sheet(a):
    from PIL import Image, ImageDraw, ImageFont
    out = Path(a.out)
    if REPO == out.resolve() or REPO in out.resolve().parents:
        sys.exit("REFUSED: the sheet is an image and never goes inside the repository (AGENTS.md rule 8)")
    out.mkdir(parents=True, exist_ok=True)
    runs = []
    for r in a.runs:
        rd = Path(r)
        runs.append((rd, json.loads((rd / "run.json").read_text(encoding="utf-8"))))
    cw, chh = 480, 300
    try:
        font = ImageFont.truetype("arialbd.ttf", 18)
    except OSError:
        font = ImageFont.load_default()
    sheet = Image.new("RGB", (160 + cw * len(SHEET_COLS), 40 + chh * len(runs)), (24, 24, 24))
    dr = ImageDraw.Draw(sheet)
    keys = out / "keyframes"
    keys.mkdir(exist_ok=True)
    for ci, (_, _, label) in enumerate(SHEET_COLS):
        dr.text((160 + ci * cw + 8, 10), label, fill=(255, 255, 255), font=font)
    for ri, (rd, run) in enumerate(runs):
        dr.text((8, 40 + ri * chh + chh // 2), run["tag"], fill=(255, 220, 120), font=font)
        for ci, (marker, off, label) in enumerate(SHEET_COLS):
            if off is None:
                src = rd / f"{marker}_1.jpg"
            else:
                f = pick_frame(run, marker, off)
                src = rd / "frames" / f if f else None
            if not src or not src.exists():
                dr.text((160 + ci * cw + 8, 40 + ri * chh + 8), "(none)", fill=(200, 80, 80), font=font)
                continue
            img = Image.open(src)
            w, h = img.size
            box = (int(w * 0.25), int(h * 0.18), int(w * 0.75), int(h * 0.72))   # the centre, where the subject stands
            crop = img.crop(box).resize((cw - 4, chh - 4))
            sheet.paste(crop, (160 + ci * cw + 2, 40 + ri * chh + 2))
            shutil.copy(src, keys / f"{run['tag']}_{ci:02d}_{re.sub(r'[^A-Za-z0-9]+', '_', label)}.jpg")
    sheet_path = out / "contact_sheet.jpg"
    sheet.save(sheet_path, quality=88)
    print("sheet:", sheet_path)
    ff = shutil.which("ffmpeg") or os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Packages",
                                                "Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe",
                                                "ffmpeg-9.0-full_build", "bin", "ffmpeg.exe")
    for rd, run in runs:
        v0, dead = run.get("video_started"), run["markers"].get("DEAD")
        if not (v0 and dead and (rd / "match.mp4").exists()):
            continue
        ss = max(0.0, dead["t"] - v0 - 4.0)
        dur = 24.0
        clip = out / f"clip_{run['tag']}.mp4"
        subprocess.run([ff, "-y", "-ss", f"{ss:.1f}", "-t", f"{dur:.1f}", "-i", str(rd / "match.mp4"),
                        "-c:v", "libx264", "-crf", "24", "-preset", "fast", str(clip)], capture_output=True)
        print("clip:", clip)
    return 0


# =========================================================================== main
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("gen")
    g.add_argument("--proto", required=True)
    g.add_argument("--tag", required=True)
    g.add_argument("--stem"); g.add_argument("--title"); g.add_argument("--out")
    g.add_argument("--damage", choices=("both", "steps", "artillery"), default="both")
    g.add_argument("--mortars", type=int, default=2)
    g.add_argument("--dist", type=float, default=36.0)
    g.add_argument("--camlock", action="store_true", help="add Camera Face Unit (unproven in any map)")
    g.add_argument("--no-preflight", action="store_true")
    r = sub.add_parser("run")
    r.add_argument("--tag", required=True)
    r.add_argument("--launch", action="store_true", help="launch the game through Steam if it is not running")
    r.add_argument("--out")
    r.add_argument("--cap-s", type=int, default=420, help="wall seconds from START to give up")
    r.add_argument("--zoom", type=int, default=6, help="mouse-wheel notches for the close angle")
    r.add_argument("--keep-display", action="store_true",
                   help="hold the display awake during the run so the screen saver cannot start (owner's call: OLED)")
    s = sub.add_parser("sheet")
    s.add_argument("runs", nargs="+")
    s.add_argument("--out", required=True)
    a = ap.parse_args(argv)
    return {"gen": cmd_gen, "run": cmd_run, "sheet": cmd_sheet}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
