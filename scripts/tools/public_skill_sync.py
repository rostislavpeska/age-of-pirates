#!/usr/bin/env python3
"""Safely synchronize approved skills between AoP and public repositories.

AoP is canonical. Export publishes snapshots. Import is an explicit review path
for outside contributions. Neither direction commits, pushes, pulls or clones.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import runpy
import tempfile


ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = ROOT / ".claude" / "skills"
MANIFEST_PATH = ROOT / "scripts" / "skill-sync-manifest.json"
CONFIG_PATH = ROOT / "config" / "skill-sync.local.json"
STATE_PATH = ROOT / "scripts" / "skill-sync-state.json"

IGNORED_NAMES = {"__pycache__", ".DS_Store"}
IGNORED_SUFFIXES = {".pyc"}
FORBIDDEN_SUFFIXES = {
    ".exe", ".dll", ".pdb", ".blend", ".blend1", ".fbx", ".psd", ".spp",
    ".gr2", ".gxo", ".ddt", ".tga", ".bar", ".xmb", ".zip", ".7z",
}
TEXT_SUFFIXES = {".md", ".txt", ".json", ".yaml", ".yml", ".py", ".ps1", ".toml", ".xs"}
PRIVATE_PATTERNS = {
    "absolute Windows user path": re.compile(r"[A-Za-z]:[\\/]Users[\\/]", re.IGNORECASE),
    "Windows profile data path": re.compile(r"AppData[\\/]", re.IGNORECASE),
    "private Steam account path": re.compile(r"[\\/]765611\d{8,}[\\/]"),
    "local converter configuration": re.compile(r"converter\.local\.json", re.IGNORECASE),
    "local skill-sync configuration": re.compile(r"skill-sync\.local\.json", re.IGNORECASE),
}


def read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"Missing required file: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}")


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def files_in(root: Path):
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        rel = path.relative_to(root)
        if any(part in IGNORED_NAMES for part in rel.parts) or path.suffix.lower() in IGNORED_SUFFIXES:
            continue
        yield path, rel


def digest_tree(root: Path) -> str:
    digest = hashlib.sha256()
    for path, rel in files_in(root):
        digest.update(rel.as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def validate_skill(root: Path, expected_name: str) -> None:
    if not root.is_dir():
        raise ValueError(f"Missing skill directory: {root}")
    entry = root / "SKILL.md"
    if not entry.is_file():
        raise ValueError(f"Missing SKILL.md: {root}")
    text = entry.read_text(encoding="utf-8")
    if not text.startswith("---\n") or "\n---\n" not in text[4:]:
        raise ValueError(f"Invalid frontmatter: {entry}")
    frontmatter = text.split("---", 2)[1]
    match = re.search(r"^name:\s*([^\n]+)$", frontmatter, re.MULTILINE)
    actual = match.group(1).strip().strip("\"'") if match else None
    if actual != expected_name:
        raise ValueError(f"Skill name {actual!r} does not match directory {expected_name!r}")
    if not re.search(r"^description:\s*\S", frontmatter, re.MULTILINE):
        raise ValueError(f"Missing description: {entry}")


def safety_scan(root: Path) -> None:
    problems = []
    for path in [root] if root.is_file() else sorted(root.rglob("*")):
        rel = Path(path.name) if path == root else path.relative_to(root)
        if path.is_symlink() or (getattr(path.stat(follow_symlinks=False), "st_file_attributes", 0) & 0x400):
            problems.append(f"symlink: {rel}")
            continue
        if not path.is_file() or any(part in IGNORED_NAMES for part in rel.parts):
            continue
        suffix = path.suffix.lower()
        if suffix in FORBIDDEN_SUFFIXES:
            problems.append(f"forbidden binary/source asset: {rel}")
            continue
        if suffix in TEXT_SUFFIXES or path.name == "SKILL.md":
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                problems.append(f"non-UTF-8 public text file: {rel}")
                continue
            for label, pattern in PRIVATE_PATTERNS.items():
                if pattern.search(text):
                    problems.append(f"{label}: {rel}")
    if problems:
        raise ValueError("Public safety scan failed:\n  " + "\n  ".join(problems))


def file_changes(left: Path, right: Path) -> list[str]:
    left_files = {rel.as_posix(): path for path, rel in files_in(left)}
    right_files = {rel.as_posix(): path for path, rel in files_in(right)}
    rows = []
    for rel in sorted(left_files.keys() | right_files.keys()):
        if rel not in left_files:
            rows.append(f"ADD {rel}")
        elif rel not in right_files:
            rows.append(f"DELETE {rel}")
        elif left_files[rel].read_bytes() != right_files[rel].read_bytes():
            rows.append(f"MODIFY {rel}")
    return rows


def is_within(child: Path, parent: Path) -> bool:
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def replace_tree(source: Path, destination: Path) -> None:
    parent = destination.parent.resolve()
    if destination.resolve().parent != parent:
        raise ValueError(f"Unexpected destination: {destination}")
    incoming = parent / f".{destination.name}.sync-new"
    backup = parent / f".{destination.name}.sync-old"
    for transient in (incoming, backup):
        if os.path.lexists(transient):
            raise ValueError(f"Previous staging path exists; review before retrying: {transient}")
    shutil.copytree(source, incoming, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    validate_skill(incoming, destination.name)
    safety_scan(incoming)
    if destination.exists():
        destination.rename(backup)
    try:
        incoming.rename(destination)
    except Exception:
        if backup.exists() and not destination.exists():
            backup.rename(destination)
        raise
    if backup.exists():
        shutil.rmtree(backup)


def public_root(repo: Path) -> Path:
    source = repo / '.claude' / 'skills'
    if not source.is_dir() or source.is_symlink() or (getattr(source.stat(follow_symlinks=False), 'st_file_attributes', 0) & 0x400):
        raise ValueError(f'Expected physical .claude/skills directory: {repo}')
    if os.path.lexists(repo / 'skills'):
        raise ValueError(f'Legacy skills/ tree remains: {repo}')
    return source


def load_context(requested="all"):
    manifest = read_json(MANIFEST_PATH)
    config = read_json(CONFIG_PATH)
    state = read_json(STATE_PATH) if STATE_PATH.exists() else {"schemaVersion": 1, "skills": {}}
    repositories = config.get("repositories", {})
    contexts = {}
    for target, spec in manifest.get("targets", {}).items():
        if requested != 'all' and target != requested:
            continue
        if target not in repositories:
            raise SystemExit(f"No repository path configured for target {target!r} in {CONFIG_PATH}")
        repo = Path(repositories[target]).expanduser().resolve()
        if not (repo / ".git").exists():
            raise SystemExit(f"Configured {target} repository is invalid: {repo}")
        try:
            public_root(repo)
        except ValueError as exc:
            raise SystemExit(str(exc))
        if is_within(repo, ROOT) or is_within(ROOT, repo):
            raise SystemExit(f"Public repository must remain separate from AoP: {repo}")
        contexts[target] = (repo, list(spec.get("skills", [])))
    return manifest, state, contexts


def classify(aop_hash: str, public_hash: str, base_hash: str | None) -> str:
    if base_hash is None:
        return "untracked-equal" if aop_hash == public_hash else "untracked-different"
    if aop_hash == public_hash:
        return "equal"
    aop_changed = aop_hash != base_hash
    public_changed = public_hash != base_hash
    if aop_changed and public_changed:
        return "conflict"
    if aop_changed:
        return "aop-ahead"
    if public_changed:
        return "public-ahead"
    return "equal"


def selected_targets(requested: str, contexts: dict) -> list[str]:
    if requested == "all":
        return sorted(contexts)
    if requested not in contexts:
        raise SystemExit(f"Unknown target {requested!r}; choose from all, {', '.join(sorted(contexts))}")
    return [requested]


def skill_status(aop, public, name, base, command, onboard=False):
    validate_skill(aop, name)
    safety_scan(aop)
    if not public.exists():
        if command == 'export' and onboard and base is None:
            return 'new-public'
        raise ValueError(f'{name}: missing public package; new packages require export --onboard and no existing baseline')
    validate_skill(public, name)
    safety_scan(public)
    status = classify(digest_tree(aop), digest_tree(public), base)
    if command != 'status' and status not in {'equal', 'untracked-equal', 'aop-ahead' if command == 'export' else 'public-ahead'}:
        raise ValueError(f'{name}: refusing {status}; reconcile or use the correct direction')
    return status


def audit_release(source, names):
    """Audit only the prospective release, so missing allowlisted companions fail."""
    audit = runpy.run_path(str(SOURCE_ROOT / 'skill-library-audit/scripts/audit_library.py'))['audit']
    with tempfile.TemporaryDirectory(prefix='skill-release-audit-') as tmp:
        staged = Path(tmp)
        for name in names:
            shutil.copytree(source / name, staged / name, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
        report = audit(staged, names)
        if report['exitCode']:
            raise ValueError('Release resource audit failed: ' + json.dumps(report['errors'] + report['incomplete']))


def sync_support_files(mapping, repo, target, state, command, write):
    """Synchronize only named adapter files, with the same conflict rules as skills."""
    baselines = state.setdefault("files", {})
    failed, changed = False, False
    for public_rel, source_rel in mapping.items():
        source, public = ROOT / source_rel, repo / public_rel
        try:
            if not is_within(source, ROOT) or not is_within(public, repo):
                raise ValueError("Support file must stay inside its repository")
            if source.is_symlink() or public.is_symlink():
                raise ValueError("Support file must not be a symlink")
            if not source.is_file() or (public.exists() and not public.is_file()):
                raise ValueError("Invalid support file")
            safety_scan(source)
            if public.exists():
                safety_scan(public)
            local_hash = hashlib.sha256(source.read_bytes()).hexdigest()
            public_hash = hashlib.sha256(public.read_bytes()).hexdigest() if public.exists() else None
            key = f"{target}/{public_rel}"
            base = baselines.get(key)
            status = "aop-ahead" if public_hash is None and base is None else classify(local_hash, public_hash, base)
            print(f"  adapter {public_rel}: {status}")
            if status in {"equal", "untracked-equal"}:
                if write and baselines.get(key) != local_hash:
                    baselines[key] = local_hash
                    changed = True
                continue
            if status in {"conflict", "untracked-different"}:
                raise ValueError("No safe common base or both sides changed; review and merge manually")
            if command == "status":
                continue
            permitted = (command == "export" and status == "aop-ahead") or (
                command == "import" and status == "public-ahead" and public_hash is not None)
            if not permitted:
                raise ValueError("Wrong change direction or deleted public adapter; review manually")
            if write:
                incoming, destination = (source, public) if command == "export" else (public, source)
                destination.parent.mkdir(parents=True, exist_ok=True)
                staged = destination.with_name(destination.name + ".sync-new")
                if os.path.lexists(staged):
                    raise ValueError(f"Temporary file already exists: {staged}")
                with staged.open("xb") as handle:
                    handle.write(incoming.read_bytes())
                staged.replace(destination)
                baselines[key] = hashlib.sha256(destination.read_bytes()).hexdigest()
                changed = True
                print(f"    {command.upper()}ED")
            else:
                print("    preview only; add --write after review")
        except ValueError as exc:
            print(f"ERROR adapter {public_rel}: {exc}")
            failed = True
    return failed, changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("status", "export", "import"))
    parser.add_argument("--target", default="all")
    parser.add_argument("--write", action="store_true", help="perform copies; otherwise preview only")
    parser.add_argument("--onboard", action="store_true", help="explicitly create newly allowlisted public packages without a prior baseline")
    args = parser.parse_args()
    if args.command == "status" and args.write:
        parser.error("status is always read-only")

    if args.onboard and args.command != 'export':
        parser.error('--onboard is only valid for export')
    manifest, state, contexts = load_context(args.target)
    state_skills = state.setdefault("skills", {})
    failed = False
    state_changed = False

    # Validate every selected release and change direction before the first write.
    if args.command != 'status':
        try:
            for target in selected_targets(args.target, contexts):
                repo, skills = contexts[target]
                for skill in skills:
                    skill_status(SOURCE_ROOT / skill, public_root(repo) / skill, skill,
                                 state_skills.get(f'{target}/{skill}'), args.command, args.onboard)
                audit_release(SOURCE_ROOT if args.command == 'export' else public_root(repo), skills)
                bad, _ = sync_support_files(manifest.get('supportFiles', {}), repo, target,
                                            state, args.command, False)
                if bad:
                    raise ValueError(f'{target}: support-file preflight failed')
        except (ValueError, OSError) as exc:
            print(f'REFUSED before writing: {exc}')
            return 1

    for target in selected_targets(args.target, contexts):
        repo, skills = contexts[target]
        print(f"[{target}] {repo}")
        adapter_failed, adapter_changed = sync_support_files(
            manifest.get("supportFiles", {}), repo, target, state, args.command, args.write)
        failed = failed or adapter_failed
        state_changed = state_changed or adapter_changed
        for skill in skills:
            aop = SOURCE_ROOT / skill
            public = public_root(repo) / skill
            try:
                status = skill_status(aop, public, skill, state_skills.get(f'{target}/{skill}'), args.command, args.onboard)
            except ValueError as exc:
                print(f"ERROR {skill}: {exc}")
                failed = True
                continue

            aop_hash = digest_tree(aop)
            public_hash = digest_tree(public) if public.exists() else None
            key = f"{target}/{skill}"
            base_hash = state_skills.get(key)
            print(f"  {skill}: {status}")

            if status == "untracked-equal":
                if args.write and args.command in {"export", "import"}:
                    state_skills[key] = aop_hash
                    state_changed = True
                    print("    initialized synchronization hash")
                continue
            if status == "untracked-different":
                print("    REFUSED: no synchronization base and copies differ; reconcile manually first")
                failed = True
                continue
            if status == "conflict":
                print("    REFUSED: both AoP and public copy changed; merge manually in AoP")
                failed = True
                continue
            if status == "equal":
                if args.write and base_hash != aop_hash:
                    state_skills[key] = aop_hash
                    state_changed = True
                continue

            permitted = (args.command == "export" and status in {"aop-ahead", "new-public"}) or (
                args.command == "import" and status == "public-ahead"
            )
            if args.command == "status":
                continue
            if not permitted:
                wanted = "import" if status == "public-ahead" else "export"
                print(f"    REFUSED: run {wanted} for this change direction")
                failed = True
                continue

            source, destination = (aop, public) if args.command == "export" else (public, aop)
            for change in file_changes(destination, source):
                print(f"    {change}")
            if args.write:
                replace_tree(source, destination)
                synced_hash = digest_tree(destination)
                if synced_hash != digest_tree(source):
                    raise RuntimeError(f"Post-copy hash mismatch for {skill}")
                state_skills[key] = synced_hash
                state_changed = True
                print(f"    {args.command.upper()}ED")
            else:
                print("    preview only; add --write after review")

    if state_changed:
        write_json(STATE_PATH, state)
        print(f"Updated {STATE_PATH}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
