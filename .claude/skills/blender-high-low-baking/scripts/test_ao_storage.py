"""INC-120: AO storage is separate from BaseColor/shader application."""
import numpy as np
from check_ao_storage import assess

def test_inc120_white_channel_rejects_measured_window_contacts():
    e=np.array([[255,220],[150,80]])
    assert assess(e,np.full_like(e,255),np.ones_like(e,dtype=bool))['status']=='FAIL'

def test_inc120_reference_contract_keeps_ao_even_with_shaded_basecolor():
    e=np.array([[255,220],[150,80]])
    assert assess(e,e,np.ones_like(e,dtype=bool))['status']=='PASS'

def test_inc120_sparse_lost_contact_cannot_hide_in_percentile():
    e=np.full((100,100),255);e[50,50]=80
    assert assess(e,np.full_like(e,255),np.ones_like(e,dtype=bool))['mismatched_texels']==1

def test_inc120_missing_contact_source_is_not_a_pass():
    e=np.full((2,2),255)
    assert assess(e,e,np.ones_like(e,dtype=bool))['status']=='FAIL'

def test_open_noncontact_surface_can_explicitly_stay_white():
    e=np.full((2,2),255)
    assert assess(e,e,np.ones_like(e,dtype=bool),require_contact=False)['status']=='PASS'

def test_empty_and_misaligned_scope_fail():
    e=np.array([[100]])
    assert assess(e,e,np.zeros_like(e,dtype=bool))['status']=='FAIL'
    assert assess(e,e,np.ones((2,2),dtype=bool))['status']=='FAIL'

def test_nonfinite_values_fail():
    assert assess([[100]],[[float('nan')]],[[True]])['status']=='FAIL'
