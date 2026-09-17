// ============================================================================
// zplondon.xs  -  London on the Paris rig, laid out to the user's Figma sketch
// (2026-09-17, measured from the sketch: 10 block lines across the map, the
// road between the 8th and 9th; 4 lines per bank along the river).
// The LONG axis is z (573 m), the Thames runs along x at z = 0.5 with a
// STRAIGHT shoreline, the land route runs along z near the x = 1 edge with
// TWO block rows behind it and eight in front, players sit at both z ends.
// Editor twin: Steam Game\RandMaps\00000_zplondon.xs (row 2 of the Type list).
// LAYOUT STAGE: no resources, no countryside content, no walls; triggers = the harbour guards only,
// one trade block per bank at row 1 x col 3 (socket toward the road), the socket on London Bridge, the north-west
// harbours EU_SPC_London_Harbour_NW_01 / _SE_01, two per bank (rows 7-8 and rows 4-5), shore edge 2 tiles
// into the city, their posts (zpOrientalFerry, Istanbul's ferry) placed FIRST and linked to the lane, the
// groupings hung off the posts' real positions (zpvenicecity 1:1, minus scaffolds).
// ----------------------------------------------------------------------------
// EVERY POSITION IS INHERITED FROM REAL TRADE-ROUTE OBJECTS (user 2026-09-18): x from the land
// route's docked controllers, z per bank from a docked controller on that bank's lane leg; the
// river centre is the middle of the two real legs. One city number (cityDistTiles), one harbour
// number (harbourShoreTiles, off the leg), the bridge's own offset - nothing else moves a bank. Every tile /
// metre helper gets a POSITIVE argument (they ignore negatives silently - Istanbul's documented bug).
// GRID = Paris's numbers on a 360 m short side, the corridor moved from
// Paris's middle route to the London road: 7 m margins, rows across x every
// 34 m (4 m streets), the corridor 3 + 3 m around the road; columns along z
// every 32 m (2 m streets) from a 7 m quay promenade.
//   row 00, row 0   behind the road (toward x = 1)
//   rows 1-8        in front of the road       rows 1-2 x cols 1-2 = St Paul (S) / Minster (N)
//                                              row 3 x cols 1-2 = Stuart (S) / Parliament (N)
//                                              rows 7-8 x cols 1-2 = Tower of London, at the water
// BUILD ORDER (load-bearing, pinned by the 2026-09-17 water tests):
//   1. LAND route + on-route controllers + the bridge socket BEFORE any water
//      (a route built after water exists poisons every later water placement,
//      and an island needs a docked zpSPCWaterSpawnPoint on a built route)
//   2. the river: one "ZP Paris River" radius 40 (~84 m); RECT-MAP RULE: river
//      coordinates are read in size_x units -> z authored as metres / sizeX
//   3. London Bridge with rmPlaceGroupingInstanceAtLoc, max distance 0.00, no
//      scaffold; its height grid is cropped to the river (no baked quay)
//   1b. the U lane (mouth to row 3) built BEFORE the river + a fake stopper docked
//      on it - zpvenicecity's order
//   2b. four harbour posts (zpOrientalFerry) linked to the lane, right after the
//      river, real positions read back; a privateer guard nugget on the water each
//   3b. four harbour groupings hung off the posts (instance API, no scaffolds)
//   5. quays (straight, one per bank), streets, plain countryside
//   6. blocks in Paris's order: fixed doubles, fixed singles (Figma: Park r4c1, Menagerie
//      r4c2, Native Jewish r6c3, Factory r0c2), resource buildings in shuffled zones, treasures,
//      houses; 6b. Paris riverside decorations x4 per bank, 7. players,
//   8. ALL triggers at the end: one AutoConvert suspension for every capturable (4
//      posts, 2 menageries, 2 factories, 2 Tower flags), a release per guard nugget,
//      Istanbul's per-player Tower conversion family (flag taken -> the Tower follows)
// Distances are in TILES (1 tile = 2 m) or METRES; XS trap: never write
// intVar * floatVar (it truncates to 0) - pass ints to rmXTilesToFraction().
// XS trap 2: `label` is a keyword - never name anything label.
// ============================================================================
int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

// Drop a controller AT a route point and read where it really is (fractions
// in gRealX / gRealZ). rmPlaceObjectDefAtPoint always lands on the built route.
// Paris's city randomiser (Alistair's), verbatim: a list of cell locations split into zones, each zone shuffled,
// placeGroupings takes the first cells of a zone in shuffled order, filler takes the first FREE cell of a range.
int gCityLocs = -1;
int gCityLocsStatus = -1;

void shuffle(int arrayID = -1, int start = -1, int end = -1) {
  for (int i = end; i > start; i--) {
    int j = rmRandInt(start, end);
    vector temp = xsArrayGetVector(arrayID, i);
    xsArraySetVector(arrayID, i, xsArrayGetVector(arrayID, j));
    xsArraySetVector(arrayID, j, temp);
  }
}

void placeGroupings(int groupingsArrayID = -1, int startIndex = -1) {
  for (i = 0; < xsArrayGetSize(groupingsArrayID)) {
    int grouping = xsArrayGetInt(groupingsArrayID, i);
    vector loc = xsArrayGetVector(gCityLocs, startIndex + i);
    float locX = xsVectorGetX(loc);
    float locZ = xsVectorGetZ(loc);
    rmPlaceGroupingAtLoc(grouping, 0, locX, locZ);
    xsArraySetBool(gCityLocsStatus, startIndex + i, true);
  }
}

// Place grouping at the first free slot within the specified boundaries.
// Returns false if no more slots found.
bool filler(int groupingID = -1, int startIndex = -1, int endIndex = -1) {
  for (i = startIndex; <= endIndex) {
    bool taken = xsArrayGetBool(gCityLocsStatus, i);
    if (taken) continue;
    vector loc = xsArrayGetVector(gCityLocs, i);
    float locX = xsVectorGetX(loc);
    float locZ = xsVectorGetZ(loc);
    rmPlaceGroupingAtLoc(groupingID, 0, locX, locZ);
    xsArraySetBool(gCityLocsStatus, i, true);
    return true;
  }

  return false;
}

int gControllerIdx = 0;
float gRealX = 0.5;
float gRealZ = 0.5;
void routePoint(int tradeRouteID = -1, float fraction = 0.5)
{
	gControllerIdx = gControllerIdx + 1;
	int ctrl = rmCreateObjectDef("route controller " + gControllerIdx);
	rmAddObjectDefItem(ctrl, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefTradeRouteID(ctrl, tradeRouteID);
	rmSetObjectDefAllowOverlap(ctrl, true);
	rmSetObjectDefMinDistance(ctrl, 0.0);
	rmSetObjectDefMaxDistance(ctrl, 0.0);
	rmPlaceObjectDefAtPoint(ctrl, 0, rmGetTradeRouteWayPoint(tradeRouteID, fraction));
	vector loc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(ctrl, 0));
	gRealX = rmXMetersToFraction(xsVectorGetX(loc));
	gRealZ = rmZMetersToFraction(xsVectorGetZ(loc));
}

// A SocketTradeRoute linked to the route, searched within 4 m of the given spot
// (the road x is measured, so the spot is on the road).
int gSocketIdx = 0;
void routeSocket(int tradeRouteID = -1, float x = 0.5, float z = 0.5)
{
	gSocketIdx = gSocketIdx + 1;
	int sock = rmCreateObjectDef("TR socket " + gSocketIdx);
	rmAddObjectDefItem(sock, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefTradeRouteID(sock, tradeRouteID);
	rmSetObjectDefAllowOverlap(sock, true);
	rmSetObjectDefMinDistance(sock, 0.0);
	rmSetObjectDefMaxDistance(sock, 4.0);
	rmPlaceObjectDefAtLoc(sock, 0, x, z);
}

// The harbour post, zpvenicecity's "sockets to dock Trade Posts" 1:1: the post unit linked to the lane, min 0 /
// max 0.5, placed BEFORE its harbour grouping (the grouping is then hung off the post's REAL position, read back
// into gRealX / gRealZ - Venice's ControllerLoc idiom). The unit is Istanbul's ferry, zpOrientalFerry (user
// 2026-09-18, replacing zpTradingPostCaptureNaval); its look gets swapped per map via mapmods later.
int gPostIdx = 0;
int harbourPost(int laneID = -1, float x = 0.5, float z = 0.5)
{
	gPostIdx = gPostIdx + 1;
	int post = rmCreateObjectDef("harbour post " + gPostIdx);
	rmSetObjectDefTradeRouteID(post, laneID);
	rmAddObjectDefItem(post, "zpOrientalFerry", 1, 0.0);
	rmSetObjectDefMinDistance(post, 0.0);
	rmSetObjectDefMaxDistance(post, 0.5);
	rmPlaceObjectDefAtLoc(post, 0, x, z);
	vector loc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(post, 0));
	gRealX = rmXMetersToFraction(xsVectorGetX(loc));
	gRealZ = rmZMetersToFraction(xsVectorGetZ(loc));
	rmEchoInfo("LONDON harbour post " + gPostIdx + " asked " + rmXFractionToMeters(x) + "," + rmZFractionToMeters(z) + " m -> real " + xsVectorGetX(loc) + "," + xsVectorGetZ(loc));
	return(post);
}

// A harbour guard: nuggetmods zpNuggetLondonHarbour (difficulty 603 = zpNuggetInvisibleWater + one
// dePrivateerGuardian, the Fisherman's Guild mechanism of Istanbul moved onto the water), dropped in front of a
// pier at the exact spot (min / max 0). The caller latches rmSetNuggetDifficulty(603, 603) around the four calls.
int gGuardIdx = 0;
int harbourGuard(float x = 0.5, float z = 0.5)
{
	gGuardIdx = gGuardIdx + 1;
	int guard = rmCreateObjectDef("harbour guard " + gGuardIdx);
	rmAddObjectDefItem(guard, "zpNuggetInvisibleWater", 1, 0.0);
	rmSetObjectDefMinDistance(guard, 0.0);
	rmSetObjectDefMaxDistance(guard, 0.0);
	rmPlaceObjectDefAtLoc(guard, 0, x, z);
	return(guard);
}

// An island grouping: the instance API with an exact position (the rotated
// bridge places only this way; any search radius fails on water).
void placeIsland(int grouping = -1, float x = 0.0, float z = 0.0)
{
	rmSetGroupingMinDistance(grouping, 0.0);
	rmSetGroupingMaxDistance(grouping, 0.00);
	rmAddGroupingToClass(grouping, rmClassID("classPlateau"));
	int placement = rmPlaceGroupingInstanceAtLoc(grouping, x, z, 0);
}

// One city block grouping, Paris settings.
int cityBlock(string blockName = "", string blockFile = "")
{
	int g = rmCreateGrouping(blockName, blockFile);
	rmSetGroupingMinDistance(g, 0.00);
	rmSetGroupingMaxDistance(g, 0.50);
	rmAddGroupingToClass(g, rmClassID("classBlock"));
	return(g);
}

// A quay plateau (Paris "shore" area) clipped to a box: the box edge that faces
// the water becomes the quay wall ("ZP City" cliff, height 0); the matching
// streets paint (Paris "streets" area) uses the same box.
int gQuayIdx = 0;
void quaySegment(float x1 = 0.0, float z1 = 0.0, float x2 = 1.0, float z2 = 1.0, float sizeFrac = 0.7)
{
	gQuayIdx = gQuayIdx + 1;
	int box = rmCreateBoxConstraint("quay box " + gQuayIdx, x1, z1, x2, z2);
	int quay = rmCreateArea("quay " + gQuayIdx);
	rmSetAreaSize(quay, sizeFrac, sizeFrac);
	rmSetAreaLocation(quay, (x1 + x2) * 0.5, (z1 + z2) * 0.5);
	rmSetAreaCoherence(quay, 1.0);
	rmSetAreaBaseHeight(quay, 1.0);
	rmAddAreaInfluenceSegment(quay, x1 + (x2 - x1) * 0.1, (z1 + z2) * 0.5, x2 - (x2 - x1) * 0.1, (z1 + z2) * 0.5);
	rmSetAreaCliffType(quay, "ZP City");
	rmSetAreaCliffEdge(quay, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(quay, 0, 0.0, 1.0);
	rmAddAreaConstraint(quay, box);   // Paris: the shore area has only its box (no plateau avoidance - that gapped the bridge)
	rmAddAreaToClass(quay, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(quay, false);
	rmBuildArea(quay);
	int street = rmCreateArea("streets " + gQuayIdx);
	rmSetAreaSize(street, sizeFrac, sizeFrac);
	rmSetAreaLocation(street, (x1 + x2) * 0.5, (z1 + z2) * 0.5);
	rmSetAreaCoherence(street, 1.0);
	rmSetAreaTerrainType(street, "city\ground1_cob_dark");
	rmAddAreaInfluenceSegment(street, x1 + (x2 - x1) * 0.1, (z1 + z2) * 0.5, x2 - (x2 - x1) * 0.1, (z1 + z2) * 0.5);
	rmAddAreaConstraint(street, box);
	rmSetAreaObeyWorldCircleConstraint(street, false);
	rmBuildArea(street);
}

void main(void)
{
	rmSetStatusText("",0.01);

	// natives: only the Parliament block carries a socket (zpSocketSansculottes,
	// the user's grouping) - allocated the Paris way so the socket has its civ
	int subCiv0=-1;
	int subCiv1=-1;
	if (rmAllocateSubCivs(2) == true)
	{
		subCiv0=rmGetCivID("zpSansculottes");
		rmEchoInfo("subCiv0 is zpSansculottes "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "zpSansculottes");
		subCiv1=rmGetCivID("jewish");
		rmEchoInfo("subCiv1 is jewish "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "jewish");
	}

	// ---- Paris frame, long axis on z: 360 m = 6.6 + row 00 + 4 + row 0 + 10.2 + road + 3 + row 1 + 7 x 34 + 6.6
	int sizeX = 360;
	int sizeZ = 573;
	if (cNumberNonGaiaPlayers >=3)
		sizeZ = 653;
	if (cNumberNonGaiaPlayers >=6)
		sizeZ = 773;
	rmSetMapSize(sizeX, sizeZ);

	rmSetAllMapReveal(true);
	rmSetMapElevationHeightBlend(1);
	rmSetSeaLevel(0.0);
	rmSetLightingSet("age3challenges09a");
	rmSetSeaType("great lakes2");
	rmEnableLocalWater(false);
	rmTerrainInitialize("nwterritory\ground_grass2_nwt", 1.0);
	rmSetMapType("grass");
	rmSetMapType("land");
	rmSetMapType("default");
	rmSetMapType("westEurope");
	rmSetMapType("piratehistoricalmap");
	rmSetMapType("euroTradeRouteUpgradeAll");
	chooseMercs();
	rmSetWorldCircleConstraint(true);

	int classPlayer=rmDefineClass("player");
	rmDefineClass("classHill");
	rmDefineClass("classPatch");
	rmDefineClass("starting settlement");
	rmDefineClass("startingUnit");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("classCliff");
	rmDefineClass("secrets");
	rmDefineClass("nuggets");
	rmDefineClass("center");
	rmDefineClass("tradeIslands");
	int classStreet=rmDefineClass("classStreet");
	rmDefineClass("classPlateau");
	rmDefineClass("classBlock");
	float spawnSwitch = rmRandInt(0,1);

	// ---- constraints (the Paris subset this stage uses) ---------------------
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 5.0);
	int avoidPlateauShort = rmCreateClassDistanceConstraint("avoid plateau short", rmClassID("classPlateau"), 2.0);   // countryside only (Paris)

	// ---- TUNABLES -------------------------------------------------------------
	float roadAsk       = 0.7756; // land route x asked = 279.2 m: 6.6 + 30 + 4 + 30 + 10.2 from the x = 1 edge
	float zRiverAsk     = 0.5;    // the river centre line (rivers do not snap)
	float rowGapFarM    = 18.0;   // road centre -> row 0 centre (edge 3 m off the road, same as row 1: the Paris 10.2 m far side left the rows behind the road off the route)
	float rowGapNearM   = 18.0;   // road centre -> row 1 centre (edge 3 m off the road: Paris's Z5 side)
	float rowPitchM     = 34.0;   // Paris: 30 m block + 4 m street
	int   riverRadius   = 40;     // ~84 m of water (measured 2026-09-17); the bridge's arches span it (41 with the bank shift
	                              // read as "too much" - user 2026-09-18: the water stays, only the Minster bank's land edge moves)
	// THE ONE CITY NUMBER: each bank's quay wall line sits cityDistTiles off the REAL position of its own lane leg
	// (a docked controller on the leg, Istanbul's routeRealZ). 13 tiles = 26 m = the water's edge for a 16 m leg;
	// 14 = both banks one tile further off the naval route (user 2026-09-18)
	int   cityDistTiles = 14;
	int   cityDepthTiles = 66;    // wall line -> column 4's outer edge (4 columns x 16 tiles + the 5 m promenade)
	int   col1 = 10;   int col2 = 26;   int col3 = 42;   int col4 = 58;   // column centres off the wall line: Paris pitch 16 tiles, a 5 m promenade
	// THE HARBOUR NUMBER: each pier's shore edge this many tiles off the REAL lane leg - independent of the city
	// number, so moving the banks never moves the piers (16 = the wall at 14 + 2 tiles into the city, user 2026-09-18)
	int   harbourShoreTiles = 16;
	// London Bridge (EU_SPC_London_Bridge = the user's re-export London_Bridge_New, 24x48): its origin
	// sits at (road + 0.78 m, river + 0.4 m) so the deck stays on the road and the arches span the river
	float bridgeOffX = 0.78;    float bridgeOffZ = 0.4;   // the 2026-09-17 re-export: origin 6.00 m further west (north tower pivot: x -9.01 -> -15.01, z unchanged)
	// the nautical U: legs 16 m off the river centre from the mouth, the turn 80 m west of the road (in front of
	// row 3, the palaces; 60 m clear of the bridge island - 30 m was "too far to the bridge", user 2026-09-17)
	float laneLegM = 16.0;   float laneTurnFromRoadM = 80.0;
	// the harbours = the user's exports "Harbour Fix" (north-west bank, EU_SPC_London_Harbour_NW_01) and "Harbour
	// Fix_S" (south-east, EU_SPC_London_Harbour_SE_01) with their centre post removed; measured from the files: a 5.0 m
	// flat top, ZP City wall on the water face, the shore edge open toward the quay. Each is hung so its shore edge
	// sits harbourShoreTiles off its bank's real lane leg; the post goes down FIRST at the export's own spot (+1 m z:
	// every unit of both exports was moved z +1 against its terrain on 2026-09-17, the post with them)
	// (grouping origin -> post), linked to the lane, and the grouping is hung off the post's real position.
	// ALL POSITIVE (the tile / metre helpers ignore a negative argument silently - Istanbul's documented bug; the sign
	// lives at the call): top edge = origin -> shore edge, post = origin -> post toward the WEST (x) and the WATER (z)
	float hNTopEdgeM = 12.0;    float hNPostWestM = 1.5233;   float hNPostToWaterM = 3.5141;   // north: top z -8..+12, +z = shore
	float hSTopEdgeM = 10.0;    float hSPostWestM = 0.4970;   float hSPostToWaterM = 5.7479;   // south: top z -10..+10, -z = shore
	float harbourGuardOffM = 18.0;   // the guard nugget (privateer) this far off the grouping origin toward the river: 10 / 8 m off the pier face, on the lane leg
	float towerFlagOffM = 14.0;      // the Tower's capturable flag this far along the river off the Tower block's centre (inside the walls)
	float towerNugOffM = 20.0;       // its Redcoat guard nugget this much further, toward the gate side
	// Unit-id laws (Istanbul :4160-4180 measured 2 and 2 there; London starts at 0 / 0 - user 2026-09-18 - and is tuned
	// once the triggers are watched in game): rmGetUnitPlaced (object defs) + instanceIdShiftIndividual,
	// rmGetGroupingInstanceUnitByType (grouping instances) + instanceIdShift
	int instanceIdShiftIndividual = 0;
	int instanceIdShift = 0;
	// riverside decorations (40 m long): the mouth slot before the first harbour is only 26 m (map edge .. the
	// harbour's outer platforms), so that one is centred 12 m in: 8 m of it beyond the edge, its end on the platforms
	float decoMouthXM = 12.0;

	rmSetStatusText("",0.10);

	// ---- 1. LAND TRADE ROUTE FIRST, its controllers and the bridge socket ------------------------
	int tradeRouteID = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteID, roadAsk, 0.0);
	rmAddTradeRouteWaypoint(tradeRouteID, roadAsk, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID, roadAsk, 1.0);
	rmBuildTradeRoute(tradeRouteID, "dirt");
	// two on-route points give the real x (the built route snaps)
	routePoint(tradeRouteID, 0.25);
	float road25X = gRealX;
	routePoint(tradeRouteID, 0.75);
	float road75X = gRealX;
	float xRoad = (road25X + road75X) * 0.5;
	rmEchoInfo("LONDON road x: asked " + roadAsk + " -> real " + xRoad);
	float zRiver = zRiverAsk;                   // the lane is ASKED off this line; the real centre is measured below

	rmSetStatusText("",0.20);

	// ---- 1b. THE NAUTICAL LANE, built BEFORE the river like zpvenicecity's water_trail (a water route built after
	// the water exists poisoned every later grouping on the water - 2026-09-17 tests), then Venice's fake stopper
	// docked on it (zpSPCWaterSpawnPoint at waypoint 0.5, AllowOverlap, min / max 0: "without it the islands don't spawn")
	int waterRouteID = rmCreateTradeRoute();
	float laneTurnX = xRoad - rmXMetersToFraction(laneTurnFromRoadM);
	rmAddTradeRouteWaypoint(waterRouteID, 0.0, zRiver - rmZMetersToFraction(laneLegM));
	rmAddTradeRouteWaypoint(waterRouteID, laneTurnX, zRiver - rmZMetersToFraction(laneLegM));
	rmAddTradeRouteWaypoint(waterRouteID, laneTurnX, zRiver + rmZMetersToFraction(laneLegM));
	rmAddTradeRouteWaypoint(waterRouteID, 0.0, zRiver + rmZMetersToFraction(laneLegM));
	rmBuildTradeRoute(waterRouteID, "water_trail");
	int laneStopper = rmCreateObjectDef("TradeShipStopperFake");
	rmAddObjectDefItem(laneStopper, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(laneStopper, true);
	rmSetObjectDefMinDistance(laneStopper, 0.0);
	rmSetObjectDefMaxDistance(laneStopper, 0.0);
	vector laneMid = rmGetTradeRouteWayPoint(waterRouteID, 0.5);
	rmPlaceObjectDefAtPoint(laneStopper, 0, laneMid);
	// the REAL lane: one docked controller per leg (f 0.2 on the south leg, 0.8 on the north one), Istanbul's
	// routeRealZ - their read-back z is the only z this map trusts from here on
	routePoint(waterRouteID, 0.2);
	float zLaneS = gRealZ;
	routePoint(waterRouteID, 0.8);
	float zLaneN = gRealZ;
	zRiver = (zLaneS + zLaneN) * 0.5;                              // the river centre = the middle of the two real legs
	float wallS = zLaneS - rmZTilesToFraction(cityDistTiles);      // the St Paul's bank's quay wall line
	float wallN = zLaneN + rmZTilesToFraction(cityDistTiles);      // the Minster bank's quay wall line
	rmEchoInfo("LONDON lane legs real " + rmZFractionToMeters(zLaneS) + " / " + rmZFractionToMeters(zLaneN) + " m; river centre " + rmZFractionToMeters(zRiver) + " m, walls " + rmZFractionToMeters(wallS) + " / " + rmZFractionToMeters(wallN) + " m");
	routeSocket(tradeRouteID, xRoad, zRiver);   // the one socket: on London Bridge, at the real crossing

	// ---- 2. THE RIVER (z authored in size_x units: true z metres / sizeX) ------------------------
	int riverMain = rmRiverCreate(-1, "ZP Paris River", 4, 4, riverRadius, riverRadius);
	rmRiverAddWaypoint(riverMain, 0.0, rmXMetersToFraction(rmZFractionToMeters(zRiver)));
	rmRiverAddWaypoint(riverMain, 1.0, rmXMetersToFraction(rmZFractionToMeters(zRiver)));
	rmRiverBuild(riverMain);

	rmSetStatusText("",0.30);

	// ---- 2b. THE HARBOUR POSTS (zpvenicecity: the trade sockets go down right after the rivers, BEFORE the
	// groupings): each at the spot its export had the post, the real position read back for the grouping
	float harbourX1 = xRoad - rmXMetersToFraction(rowGapNearM + 6.5 * rowPitchM);   // the Tower rows' (7-8) centre
	float harbourX2 = xRoad - rmXMetersToFraction(rowGapNearM + 3.5 * rowPitchM);   // rows 4-5 centre, halfway to the bridge
	float harbourNZ = zLaneN + rmZTilesToFraction(harbourShoreTiles) - rmZMetersToFraction(hNTopEdgeM);   // north origins: shore edge off the real leg, top edge back to the origin
	float harbourSZ = zLaneS - rmZTilesToFraction(harbourShoreTiles) + rmZMetersToFraction(hSTopEdgeM);   // south origins
	int postDefN1 = harbourPost(waterRouteID, harbourX1 - rmXMetersToFraction(hNPostWestM), harbourNZ - rmZMetersToFraction(hNPostToWaterM));
	float postN1X = gRealX;   float postN1Z = gRealZ;
	int postDefN2 = harbourPost(waterRouteID, harbourX2 - rmXMetersToFraction(hNPostWestM), harbourNZ - rmZMetersToFraction(hNPostToWaterM));
	float postN2X = gRealX;   float postN2Z = gRealZ;
	int postDefS1 = harbourPost(waterRouteID, harbourX1 - rmXMetersToFraction(hSPostWestM), harbourSZ + rmZMetersToFraction(hSPostToWaterM));
	float postS1X = gRealX;   float postS1Z = gRealZ;
	int postDefS2 = harbourPost(waterRouteID, harbourX2 - rmXMetersToFraction(hSPostWestM), harbourSZ + rmZMetersToFraction(hSPostToWaterM));
	float postS2X = gRealX;   float postS2Z = gRealZ;
	// the real grouping origins, back from the real posts (x: post + west offset; z: post away from the water)
	float originN1X = postN1X + rmXMetersToFraction(hNPostWestM);   float originN1Z = postN1Z + rmZMetersToFraction(hNPostToWaterM);
	float originN2X = postN2X + rmXMetersToFraction(hNPostWestM);   float originN2Z = postN2Z + rmZMetersToFraction(hNPostToWaterM);
	float originS1X = postS1X + rmXMetersToFraction(hSPostWestM);   float originS1Z = postS1Z - rmZMetersToFraction(hSPostToWaterM);
	float originS2X = postS2X + rmXMetersToFraction(hSPostWestM);   float originS2Z = postS2Z - rmZMetersToFraction(hSPostToWaterM);
	// the guards: one privateer nugget on the water in front of each pier, harbourGuardOffM off the origin toward the river
	rmSetNuggetDifficulty(603, 603);
	int guardDefN1 = harbourGuard(originN1X, originN1Z - rmZMetersToFraction(harbourGuardOffM));
	int guardDefN2 = harbourGuard(originN2X, originN2Z - rmZMetersToFraction(harbourGuardOffM));
	int guardDefS1 = harbourGuard(originS1X, originS1Z + rmZMetersToFraction(harbourGuardOffM));
	int guardDefS2 = harbourGuard(originS2X, originS2Z + rmZMetersToFraction(harbourGuardOffM));

	// ---- 3. LONDON BRIDGE (instance API, no scaffold): deck on the road, arches over the river -----
	// Deck 4.949 = the export's 5.949 - 1.0, approved 2026-09-18 ("Keep this"). The game keeps a loaded grouping's
	// terrain by NAME, so a deck change only shows under a new file name or after a game restart.
	int londonBridge = rmCreateGrouping("london bridge", "EU_SPC_London_Bridge");
	placeIsland(londonBridge, xRoad + rmXMetersToFraction(bridgeOffX), zRiver + rmZMetersToFraction(bridgeOffZ));

	// ---- 3b. THE HARBOUR GROUPINGS, hung off their posts' REAL positions (grouping origin = post - export offset),
	// zpvenicecity's ControllerLoc idiom; the instance API, max distance 0.00, no scaffold
	int harbourN1 = rmCreateGrouping("harbour north 1", "EU_SPC_London_Harbour_NW_01");
	placeIsland(harbourN1, originN1X, originN1Z);
	int harbourN2 = rmCreateGrouping("harbour north 2", "EU_SPC_London_Harbour_NW_01");
	placeIsland(harbourN2, originN2X, originN2Z);
	int harbourS1 = rmCreateGrouping("harbour south 1", "EU_SPC_London_Harbour_SE_01");
	placeIsland(harbourS1, originS1X, originS1Z);
	int harbourS2 = rmCreateGrouping("harbour south 2", "EU_SPC_London_Harbour_SE_01");
	placeIsland(harbourS2, originS2X, originS2Z);

	// ---- 5. CITY FLOOR: one straight quay per bank, streets, plain countryside ----------------------
	quaySegment(0.0, wallS - rmZTilesToFraction(cityDepthTiles), 1.0, wallS, 0.7);
	quaySegment(0.0, wallN, 1.0, wallN + rmZTilesToFraction(cityDepthTiles), 0.7);

	int countrysideSouth = rmCreateArea("countryside S");
	rmSetAreaSize(countrysideSouth , 0.6, 0.6);
	rmSetAreaLocation(countrysideSouth , 0.5, zRiver-rmZTilesToFraction(130));
	rmSetAreaCoherence(countrysideSouth , 1.0);
	rmSetAreaBaseHeight(countrysideSouth, 1.0);
	rmAddAreaConstraint(countrysideSouth , avoidPlateauShort);
	rmSetAreaMix(countrysideSouth, "nwt_grass1");
	rmSetAreaElevationVariation(countrysideSouth, 0.0);
	rmBuildArea(countrysideSouth );

	int countrysideNorth = rmCreateArea("countryside N");
	rmSetAreaSize(countrysideNorth , 0.6, 0.6);
	rmSetAreaLocation(countrysideNorth , 0.5, zRiver+rmZTilesToFraction(130));
	rmSetAreaCoherence(countrysideNorth , 1.0);
	rmSetAreaBaseHeight(countrysideNorth, 1.0);
	rmAddAreaConstraint(countrysideNorth , avoidPlateauShort);
	rmSetAreaMix(countrysideNorth, "nwt_grass1");
	rmSetAreaElevationVariation(countrysideNorth, 0.0);
	rmBuildArea(countrysideNorth );

	rmSetStatusText("",0.50);

	// ---- the grid, from the MEASURED road and the river ---------------------------------------------
	float locX00 = xRoad + rmXMetersToFraction(rowGapFarM + rowPitchM);   // second row behind the road
	float locX0 = xRoad + rmXMetersToFraction(rowGapFarM);                // first row behind the road
	float locX1 = xRoad - rmXMetersToFraction(rowGapNearM);
	float locX2 = locX1 - rmXMetersToFraction(rowPitchM);
	float locX3 = locX2 - rmXMetersToFraction(rowPitchM);
	float locX4 = locX3 - rmXMetersToFraction(rowPitchM);
	float locX5 = locX4 - rmXMetersToFraction(rowPitchM);
	float locX6 = locX5 - rmXMetersToFraction(rowPitchM);
	float locX7 = locX6 - rmXMetersToFraction(rowPitchM);
	float locX8 = locX7 - rmXMetersToFraction(rowPitchM);
	float locX12 = (locX1 + locX2) * 0.5;    // 2-row block centres
	float locX78 = (locX7 + locX8) * 0.5;
	float locZs1 = wallS-rmZTilesToFraction(col1);
	float locZs2 = wallS-rmZTilesToFraction(col2);
	float locZs3 = wallS-rmZTilesToFraction(col3);
	float locZs4 = wallS-rmZTilesToFraction(col4);
	float locZn1 = wallN+rmZTilesToFraction(col1);
	float locZn2 = wallN+rmZTilesToFraction(col2);
	float locZn3 = wallN+rmZTilesToFraction(col3);
	float locZn4 = wallN+rmZTilesToFraction(col4);
	float locZs12 = wallS-rmZTilesToFraction(col1+col2)*0.5;    // 2-column block centres
	float locZn12 = wallN+rmZTilesToFraction(col1+col2)*0.5;

	// ---- 6. BLOCKS, Paris's order: 6.1 fixed double blocks, 6.2 fixed single blocks, 6.3 resource buildings in the
	// city zones (Paris's shuffled randomiser), 6.4 bastions + treasures (fillers), 6.5 houses in every free cell.
	// London's centre sits at the bridge: the Centre zone = the cells around the Basilicas and along the shores.
	// The banks are MIRRORED (same rows and columns), each bank shuffled on its own. Only Paris's resource,
	// bastion and treasure assets - no natives, no city hall / court / military / construction (user 2026-09-18).
	int blockStPaul = cityBlock("st paul", "EU_SPC_London_StPaul");
	int blockMinster = cityBlock("minster", "EU_SPC_London_Minster");
	int blockStuart = cityBlock("stuart natives", "EU_Native_Block_Stuart_01_270");
	int blockParliament = cityBlock("parliament natives", "EU_Native_Block_Parlam_01_90");
	int blockTower = cityBlock("tower of london", "EU_SPC_London_Tower_01");
	int blockTower180 = cityBlock("tower of london north", "EU_SPC_London_Tower_01_180");   // turned 180 degrees, the red Tower (variation +1) for the north-west shore
	int blockTrade = cityBlock("trade block", "EU_SPC_Block_Trade_90");   // socket on the +x side: faces the road from row 1
	// the Figma's fixed EU blocks (Paris / Versailles definitions): Park green, Menagerie magenta, Native Jewish black,
	// Factory dark brown - one per bank, mirrored
	int blockPark = cityBlock("park", "EU_House_Block_Park");
	int blockMenagerie = cityBlock("menagerie", "EU_Resource_Block_Menagerie");      // Paris: instance API, nugget 98
	int blockJewish = cityBlock("jewish natives", "EU_Natives_Block_Jewish");         // Versailles
	int blockFactory = cityBlock("factory", "EU_Resource_Block_All1");               // Paris's Factory: instance API, nugget 299
	// Paris's resource buildings by zone: Centre = Market, Bank, Embassy; Outer = Gold Smelter; Suburbs = Destilery,
	// Warehouse + the Mill and the Forester Paris defines but never places
	int blockMarket = cityBlock("market", "EU_Resource_Block_All2");
	int blockBank = cityBlock("bank", "EU_Resource_Block_Gold1");
	int blockEmbassy = cityBlock("Native Embassy", "EU_House_Block_Embassy");
	int blockGoldSmelter = cityBlock("Gold Smelter", "EU_Resource_Block_Gold2");
	int blockDestilery = cityBlock("Destilery", "EU_Resource_Block_Food2");
	int blockWarehouse = cityBlock("Warehouse", "EU_Resource_Block_Wood1");
	int blockMill = cityBlock("Mill", "EU_Resource_Block_Food1");
	int blockForester = cityBlock("Forester", "EU_Resource_Block_Wood2");
	// Paris's treasures (its bastion blocks dropped - user 2026-09-18) + the user's Academy block (nuggetmods
	// zpNuggetAcademyLondon 604: the Istanbul academy nugget with British guardians)
	int blockAcademy = cityBlock("Academy", "EU_House_Block_Academy");
	int blockTreasure01 = cityBlock("Treasure1", "EU_House_Block_Treasure1");
	int blockTreasure02 = cityBlock("Treasure2", "EU_House_Block_Treasure2");
	// the filler houses
	int blockHouse01 = cityBlock("house1", "EU_House_Block_01");
	int blockHouse02 = cityBlock("house2", "EU_House_Block_02");
	int blockHouse03 = cityBlock("house3", "EU_House_Block_03");
	int blockHouse04 = cityBlock("house4", "EU_House_Block_04");
	int blockHouse05 = cityBlock("house5", "EU_House_Block_05");
	int blockHouse06 = cityBlock("house6", "EU_House_Block_06");

	// ---- 6.1 fixed double blocks: St Paul / Minster rows 1-2 x cols 1-2, Stuart / Parliament row 3 across cols
	// 1-2, the Towers rows 7-8 x cols 1-2 at the water
	rmPlaceGroupingAtLoc(blockStPaul, 0, locX12, locZs12);
	rmPlaceGroupingAtLoc(blockStuart, 0, locX3, locZs12);
	int towerS = rmPlaceGroupingInstanceAtLoc(blockTower, locX78, locZs12, 0);      // instance: the trigger needs the Tower's id
	rmPlaceGroupingAtLoc(blockMinster, 0, locX12, locZn12);
	rmPlaceGroupingAtLoc(blockParliament, 0, locX3, locZn12);
	int towerN = rmPlaceGroupingInstanceAtLoc(blockTower180, locX78, locZn12, 0);
	// Istanbul's palace handle for each Tower: a capturable flag (deSPCCapturableFlagCossack, socketcapture.tactics =
	// AutoConvert) inside the walls, towerFlagOffM along the river off the block centre, and a Redcoat guard nugget
	// (nuggetmods zpNuggetTowerOfLondon 605: ten deSPCHMRedcoat, the vanilla Redcoat as a normal aggressive unit, the
	// shape of zpNuggetIstanbul's nine Janissaries) towerNugOffM further on - the guards stand
	// between the gate and the flag ("shouldn't be easy to get there")
	int towerFlagS = rmCreateObjectDef("tower flag S");
	rmAddObjectDefItem(towerFlagS, "deSPCCapturableFlagCossack", 1, 0.0);
	rmSetObjectDefMinDistance(towerFlagS, 0.0);
	rmSetObjectDefMaxDistance(towerFlagS, 2.0);
	rmPlaceObjectDefAtLoc(towerFlagS, 0, locX78 + rmXMetersToFraction(towerFlagOffM), locZs12);
	int towerFlagN = rmCreateObjectDef("tower flag N");
	rmAddObjectDefItem(towerFlagN, "deSPCCapturableFlagCossack", 1, 0.0);
	rmSetObjectDefMinDistance(towerFlagN, 0.0);
	rmSetObjectDefMaxDistance(towerFlagN, 2.0);
	rmPlaceObjectDefAtLoc(towerFlagN, 0, locX78 - rmXMetersToFraction(towerFlagOffM), locZn12);
	rmSetNuggetDifficulty(605, 605);
	int towerNugS = rmCreateObjectDef("tower guard S");
	rmAddObjectDefItem(towerNugS, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(towerNugS, 0.0);
	rmSetObjectDefMaxDistance(towerNugS, 2.0);
	rmPlaceObjectDefAtLoc(towerNugS, 0, locX78 + rmXMetersToFraction(towerNugOffM), locZs12);
	int towerNugN = rmCreateObjectDef("tower guard N");
	rmAddObjectDefItem(towerNugN, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(towerNugN, 0.0);
	rmSetObjectDefMaxDistance(towerNugN, 2.0);
	rmPlaceObjectDefAtLoc(towerNugN, 0, locX78 - rmXMetersToFraction(towerNugOffM), locZn12);

	// ---- 6.2 fixed single blocks: trade block row 1 col 3, Park row 4 col 1, Menagerie row 4 col 2, Native Jewish
	// row 6 col 3, Factory row 0 col 2 - nugget latches as Paris
	rmPlaceGroupingAtLoc(blockTrade, 0, locX1, locZs3);
	rmPlaceGroupingAtLoc(blockTrade, 0, locX1, locZn3);
	rmPlaceGroupingAtLoc(blockPark, 0, locX4, locZs1);
	rmPlaceGroupingAtLoc(blockPark, 0, locX4, locZn1);
	rmSetNuggetDifficulty(98, 98);
	int menagerieS = rmPlaceGroupingInstanceAtLoc(blockMenagerie, locX4, locZs2, 0);
	int menagerieN = rmPlaceGroupingInstanceAtLoc(blockMenagerie, locX4, locZn2, 0);
	rmPlaceGroupingAtLoc(blockJewish, 0, locX6, locZs3);
	rmPlaceGroupingAtLoc(blockJewish, 0, locX6, locZn3);
	rmSetNuggetDifficulty(299, 299);
	int factoryS = rmPlaceGroupingInstanceAtLoc(blockFactory, locX0, locZs2, 0);
	int factoryN = rmPlaceGroupingInstanceAtLoc(blockFactory, locX0, locZn2, 0);

	rmSetStatusText("",0.70);

	// ---- 6.3 the zones: the 25 free cells per bank, mirrored. Centre (7) = the cells around the Basilicas and
	// along the shores: col 1 rows 5, 6, 0 / col 2 rows 5, 6 / col 3 rows 2, 3. Outer centre (5) = col 3 rows
	// 4, 5 / col 1 row 00 / col 2 row 00 / col 3 row 0. Suburbs (13) = col 4 every row / col 3 rows 00, 7, 8.
	const int NUM_CELLS = 50;
	const int S_CENTER_START = 0;    const int S_CENTER_END = 6;
	const int S_OUTER_START = 7;     const int S_OUTER_END = 11;
	const int S_SUBURBS_START = 12;  const int S_SUBURBS_END = 24;
	const int N_CENTER_START = 25;   const int N_CENTER_END = 31;
	const int N_OUTER_START = 32;    const int N_OUTER_END = 36;
	const int N_SUBURBS_START = 37;  const int N_SUBURBS_END = 49;
	gCityLocs = xsArrayCreateVector(NUM_CELLS, cInvalidVector, "List of locations in the city");
	gCityLocsStatus = xsArrayCreateBool(NUM_CELLS, false, "Flags a loc as taken or not");
	// South - Centre
	xsArraySetVector(gCityLocs, 0, xsVectorSet(locX5, 0.0, locZs1));
	xsArraySetVector(gCityLocs, 1, xsVectorSet(locX6, 0.0, locZs1));
	xsArraySetVector(gCityLocs, 2, xsVectorSet(locX0, 0.0, locZs1));
	xsArraySetVector(gCityLocs, 3, xsVectorSet(locX5, 0.0, locZs2));
	xsArraySetVector(gCityLocs, 4, xsVectorSet(locX6, 0.0, locZs2));
	xsArraySetVector(gCityLocs, 5, xsVectorSet(locX2, 0.0, locZs3));
	xsArraySetVector(gCityLocs, 6, xsVectorSet(locX3, 0.0, locZs3));
	// South - Outer centre
	xsArraySetVector(gCityLocs, 7, xsVectorSet(locX4, 0.0, locZs3));
	xsArraySetVector(gCityLocs, 8, xsVectorSet(locX5, 0.0, locZs3));
	xsArraySetVector(gCityLocs, 9, xsVectorSet(locX00, 0.0, locZs1));
	xsArraySetVector(gCityLocs, 10, xsVectorSet(locX00, 0.0, locZs2));
	xsArraySetVector(gCityLocs, 11, xsVectorSet(locX0, 0.0, locZs3));
	// South - Suburbs
	xsArraySetVector(gCityLocs, 12, xsVectorSet(locX00, 0.0, locZs4));
	xsArraySetVector(gCityLocs, 13, xsVectorSet(locX0, 0.0, locZs4));
	xsArraySetVector(gCityLocs, 14, xsVectorSet(locX1, 0.0, locZs4));
	xsArraySetVector(gCityLocs, 15, xsVectorSet(locX2, 0.0, locZs4));
	xsArraySetVector(gCityLocs, 16, xsVectorSet(locX3, 0.0, locZs4));
	xsArraySetVector(gCityLocs, 17, xsVectorSet(locX4, 0.0, locZs4));
	xsArraySetVector(gCityLocs, 18, xsVectorSet(locX5, 0.0, locZs4));
	xsArraySetVector(gCityLocs, 19, xsVectorSet(locX6, 0.0, locZs4));
	xsArraySetVector(gCityLocs, 20, xsVectorSet(locX7, 0.0, locZs4));
	xsArraySetVector(gCityLocs, 21, xsVectorSet(locX8, 0.0, locZs4));
	xsArraySetVector(gCityLocs, 22, xsVectorSet(locX00, 0.0, locZs3));
	xsArraySetVector(gCityLocs, 23, xsVectorSet(locX7, 0.0, locZs3));
	xsArraySetVector(gCityLocs, 24, xsVectorSet(locX8, 0.0, locZs3));
	// North - Centre (the mirror)
	xsArraySetVector(gCityLocs, 25, xsVectorSet(locX5, 0.0, locZn1));
	xsArraySetVector(gCityLocs, 26, xsVectorSet(locX6, 0.0, locZn1));
	xsArraySetVector(gCityLocs, 27, xsVectorSet(locX0, 0.0, locZn1));
	xsArraySetVector(gCityLocs, 28, xsVectorSet(locX5, 0.0, locZn2));
	xsArraySetVector(gCityLocs, 29, xsVectorSet(locX6, 0.0, locZn2));
	xsArraySetVector(gCityLocs, 30, xsVectorSet(locX2, 0.0, locZn3));
	xsArraySetVector(gCityLocs, 31, xsVectorSet(locX3, 0.0, locZn3));
	// North - Outer centre
	xsArraySetVector(gCityLocs, 32, xsVectorSet(locX4, 0.0, locZn3));
	xsArraySetVector(gCityLocs, 33, xsVectorSet(locX5, 0.0, locZn3));
	xsArraySetVector(gCityLocs, 34, xsVectorSet(locX00, 0.0, locZn1));
	xsArraySetVector(gCityLocs, 35, xsVectorSet(locX00, 0.0, locZn2));
	xsArraySetVector(gCityLocs, 36, xsVectorSet(locX0, 0.0, locZn3));
	// North - Suburbs
	xsArraySetVector(gCityLocs, 37, xsVectorSet(locX00, 0.0, locZn4));
	xsArraySetVector(gCityLocs, 38, xsVectorSet(locX0, 0.0, locZn4));
	xsArraySetVector(gCityLocs, 39, xsVectorSet(locX1, 0.0, locZn4));
	xsArraySetVector(gCityLocs, 40, xsVectorSet(locX2, 0.0, locZn4));
	xsArraySetVector(gCityLocs, 41, xsVectorSet(locX3, 0.0, locZn4));
	xsArraySetVector(gCityLocs, 42, xsVectorSet(locX4, 0.0, locZn4));
	xsArraySetVector(gCityLocs, 43, xsVectorSet(locX5, 0.0, locZn4));
	xsArraySetVector(gCityLocs, 44, xsVectorSet(locX6, 0.0, locZn4));
	xsArraySetVector(gCityLocs, 45, xsVectorSet(locX7, 0.0, locZn4));
	xsArraySetVector(gCityLocs, 46, xsVectorSet(locX8, 0.0, locZn4));
	xsArraySetVector(gCityLocs, 47, xsVectorSet(locX00, 0.0, locZn3));
	xsArraySetVector(gCityLocs, 48, xsVectorSet(locX7, 0.0, locZn3));
	xsArraySetVector(gCityLocs, 49, xsVectorSet(locX8, 0.0, locZn3));
	shuffle(gCityLocs, S_CENTER_START, S_CENTER_END);
	shuffle(gCityLocs, S_OUTER_START, S_OUTER_END);
	shuffle(gCityLocs, S_SUBURBS_START, S_SUBURBS_END);
	shuffle(gCityLocs, N_CENTER_START, N_CENTER_END);
	shuffle(gCityLocs, N_OUTER_START, N_OUTER_END);
	shuffle(gCityLocs, N_SUBURBS_START, N_SUBURBS_END);

	// the resource buildings, Paris's nugget latch 195
	rmSetNuggetDifficulty(195, 195);
	int southCenterGroupings = xsArrayCreateInt(3, -1, "List of groupings for the city centre (south).");
	xsArraySetInt(southCenterGroupings, 0, blockMarket);
	xsArraySetInt(southCenterGroupings, 1, blockBank);
	xsArraySetInt(southCenterGroupings, 2, blockEmbassy);
	placeGroupings(southCenterGroupings, S_CENTER_START);
	int northCenterGroupings = xsArrayCreateInt(3, -1, "List of groupings for the city centre (north).");
	xsArraySetInt(northCenterGroupings, 0, blockMarket);
	xsArraySetInt(northCenterGroupings, 1, blockBank);
	xsArraySetInt(northCenterGroupings, 2, blockEmbassy);
	placeGroupings(northCenterGroupings, N_CENTER_START);
	int southOutCenterGroupings = xsArrayCreateInt(1, -1, "List of groupings for the outer centre (south).");
	xsArraySetInt(southOutCenterGroupings, 0, blockGoldSmelter);
	placeGroupings(southOutCenterGroupings, S_OUTER_START);
	int northOutCenterGroupings = xsArrayCreateInt(1, -1, "List of groupings for the outer centre (north).");
	xsArraySetInt(northOutCenterGroupings, 0, blockGoldSmelter);
	placeGroupings(northOutCenterGroupings, N_OUTER_START);
	int southSuburbGroupings = xsArrayCreateInt(4, -1, "List of suburbs groupings (south).");
	xsArraySetInt(southSuburbGroupings, 0, blockDestilery);
	xsArraySetInt(southSuburbGroupings, 1, blockWarehouse);
	xsArraySetInt(southSuburbGroupings, 2, blockMill);
	xsArraySetInt(southSuburbGroupings, 3, blockForester);
	placeGroupings(southSuburbGroupings, S_SUBURBS_START);
	int northSuburbGroupings = xsArrayCreateInt(4, -1, "List of suburbs groupings (north).");
	xsArraySetInt(northSuburbGroupings, 0, blockDestilery);
	xsArraySetInt(northSuburbGroupings, 1, blockWarehouse);
	xsArraySetInt(northSuburbGroupings, 2, blockMill);
	xsArraySetInt(northSuburbGroupings, 3, blockForester);
	placeGroupings(northSuburbGroupings, N_SUBURBS_START);

	// ---- 6.4 treasures (192), Paris's fillers: the first free cells of each bank in zone order, so they take
	// two of the Centre's leftover cells around the Basilicas and the shores (no bastions - user 2026-09-18)
	rmSetNuggetDifficulty(604, 604);
	filler(blockAcademy, S_CENTER_START, S_SUBURBS_END);
	filler(blockAcademy, N_CENTER_START, N_SUBURBS_END);
	rmSetNuggetDifficulty(192, 192);
	filler(blockTreasure01, S_CENTER_START, S_SUBURBS_END);
	filler(blockTreasure02, S_CENTER_START, S_SUBURBS_END);
	filler(blockTreasure01, N_CENTER_START, N_SUBURBS_END);
	filler(blockTreasure02, N_CENTER_START, N_SUBURBS_END);

	// ---- 6.5 houses in every cell still free, the six Paris house blocks in turn
	int houseGroupings = xsArrayCreateInt(6, -1, "List of house groupings.");
	xsArraySetInt(houseGroupings, 0, blockHouse01);
	xsArraySetInt(houseGroupings, 1, blockHouse02);
	xsArraySetInt(houseGroupings, 2, blockHouse03);
	xsArraySetInt(houseGroupings, 3, blockHouse04);
	xsArraySetInt(houseGroupings, 4, blockHouse05);
	xsArraySetInt(houseGroupings, 5, blockHouse06);
	int houseIdx = 0;
	for (cellIdx = 0; < NUM_CELLS) {
		if (xsArrayGetBool(gCityLocsStatus, cellIdx) == false) {
			vector cellLoc = xsArrayGetVector(gCityLocs, cellIdx);
			rmPlaceGroupingAtLoc(xsArrayGetInt(houseGroupings, houseIdx), 0, xsVectorGetX(cellLoc), xsVectorGetZ(cellLoc));
			xsArraySetBool(gCityLocsStatus, cellIdx, true);
			houseIdx = houseIdx + 1;
			if (houseIdx >= 6)
				houseIdx = 0;
		}
	}

	// ---- 6b. RIVERSIDE DECORATIONS (Paris: EU_Riverside_SW_01 / NE_01 at its quay wall line, min 0 / max 0.5,
	// turned for London as EU_SPC_London_Riverside_SE_01 / _NW_01;
	// classBlock, after the blocks), turned one quarter for the x-running river (_270: water side +z on the south
	// bank, -z on the north), centred on the quay wall line; four per bank along x (user 2026-09-18): before the
	// first harbour, between the harbours, between the second harbour and the bridge, behind the bridge
	int riversideS = cityBlock("riverside south", "EU_SPC_London_Riverside_SE_01");
	int riversideN = cityBlock("riverside north", "EU_SPC_London_Riverside_NW_01");
	float decoZs = wallS;
	float decoZn = wallN;
	float decoX1 = rmXMetersToFraction(decoMouthXM);
	float decoX2 = (harbourX1 + harbourX2) * 0.5;                                          // between the harbours
	float decoX3 = (harbourX2 + xRoad + rmXMetersToFraction(bridgeOffX) - rmXMetersToFraction(22.0)) * 0.5;    // second harbour .. the bridge's west wall
	float decoX4 = (xRoad + rmXMetersToFraction(bridgeOffX + 16.0) + 1.0) * 0.5;          // the bridge's east wall .. the map edge
	rmPlaceGroupingAtLoc(riversideS, 0, decoX1, decoZs);
	rmPlaceGroupingAtLoc(riversideS, 0, decoX2, decoZs);
	rmPlaceGroupingAtLoc(riversideS, 0, decoX3, decoZs);
	rmPlaceGroupingAtLoc(riversideS, 0, decoX4, decoZs);
	rmPlaceGroupingAtLoc(riversideN, 0, decoX1, decoZn);
	rmPlaceGroupingAtLoc(riversideN, 0, decoX2, decoZn);
	rmPlaceGroupingAtLoc(riversideN, 0, decoX3, decoZn);
	rmPlaceGroupingAtLoc(riversideN, 0, decoX4, decoZn);

	rmSetStatusText("",0.80);

	// ---- 7. PLAYERS (Paris placement, transposed onto the z axis) -----------------------------
	if (cNumberTeams == 2){
		if (spawnSwitch ==0){
			if (PlayerNum == 2)
			{
				rmPlacePlayer(1, 0.35, 0.07);
				rmPlacePlayer(2, 0.65, 0.93);
			}
			if (PlayerNum == 3 || PlayerNum == 4)
			{
				rmSetPlacementTeam(0);
				rmPlacePlayersLine(0.23, 0.1, 0.73, 0.1, 0, 0);
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.73, 0.9, 0.23, 0.9, 0, 0);
			}
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.10, 0.10, 0.75, 0.10, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.90, 0.90, 0.25, 0.90, 0, 0);
		}
		else{
			if (PlayerNum == 2)
			{
				rmPlacePlayer(2, 0.35, 0.07);
				rmPlacePlayer(1, 0.65, 0.93);
			}
			if (PlayerNum == 3 || PlayerNum == 4)
			{
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.23, 0.1, 0.73, 0.1, 0, 0);
				rmSetPlacementTeam(0);
				rmPlacePlayersLine(0.73, 0.9, 0.23, 0.9, 0, 0);
			}
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.10, 0.10, 0.75, 0.10, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.90, 0.90, 0.25, 0.90, 0, 0);
		}
	}
	else{
		rmPlacePlayersLine(0.10, 0.10, 0.75, 0.10, 0, 0);
	}

	int playerStart = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(playerStart, 7.0);
	rmSetObjectDefMaxDistance(playerStart, 12.0);
	int aiStartUrban = rmCreateObjectDef("is city map");
	rmAddObjectDefItem(aiStartUrban, "zpAIStartUrbanMap", 1, 0.0);

	for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		int startID = rmCreateObjectDef("object"+i);
		rmAddObjectDefItem(startID, "deSPCCommandPost", 1, 2.0);
		rmSetObjectDefMinDistance(startID, 0.0);
		if (cNumberNonGaiaPlayers >=5){
			rmSetObjectDefMaxDistance(startID, 10.0);
			rmAddObjectDefConstraint(startID, avoidTradeRouteMin);
		}
		else{
			rmSetObjectDefMaxDistance(startID, 1.0);
		}
		rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(aiStartUrban, i, 0.5, 0.5);
	}
	// starting hunt / gold / berries and every map resource: deliberately absent at the layout stage

	// ============================================================================================
	// 8. TRIGGERS - all of them here, at the end (Paris / Istanbul). Ids: object defs = rmGetUnitPlaced +
	//    instanceIdShiftIndividual, grouping instances = rmGetGroupingInstanceUnitByType + instanceIdShift; a
	//    baked nugget is queried by its nuggetmods <nuggetunit>, never by the authored placeholder (Istanbul).
	// ============================================================================================
	int unit_postN1 = rmGetUnitPlaced(postDefN1, 0) + instanceIdShiftIndividual;
	int unit_postN2 = rmGetUnitPlaced(postDefN2, 0) + instanceIdShiftIndividual;
	int unit_postS1 = rmGetUnitPlaced(postDefS1, 0) + instanceIdShiftIndividual;
	int unit_postS2 = rmGetUnitPlaced(postDefS2, 0) + instanceIdShiftIndividual;
	int unit_guardN1 = rmGetUnitPlaced(guardDefN1, 0) + instanceIdShiftIndividual;
	int unit_guardN2 = rmGetUnitPlaced(guardDefN2, 0) + instanceIdShiftIndividual;
	int unit_guardS1 = rmGetUnitPlaced(guardDefS1, 0) + instanceIdShiftIndividual;
	int unit_guardS2 = rmGetUnitPlaced(guardDefS2, 0) + instanceIdShiftIndividual;
	int unit_menagerieS = rmGetGroupingInstanceUnitByType(menagerieS, "zpSPCMenagerie") + instanceIdShift;
	int unit_menagerieN = rmGetGroupingInstanceUnitByType(menagerieN, "zpSPCMenagerie") + instanceIdShift;
	int unit_menagerieNugS = rmGetGroupingInstanceUnitByType(menagerieS, "zpNuggetInvisible") + instanceIdShift;   // nuggetmods 98
	int unit_menagerieNugN = rmGetGroupingInstanceUnitByType(menagerieN, "zpNuggetInvisible") + instanceIdShift;
	int unit_factoryS = rmGetGroupingInstanceUnitByType(factoryS, "zpSPCCapturableFactory") + instanceIdShift;
	int unit_factoryN = rmGetGroupingInstanceUnitByType(factoryN, "zpSPCCapturableFactory") + instanceIdShift;
	int unit_factoryNugS = rmGetGroupingInstanceUnitByType(factoryS, "zpNuggetInvisible") + instanceIdShift;       // nuggetmods 299
	int unit_factoryNugN = rmGetGroupingInstanceUnitByType(factoryN, "zpNuggetInvisible") + instanceIdShift;
	int unit_towerBldS = rmGetGroupingInstanceUnitByType(towerS, "zpSPCTowerOfLondon") + instanceIdShift;
	int unit_towerBldN = rmGetGroupingInstanceUnitByType(towerN, "zpSPCTowerOfLondon") + instanceIdShift;
	int unit_towerFlagS = rmGetUnitPlaced(towerFlagS, 0) + instanceIdShiftIndividual;
	int unit_towerFlagN = rmGetUnitPlaced(towerFlagN, 0) + instanceIdShiftIndividual;
	int unit_towerNugS = rmGetUnitPlaced(towerNugS, 0) + instanceIdShiftIndividual;
	int unit_towerNugN = rmGetUnitPlaced(towerNugN, 0) + instanceIdShiftIndividual;
	rmEchoInfo("LONDON ids: posts " + unit_postN1 + " " + unit_postN2 + " " + unit_postS1 + " " + unit_postS2 + " guards " + unit_guardN1 + " " + unit_guardN2 + " " + unit_guardS1 + " " + unit_guardS2);
	rmEchoInfo("LONDON ids: menageries " + unit_menagerieS + " " + unit_menagerieN + " nuggets " + unit_menagerieNugS + " " + unit_menagerieNugN + " factories " + unit_factoryS + " " + unit_factoryN + " nuggets " + unit_factoryNugS + " " + unit_factoryNugN);
	rmEchoInfo("LONDON ids: towers " + unit_towerBldS + " " + unit_towerBldN + " flags " + unit_towerFlagS + " " + unit_towerFlagN + " nuggets " + unit_towerNugS + " " + unit_towerNugN);

	// ---- 8.1 startup: every capturable's AutoConvert suspended (Istanbul "Trade Harbours NoAutoConvert")
	rmCreateTrigger("London NoAutoConvert");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_postN1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_postN2);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_postS1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_postS2);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_menagerieS);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_menagerieN);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_factoryS);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_factoryN);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_towerFlagS);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_towerFlagN);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ---- 8.2 releases: each guard nugget collectable -> its capturable converts again (Istanbul "Harbour k Convert ON")
	rmCreateTrigger("Harbour N1 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_guardN1);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_postN1, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour N2 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_guardN2);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_postN2, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour S1 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_guardS1);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_postS1, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour S2 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_guardS2);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_postS2, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Menagerie S Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_menagerieNugS);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_menagerieS, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Menagerie N Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_menagerieNugN);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_menagerieN, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Factory S Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_factoryNugS);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_factoryS, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Factory N Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_factoryNugN);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_factoryN, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ---- 8.3 the Towers, Istanbul's palace family: the per-player conversion triggers exist first (the unlock
	// references them by name), the unlock releases the flag and arms them, each fires when its player holds the
	// flag and converts the Tower building to that player, then re-arms the others (never itself)
	for (tcS = 1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("TowerConvS_Plr" + tcS);
	}
	for (tcN = 1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("TowerConvN_Plr" + tcN);
	}

	rmCreateTrigger("TowerSUnlock");
	rmSwitchToTrigger(rmTriggerID("TowerSUnlock"));
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_towerNugS);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_towerFlagS, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	for (tuS = 1; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TowerConvS_Plr" + tuS));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("TowerNUnlock");
	rmSwitchToTrigger(rmTriggerID("TowerNUnlock"));
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_towerNugN);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_towerFlagN, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	for (tuN = 1; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TowerConvN_Plr" + tuN));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	for (tpS = 1; <= cNumberNonGaiaPlayers)
	{
		rmSwitchToTrigger(rmTriggerID("TowerConvS_Plr" + tpS));
		rmAddTriggerCondition("Units Owned");
		rmSetTriggerConditionParam("SrcObject", ""+unit_towerFlagS);
		rmSetTriggerConditionParamInt("Player", tpS);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject", ""+unit_towerBldS);
		rmSetTriggerEffectParamInt("PlayerID", tpS);
		for (tqS = 1; <= cNumberNonGaiaPlayers)
		{
			if (tqS != tpS)
			{
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("TowerConvS_Plr" + tqS));
			}
		}
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset", "SheepFound");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(false);
		rmSetTriggerLoop(false);
	}
	for (tpN = 1; <= cNumberNonGaiaPlayers)
	{
		rmSwitchToTrigger(rmTriggerID("TowerConvN_Plr" + tpN));
		rmAddTriggerCondition("Units Owned");
		rmSetTriggerConditionParam("SrcObject", ""+unit_towerFlagN);
		rmSetTriggerConditionParamInt("Player", tpN);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject", ""+unit_towerBldN);
		rmSetTriggerEffectParamInt("PlayerID", tpN);
		for (tqN = 1; <= cNumberNonGaiaPlayers)
		{
			if (tqN != tpN)
			{
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("TowerConvN_Plr" + tqN));
			}
		}
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset", "SheepFound");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(false);
		rmSetTriggerLoop(false);
	}

	rmSetStatusText("",0.99);
} // END
