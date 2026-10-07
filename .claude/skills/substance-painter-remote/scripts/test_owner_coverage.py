from owner_coverage import assess


def quad(x0,y0,x1,y1):
    return [[[x0,y0],[x1,y0],[x1,y1]],[[x0,y0],[x1,y1],[x0,y1]]]


def test_shared_readers_need_one_representative():
    one=quad(.1,.1,.4,.4)
    assert assess(one+one,one,64)['status']=='PASS'


def test_ao_bank_omitted_by_old_chart_label_fails():
    one=quad(.1,.1,.4,.4);bank=quad(.6,.1,.9,.4)
    result=assess(one+bank,one,64)
    assert result['status']=='FAIL' and result['missing_pixels']>300


def test_larger_member_requires_uncovered_extent_only():
    old=quad(.1,.1,.4,.4);larger=quad(.1,.1,.7,.4)
    assert assess(larger,old,64)['status']=='FAIL'
    assert assess(larger,old+quad(.4,.1,.7,.4),64)['status']=='PASS'


def test_mirrored_reader_with_same_coverage_passes():
    uv=quad(.1,.1,.4,.4)
    assert assess([t[::-1] for t in uv],uv,64)['status']=='PASS'
