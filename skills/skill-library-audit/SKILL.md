---
name: skill-library-audit
description: Check a skill library for missing bundled resources, unresolved companion skills, undeclared Python imports and local application prerequisites. Use for library maintenance or before exporting skills; does not install or launch software.
---

# Audit skill resources

Run the bundled checker against the physical `skills/` directory. It uses Python's
standard library and reads files only. From a repository root:

```bash
python -B skills/skill-library-audit/scripts/audit_library.py --skills-root skills
python -B skills/skill-library-audit/scripts/audit_library.py --skills-root skills --skill aoe3de-building-export
python -B skills/skill-library-audit/scripts/audit_library.py --skills-root skills --skill aoe3de-building-export --machine --operation conversion
```

The selected package's declared companion skills are audited transitively. A
`resources.json` lists required files, companion skills and conditional external
prerequisites; read [the declaration format](references/resource-contract.md) when
adding or changing one. Legacy packages without declarations are **incomplete**,
not silently verified. Do not add empty declarations merely to get a green result.

For machine checks, optional `--local-config /path/to/tools.json` reads explicit
tool locations. Keep real configuration outside exported packages; the
[example](assets/tool-paths.example.json) contains no device paths. Read
[local application checks](references/local-tools.md) before interpreting results.
The checker never runs configured commands or application probes.

Report package errors, declaration coverage and machine readiness separately.
`present-unverified` proves a file or Python distribution was found; it does not
prove application compatibility, licensing, live connections or correct output.
`not-required` applies only to the selected operation. Without `--machine`, machine
readiness is untested. Exit 0 means the requested static scope passed, 1 means
invalid/missing resources, and 2 means incomplete coverage or unresolved machine
readiness. Inspect the report rather than interpreting any exit as a game test.

Markdown file links and literal backticked `scripts/`, `references/` and `assets/`
paths are checked. Python imports are parsed without executing helpers. Dynamic
imports, prose-only dependencies, link fragments and external URLs still need
review. Network links are listed as unchecked; do not fetch them unless requested.

Before release, review declaration completeness against the instructions and test
an isolated copy of the intended package set. Run failure fixtures:

```bash
python -B -m unittest discover -s skills/skill-library-audit/tests -v
```

Continue useful work when an optional application is missing. For a required
missing capability, report the blocked operation and an appropriate manual or
already agreed alternative. Do not install dependencies, launch applications,
change machine settings or modify consumer assets to make an audit pass.
