"""Expose one .claude/skills/ source to Claude Code, Codex, Cursor, Gemini CLI and Copilot.

Maintained in AoP; public repositories receive reviewed snapshots of this helper.
Python 3.10+. No skill copies, deletion, agent launches or machine-specific paths.
"""
from pathlib import Path
import argparse
import os
import subprocess


ROOT = next(path for path in Path(__file__).resolve().parents if (path / "AGENTS.md").is_file())
ADAPTERS = (".agents", ".claude")


def is_link(path: Path) -> bool:
    return path.is_symlink() or bool(getattr(path.lstat(), "st_file_attributes", 0) & 0x400)


def setup(root: Path = ROOT, *, user_home: Path | None = None, check: bool = False) -> None:
    root = root.resolve()
    source = root / ".claude" / "skills"
    if not source.is_dir() or is_link(source):
        raise SystemExit(f"Expected physical canonical skill directory: {source}")
    if os.path.lexists(root / "skills"):
        raise SystemExit("Unexpected legacy skills/ tree. Review the migration before setup.")
    skills = sorted(path.parent for path in source.glob("*/SKILL.md"))
    if not skills:
        raise SystemExit(f"No skills found in {source}")
    if user_home is None:
        pairs = [(root / ".agents" / "skills", source)]
    else:
        pairs = [(user_home / agent / "skills" / skill.name, skill)
                 for agent in ADAPTERS for skill in skills]

    # Preflight all destinations. Never delete copies or replace unexpected links.
    missing = []
    for link, target in pairs:
        if os.path.lexists(link):
            if not is_link(link) or not link.exists() or not os.path.samefile(link, target):
                raise SystemExit(f"Refusing to replace existing path: {link}. Review it manually.")
        else:
            missing.append((link, target))
    if check and missing:
        raise SystemExit("Missing discovery links; run setup without --check:\n" +
                         "\n".join(str(link) for link, _ in missing))

    for link, target in missing:
        link.parent.mkdir(parents=True, exist_ok=True)
        if os.name == "nt":
            subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(target)],
                           check=True, capture_output=True, text=True)
        else:
            link.symlink_to(os.path.relpath(target, link.parent), target_is_directory=True)

    for link, target in pairs:
        if not os.path.samefile(link, target):
            raise SystemExit(f"Discovery link verification failed: {link}")
        entries = [target / "SKILL.md"] if user_home is not None else sorted(target.glob("*/SKILL.md"))
        for entry in entries:
            if not os.path.samefile(entry, link / entry.relative_to(target)):
                raise SystemExit(f"Skill identity verification failed: {entry}")
    print(f"Verified {len(skills)} skills through {len(pairs)} links; source: {source}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scope", choices=("project", "user"), default="project")
    parser.add_argument("--check", action="store_true", help="verify only; write nothing")
    args = parser.parse_args()
    setup(user_home=Path.home() if args.scope == "user" else None, check=args.check)


if __name__ == "__main__":
    main()
