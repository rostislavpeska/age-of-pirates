# Rules for every fixture, plain set (give these to the builder with a brief_plain.md)

You write ONE Python script for Blender 5.1 (`bpy`) that builds the scene in the brief.

- The runner deletes every default object, runs your script in background Blender, and saves the file. Start from
  an empty scene; do not save, load or write any file yourself.
- Metres, Z up, ground at z = 0. Use the exact numbers in the brief.
- Create exactly the named parts, with exactly those object names (Blender must not rename them to `.001`). Delete
  any helper object before the script ends.
- Mesh objects only. Modifiers are allowed. No add-ons, no network, no randomness: the same script must build the
  same scene every time.
- A **closed part** is a watertight solid with its faces pointing outward. A **sheet** is a single-sided surface with
  its faces pointing up or outward: the game draws only the front side of a face.
- The model is a game building seen from an RTS camera, and it should look right.
- Do not open, read or run the `junction-testbed` skill, any `key.json`, or any checker.

Deliver the script only.
