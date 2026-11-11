"""Camera bench: look at ONE placed unit from scripted camera positions (trigger Camera Cut) in the Scenario Editor's
Playtest, and keep one still per view. Built 2026-10-08 to inspect attachments (the Korean stable's horses).

    python scripts/aitest/camera_bench.py gen --proto zzKoreanStablePhysics --tag korstable \
        --bones art/zbench_korean_military/stable/korean_stable_physics.gr2:bone_horse1,bone_horse2 --headings 60,90,120
    python scripts/aitest/camera_bench.py editor --tag korstable [--launch]
    python scripts/aitest/camera_bench.py math --target 100,1,100 --heading 90 --pitch 32 --dist 15

gen     writes <Steam>/Game/RandMaps/000000_cambench_<tag>.xs/.xml (never the mod folder: a test map must not ship) with
        destruction_bench's frozen spine. The subject stands at the map centre (world x = z = 100 m on the 200 m map)
        for player 1. One trigger per view, on a timer: "Camera Cut" + the marker "ZPMARK Vnn"; "ZPMARK END" after the
        last view. The camera target is the subject's position, moved to the mean rest position of --bones (an
        attachment point) and/or by --focus. Runs unitbench's offline pre-flight and the S6 scope check, and stores the
        view table in <stem>.bench.json.
editor  from the home menu (or the open Scenario Editor; --launch starts the game through Steam, owner-authorised):
        Scenario Editor -> New -> Type = the map (found by OCR in the list) -> Generate -> Playtest -> one PNG still per
        marker -> Escape -> Quit -> Yes (back in the editor). Every click follows a pixel/OCR check of the screen;
        an unknown screen stops the run. The game process is NEVER killed. Outputs (stills, contact sheet, compiled
        trigtemp.xs, Age3Log slice, report.md) go to a folder OUTSIDE the repository.
math    prints the CameraInfo value for one camera.

Measured 2026-10-08 (AoE3DE_s.exe and in game): the effect's command is trCameraCut(%CameraInfo%); the engine help
reads "trCameraCut( pos, dir, up, right )"; the editor's Set Cut writes the value as the literal text
"vector(%f,%f,%f), vector(%f,%f,%f), vector(%f,%f,%f), vector(%f,%f,%f)", and a random map passing that text compiles
to the same call (13 of 13 in trigtemp.xs) and moves the camera there. World frame: x, z along the map edges in metres,
y up. A building placed by rmPlaceObjectDefAtLoc stands with world = position + (-raw x, raw y, -raw z) of its GR2
(the Korean stable's overhead view). Outside cinematic mode only the position and the heading follow the cut: the game
camera keeps its own tilt (20, 32 and 75 degrees all rendered at about the normal tilt). Cinematic Mode
(trLetterBox(true, false)), as campaign cutscenes use it, is the untested next step for real pitch control.
"""
from __future__ import annotations

import argparse
import datetime
import json
import math
import re
import shutil
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import destruction_bench as db  # noqa: E402  (spine, Trig, OCR, screen helpers)

REPO = db.REPO
PROFILE = db.PROFILE
STEAM_RANDMAPS = db.STEAM_RANDMAPS
DEFAULT_OUT = Path(db.tempfile.gettempdir()) / "aop_camera_bench"
MAP_M = 200.0                     # the spine's rmSetMapSize(200, 200)
BS = chr(92)
EDITOR_POINTS = ("home_editor", "editor_new", "editor_play", "editor_type_arrow", "editor_generate", "match_quit",
                 "quit_yes", "home_skirmish", "mouse_park")


# ============================================================================ camera math
def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def camera(target, heading_deg, pitch_deg, dist):
    """(pos, dir, up, right) for a camera `dist` metres from `target` (world x, y, z; y up) looking along compass
    heading `heading_deg` (0 = +z, 90 = +x) and down by `pitch_deg`. right is horizontal; up = dir x right."""
    th, ph = math.radians(heading_deg), math.radians(pitch_deg)
    d = (math.cos(ph) * math.sin(th), -math.sin(ph), math.cos(ph) * math.cos(th))
    p = tuple(t - dist * c for t, c in zip(target, d))
    r = (math.cos(th), 0.0, -math.sin(th))
    u = cross(d, r)
    return p, d, u, r


def camera_info(target, heading_deg, pitch_deg, dist) -> str:
    """The CameraInfo parameter text, in the editor's own format."""
    return ", ".join("vector(%f,%f,%f)" % v for v in camera(target, heading_deg, pitch_deg, dist))


def views(target, headings, pitch, dist, overhead=True):
    out = [{"label": f"h{h:g}", "heading": h, "pitch": pitch, "dist": dist} for h in headings]
    if overhead:
        out.append({"label": "overhead", "heading": headings[0] if headings else 0, "pitch": 75.0, "dist": dist * 1.5})
    for i, v in enumerate(out, 1):
        v["id"] = f"V{i:02d}"
        v["camera_info"] = camera_info(target, v["heading"], v["pitch"], v["dist"])
    return out


def bone_offset(gr2: Path, names):
    """World offset (x, y, z) of the mean rest position of `names` for a building placed by the random map:
    world = (-raw x, raw y, -raw z), measured 2026-10-08."""
    sys.path.insert(0, str(REPO / "scripts" / "havok"))
    from gr2_read import Gr2
    from gr2_addbones import quat_to_R
    g = Gr2(str(gr2))
    r = g.root(); _, _, sp, st = r["Skeletons"]; sk = g.read(*st, *g.deref(sp[0], sp[1]))
    bones = g.array(sk["Bones"]); world = []
    for b in bones:
        t = b["Transform"]; R = quat_to_R(t[4:8]); p = list(t[1:4]); pi = b["ParentIndex"][0]
        if pi >= 0:
            PR, pp = world[pi]
            world.append((PR @ R, [pp[k] + sum(PR[k][j] * p[j] for j in range(3)) for k in range(3)]))
        else:
            world.append((R, p))
    idx = {b["Name"].lower(): i for i, b in enumerate(bones)}
    missing = [n for n in names if n.lower() not in idx]
    if missing:
        raise SystemExit(f"{gr2.name}: no bone {missing}")
    pts = [world[idx[n.lower()]][1] for n in names]
    m = [sum(p[k] for p in pts) / len(pts) for k in range(3)]
    return (-m[0], m[1], -m[2])


# ============================================================================ gen
XS_HEAD = """// {STEM} - camera bench. GENERATED by scripts/aitest/camera_bench.py - do not edit by hand.
// Subject {PROTO} stands at the map centre (world 100, 100 m) for player 1; camera target {TARGET}. One trigger per
// view: Camera Cut + on-screen marker "ZPMARK Vnn"; "ZPMARK END" after the last view. The spine (includes,
// chooseMercs, rmSetMapSize, rmTerrainInitialize, rmSetMapType, player placement, TC) is rm-unit-bench's frozen one
// (scripts/tools/unitbench.py, shared with destruction_bench.py): without it generation crashes or aborts.

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

   // players on a 0.40 ring, then player 1 moves to the centre
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

   // the subject at the map centre; a Settler at the south edge keeps player 1 alive
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
   rmSetStatusText("", 0.80);

   // ---- triggers: all created first, so every lookup finds its target
{CREATES}

{BODIES}
   rmSetStatusText("", 1.0);
}
"""

XML_TEMPLATE = """<?xml version = "1.0" encoding = "UTF-8"?>
<mapinfo displayName = "{TITLE}" detailsText = "Camera bench for {PROTO}. Generated by scripts/aitest/camera_bench.py."
    imagepath = "ui{BS}random_map{BS}atols{BS}atols_mini" cannotReplace = "" loadBackground = "ui{BS}random_map{BS}atols{BS}atols_map">
   <loadss>ui{BS}random_map{BS}atols{BS}atols_01</loadss>
</mapinfo>
"""


def build_triggers(view_list, first_s, step_s):
    trigs = [db.Trig("CB_Reveal").eff("Render Fog/Black Map", ("Black", False), ("Fog", False))]
    t = first_s
    for v in view_list:
        v["t"] = t
        trigs.append(db.Trig(f"CB_{v['id']}").cond("Timer", ("Param1", t))
                     .eff("Camera Cut", ("CameraInfo", v["camera_info"])).marker(v["id"]))
        t += step_s
    trigs.append(db.Trig("CB_End").cond("Timer", ("Param1", t)).marker("END"))
    return trigs


def render(stem, title, proto, view_list, first_s, step_s, target):
    trigs = build_triggers(view_list, first_s, step_s)
    creates = "\n".join(f'   rmCreateTrigger("{t.name}");' for t in trigs)
    bodies = "\n".join("\n".join(t.body()) for t in trigs)
    xs = db.fill(XS_HEAD, STEM=stem, PROTO=proto, TARGET="(%.2f, %.2f, %.2f)" % tuple(target), BS=BS,
                 CREATES=creates, BODIES=bodies)
    xml = db.fill(XML_TEMPLATE, TITLE=title, PROTO=proto, BS=BS)
    return xs, xml, trigs


def cmd_gen(a):
    stem = a.stem or f"000000_cambench_{a.tag}"
    title = a.title or f"CAMBENCH {a.tag.upper()}"
    off = (0.0, 0.0, 0.0)
    if a.bones:
        path, names = a.bones.rsplit(":", 1)
        off = bone_offset(REPO / path if not Path(path).is_absolute() else Path(path), names.split(","))
        print(f"  focus = mean of {names} -> world offset ({off[0]:.2f}, {off[1]:.2f}, {off[2]:.2f}) m")
    target = (MAP_M * 0.5 + off[0] + a.focus[0], off[1] + a.focus_y, MAP_M * 0.5 + off[2] + a.focus[1])
    headings = [float(h) for h in a.headings.split(",")]
    vl = views(target, headings, a.pitch, a.dist, not a.no_overhead)
    xs, xml, trigs = render(stem, title, a.proto, vl, a.first_s, a.step_s, target)
    out = Path(a.out) if a.out else STEAM_RANDMAPS
    if not out.is_dir():
        sys.exit(f"output folder {out} does not exist")
    if REPO == out.resolve() or REPO in out.resolve().parents:
        sys.exit("REFUSED: a test map never goes into the mod folder (it would ship); use the Steam RandMaps folder")
    xs_path = out / f"{stem}.xs"
    db.write_crlf(xs_path, xs)
    db.write_crlf(out / f"{stem}.xml", xml)
    print(f"wrote {xs_path} ({len(vl)} views, {len(trigs)} triggers); editor Type list entry '{stem}'")
    ok = True
    if not a.no_preflight:
        sys.path.insert(0, str(REPO / "scripts" / "tools"))
        import unitbench
        rep = unitbench.preflight([a.proto], "Settler", 0.0, xs_path)
        ok = rep["fail"] == 0
    rc, msg = db.scope_check(xs_path)
    print("  S6 scope check:", msg)
    ok = ok and rc == 0
    meta = {"stem": stem, "title": title, "proto": a.proto, "target": target, "views": vl, "first_s": a.first_s,
            "step_s": a.step_s, "end_s": a.first_s + a.step_s * len(vl), "written": str(xs_path)}
    (out / f"{stem}.bench.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    return 0 if ok else 1


# ============================================================================ editor run
_MARK = db._canon("ZPMARK")


def parse_view_markers(lines):
    found = set()
    for ln in lines:
        t = db._canon(ln)
        i = t.find(_MARK)
        while i >= 0:
            rest = t[i + len(_MARK):]
            m = re.match(r"V(\d{2})", rest)
            if m:
                found.add("V" + m.group(1))
            elif rest.startswith("END"):
                found.add("END")
            i = t.find(_MARK, i + 1)
    return found


def still(path: Path):
    from PIL import ImageGrab
    try:
        img = ImageGrab.grab()
    except OSError:
        return None
    img.convert("RGB").save(path)
    return path


def ocr_region(ocr, png: Path, box, scale=3):
    """[(text, cx, cy)] in screen pixels for one screen region. The editor's small bold grey-on-grey list text defeats
    Windows OCR at 1:1 (2026-10-08: 'camb', 'ench'); auto-contrast + 3x LANCZOS reads every row."""
    from PIL import Image, ImageOps
    crop = png.with_name(png.stem + "_ocr.png")
    im = ImageOps.autocontrast(Image.open(png).convert("L").crop(box), cutoff=2)
    im.resize((im.width * scale, im.height * scale), Image.LANCZOS).save(crop)
    with ocr.lock:
        ocr.p.stdin.write(str(crop.resolve()) + "\n"); ocr.p.stdin.flush()
        r = json.loads(ocr.p.stdout.readline(), strict=False)
    return [(ln["text"], box[0] + (ln["x"] + ln["w"] // 2) // scale, box[1] + (ln["y"] + ln["h"] // 2) // scale)
            for ln in r.get("lines", [])]


def contact_sheet(rd: Path, meta: dict, got: dict):
    from PIL import Image, ImageDraw, ImageFont
    vl = meta["views"]
    cols = min(3, len(vl)); cw, ch = 960, 600
    rows = (len(vl) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cw, rows * (ch + 34)), (20, 20, 20))
    dr = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arialbd.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    for i, v in enumerate(vl):
        x, y = (i % cols) * cw, (i // cols) * (ch + 34)
        dr.text((x + 8, y + 6), f"{v['id']} {v['label']} pitch {v['pitch']:g} dist {v['dist']:g}", fill=(255, 220, 120), font=font)
        f = got.get(v["id"])
        if f and Path(f).exists():
            sheet.paste(Image.open(f).convert("RGB").resize((cw - 4, ch - 4)), (x + 2, y + 34))
        else:
            dr.text((x + 8, y + 60), "(no still)", fill=(220, 80, 80), font=font)
    p = rd / "contact_sheet.jpg"
    sheet.save(p, quality=90)
    return p


def cmd_editor(a):
    import driver as d
    meta_path = STEAM_RANDMAPS / f"000000_cambench_{a.tag}.bench.json"
    if not meta_path.exists():
        sys.exit(f"no generated camera bench for tag '{a.tag}' ({meta_path.name}) - run gen first")
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    out_root = Path(a.out) if a.out else DEFAULT_OUT
    if REPO == out_root.resolve() or REPO in out_root.resolve().parents:
        sys.exit("REFUSED: stills are images and never go inside the repository")
    rd = out_root / f"{datetime.datetime.now():%Y%m%d_%H%M%S}_{a.tag}"
    frames = rd / "frames"
    frames.mkdir(parents=True, exist_ok=True)
    log = {"tag": a.tag, "bench": meta, "events": [], "views": {}, "checks": {}}

    def ev(msg):
        log["events"].append([round(time.time(), 2), msg])
        print(f"   [{datetime.datetime.now():%H:%M:%S}] {msg}", flush=True)

    def save():
        (rd / "run.json").write_text(json.dumps(log, indent=1), encoding="utf-8")

    def stop(code, msg, shot_name="stop.jpg"):
        db.shot(rd / shot_name); ev(msg + f" - STOP (screenshot {shot_name}); the game is untouched"); save()
        return code

    nav = d.load_coords()
    missing = [k for k in EDITOR_POINTS if k not in nav]
    if missing:
        sys.exit(f"the coordinate sheet lacks {missing} - measure them from screenshots (ui-calibrate) first")
    in_editor = lambda: d.probe_ok(nav["editor_new"]) and d.probe_ok(nav["editor_play"])  # noqa: E731
    if db.input_desktop() != "Default":
        ev("the input desktop is not Default (screen saver / lock / UAC) - wake the screen and rerun"); save(); return 7
    if not d.game_running():
        if not a.launch:
            sys.exit("the game is not running - start it (or pass --launch, owner-authorised); never killed")
        ev("launching through Steam (owner-authorised)")
        db.os.startfile(d.STEAM_URL); time.sleep(5)
        if not db.wait_home_booting(d, nav, 420, ev):
            return stop(3, "the home menu did not appear within 420 s")
    d.focus_game()
    if not in_editor():
        if not d.probe_ok(nav["home_skirmish"]):
            return stop(3, "neither the home menu nor the Scenario Editor is on screen")
        d.guard(); d.click(nav["home_editor"]["x"], nav["home_editor"]["y"])
        if not d.wait_probe(nav["editor_new"], 90) or not in_editor():
            return stop(3, "the Scenario Editor did not open")
        time.sleep(3)
    ev("Scenario Editor up")
    ocr = db.Ocr()
    try:
        ax, ay = nav["editor_type_arrow"]["x"], nav["editor_type_arrow"]["y"]
        if not d.probe_ok(nav["editor_type_arrow"]):           # the New Scenario dialog may already be open
            d.guard(); d.click(nav["editor_new"]["x"], nav["editor_new"]["y"])
            if not d.wait_probe(nav["editor_type_arrow"], 15):
                return stop(3, "the New Scenario dialog did not open")
            time.sleep(1)
        d.guard(); d.click(ax, ay); time.sleep(2)
        lst = rd / "type_list.png"; still(lst)
        want = db._canon(meta["stem"])
        rows = [(t, x, y) for t, x, y in ocr_region(ocr, lst, (ax - 638, ay + 26, ax - 18, ay + 556))
                if want in db._canon(t)]
        if len(rows) != 1:
            d.key_esc()
            return stop(4, f"the Type list shows '{meta['stem']}' {len(rows)} times (needs exactly 1; visible rows only)",
                        "type_list_fail.jpg")
        d.guard(); d.click(rows[0][1], rows[0][2]); time.sleep(2)
        chosen = rd / "type_chosen.png"; still(chosen)
        if not any(want in db._canon(t) for t, _, _ in ocr_region(ocr, chosen, (ax - 638, ay - 26, ax - 30, ay + 24))):
            return stop(4, "the Type field does not show the map after the click")
        ev(f"Type = {meta['stem']}")
        d.guard(); d.click(nav["editor_generate"]["x"], nav["editor_generate"]["y"])
        t0 = time.time()
        while time.time() - t0 < 180 and (d.probe_ok(nav["editor_type_arrow"]) or not in_editor()):
            time.sleep(3)
        if not in_editor():
            return stop(5, "generation did not return to the editor within 180 s")
        time.sleep(4)
        ev("map generated")
        before_dumps = db.dumps_now()
        log_pos = d.log_size()
        d.guard(); d.click(nav["editor_play"]["x"], nav["editor_play"]["y"])
        t_play = time.time()
        ev("Playtest pressed")
        db.mouse_to(d, nav["mouse_park"]["x"], nav["mouse_park"]["y"])
        # Continuous frames, each labelled with the newest view marker OCR finds in it (the chat keeps older markers,
        # the counter line shows the current one; views run in order). Stills are picked afterwards, so nothing
        # blocks the loop (2026-10-08: a 2 s PNG save after each marker made V03's still catch V04).
        flog, n = [], 0
        t_cap = t_play + meta["end_s"] + 150
        while time.time() < t_cap:
            if db.input_desktop() != "Default":
                ev("the input desktop changed mid-run - STOP (nothing clicked)"); break
            d.guard()
            if not d.game_running():
                ev("GAME PROCESS DIED"); log["checks"]["no_crash"] = "FAIL (process died)"; break
            n += 1
            fp = frames / f"f{n:05d}.jpg"
            db.shot(fp, quality=92)
            found = parse_view_markers(ocr.read(fp))
            vids = sorted(found - {"END"})
            flog.append({"file": fp.name, "t": round(time.time() - t_play, 2), "view": vids[-1] if vids else None})
            if vids and not any(f["view"] == vids[-1] for f in flog[:-1]):
                ev(f"view {vids[-1]} on screen (frame {fp.name})")
            if "END" in found:
                ev("END marker"); break
            time.sleep(0.2)
        got = {}
        for v in meta["views"]:
            run = [f for f in flog if f["view"] == v["id"]]
            if run:
                pick = run[len(run) // 2]
                shutil.copy(frames / pick["file"], rd / f"{v['id']}.jpg")
                got[v["id"]] = str(rd / f"{v['id']}.jpg")
                log["views"][v["id"]] = {"still": f"{v['id']}.jpg", "frame": pick["file"], "t": pick["t"], "frames": len(run)}
        log["frames"] = flog
        alive = d.game_running()
        if alive and db.input_desktop() == "Default":
            d.focus_game(); d.key_esc(); time.sleep(1.5)
            d.guard(); d.click(nav["match_quit"]["x"], nav["match_quit"]["y"]); time.sleep(2)
            d.guard(); d.click(nav["quit_yes"]["x"], nav["quit_yes"]["y"])
            back = d.wait_probe(nav["editor_new"], 60) and in_editor()
            ev("Playtest quit: " + ("back in the editor" if back else "editor NOT seen - owner needed, the game is untouched"))
        ch = log["checks"]
        ch.setdefault("no_crash", "PASS" if alive else "FAIL")
        new_dumps = sorted(p for p, m in db.dumps_now().items() if before_dumps.get(p) != m)
        ch["no_new_crash_dump"] = "PASS" if not new_dumps else f"FAIL {new_dumps}"
        _, chunk = d.new_log_content(log_pos)
        (rd / "Age3Log_slice.txt").write_text(chunk, encoding="utf-8")
        bad = [ln.strip()[-220:] for ln in chunk.splitlines()
               if re.search(r"(?i)error|fail|exception|assert|missing|could not|unable", ln)
               and re.search(r"(?i)\.gr2|\.xml|bone|attach|havok|XS:", ln)]
        ch["log_clean"] = "PASS" if not bad else "FAIL: " + " | ".join(bad[:6])
        tt = PROFILE / "Trigger" / "trigtemp.xs"
        if tt.exists() and tt.stat().st_mtime > t_play - 5:
            shutil.copy(tt, rd / "trigtemp.xs")
            cuts = re.findall(r"trCameraCut\([^;]*\);", tt.read_text(encoding="utf-8", errors="replace"))
            ch["trigtemp_camera_cuts"] = f"{len(cuts)} of {len(meta['views'])}"
        else:
            ch["trigtemp_camera_cuts"] = "n/a (no fresh trigtemp.xs)"
        ch["views"] = f"{len(got)} of {len(meta['views'])} stills"
    finally:
        ocr.close()
    sheet = contact_sheet(rd, meta, got)
    save()
    lines = [f"# Camera bench (editor Playtest): {a.tag} ({meta['proto']})", "", "| Check | Result |", "|---|---|"]
    lines += [f"| {k} | {v} |" for k, v in log["checks"].items()]
    lines += ["", "| View | Heading | Pitch | Dist | Still |", "|---|---|---|---|---|"]
    for v in meta["views"]:
        lines.append(f"| {v['id']} {v['label']} | {v['heading']:g} | {v['pitch']:g} | {v['dist']:g} | "
                     f"{log['views'].get(v['id'], {}).get('still', 'missing')} |")
    lines += ["", f"Contact sheet: {sheet.name}", "", "Events:", ""]
    lines += [f"- {time.strftime('%H:%M:%S', time.localtime(t))} {m}" for t, m in log["events"]]
    (rd / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"run folder: {rd}", flush=True)
    return 0 if len(got) == len(meta["views"]) else 1


def cmd_math(a):
    t = tuple(float(x) for x in a.target.split(","))
    print(camera_info(t, a.heading, a.pitch, a.dist))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("gen")
    g.add_argument("--proto", required=True)
    g.add_argument("--tag", required=True)
    g.add_argument("--stem"); g.add_argument("--title"); g.add_argument("--out")
    g.add_argument("--bones", help="GR2:bone1,bone2 - aim at the mean rest position of these bones (repo-relative GR2)")
    g.add_argument("--focus", type=lambda s: tuple(float(x) for x in s.split(",")), default=(0.0, 0.0),
                   help="extra world x,z offset of the camera target (m)")
    g.add_argument("--focus-y", type=float, default=1.0, help="target height above the bones / the base (m)")
    g.add_argument("--headings", default="0,45,90,135,180,225,270,315",
                   help="camera headings in degrees (0 = looking along +z, 90 = along +x)")
    g.add_argument("--pitch", type=float, default=20.0,
                   help="degrees down; outside cinematic mode the game keeps its own tilt (measured 2026-10-08)")
    g.add_argument("--dist", type=float, default=14.0)
    g.add_argument("--no-overhead", action="store_true")
    g.add_argument("--first-s", type=int, default=8)
    g.add_argument("--step-s", type=int, default=5)
    g.add_argument("--no-preflight", action="store_true")
    e = sub.add_parser("editor")
    e.add_argument("--tag", required=True)
    e.add_argument("--launch", action="store_true", help="launch the game through Steam if it is not running")
    e.add_argument("--out")
    m = sub.add_parser("math")
    m.add_argument("--target", required=True)
    m.add_argument("--heading", type=float, required=True)
    m.add_argument("--pitch", type=float, required=True)
    m.add_argument("--dist", type=float, required=True)
    a = ap.parse_args(argv)
    return {"gen": cmd_gen, "editor": cmd_editor, "math": cmd_math}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
