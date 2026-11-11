"""A reused accepted page cannot waive new pages or changed bytes."""
import hashlib
import sys
from pathlib import Path
import pytest
sys.path.insert(0, str(Path(__file__).parent))
from gr2_ao_check import page_limit


def fixture_page(tmp_path):
    p = tmp_path / 'shared_Masks.ddt'; p.write_bytes(b'accepted AO bytes')
    e = dict(file=p.name, sha256=hashlib.sha256(p.read_bytes()).hexdigest(), max_m2=.8,
             owner_quote='Accepted existing surface', date='2026-10-12', source_acceptance='fixture record')
    return p, e


def test_only_exact_shared_page_gets_acceptance(tmp_path):
    p, e = fixture_page(tmp_path); prof = {'ao_shared_uv_accepted_pages': [e]}
    assert page_limit(p, prof)[0] == .8
    own = tmp_path / 'own_Masks.ddt'; own.write_bytes(p.read_bytes())
    assert page_limit(own, prof) == (.5, None)


def test_changed_bytes_fail(tmp_path):
    p, e = fixture_page(tmp_path); p.write_bytes(b'changed')
    with pytest.raises(ValueError, match='hash changed'):
        page_limit(p, {'ao_shared_uv_accepted_pages': [e]})


@pytest.mark.parametrize('field', ['owner_quote', 'date', 'source_acceptance', 'sha256'])
def test_missing_acceptance_evidence_fails(tmp_path, field):
    p, e = fixture_page(tmp_path); e.pop(field)
    with pytest.raises(ValueError, match='incomplete'):
        page_limit(p, {'ao_shared_uv_accepted_pages': [e]})


def test_duplicate_acceptance_fails(tmp_path):
    p, e = fixture_page(tmp_path)
    with pytest.raises(ValueError, match='duplicate'):
        page_limit(p, {'ao_shared_uv_accepted_pages': [e, e]})
