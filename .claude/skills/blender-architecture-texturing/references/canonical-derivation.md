# Canonical derivation: repeat an accepted look without drift

Owner, 2026-10-10: "Each roof now looks worse than previous. The Town center last version must be canonical
reference ... The roof is not perfect - even original but each copy is worse and worse."

## The failure: a copy chain

Each new building re-derived the accepted look: the Town Center (TC) roof recipe was adapted for the Houses, the Castle
copied that, and the Dock copied the Castle. Every step re-implemented code, re-described the look in prose and
re-tuned numbers. Each re-implementation dropped something. The Dock roof lost the TC's photo clay, grime-placed
chips and soot, moss and detail normal, and procedural noise replaced them. The result read "cheap", and its edges got
a different texture than its field.

Research agrees. LLM transmission chains drift toward attractor states, and drift grows with open-ended instructions
([Perez et al., ICLR 2025](https://arxiv.org/abs/2407.04503)). A copied recipe is a Blender *Append* ("copies
data-blocks ... without keeping any reference"), not a *Link*
([manual](https://docs.blender.org/manual/en/latest/files/linked_libraries/link_append.html)).

## The method: star topology, canonical data, executable gates

1. **One canon, pinned.** Pick the accepted asset's *last installed* version and freeze it as a hashed canon pack:
   - its decoded runtime maps (what the player sees);
   - its authoring inputs (tile/role IDs, class maps);
   - a profile of measured metrics.

   A newer accepted version gets a new pack version; it never edits a pack in place.
   Precedent: pip hash-checking mode ([pip](https://pip.pypa.io/en/stable/topics/secure-installs/)) and versioned Houdini
   assets ([SideFX](https://www.sidefx.com/docs/houdini/assets/versioning_systems.html)).
2. **Derive from the canon, never from another derivative (star, not chain).** A building is a thin preset that
   *samples* the canon:
   - **Same or lower texel density than the canon:** exemplar transfer by local features that are defined identically
     on both sides.
   - **Higher density** (the canon would be upscaled into blocks or streaks): use the canon's measured statistics
     instead: mean colour, between-unit tone spread and within-unit grain.

   Look code (palettes, light models, noise "to make it rich") never lives in a building recipe.
3. **Executable over prose.** The canon module, its tests and its gate are the specification; prose explains them.
   Agents follow a script reliably, and they re-interpret prose
   ([Anthropic, Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills);
   [Fowler, specification by example](https://martinfowler.com/bliki/SpecificationByExample.html)).
4. **A check the agent can run.** A numeric gate compares the derived appearance profile with the canon's: per-bin
   colour means, contrast ratios, speck/moss fractions and normal slope quantiles. "Give Claude a check it can run"
   ([Claude Code best practices](https://code.claude.com/docs/en/best-practices)).
   - Never loosen a tolerance to pass. Fix the transfer, or record the deviation for the owner.
   - Equal-weight bins keep a ratio independent of how much area a building's geometry gives each class.
5. **Golden renders in one fixed look-dev rig.** Same light, sky, view transform, pitch and metres-per-pixel for the
   canon and every derivative, then a side-by-side. Reviewers compare only the asset
   ([CAVE Academy turntables](https://caveacademy.com/wiki/post-production-assets/assets-general/framing-your-asset-for-turntables/);
   Unreal's ground-truth screenshot tests,
   [Epic](https://dev.epicgames.com/documentation/unreal-engine/screenshot-comparison-tool-in-unreal-engine)).
   Human acceptance stays final; FLIP/SSIM-style metrics only flag drift
   ([NVIDIA FLIP](https://research.nvidia.com/publication/flip)).
6. **Improve the canon, then re-derive.** When the canon is imperfect, fix it once, version the pack and regenerate
   every building from it. A local improvement made in one building is a new fork; it is forbidden.
7. **Cover every reader.** Masks by role label miss islands that are the same surface under another label (the Dock
   eave strips and shell rims). Select by the data that defines the surface (a real tile ID), not by name.
   - Treat flat bake copies (rims, undersides) explicitly.
   - After the transfer, look at every edge and island in the rig.

## Checklist for any derived look

- [ ] Canon pack version and hashes recorded in the building's report.
- [ ] No palette, light model or "richness noise" for that material in the building recipe.
- [ ] Features identical on canon and target (tests prove it on a synthetic grid).
- [ ] Gate run: PASS, or each failing metric reported to the owner with its number.
- [ ] Look-dev pair rendered: canon vs building at the same scale.
- [ ] Every island of the material checked, including edges, rims, undersides and receivers.

Implementation for the Korean roof: [korean-architecture roof canon](../../korean-architecture/references/roof-canonical.md).
