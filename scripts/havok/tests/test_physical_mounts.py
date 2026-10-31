import numpy as np
from scripts.havok.gr2_lint import check_physical_mounts

def fixture():
    world=np.eye(4);world[3,:3]=[0,3,0]
    points=np.array([[x,y,z] for y in [.1,5] for x,z in [(.05,0),(-.05,0),(0,.05),(0,-.05)]])
    info={'bones':[{'name':'bone_flag_civ','world':world}], 'render':[{'pos':points,'bone':np.zeros(8,int),'bone_names':['pole']}]}
    profile={'physical_mounts':[{'bone':'bone_flag_civ','position':[0,3,0],'body':'pole','bottom_y':.1,'top_y':5}]}
    return info,profile

def test_mount_passes_both_states():
    info,p=fixture()
    assert all(check_physical_mounts(s,info,p)[0]['status']=='PASS' for s in ('intact','damaged'))

def test_missing_pole_fails():
    info,p=fixture();info['render'][0]['pos'][:,1]=1
    assert check_physical_mounts('intact',info,p)[0]['status']=='FAIL'

def test_floating_flag_fails():
    info,p=fixture();info['bones'][0]['world'][3,0]=1
    assert check_physical_mounts('intact',info,p)[0]['status']=='FAIL'

def test_roof_assigned_to_pole_body_fails():
    info,p=fixture();info['render'][0]['pos'][0,0]=2
    assert check_physical_mounts('damaged',info,p)[0]['status']=='FAIL'
