---
name: mod-portal-changelog
description: Fill the Change List box on the Age of Empires mod portal from a changelog file, through Claude in Chrome, without submitting, and write the Discord release note with the team credits. Use when the owner wants release notes in the portal's editor or for Discord, or a paste into that editor failed.
---

# Mod portal changelog

**Submit is the owner's. Never press it.** Owner, 2026-11-07: "Do NOT submiot anything!!!" Submit publishes on the
public page and uploads any attached zip. Nothing in this route clicks on the page: the agent fills the box by script,
checks it and hands the tab over.

## The page

Edit page: `https://www.ageofempires.com/mods/details/<id>/edit/`. The public Age of Pirates page is id 42687 (the
README links it). Other ids exist (169691 was used on 2026-09-02), so the snippet checks the mod name on the page.

| Field | Element | Rule |
|---|---|---|
| New changelog entry | TinyMCE `mod-change-list` (textarea name `ChangeList`) | The only field this route writes. Caption: "Use this space to prepend a new entry to the Change List." Shows "(10,000 character limit)". |
| Description | TinyMCE `mod-description` | Never touch. The snippet checks it stayed the same. |
| Previous Changes | below the box | "Previous entries are not editable." |
| Mod name, visibility | `mod-name`, `mod-visibility` | Read and report them. |

The editor stores an em dash as `&mdash;`, so the stored text is longer than the source. Whether the server counts
visible text or stored HTML is untested: keep the stored length under the limit.

## The route

1. **Check the browser first.** This needs Claude in Chrome, because only the owner's Chrome is signed in. Without it,
   say "This session cannot control Chrome" and hand off as the global rules say. Follow `chrome-browser` and announce
   the browser use (AGENTS.md rule 11).
2. **Pick the source.** The full record is `docs/changelog_v<version>.md`. If it is over the limit, keep a shortened
   `docs/changelog_v<version>_portal.md`:
   - flat bullets only, with the subject written into each ("- London: ...");
   - the bugfix section word for word, new text never invented;
   - cut in this order: unit stats and costs, mercenary lists, smaller map updates, smaller AI details.
   Tell the owner what was cut.
3. **Prepare it:**

       python .claude/skills/mod-portal-changelog/scripts/changelog_portal.py docs/changelog_v<version>_portal.md \
           --out-dir <scratchpad> --full docs/changelog_v<version>.md

   Exit 1 means fix the source (over the limit, or a bugfix line differs). Each `WARN goes public` line must be named
   to the owner at hand-over. Output goes to the scratchpad; the tool refuses the repo.
4. **Open the page in a new tab** (`tabs_create_mcp`, then `navigate`). A sign-in page means stop: sign-in is the
   owner's. If a site permission is waiting, tell the owner and wait.
5. **Fill it.** Read `<stem>_fill.js` and pass its whole text to `javascript_tool`, unchanged. It refuses and writes
   nothing when the text changed in transit, the page is not an edit page, the mod name differs, an editor is missing
   or the box already holds text. Report a refusal as it is. Use `--replace` only when the owner wants the box replaced.
6. **Check the result it returns:** `ok: true`, `storedChars` equal to the tool's "stored by the editor", the bullet
   count, and `descriptionUnchanged: true`. Then take one screenshot.
7. **Hand over and leave the tab open.** Report the mod name and visibility, the sizes, what was cut and each WARN line.
   Say that a reload loses the text and you can fill it again from the file. Never navigate that tab away: a dialog
   would block the extension.

## Discord release note

For the players in the Age of Pirates Discord. The owner posts it himself, after Submit: its change-list link shows the
new notes only then. Save it as `docs/release_note_v<version>_discord.md`. The accepted example is
`docs/release_note_v7.3_discord.md` (owner's own edit, 2026-11-08).

**Format** (owner 2026-11-08: "Discord does NOT support markdown!!!", then his own version with bold: "bold supported"):
- `**bold**` for the title and for the section names, written in capitals. No `#` headings, no code fences, no other markup.
- `•` bullets, one line each, the subject first ("Danube: only the bridges lead to ...").
- Title: `Age of Pirates <version>: <version name>`, with the name the owner gives the version (7.3: "keep Historical
  maps vol.3 as name of the version").
- Updates and fixes: the main bugfix of the changelog must be in it (7.3: cliff boarding and landing).
- Length: at most about 1,830 characters. His 7.3 draft of 1,909 had to be "72 characters shorter"; the posted one is
  1,825. Measure the file (`len()` of its text) before handing over, and cut words, never whole items.
- Hand it over ready to paste, and say what was cut.

```text
**Age of Pirates <version>: <version name>**

<one sentence: what the release brings>

**NEW MAPS**
• <Map name (place, year)>: <who against whom>. <how to win>.

**NEW CONTENT**
• <Native, unit or building>: <one line>.

**UPDATES AND FIXES**
• <one line per change, the main bugfix included>

**THANK YOU**
• @<handle> for <what they did in this release>

Full change list: https://www.ageofempires.com/mods/details/42687/
```

**Team.** Thank only the members who took part in this release, for what they did in it. Ask the owner who took part;
this table gives the handles, not the guest list. Write the handle exactly as below (lower case, as the owner confirmed:
"the names of the people are correct in the last version").

| Discord handle | Credited in 7.3 for |
|---|---|
| `@superleihwerker` | the new buildings and ships |
| `@vividlyplain` | the Unknown map update |
| `@assertivewall` | the never-ending effort with the AI |
| `@unstoppablestreletsy_yt` | great gameplay videos and continuous support and testing |

The team has more members (owner, 2026-11-08: "I'll tell you other names when they participate on some future
update"). Add each new member here, with the handle exactly as he writes it and what they were credited for.

## Routes that failed (2026-11-07)

| Route | Result |
|---|---|
| Full changelog in the box | 13,105 visible characters, over the limit. |
| Owner pasting formatted text | Bold was lost and nested bullets merged into their parent ("battery towers.St Paul's Cathedral"). |
| HTML placed on the Windows clipboard for the owner to paste | The clipboard bytes checked out, then the owner reported "Nothing works!!!!!". The cause was never found, so this is not a first route. |

## What is proven

- **Run on the real page (2026-11-07, id 42687):** a hand-written snippet with the same four calls (`setContent`,
  `setDirty`, `dispatch('change')`, `save`). Result: 9,153 source characters, 9,363 stored, 7,878 visible, 52 bullets,
  Description unchanged.
- **Replayed from the saved source (2026-11-07):** the tool on `docs/changelog_v7.3_portal.md` wrote HTML byte-identical
  to what went into the box, and predicted the same 9,363 stored and 7,878 visible characters.
- **Tested without a browser:** `python -m pytest .claude/skills/mod-portal-changelog/tests -q` runs the tool and runs
  the snippet against a stand-in page (needs node; skips without it).
- **Generated snippet run on the real page (2026-11-07, id 42687, `--replace`, box empty after a reload):** it returned
  `ok: true` with 9,238 stored and 7,769 visible characters and 51 bullets, all equal to the tool's prediction; Description
  unchanged. The owner then edited the box himself in the same tab, so stop touching the tab once it is handed over.
- **Not proven yet:** what the public page shows after Submit with a box filled this way.

Upload and zip checks: `mod-deploy-check`. An attached zip only sits in the queue until Submit, so each upload attempt is
a real publish.
