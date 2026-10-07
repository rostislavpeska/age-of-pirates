# Korean military export repair — r59 / INC-133

The owner rejected the r58 Barracks and Stable in-game: their textures sampled
unrelated atlas regions. Both Korean editor entries also reused Japanese names,
including names shared with the Japanese comparison clones.

The raw writer stored Blender `(u,v)` unchanged. The working Town Center route
stores `(u,1-v)`. Independent comparison of all 13,573 TC triangles established
that boundary; all four r58 intact/damaged files violated it. Texture resolution,
material count and density were not the cause. Native readback compared the file
with the writer's own wrong input, and density is invariant under a V reflection.
Authoring-file beauty renders did not exercise the serialized export.

r59 converts V once before computing tangents and packing vertex UVs. Source
geometry, material assignments, author UVs, textures and destruction HKT remain
unchanged. All four corrected files match source triangle corners exactly at the
stored float16 precision. Before/after renders use bound GR2 meshes and their
material XML's decoded DDTs, and reproduce/remove the reported mishmash.

The regression gate hashes ordered source triangle positions and expected raw UVs
per material. It rejects the four r58 files and accepts the four r59 files. Its
expectations come from frozen author data, independently of the writer.

Run the complete installed-file gates from the mod root:

```powershell
python scripts/havok/gr2_lint.py --profiles config/gr2_lint_military.json --profile korean_barracks_physics art/zbench_korean_military/barracks
python scripts/havok/gr2_lint.py --profiles config/gr2_lint_military.json --profile korean_stable_physics art/zbench_korean_military/stable
python -m pytest scripts/havok/tests/test_gr2_uv_contract.py -q
```

Native inspection needs the configured Korean repository tools; a SKIP is not a
pass. The portable profile pins source contracts, the owner's page allocation,
and the shared TC resources. Rebuild contracts from author inputs only when the
source changes; do not regenerate expectations from a suspect runtime file.

| Editor name | Internal proto |
|---|---|
| Korean Barracks | `zzKoreanBarracksPhysics` |
| Korean Stable | `zzKoreanStablePhysics` |
| Japanese Barracks (Reference) | `zzJapaneseBarracksPhysics` |
| Japanese Stable (Reference) | `zzJapaneseStablePhysics` |

The display/editor IDs are unique and compiled in all 15 language tables. No
vanilla unit was renamed or deleted. Restart the game after updating the mod.

This repair's offline gates pass; a fresh owner game test remains pending. The
mapping renders use geometric normals and do not certify the complete engine
normal shader. The prior TC tangent compensation is retained; V-dependent packed
handedness is recalculated. Physics behavior is unchanged, not newly playtested.
The global XML audit reports unrelated existing reference errors and the text
audit reports five existing team-name issues; the four edited units and all
compiled labels have separate passing checks. No paid image calls were made;
the additional financial cost of this incident was not measured.

Full before/after binaries, pictures, independent findings and source provenance
are preserved in the Korean repository's external snapshot referenced by
`research/Colonial_Military_12/runtime_r59/SNAPSHOT.json`.
