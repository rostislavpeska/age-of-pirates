"""Load the consumer's page contract; reusable skills contain no game sizes."""
import json
from pathlib import Path
def load(path,subproject=None):
    raw=json.loads(Path(path).read_text(encoding='utf-8-sig'))
    out={k:v for k,v in raw.items() if k!='subprojects'}
    if subproject:
        def resolve(name,seen):
            if name in seen:raise ValueError('Profile inheritance cycle')
            if name not in raw.get('subprojects',{}):raise ValueError('Unknown subproject')
            part=dict(raw['subprojects'][name]);parent=part.pop('extends',None)
            merged=resolve(parent,seen|{name}) if parent else {}
            merged.update(part);return merged
        out.update(resolve(subproject,set()));out['subproject']=subproject
    if not out.get('page_sizes') or not isinstance(out.get('square_only'),bool):raise ValueError('Missing page policy')
    return out
def validate_page(profile,width,height):
    return (not profile['square_only'] or width==height) and width in profile['page_sizes'] and height in profile['page_sizes']
