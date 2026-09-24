"""gameio: one shared layer for driving and watching the running Age of Empires III DE window (created 2026-09-24).

Why: the game-control code was duplicated across about eight scripts (scripts/aitest/driver.py and probe.py,
sandbox/census/game_driver.py, gamewin.py, capture.py, editor_regen.py, scripts/havok/pw.py), with four click and
three key semantics and five incompatible coordinate stores (survey 2026-09-24). This package is ADDITIVE: it
copies the live-verified pieces and changes none of those files.

    win      read-only window facts (find, rects, foreground, cursor, process, screen) - ctypes, lazy
    geom     pure geometry (SendInput normalisation, client/screen conversion) - no ctypes at all
    inputs   Session: focus / check / click / move / drag / key / type_text with an abort-corner guard and a
             foreground check before every event, the window under every press checked, only a window of
             AoE3DE_s.exe accepted, a 1.0 s settle after a focus switch, and a dry run that records the exact
             event list (fix round 2026-09-24: gameio review F1-F5)
    capture  grab / window_image (PrintWindow, works when the game is covered) / shot with a JSON sidecar /
             pixel / Recorder (ffmpeg)
    sheets   scripts/gameio/sheets/<W>x<H>.json - UI points with provenance; derived points refused by default
    screens  recognisers returning (bool, evidence): is_main_menu, menu_layout_ok, is_editor, probe_ok

Rules: no Win32 call happens at import (every ctypes.windll access is inside a function); DPI awareness only
through win.dpi_aware(), which Session() and the CLI call. CLI: python -m scripts.gameio --help.
"""
