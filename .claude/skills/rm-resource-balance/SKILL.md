---
name: rm-resource-balance
description: Balance the resources of a random map by COUNTING them - what every grouping carries, what the script places, how both sides and each player come out for every lobby size, and whether a saved generation really spawned it evenly. No absolute targets (each map is different); a counting method, one script, reference points and the traps that made counts lie. Use when setting or changing mine / hunt / berry counts, when one side seems richer, when "resources spawn unevenly", or before proposing a resource formula. Triggers on "balance resources", "how many mines", "resources per player", "uneven resources", "one side has more", "count the mines", "resource formula".
---

# rm-resource-balance: count, then decide

There is no right number of mines. A city map whose blocks already hold 20 000 coin per player needs a thin
countryside; an open land map needs everything from the script. Balance here means two things:

1. **Parity (a hard rule):** both sides can reach the same resources. Verify it in a saved generation. Never
   infer it from the script: the script states the request, not what spawned.
2. **The per-player trend (the owner's design choice):** how coin and food per player change from 1v1 to 4v4,
   and in uneven lobbies. Propose it with numbers; the owner decides.

## The method

1. **Inventory the groupings.** Every grouping the map names, with its resource units and amounts:
   ```bash
   python .claude/skills/rm-resource-balance/scripts/resource_count.py groupings randmaps/<map>.xs
   ```
   It also lists every `rmAddObjectDefItem` of a resource proto in the script, with its line. The placement
   COUNT is the script's own formula: read it at that def's `rmPlaceObjectDef*` lines.
2. **Compose each lobby size from the map's branches.** Read which groupings the script places for 1, 2, 3, 4
   and 5+ per side: seat blocks per player, blocks placed once per side, 1v1-only extras, the "5 and more" kit.
   Write it as a table: *fixed per side | per seated player | only at N per side*.
3. **Add the script-placed resources** by their formula (per side, per player, per bank, `resScale` steps).
4. **Total per side and per player** for N = 1..4 per side and the uneven lobbies (2v1, 3v2, 4v3, 5v3). A few
   lines of Python over the table do it; keep the script in the session scratchpad.
5. **Compare with the reference points below,** then propose ONE formula for both sides. Prefer one computed
   from the total player count (`cNumberNonGaiaPlayers`): in uneven lobbies the bigger team then gets less per
   player. London uses `(players + 1) / 2` per bank for tin, herds and berries (owner 2026-09-27).
6. **Verify the spawn** in a saved generation (rm-census):
   ```bash
   python .claude/skills/rm-resource-balance/scripts/resource_count.py census <save.age3Yscn> --axis z --beyond <m>
   ```
   It splits the map at the midline of `--axis`; `--beyond` counts only units at least that far from it (the
   countryside beyond a wall). The pass criterion: the requested count on each side, `parity: EQUAL`.

## Reference points (orientation, not targets)

| Source | Extra coin | Hunts | Berries |
|---|---|---|---|
| Vanilla team maps (Great Plains, New England, Carolina, Saguenay, Yukon, Colorado) | ~3 mines per player + the starting mine: ~8000 coin per player, the same in every lobby size | 2N-6N herds | rare (Carolina: N clusters) |
| Vanilla 1v1 | 3-4 hand-mirrored mines per player | mirrored pairs | - |
| Florence / Istanbul / Paris (mod) | 2 + N per side / 2 + N/4 + 1 + N/4 / 2 per side from 4 players | about the mines' count | - |
| King of Bohemia, Crownlands (mod) | 2N per half | 3N per half | N per half |

Amounts per unit (vanilla `protoy`): MineTin 1500, Mine (silver) / MineCopper / deMineCoalBuildable 2000,
MineGold 5000; Deer 400, Elk / Bison / Moose 500; BerryBush 1000. ypGoat and Sheep are livestock (50), not hunts.
Duck, DuckFamily and Wolf hold nothing. The script reads all of these itself.

## Traps that made the counts lie (each one cost a real session)

- **Forest areas wipe what was placed before them.** A forest area without `avoidAll` deletes every mine and herd
  it grows over: London 1v1 had 0 of 4 countryside tin mines. Check the forests FIRST (rm-workflow editing rules).
- **Requested is not spawned.** `rmPlaceObjectDefInArea` gives up silently in a thin, heavily fenced band. Count
  the save; never trust the formula.
- **Constraints test the object's centre.** Big objects (mines, treasure camps) need the edge and avoid
  distances of their size (rm-objects-herds, "Map-edge constraints").
- **`rmRandInt` in an item is rolled once per def:** one def placed on both sides gives both the same herd size.
  A helper that creates a def per call re-rolls per side.
- **Uneven kits across lobby sizes.** London's 5+ per side seat kit has no geese: that side's wild food falls from
  ~9900 to ~3700 per player. Step 2's table shows such cliffs; flag them.

Worked example: `docs/briefs/2026-09-27-london-countryside-resources-plan.md` (groupings, per-side table,
other maps, the formula, the saves).
