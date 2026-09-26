---
name: aoe3de-destructible-building
description: Plan and export new Age of Empires III DE destructible buildings using an already proven donor body graph. Covers intact shells, capped fractured geometry, rigid bindings, collision refits and human game validation. Use for a new building such as the Korean Town Center; use havok-destruction for inspecting or editing an existing destruction asset.
---

# New destructible buildings from a proven donor

New architectural geometry can retain a donor's physics graph while replacing its
render pieces and collision hulls. Korean Town Center v07 and detailed v20 were
confirmed working in game. This is not evidence for arbitrary HKT graph creation.

Read [havok-destruction](../havok-destruction/SKILL.md) for the runtime contract,
donor inspection and frames; [GR2 editing](../gr2-granny-edit/SKILL.md) for exact
bindings, serialization and native loading. In Age of Pirates, enter through
[aoe-building-pipeline](../aoe-building-pipeline/SKILL.md). Use
[blender-architecture](../blender-architecture/SKILL.md) for geometry and its
surface-visibility reference before hidden-face removal. These are local library
dependencies; this package is not currently a standalone public export.

## Prepare while the intact building is being designed

1. Approve the plain intact silhouette and footprint first. Compare the donor's
   structural regions and active animfile decal at its declared dimensions.
   A similar outline helps donor choice but does not prove graph compatibility.
   Keep creative architecture independent of the donor's old fracture outlines.
2. Maintain separate representations: editable quad-based architectural source;
   closed fracture volumes; optimized intact render shell; damaged render pieces
   with thickness/caps; collision hulls. They may share data where appropriate,
   but an intact visibility decision must not delete a damaged piece's back.
   Keep authoring quads and reliable planar n-gons. Triangulate a frozen export
   duplicate only; diagnostic triangle measurements must preserve source faces.
3. Name structural parts and retain stable source face IDs through splits.
   Plan fixed foundations, stage-breaking regions, on-death pieces, attachment
   supports and material families. Record each damage piece's intended donor
   body/bone, rather than relying on object order or nearest-bone guesses.
4. Reserve separate surface classes: visible exterior; reusable backing;
   destruction-only interior/cut. Preserve exterior corner normals, UVs and
   material assignments on surviving surfaces. Interior wood/stone/clay can use
   overlapping simple bitmap patches at an approved smaller resolution. A
   downward normal alone is neither a visibility proof nor a density rule.
5. Plan poles and real support geometry for civ/garrison flags and any other
   attachments. Record intact and damaged parent chains. If a support falls,
   the attachment must follow that piece; inspect donor animtrans behavior.
   Do not apply ship-specific root rotations to a building without measurement.
6. Record one assembled rest pose, units, axes, transforms and decal footprint.
   Define separate intact and damaged packed-vertex/triangle budgets, including
   caps, UV/normal splits and repeated fragments. Collision/body count is a
   separate budget. Freeze evaluated geometry on export copies, not live source.

An open intact shell is compatible with independently capped debris. For freely
rotating debris every side may become visible. A burial certificate transfers
only when the same opaque hiding geometry stays with the piece in every relevant
state. Alpha cutouts are not solid occluders. Havok collisions are independent of
render-shell closure; robust closed fracture volumes are a construction method,
not proof that all vanilla render components must be watertight.

## Bounded production sequence

1. **Identify a baseline.** Record exact donor files and hashes, names, graph,
   motion/custom properties, rest transforms, vertex bindings and attachment
   chains. Use the accepted baseline for the same donor. For an untested donor,
   validate an unchanged clone and one bounded piece edit before replication.
   Proxy, attachment, body and visible-piece counts need not match.
2. **Fracture an immutable source copy.** Cut structural volumes, cap new cuts,
   preserve source correspondence and surface attributes, then assign fragments
   to named donor groups. Check volume/coverage, caps, winding, overlaps and
   rigid ownership. Every exported triangle must have one rigid group; splitting
   a face across independently moving bones is not a valid repair. Preview the
   assembled state and separated/rotated pieces, with interiors visible.
3. **Freeze a physics test snapshot.** Export the assembled rest frame, never an
   exploded diagnostic pose. Compare intact and damaged exterior positions
   before motion. Simple existing materials may isolate physics validation from
   ongoing UV/art work; label this simplification in the manifest.
4. **Build GR2 at donor layout.** Preserve skeleton and rigid bindings using the
   GR2 skill's section, relocation, marshalling and bone-local bounds rules.
   Preserve packed shading data where geometry is retained. A generic static
   FBX-to-GR2 round trip is not the damaged-model route. Verify the actual UV set
   and material names in the serialized output, not only the Blender scene.
5. **Refit hulls, retaining the graph.** Use the measured donor-specific frame;
   preserve names, order, parents, properties, motion types and rest pivots.
   Update collision bounds, COM and inertia as required. Require a byte-identical
   no-op serialization check before a new writer changes the donor, then test
   every input point against emitted hull planes. Report donor masses, proxies,
   unused bodies or hulls bridging disconnected fragments as retained limits.
6. **Inspect serialized files.** Require valid indices, rigid ownership, finite
   positions/UVs, expected bounds, graph invariants and native Granny loading for
   new buffers/bindings. A CRC or Python parse alone missed a previous marshalling
   failure. Stop before deployment if native load fails. Physics checks do not
   validate shader, alpha, normals, AO or flag behavior.
7. **Deploy only the frozen test.** Preserve prior runtime files, record hashes
   and verify XML/material paths, CRLF and compiled twins where applicable.
   Keep the donor's Destruction p1/p99, Death and simskeleton wiring unless a
   bounded test justifies a change. Use a simple subject/control bench and
   separate final-art acceptance from physics acceptance.
8. **Human game gate.** The user tests intact placement, first transition,
   intermediate damage and final collapse; inspect newly exposed interiors,
   retained attachments, piece offsets, debris rotation and ground contact.
   Record exact feedback against hashes. Missing stage feedback stays unknown.
   If a test fails, diagnose that failure before another whole-building rebuild.

For the accepted detailed example, read
[Korean v20 evidence and limits](references/korean-v20-evidence.md). The existing
project scripts are checkpoint-specific reproduction evidence, not a portable
exporter: inspect inputs and deployment destinations before adapting them.

## Evidence and handoff

Keep a compact record of source checkpoint/hash, runtime hashes, donor identity,
surface/piece mapping, intact/damage budgets, artifact checks and manual result.
Distinguish historical acceptance from this revision. An accepted physics test
does not approve future UV edits, a new donor, final materials or an untested
attachment chain. A successful donor adaptation does not establish a general
Havok graph-authoring pipeline.
