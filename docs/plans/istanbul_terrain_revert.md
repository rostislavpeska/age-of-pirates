# Istanbul: the "terrain revert" test build

**THIS IS NOT A TERRAIN-ONLY BUILD.** Read that first. It is commit **#28
`7a493420`** — the whole thing, city grid, spawns, triggers, data — with exactly
**four terrain constants** put back to their **#27 `be0e554c`** values. It is
~99% #28.

The terrain-only build that was actually requested (#27 base + #28's terrain
changes only) **could not be produced** — see "Why" below.

Verified to GENERATE in the scenario editor at seed 4242, screenshot-confirmed.

## The four changed lines

| line | constant | #27 | #28 | this build |
|---|---|---|---|---|
| 418 | `cityExtendTilesN` | 15 | 23 | **15** |
| 419 | `cityExtendTilesS` | 15 | 23 | **15** |
| 2239 | `wallOffTilesS` | 1 | 3 | **1** |
| 2401 | `dockSizeTiles` | 230 | 350 | **350** |

Four differing lines out of 5,844. Everything else is byte-identical to #28.

## Reproduce

    git checkout --detach 7a493420
    # then set those four constants in randmaps/zpistanbulb.xs to the #27 column

Or with the harness, which does it in one command:

    python -u exp_config.py --target 7a493420 \
        --set-int cityExtendTilesN=15 cityExtendTilesS=15 \
                  wallOffTilesS=1 dockSizeTiles=350 \
        --runs 8 --minutes 60 --tag terrain-revert

## Why the real terrain-only build could not be made

Applying #28's terrain hunks onto a #27 base ALWAYS failed to load — at 1 hunk,
16 hunks, 18 hunks and a 31-hunk dependency closure. The mechanism is visible in
the source: #28 did not merely change `cityExtendTilesN` from 15 to 23, it also
added a **new consumer** that compensates by subtracting `wildIntoCity = 6`
(zpistanbulb.xs:1461-1462 in #28). Take the constant without its consumer and
the city cliff overruns, so generation dies. That pairing pattern repeats
through the commit: terrain constants and the placement code that reads them
were retuned as one piece of work.

So "#27 + #28 terrain" is not expressible as a subset of the diff. Producing it
would require hand-porting each terrain change together with whatever geometry
downstream of it must move — real map-authoring work, not patching.

## Test setup notes that cost time to learn

* Test maps must be deployed to the **Steam install** folder,
  `C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game\RandMaps`.
  The user-profile `RandMaps` is never scanned.
* Deployed map scripts are **LF**. The repo keeps CRLF; deploying CRLF makes the
  engine fail with an access violation during generation.
* A map needs its **`.mods.xml`** deployed alongside. #28's script maps `Dock`,
  `Church`, `House` etc. onto custom `*_city.xml` placement rules; without it the
  map silently "FAILED TO LOAD". #27's script does not need it.
* A `<name>.mods.xml` occupies its **own row** in the editor's map selector,
  sorting ABOVE the plain name — so adding it shifts every row below it.
