"""Prepare a changelog for the mod portal's Change List box (TinyMCE) and write the snippet that fills it.

Skill: mod-portal-changelog. The HTML is flat on purpose: only h2, h3, p, ul, li and strong, no styles, no nested
lists. A nested bullet pasted into that editor merged into its parent, so a sub-bullet becomes its own bullet; write
its subject into the text ("- London: ...").

    python changelog_portal.py <portal.md> --out-dir <scratchpad> [--full <full changelog.md>] [--mod-name NAME] [--replace]

Writes <stem>.html and <stem>_fill.js into --out-dir, which must be outside this repo. The snippet only fills the box;
nothing here presses Submit.
Exit: 0 ready; 1 over the limit, or the bugfix section differs from --full (no files written); 2 bad arguments.
"""
import argparse
import html
import html.entities
import json
import re
import sys
from pathlib import Path

LIMIT = 10000
REPO = Path(__file__).resolve().parents[4]
UNCONFIRMED = re.compile(r"not yet confirmed|not confirmed|beta testing|untested", re.I)

FILL_JS = r"""(() => {
  const html = __HTML__;
  const expectedLength = __LENGTH__, expectedHash = __HASH__, expectedName = __NAME__, replace = __REPLACE__;
  const refuse = (why) => JSON.stringify({ok: false, refused: why});
  let hash = 0;
  for (let i = 0; i < html.length; i++) hash = (hash * 31 + html.charCodeAt(i)) | 0;
  if (html.length !== expectedLength || hash !== expectedHash) return refuse('the snippet text changed in transit: read the file again and pass it unchanged');
  if (!/\/mods\/details\/\d+\/edit\/?$/.test(location.pathname)) return refuse('not a mod edit page: ' + location.pathname);
  const nameField = document.getElementById('mod-name');
  const modName = nameField ? nameField.value : null;
  if (modName !== expectedName) return refuse('the page is for ' + modName + ', expected ' + expectedName);
  const box = window.tinymce && tinymce.get('mod-change-list');
  const description = window.tinymce && tinymce.get('mod-description');
  if (!box || !description) return refuse('the Change List or Description editor is missing: the page changed, stop and report');
  const before = box.getContent().length;
  if (before !== 0 && !replace) return refuse('the box already holds ' + before + ' characters: rebuild with --replace only if the owner wants it replaced');
  const descriptionBefore = description.getContent();
  box.setContent(html);
  box.setDirty(true);
  box.dispatch('change');
  box.save();
  const body = box.getBody();
  const stored = box.getContent();
  const unchanged = description.getContent() === descriptionBefore;
  const visibility = document.getElementById('mod-visibility');
  return JSON.stringify({
    ok: stored.length <= __LIMIT__ && unchanged,
    modName,
    visibility: visibility ? visibility.options[visibility.selectedIndex].text : null,
    storedChars: stored.length,
    visibleChars: body.textContent.length,
    h2: body.querySelectorAll('h2').length,
    h3: body.querySelectorAll('h3').length,
    li: body.querySelectorAll('li').length,
    strong: body.querySelectorAll('strong').length,
    textareaChars: document.getElementById('mod-change-list').value.length,
    descriptionUnchanged: unchanged,
  });
})()
"""


def inline(text):
    return re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", html.escape(text, quote=False))


def to_html(text):
    """Return the flat HTML and the sub-bullets it flattened."""
    parts, flattened = [], []
    in_list = False
    for line in text.splitlines():
        if not line.strip():
            continue
        bullet = re.match(r"( *)- (.*)", line)
        if bullet:
            if not in_list:
                parts.append("<ul>")
                in_list = True
            if bullet.group(1):
                flattened.append(bullet.group(2))
            parts.append("<li>%s</li>" % inline(bullet.group(2)))
            continue
        if in_list:
            parts.append("</ul>")
            in_list = False
        heading = re.match(r"(#+) (.*)", line)
        if heading:
            tag = "h3" if len(heading.group(1)) == 3 else "h2"
            parts.append("<%s>%s</%s>" % (tag, inline(heading.group(2)), tag))
        else:
            parts.append("<p>%s</p>" % inline(line))
    if in_list:
        parts.append("</ul>")
    return "\n".join(parts), flattened


def stored_length(body):
    """Length after TinyMCE stores it: non-ASCII becomes a named entity (an em dash is &mdash;, +6; measured 2026-11-07)."""
    extra = 0
    for char in body:
        name = html.entities.codepoint2name.get(ord(char))
        if name and ord(char) > 127:
            extra += len(name) + 1
    return len(body) + extra


def visible_length(body):
    return len(html.unescape(re.sub(r"<[^>]+>", "", body)).replace("\n", ""))


def section(text, title):
    lines, inside = [], False
    for line in text.splitlines():
        if line.startswith("## "):
            inside = line[3:].strip() == title
            continue
        if inside and line.strip():
            lines.append(line.rstrip())
    return lines


def utf16_hash(text):
    """Length and hash in UTF-16 units, the same values the snippet computes in the page."""
    units = text.encode("utf-16-le")
    value = 0
    for i in range(0, len(units), 2):
        value = (value * 31 + int.from_bytes(units[i:i + 2], "little")) & 0xFFFFFFFF
    return len(units) // 2, value - (1 << 32) if value >= (1 << 31) else value


def fill_js(body, mod_name, replace):
    length, value = utf16_hash(body)
    snippet = FILL_JS.replace("__LENGTH__", str(length)).replace("__HASH__", str(value))
    snippet = snippet.replace("__NAME__", json.dumps(mod_name)).replace("__REPLACE__", "true" if replace else "false")
    snippet = snippet.replace("__LIMIT__", str(LIMIT))
    return snippet.replace("__HTML__", json.dumps(body))


def main(argv=None):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description="Prepare a changelog for the mod portal's Change List box.")
    parser.add_argument("source", help="the changelog markdown to put in the box")
    parser.add_argument("--out-dir", required=True, help="where to write the HTML and the snippet, outside this repo")
    parser.add_argument("--full", help="the full changelog; its bugfix section must match the source word for word")
    parser.add_argument("--mod-name", default="Age of Pirates", help="the snippet refuses a page with another mod name")
    parser.add_argument("--replace", action="store_true", help="let the snippet replace text already in the box")
    args = parser.parse_args(argv)

    out_dir = Path(args.out_dir).resolve()
    if out_dir == REPO or REPO in out_dir.parents:
        print("REFUSED: --out-dir is inside the repo. Scratch output goes to the session scratchpad.")
        return 2

    source = Path(args.source)
    text = source.read_text(encoding="utf-8")
    body, flattened = to_html(text)
    stored = stored_length(body)
    print("html chars %d | stored by the editor %d of %d | visible text %d | bullets %d | em dashes %d"
          % (len(body), stored, LIMIT, visible_length(body), body.count("<li>"), body.count("—")))
    for line in flattened:
        print("WARN sub-bullet became its own bullet, check it names its subject: " + line)
    for line in text.splitlines():
        if UNCONFIRMED.search(line):
            print("WARN goes public, tell the owner: " + line.strip())

    failed = False
    if stored > LIMIT:
        print("OVER THE LIMIT by %d characters: shorten the source." % (stored - LIMIT))
        failed = True
    if args.full:
        ours = section(text, "Bugfixes")
        theirs = section(Path(args.full).read_text(encoding="utf-8"), "Bugfixes")
        for line in theirs:
            if line not in ours:
                print("BUGFIX MISSING from the source: " + line)
                failed = True
        for line in ours:
            if line not in theirs:
                print("BUGFIX NOT in the full changelog: " + line)
                failed = True
    if failed:
        return 1

    out_dir.mkdir(parents=True, exist_ok=True)
    html_path = out_dir / (source.stem + ".html")
    js_path = out_dir / (source.stem + "_fill.js")
    html_path.write_text(body, encoding="utf-8", newline="\n")
    js_path.write_text(fill_js(body, args.mod_name, args.replace), encoding="utf-8", newline="\n")
    print("wrote " + str(html_path))
    print("wrote " + str(js_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
