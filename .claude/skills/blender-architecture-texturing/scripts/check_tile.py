"""Read-only edge diagnostic; no universal numerical artistic pass threshold."""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image


def measure(array):
    a = array.astype(float)
    if min(a.shape[:2]) < 2:
        raise ValueError('Image must be at least 2x2')
    horizontal = float(np.abs(a[:, 1:] - a[:, :-1]).mean())
    vertical = float(np.abs(a[1:] - a[:-1]).mean())
    left_right = float(np.abs(a[:, 0] - a[:, -1]).mean())
    top_bottom = float(np.abs(a[0] - a[-1]).mean())
    return dict(left_right_error=left_right, top_bottom_error=top_bottom,
                normal_horizontal_variation=horizontal, normal_vertical_variation=vertical,
                horizontal_seam_ratio=left_right / max(horizontal, 1e-6),
                vertical_seam_ratio=top_bottom / max(vertical, 1e-6),
                warning='Inspect a 3x3 repeat: low seam error does not certify motif continuity')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image')
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    report = measure(np.array(Image.open(args.image).convert('RGB')))
    Path(args.out).write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))
