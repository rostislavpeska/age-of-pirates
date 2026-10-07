---
name: lobby-minimap
description: Make a map's lobby minimap images (<map>_mini.png with the NEW / REWORKED ribbon, <map>_mini2.png plain) the way the finished AoP maps were made - a passive-AI skirmish, the map revealed by cheat, two captures of the extended in-game minimap, the disc cut clean, and the owner's Photoshop template (gold border for normal maps, silver for historical ones). Also the loading-screen screenshots (<map>_01..03.png: camera on the settlements, HUD-free crop, the parchment frame only). Use when a map needs its lobby / picker image or loading screenshots, when asked for "the minimap image", "the lobby minimap", "the NEW ribbon", "map screenshots", or when a map still borrows another map's images.
---

# Lobby minimap images

Owner 2026-10-07 (the Danube): "start game on Danube, extend minimap - use the extend button, take 2 printscreens of
the minimap (to eliminate the screen area rectangle), find the minimap psd, do a clean circle and add the border -
avoid any artifacts, especially on the bottom - then generate 2 versions, one New (with the ribbon), one normal";
"you have to use Photoshop here"; "use the cheat to discover the map: mircator"; the silver border "is for historical
maps - track it in the skill".

## The convention (measured on the finished maps, 2026-10-07)

| What | Value |
|---|---|
| Files | `data/wpfg/resources/images/icons/random_map/<map>/<map>_mini.png` (the lobby shows it; may carry a ribbon) and `<map>_mini2.png` (the same, plain) |
| Lobby XML | `imagepath = "ui\random_map\<map>\<map>_mini"` in the map's `<stem>.xml` |
| Image | 512 x 512 RGBA, transparent outside the frame's drop shadow |
| Map disc | centre 256 / 256, the map out to r 226 px; the in-game minimap's own dark edge shading is kept |
| Border | **gold** for normal maps (template layer `Vrstva 1`: Elbe, Kurils, Mississippi, Dead Sea, Malta, Adriatic Sea, Australia ...), **silver** for historical maps (`Vrstva 30`: London, Paris, Istanbul, Independence War, Versailles, Aztec City, Civil War, Florence, Fall of Venice, Crownlands, King of Bohemia). Owner: the silver one "is for historical maps" |
| Ribbons | NEW (`Vrstva 2`, box 85..407 x 421..511), REWORKED (`Vrstva 29`) - only on `_mini.png` |

Measured: Istanbul and London's rings are identical; every gold map's ring from r 232 out equals `Vrstva 1`
pixel for pixel; London = its disc over `Vrstva 30`, Elbe = its disc over `Vrstva 1`.

## The template

The owner's `minimap_template.psd` (on his OneDrive: `<OneDrive>/age_of_pirates_wip_files/icons/`, 512 x 512, 41
flat layers named `Vrstva N`, the finished maps' discs among them, most hidden). Never open or save the original:
`compose_lobby_minimap.py` copies it and works on the copy. Pillow reads only 2 of its 41 layers; use Photoshop
through the `photoshop-live-edit` skill (COM + ExtendScript, no screen clicks; `start_photoshop.ps1` starts it).

## Procedure (about 15 minutes of screen control: warn the owner and wait for his go - AGENTS.md rule 11)

All paths below are relative to this skill's `scripts/` unless written otherwise; captures and outputs go to the
session scratchpad (AGENTS.md rule 8).

1. `python passive_ai.py apply` - every AI control flag off in both mod AI files (temporary; never commit it).
2. Start the game (the `game-startup` skill: Steam URL, Esc through the intros). `python game.py saver` must say no
   screen saver - a screen saver swallows all input; ask the owner to wake the screen, never end it by script.
3. Home -> Skirmish -> the lobby: pick the map with the harness's own picker
   (`driver.select_map(nav, "<display name>", custom=True)` from `<repo>/scripts/aitest/driver.py`; the mod's maps are
   only under Custom Maps), 2 players (the players dropdown at the top of the right panel), Play.
4. In the match: reveal the map with full visibility, `python game.py cheat mercator` (the `aoe3-cheats` skill; the
   spelling `mircator` only lands in the chat). A recognised cheat leaves no chat line. `X marks the spot` alone
   leaves the fog of war: the map comes out darker than the finished images, with a glow round your own base.
5. Press the minimap's extend button (the four-arrow icon at the minimap's top right; 2880 x 1800: 2848, 1380).
6. Two captures with the camera elsewhere: click the minimap at a far point inside the disc, click a neutral
   terrain spot to park the cursor (never a screen corner: the camera edge-scrolls), `python game.py shot A.png`;
   the same at an opposite point for `B.png`. 2880 x 1800: minimap points 2111, 1025 and 2561, 1525, park 900, 900.
   Capture A's view outline must lie inside the disc.
7. End the match with the harness (`driver.end_match(nav)`), `python passive_ai.py revert` (prints that both AI
   files equal HEAD), close the game (Exit, Yes) unless the owner keeps it open.
8. `python minimap_disc.py A.png B.png <map>_disc.png --mask mask.png` - look at the mask: red = the outline
   replaced from B, blue = icons that moved (kept as in A).
9. `python compose_lobby_minimap.py --template <minimap_template.psd> --disc <map>_disc.png --name <map>
   --border gold|silver --ribbon new|reworked|none --out <dir>`
10. `python check_lobby_minimap.py <dir> <map> <map>_disc.png --border gold|silver` must print OK.
11. Send both PNGs and a side-by-side with a finished map of the same border. Install only on the owner's word:
    the two files into `data/wpfg/resources/images/icons/random_map/<map>/` and the `imagepath` in the lobby XML
    (sync the editor copy: `python <repo>/scripts/tools/sync_local_maps.py --sync`).

## Pitfalls (each cost time on 2026-10-07)

- **A "darker pixel wins" merge** deletes or doubles the icons that move between the two captures (fish, herds).
  Replace only capture A's outline (what `minimap_disc.py` does).
- **The disc radius:** past r 226 it covers the ring's inner edge, short of it the template's old map shows through.
  `check_lobby_minimap.py` catches both.
- **Photoshop:** selecting a layer through `activeLayer` makes it visible - set visibility explicitly afterwards.
  A plain child `powershell.exe` on this device refuses unsigned scripts: the compose script passes
  `-ExecutionPolicy Bypass` for that one process.
- **The NEW ribbon covers the bottom of the disc:** a base standing there disappears behind it (the Danube's blue
  fort, 2026-10-07; the sides are drawn at random in 1v1).
- **Shell heredocs collapse backslashes** (AGENTS.md rule 6): write scripts to files.
- **A screen saver eats every click and key** (PrintWindow captures still work). On the owner's OLED laptop it is
  the maker's pixel-refresh screen saver after 30 min idle, not a lock: an approval given remotely after a long idle
  finds it already running. `game.py saver` detects it; the Windows keep-awake API cannot prevent it (Microsoft:
  "does not stop the screen saver from executing"). Ending it needs the owner's explicit yes.

## Facts the scripts rest on (2880 x 1800, 2026-10-07)

- The extended minimap's frame: centre 2369.5 / 1259.5, inner edge r 483.9 px (fit on the green -> brown step,
  665 of 716 rays within 2.5 px, the same in both captures). Other resolutions: `minimap_disc.py --fit`, then
  record the circle here.
- The map darkens over its last ~30 px before the frame (the in-game edge shading); the finished images keep it.
- The compass markers and the extend button sit on the frame, not on the map.

## Loading-screen screenshots (`<map>_01..03.png`)

Owner 2026-10-07: three per map, usually the native settlements; no sky in the picture; standard in-game views are
fine ("photomode seems to be too tricky"; "stop chasing the engine"). Only what is below is proven.

**What the owner ships is his own photo-mode shots** (the Danube's final set, his commit 45279420, replaced the agent's
top-down shots the same evening): a low camera close to the subject, a horizon and a strip of sky under the frame's
top edge, a warm late-day lighting preset, and a foreground that leads in (01: the bridge with the castle behind it;
02: the Hussite camp at sunset; 03: the Orthodox monastery up close). Treat the agent's top-down shots as placeholders
until he replaces them, and compare any new set against `data/wpfg/resources/images/icons/random_map/danube/`.

| What | Value |
|---|---|
| Files | `<map>_01.png` .. `_03.png` beside the minimap images; lobby XML `<loadss>ui\random_map\<map>\<map>_01</loadss>` x 3 |
| Image | 1200 x 600 RGBA |
| Template | `Map Image Template.psd` (same OneDrive folder, 735 MB, 180 flat layers): the burnt-parchment frame `Vrstva 33` over the screenshot, the screenshot opaque inside the frame's outer edge (bbox 37..1174 x 1..598) and transparent outside. Frame + screenshot reproduces `london_04.png` within 0.8 levels |
| NEVER | `Layer 1` / `Layer 1 kopie` (soft-light parchment overlays): owner, "makes the image look 50% cheaper" |

Safe procedure, in the same passive-AI match as the minimap (steps 1-4 above; screen control announced):

1. Read each settlement's icon on the live minimap (huts = natives, crowns = electors). Groupings placed at random
   sit ~20 m from mapsim's prediction: aim at the icon, not at the script. World point =
   `transform.minimap_to_world(icon_x - 4.5, icon_y - 7, size_x, size_z, cal)` (`<repo>/scripts/mapview`; the
   icon's centre sits 4.5 / 7 px below-right of the object, measured on a fixed castle).
2. Per shot: `game.py move 1700 30` (top bar: clears any hover tooltip), then
   `python <repo>/scripts/mapview/camera.py shot X Z --map game/randmaps/<stem>.xs --players 2 --screen ingame
   --name <n> --out <scratch>` (the `minimap-twin` skill). It must print OK or CLIPPED within 3 px.
3. Pick a HUD-free crop of the full shot at the shape's aspect 1.976 (1138 x 576). 2880 x 1800: x1 <= 2370 with
   y in 105..1290 (e.g. 0,105,2341,1290), or x1 <= 2195 with y down to 1515 (e.g. 0,345,2195,1456). A large building
   (Jesuit cathedral, Orthodox monastery: ~1150 px tall) only just fits; the camera centres the object's ground
   point, so the building stands high in the picture.
4. QC: no black void (a settlement within ~40 m of the map edge shows it - the Danube's Hussite camp; pick another),
   no HUD, no cursor.
5. Export once from a COPY of the template (photoshop-live-edit; visibility set explicitly, PNG copy) `Vrstva 33`
   (frame) and `Vrstva 156` (London's screenshot = the shape), then
   `python compose_loading_screen.py --frame vrstva33.png --shape vrstva156.png --shot <full>.png --crop X0,Y0,X1,Y1
   --out <map>_0N.png` and send the three as one sheet. The Danube's 2026-10-07 set was made this way.

Do NOT (each cost time on 2026-10-07): photo mode (it keeps its own camera per game process, R resets to that, and
leaving it drags the game camera to the photo spot); arrow or WASD keys (one 0.08 s tap crossed half the map); own
minimap clicks with the cursor parked ON the minimap (the camera follows the cursor); the mouse wheel to zoom out
(the default view is already the widest). `camera.py` refuses (`minimap_lost`, 5 of 8 probes) when a hover tooltip
from its own park point covers the ring - step 2's cursor move prevents it (INC-134).

Related: `aoe3-cheats`, `game-startup`, `photoshop-live-edit`, `minimap-twin` (the camera), `map-minimap` (editor
generations, not the lobby image), `ui-calibrate` (another screen size).
