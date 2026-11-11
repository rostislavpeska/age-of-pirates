"""The test-only marker: a line carrying AOP-TEST-ONLY is a test hook that must be removed before ANY export, beta or
production. make_zip.py refuses to build while one is left in a file it would zip, and prezip_check.py blocks on it.

Owner, 2026-10-19 (a zpHCUnlockTest placement for player 1 sat in the shipped Burma map): "flag as test unit to be
removed before exporting to Beta or production - maybe also specific pattern which is then catched by test before
export to zip". Put the marker in a comment on the test lines themselves:

    // AOP-TEST-ONLY: <what it is, who/when>; remove before a beta or prod export        (.xs)
    <!-- AOP-TEST-ONLY: <what it is, who/when>; remove before a beta or prod export -->  (.xml and the other XML files)

Only text files the game reads are scanned, so a binary that happens to hold the bytes is never flagged."""
import os

TEST_ONLY_MARK = "AOP-TEST-ONLY"
TEXT_EXT = {".xs", ".xml", ".material", ".tactics", ".lgt", ".particle", ".set", ".xaml", ".personality", ".txt"}


def marked_lines(rel, read):
    """rel: posix path inside the mod; read() -> bytes. Returns 'path:line: text' for every marked line."""
    if os.path.splitext(rel)[1].lower() not in TEXT_EXT:
        return []
    data = read()
    if TEST_ONLY_MARK.encode() not in data:
        return []
    lines = data.decode("utf-8", "replace").splitlines()
    return ["%s:%d: %s" % (rel, i, ln.strip()[:140]) for i, ln in enumerate(lines, 1) if TEST_ONLY_MARK in ln]
