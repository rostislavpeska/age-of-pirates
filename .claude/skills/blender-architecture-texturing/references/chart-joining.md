# UV workflow ownership

The former combined procedure is now maintained in two dedicated skills:

1. [Clean UV authoring](../../blender-clean-uv/SKILL.md) owns coherent charts,
   geometry adjacency, two-axis density, hidden-surface allocation and the actual
   editable Blender handoff. See its
   [chart construction reference](../../blender-clean-uv/references/chart-construction.md).
2. [UV reuse and space optimization](../../blender-uv-reuse/SKILL.md) owns
   geometry-based candidate matching, compatible pixel sharing and economical
   packing. See its
   [correspondence, AO and budget reference](../../blender-uv-reuse/references/matching-and-budget.md).

Chart construction precedes reuse decisions and final owner packing. A unique
working layout can be made first for independent inspection and comparison bakes;
it is not the economical final atlas. Clean-editor approval does not approve
remaining fragmentation, runtime size changes, final art or export.

This compatibility index preserves earlier reference links. Maintain the
procedures in their owning skills rather than duplicating them here.
