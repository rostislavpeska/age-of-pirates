# Provenance and coverage

Packaged in AoP on 2026-09-22. This is local library work; no public export or
third-party redistribution approval is implied. The owning reference texts now
live in this package. Old AoP documentation paths forward here. Original and
packaged SHA-256 hashes are recorded in [sources.json](sources.json).

| Reference | Origin and limits |
| --- | --- |
| Data XML guide | Existing AoP `docs/data_xml_guide.md`, shared portion before the Placement Rules section. Original upstream author/license were not recorded in that file. Tables contain apparent extraction/spacing artifacts; verify doubtful identifiers against installed game data. AoP-specific placement/nugget/map-override observations remain in AoP's original documentation path. |
| RM commands | Existing AoP `docs/rm_commands_reference.md`, dated 2025-11-05, described there as merged official documentation and an existing reference. Its upstream URLs/license were not recorded. Historical guides disagree on total counts, and the text contains mixed signature formatting and suspect entries. No count is presented as complete current-build coverage. |
| XS/AI reference | Existing AoP `docs/ai_reference.xs`; its header attributes updates to the [ESO Community tutorial](https://eso-community.net/viewtopic.php?f=33&t=19871). Preserve its notes: functions/constants are not sorted by game version, and some do not work in older editions. Redistribution terms and current DE coverage remain unverified. |
| UI commands | Existing AoP `docs/command_list.md`; original author, source URL, date and license were not recorded. This is a lookup aid, not a validated current-build API inventory. |
| Map/trigger workflow | New portable summary of AoP's map/trigger workflow, based on its existing guides and RM skills. Deliberately omits factions, record ids, deployment paths and private harness commands. |
| Runtime XML profile | New summary of the existing AoP XML/building profile. Scope is stated explicitly; applicability to another mod/toolchain requires verification. |

Before public redistribution, establish the rights and attribution for copied
third-party material or replace it with an independently authored summary and
source links. Do not silently apply the skill repository's MIT license to texts
whose redistribution terms have not been established. These notes make that work
visible; the static resource audit does not resolve licensing or factual accuracy.

Use exact function/field searches and read context. Compare version-sensitive claims
with the installed build and known-working examples. Do not silently correct an
uncertain signature or promote a reverse-engineered observation to a universal rule.
