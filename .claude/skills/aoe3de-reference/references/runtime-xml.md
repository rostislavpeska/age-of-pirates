# Static building runtime XML profile

This summarizes the AoP-tested static-building profile. Verify it against a working
asset in the consuming mod; it is not a complete animation/material schema.

- Keep runtime animation/material XML editable and use CRLF for this tested
  profile. Check line endings early when a placeable unit has an invisible model.
  Determine separately whether the target data-file family loads plain XML or an
  XMB twin; rebuild an existing data twin after changing its source.
- Animation XML references a Granny model through a component, and an `Idle`
  animation selects that component. Extra construction/destruction/attachment
  behavior needs its own working reference; do not inherit unrelated branches.
- Match `.material` submaterial names to the names serialized inside the GR2.
  Resolve texture overrides using the target's archive-style paths. Reference stock
  assets by their game archive path rather than shipping duplicate stock files.
- Validate model, texture, decal and sound references using the current game and
  mod. A syntactically valid path is not proof that the referenced asset exists.
- Keep channel packing, normal handedness, transparency, compression and mip count
  tied to the observed shader/profile. The building package's opaque texture
  validator covers one specific profile, not all game textures.
- Check actual GR2 structures and bindings before installation, then test rendering
  in the game separately. Valid XML, a recognized GR2 header and a successful
  converter exit are insufficient evidence of a correct rendered building.
