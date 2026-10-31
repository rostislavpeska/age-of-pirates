"""Validate whole architectural-role coverage, separately from no-leak checks.

Input is a source-bound sampling report from the current complete model. The
required component census is an external hashed artifact bound to the same source.
Its source_parts must be partitioned exactly into covered_roles [{part,role,component}]
and excluded_roles [{part,role,reason}]. The covered component IDs define the report's
required_components. Classification and geometric sampling remain producer responsibilities;
this gate checks source/census identity, evidence completeness and coverage thresholds.
"""
import argparse
import hashlib
import json
from pathlib import Path


def file_sha256(path):
    digest=hashlib.sha256()
    with Path(path).open('rb') as handle:
        for chunk in iter(lambda:handle.read(1024*1024),b''):digest.update(chunk)
    return digest.hexdigest()


def identifiers(value):
    return isinstance(value,list) and bool(value) and all(isinstance(x,str) and bool(x.strip()) for x in value)


def census_components(data, source, errors):
    binding=data.get('census')
    if not isinstance(binding,dict):
        errors.append('External source-bound census is required')
        return None
    try:
        path=Path(binding.get('path',''))
        if not path.is_file() or file_sha256(path)!=binding.get('sha256'):
            raise ValueError('missing or stale census identity')
        census=json.loads(path.read_text(encoding='utf-8'))
        if not isinstance(census,dict) or census.get('schema')!=1:
            raise ValueError('unsupported census schema')
        if (not isinstance(census.get('source'),dict) or not source.get('sha256')
                or census['source'].get('sha256')!=source['sha256']):
            raise ValueError('census belongs to a different source')
        parts=census.get('source_parts')
        if not identifiers(parts) or len(set(parts))!=len(parts):
            raise ValueError('census source_parts missing, empty or duplicated')
        covered,excluded=census.get('covered_roles'),census.get('excluded_roles')
        if not isinstance(covered,list) or not covered or not isinstance(excluded,list):
            raise ValueError('both covered_roles and excluded_roles must be explicitly declared')
        classified=[];components=set()
        for category,rows in [('covered',covered),('excluded',excluded)]:
            for row in rows:
                field='component' if category=='covered' else 'reason'
                if (not isinstance(row,dict) or any(not isinstance(row.get(k),str) or not row[k].strip()
                                                     for k in ['part','role',field])):
                    raise ValueError(f'{category} role requires part, role and {field}')
                classified.append(row['part'])
                if category=='covered':components.add(row['component'])
        if len(classified)!=len(set(classified)):
            raise ValueError('a source part is classified more than once')
        if set(classified)!=set(parts):
            raise ValueError('covered/excluded roles do not exactly partition source_parts')
        return components
    except (OSError,ValueError,TypeError) as exc:
        errors.append('Invalid external census: '+str(exc))
        return None


def validate(data):
    errors = []
    required = data.get('required_components', [])
    if not identifiers(required) or len(set(required)) != len(required):
        errors.append('Required architectural component census missing or duplicated')
        required=[]
    rows = data.get('components', [])
    if not isinstance(rows,list) or any(not isinstance(r,dict) for r in rows):
        errors.append('Component results must be a list of objects')
        rows=[]
    keys = [r.get('id') for r in rows]
    if any(not isinstance(key,str) or not key.strip() for key in keys):
        errors.append('Component results require nonempty string IDs')
        keys=[key for key in keys if isinstance(key,str) and key.strip()]
    if len(set(keys)) != len(keys):
        errors.append('Duplicate component results')
    missing = sorted(set(required) - set(keys))
    if missing:
        errors.append('Unmeasured required components: ' + ', '.join(missing))
    extra=sorted(set(keys)-set(required))
    if extra:
        errors.append('Unexpected component results: '+', '.join(extra))
    threshold = data.get('minimum_fraction', 0.98)
    if type(threshold) not in (int,float) or not 0.98 <= threshold <= 1:
        errors.append('Coverage threshold must be 0.98 to 1')
        threshold = 0.98
    for row in rows:
        if row.get('id') not in required:
            continue
        total, covered = row.get('samples', 0), row.get('covered', -1)
        if type(total) is not int or type(covered) is not int or total <= 0 or not 0 <= covered <= total:
            errors.append(str(row.get('id')) + ': invalid or empty sampling')
        elif covered / total < threshold:
            errors.append(str(row['id']) + ': incomplete role coverage')
        if type(row.get('foreign_reader_conflicts')) is not int or row['foreign_reader_conflicts'] != 0:
            errors.append(str(row.get('id')) + ': unverified or conflicting readers')
    source = data.get('source', {})
    if not isinstance(source,dict):source={}
    try:
        path = Path(source.get('path', ''))
        source_ok=path.is_file() and file_sha256(path)==source.get('sha256')
    except (OSError,TypeError):source_ok=False
    if not source_ok:
        errors.append('Source identity missing or stale')
    expected=census_components(data,source,errors)
    if expected is not None and expected!=set(required):
        errors.append('Required components differ from the bound external census')
    return {'status': 'FAIL' if errors else 'PASS', 'errors': errors,
            'required_components': len(required), 'measured_components': len(rows)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    args = parser.parse_args()
    result = validate(json.loads(args.report.read_text(encoding='utf-8')))
    print(json.dumps(result, indent=2))
    return int(result['status'] != 'PASS')


if __name__ == '__main__':
    raise SystemExit(main())
