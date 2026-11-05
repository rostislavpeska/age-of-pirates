"""The missed/double V inversion must fail even though density is identical."""
import hashlib,json,sys
from pathlib import Path
import numpy as np
import pytest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from gr2_uv_contract import from_author,check
from gr2_uv_convention import blender_to_gr2_uv

def fixture(tmp_path):
    author=[[.125,.25],[.875,.25],[.125,.75]]
    vertices=[dict(p=p,uv=u) for p,u in zip([[0,0,0],[1,0,0],[0,1,0]],author)]
    part=dict(material='Wood',vertices=vertices,faces=[[0,1,2]])
    payload=dict(materials={'Wood':{'runtime_name':'mata'}},intact=[part],damaged=[part])
    manifest=dict(convention='raw_gr2=(author_u,1-author_v)',expected=from_author(payload))
    path=tmp_path/'source.json';path.write_text(json.dumps(manifest))
    config=dict(path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    mesh=dict(mats=['mata'],pos=np.array([v['p'] for v in vertices]),
              uv=np.array([[.125,.75],[.875,.75],[.125,.25]]),tris=np.array([[0,1,2]]))
    return config,dict(render=[mesh])

@pytest.mark.parametrize('stage',['intact','damaged'])
def test_literal_runtime_uv_accepts_correct_and_rejects_missing_or_double_flip(tmp_path,stage):
    config,info=fixture(tmp_path)
    assert check(stage,info,config,tmp_path)[0]
    info['render'][0]['uv'][:,1]=1-info['render'][0]['uv'][:,1]
    assert not check(stage,info,config,tmp_path)[0]

def test_wrong_material_or_source_identity_fails(tmp_path):
    config,info=fixture(tmp_path);info['render'][0]['mats']=['matc']
    assert not check('intact',info,config,tmp_path)[0]
    config['sha256']='0'*64
    assert not check('intact',info,config,tmp_path)[0]

def test_tiled_coordinates_and_no_inplace_mutation():
    author=np.array([[.125,.25],[-.25,1.75],[2,-.5]])
    original=author.copy()
    assert np.array_equal(blender_to_gr2_uv(author),[[.125,.75],[-.25,-.75],[2,1.5]])
    assert np.array_equal(author,original)

@pytest.mark.parametrize('bad',[[1,2],[[1,2,3]],[[float('nan'),1]]])
def test_rejects_invalid_author_data(bad):
    with pytest.raises(ValueError):blender_to_gr2_uv(bad)
