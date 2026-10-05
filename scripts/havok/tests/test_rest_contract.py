"""INC-071: cheap checks for observed scene-copy losses, not a physics emulator."""
import sys
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from gr2_lint import check_rest_bounds, check_ground_supports

def model(points):return {'render':[{'pos':np.array(points, dtype=float)}]}

PROFILE={'rest_contract':{'bounds_tolerance_m':.02,'ground_supports':[{'name':'hall-foot','xz_min':[0,0],'xz_max':[1,1]}]}}

def test_displaced_damage_rejected():
    a=model([[0,0,0],[1,7,1]])
    b=model([[0,0,0],[1,14,1]])
    assert check_rest_bounds('damaged',b,a,PROFILE)['status']=='FAIL'

def test_tessellation_difference_can_pass_same_rest_envelope():
    a=model([[0,0,0],[1,7,1]])
    b=model([[0,0,0],[.5,3.5,.5],[1,7,1]])
    assert check_rest_bounds('damaged',b,a,PROFILE)['status']=='PASS'

def test_fence_at_zero_does_not_hide_floating_hall():
    a=model([[0,.38,0],[1,.38,1],[4,0,4]])
    assert check_ground_supports('intact',a,PROFILE)[0]['status']=='FAIL'

def test_grounded_hall_passes():
    a=model([[0,0,0],[1,0,1],[4,0,4]])
    assert check_ground_supports('intact',a,PROFILE)[0]['status']=='PASS'

def test_missing_support_fails():
    assert check_ground_supports('intact',model([[4,0,4]]),PROFILE)[0]['status']=='FAIL'
