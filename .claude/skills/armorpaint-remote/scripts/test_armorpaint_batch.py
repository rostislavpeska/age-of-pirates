import tempfile
import unittest
from pathlib import Path
from PIL import Image
from armorpaint_batch import check_evidence, prepare_directory, runtime, run_script, resize_script, validate_save_targets

class EvidenceTests(unittest.TestCase):
    def test_stale_native_path_is_rejected_before_launch(self):
        import json
        with tempfile.TemporaryDirectory() as d:
            old=Path(d)/'old.arm';old.write_bytes(b'preserve source')
            new=Path(d)/'new.arm'
            code='project_filepath_set('+json.dumps(str(old))+');project_save(0);'
            with self.assertRaises(ValueError):validate_save_targets(code,[new])
            self.assertEqual(old.read_bytes(),b'preserve source')
            validate_save_targets(code.replace(json.dumps(str(old)),json.dumps(str(new))),[new])
            with self.assertRaises(FileExistsError):validate_save_targets(code,[old])

    def test_implicit_and_dynamic_save_targets_rejected(self):
        for code in ['project_save(0);','project_filepath_set(target);project_save(0);']:
            with self.assertRaises(ValueError):validate_save_targets(code,['new.arm'])

    def test_resolution_validation(self):
        for value in [0, 63, 1000, 32768, True, 1024.0]:
            with self.assertRaises(ValueError): resize_script(value, 'result.arm')
        script = resize_script(1024, 'result.arm')
        self.assertIn('script_set_texture_resolution(1024)', script)
        self.assertIn('frame==5', script)

    def test_no_unobservable_script_run(self):
        with self.assertRaises(ValueError):
            run_script(None,'missing','missing','missing',[],'DONE')
        with self.assertRaises(ValueError):
            run_script(None,'missing','missing','missing',['output'],'')

    def test_exit_zero_missing_output_fails(self):
        with tempfile.TemporaryDirectory() as d:
            errors,_=check_evidence(0,'DONE','DONE',[Path(d)/'missing.png'])
            self.assertTrue(errors)

    def test_exit_zero_native_error_fails(self):
        errors,_=check_evidence(0,'Invalid script path. DONE','DONE',[])
        self.assertTrue(errors)

    def test_missing_marker_fails(self):
        self.assertTrue(check_evidence(0,'','DONE',[])[0])

    def test_png_decode_dimensions_and_identity(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'map.png';Image.new('RGB',(16,16),(4,5,6)).save(p)
            errors,out=check_evidence(0,'DONE','DONE',[p],(16,16))
            self.assertFalse(errors);self.assertEqual(out[str(p)]['size'],[16,16])
            self.assertTrue(check_evidence(0,'DONE','DONE',[p],(32,32))[0])
            p.write_text('Not PNG')
            self.assertTrue(check_evidence(0,'DONE','DONE',[p],(16,16))[0])

    def test_reject_existing_output_directory(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d)/'old.arm').write_text('preserve')
            with self.assertRaises(FileExistsError): prepare_directory(d)
            self.assertEqual((Path(d)/'old.arm').read_text(),'preserve')

    def test_local_configuration(self):
        import json
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as d:
            exe=Path(d)/'test.exe';exe.write_bytes(b'test')
            config=Path(d)/'local.json';config.write_text(json.dumps({'tools':{'armorpaint':{'path':str(exe)}}}))
            with patch.dict('os.environ', {}, clear=True):
                self.assertEqual(runtime(local_config=config),exe.resolve())

if __name__=='__main__': unittest.main()
