"""Editor regeneration loop (2026-09-18, the debugRandomMaps bisect). Kills the game - ONLY on the user's explicit
word, the game-startup skill forbids it otherwise - relaunches via Steam, skips intros until the MAIN MENU is
recognised by pixels, opens the Scenario Editor, generates London (row 2 of the Type list) with a fixed seed,
screenshots the load bar every 10 s and prints its fill (0 % after the first reads = generated; a constant value =
hung). Screenshots go to sandbox/census/samples/regen/.
  python sandbox/census/editor_regen.py <tag> <seed>                # full restart
  python sandbox/census/editor_regen.py <tag> <seed> --from-menu    # game already at the main menu
  python sandbox/census/editor_regen.py <tag> <seed> --in-editor    # editor already open
Coordinates are the 2560x1080 client sheet of census_run.py; the map row (1024, 528) is London's - another map
needs its own row (screenshot the open dropdown first)."""
import subprocess, sys, time, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import game_driver as gd
from census_run import C
from PIL import Image, ImageGrab
S = os.path.join(os.path.dirname(os.path.abspath(__file__)), "samples", "regen")
os.makedirs(S, exist_ok=True)
tag = sys.argv[1] if len(sys.argv) > 1 else "run"
seed = sys.argv[2] if len(sys.argv) > 2 else "4242"
restart = "--no-restart" not in sys.argv and "--from-menu" not in sys.argv and "--in-editor" not in sys.argv
from_menu = "--from-menu" in sys.argv

def grab(h):
    x, y, w, hh = gd.client_rect(h)
    return ImageGrab.grab(bbox=(x, y, x + w, y + hh)).convert("RGB")

def is_menu(im):
    # the left button column: >= 12 gold label rows between y 240 and 720 (videos give < 8)
    def gold(c): return c[0] > 190 and c[1] > 160 and c[2] < 160
    rows = sum(1 for y in range(240, 720, 2) if gold(im.getpixel((444, y))))
    return rows >= 12

def is_editor(im):
    a = im.getpixel((1280, 14)); b = im.getpixel((2375, 45))     # dark grey menu bar + the blue player-colour box
    return abs(a[0] - a[1]) < 12 and a[0] < 60 and b[2] > 200 and b[0] < 80

def bar_fill(path):
    im = Image.open(path).convert("RGB")
    y = 1032; x0, x1 = 785, 1773
    lit = sum(1 for x in range(x0, x1) if (lambda p: p[2] > 150 and p[1] > 150 and p[0] < 120)(im.getpixel((x, y))))
    return round(100.0 * lit / (x1 - x0), 1)

if restart:
    subprocess.run(["powershell", "-NoProfile", "-Command", "Stop-Process -Name AoE3DE_s -Force -ErrorAction SilentlyContinue"], capture_output=True)
    time.sleep(4)
    subprocess.run(["powershell", "-NoProfile", "-Command", "Start-Process 'steam://rungameid/933110'"], capture_output=True)
    t0 = time.time(); h = None
    while time.time() - t0 < 150:
        h = gd.find_game()
        if h: break
        time.sleep(3)
    print("window after", round(time.time() - t0), "s", flush=True)
    time.sleep(30)
    t1 = time.time(); ok = False; black = 0
    while time.time() - t1 < 300:
        h = gd.find_game()
        if h:
            try:
                x, y, w, hh = gd.client_rect(h)
                if w >= 2560 and hh >= 1080:
                    gd.focus(h)
                    im = grab(h)
                    if is_menu(im):
                        ok = True; break
                    if sum(im.getpixel((1280, 540))) > 30 or sum(im.getpixel((640, 300))) > 30:
                        gd.key(0x1B)        # a video is showing: skip it
                    else:
                        black += 1
            except Exception as e:
                print("grab err", e, flush=True)
        time.sleep(6)
    print("black frames seen", black, flush=True)
    print("menu" if ok else "MENU NOT SEEN", "after", round(time.time() - t1), "s", flush=True)
    if not ok:
        gd.shot(h, os.path.join(S, f"{tag}_nomenu.png")); sys.exit(2)
    time.sleep(10)                              # the menu ignores clicks for a while after it appears
    t2 = time.time(); ok = False
    for attempt in range(4):
        gd.focus(h); gd.click(h, 444, 599)     # Scenario Editor
        for _ in range(8):
            time.sleep(5)
            if is_editor(grab(h)): ok = True; break
        if ok: break
        print("editor click", attempt + 1, "did not take", flush=True)
    print("editor" if ok else "EDITOR NOT SEEN", "after", round(time.time() - t2), "s", flush=True)
    if not ok:
        gd.shot(h, os.path.join(S, f"{tag}_noeditor.png")); sys.exit(4)
    time.sleep(3)
if from_menu:
    h = gd.find_game(); gd.focus(h); time.sleep(1)
    if not is_menu(grab(h)):
        gd.shot(h, os.path.join(S, f"{tag}_notmenu.png")); print("NOT AT THE MENU"); sys.exit(3)
    time.sleep(10)                              # the menu ignores clicks for a while after it appears
    t2 = time.time(); ok = False
    for attempt in range(4):
        gd.focus(h); gd.click(h, 444, 599)     # Scenario Editor
        for _ in range(8):
            time.sleep(5)
            if is_editor(grab(h)): ok = True; break
        if ok: break
        print("editor click", attempt + 1, "did not take", flush=True)
    print("editor" if ok else "EDITOR NOT SEEN", "after", round(time.time() - t2), "s", flush=True)
    if not ok:
        gd.shot(h, os.path.join(S, f"{tag}_noeditor.png")); sys.exit(4)
    time.sleep(3)
h = gd.find_game(); gd.focus(h)
gd.shot(h, os.path.join(S, f"{tag}_editor.png"))
gd.click(h, *C["file_menu"]); time.sleep(0.8)
gd.click(h, *C["file_new"]); time.sleep(1.5)
gd.click(h, *C["type_arrow"]); time.sleep(0.8)
gd.drag(h, *C["dd_thumb_top_from"], *C["dd_thumb_top_to"]); time.sleep(0.5)
gd.click(h, 1024, 528); time.sleep(0.6)          # row 2 = 00000_zplondon
gd.set_field(h, *C["seed_field"], seed, width=6)
gd.shot(h, os.path.join(S, f"{tag}_dialog.png"))
gd.click(h, *C["generate"])
for i in range(12):
    time.sleep(10)
    p = os.path.join(S, f"{tag}_gen_{i:02d}.png")
    gd.shot(h, p)
    f = bar_fill(p)
    print(f"t+{(i+1)*10}s bar {f}%", flush=True)
    if f == 0.0 and i >= 1:
        print("bar gone", flush=True); break
gd.shot(h, os.path.join(S, f"{tag}_final.png"))
print("END", flush=True)
