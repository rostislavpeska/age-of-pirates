"""London layout judge: read a saved generation of zplondon and check the layout of the user's Figma
sketch (measured 2026-09-17: 10 block lines across the map, the road between the 8th and 9th; 4 lines
per bank along the river; straight shoreline).

    python sandbox/census/london_judge.py <save.age3Yscn> [--players 4]

Everything is measured from unit POSITIONS (census.py's record scan) and building fingerprints; proto
NAMES of mod units are only partly reliable, so the road, the river and the grid come from geometry:
  river  = the widest gap in the z distribution of buildings (city middle, away from the bridge)
  road   = the widest gap in the x distribution of buildings in the outer band, away from the bridge
  rows   = 00 and 0 behind the road (25.2 m off it, 34 m apart), 1..8 in front (18 m off the road, then 34 m pitch)
  cols   = 32 m bands from column 1 (64 m off the river centre) outward
Checks:
  R1 road corridor 10-16 m between block edges (Paris 13 m)
  R2 every cell of rows 00..8 x columns 1..4 holds buildings
  R4 Tower of London at rows 7-8 x columns 1-2 (at the water) on both banks
  R5 St Paul (S) / Minster (N) at rows 1-2 x cols 1-2; palaces at row 3
  B1 14 bridge faces centred within 6 m of the crossing
  S1 a non-prop unit on the road line at the crossing (the bridge socket)
  T1 one SocketTradeRoute per bank at row 1 x column 3 (the trade block beside the cathedral, socket toward the road)
  F1 the Figma's fixed EU blocks: 2 zpSPCMenagerie (row 4 col 2), 2 zpSocketJewishEU (row 6 col 3), 2 zpSPCCapturableFactory (row 0 col 2), 2 Construction (row 0 col 1, fingerprint zpUnderbrushConstructionJesuitTemple); the Park has no fingerprint proto; the Mill (zpSPCTownMill) in the Destilery's place; no Forester in the city
  H2 harbour guards: 4 dePrivateerGuardian + 4 zpNuggetInvisibleWater (nuggetmods zpNuggetLondonHarbour, difficulty 603)
  T2 the Towers' capturable flags (2), their Redcoat guards (10 each, nugget 605), the two Academy rewards (nugget 604)
  D1 the Paris riverside decorations (EU_Riverside_SW_01_270 south / NE_01_270 north, 4 per bank): >= 10 PropSwan on the map
  H1 four pier harbours (2 per bank at the rows 7-8 and rows 4-5 centres): >= 10 zpHarbourPlatform each, one zpOrientalFerry post (placed first, Venice City's way) within 3 m of each asked spot
  W1 straight shoreline: no building inside the river band away from the bridge
Prints the occupancy matrix so a missing block is one glance.
"""
import argparse
import sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from census import census  # noqa: E402

BUILDINGS = {"zpSPCEUHouseProp", "zpSPCCityBuildingMix", "deSPCWaterlooHouseProp", "zpSPCCityHouse",
             "zpNativeHouseOrthodox", "zpSPROPBuildingMix", "zpNatEUBritishPalaces", "zpNatEUScottishPalaces",
             "zpSPCLondonBasilica", "zpSPCMinster", "zpSPCTowerOfLondon", "SPCFortCorner", "SPCFortTower",
             "SPCFortWallMedium"}
PROPS = {"SPCPathBlock3", "PropsColony", "PropsPoles", "PropsPottedPlants", "zpPropsFlowers", "zpPropsFlowersBohemia",
         "deNatEUPropFence", "zpPropsColony", "zpNatEUPropFencDarkBrickB", "deSPCTreeCypressProp", "UnderbrushCoastalJapan",
         "deSPCTreeOakProp", "zpPropMarketStall", "deNatEUPropVilMale", "deNatEUPropVilFemale", "UnderbrushCalifornia",
         "UnderbrushCeylon", "UnderbrushAraucania", "dePropsAnimalsChicken", "deNatEUPropStatue", "zpHCFountainA",
         "zpHCFountainC", "SPCPathBlock1", "zpHCUnitA", "zpHCUnitB", "zpHCUnitC", "zpPropJesuitFence", "ypSMJesuitAccessory",
         "NativeTownObstruction", "zpNativePropsCastleGuards", "deNuggetAfricanDroppedWood", "zpNativePropsCastleLeaders",
         "zpPropStatueHomeCity", "zpNatEUPropFencDarkBrick", "deNatEUPropVilLeaders", "zpNatEUPropObelisk", "SPCFlag",
         "zpSPCFortWallProp", "zpHarbourPathBlock3", "zpNativeUnitVenetianPoles", "SPCFortWallLarge", "deSPCEuroTower",
         "zpBridgeFace", "zpHarbourPlatform", "ypSMSufiAccessory", "dePropsAnimalsCamel", "zpPropJewishMarketStall",
         "zpHarbourShip", "zpHarbourCenterVenice"} | BUILDINGS
PITCH_M, COL_M, GAP_FAR_M, GAP_NEAR_M, COL1_M = 34.0, 32.0, 18.0, 18.0, 64.0
ROWS = ["00", "0", "1", "2", "3", "4", "5", "6", "7", "8"]


def widest_gap(values, lo, hi, min_gap=6.0):
    vs = sorted(v for v in values if lo <= v <= hi)
    best = (0.0, None, None)
    for a, b in zip(vs, vs[1:]):
        if b - a > best[0]:
            best = (b - a, a, b)
    return best if best[0] >= min_gap else (0.0, None, None)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("save")
    ap.add_argument("--players", type=int, default=4)
    ap.add_argument("--size-x", type=float, default=360.0)
    a = ap.parse_args(argv)
    size_z = 573.0 if a.players < 3 else (653.0 if a.players < 6 else 773.0)
    U = [u for u in census(a.save) if u["x"] == u["x"]]
    B = [u for u in U if u["proto"] in BUILDINGS]
    res = []

    def check(code, ok, msg):
        res.append((code, ok, msg)); print(f"  {'PASS' if ok else 'FAIL'} {code}  {msg}")

    mid = [u for u in B if 60.0 <= u["x"] <= 250.0]
    gap, z0, z1 = widest_gap([u["z"] for u in mid], size_z * 0.25, size_z * 0.75, 12.0)
    z_river = (z0 + z1) / 2 if z0 else size_z / 2
    print(f"river: buildings stop at z {z0} .. {z1} -> centre {z_river:.1f} (gap {gap:.0f} m incl. promenades)")
    outer = [u for u in B if abs(u["z"] - z_river) > 60.0]
    gap, x0, x1 = widest_gap([u["x"] for u in outer], a.size_x * 0.55, a.size_x, 6.0)
    x_road = (x0 + x1) / 2 if x0 else a.size_x * 0.78
    # the two on-route controllers (f 0.25 / 0.75 of the land route) carry the exact road x; prefer them
    ctrl = [u for u in U if u["proto"] in ("zpSPCWaterSpawnPoint", "Travois") and abs(u["x"] - x_road) < 15
            and (abs(u["z"] - size_z * 0.25) < 25 or abs(u["z"] - size_z * 0.75) < 25)]
    if ctrl:
        x_road = sum(u["x"] for u in ctrl) / len(ctrl)
    print(f"road corridor: buildings stop at x {x0} .. {x1} -> road centre {x_road:.1f}, corridor {gap:.0f} m")
    check("R1", x0 is not None and 10.0 <= gap <= 18.0, f"road corridor {gap:.0f} m between block edges (Paris 13 m)")

    def row_of(x):
        if x > x_road:
            return "00" if x > x_road + GAP_FAR_M + PITCH_M / 2 else "0"
        return str(int(round((x_road - GAP_NEAR_M - x) / PITCH_M)) + 1)

    def col_of(z):
        d = abs(z - z_river)
        return int(round((d - COL1_M) / COL_M)) + 1, ("N" if z > z_river else "S")

    occ = defaultdict(Counter)
    for u in B:
        if abs(u["z"] - z_river) < 50.0:      # bridge units are not city blocks
            continue
        r = row_of(u["x"]); c, bank = col_of(u["z"])
        if r in ROWS and 1 <= c <= 4:
            occ[bank][(r, c)] += 1
    for bank in ("S", "N"):
        print(f"  bank {bank}: rows 00..8 x columns 1..4 (buildings per cell)")
        for r in ROWS:
            print(f"    row {r:>2}: " + "  ".join(f"{occ[bank][(r, c)]:3}" for c in range(1, 5)))
    empty = [(bank, r, c) for bank in ("S", "N") for r in ROWS for c in range(1, 5) if occ[bank][(r, c)] == 0]
    check("R2", not empty, f"empty block cells: {empty or 'none'}")
    towers = [(row_of(u["x"]), col_of(u["z"])) for u in U if u["proto"] == "zpSPCTowerOfLondon"]
    check("R4", len(towers) == 2 and all(r in ("7", "8") and c in (1, 2) for r, (c, _) in towers) and {b for _, (_, b) in towers} == {"S", "N"},
          f"Tower of London at {towers} (expected rows 7-8 x columns 1-2 at the water, one per bank)")
    sp = [(row_of(u["x"]), col_of(u["z"])) for u in U if u["proto"] == "zpSPCLondonBasilica"]
    mi = [(row_of(u["x"]), col_of(u["z"])) for u in U if u["proto"] == "zpSPCMinster"]
    pal = Counter(col_of(u["z"])[1] + str(row_of(u["x"])) for u in U if u["proto"] in ("zpNatEUBritishPalaces", "zpNatEUScottishPalaces"))
    check("R5", bool(sp) and bool(mi) and sp[0][0] in ("1", "2") and mi[0][0] in ("1", "2") and sp[0][1][1] == "S" and mi[0][1][1] == "N"
          and all(k[1:] == "3" for k in pal), f"St Paul {sp}, Minster {mi}, palaces by bank+row {dict(pal)}")

    faces = [u for u in U if u["proto"] == "zpBridgeFace"]
    near = [u for u in faces if abs(u["x"] - x_road) < 40 and abs(u["z"] - z_river) < 60]
    cx = sum(u["x"] for u in near) / len(near) if near else float("nan")
    cz = sum(u["z"] for u in near) / len(near) if near else float("nan")
    check("B1", len(near) >= 14 and abs(cx - x_road) <= 6 and abs(cz - z_river) <= 6,
          f"bridge faces at the crossing: {len(near)} (centre {cx:.1f},{cz:.1f} vs road {x_road:.1f}, river {z_river:.1f}); all {len(faces)}")
    socks = [u for u in U if abs(u["x"] - x_road) <= 8 and u["proto"] not in PROPS and u["y"] > 0.5]
    at_bridge = [u for u in socks if abs(u["z"] - z_river) < 25]
    check("S1", len(at_bridge) >= 1, "road-line units at the bridge: " + ", ".join(f"{u['proto']}({u['z']:.0f})" for u in at_bridge))
    tsock = [(row_of(u["x"]), col_of(u["z"])) for u in U if u["proto"] == "SocketTradeRoute"]
    check("T1", len(tsock) == 2 and all(r == "1" and c == 3 for r, (c, _) in tsock) and {b for _, (_, b) in tsock} == {"S", "N"},
          f"trade sockets at {tsock} (expected row 1 x column 3, one per bank)")
    hx1 = x_road - GAP_NEAR_M - 6.5 * PITCH_M; hx2 = x_road - GAP_NEAR_M - 3.5 * PITCH_M   # rows 7-8 / rows 4-5 centres
    nz = z_river + 16.0 + 32.0 - 12.0; sz = z_river - 16.0 - 32.0 + 10.0                  # grouping origins: pier shore edge 16 tiles off the leg (leg 16 m), top edge back
    spots = {"N1": (hx1 - 1.5233, nz - 3.5141), "N2": (hx2 - 1.5233, nz - 3.5141),
             "S1": (hx1 - 0.4970, sz + 5.7479), "S2": (hx2 - 0.4970, sz + 5.7479)}          # asked post spots (units z +1)
    posts = [u for u in U if u["proto"] == "zpOrientalFerry"]
    hmsg = []; hok = True
    for tag, (px, pz) in spots.items():
        plat = [u for u in U if u["proto"] == "zpHarbourPlatform" and abs(u["x"] - px) < 22 and abs(u["z"] - pz) < 18]
        near = [u for u in posts if abs(u["x"] - px) <= 3 and abs(u["z"] - pz) <= 3]
        hok = hok and len(plat) >= 10 and len(near) == 1
        hmsg.append(f"{tag}: {len(plat)} platforms, ferry post {'at ' + str((round(near[0]['x'], 1), round(near[0]['z'], 1))) if near else 'MISSING'} (asked {px:.1f},{pz:.1f})")
    check("H1", hok, "harbours " + "; ".join(hmsg) + f"; zpOrientalFerry on the map {len(posts)} (4 expected)")
    fixed = {"zpSPCMenagerie": 2, "zpSocketJewishEU": 2, "zpSPCCapturableFactory": 2,
             "zpSPCCityMarket": 2, "zpSPCNationalBank": 2, "zpSPCGoldSmelter": 2, "zpSPCTownMill": 2, "zpUnderbrushConstructionJesuitTemple": 2}
    got = {k: sum(1 for u in U if u["proto"] == k) for k in fixed}
    check("F1", all(got[k] == v for k, v in fixed.items()), f"EU blocks, one per bank each (fixed + Paris zone resources): {got}")
    guards = sum(1 for u in U if u["proto"] == "dePrivateerGuardian"); nugs = sum(1 for u in U if u["proto"] == "zpNuggetInvisibleWater")
    check("H2", guards == 4 and nugs >= 4, f"harbour guards: {guards} dePrivateerGuardian, {nugs} water nuggets (4 each expected; needs the game restarted after the nuggetmods edit)")
    flags = sum(1 for u in U if u["proto"] == "deSPCCapturableFlagCossack"); redcoats = sum(1 for u in U if u["proto"] == "deSPCHMRedcoat")
    academies = sum(1 for u in U if u["proto"] == "zpAcademyReward")
    check("T2", flags == 2 and redcoats >= 18 and academies == 2, f"Towers: {flags} capturable flags, {redcoats} Redcoat guards (20 after a restart); Academy rewards {academies} (2)")
    swans = [u for u in U if u["proto"] == "PropSwan"]
    check("D1", len(swans) >= 10, f"riverside decorations: {len(swans)} swans (4 x SW_01 = 4, 4 x NE_01 = 8; the mouth pair may lose some off the edge)")
    intruders = [u for u in U if abs(u["z"] - z_river) < 30 and abs(u["x"] - x_road) > 40 and u["proto"] in BUILDINGS]
    # promenade width: nearest building edge to the water on each bank, away from the bridge (equal on both banks, ~7 m)
    away = [u for u in B if abs(u["x"] - x_road) > 40]
    prom_s = z_river - max(u["z"] for u in away if u["z"] < z_river); prom_n = min(u["z"] for u in away if u["z"] > z_river) - z_river
    print(f"  promenade: nearest building south {prom_s:.1f} m, north {prom_n:.1f} m off the river centre (walls at 44 m)")
    check("W1", not intruders, f"buildings inside the river band away from the bridge: {len(intruders)} (straight shoreline expected)")
    fails = [c for c, ok, _ in res if not ok]
    print("VERDICT:", "PASS" if not fails else "FAIL " + " ".join(fails))
    return 0 if not fails else 1


if __name__ == "__main__":
    raise SystemExit(main())
