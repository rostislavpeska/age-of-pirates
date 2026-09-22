# Resource declaration, version 1

Each audited package has `resources.json`. Paths in `files` are relative to the
package and must stay inside it. Include every required bundled helper, reference,
asset and test fixture; `SKILL.md` is required. The declaration itself is implicit.
`skills` contains companion directory names under the same library root. The
checker follows them transitively and detects missing or invalid packages.

```json
{
  "schemaVersion": 1,
  "files": ["SKILL.md", "scripts/check.py"],
  "skills": [],
  "external": [
    {
      "id": "python",
      "kind": "executable",
      "commands": ["python", "python3"],
      "requiredFor": ["check"],
      "optional": false,
      "note": "Use the interpreter selected for this task."
    }
  ]
}
```

External kinds: `executable`, `application`, `directory`, `python-package`,
`capability`. Each needs an id, a nonempty list of operation names in `requiredFor`,
an `optional` boolean and a concrete `note`. Optional fields:

- `commands`: candidate executable names searched on PATH; never executed.
- `environment`: environment variable containing the local path.
- `distribution`: Python distribution name, required for `python-package`.
- `modules`: import roots supplied by this prerequisite, e.g. `PIL` or `bpy`.

The checker rejects unknown fields and malformed declarations. It compares Python
import roots with standard-library names, bundled modules, declared companion
modules and declared external modules. This is static dependency evidence; dynamic
imports, platform-specific branches and plugin discovery require manual review.
Required files and referenced local files must be declared; undeclared files in a
package are reported so newly added helpers cannot silently bypass the audit.

With `--machine`, distribution metadata is read in the audit's Python interpreter.
Files are discovered from `tools.<id>.path` in an optional local configuration,
then the declared environment variable, then PATH. An explicitly configured but
missing path is reported missing instead of silently selecting another program.
No registry scans, installation, imports of application modules or subprocess
probes occur. Capability prerequisites remain unverified even if a path exists.

`--operation` filters external prerequisites, not package integrity. It must match
an operation declared by the selected packages. Required missing or unverified
application capabilities make machine readiness unresolved. Optional tools do not
block it, but remain visible in the report. A package audit alone never verifies
tool versions, licenses, sessions, output fidelity or game behavior.

Do not confuse this resource contract with the export allowlist. A declaration
does not authorize redistribution or export. Record source provenance separately
for third-party references and retain the normal publication review.
