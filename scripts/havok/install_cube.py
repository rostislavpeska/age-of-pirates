"""Install the test cube into the mod: art files, animfile, proto (zpTestCube cloned from zpSheriffOffice)."""
import os, re, shutil
MOD = r'C:\Users\rosti\Games\Age of Empires 3 DE\76561199512878537\mods\local\age-of-pirates'
SRC = r'C:\Users\rosti\Downloads\Havok2018\cube'
art = os.path.join(MOD, 'art', 'buildings', 'test_cube'); os.makedirs(art, exist_ok=True)

# 1. models + physics + materials (material cloned from a prop that renders in-game)
shutil.copyfile(os.path.join(SRC, 'test_cube_damaged.gr2'), os.path.join(art, 'test_cube_damaged.gr2'))
shutil.copyfile(os.path.join(SRC, 'test_cube_damaged.gr2'), os.path.join(art, 'test_cube.gr2'))
shutil.copyfile(os.path.join(SRC, 'test_cube_damaged.hkt'), os.path.join(art, 'test_cube_damaged.hkt'))
mat = os.path.join(MOD, 'art', 'buildings', 'props', 'tortuga', 'barrel.material')
shutil.copyfile(mat, os.path.join(art, 'test_cube.material'))
shutil.copyfile(mat, os.path.join(art, 'test_cube_damaged.material'))

# 2. animfile: the sheriff's, with model paths swapped and its private bones dropped
xml = open(os.path.join(MOD, 'art', 'buildings', 'sheriff', 'sheriff_office.xml'), 'rb').read().decode('utf-8')
xml = xml.replace('buildings\\sheriff\\sheriff_damaged', 'buildings\\test_cube\\test_cube_damaged')
xml = xml.replace('buildings\\saloon\\lp_saloon', 'buildings\\test_cube\\test_cube')
xml = re.sub(r'<file>buildings\\sheriff\\sheriff</file>', r'<file>buildings\\test_cube\\test_cube</file>', xml)
xml = re.sub(r'  <definebone>[^<]+</definebone>\r?\n', '', xml)
xml = xml.replace('<submodel>mercenary_saloon', '<submodel>test_cube')
xml = xml.replace('<submodelref ref="mercenary_saloon"></submodelref>', '<submodelref ref="test_cube"></submodelref>')
assert 'buildings\\sheriff\\sheriff_damaged' not in xml and xml.count('test_cube\\test_cube') >= 4
open(os.path.join(art, 'test_cube.xml'), 'wb').write(xml.encode('utf-8'))
print('animfile refs:', sorted(set(re.findall(r'<(?:file|model)>([^<]+)</', xml))))

# 3. proto: clone zpSheriffOffice -> zpTestCube, next id, inserted directly above the TEST marker
pp = os.path.join(MOD, 'data', 'protomods.xml')
txt = open(pp, 'rb').read().decode('utf-8')
assert '\r\n' in txt
ids = [int(x) for x in re.findall(r'<unit id="(\d+)"', txt)]
new_id = max(ids) + 1
m = re.search(r'  <unit id="21016" name="zpSheriffOffice">.*?\r\n  </unit>\r\n', txt, re.S)
block = m.group(0)
block = block.replace('id="21016" name="zpSheriffOffice"', 'id="%d" name="zpTestCube"' % new_id)
block = block.replace('buildings\\sheriff\\sheriff_office.xml', 'buildings\\test_cube\\test_cube.xml')
block = re.sub(r'<obstructionradiusx>[^<]+</obstructionradiusx>', '<obstructionradiusx>1.5000</obstructionradiusx>', block)
block = re.sub(r'<obstructionradiusz>[^<]+</obstructionradiusz>', '<obstructionradiusz>1.5000</obstructionradiusz>', block)
block = re.sub(r'<buildlimit>[^<]+</buildlimit>', '<buildlimit>50</buildlimit>', block)
marker = [mm for mm in re.finditer(r'^.*TEST.*$', txt, re.M)]
marker_line = [mm for mm in marker if '<!--' in mm.group(0)]
assert marker_line, 'no TEST marker comment found'
pos = marker_line[-1].start()
if 'name="zpTestCube"' not in txt:
    txt = txt[:pos] + block + txt[pos:]
    open(pp, 'wb').write(txt.encode('utf-8'))
print('proto zpTestCube id', new_id, '| inserted above marker:', marker_line[-1].group(0).strip()[:80])
print('block lines:', block.count('\r\n'), '| animfile line:', re.search(r'<animfile>[^<]+', block).group(0))
