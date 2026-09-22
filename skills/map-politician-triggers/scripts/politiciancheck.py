#!/usr/bin/env python
"""Audit a random map's consulate politician switcher family.

    python politiciancheck.py randmaps/zpistanbulb.xs

Checks, in the order they bite:
  1. every Activate_* switcher fires the right balance/returner events
  2. the three balance/returner triggers are actually defined
  3. every switcher is armed by a Fire Event in Human_Check_Plr
  4. no rmTriggerID lookup lacks an rmCreateTrigger (those resolve to -1)
  5. brace balance and line endings

Exit code is non-zero if anything in 1-4 fails.
"""
import re
import sys

# Asian consulate swaps do not touch the Italian shipments, so they only need
# the returner. Faction big buttons zero DEShipItalianVillager /
# DEShipItalianFishingBoat and must repay them. See SKILL.md Rule 0.
RETURNER = 'Cheat_Returner'
ITALIAN = ['Italian_Vilager_Balance', 'Italian_Gondola_Balance']
ASIAN_MARKERS = ('Japan', 'China', 'India', 'Khmer', 'Chinese', 'Japanese', 'Indians')


def norm(name):
    """rmTriggerID normalises spaces to underscores. Casing is NOT normalised."""
    return name.replace(' ', '_')


def body_after(src, head, name):
    """Body from `head` to that trigger's own rmSetTriggerLoop."""
    i = src.index(head)
    j = src.find('rmSetTriggerLoop', i)
    return (name, src[i + len(head):j] if j > i else '')


def switcher_bodies(src):
    """(name, body) for each Activate_* switcher.

    Two idioms, and they must not be mixed. In the pre-declare idiom every
    trigger is created at the top of the loop, so a bare rmCreateTrigger line
    is followed by an UNRELATED trigger's body - reading it would report
    nonsense. When any rmSwitchToTrigger("Activate_...") exists, that form is
    authoritative and bare creates are ignored.
    """
    switched = [(m.group(1), m.group(0)) for m in re.finditer(
        r'rmSwitchToTrigger\(rmTriggerID\("(Activate_[^"]+?)"\s*\+\s*\w+\)\);', src)]
    if switched:
        return [body_after(src, head, name) for name, head in switched]
    return [body_after(src, m.group(0), norm(m.group(1))) for m in re.finditer(
        r'rmCreateTrigger\("(Activate [^"]+?)"\s*\+\s*\w+\);', src)]


def human_check_body(src):
    """The arming trigger's body, honouring the same idiom split."""
    for pat in (r'rmSwitchToTrigger\(rmTriggerID\("Human_Check_Plr"\s*\+\s*\w+\)\);',
                r'rmCreateTrigger\("Human Check Plr"\s*\+\s*\w+\);'):
        m = re.search(pat, src)
        if m:
            # the arming trigger fires many events; run to its Active/Loop tail
            i = m.end()
            j = re.search(r'rmSetTriggerPriority', src[i:])
            return src[i:i + j.start()] if j else src[i:]
    return None


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    raw = open(path, 'rb').read()
    src = raw.decode('utf-8', 'replace')
    crlf = raw.count(b'\r\n')
    lf = raw.count(b'\n') - crlf
    fails = 0

    created = {norm(m) for m in re.findall(r'rmCreateTrigger\("([^"]+?)"', src)}
    looked = {norm(m) for m in re.findall(r'rmTriggerID\("([^"]+?)"', src)}

    print('== switchers and what they fire ==')
    switchers = switcher_bodies(src)
    if not switchers:
        print('  (no Activate_* switcher found - map has no politician family)')
    for name, body in switchers:
        fires = re.findall(r'rmTriggerID\("([A-Za-z_]+?)"', body)
        asian = any(k in name for k in ASIAN_MARKERS)
        want = [RETURNER] if asian else ITALIAN + [RETURNER]
        missing = [w for w in want if w not in fires]
        kind = 'asian ' if asian else 'faction'
        if missing:
            fails += 1
            print('  FAIL %s %-32s missing %s' % (kind, name, ', '.join(missing)))
        else:
            print('  ok   %s %-32s %s' % (kind, name, ', '.join(fires)))

    print('\n== balance/returner definitions ==')
    for t in ITALIAN + [RETURNER]:
        if t in created:
            print('  ok   %s defined' % t)
        elif any(t in b for _, b in switchers):
            fails += 1
            print('  FAIL %s is fired but never created (rmTriggerID -> -1)' % t)
        else:
            print('  --   %s absent (and never fired)' % t)

    print('\n== arming: Fire Event inside Human_Check_Plr ==')
    hc = human_check_body(src)
    if hc is None:
        print('  (no Human_Check_Plr found)')
    else:
        armed = set(re.findall(r'rmTriggerID\("(Activate_[A-Za-z_]+?)"', hc))
        for name, _ in switchers:
            if name in armed:
                print('  ok   %s armed' % name)
            else:
                fails += 1
                print('  FAIL %s never armed - it can never fire' % name)

    print('\n== lookups with no rmCreateTrigger (resolve to -1) ==')
    missing = sorted(looked - created)
    if not missing:
        print('  none')
    for m in missing:
        fails += 1
        near = [c for c in created if c.lower() == m.lower()]
        hint = '  <- casing differs from %s' % near[0] if near else ''
        print('  FAIL %s%s' % (m, hint))

    braces = src.count('{') - src.count('}')
    print('\n== file ==')
    print('  braces %+d %s' % (braces, '(balanced)' if braces == 0 else '(UNBALANCED)'))
    print('  CRLF=%d LF=%d' % (crlf, lf))
    if braces:
        fails += 1

    print('\n%s' % ('FAILURES: %d' % fails if fails else 'all politician checks passed'))
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
