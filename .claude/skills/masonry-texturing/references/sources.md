# Research sources (2026-10-09)

Community and trade sources, used as practice hints and verified on the castle renders. These are not authorities.

- Joints should be thinner, irregular and dark grey, not thick black outlines; stones need edge wear and chips, warm
  highlights and cool shadows, and colour variation per stone. Cracked stones should have fragments slightly moved.
  Sources: Polycount critique threads,
  [comment 1999613](https://polycount.com/discussion/comment/1999613),
  [comment 2027239](https://polycount.com/discussion/comment/2027239).
- Pixel or hand-painted walls are built from a mean tone plus scattered near-identical shades, with mortar a little
  lighter or darker than the wall average. Source: [GFX tutorial](https://wolfenstein3d.nl/gfxtutorial7/).
- Procedural walls: a per-cell random ID drives height, colour and roughness; breakup at three scales (a large warp
  for silhouette, mid noise for chips, fine noise for surface); mortar as its own height pass; tile 3x3 to check
  repetition. Sources:
  [80.lv procedural stone wall](https://80.lv/articles/creating-a-procedural-stone-wall-in-substance-designer),
  [varied rock walls](https://80.lv/articles/001agt-creating-varied-rock-walls-in-substance-designer),
  [Substance tile sampler](https://helpx.adobe.com/substance-3d-designer/substance-compositing-graphs/nodes-reference-for-substance-compositing-graphs/node-library/texture-generators/patterns/tile-sampler.html).
- Running bond offsets units by half their length. Historic stone steps were often one piece forming tread and riser
  (the "heavy tread"). Typical stone steps are a 150 mm riser and a 300 mm tread, with a slight fall on each tread for
  runoff. Sources:
  [Engineerfix brick stairs](https://engineerfix.com/brick-stairs-ideas-from-design-to-durable-construction/),
  [modular stone stair patent](https://patents.google.com/patent/US6634145),
  [Waverley stairs spec](https://www.waverley.nsw.gov.au/__data/assets/pdf_file/0009/166815/D20_71363_PDTM_RevG_C_Stairs.pdf).
