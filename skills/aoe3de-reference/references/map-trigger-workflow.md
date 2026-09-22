# Reusable map and trigger workflow

This is a curated workflow derived from AoP's map and trigger guides. It requires
the consuming mod's own data and test environment; it does not depend on AoP maps,
captains, factions, profile paths or automation harnesses.

1. Establish the intended player/team counts, map scale, terrain, resources and
   objectives. Start from a known-working map spine from the installed game and
   retain its required includes and initialization. Look up function signatures
   in the [RM reference](rm_commands_reference.md), then confirm doubtful/versioned
   behavior against a current game example.
2. Resolve every proto, terrain, water, cliff, grouping and technology name from
   current game/mod data. Archive record names can differ from editor labels.
   Historical catalogs are evidence of a particular build, not current truth.
3. Keep map fractions, metres and terrain tiles distinct. Verify start positions
   and object placement numerically as well as visually; rotation of the minimap
   makes screen directions an unreliable substitute for world coordinates.
4. For triggers, consult the installed trigger definition data for condition/effect
   names and parameter types. Declare trigger identifiers before cross-referencing
   them; check event targets, player ownership, activation and loop/one-shot state.
   Use the consuming mod's technology and politician records. A working engine
   trigger does not imply another mod provides the same technologies.
5. Run available syntax, reference and placement checks offline. If a simulator is
   used, state its unsupported features; a simulated result does not prove the
   engine generated the same scene.
6. Test the actual deployed map in the game when authorized. Compare multiple seeds
   and required player/team cases. A saved-scene census answers whether a unit was
   placed; screenshots answer whether it rendered. Keep those results separate.
7. Preserve editable scripts and test evidence. Follow the consuming project's
   deployment and reload rules, especially the distinction between per-generation
   map loading and startup-indexed data/groupings. Diagnose which file was loaded
   before repeatedly changing placement or trigger logic.

The full AoP guides retain the mod-specific examples and automation instructions
in AoP. Their presence elsewhere is not a prerequisite for this portable summary.
