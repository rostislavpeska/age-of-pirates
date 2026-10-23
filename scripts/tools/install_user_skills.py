"""Optional user-scope links to this checkout; never copy or overwrite skills."""
from pathlib import Path
import runpy
import sys


if __name__ == "__main__":
    folder = Path(__file__).resolve().parent
    helper = next(path for path in (folder / "setup_repo_skill_links.py",
                                   folder / "setup_agent_skill_link.py") if path.is_file())
    sys.argv = [str(helper), "--scope", "user", *sys.argv[1:]]
    runpy.run_path(str(helper), run_name="__main__")
