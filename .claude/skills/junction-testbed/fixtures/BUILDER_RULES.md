# Rules for every junction fixture (give these to the builder with the brief)

You write ONE Python script for Blender 5.1 (`bpy`) that builds the scene in the brief.

- The runner deletes every default object, runs your script in background Blender, and saves the file. Start from
  an empty scene; do not save, load or write any file yourself.
- Metres, Z up, ground at z = 0. Use the exact numbers in the brief.
- Create exactly the named parts, with exactly those object names (Blender must not rename them to `.001`). Delete
  any helper object before the script ends.
- Mesh objects only. Modifiers are allowed (the checker measures the evaluated mesh). No add-ons, no network, no
  randomness: the same script must build the same scene every time.
- A **closed part** is a watertight solid with its faces pointing outward. A **sheet** is a single-sided surface with
  its faces pointing up or outward: the game draws only the front side of a face.
- Every junction in the brief is measured to the millimetre: gaps, parts running into or through each other, parts
  standing out beyond what they join, and how much of a seated face really touches.
- Faces of two parts must never lie exactly on each other facing the same way: the game draws both at one depth and
  they flicker. Where a part rests under another part's visible surface, keep it 1 to 5 mm below that surface.
- Do not open, read or run the `junction-testbed` skill, its fixtures' `key.json` or any checker. Build the junctions
  right by construction.

Deliver the script only.
