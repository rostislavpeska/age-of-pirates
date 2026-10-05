"""Read-only locator/hash verification for the Korean recipe sources and external evidence."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[4]/'scripts'/'tools'))
import local_env  # noqa: E402  this device's AOP_KOREAN_REPO / AOP_KOREAN_ASSETS (config/aop.local.env)

def check(registry, roots):
    rows=[]
    for item in registry['files']:
        p=roots[item['root']]/item['path']
        status='MISSING'
        if p.is_file():
            status='OK' if hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'] else 'CHANGED'
        rows.append({'role':item['role'],'status':status,'path':str(p)})
    return rows

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--korean-root',type=Path,default=local_env.value('AOP_KOREAN_REPO'))
    ap.add_argument('--assets-root',type=Path,default=local_env.value('AOP_KOREAN_ASSETS'))
    args=ap.parse_args()
    if not args.korean_root or not args.assets_root:
        ap.error('AOP_KOREAN_REPO / AOP_KOREAN_ASSETS are not set on this device: python scripts/tools/local_env.py')
    registry=json.loads((Path(__file__).resolve().parents[1]/'recipes.json').read_text(encoding='utf-8'))
    rows=check(registry,{'korean_repo':args.korean_root,'assets':args.assets_root})
    for row in rows:print(f"{row['status']:7} {row['role']}: {row['path']}")
    return 0 if all(r['status']=='OK' for r in rows) else 1

if __name__=='__main__':raise SystemExit(main())
