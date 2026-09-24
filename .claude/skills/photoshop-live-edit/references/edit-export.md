# Live editing and export recipes

## Script shape and target identity

Write `.jsx` with ES3 syntax (`var`, ordinary functions). Photoshop's ExtendScript
does not provide modern JavaScript modules, arrow functions or guaranteed native
JSON support. Use forward slashes in JSX path strings or escape backslashes
properly. Write the code to a file rather than nesting scripts inside shell quotes.

```javascript
#target photoshop
(function () {
    var expectedId = 123; // from a fresh inventory, never guessed
    var expectedName = 'the-confirmed-source.psd';
    var doc = null;
    for (var i = 0; i < app.documents.length; i++) {
        if (app.documents[i].id === expectedId) doc = app.documents[i];
    }
    if (!doc || doc.name !== expectedName) throw new Error('Target changed; inspect again.');
    // Also compare doc.fullName when a path was available in the inventory.
    var original = app.activeDocument;
    var dialogs = app.displayDialogs;
    try {
        app.activeDocument = doc;
        app.displayDialogs = DialogModes.NO;
        // Perform only the reviewed operations on doc.
        return 'Completed for document ' + doc.id;
    } finally {
        app.displayDialogs = dialogs;
        app.activeDocument = original;
    }
}());
```

If a call fails after partial work, inspect before retrying. A timeout or COM error
does not roll back layers, saves, or file writes. Restore preferences in `finally`,
including ruler units if changed. Use DOM operations when supported; narrowly
scoped Action Manager code is appropriate for a mask/channel operation missing
from the DOM. Validate that operation on a disposable document first.

## Layered checkpoint and editable changes

For an unsaved/dirty source, make a **nonmerged duplicate** and save that as a new
PSD with `PhotoshopSaveOptions.layers = true`. Set `alphaChannels = true` if those
channels matter. This captures the live state without replacing the operator's
source path. Check the new output path does not already exist. Close only the
duplicate, restore the user's active document, and retain the original.

An existing named PSD may then be saved in place when that is the requested source.
For a PNG/TGA source with live edits, save a layered PSD copy as the editable source;
do not silently overwrite the original raster or flatten the only edited document.
Never substitute an older disk file for dirty live content.

The Color blend mode is `BlendMode.COLORBLEND`. `BlendMode.COLOR` does not exist,
and assigning it throws a misleading "invalid enumeration value", which a localized
Photoshop shows in its UI language. Check any other enum name against the DOM
reference before use. On CC 2018 driven over COM (2026-09-24), a script that set
`app.displayDialogs = DialogModes.NO` then failed in `artLayers.add()`, and restoring
the saved value in `finally` threw that same error. The same calls worked without
touching `displayDialogs`. If a restore in `finally` can throw, give it its own `try`
so it does not hide the real error; label the steps to find the failing call.

For tint/contrast changes, use a named correction layer/adjustment with the intended
semantic mask. Read existing layer visibility and blend modes before appending.
Reuse/update the task's own correction layer deliberately to avoid compounding
changes. Preserve manually painted layers. Imported generated material, if
requested, must be placed in the PSD before its resulting composition is exported.

## TGA export from the approved composition

Inside the target-guarded `try` block above, after saving/capturing the source:

```javascript
var temporary = null;
try {
    // false preserves channels/layers in the disposable copy until export prep.
    temporary = doc.duplicate(doc.name + '_EXPORT_ONLY', false);
    app.activeDocument = temporary;
    temporary.flatten();
    var options = new TargaSaveOptions();
    // Example for a verified RGB map with no alpha. NOT universal map settings.
    options.resolution = TargaBitsPerPixels.TWENTYFOUR;
    options.alphaChannels = false;
    options.rleCompression = true;
    temporary.saveAs(new File('C:/scratch/confirmed-output.tga'), options, true, Extension.LOWERCASE);
} finally {
    if (temporary) temporary.close(SaveOptions.DONOTSAVECHANGES);
    app.activeDocument = doc;
}
```

This example assumes verified RGB, 8-bit data and no required transparency/alpha.
Do not use it unchanged for a different contract. Required alpha needs a deliberate
32-bit export and preservation of the intended alpha channel; layer transparency
must not be lost by flattening without preparation. Verify exported alpha itself.
PSD documents with unsupported mode/bit depth need an explicit export decision,
not a silent conversion. Test those paths separately; the bundled smoke test covers
only layered RGB -> 24-bit TGA.

For normal maps and packed masks, avoid profile conversions and aesthetic tonal
adjustments. Confirm exact channel assignments from the destination material or a
known-good asset. A map called Masks does not imply a universal channel layout.
Normal-map orientation and motif orientation are separate questions. No flip,
rotation, resampling or normal regeneration belongs in an export-only operation.

For AO derived from BaseColor, if requested: use the intended material mask, a
grayscale detail contribution and a controlled strength; preserve unrelated packed
channels. Check whether AO is already baked into BaseColor before multiplying it
again. Keep the layer and mask editable in the source.

## Verification and feedback

Check the PSD reopens with layers/checking overlays intact on a copy when needed.
Check the raster's dimensions, mode, channels/alpha, orientation and representative
pixels. Verify pixels outside edited masks are unchanged; do not infer this from
file hashes when compression differs. Inspect normal/mask channels as data.
The bundled scratch test verifies the basic DOM export mechanism only.

If game deployment is requested, convert the exported file with the destination
workflow's verified flags, preserve previous custom outputs and compare generated
versus installed hashes. Texture edits alone do not justify re-exporting geometry.
Refresh only the intended live scene's images. Show the operator the result in
their working document/scene and let them give the next visual correction.
