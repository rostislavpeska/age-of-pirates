---
name: minimap-twin
description: One world coordinate for the map script, the saved generation, the minimap and the in-game camera (scripts/mapview + scripts/gameio). Use to calibrate a screen's minimap from its drawn disc, check it (explorer stars or the map's edges), build the twin of a map (mapsim's expected objects joined with the census of an editor save - key objects, grouping votes, owners, MISSING/moved lists), aim the camera at a world point and photograph or record it, or convert metres / fractions / minimap pixels either way. Triggers on "minimap pixel", "where on the minimap", "photograph the enemy base", "record at the bridge", "spawn check", "did the grouping spawn", "twin", "calibrate the minimap", "world coordinate", "census positions".
---

# The minimap digital twin (`scripts/mapview`, input through `scripts/gameio`)

Spec: `docs/briefs/2026-09-24-minimap-digital-twin-spec.md` (its section 7 lists what the build corrected).
Everything is offline except `camera.py` and `python -m scripts.gameio`; those move only the camera / the game's own
UI, and only on the owner's word.

## Facts the tools rest on (measured 2026-09-24, 2560x1080)

- **Rotation:** visual top = code corner (1,1), right = (1,0), left = (0,1); a pure 45 degree rotation (free-affine
  angle and skew under 1 degree on Paris, Elbe and London pairs). `transform.frac_to_uv` = mapsim's render.
- **The disc:** its diameter is the map's LONGER side; the drawn map is centred on the ring within 0.2 px. Editor:
  centre (2269.33, 920.33), drawn rim 130.5 px (unchanged by the September patch). Match HUD: (2399.32, 899.31),
  rim 147.0 px from a pre-patch frame - re-measure live. The old aitest sheet's `minimap_center` (2320,900) is wrong.
- **Map size:** the engine rounds `rmSetMapSize` to whole 2 m tiles: London 2p / 3-5p / 6+p = 360 x 646 / 686 / 766 m.
  `mapinfo.map_size` gives the engine size; `census_reader.map_size(save)` reads it exactly from the save.
- **Census:** a unit's own position is the header before its `UN` tag (tag-49, older saves tag-48, validated by an
  orthonormal 3x3); the owner is the u16 20 bytes before the header (`player`). The pre-2026-09-24 census read the
  next record - old `*_units.json` and position verdicts are wrong.
- **Minimap stars are EXPLORERS**, not town centres (glyph ~1 px from the explorer's projected position).
- **Camera outline:** its aim point is the intersection of the diagonals, not the outline's centroid.

## Measured 2026-09-24 on the 2880x1800 test device (report: docs/briefs/2026-09-24-minimap-twin-test-report.md)

- Never scale the 2560 numbers: the UI is 1.5-1.7x larger. Editor disc (2553.25, 1534.21) rim 218.72 px, match disc
  (2639.24, 1529.19) rim 220.89 px; sheet `scripts/gameio/sheets/2880x1800.json`, records `cal/*_2880x1800.json`.
- Stars grow with the UI: `minimap_detect.star_radii(r)` scales the template above a 147 px rim.
- The edge inset grows with the UI (editor 2.3 px, match 3.5 px at ~220 px rims): `calibrate.edge_band(rim)` scales
  the 0.5-2.5 px band and the 1 px side agreement by rim / 130.5; both 2880 records are checked. Camera look-at =
  target + (-0.32, -3.69) px in a match (`look_offset_px`, sd 0.9 px); every shot verified within 2.1 px.
- Census names need the CURRENT vanilla protoy: `census_reader` builds the `mapcheck --live` cache itself now; with
  the repo snapshot every mod index shifts (London twin: 6/35 key objects instead of 35/35).
- The editor's Type list shows only the Steam `Game\RandMaps` root and vanilla: London is tested as the root
  copy `00000_zplondon`, kept equal to the repo by `scripts/tools/sync_local_maps.py` (rm-workflow); a copy added
  while the game runs is seen only after Close + File > New.
- In the lobby's map picker the mod's maps are only under Select Type = **Custom Maps** (London = "Restoration of
  the Monarchy"); reopening the picker resets the type to All Maps.

## Calibrate a screen (once per screen kind and resolution)

1. A full-resolution screenshot with the minimap visible and NO dialog open (a dialog dims the screen: refused).
2. `python scripts/mapview/calibrate.py disc <png> --screen editor|ingame` - fits the ring, writes
   `scripts/mapview/cal/<screen>_<W>x<H>.json` as accepted, not checked.
3. Check it, one of:
   - editor, with a save of the same generation: `calibrate.py stars <png> --colour 0,0,255 ...` gives the stars;
     pair them with the save's Explorers (`census_reader.read(save)`, `player` = the colour's slot) in a pairs file
     (metres + size or --map/--players) and `calibrate.py check <pairs.json> --screen editor --size 2560x1080`
     (PASS = every pair within 3 px; live London: 0.75-1.22 px);
   - any screen, no save needed, non-square maps only: `calibrate.py edges <png> --screen ingame --map zplondon
     --players 4` - the long edges must sit 0.5-2.5 px inside the model edge, both sides within 1 px (scaled by
     rim / 130.5 on larger screens, `edge_band`), and the map must
     reach the rim at both ends of the long axis (a map drawn off-centre inside the ring leaves a black cap).
4. `calibrate.py show` lists the records. Aiming refuses anything not accepted and checked (`--unchecked` drops
   only the check gate, for a first live look).

## Build a twin (editor saves only)

    python scripts/mapview/twin.py randmaps/zplondon.xs --players 4 --teams 2 --census <save.age3Yscn> \
        [--team-layout 1,2/3,4] [--out <dir>]

Output (default a fresh temp folder): `twin.json` + `twin.png`; the CLI prints the counts, the key objects (Keeps,
sockets, town centres ...), every grouping's member vote and measured anchor, owner verdicts, and the MISSING /
unmodelled / unjudged lists with reasons (either-arm random branches, search radii, in-area placements, runtime
anchors, route-docked neighbours). Live London 4p (2026-09-24): 35/35 key objects, 67/69 groupings, 0 extra,
0 owner mismatches; the two misses are real - the first riverside deco (asked at x = 12 m, 7.5 m off the map edge) never spawns on either bank (the census holds 3 instances per bank, at x = 90 / 198 / 328 m).

## Aim the camera (a running match or the editor, on the owner's word)

    python scripts/mapview/camera.py goto 280 344 --map zplondon --players 4 [--screen ingame] [--dry-run]
    python scripts/mapview/camera.py shot 280 344 --map zplondon --players 4 --name bridge
    python scripts/mapview/camera.py record 280 344 --map zplondon --players 4 --name bridge --seconds 60
    python scripts/aitest/snapshots.py <out> --world targets.json --map zplondon --players 4

The camera clicks only inside the disc (6 px from the rim), only after the ring probes pass on a fresh screenshot,
with the corner abort and a foreground + window-under-the-cursor check before every event; it verifies the outline's
aim point within 3 px and stops a batch the moment the game loses the foreground. Output defaults to a temp folder.

## Random spawns: census the scenario, then photograph it (proven 2026-09-24)

Generate in the editor and save; read each object's exact position from the save by its proto
(`census_reader.read(save)`, e.g. St Paul's = `zpSPCLondonBasilica`) or take the twin's measured grouping anchors;
load the scenario (editor File > Load Scenario, sheet `editor.file_load`) and shoot with
`camera.py shot X Z --size <the save's map size> --screen editor`. London 4p: St Paul's read at (241.7, 260.9) - the
south spot in that generation - photographed there, the Minster on the north spot.

## Game UI through `python -m scripts.gameio`

`shot`, `pixel`, `click`, `key`, `type`, `menu <name>` (clicks a main-menu button only when the live layout and the
button's label probe match), `state`, `where`; `--dry-run` everywhere. Points and their provenance live in
`scripts/gameio/sheets/2560x1080.json` (derived points are refused). The September patch moved the main menu: the old
Skirmish point (444,490) now hits Multiplayer.
