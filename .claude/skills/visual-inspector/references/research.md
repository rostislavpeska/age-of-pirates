# Research brief: vision-model inspectors for 3D asset QA (2026-10-10)

Condensed from a sourced research pass. Claims marked **unconfirmed** were not stated by primary documentation.

## What the evidence says

- **Deterministic first, vision for judgement.** VideoGameQA-Bench (16 VLMs): best glitch detection about 82 %, visual
  regression (before/after) 45 %, fine-detail questions 53 %; slight-overlap clipping usually missed; some models flag
  everything (100 % recall, < 2 % specificity), others almost nothing. Prompt wording moved accuracy only a few points:
  image design and controls matter more. Counts, pixel diffs and overlap tests belong in code.
- **Simple, flat images.** Simplified images raised counting accuracy dramatically ("VLMs are blind"); colour counting
  is often below 30 % (ColorBench). Ask "is magenta visible, in which cell?", never "how many patches?".
- **Size matters causally** ("MLLMs know where to look"): small subjects are misread even when attended. Single views
  plus crops of flagged cells; contact sheets only for triage.
- **Burn text into pixels.** Models do not read file names or metadata (Claude and OpenAI vision docs). Labelled grids
  (Scaffold) or numbered marks (Set-of-Mark) make regions speakable; avoid left/right language (spatial reasoning
  failures, "What's up").
- **Order and count.** Multi-image position bias (weaker in the middle); 4-6 images per inspector, rotated across
  inspectors. Claude prefers images before text, each introduced "Image 1:", ...
- **Binary questions per defect class** (CADCodeVerify) beat an open "find problems"; give a NOT-a-defect list, allow
  "nothing found", ask for the label read back (echo check).
- **Juries.** A panel of smaller diverse models beat one large judge at > 7x lower cost with less self-preference (PoLL);
  independent contexts and different model families decorrelate errors (Claude + GPT via Codex).
- **Controls.** Plant a known defect in each batch and include a clean image; drop inspectors that miss or invent.
  (Standard engineering practice; no paper measured it for this task.)
- **Never edit on a VLM finding alone.** Verify deterministically or with a close-up (VideoGameQA: autonomous use not
  yet feasible; Anthropic: verify outputs, best-of-N disagreement flags hallucination).

## Engine facts

- Claude: standard tier downsizes to 1568 px long edge (high tier 2576 px); tokens about ceil(w/28) x ceil(h/28); more
  than 20 images per request requires each <= 2000 px. Claude Code re-encodes images still over about 500 KB as JPEG
  (blurs thin overlay lines). Subagents: several Agent calls in one message run concurrently, fresh context each; per-call
  `model` overrides the definition. Headless: `claude -p --output-format json --json-schema ...` returns
  `.structured_output`; `--allowedTools Read`.
- Codex: `codex exec` (read-only sandbox), `-i/--image` repeatable or comma list, `--output-schema`, `-o` last message,
  `--ephemeral`, `--skip-git-repo-check`, `-C` work dir. Codex concatenates AGENTS.md files from the Git root down to the
  work dir, so run inspectors in a folder outside any repo. Strict schema: every object `additionalProperties: false`
  and every property required; avoid `pattern`/`format` (**unconfirmed**, third-party reports). Image size limits are
  undocumented: keep <= 2048 px. Temperature control is not documented for either CLI (**unconfirmed**): diversify by
  order, crops and model family instead.

## Sources

- Claude vision: https://platform.claude.com/docs/en/build-with-claude/vision
- Claude vision coordinates: https://platform.claude.com/docs/en/build-with-claude/vision-coordinates
- Reduce hallucinations: https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations
- Claude Code subagents: https://code.claude.com/docs/en/subagents
- Claude Code headless: https://code.claude.com/docs/en/headless
- Claude Code tools reference: https://code.claude.com/docs/en/tools-reference
- Anthropic multi-agent research system: https://www.anthropic.com/engineering/multi-agent-research-system
- Codex CLI reference: https://learn.chatgpt.com/docs/developer-commands?surface=cli
- Codex AGENTS.md: https://developers.openai.com/codex/guides/agents-md
- Codex image workflows (third-party): https://codex.danielvaughan.com/2026/03/28/codex-cli-image-workflows/
- Strict-mode schema note (third-party): https://braintrust.dev/docs/kb/strict-mode-omits-required-field-in-structured-output
- OpenAI images and vision: https://developers.openai.com/docs/guides/images-vision
- VideoGameQA-Bench: https://arxiv.org/html/2505.15952v2
- VLMs are blind: https://arxiv.org/abs/2407.06581
- ColorBench: https://arxiv.org/abs/2504.10514
- MLLMs know where to look: https://arxiv.org/abs/2502.17422
- Set-of-Mark: https://arxiv.org/abs/2310.11441
- Scaffold: https://arxiv.org/abs/2402.12058
- Multi-image position bias: https://arxiv.org/abs/2503.13792
- What's "up": https://arxiv.org/abs/2310.19785
- MLLM-as-a-Judge: https://arxiv.org/abs/2402.04788
- PoLL (juries): https://arxiv.org/abs/2404.18796
- GPTEval3D: https://openaccess.thecvf.com/content/CVPR2024/papers/Wu_GPT-4Vision_is_a_Human-Aligned_Evaluator_for_Text-to-3D_Generation_CVPR_2024_paper.pdf
- Gen3DEval: https://arxiv.org/abs/2504.08125
- CADCodeVerify: https://arxiv.org/abs/2410.05340
- BlenderGym: https://arxiv.org/abs/2504.01786
- SceneCraft: https://arxiv.org/abs/2403.01248
- LL3M: https://arxiv.org/abs/2508.08228
- XBIDetective: https://arxiv.org/pdf/2512.15804
