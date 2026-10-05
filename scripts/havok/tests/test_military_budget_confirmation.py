"""INC-066: exact owner page budget is equivalent to the small class label."""
import json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import gr2_lint as L

def check(tmp_path,text,model='stable',cls='small'):
 p=tmp_path/'owner.json';p.write_text(json.dumps({'items':[{'id':'owner','text':text}]}))
 return L.class_confirmation({'confirmed_by':'owner'},cls,{'names':[model]},model,store=p)[0]

def test_exact_single_map_budget(tmp_path):
 assert check(tmp_path,'Barracks and stable. Each one 2048 clean UV map.') is True
 assert check(tmp_path,'Stable small class.') is True

def test_no_unrelated_or_ambiguous_confirmation(tmp_path):
 for text in ('Barracks. Each one 2048 clean UV map.',
              'Stable. Each one 2048 + 1024.',
              'Stable. Each one 2048? Maybe two maps.',
              'Stable. Each one 4096.',
              'Stable at 2048 would be nice.',
              'Stable. Each one 2048 and two atlases.'):
  assert check(tmp_path,text) is False,text
 assert check(tmp_path,'Stable. Each one 2048 clean UV map.',cls='large') is False
