"""The changelog tool for the mod portal's Change List box: flat HTML, size limit, bugfix match and a fill snippet that
refuses the wrong page and never submits (owner 2026-11-07: "Do NOT submiot anything!!!").

    python -m pytest .claude/skills/mod-portal-changelog/tests -q
"""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

SKILL = Path(__file__).resolve().parents[1]
TOOL = SKILL / "scripts" / "changelog_portal.py"
REPO = Path(__file__).resolve().parents[4]
sys.dont_write_bytecode = True
sys.path.insert(0, str(TOOL.parent))

import changelog_portal  # noqa: E402

SAMPLE = ("# Version 1: Ships & Forts\n\nIntro line.\n\n## Maps\n- **London** — a map.\n  - London: a sub bullet.\n\n"
          "### Updates\n- Other (not yet confirmed in game).\n\n## Bugfixes\n- Fixed one.\n")

# A small stand-in for the page: the real editor's calls, recorded, so the snippet's logic runs without a browser.
PAGE = r"""
const fs = require('fs');
const snippet = fs.readFileSync(process.argv[2], 'utf8');
const state = JSON.parse(process.argv[3]);
const calls = [];
const editor = (content) => ({
  content,
  getContent() { return this.content; },
  setContent(h) { calls.push('setContent'); this.content = h.replace(/—/g, '&mdash;'); },
  setDirty() { calls.push('setDirty'); },
  dispatch(name) { calls.push('dispatch:' + name); },
  save() { calls.push('save'); },
  getBody() {
    const all = this.content;
    return {
      textContent: all.replace(/<[^>]+>/g, '').replace(/\n/g, ''),
      querySelectorAll: (tag) => ({length: (all.match(new RegExp('<' + tag + '>', 'g')) || []).length}),
    };
  },
});
const editors = {'mod-change-list': editor(state.box), 'mod-description': editor('<p>description</p>')};
globalThis.window = globalThis;
globalThis.tinymce = {get: (id) => editors[id]};
globalThis.location = {pathname: state.path};
globalThis.document = {getElementById: (id) => ({
  'mod-name': {value: state.name},
  'mod-visibility': {selectedIndex: 0, options: [{text: 'Public'}]},
  'mod-change-list': {value: editors['mod-change-list'].content},
}[id] || null)};
const result = JSON.parse((0, eval)(snippet));
console.log(JSON.stringify({result, calls, box: editors['mod-change-list'].content,
                            description: editors['mod-description'].content}));
"""


def prepare(tmp_path, text=SAMPLE, *extra):
    source = tmp_path / "notes.md"
    source.write_text(text, encoding="utf-8", newline="\n")
    out = tmp_path / "out"
    run = subprocess.run([sys.executable, str(TOOL), str(source), "--out-dir", str(out), *extra],
                         capture_output=True, text=True, encoding="utf-8")
    return run, out


def run_page(tmp_path, snippet, box="", name="Age of Pirates", path="/mods/details/42687/edit/"):
    node = shutil.which("node")
    if not node:
        pytest.skip("node is not installed here")
    page = tmp_path / "page.cjs"
    page.write_text(PAGE, encoding="utf-8")
    code = tmp_path / "snippet.js"
    code.write_text(snippet, encoding="utf-8")
    state = json.dumps({"box": box, "name": name, "path": path})
    run = subprocess.run([node, str(page), str(code), state], capture_output=True, text=True, encoding="utf-8")
    assert run.returncode == 0, run.stderr
    return json.loads(run.stdout)


def test_html_is_flat_and_uses_only_the_plain_tags():
    body, flattened = changelog_portal.to_html(SAMPLE)
    assert set(re.findall(r"</?(\w+)", body)) == {"h2", "h3", "p", "ul", "li", "strong"}
    assert "<ul>\n<li><strong>London</strong> — a map.</li>\n<li>London: a sub bullet.</li>\n</ul>" in body
    assert flattened == ["London: a sub bullet."]
    assert "Ships &amp; Forts" in body


def test_sizes_match_what_the_editor_measured():
    body = "<p>A &amp; B — C</p>"
    assert changelog_portal.stored_length(body) == len(body) + 6      # em dash stored as &mdash;
    assert changelog_portal.visible_length(body) == len("A & B — C")   # &amp; is one visible character


def test_stored_length_decides_the_limit(tmp_path):
    text = "- " + "—" * 1500 + "\n"       # short as text, over the limit once the editor stores it
    run, out = prepare(tmp_path, text)
    assert run.returncode == 1
    assert "OVER THE LIMIT" in run.stdout
    assert not out.exists()


def test_bugfix_section_must_match_the_full_changelog(tmp_path):
    full = tmp_path / "full.md"
    full.write_text(SAMPLE, encoding="utf-8")
    run, out = prepare(tmp_path, SAMPLE, "--full", str(full))
    assert run.returncode == 0, run.stdout
    full.write_text(SAMPLE + "- Fixed two.\n", encoding="utf-8")
    run, _ = prepare(tmp_path, SAMPLE, "--full", str(full))
    assert run.returncode == 1
    assert "BUGFIX MISSING from the source: - Fixed two." in run.stdout


def test_unconfirmed_wording_and_flattened_bullets_are_reported(tmp_path):
    run, _ = prepare(tmp_path)
    assert run.returncode == 0, run.stdout
    assert "WARN goes public, tell the owner: - Other (not yet confirmed in game)." in run.stdout
    assert "WARN sub-bullet became its own bullet" in run.stdout


def test_output_never_goes_into_the_repo(tmp_path):
    source = tmp_path / "notes.md"
    source.write_text(SAMPLE, encoding="utf-8")
    run = subprocess.run([sys.executable, str(TOOL), str(source), "--out-dir", str(REPO / "docs")],
                         capture_output=True, text=True)
    assert run.returncode == 2
    assert "REFUSED" in run.stdout


def test_snippet_has_no_way_to_submit(tmp_path):
    run, out = prepare(tmp_path)
    assert run.returncode == 0, run.stdout
    snippet = (out / "notes_fill.js").read_text(encoding="utf-8")
    assert not re.search(r"submit|click|fetch|XMLHttpRequest|sendBeacon", snippet, re.I)


def test_snippet_fills_only_the_change_list(tmp_path):
    run, out = prepare(tmp_path)
    assert run.returncode == 0, run.stdout
    body = (out / "notes.html").read_text(encoding="utf-8")
    page = run_page(tmp_path, (out / "notes_fill.js").read_text(encoding="utf-8"))
    assert page["calls"] == ["setContent", "setDirty", "dispatch:change", "save"]
    assert page["box"] == body.replace("—", "&mdash;")
    assert page["description"] == "<p>description</p>"
    result = page["result"]
    assert result["ok"] is True and result["descriptionUnchanged"] is True
    assert result["storedChars"] == changelog_portal.stored_length(body)
    assert result["textareaChars"] == result["storedChars"]
    assert (result["modName"], result["visibility"], result["li"], result["h2"]) == ("Age of Pirates", "Public", 4, 3)


@pytest.mark.parametrize("page_state, why", [
    ({"box": "<p>old</p>"}, "already holds"),
    ({"name": "Another Mod"}, "the page is for Another Mod"),
    ({"path": "/mods/details/42687/"}, "not a mod edit page"),
])
def test_snippet_refuses_and_writes_nothing(tmp_path, page_state, why):
    run, out = prepare(tmp_path)
    assert run.returncode == 0, run.stdout
    page = run_page(tmp_path, (out / "notes_fill.js").read_text(encoding="utf-8"), **page_state)
    assert page["result"]["ok"] is False
    assert why in page["result"]["refused"]
    assert page["calls"] == []


def test_snippet_refuses_text_changed_in_transit(tmp_path):
    run, out = prepare(tmp_path)
    assert run.returncode == 0, run.stdout
    snippet = (out / "notes_fill.js").read_text(encoding="utf-8")
    assert "a map." in snippet
    page = run_page(tmp_path, snippet.replace("a map.", "a mop."))
    assert page["result"]["ok"] is False
    assert "changed in transit" in page["result"]["refused"]
    assert page["calls"] == []


def test_replace_needs_its_flag(tmp_path):
    run, out = prepare(tmp_path, SAMPLE, "--replace")
    assert run.returncode == 0, run.stdout
    page = run_page(tmp_path, (out / "notes_fill.js").read_text(encoding="utf-8"), box="<p>old</p>")
    assert page["result"]["ok"] is True
    assert "old" not in page["box"]
