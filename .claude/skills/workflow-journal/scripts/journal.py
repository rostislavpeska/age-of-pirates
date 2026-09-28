"""Shared lesson journal for agents doing 3D work (Claude, GPT Astra, others).

One JSON record per line in .claude/skills/JOURNAL.jsonl. Records are written the
moment a lesson happens; a later distillation pass groups the open ones by skill and
turns repeated, evidenced lessons into skill edits.

  python journal.py add --agent claude --stage atlas --kind correction \
      --skills aoe-uv-atlas-export --lesson "..." --evidence "..." [--cost ...] [--project korean-tc] [--repeats ID]
  python journal.py list [--open] [--skill S] [--stage S] [--agent A] [--project P]
  python journal.py digest [--skill S]      # open records grouped by skill (Markdown)
  python journal.py mark ID distilled --into blender-uv-conjoin/SKILL.md
  python journal.py mark ID rejected --note "why"
"""
import argparse, datetime, json, os, sys
from pathlib import Path

SKILLS = Path(__file__).resolve().parents[2]
PATH = SKILLS / 'JOURNAL.jsonl'
STAGES = ('modeling', 'unwrap', 'conjoin', 'ao', 'atlas', 'baking', 'texturing', 'export', 'review', 'tooling')
KINDS = ('correction', 'failure', 'confirmed', 'measurement', 'idea')
STATUSES = ('open', 'distilled', 'rejected')


def load(path=PATH):
    p = Path(path)
    if not p.exists():
        return []
    return [json.loads(line) for line in p.read_text(encoding='utf-8').splitlines() if line.strip()]


def _save(rows, path):
    tmp = Path(str(path) + '.tmp')
    tmp.write_text(''.join(json.dumps(r, ensure_ascii=False) + '\n' for r in rows), encoding='utf-8')
    os.replace(tmp, path)


def add(agent, stage, kind, skills, lesson, evidence, cost='', project='', repeats='', date=None, path=PATH):
    """Validate and append one record; returns it. Ids are date-agent-n, so agents never collide."""
    agent = agent.strip().lower()
    if not agent or not lesson.strip() or not evidence.strip():
        raise ValueError('agent, lesson and evidence are required (no evidence, no lesson)')
    if stage not in STAGES:
        raise ValueError(f'stage must be one of {STAGES}')
    if kind not in KINDS:
        raise ValueError(f'kind must be one of {KINDS}')
    skills = [s.strip() for s in (skills.split(',') if isinstance(skills, str) else skills) if s.strip()]
    unknown = [s for s in skills if not s.startswith('new:') and not (SKILLS / s / 'SKILL.md').is_file()]
    if unknown:
        raise ValueError(f'unknown skills {unknown}; name an existing package or use new:<name>')
    rows = load(path)
    if repeats and repeats not in {r['id'] for r in rows}:
        raise ValueError(f'--repeats {repeats} is not a journal id')
    date = date or datetime.date.today().isoformat()
    n = 1 + sum(1 for r in rows if r['date'] == date and r['agent'] == agent)
    rec = dict(id=f'{date}-{agent}-{n:02d}', date=date, agent=agent, project=project, stage=stage, kind=kind,
               skills=skills, lesson=lesson.strip(), evidence=evidence.strip(), cost=cost.strip(),
               repeats=repeats, status='open', distilled_into='', note='')
    with open(path, 'a', encoding='utf-8') as f:
        f.write(json.dumps(rec, ensure_ascii=False) + '\n')
    return rec


def select(rows, open_only=False, skill='', stage='', agent='', project=''):
    return [r for r in rows if (not open_only or r['status'] == 'open') and (not skill or skill in r['skills'])
            and (not stage or r['stage'] == stage) and (not agent or r['agent'] == agent)
            and (not project or r['project'] == project)]


def digest(rows, skill=''):
    """Open records grouped by skill. A skill with an owner correction or a repeated lesson is a candidate."""
    groups = {}
    for r in select(rows, open_only=True, skill=skill):
        for s in r['skills'] or ['(no skill)']:
            groups.setdefault(s, []).append(r)
    repeated = {r['repeats'] for r in rows if r['repeats']}
    out = ['# Journal digest (open records)', '']
    for s in sorted(groups, key=lambda k: -len(groups[k])):
        rs = groups[s]
        flag = any(r['kind'] == 'correction' for r in rs) or any(r['id'] in repeated or r['repeats'] for r in rs)
        out.append(f'## {s} - {len(rs)} open' + (' - DISTILL CANDIDATE' if flag else ''))
        for r in rs:
            rep = f' (repeats {r["repeats"]})' if r['repeats'] else ''
            out.append(f'- `{r["id"]}` {r["kind"]}/{r["stage"]}{rep}: {r["lesson"]}')
            out.append(f'  - evidence: {r["evidence"]}' + (f' | cost: {r["cost"]}' if r['cost'] else ''))
        out.append('')
    return '\n'.join(out)


def mark(rid, status, into='', note='', path=PATH):
    if status not in STATUSES:
        raise ValueError(f'status must be one of {STATUSES}')
    if status == 'distilled' and not into:
        raise ValueError('distilled needs --into (the skill file that now holds the lesson)')
    rows = load(path)
    hit = [r for r in rows if r['id'] == rid]
    if not hit:
        raise ValueError(f'no record {rid}')
    hit[0].update(status=status, distilled_into=into, note=note)
    _save(rows, path)
    return hit[0]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--file', default=str(PATH))
    sub = ap.add_subparsers(dest='cmd', required=True)
    a = sub.add_parser('add')
    for k in ('agent', 'stage', 'kind', 'lesson', 'evidence'):
        a.add_argument('--' + k, required=True)
    a.add_argument('--skills', default='')
    for k in ('cost', 'project', 'repeats'):
        a.add_argument('--' + k, default='')
    li = sub.add_parser('list')
    li.add_argument('--open', action='store_true')
    for k in ('skill', 'stage', 'agent', 'project'):
        li.add_argument('--' + k, default='')
    d = sub.add_parser('digest')
    d.add_argument('--skill', default='')
    m = sub.add_parser('mark')
    m.add_argument('id')
    m.add_argument('status', choices=STATUSES)
    m.add_argument('--into', default='')
    m.add_argument('--note', default='')
    args = ap.parse_args(argv)
    try:
        if args.cmd == 'add':
            rec = add(args.agent, args.stage, args.kind, args.skills, args.lesson, args.evidence,
                      args.cost, args.project, args.repeats, path=args.file)
            print('ADDED', rec['id'])
        elif args.cmd == 'list':
            for r in select(load(args.file), args.open, args.skill, args.stage, args.agent, args.project):
                print(f'{r["id"]} [{r["status"]}] {r["kind"]}/{r["stage"]} {",".join(r["skills"])}: {r["lesson"]}')
        elif args.cmd == 'digest':
            print(digest(load(args.file), args.skill))
        else:
            r = mark(args.id, args.status, args.into, args.note, path=args.file)
            print('MARKED', r['id'], r['status'])
    except ValueError as e:
        sys.exit(f'journal: {e}')


if __name__ == '__main__':
    main()
