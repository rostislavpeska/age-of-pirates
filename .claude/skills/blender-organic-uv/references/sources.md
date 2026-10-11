# Sources

External sources are summaries unless marked [read]. Measured claims come from background-Blender experiments of
2026-10-11 (Blender 5.1.2, hash ec6e62d40fa9) on a 1.1k-triangle rider and synthetic meshes; their records are in the
shared workflow journal (`.claude/skills/JOURNAL.jsonl`, stage `unwrap`, ids `2026-10-11-claude-*uv*`, `m1abf`,
`m2-lscm`, `m3slim`, `m4-mirror`, `m5-autoseam`, `m6-painter`, `judge-technical`, `h1-build`, `h1-verify`).

## Metrics

- Sander, Snyder, Gortler, Hoppe 2001, "Texture Mapping Progressive Meshes": L2 / Linf texture stretch [read].
  https://www.hhoppe.com/tmpm.pdf
- Hormann, Levy, Sheffer, mesh parameterization course and surveys (conformal vs isometric energies).
  https://www.inf.usi.ch/hormann/parameterization

## Flattening

- Rabinovich, Poranne, Panozzo, Sorkine-Hornung 2017, Scalable Locally Injective Mappings (SLIM, Blender's
  MINIMUM_STRETCH). https://www.research-collection.ethz.ch/bitstream/20.500.11850/123420/1/eth-48835-01.pdf
- Blender 4.3 release notes, Modeling & UV (SLIM, iterations, no flip) [read].
  https://developer.blender.org/docs/release_notes/4.3/modeling/
- Blender 4.3 manual, UV operators (method and option texts) [read].
  https://docs.blender.org/manual/en/4.3/modeling/meshes/editing/uv.html
- Sheffer, Levy, Mogilnitsky, Bogomyakov 2005, ABF++. https://www.cs.ubc.ca/~sheffa/papers/abf_plus_plus.pdf
- Levy, Petitjean, Ray, Maillot 2002, LSCM. https://people.engr.tamu.edu/schaefer/teaching/689_Fall2006/p362-levy.pdf

## Cuts

- Sheffer & Hart 2002, Seamster (cuts through curvature hot spots; the cone-point rule).
  https://www.cs.ubc.ca/~sheffa/papers/VIS02.pdf
- Li, Kaufman, Kim, Solomon, Sheffer 2018, OptCuts (joint cuts and distortion; why a search was not chosen).
  https://research.adobe.com/publication/optcuts-joint-optimization-of-surface-cuts-and-parameterization
- Piponi & Borshukov 2000, pelting (the T-shaped pelt the automatic search produced). https://history.siggraph.org/?p=118301
- Polycount discussions on seams in hidden places and along clothing, UV splits on hard edges, edge padding and mips,
  texel-density priorities for faces and hands, low-poly hand-painted layouts.
  https://polycount.com/discussion/comment/1436376 , https://polycount.com/discussion/comment/1616419 ,
  https://polycount.com/discussion/231919/filling-uv-space-vs-texel-density

## Packing

- Blender 3.6 packer notes (shape methods, margin methods). https://wiki.blender.org/wiki/User:Chris_Blackbourn/BlogDraft
- Measured, not found documented: `pack_islands(margin_method='FRACTION')` pads every island, so the island gap is
  2 x margin and the page border 1 x margin.

## Reference units

- The shipped-unit measurements behind a gate profile (the reference rider's numbers quoted in these pages, the seam
  anatomy, the page budgets) belong to the consuming game layer, which records how they were measured; this package
  only consumes the profile (`resources.json`, capability `gate-profile`).
