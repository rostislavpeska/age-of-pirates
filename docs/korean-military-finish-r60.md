# Korean military r60 texture correction

**Review update:** the owner still reports reversed tile shadows. The roof is
unaccepted. The analytic profile and native checks below are bounded evidence,
not proof that the final game appearance is correct. See the canonical baking
skill `roof-tile-direction-qa` and the Korean r61 diagnostic record.

The r60 candidate contains a tile-lap source-profile repair, stronger Photoshop
window contact shading, and Painter dust/timber wear. Six BaseColor/Normals/Masks
DDTs changed under `art/zbench_korean_military/`. The same maps serve the intact
and damaged models. Geometry, runtime UVs, Havok, material XML, player-color maps
and protected Town Center resources are unchanged; one own 2048 atlas per model.

## Root causes and prevention

- **INC-135, roof laps:** the source coordinate increases uphill, but the old
  relief phase placed its sharp drop uphill. Correct the HIGH profile sign and
  rebake all 16 owner regions; do not guess a normal green-channel flip. Keep tile
  IDs, end alpha and accepted ridge geometry. The generic roof-lap gate includes
  wrong-sign, flat-profile and reversed-sample tests; Korean roof rules retain
  the measured recipe. A second failure came from a stale Blender scene transform:
  update the dependency graph before freezing HIGH/LOW transforms, and make
  script exceptions return a nonzero background Blender exit code.
- **INC-136, misleading Painter readiness:** a hidden scripting process was
  incorrectly conflated with the owner's visible instance. Report process PID,
  window visibility, API reachability, project and verified operation separately.
  Discover paths on each device. Mutations with multiple Painter processes require
  the expected API PID. The owner's manually opened project was not touched.
- **INC-137, incomplete Painter proxy:** historical owner labels omitted 39,252
  Barracks and 11,107 Stable used texels. The repaired proxy covers all current
  own-atlas texels, including AO variants, without duplicating complete shared
  readers. Its clipped additions preserve current positions/normals and do not
  alter the game mesh. A raster coverage gate now has targeted negative fixtures.
- Photoshop exported cleared RGB beneath alpha zero. Preserve the editable PSD,
  but import only the authorized window regions and their padding into the frozen
  atlas. Painter also has small exterior/gutter export differences: use the
  validated scoped delta, not an unverified whole-page replacement.

## Application proof and validation

Actual Photoshop COM edits produced four layered PSDs. Actual Painter 9.1.2 edits
added `r60 mineral dust and timber wear` with its native Dirt generator to both
sets; project save/reopen/export passed. Public project/resource/export APIs work.
This version has no public layerstack API; named layer/generator edits use the
separately tested bounded Qt adapter. The original crashing batch adapter remains
quarantined. No claim of a full modern Painter API or bit-identical whole export.

The edited cores reproduce within 1/255 for color and exactly for roughness.
Preservation checks match 466 source/candidate geometry, transform, UV and material
records. Independent review verified current proxy coverage, protected channels,
eight shot hashes and six installed DDT hashes. The targeted tool tests passed:
49 tests plus six subtests, followed by 12 owner-coverage/local-environment tests.

Strict installed native checks: **Barracks 23 PASS, Stable 25 PASS; zero FAIL/SKIP**.
Both models retain the previously corrected r59 runtime V convention.

```powershell
python scripts/havok/gr2_lint.py --profile korean_barracks_physics art/zbench_korean_military/barracks
python scripts/havok/gr2_lint.py --profile korean_stable_physics art/zbench_korean_military/stable
```

Author sources, seven handoffs, actual application logs, matched renders, raw bake
masters, rollback maps and hashes are in the Korean repository's r60 snapshot.
Resolve its location through `$AOP_KOREAN_REPO/CURRENT.json.military_current` and
`python tools/assets.py --verify --all` there. Local paths remain device settings.

## Manual review remains

No agent-controlled r60 engine appearance or destruction playtest was performed. Native lint and
Blender renders do not constitute owner acceptance. Restart/reload the game to
avoid stale maps and inspect **Korean Barracks** (`zzKoreanBarracksPhysics`) and
**Korean Stable** (`zzKoreanStablePhysics`). Paid image calls: zero.
