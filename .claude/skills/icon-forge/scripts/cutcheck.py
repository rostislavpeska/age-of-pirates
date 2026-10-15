"""Fail when added icon art is cut by the stone frame.

The art is whatever differs from the field it was composited on (the flag, the
cloth). That art must sit inside the 128-px content window with a margin, so
the frame never slices a weapon, a tool or a charge.

    python .claude/skills/icon-forge/scripts/cutcheck.py icon.png --field flag.png [--margin 4]

Exit 0 when every added pixel is inside the margin. Exit 1 when any added pixel
lies in the frame or in the margin, or when the icon adds nothing.
"""
import argparse
import sys

import numpy as np
from PIL import Image

# Same window as iconsheet.py and iconforge: left, top, right, bottom (right and bottom exclusive).
WINDOW = (14, 18, 115, 114)


def added_pixels(icon, field, tol=18):
    """Boolean mask of pixels that are not the field. Both images are RGB, any size; compared at 128."""
    icon = np.array(Image.open(icon).convert("RGB").resize((128, 128), Image.Resampling.BOX))
    field = np.array(Image.open(field).convert("RGB").resize((128, 128), Image.Resampling.BOX))
    delta = np.max(np.abs(icon.astype(np.int16) - field.astype(np.int16)), axis=2)
    return delta > tol


def violations(icon, field, margin=4, tol=18):
    """Count of added pixels outside the safe inset. 0 means the charge is whole."""
    diff = added_pixels(icon, field, tol=tol)
    if not diff.any():
        return -1
    x0, y0, x1, y1 = WINDOW
    sx0, sy0, sx1, sy1 = x0 + margin, y0 + margin, x1 - margin, y1 - margin
    safe = np.zeros(diff.shape, dtype=bool)
    safe[sy0:sy1, sx0:sx1] = True
    return int((diff & ~safe).sum())


def main(argv):
    parser = argparse.ArgumentParser(description="Reject icon art cut by the stone frame.")
    parser.add_argument("icons", nargs="+")
    parser.add_argument("--field", required=True, help="The cloth or flag the art was composited onto.")
    parser.add_argument("--margin", type=int, default=4)
    args = parser.parse_args(argv)
    failed = False
    for path in args.icons:
        count = violations(path, args.field, margin=args.margin)
        if count == -1:
            print(f"FAIL {path}: no added art")
            failed = True
        elif count:
            print(f"FAIL {path}: {count} added pixels are cut by the frame or its margin")
            failed = True
        else:
            print(f"ok   {path}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
