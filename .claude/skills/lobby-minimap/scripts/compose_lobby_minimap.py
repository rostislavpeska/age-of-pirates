"""Compose <name>_mini2.png (plain) and <name>_mini.png (with a ribbon) in Photoshop from the owner's template.

    python compose_lobby_minimap.py --template <minimap_template.psd> --disc DISC.png --name danube
                                    --border gold|silver [--ribbon new|reworked|none] --out DIR

The template is copied into --out first and only the copy is opened (the original is never opened or saved).
In the copy: the disc becomes a layer named after the map, directly under the ribbons, over the border layer -
the way the finished maps were made (London = its disc over Vrstva 30, Elbe = its disc over Vrstva 1). Every other
layer is hidden for the export. Photoshop runs through the photoshop-live-edit skill (COM + ExtendScript, no screen
clicks); start it with that skill's start_photoshop.ps1 when it is not running.

Template layers (minimap_template.psd, 512 x 512, measured 2026-10-07):
  Vrstva 1   gold ring + an old map: the border of the normal maps
  Vrstva 30  silver ring + an old map: the border of the historical maps
  Vrstva 2   the NEW ribbon (box 85..407 x 421..511)
  Vrstva 29  the REWORKED ribbon (box 25..467 x 422..511)"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
PS = REPO / '.claude' / 'skills' / 'photoshop-live-edit' / 'scripts' / 'photoshop.ps1'
BORDER = {'gold': 'Vrstva 1', 'silver': 'Vrstva 30'}
RIBBON = {'new': 'Vrstva 2', 'reworked': 'Vrstva 29', 'none': ''}

JSX = r"""#target photoshop
(function () {
    var COPY = '%(copy)s', DISC = '%(disc)s', OUT = '%(out)s', NAME = '%(name)s', RING = '%(ring)s', RIB = '%(ribbon)s';
    var tpl = null;
    for (var i = 0; i < app.documents.length; i++) {
        try { if (app.documents[i].fullName.fsName === new File(COPY).fsName) tpl = app.documents[i]; } catch (e) {}
    }
    if (!tpl) tpl = app.open(new File(COPY));
    app.activeDocument = tpl;
    function byName(n) { for (var q = 0; q < tpl.layers.length; q++) if (tpl.layers[q].name === n) return tpl.layers[q]; return null; }
    var ring = byName(RING), ribbon = RIB ? byName(RIB) : null, top = byName('Vrstva 2');
    if (!ring || (RIB && !ribbon) || !top) return 'ERROR: a template layer is missing (' + RING + ', ' + RIB + ')';
    var old = byName(NAME);
    if (old) old.remove();
    var disc = app.open(new File(DISC));
    if (disc.width.as('px') !== 512 || disc.height.as('px') !== 512) { disc.close(SaveOptions.DONOTSAVECHANGES); return 'ERROR: disc is not 512 x 512'; }
    app.activeDocument = disc;
    var dup = disc.activeLayer.duplicate(tpl, ElementPlacement.PLACEATBEGINNING);
    disc.close(SaveOptions.DONOTSAVECHANGES);
    app.activeDocument = tpl;
    var L = tpl.layers[0];
    L.name = NAME;
    L.move(top, ElementPlacement.PLACEAFTER);
    var b = [L.bounds[0].as('px'), L.bounds[1].as('px'), L.bounds[2].as('px'), L.bounds[3].as('px')];
    for (var m = 0; m < tpl.layers.length; m++) tpl.layers[m].visible = false;
    L.visible = true;
    ring.visible = true;
    tpl.saveAs(new File(OUT + '/' + NAME + '_mini2.png'), new PNGSaveOptions(), true, Extension.LOWERCASE);
    if (ribbon) ribbon.visible = true;
    tpl.saveAs(new File(OUT + '/' + NAME + '_mini.png'), new PNGSaveOptions(), true, Extension.LOWERCASE);
    var o = new PhotoshopSaveOptions();
    o.layers = true;
    tpl.saveAs(new File(OUT + '/' + NAME + '_work.psd'), o, true, Extension.LOWERCASE);
    return 'OK layer ' + NAME + ' at ' + b.join(',') + ' over ' + RING + (ribbon ? ', ribbon ' + RIB : ', no ribbon');
})();
"""


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--template', required=True)
    ap.add_argument('--disc', required=True)
    ap.add_argument('--name', required=True)
    ap.add_argument('--border', choices=sorted(BORDER), required=True)
    ap.add_argument('--ribbon', choices=sorted(RIBBON), default='new')
    ap.add_argument('--out', required=True)
    o = ap.parse_args(argv)
    out = Path(o.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    copy = out / f'{o.name}_template_copy.psd'
    if not copy.is_file():
        shutil.copyfile(o.template, copy)
    fwd = lambda p: str(Path(p).resolve()).replace(chr(92), '/')
    jsx = out / f'{o.name}_compose.jsx'
    jsx.write_text(JSX % {'copy': fwd(copy), 'disc': fwd(o.disc), 'out': fwd(out), 'name': o.name,
                          'ring': BORDER[o.border], 'ribbon': RIBBON[o.ribbon]}, encoding='utf-8')
    # -ExecutionPolicy Bypass for this one process only (the agent's own PowerShell sessions run that way; a plain
    # child powershell.exe on this device refuses unsigned local scripts). No system setting changes.
    r = subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-STA', '-File',
                        str(PS), '-ScriptPath', fwd(jsx)], capture_output=True, text=True)
    print((r.stdout or '').strip()[-400:], (r.stderr or '').strip()[-400:])
    ok = 'OK layer' in (r.stdout or '') and (out / f'{o.name}_mini.png').is_file() and (out / f'{o.name}_mini2.png').is_file()
    print('outputs:', out / f'{o.name}_mini.png', out / f'{o.name}_mini2.png', out / f'{o.name}_work.psd')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
