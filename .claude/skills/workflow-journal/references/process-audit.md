# Mandatory 3D process audit

Owner, 13 October 2026: track failures, inability to find proper tools and every
wasted attempt, for all OpenAI and Claude agents, without exception. This covers
coordinators, subagents, interactive work and unattended runs. It is a shared
procedure, not a second tracking database.

## Before new code

Before creating a script or new implementation, including a scratch helper or
inline program, append a record with the existing journal `add` command. Use
`stage=tooling`, `kind=measurement` for the search; use `failure` when a needed
tool is absent, inaccessible or unsuitable. If a harness/process defect is found,
also use the project's existing incident reporter and put its ID in the journal.

Record:

- Task, agent/model family, UTC time, operation and intended output.
- Actual search queries and bounded locations; inspected skill/script/tool IDs.
- Result: reusable / extend existing / not found in searched scope / unavailable /
  incompatible / found but not used. Distinguish discovery failure from absence.
- The exact capability gap, why existing tools cannot cover it, and the chosen
  reuse/extension/new-script decision. Record why a script is necessary before
  writing it. Broad "nothing works" claims are insufficient.
- Intended script path, parent recipe/version/hash, a bounded test and stop rule.
- Actual available usage and its source. Unknown token/time/cost fields say
  `unknown`; they never silently become zero. Do not allocate a whole turn's
  usage to a script without a trace that supports that attribution.

Add the resulting record ID to the script header. If no existing tool was
checked, record that omission as a process failure rather than inventing a
search afterward. Administrative reads may use existing file/CLI tools; this
does not authorize an unlogged new helper implementation.

## At every failure, retry or correction

Append an attempt record immediately, linked to the original decision. Include
command/tool, input identities, result/exit code, observed failure, evidence path,
changed hypothesis and next action. Record discarded code, redundant searches,
duplicate bakes/renders, blocked access, stale-source attempts and owner rejection.
Keep failed artifacts immutable once archived. Log unsuccessful work even if the
next attempt succeeds; a successful retry does not erase its cost or evidence.

Classify the cause precisely: missing tool, failed discovery, misuse, source/frame
error, missing integration, inadequate test, external failure or unresolved.
Label unavoidable investigation separately from confirmed avoidable repetition.
Do not claim the existence of documentation proves a working reproducible tool.

## Existing commands and a compact record

Use `journal.py add` in this skill, with `--evidence` carrying the structured facts
and `--cost` carrying accounting. Use the project's `tasks.py report` for the
incident; do not create another tracker or API. Example evidence fields:

```text
task=...; time_utc=...; attempt=...; agent_family=...;
search=[actual queries/paths]; inspected=[tool/recipe IDs];
result=extend_existing; gap=...; decision=...; script=...;
parent=...; test=...; stop=...; incident=...; outcome=...
```

Example cost field:

```text
tokens=unknown; token_source=unavailable; elapsed_s=12.4;
paid_calls=0; cost_usd=unknown; classification=avoidable_duplicate;
owner_reported_loss=separate, not measured billing
```

Update with another linked record after execution; do not rewrite the historical
decision to make it look successful. Receipt IDs belong in the task notes and
handoff. At phase end list open gaps, failed/retried/discarded attempts and which
ones changed reusable tools or gates. A phase report without this audit is
incomplete. Historical handoffs retain their original evidence.

These are mandatory agent instructions. They do not magically intercept every
filesystem write or supply unavailable billing data; do not claim such automatic
enforcement unless the installed tool hooks demonstrably provide it.
