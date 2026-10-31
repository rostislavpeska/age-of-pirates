"""area_class_probe — evidence-backed terrain regression locks (plan
D6/E1/F3): named points must classify as stated. Profile `expectations`
are sugar for exactly this template.

params:
  probes  [{"probe": [x_frac, z_frac], "class": "SHALLOW",
            "why": "...", "evidence": "<id, optional>"}]
"""

from __future__ import annotations

from typing import List

from scripts.mapcheck.finding import Finding
from scripts.mapcheck.templates import TemplateContext, _template_finding, class_at

NAME = "area_class_probe"


def area_class_probe(params: dict, ctx: TemplateContext) -> List[Finding]:
    out: List[Finding] = []
    for k, ex in enumerate(params.get("probes", [])):
        x, z = ex["probe"]
        got = class_at(ctx.tg, x, z)
        if got != ex["class"]:
            out.append(_template_finding(
                NAME, "FAIL", ctx,
                f"probe[{k}] ({x}, {z}) is {got}, expected {ex['class']}"
                + (f" — {ex['why']}" if ex.get("why") else ""),
                probe=[x, z], expected=ex["class"], got=got,
                evidence=ex.get("evidence")))
    return out
