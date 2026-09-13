"""Launch the game (harness), open the Scenario Editor, generate 000_hkt_test, capture."""
import os, sys, time, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, r'C:\Users\rosti\aop_harness\aitest')
os.chdir(r'C:\Users\rosti\aop_harness\aitest')
import gamectl, pw
S = r'C:\Users\rosti\aop_harness\aitest\editor_shots'

def alive():
    return 'AoE3DE_s.exe' in subprocess.run(['tasklist', '/FI', 'IMAGENAME eq AoE3DE_s.exe'], capture_output=True, text=True).stdout

def shot(name, crop=None):
    return pw.shot_ok(os.path.join(S, name), crop=crop)

def click(x, y, settle):
    gamectl.ensure_desktop(); gamectl.nudge_input(); gamectl.focus_game()
    gamectl.click(x, y); time.sleep(settle)

if __name__ == '__main__':
    stage = sys.argv[1] if len(sys.argv) > 1 else 'all'
    if stage in ('all', 'launch'):
        print('launch ->', gamectl.launch(timeout_s=300), flush=True)
        # the log says "menu" long before the screen shows it: wait for the home menu's dark
        # left panel (splash/loading art is brown there) before clicking anything
        for i in range(30):
            time.sleep(5)
            try:
                p = pw.px(120, 950)
            except Exception:
                continue
            if max(p) < 45 and alive():
                print('home menu on screen after extra %ds' % (5 * (i + 1)), flush=True); break
        else:
            print('home menu never seen - stopping', flush=True); sys.exit(2)
        time.sleep(3)
        for attempt in range(3):
            click(444, 599, 20)                              # home menu: Scenario Editor
            bar = pw.px(600, 11)                             # editor menu bar is light grey
            print('attempt %d: menu-bar pixel %s' % (attempt, bar), flush=True)
            if min(bar) > 150: break
            time.sleep(10)
        else:
            print('editor never opened - stopping', flush=True); sys.exit(3)
        print('editor shot:', shot('hkt_30_editor.png', crop=(0, 0, 1200, 120)), flush=True)
    if stage in ('all', 'generate'):
        click(20, 23, 1.5); click(44, 48, 3.0)               # File > New
        click(1500, 458, 2.0)                                # Type dropdown
        for _ in range(6):
            gamectl.click(1483, 763); time.sleep(0.15)       # scroll 6 rows down
        time.sleep(1.0); print('list shot:', shot('hkt_31_list.png', crop=(900, 460, 1560, 790)), flush=True)
        click(1000, 653, 1.5)                                # row: 000_hkt_test (verified position)
        print('picked shot:', shot('hkt_32_picked.png', crop=(829, 399, 1749, 776)), flush=True)
        click(1399, 740, 3.0); print('Generate clicked', flush=True); time.sleep(50)
        print('alive after generate:', alive(), flush=True)
        if alive():
            print('generated shot:', shot('hkt_33_generated.png'), flush=True)
