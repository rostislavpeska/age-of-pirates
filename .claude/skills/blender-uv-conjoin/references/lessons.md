# Lessons from the Korean Town Center (S8-S13, 2026-09-27)

## What failed and why

1. **Vertex/polygon correspondence matchers (S8-S12).** They compared vertex counts,
   polygon boundaries or whole-chart topology. On 303 randomized ground-truth trials
   they found 1-22% of valid matches and 0 of 40 partial clips; a different
   subdivision of the same surface broke them. Each miss was patched after the owner
   caught it, one heuristic at a time.
2. **Exact containment (S13, "science route").** Directed-Hausdorff containment per
   semantic label, certified and independently re-verified: 21/21 designed specimens,
   0 errors in 303 random trials, a clean tolerance step at eps. Correct - and nearly
   useless for space: ridges -28%, wall panels -26%, whole page A only -4.5%. It only
   shares near-identical geometry, and the model has few exact repeats.
3. **Measuring the wrong thing.** Summing freed member area looked like progress while
   the page did not shrink. The page was 55% empty: repacking alone saves more than all
   exact sharing combined. Always measure the packed page side at fixed density.
4. **Tooling traps.** Blender's packer failed simple controls; live MCP viewport
   screenshots returned stale frames; UV layer limit is 8 per mesh; colour attributes
   share a namespace with UV maps (name clash adds .001); Bash collapses backslashes
   in heredocs (write scripts with a file tool).

## What worked

**Similarity merge + tight repack (T1-T3).** Same material, rectangle dimensions within
+/-tol, outline IoU >= threshold after rect-to-rect mapping, greedy largest-first,
then MaxRects. Page A (569 owner charts, 8192): T1 281 owners / 4458, T2 172 / 3870,
T3 110 / 3116 (14% of the page). Member density change: T1 mean 4% max 11%, T2 13%/33%,
T3 26%/67%. The owner judged T3 closest to vanilla AoE texturing.

## Where each route belongs

- T3: architecture default. T2: when T3 stretch is visible on important surfaces.
- Exact containment: sensitive regions (ornament, signs, asymmetric detail, unique AO).
- Semantic labels matter for any route: on ridges, a naive material label let tube
  undersides share top-strip texels; end/body and sky/side/ground facing fixed it.
- Whole facades never contained one another; reuse lives at panel/strip granularity.

## Process lessons

- Show the owner the whole UV map before/after at the same scale and the colour-by-family
  model first; long reports and per-family boards did not answer "did it work".
- Keep experiments bounded; prefer one decisive measurement over many variants.

## Incident 2026-09-28: frames ate the page (owner estimate about USD 600)

After cleaning scattered faces, T3 kept every timber facade frame as ONE hollow, unique
chart. Bounding rectangles of those frames took 68% of the owner area; the page was
4360 texels (119 texels/unit on a 2048 runtime page). The owner caught it by eye.
Splitting hollow charts into posts and beams: page 2782 (188 texels/unit), hollow 5%,
unshared 15%. Root cause: the method treated a chart as untouchable once it was
"clean", and nothing measured WHERE the page went. Fix: split_hollow() runs by default
and audit() fails the run when hollow or unshared charts dominate. Cleaning (joining)
must never produce hollow composites; the gate catches it if it does.

## Incident 2026-09-28 (2): density drift

The owner asked only to conjoin and keep every chart at its original UV size. The
pipeline normalised each chart to 256 texels/unit (enlarging 352 low-density faces 8x)
and scaled the packed page to fill 0-1 (enlarging everything). Correct deliverable (S16):
owners keep UV area ratio 1.0000 against S12, the conjoined page A occupies the
bottom-left 34% x 34% of the original page and the rest is empty. Members take their
owner's texels (T3 merge): median linear 1.12x, p90 1.34x. Default now: no
normalisation, `--page` = original page.
