---
name: workflow-journal
description: Shared self-improvement journal for every agent (Claude, GPT Astra, others) doing 3D work - modeling, UV unwrap, conjoinment, AO, atlas pages, baking, texturing, export in Blender or Photoshop. Record a lesson the moment the owner corrects you, an attempt fails, a method is confirmed or a measurement settles a question; later distil the open records into skill edits. Use during any 3D workflow task and when asked to distil or review lessons.
---

# Workflow journal: record now, distil later

The owner's rule (2026-09-28): the 3D workflow must improve itself. Agents record what they
learn **while working**, in one shared file both agents read, and skills are improved later
by distilling those records - not from memory of a long session that has since been summarised.

Journal: `.claude/skills/JOURNAL.jsonl` (maintainer-only, like `FEEDBACK.md`; not exported).
Tool: `scripts/journal.py` (standard library only).

## When to write a record (at the moment, not at session end)

| Trigger | kind |
| --- | --- |
| The owner corrects you, rejects a result or points at a flaw | `correction` |
| An attempt fails, hangs, crashes, or costs a restart or re-run | `failure` |
| The owner accepts a method or result ("this is fine", "keep it") | `confirmed` |
| A number settles a question (density, fill, error rate, timing) | `measurement` |
| A promising idea you could not pursue now | `idea` |

Stages: `modeling unwrap conjoin ao atlas baking texturing export review tooling`.

```bash
python .claude/skills/workflow-journal/scripts/journal.py add --agent astra --project korean-tc \
  --stage texturing --kind correction --skills blender-architecture-texturing \
  --lesson "One sentence, rule-shaped: do X because Y." \
  --evidence "What happened, with numbers and file paths." --cost "owner rounds / restarts / USD if known"
```

A good record:

- **Lesson** is one rule-shaped sentence a future agent can follow without the session.
- **Evidence** is required: numbers, file names, the owner's words. No evidence, no lesson.
- **Skills** names the packages the lesson should change (`new:<name>` for a missing one).
- Before writing, `list --skill <name>`. If the lesson already exists, add a new record with
  `--repeats <id>`: repetition is the strongest signal for distillation. Do not edit old records.
- Never put credentials, personal data or private paths of other people in a record.

## Distil (only when the owner asks, or in a skill maintenance pass)

1. `python .claude/skills/workflow-journal/scripts/journal.py digest` - open records grouped
   by skill; `DISTILL CANDIDATE` marks skills with an owner correction or a repeated lesson.
2. For each candidate, make the smallest rule change in that skill's `SKILL.md` or reference,
   with the evidence line. Check it against the skill's tests or a small specimen.
3. `journal.py mark <id> distilled --into <skill>/SKILL.md`, or `mark <id> rejected --note ...`
   when the evidence does not hold up.

## Relation to other records

- Agent-private memory (Claude's auto-memory, Codex memories) is per agent and invisible to the
  other; keep using it, but the journal is the shared source for distillation.
- `FEEDBACK.md` stays for failures of the skill system itself (layout, discovery, sync).
- Project-specific effort counters (e.g. the Korean repo's `human_effort.jsonl`) stay where they are.
