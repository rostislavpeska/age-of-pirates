"""Regression: the r58 Stable census must include all 62 historical PROPOSAL-labelled parts."""
from pathlib import Path
import sys
import pytest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from export_census import normalize_part_id, require_part_census


def stable_fixture():
    expected=[f'Stable/part{i}' for i in range(206)]
    observed=['PROPOSAL | '+p if i<62 else p for i,p in enumerate(expected)]
    return observed,expected


def test_all_206_stable_parts_survive_the_known_62_historical_labels():
    observed,expected=stable_fixture()
    selected=[p for p in observed if normalize_part_id(p).startswith('Stable/')]
    report=require_part_census(selected,expected,'Stable')
    assert report['count']==206 and report['normalized_historical_labels']==62


def test_old_prefix_filter_cannot_clear_a_writer():
    observed,expected=stable_fixture()
    selected=[p for p in observed if p.startswith('Stable/')]
    assert len(selected)==144
    with pytest.raises(ValueError,match='missing='):require_part_census(selected,expected,'Stable')


@pytest.mark.parametrize('change',['missing','duplicate','unexpected','other_model','empty'])
def test_incomplete_or_ambiguous_inventory_fails(change):
    observed,expected=stable_fixture()
    if change=='missing':observed.pop()
    elif change=='duplicate':observed.append(expected[0])
    elif change=='unexpected':observed.append('Stable/unapproved')
    elif change=='other_model':observed[0]='Barracks/part0'
    elif change=='empty':observed=[];expected=[]
    with pytest.raises(ValueError):require_part_census(observed,expected,'Stable')


def test_only_the_exact_historical_prefix_is_normalized():
    assert normalize_part_id('PROPOSAL | Stable/x')=='Stable/x'
    assert normalize_part_id('Stable/PROPOSAL | x')=='Stable/PROPOSAL | x'
    assert normalize_part_id(None)==''
    with pytest.raises(ValueError):require_part_census(['PROPOSAL | PROPOSAL | Stable/x'],['Stable/x'],'Stable')
