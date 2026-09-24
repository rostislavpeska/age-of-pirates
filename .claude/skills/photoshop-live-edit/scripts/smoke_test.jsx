#target photoshop
(function () {
    var original = app.documents.length ? app.activeDocument : null;
    var originalId = original ? original.id : null;
    var dialogs = app.displayDialogs, owned = [], before = [];
    var folder = new Folder(Folder.temp.fsName + '/photoshop-skill-smoke-' + new Date().getTime());
    if (folder.exists || !folder.create()) throw new Error('Cannot create fresh scratch directory.');
    for (var d = 0; d < app.documents.length; d++) {
        before.push({id: app.documents[d].id, saved: app.documents[d].saved,
            layer: app.documents[d].activeLayer.name});
    }
    function check(ok, text) { if (!ok) throw new Error(text); }
    function paint(doc, rgb) {
        var color = new SolidColor();
        color.rgb.red = rgb[0]; color.rgb.green = rgb[1]; color.rgb.blue = rgb[2];
        doc.selection.fill(color, ColorBlendMode.NORMAL, 100, false);
        doc.selection.deselect();
    }
    function remember(doc) { owned.push(doc); return doc; }
    var result;
    try {
        app.displayDialogs = DialogModes.NO;
        var source = remember(app.documents.add(UnitValue(32, 'px'), UnitValue(32, 'px'),
            72, 'Photoshop_skill_disposable_test', NewDocumentMode.RGB, DocumentFill.TRANSPARENT));
        source.activeLayer.name = 'Base';
        source.selection.selectAll(); paint(source, [96, 96, 96]);
        var manual = source.artLayers.add(); manual.name = 'Manual paint preserved';
        source.selection.select([[8,8],[24,8],[24,24],[8,24]]); paint(source, [200, 32, 32]);
        var overlay = source.artLayers.add(); overlay.name = 'Checking overlay HIDDEN';
        source.selection.selectAll(); paint(source, [0, 255, 0]); overlay.visible = false;

        var psd = new File(folder.fsName + '/layered-source.psd');
        var psdOptions = new PhotoshopSaveOptions(); psdOptions.layers = true;
        source.saveAs(psd, psdOptions, false, Extension.LOWERCASE);
        var disposable = remember(source.duplicate('Disposable export', false));
        disposable.flatten();
        var tga = new File(folder.fsName + '/export.tga');
        var tgaOptions = new TargaSaveOptions();
        tgaOptions.resolution = TargaBitsPerPixels.TWENTYFOUR;
        tgaOptions.alphaChannels = false; tgaOptions.rleCompression = true;
        disposable.saveAs(tga, tgaOptions, true, Extension.LOWERCASE);
        disposable.close(SaveOptions.DONOTSAVECHANGES); owned.pop();
        source.close(SaveOptions.DONOTSAVECHANGES); owned.pop();

        var reopened = remember(app.open(psd));
        check(reopened.layers.length === 3, 'Layered PSD lost layers.');
        check(reopened.layers[0].visible === false, 'Checking overlay visibility changed.');
        check(reopened.layers[1].name === 'Manual paint preserved', 'Editable paint layer lost.');
        var exported = remember(app.open(tga));
        check(exported.width.as('px') === 32 && exported.height.as('px') === 32, 'Wrong export dimensions.');
        check(exported.channels.length === 3, 'Wrong RGB export channel count.');
        result = 'PASS: layered PSD, hidden overlay, RGB TGA dimensions/channels. Scratch: ' + folder.fsName;
    } finally {
        for (var i = owned.length - 1; i >= 0; i--) {
            try { owned[i].close(SaveOptions.DONOTSAVECHANGES); } catch (closeFailure) {}
        }
        app.displayDialogs = dialogs;
        if (original) app.activeDocument = original;
    }
    check(app.documents.length === before.length, 'Document set changed; inspect before retrying.');
    for (var j = 0; j < before.length; j++) {
        var existing = app.documents[j];
        check(existing.id === before[j].id && existing.saved === before[j].saved &&
            existing.activeLayer.name === before[j].layer, 'Original document state changed.');
    }
    check((app.documents.length ? app.activeDocument.id : null) === originalId, 'Active document changed.');
    return result + '; original document IDs, saved state, selected layers and active document preserved.';
}());
