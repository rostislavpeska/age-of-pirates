#target photoshop
(function () {
    // ExtendScript/ES3: do not assume JSON.stringify is provided by this host.
    function encode(v) {
        if (v === null || v === undefined) return 'null';
        if (typeof v === 'string') return '"' + v.replace(/[\\"\u0000-\u001f]/g, function (c) {
            if (c === '\\') return '\\\\';
            if (c === '"') return '\\"';
            return '\\u' + ('0000' + c.charCodeAt(0).toString(16)).slice(-4);
        }) + '"';
        if (typeof v === 'number' || typeof v === 'boolean') return String(v);
        var parts = [], k;
        if (v instanceof Array) {
            for (k = 0; k < v.length; k++) parts.push(encode(v[k]));
            return '[' + parts.join(',') + ']';
        }
        for (k in v) if (v.hasOwnProperty(k)) parts.push(encode(k) + ':' + encode(v[k]));
        return '{' + parts.join(',') + '}';
    }
    function layerTree(container, depth, budget) {
        var rows = [];
        for (var j = 0; j < container.layers.length; j++) {
            if (budget.left-- <= 0) { rows.push({truncated: true}); break; }
            var layer = container.layers[j];
            var row = {name: layer.name, type: layer.typename, visible: layer.visible,
                opacity: layer.opacity, blendMode: String(layer.blendMode)};
            if (layer.typename === 'LayerSet') {
                if (depth < 4) row.layers = layerTree(layer, depth + 1, budget);
                else row.childrenNotExpanded = layer.layers.length;
            }
            rows.push(row);
        }
        return rows;
    }
    var result = {version: app.version, activeDocumentId: null, documents: []};
    if (app.documents.length) result.activeDocumentId = app.activeDocument.id;
    for (var i = 0; i < app.documents.length; i++) {
        var doc = app.documents[i], path = null, channels = [];
        try { path = doc.fullName.fsName; } catch (unsavedDocument) {}
        for (var c = 0; c < doc.channels.length; c++) {
            channels.push({name: doc.channels[c].name, kind: String(doc.channels[c].kind)});
        }
        result.documents.push({id: doc.id, name: doc.name, path: path, saved: doc.saved,
            width: doc.width.as('px'), height: doc.height.as('px'), mode: String(doc.mode),
            bitsPerChannel: String(doc.bitsPerChannel), activeLayer: doc.activeLayer.name,
            channels: channels, layers: layerTree(doc, 0, {left: 120})});
    }
    return encode(result);
}());
