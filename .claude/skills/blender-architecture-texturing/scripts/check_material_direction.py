"""Validate per-reader material-direction observations; never infer art roles."""
import argparse
import json
import math
from pathlib import Path


def check(rows, tolerance=15.0):
    problems=[];checked=0;unassessed=[]
    for row in rows:
        name=row.get('face','<missing face>')
        if row.get('unassessed'):
            unassessed.append({'face':name,'reason':row['unassessed']});continue
        try:
            expected=row['expected'];actual=row['observed']
            if len(expected)!=3 or len(actual)!=3:raise ValueError('vectors need three components')
            if not all(math.isfinite(x) for x in expected+actual):raise ValueError('nonfinite vector')
            den=math.sqrt(sum(x*x for x in expected)*sum(x*x for x in actual))
            if den<1e-12:raise ValueError('zero direction')
            dot=sum(a*b for a,b in zip(expected,actual))/den
            if not row.get('signed',False):dot=abs(dot)
            angle=math.degrees(math.acos(max(-1,min(1,dot))))
            checked+=1
            if angle>tolerance:problems.append({'face':name,'angle':angle,'role':row.get('role'),'error':'direction'})
        except (KeyError,ValueError,TypeError) as exc:
            problems.append({'face':name,'error':str(exc)})
    return {'status':'FAIL' if problems or not checked else 'INCOMPLETE' if unassessed else 'PASS',
            'checked':checked,'unassessed':unassessed,'problems':problems,'tolerance_degrees':tolerance}


if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('input',type=Path);ap.add_argument('--out',type=Path);ap.add_argument('--tolerance',type=float,default=15)
    args=ap.parse_args();data=json.loads(args.input.read_text(encoding='utf-8'));report=check(data['observations'],args.tolerance)
    text=json.dumps(report,indent=2)
    if args.out:args.out.write_text(text,encoding='utf-8')
    print(text);raise SystemExit(0 if report['status']=='PASS' else 2 if report['status']=='INCOMPLETE' else 1)
