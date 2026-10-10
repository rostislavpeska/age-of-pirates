---
name: visual-inspector
description: Spawn fast vision-model inspectors from the running agent's own family (a Claude agent spawns Sonnet subagents, a Codex agent uses Codex) on rendered false-colour views of a 3D asset to catch what deterministic checks miss (visible faces classified hidden, wrong regions, seams, odd shapes). Planted and clean controls, label echo, cross-family voting, then deterministic verification. Use after every deterministic gate whose result a picture can contradict (UV visibility and sharing, region maps, geometry logic).
---

# Visual inspector (Claude and Codex)

Deterministic checks can be wrong in ways their own numbers never show (sparse ray samples called a partly covered
stair riser "hidden"; the report said PASS). A picture shows it. This skill turns pictures into a **gate**: many small,
independent, controlled inspections whose findings are voted, then **verified deterministically before anything is
changed**. Inspectors never edit; the main agent decides.

Owner rule (2026-10-10): the step that classifies faces always needs visual inspection; fast subagents give quick
feedback so the pipeline does not rely only on determinism; the workflow must run from Claude and from Codex.

## Order of work

1. **Deterministic first.** Run the domain gates (UV integrity, density, visibility, logic QA). Inspectors check what the
   numbers cannot; they never replace a gate, and a skipped gate is not a pass.
2. **Render flat false-colour views** (`scripts/render_overlay_views.py`, background Blender, nothing saved): one INT face
   attribute -> colour, emission only, neutral grey background, orthographic. `--views game` (8 azimuths at 40 deg + 4
   grazing at 15 deg) or explicit `az:el` lists; `below` is informational. Add `--control-object NAME` (PLANTED control:
   one object painted in the defect colour) and `--clean-control` (every face default colour: nothing to report).
3. **Annotate** (`scripts/annotate_views.py DIR --legend ...`): burns the view label, the legend and an A-H x 1-6 grid
   into each image, long edge <= 1568 px; writes `ANNOTATED.json` (file, label, control, grid). Controls carry the
   same kind of label as real views.
   Then **count in code** (`scripts/colour_census.py DIR --rgb 255,0,255`): pixels of the defect colour per view and per
   grid cell; planted controls must light up, clean controls and views must not. Inspectors judge shape and relevance;
   the census owns the count.
4. **Plan** (`scripts/plan_batches.py --spec SPEC.json --annotated .../ANNOTATED.json --out JOB.json --votes 2
   --engines claude` from a Claude agent, `--engines codex` from a Codex agent): 4-6 images per inspector including one
   planted and one clean control at random positions, every view seen by `--votes` inspectors in freshly shuffled rounds.
   **The engine follows the agent running the skill** (owner 2026-10-10: "Codex inspection is for Codex agents using the
   skill. You are Claude agent. You spawn Sonnet."). A Claude agent never calls Codex; a Codex agent never calls Claude.
   SPEC: asset, camera, legend, binary classes (`H1: ...?`), NOT-a-defect list.
5. **Run inspectors** (any mix; all write the same schema `references/inspector_output.schema.json`):
   - **Claude, in session (Claude Code) - the required Claude route there** (owner 2026-10-10: "you must run claude
     inspectors from here"): for each batch `python scripts/run_inspector.py --job JOB.json --print-prompt ID` and spawn
     an Agent with `model: sonnet` and that prompt. **Respect the project's launch cap** (AoP AGENTS.md: at most 2 jobs
     at once across all sessions, agents included): launch in waves of the free slots, never all batches at once
     (2026-10-10 incident: two rounds of 16 simultaneous inspectors). Save each reply as `RESULTS/<inspector_id>.json`
     (the reply arrives as handback text; the agent output file can be empty). Never shell out to `claude -p` from a
     Claude Code session.
   - **Claude, headless (only from Codex or plain scripts, no Claude session):** `python scripts/run_inspector.py --job
     JOB.json --out-dir RESULTS --engine claude` (`claude -p --model sonnet --json-schema ... --allowedTools Read`).
   - **Codex agents:** `python scripts/run_inspector.py --job JOB.json --out-dir RESULTS --engine codex` (`codex exec -s
     read-only --ephemeral --skip-git-repo-check --output-schema ... --image F ...`, prompt on stdin), or Codex's own
     subagents. The binary is `CODEX_BIN`, `codex` on PATH, or the Codex desktop app's bundled `codex.exe`.
   - Independence comes from fresh contexts, shuffled orders and controls within the agent's own family; the research's
     cross-family jury is background, not a step (`references/research.md`).
6. **Aggregate** (`scripts/aggregate_findings.py --job JOB.json --results RESULTS --out AGG.json`). An inspector is
   INVALID (votes dropped, never read as clean) when it skipped an image, misread a burned label, missed the planted
   control, reported anything on the clean control, or named a cell outside the grid. Findings are clustered per image
   and class over touching cells; >= 2 distinct inspectors = CONSENSUS. Views seen by fewer valid inspectors are
   UNDER_COVERED: re-run, do not assume clean.
7. **Verify every consensus and every high-confidence single finding** deterministically (face ids from an ID buffer,
   a ray, a measurement) or with a close-up render of the named cells, before changing the asset. Record each real miss as
   a new deterministic rule or check, so the next run catches it without eyes.
8. **Report**: inspectors valid/total, controls caught, consensus findings with verification result, under-covered views.

## Inspector prompt rules (research-backed, `references/research.md`)

- Flat colours, labels, legend and grid **burned into the pixels**; models read pixels, not file names or metadata.
- 4-6 images per inspector; rotate order between rounds (position bias).
- Binary questions per defect class with an explicit "NOT a defect" list; never ask for counts; locate by grid cell, never
  "left/right".
- Ask the inspector to copy the view label first (proof of looking), then decide per cell; "no finding" is valuable.
- Strict JSON output (schema enforced by both CLIs); one object, nothing else.
- Independent inspectors, then voting; a jury across model families is less correlated than more runs of one model.
- Planted positive control in every batch and a clean control: an inspector that cannot find the planted defect proves
  nothing by reporting none; one that reports on the clean image over-reports.

## Limits and costs (measured 2026-10-10)

- Claude: images over 1568 px long edge are downscaled (standard tier; 2576 on the high tier); images over about 500 KB
  are re-encoded to JPEG, which smears flat colour edges. Keep flat PNG under that size (`annotate_views.py` does).
- A Sonnet inspector with 5-6 annotated images answers in about 15-21 s.
- Codex CLI 0.162 `exec`: `--image` is repeatable and greedy (prompt goes on stdin); `--output-schema` needs every object
  `additionalProperties: false` with all properties required (`test_visual_inspector.py` checks the schema).
- Both CLIs use their own stored sign-in; never put keys or URLs in prompts, command lines or logs.
- Account quotas end runs early: Codex answered "You've hit your usage limit ... try again at <date>" in about 3 s per
  inspector (2026-10-10). The runner records FAILED (never clean); re-run the round when the quota allows.

## Pitfalls

- **Decode errors look like visibility.** An ID buffer with dithering on (Blender default `render.dither_intensity` 1)
  moves ids onto neighbouring faces; self-check every lit pixel against its face's projected box.
- **Overlay framing must contain the model** in every view (a model off camera reads as "nothing wrong").
- **Do not trust a single inspector** and do not trust consensus without verification: inspectors confuse thin outlines
  and eave hairlines with defects; verification decides.
- **Do not reuse the planted control's twin view in the same batch** when avoidable (the pair reveals the plant).

## Files

- `scripts/render_overlay_views.py`: flat overlay renders, planted and clean controls (Blender).
- `scripts/annotate_views.py`: labels, legend, grid, size limit, `ANNOTATED.json` (PIL).
- `scripts/colour_census.py`: deterministic per-view, per-cell count of a legend colour (exit 1 on a defect pixel).
- `scripts/plan_batches.py`: job file with batches, controls, rounds, engines; refuses a missing planted control and
  control twins of inspected views.
- `scripts/run_inspector.py`: prompt filling, Claude headless and Codex runners, in-session prompt printing.
- `scripts/aggregate_findings.py`: validity gates, voting, coverage.
- `scripts/test_visual_inspector.py`: regression tests (no models called).
- `references/inspector_prompt.md`: the prompt template; `references/inspector_output.schema.json`: output schema.
- `references/research.md`: the best-practice brief and its sources.
