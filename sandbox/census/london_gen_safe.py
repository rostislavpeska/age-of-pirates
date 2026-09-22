"""Generate London in the ALREADY OPEN Scenario Editor, touching the screen only if the editor is verifiably in front.
  python sandbox/census/london_gen_safe.py <tag> [seed] [--save NAME] [--dry-run]
Screenshots + the game's trigtemp.xs copy go to sandbox/census/samples/regen/. Exits 3 without a single click when
the editor is not the foreground window (2026-09-22: a blind run clicked into the user's desktop). Exits 2 without
any input event when there is no game window. --dry-run prints the window, its monitor and every click / key it
WOULD make (normalised and pixel coordinates) and makes none, takes no screenshot and skips the editor check.
Positions: the 2560x1080 client sheet of census_run.py, normalised through gamewin.py (any monitor)."""
import os, sys, time, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gamewin as gw
from census_run import C
from editor_regen import is_editor, bar_fill

S = os.path.join(os.path.dirname(os.path.abspath(__file__)), "samples", "regen")
PROFILE = r"C:\Users\TIGO\Games\Age of Empires 3 DE\76561198347905238"
TRIG = os.path.join(PROFILE, "Trigger", "trigtemp.xs")
DUMP = os.path.join(PROFILE, "RandMaps", "Age3DERM00000_zplondon.dmp.txt")
N = gw.normalise_sheet(C)                          # census_run.py:41-49, 2560x1080 client pixels -> 0..1
# Type dropdown, opened WITHOUT dragging the list to the top: row 2 = 00000_zplondon (list of 2026-09-22 18:01),
# measured at 2560x1080 client pixels (1024, 559) -> / (2560, 1080)
LONDON_ROW = (1024 / 2560, 559 / 1080)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    dry = "--dry-run" in argv
    tag = argv[0] if len(argv) > 0 and not argv[0].startswith("--") else "ldn"
    seed = argv[1] if len(argv) > 1 and not argv[1].startswith("--") else "4242"
    save_name = argv[argv.index("--save") + 1] if "--save" in argv else None

    P = gw.open_pilot(dry)
    if not P: print("NO GAME WINDOW"); return 2
    if not dry:
        os.makedirs(S, exist_ok=True)
    P.focus(); P.wait(1.0)
    if dry:
        print(f"DRY check is_editor at {gw.norm(1280, 14)} and {gw.norm(2375, 45)}; not in front -> exit 3, no click")
    else:
        im = P.grab(); im.save(os.path.join(S, f"{tag}_check.png"))
        if not is_editor(im): print("EDITOR NOT IN FRONT - no click made"); return 3
    t_dump0 = os.path.getmtime(DUMP) if os.path.exists(DUMP) else 0
    t_trig0 = os.path.getmtime(TRIG) if os.path.exists(TRIG) else 0

    P.click(*N["file_menu"], "File"); P.wait(0.8)
    P.click(*N["file_new"], "New"); P.wait(1.5)
    P.click(*N["type_arrow"], "Type dropdown arrow"); P.wait(1.0)
    P.shot(os.path.join(S, f"{tag}_dropdown.png"))
    P.click(*LONDON_ROW, "row 2 = 00000_zplondon"); P.wait(0.8)
    P.set_field(*N["seed_field"], seed, label="seed"); P.wait(0.5)
    P.shot(os.path.join(S, f"{tag}_dialog.png"))
    P.click(*N["generate"], "Generate"); t0 = time.time()
    for i in range(18):
        P.wait(10); p = os.path.join(S, f"{tag}_gen_{i:02d}.png"); P.shot(p)
        if dry:
            print("DRY bar_fill of each shot; stop when 0 % after the first reads (up to 18 x 10 s)"); break
        f = bar_fill(p)
        print(f"t+{(i + 1) * 10}s bar {f}%", flush=True)
        if i >= 1 and f == 0.0: print("bar gone", flush=True); break
    P.wait(3); P.shot(os.path.join(S, f"{tag}_final.png")); print("final shot after", round(time.time() - t0), "s")
    if dry:
        print(f"DRY compare the mtimes of {DUMP} and {TRIG}; copy trigtemp.xs to {os.path.join(S, tag + '_trigtemp.xs')}")
        written = True
    else:
        t_dump1 = os.path.getmtime(DUMP) if os.path.exists(DUMP) else 0
        t_trig1 = os.path.getmtime(TRIG) if os.path.exists(TRIG) else 0
        print("RM dump written:", t_dump1 > t_dump0, "| trigger script written:", t_trig1 > t_trig0)
        if t_trig1 > t_trig0:
            shutil.copyfile(TRIG, os.path.join(S, f"{tag}_trigtemp.xs")); print("trigtemp.xs copied")
        written = t_dump1 > t_dump0
    if save_name and written:
        P.click(*N["file_menu"], "File"); P.wait(0.8)
        P.click(*N["file_saveas"], "Save As"); P.wait(1.5)
        P.set_field(*N["save_name"], save_name, label="save name"); P.wait(0.5)
        P.shot(os.path.join(S, f"{tag}_save.png"))
        P.click(*N["save_button"], "Save"); P.wait(3.0)
        print("saved as", save_name)
    print("END")
    return 0


if __name__ == "__main__":
    sys.exit(main())
