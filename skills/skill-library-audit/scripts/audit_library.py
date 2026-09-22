"""Read-only resource audit. Never executes package code or external programs."""
from __future__ import annotations

import argparse
import ast
import importlib.metadata
import json
import os
from pathlib import Path
import re
import shutil
import sys
from urllib.parse import unquote, urlsplit

NAME = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
KINDS = {"executable", "application", "directory", "python-package", "capability"}
EXTERNAL_KEYS = {"id", "kind", "commands", "environment", "distribution", "modules",
                 "requiredFor", "optional", "note"}
IGNORED = {"__pycache__", ".DS_Store"}


def inside(path, root):
    return path.resolve().is_relative_to(root.resolve())


def strings(value, nonempty=False):
    return isinstance(value, list) and (bool(value) or not nonempty) and all(
        isinstance(item, str) and bool(item.strip()) for item in value)


def read_declaration(path):
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(data, dict) or set(data) != {"schemaVersion", "files", "skills", "external"}:
        raise ValueError("expected schemaVersion, files, skills and external fields only")
    if type(data["schemaVersion"]) is not int or data["schemaVersion"] != 1:
        raise ValueError("unsupported schemaVersion")
    if not strings(data["files"], True) or "SKILL.md" not in data["files"]:
        raise ValueError("files must include SKILL.md")
    if len(set(data["files"])) != len(data["files"]):
        raise ValueError("duplicate declared file")
    if not strings(data["skills"]) or any(not NAME.fullmatch(n) for n in data["skills"]):
        raise ValueError("skills must contain package names")
    if not isinstance(data["external"], list):
        raise ValueError("external must be a list")
    ids = set()
    for item in data["external"]:
        if not isinstance(item, dict) or set(item) - EXTERNAL_KEYS:
            raise ValueError("invalid external entry or unknown field")
        if not {"id", "kind", "requiredFor", "optional", "note"} <= set(item):
            raise ValueError("external entry missing required fields")
        if not isinstance(item["id"], str) or not NAME.fullmatch(item["id"]) or item["id"] in ids:
            raise ValueError("invalid or duplicate external id")
        ids.add(item["id"])
        if not isinstance(item["kind"], str) or item["kind"] not in KINDS:
            raise ValueError("unknown external kind")
        if type(item["optional"]) is not bool or not strings(item["requiredFor"], True):
            raise ValueError("invalid optional/requiredFor")
        if not isinstance(item["note"], str) or not item["note"].strip():
            raise ValueError("external entry needs a useful note")
        for field in ("commands", "modules"):
            if field in item and not strings(item[field]):
                raise ValueError(f"invalid {field}")
        for field in ("environment", "distribution"):
            if field in item and (not isinstance(item[field], str) or not item[field].strip()):
                raise ValueError(f"invalid {field}")
        if item["kind"] == "python-package" and not item.get("distribution"):
            raise ValueError("python-package needs distribution")
    return data


def local_config(path):
    if path is None:
        return {}
    data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    if not isinstance(data, dict) or set(data) != {"tools"} or not isinstance(data["tools"], dict):
        raise ValueError("local config must contain only tools")
    for key, item in data["tools"].items():
        if not NAME.fullmatch(key) or not isinstance(item, dict) or set(item) != {"path"}:
            raise ValueError("tool configuration permits only an id and path, never commands")
        if not isinstance(item["path"], str):
            raise ValueError("configured path must be a string")
    return data["tools"]


def machine_check(item, config, operation):
    result = {"id": item["id"], "kind": item["kind"], "optional": item["optional"],
              "requiredFor": item["requiredFor"], "note": item["note"]}
    if operation and operation not in item["requiredFor"]:
        return dict(result, status="not-required")
    if item["kind"] == "python-package":
        try:
            version = importlib.metadata.version(item["distribution"])
            return dict(result, status="available", version=version,
                        evidence="distribution metadata in audit interpreter; code not imported")
        except importlib.metadata.PackageNotFoundError:
            return dict(result, status="missing")
    configured = config.get(item["id"], {}).get("path", "")
    supplied = configured or os.environ.get(item.get("environment", ""), "")
    candidate = supplied
    if not supplied:
        candidate = next((found for name in item.get("commands", [])
                          if (found := shutil.which(name))), None)
    if candidate:
        path = Path(candidate).expanduser()
        present = path.is_dir() if item["kind"] == "directory" else path.is_file()
        return dict(result, status="present-unverified" if present else "missing",
                    evidence="configured/discovered path exists" if present else "path not found")
    return dict(result, status="unverified" if item["kind"] == "capability" else "missing")


def audit(skills_root, selected=None, machine=False, operation=None, config=None):
    root = Path(skills_root).resolve()
    report = {"skillsRoot": str(root), "packages": {}, "errors": [], "incomplete": [],
              "externalLinksUnchecked": [], "machine": [], "machineChecked": machine}

    def error(message):
        report["errors"].append(message)

    if not root.is_dir():
        error("skills root is not a directory")
        return finish(report)
    seeds = list(selected or sorted(p.name for p in root.iterdir() if p.is_dir() and not p.name.startswith('.')))
    if not seeds:
        error("no skill packages found")
    pending, declarations = list(seeds), {}
    while pending:
        name = pending.pop(0)
        if name in report["packages"]:
            continue
        report["packages"][name] = {"declared": False}
        if not NAME.fullmatch(name):
            error(f"{name}: invalid package name")
            continue
        folder = root / name
        if not inside(folder, root):
            error(f"{name}: package escapes library")
            continue
        entry = folder / "SKILL.md"
        if not entry.is_file():
            error(f"{name}: missing SKILL.md")
            continue
        text = entry.read_text(encoding="utf-8-sig")
        front = re.match(r"\A---\n(.*?)\n---(?:\n|$)", text, re.S)
        if not front or not re.search(r"^name:\s*" + re.escape(name) + r"\s*$", front[1], re.M) or not re.search(r"^description:\s*\S", front[1], re.M):
            error(f"{name}: invalid frontmatter")
        declaration = folder / "resources.json"
        if not declaration.is_file():
            report["incomplete"].append(f"{name}: no resources.json; dependencies unaudited")
            continue
        try:
            data = read_declaration(declaration)
        except (ValueError, OSError) as exc:
            error(f"{name}: invalid resources.json: {exc}")
            continue
        declarations[name] = data
        report["packages"][name]["declared"] = True
        pending.extend(data["skills"])

    operations = {op for name in seeds if name in declarations
                  for item in declarations[name]["external"] for op in item["requiredFor"]}
    if operation and operation not in operations:
        error(f"unknown operation for selected packages: {operation}")
    if operation and not machine:
        error("operation requires machine mode")

    for name, data in declarations.items():
        folder = root / name
        declared = set()
        for rel in data["files"]:
            path = folder / rel
            if Path(rel).is_absolute() or not inside(path, folder):
                error(f"{name}: declared path escapes package: {rel}")
                continue
            declared.add(path.resolve())
            if not path.is_file():
                error(f"{name}: missing resource: {rel}")
        for path in folder.rglob('*'):
            if any(part in IGNORED for part in path.relative_to(folder).parts) or path.suffix == '.pyc':
                continue
            if path.is_symlink() or (hasattr(path, 'is_junction') and path.is_junction()):
                error(f"{name}: linked resource not portable: {path.relative_to(folder)}")
            if path.is_file() and path.name != 'resources.json' and path.resolve() not in declared:
                error(f"{name}: undeclared bundled file: {path.relative_to(folder)}")

        # Collect only declared companion modules, never arbitrary AoP modules.
        closure, queue = set(), [name]
        while queue:
            dep = queue.pop()
            if dep in closure or dep not in declarations:
                continue
            closure.add(dep)
            queue.extend(declarations[dep]['skills'])
        modules = {Path(p).stem for dep in closure for p in declarations[dep]['files'] if p.endswith('.py')}
        modules.update(Path(p).parent.name for dep in closure for p in declarations[dep]['files'] if p.endswith('/__init__.py'))
        modules.update(m for dep in closure for item in declarations[dep]['external'] for m in item.get('modules', []))
        modules.update(sys.stdlib_module_names)
        for path in sorted(declared):
            if not path.is_file():
                continue
            if path.suffix == '.py':
                try:
                    tree = ast.parse(path.read_text(encoding='utf-8-sig'))
                    for node in ast.walk(tree):
                        if isinstance(node, ast.Import):
                            imports = [alias.name.split('.')[0] for alias in node.names]
                        elif isinstance(node, ast.ImportFrom):
                            imports = [node.module.split('.')[0]] if node.module else []
                        else:
                            continue
                        for module in imports:
                            if module not in modules:
                                error(f"{name}: undeclared Python import {module} in {path.name}:{node.lineno}")
                except (SyntaxError, UnicodeError) as exc:
                    error(f"{name}: invalid Python {path.name}: {exc}")
            if path.suffix != '.md':
                continue
            text = path.read_text(encoding='utf-8-sig')
            # Inline Markdown links outside fenced code blocks; anchors are not file dependencies.
            prose = re.sub(r'(?ms)^```[^\n]*\n.*?^```\s*$', '', text)
            links = re.findall(r'\]\(([^)]+)\)', prose)
            for target in links:
                target = target.strip().strip('<>')
                parsed = urlsplit(target)
                if parsed.scheme or parsed.netloc:
                    report['externalLinksUnchecked'].append(target)
                    continue
                if not parsed.path:
                    continue
                dest = (path.parent / unquote(parsed.path)).resolve()
                if not inside(dest, root):
                    error(f"{name}: link escapes library: {target}")
                elif not dest.is_file():
                    error(f"{name}: missing linked file: {target}")
                else:
                    owner = dest.relative_to(root).parts[0]
                    if owner != name and owner not in closure:
                        error(f"{name}: undeclared companion link: {owner}")
                    if owner == name and dest not in declared:
                        error(f"{name}: linked file not declared: {target}")
            for span in re.findall(r'`([^`\n]+)`', text):
                for rel in re.findall(r'(?<![\w/.-])(?:scripts|references|assets)/[\w./-]+\.(?:py|ps1|md|json|xs|txt|png)\b', span):
                    if (folder / rel).resolve() not in declared:
                        error(f"{name}: literal resource not declared: {rel}")
        if machine:
            for item in data['external']:
                result = machine_check(item, config or {}, operation)
                result['skill'] = name
                report['machine'].append(result)
    return finish(report)


def finish(report):
    report['errors'] = sorted(set(report['errors']))
    report['externalLinksUnchecked'] = sorted(set(report['externalLinksUnchecked']))
    report['packageIntegrity'] = 'failed' if report['errors'] else 'incomplete' if report['incomplete'] else 'passed'
    unresolved = any(not item['optional'] and item['status'] not in {'available', 'not-required'}
                     for item in report['machine'])
    report['machineReadiness'] = 'unresolved' if unresolved else 'presence-checks-passed' if report['machineChecked'] else 'untested'
    report['exitCode'] = 1 if report['errors'] else 2 if report['incomplete'] or unresolved else 0
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--skills-root', type=Path, required=True)
    parser.add_argument('--skill', action='append', dest='selected')
    parser.add_argument('--machine', action='store_true')
    parser.add_argument('--operation')
    parser.add_argument('--local-config', type=Path)
    args = parser.parse_args()
    try:
        config = local_config(args.local_config)
        report = audit(args.skills_root, args.selected, args.machine, args.operation, config)
    except (ValueError, OSError) as exc:
        parser.exit(1, f'Audit input error: {exc}\n')
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return report['exitCode']


if __name__ == '__main__':
    raise SystemExit(main())
