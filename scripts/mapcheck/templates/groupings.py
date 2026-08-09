"""grouping_spawn_complete — the zpparis "did all random city blocks
spawn" case (plan E1/F3): every placement whose def name or grouping file
matches the pattern must be present, in the expected number, on allowed
ground where anchors are concrete.

params:
  pattern          fnmatch glob over the def name AND the grouping file ref
  expected         int — required total placement count
  allowed_classes  optional class allow-list for concrete anchors
"""

from __future__ import annotations

from fnmatch import fnmatch
from typing import List

from scripts.mapcheck.finding import Finding
from scripts.mapcheck.templates import TemplateContext, _template_finding, class_at

NAME = "grouping_spawn_complete"


def grouping_spawn_complete(params: dict, ctx: TemplateContext) -> List[Finding]:
    out: List[Finding] = []
    pattern = params.get("pattern", "*")
    expected = params.get("expected")

    matches = []
    grouping_files = {d.line: str(d.proto)
                      for d in ctx.ex.defs.values() if d.is_grouping}
    for p in ctx.rs.placements:
        ref = grouping_files.get(p.line, "")
        if fnmatch(p.name.lower(), pattern.lower()) or \
                (ref and fnmatch(ref.lower(), pattern.lower())):
            matches.append(p)

    total = sum(max(1, p.count) for p in matches)
    if expected is not None and total != int(expected):
        out.append(_template_finding(
            NAME, "FAIL", ctx,
            f"pattern {pattern!r}: {total} placements found, "
            f"expected {expected}"
            + (f" (defs: {[p.name for p in matches]})" if matches else ""),
            found=total, expected=int(expected)))

    allowed = params.get("allowed_classes")
    if allowed:
        for p in matches:
            if p.x is None or p.z is None:
                continue    # runtime anchor — legality is the sim's job
            cls = class_at(ctx.tg, p.x, p.z)
            if cls not in allowed:
                out.append(_template_finding(
                    NAME, "FAIL", ctx,
                    f"{p.name} at ({p.x:.3f}, {p.z:.3f}) is on {cls}, "
                    f"allowed {allowed}", name=p.name, got=cls))
    return out
