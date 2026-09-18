// ============================================================================
// zplondon.xs  -  London on the Paris rig (Figma sketch of 2026-09-17)
// ----------------------------------------------------------------------------
// The long axis is z (573 m), the Thames runs along x at the map's middle with
// a straight shoreline, the land route runs along z near the x = 1 edge; two
// block rows behind the road, eight in front, players at both z ends. The
// banks are mirrored. Editor twin: Steam Game\RandMaps\00000_zplondon.xs.
// History and open bugs: memory london-map-status / london-privateer-nugget-bug.
//
// BUILD ORDER (every step's position is inherited from a REAL trade-route object)
//   1  land route, real road x from two docked controllers                     (law 1)
//   2  nautical lane + fake stopper, real leg z per bank -> river centre, walls, the bridge socket (law 1)
//   3  the grid, derived from the real road and the real walls (no placement)
//   4  the river (rect-map rule: z authored in size_x units)
//   5  harbour posts docked on the lane, real positions read back              (law 1)
//   6  London Bridge, instance API                                              (law 2)
//   7  harbour groupings hung off the real posts, instance API                  (law 2)
//   8  privateer treasures (water nuggets 603) beside the harbours - OPEN BUG, not seen spawning yet
//   9  quays (one straight plateau per bank), streets, countryside
//   10 blocks in Paris's order: fixed doubles, fixed singles, zones, fillers, houses
//   11 riverside decorations, 12 players, 13 triggers (all at the end)
//
// LAWS (pinned by tests, dates in the memories)
//   1  land route + docked controllers BEFORE any water; the lane BEFORE the river; a
//      route built after water exists poisons every later water placement (2026-09-17)
//   2  groupings on water: rmPlaceGroupingInstanceAtLoc, max distance 0.00, no scaffold
//   3  the tile / metre helpers ignore a NEGATIVE argument silently - pass positives,
//      the sign lives at the call site
//   4  intVar * floatVar truncates to 0 - literals or floats only in that product
//   5  the running game keeps a loaded grouping's TERRAIN by file name; a terrain edit
//      shows only under a new name or after a restart (units re-read)
//   6  `label` and the other XS keywords are not identifiers
// Unit ids are positional: never add, drop or reorder a placement call without a census.
// ============================================================================
int PlayerNum = cNumberNonGaiaPlayers;

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

// ============================================================================
// HELPERS
// ============================================================================

// ---- Paris's city randomiser (Alistair's), verbatim: a list of cell locations split into zones, each zone
// shuffled; placeGroupings takes the first cells of a zone in shuffled order, filler the first FREE cell of a range.
int gCityLocs = -1;
int gCityLocsStatus = -1;
int gCellsPerBank = 24;   // the north bank's cell i is the south bank's cell i mirrored, at index i + gCellsPerBank

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

// Place a grouping at the first free cell in [startIndex, endIndex]; false when none is left.
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

// One city cell on both banks: the south one at index i, its mirror at i + gCellsPerBank.
void cityCell(int i = -1, float rowX = 0.0, float colZS = 0.0, float colZN = 0.0) {
	xsArraySetVector(gCityLocs, i, xsVectorSet(rowX, 0.0, colZS));
	xsArraySetVector(gCityLocs, i + gCellsPerBank, xsVectorSet(rowX, 0.0, colZN));
}

// ---- trade-route read-backs: each call PLACES one controller unit (it counts in the unit ids) and leaves the
// unit's real position in gRealX / gRealZ - copy them on the next line, the next call overwrites them.
float gRealX = 0.5;
float gRealZ = 0.5;

// A zpSPCWaterSpawnPoint dropped AT a route waypoint (rmPlaceObjectDefAtPoint lands on the BUILT route).
int gControllerIdx = 0;
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

// A SocketTradeRoute linked to the route, searched within 4 m of the spot (the spot is on the measured road).
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

// A harbour's post (zpOrientalFerry, Istanbul's ferry) linked to the lane, min 0 / max 0.5 - zpvenicecity's
// "sockets to dock Trade Posts" 1:1. Asked where the harbour's export has the post (its origin - postWestM in x,
// origin + postToWaterM toward the water: waterSign -1.0 on the north bank, +1.0 on the south), placed BEFORE the
// harbour grouping; the grouping origin is rebuilt from the post's REAL position into gHarbourX / gHarbourZ -
// copy them on the next line. Returns the post's object def.
float gHarbourX = 0.5;
float gHarbourZ = 0.5;
int gPostIdx = 0;
int harbourPost(int laneID = -1, float originX = 0.5, float originZ = 0.5, float postWestM = 0.0, float postToWaterM = 0.0, float waterSign = 1.0)
{
	gPostIdx = gPostIdx + 1;
	float x = originX - rmXMetersToFraction(postWestM);
	float z = originZ + waterSign * rmZMetersToFraction(postToWaterM);
	int post = rmCreateObjectDef("harbour post " + gPostIdx);
	rmSetObjectDefTradeRouteID(post, laneID);
	rmAddObjectDefItem(post, "zpOrientalFerry", 1, 0.0);
	rmSetObjectDefMinDistance(post, 0.0);
	rmSetObjectDefMaxDistance(post, 0.5);
	rmPlaceObjectDefAtLoc(post, 0, x, z);
	vector loc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(post, 0));
	float realX = rmXMetersToFraction(xsVectorGetX(loc));
	float realZ = rmZMetersToFraction(xsVectorGetZ(loc));
	gHarbourX = realX + rmXMetersToFraction(postWestM);
	gHarbourZ = realZ - waterSign * rmZMetersToFraction(postToWaterM);
	rmEchoInfo("LONDON harbour post " + gPostIdx + " asked " + rmXFractionToMeters(x) + "," + rmZFractionToMeters(z) + " m -> real " + xsVectorGetX(loc) + "," + xsVectorGetZ(loc));
	return(post);
}

// ---- groupings
// An island grouping at an exact spot (law 2); returns the instance for rmGetGroupingInstanceUnitByType.
int placeIsland(int grouping = -1, float x = 0.0, float z = 0.0)
{
	rmSetGroupingMinDistance(grouping, 0.0);
	rmSetGroupingMaxDistance(grouping, 0.00);
	rmAddGroupingToClass(grouping, rmClassID("classPlateau"));
	int placement = rmPlaceGroupingInstanceAtLoc(grouping, x, z, 0);
	return(placement);
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

// ---- areas
// A quay plateau (Paris "shore" area) clipped to a box: the box edge facing the water becomes the quay wall
// ("ZP City" cliff, height 0); the streets paint (Paris "streets" area) uses the same box. Only the box
// constrains it - plateau avoidance gapped the bridge.
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
	rmAddAreaConstraint(quay, box);
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

// Plain grass countryside behind one bank (Paris), kept off the plateaus.
void countryside(string name = "", float z = 0.5, int constraint = -1)
{
	int area = rmCreateArea(name);
	rmSetAreaSize(area, 0.6, 0.6);
	rmSetAreaLocation(area, 0.5, z);
	rmSetAreaCoherence(area, 1.0);
	rmSetAreaBaseHeight(area, 1.0);
	rmAddAreaConstraint(area, constraint);
	rmSetAreaMix(area, "nwt_grass1");
	rmSetAreaElevationVariation(area, 0.0);
	rmBuildArea(area);
}

// ---- object defs
// A single unit at an exact spot, min 0 / max maxM; returns the def (rmGetUnitPlaced needs it).
int unitAt(string name = "", string proto = "", float maxM = 0.0, float x = 0.5, float z = 0.5)
{
	int d = rmCreateObjectDef(name);
	rmAddObjectDefItem(d, proto, 1, 0.0);
	rmSetObjectDefMinDistance(d, 0.0);
	rmSetObjectDefMaxDistance(d, maxM);
	rmPlaceObjectDefAtLoc(d, 0, x, z);
	return(d);
}

// A water treasure's object def, zpcaribbeanwars's form: the ypNuggetBoat placeholder, the nuggetmods difficulty
// latched, min 0 / max maxM search. Define only - the spawn is a separate rmPlaceObjectDefAtLoc at the caller.
int waterNuggetDef(string name = "", int difficulty = 0, float maxM = 0.0)
{
	int d = rmCreateObjectDef(name);
	rmAddObjectDefItem(d, "ypNuggetBoat", 1, 0.0);
	rmSetNuggetDifficulty(difficulty, difficulty);
	rmSetObjectDefMinDistance(d, 0.0);
	rmSetObjectDefMaxDistance(d, maxM);
	return(d);
}

// ---- triggers (Istanbul's shapes)
// One "AutoConvert suspended" effect on the current trigger.
void suspendAutoConvert(int unitId = -1)
{
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", "" + unitId);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
}

// "Guard nugget collectable -> the capturable converts again" (Istanbul "Harbour k Convert ON").
void releaseOnNugget(string name = "", int nuggetId = -1, int unitId = -1)
{
	rmCreateTrigger(name);
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", "" + nuggetId);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", "" + unitId, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
}

// The Tower family (Istanbul's palace), three passes so every name exists before a Fire Event references it:
// pass 1 creates the per-player conversion triggers; pass 2 the unlock (guard nugget collectable -> the flag
// converts again, all conversions armed); pass 3 fills each conversion (player p holds the flag -> the Tower
// building converts to p, the OTHER players' conversions re-armed).
void towerConvCreate(string side = "")
{
	for (k = 1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("TowerConv" + side + "_Plr" + k);
	}
}

void towerUnlock(string side = "", int nuggetId = -1, int flagId = -1)
{
	rmCreateTrigger("Tower" + side + "Unlock");
	rmSwitchToTrigger(rmTriggerID("Tower" + side + "Unlock"));
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", "" + nuggetId);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", "" + flagId, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	for (k = 1; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TowerConv" + side + "_Plr" + k));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
}

void towerConvFill(string side = "", int flagId = -1, int buildingId = -1)
{
	for (p = 1; <= cNumberNonGaiaPlayers)
	{
		rmSwitchToTrigger(rmTriggerID("TowerConv" + side + "_Plr" + p));
		rmAddTriggerCondition("Units Owned");
		rmSetTriggerConditionParam("SrcObject", "" + flagId);
		rmSetTriggerConditionParamInt("Player", p);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject", "" + buildingId);
		rmSetTriggerEffectParamInt("PlayerID", p);
		for (q = 1; <= cNumberNonGaiaPlayers)
		{
			if (q != p)
			{
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("TowerConv" + side + "_Plr" + q));
			}
		}
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset", "SheepFound");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(false);
		rmSetTriggerLoop(false);
	}
}

// ============================================================================
void main(void)
{
	rmSetStatusText("",0.01);

	// ---- 0. civs, frame, map types, classes, constraints --------------------------------------------
	// natives: the Parliament block carries the one socket (zpSocketSansculottes) - allocated the Paris way
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

	// Paris frame, long axis on z: 360 m = 6.6 + row 00 + 4 + row 0 + 10.2 + road + 3 + row 1 + 7 x 34 + 6.6
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
	rmSetMapType("water");   // every map in the mod with water nuggets declares it (Istanbul, Caribbean, Independence, Iceland); added 2026-09-18 for the privateer treasures
	rmSetMapType("default");
	rmSetMapType("westEurope");
	rmSetMapType("piratehistoricalmap");
	rmSetMapType("euroTradeRouteUpgradeAll");
	chooseMercs();
	rmSetWorldCircleConstraint(true);

	// Paris's class list (looked up by name where used)
	rmDefineClass("player");
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
	rmDefineClass("classStreet");
	rmDefineClass("classPlateau");
	rmDefineClass("classBlock");
	int spawnSwitch = rmRandInt(0,1);

	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 5.0);                            // 5+ player starts
	int avoidPlateauShort = rmCreateClassDistanceConstraint("avoid plateau short", rmClassID("classPlateau"), 2.0);   // countryside (Paris)

	// ---- T. TUNABLES --------------------------------------------------------------------------------
	// T1. asked lines (the engine snaps the road; the real x / z are read back in 1 and 2)
	float roadAsk      = 0.7756;   // land route x = 279.2 m from the x = 1 edge: 6.6 + 30 + 4 + 30 + 10.2
	float zRiverAsk    = 0.5;      // river centre line asked (rivers do not snap; the lane is asked off it)
	int   riverRadius  = 40;       // ~84 m of water; the bridge's arches span it

	// T2. the two bank numbers - the ONLY knobs that move a bank, both off the REAL lane leg of that bank
	int   cityDistTiles     = 14;  // real leg -> quay wall line (13 = the water's edge for a 16 m leg)
	int   harbourShoreTiles = 16;  // real leg -> a pier's shore edge; independent of the city number

	// T3. grid pitch (Paris's numbers on a 360 m short side)
	float rowGapFarM    = 18.0;    // road centre -> row 0 centre (row edge 3 m off the road)
	float rowGapNearM   = 18.0;    // road centre -> row 1 centre (Paris's Z5 side)
	float rowPitchM     = 34.0;    // 30 m block + 4 m street, rows across x
	int   colFirstTiles = 10;      // wall line -> column 1 centre (a 5 m promenade + half a block)
	int   colPitchTiles = 16;      // 30 m block + 2 m street, columns along z
	int   cityDepthTiles = 66;     // wall line -> column 4's outer edge (4 x 16 + the promenade)

	// T4. FILE FACTS - measured from the grouping exports, never tuned; re-measure when an export changes
	float bridgeOffX = 0.78;       float bridgeOffZ = 0.4;   // EU_SPC_London_Bridge (24x48) origin off (road, river): deck on the road, arches over the water
	float bridgeWestWallM = 22.0;  float bridgeEastWallM = 16.0;   // the bridge island's walls off its origin (riverside deco slots)
	float hNTopEdgeM = 12.0;       float hNPostWestM = 1.5233;   float hNPostToWaterM = 3.5141;   // EU_SPC_London_Harbour_NW_01: top z -8..+12, +z = shore; origin -> post west / toward the water
	float hSTopEdgeM = 10.0;       float hSPostWestM = 0.4970;   float hSPostToWaterM = 5.7479;   // EU_SPC_London_Harbour_SE_01: top z -10..+10, -z = shore
	// (both exports had every unit moved z +1 against the terrain on 2026-09-17, the post with them)

	// T5. handles and laws
	float laneLegM = 16.0;              // the nautical U: legs this far off the river centre
	float laneTurnFromRoadM = 80.0;     // the U's turn this far west of the road (in front of row 3; 60 m clear of the bridge)
	float harbourGuardOffM = 30.0;      // privateer treasure: this far from its harbour's origin along the river toward the bridge (+x), 12 m clear of the pier's terrain box
	float harbourGuardOffLegM = 6.0;    // ... and this far shoreward of the bank's REAL lane leg: ship-valid water (the census of 2026-09-18 11:23 shows nothing placed on the shallow bank 6-8 m off the quay wall)
	float harbourGuardSearchM = 15.0;   // ... and the search radius around that spot
	float decoMouthXM = 12.0;           // the first riverside deco (40 m) centred this far in: the mouth slot is only 26 m
	int   instanceIdShiftIndividual = 0;   // rmGetUnitPlaced (object defs) + this = engine unit id (Istanbul measured 2; London 0, tuned when the triggers are watched)
	int   instanceIdShift = 0;             // rmGetGroupingInstanceUnitByType (grouping instances) + this

	rmSetStatusText("",0.10);

	// ---- 1. LAND ROUTE (law 1) and its real x ---------------------------------------------------
	int tradeRouteID = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteID, roadAsk, 0.0);
	rmAddTradeRouteWaypoint(tradeRouteID, roadAsk, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID, roadAsk, 1.0);
	rmBuildTradeRoute(tradeRouteID, "dirt");
	routePoint(tradeRouteID, 0.25);
	float road25X = gRealX;
	routePoint(tradeRouteID, 0.75);
	float road75X = gRealX;
	float xRoad = (road25X + road75X) * 0.5;
	rmEchoInfo("LONDON road x: asked " + roadAsk + " -> real " + xRoad);
	float zRiver = zRiverAsk;   // asked; the real centre is measured in 2

	rmSetStatusText("",0.20);

	// ---- 2. THE NAUTICAL LANE (law 1: before the river, zpvenicecity's water_trail), Venice's fake stopper docked
	// on it (zpSPCWaterSpawnPoint at waypoint 0.5, AllowOverlap, min / max 0: "without it the islands don't spawn"),
	// then one docked controller per leg - their read-back z is the only z this map trusts from here on
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
	routePoint(waterRouteID, 0.2);
	float zLaneS = gRealZ;
	routePoint(waterRouteID, 0.8);
	float zLaneN = gRealZ;
	zRiver = (zLaneS + zLaneN) * 0.5;                              // the river centre = the middle of the two real legs
	float wallS = zLaneS - rmZTilesToFraction(cityDistTiles);      // the St Paul's bank's quay wall line
	float wallN = zLaneN + rmZTilesToFraction(cityDistTiles);      // the Minster bank's quay wall line
	rmEchoInfo("LONDON lane legs real " + rmZFractionToMeters(zLaneS) + " / " + rmZFractionToMeters(zLaneN) + " m; river centre " + rmZFractionToMeters(zRiver) + " m, walls " + rmZFractionToMeters(wallS) + " / " + rmZFractionToMeters(wallN) + " m");
	routeSocket(tradeRouteID, xRoad, zRiver);   // the one socket: on London Bridge, at the real crossing

	// ---- 3. THE GRID, from the real road and the real walls (nothing is placed here) ---------------
	// rows across x: 00 and 0 behind the road (+x), 1..8 in front (-x); 12 / 78 = the 2-row block centres
	float locX00 = xRoad + rmXMetersToFraction(rowGapFarM + rowPitchM);
	float locX0 = xRoad + rmXMetersToFraction(rowGapFarM);
	float locX1 = xRoad - rmXMetersToFraction(rowGapNearM);
	float locX2 = locX1 - rmXMetersToFraction(rowPitchM);
	float locX3 = locX2 - rmXMetersToFraction(rowPitchM);
	float locX4 = locX3 - rmXMetersToFraction(rowPitchM);
	float locX5 = locX4 - rmXMetersToFraction(rowPitchM);
	float locX6 = locX5 - rmXMetersToFraction(rowPitchM);
	float locX7 = locX6 - rmXMetersToFraction(rowPitchM);
	float locX8 = locX7 - rmXMetersToFraction(rowPitchM);
	float locX12 = (locX1 + locX2) * 0.5;
	float locX78 = (locX7 + locX8) * 0.5;
	float locX34 = (locX3 + locX4) * 0.5;   // the Stuart export's 2-row slot (see 10.1)
	// columns along z off each bank's wall line (s = St Paul's / south, n = Minster / north); 12 = the 2-column centre
	int col1 = colFirstTiles;
	int col2 = colFirstTiles + colPitchTiles;
	int col3 = colFirstTiles + colPitchTiles * 2;
	int col4 = colFirstTiles + colPitchTiles * 3;
	float locZs1 = wallS-rmZTilesToFraction(col1);
	float locZs2 = wallS-rmZTilesToFraction(col2);
	float locZs3 = wallS-rmZTilesToFraction(col3);
	float locZs4 = wallS-rmZTilesToFraction(col4);
	float locZn1 = wallN+rmZTilesToFraction(col1);
	float locZn2 = wallN+rmZTilesToFraction(col2);
	float locZn3 = wallN+rmZTilesToFraction(col3);
	float locZn4 = wallN+rmZTilesToFraction(col4);
	float locZs12 = wallS-rmZTilesToFraction(col1+col2)*0.5;
	float locZn12 = wallN+rmZTilesToFraction(col1+col2)*0.5;
	// the HARBOURS: two per bank, N1 / S1 at the Tower rows' (7-8) centre, N2 / S2 at the rows 4-5 centre halfway to
	// the bridge (their x kept as its own expression, not locX78: the asked post goes through the lane snap and this
	// form is the censused one); each bank's grouping origin z = shore edge harbourShoreTiles off the REAL leg, the
	// export's top edge back to the origin
	float harbour1X = xRoad - rmXMetersToFraction(rowGapNearM + 6.5 * rowPitchM);
	float harbour2X = xRoad - rmXMetersToFraction(rowGapNearM + 3.5 * rowPitchM);
	float harbourNZ = zLaneN + rmZTilesToFraction(harbourShoreTiles) - rmZMetersToFraction(hNTopEdgeM);
	float harbourSZ = zLaneS - rmZTilesToFraction(harbourShoreTiles) + rmZMetersToFraction(hSTopEdgeM);

	// ---- 4. THE RIVER (rect-map rule: river z is read in size_x units -> true z metres / sizeX) ----
	int riverMain = rmRiverCreate(-1, "ZP Paris River", 4, 4, riverRadius, riverRadius);
	rmRiverAddWaypoint(riverMain, 0.0, rmXMetersToFraction(rmZFractionToMeters(zRiver)));
	rmRiverAddWaypoint(riverMain, 1.0, rmXMetersToFraction(rmZFractionToMeters(zRiver)));
	rmRiverBuild(riverMain);

	rmSetStatusText("",0.30);

	// ---- 5. THE HARBOUR POSTS (zpvenicecity: right after the river, BEFORE the groupings). Each harbour's names:
	// harbour<bank><k>PostDef, harbour<bank><k>X / Z = its grouping origin rebuilt from the REAL post
	int harbourN1PostDef = harbourPost(waterRouteID, harbour1X, harbourNZ, hNPostWestM, hNPostToWaterM, -1.0);
	float harbourN1X = gHarbourX;   float harbourN1Z = gHarbourZ;
	int harbourN2PostDef = harbourPost(waterRouteID, harbour2X, harbourNZ, hNPostWestM, hNPostToWaterM, -1.0);
	float harbourN2X = gHarbourX;   float harbourN2Z = gHarbourZ;
	int harbourS1PostDef = harbourPost(waterRouteID, harbour1X, harbourSZ, hSPostWestM, hSPostToWaterM, 1.0);
	float harbourS1X = gHarbourX;   float harbourS1Z = gHarbourZ;
	int harbourS2PostDef = harbourPost(waterRouteID, harbour2X, harbourSZ, hSPostWestM, hSPostToWaterM, 1.0);
	float harbourS2X = gHarbourX;   float harbourS2Z = gHarbourZ;

	// ---- 6. LONDON BRIDGE (law 2): deck on the road, arches over the river; deck height 4.949 ---------
	int londonBridge = rmCreateGrouping("london bridge", "EU_SPC_London_Bridge");
	int bridgeInst = placeIsland(londonBridge, xRoad + rmXMetersToFraction(bridgeOffX), zRiver + rmZMetersToFraction(bridgeOffZ));

	// ---- 7. THE HARBOUR GROUPINGS at their origins (zpvenicecity's ControllerLoc idiom, law 2) --------
	int harbourN1Grouping = rmCreateGrouping("harbour north 1", "EU_SPC_London_Harbour_NW_01");
	int harbourN1Inst = placeIsland(harbourN1Grouping, harbourN1X, harbourN1Z);
	int harbourN2Grouping = rmCreateGrouping("harbour north 2", "EU_SPC_London_Harbour_NW_01");
	int harbourN2Inst = placeIsland(harbourN2Grouping, harbourN2X, harbourN2Z);
	int harbourS1Grouping = rmCreateGrouping("harbour south 1", "EU_SPC_London_Harbour_SE_01");
	int harbourS1Inst = placeIsland(harbourS1Grouping, harbourS1X, harbourS1Z);
	int harbourS2Grouping = rmCreateGrouping("harbour south 2", "EU_SPC_London_Harbour_SE_01");
	int harbourS2Inst = placeIsland(harbourS2Grouping, harbourS2X, harbourS2Z);

	// ---- 8. THE PRIVATEER TREASURES: one water nugget per harbour (nuggetmods zpNuggetLondonHarbour 603: waternugget,
	// nuggetunit zpNuggetInvisibleWater, one dePrivateerGuardian), defined first, spawned after, each harbourGuardOffM
	// along the river toward the bridge and harbourGuardOffLegM shoreward of the bank's real lane leg. Census 2026-09-18:
	// the 603 record DOES resolve (a land placeholder under the latch became its nuggetunit); the water placeholder
	// (ypNuggetBoat, movementtype water, obstruction 3 x 2) is what never placed on the bank - the ferry posts prove
	// nothing about depth (zpOrientalFerry is an AIR unit). The asked spots are echoed in metres.
	int harbourN1GuardDef = waterNuggetDef("harbour guard north 1", 603, harbourGuardSearchM);
	int harbourN2GuardDef = waterNuggetDef("harbour guard north 2", 603, harbourGuardSearchM);
	int harbourS1GuardDef = waterNuggetDef("harbour guard south 1", 603, harbourGuardSearchM);
	int harbourS2GuardDef = waterNuggetDef("harbour guard south 2", 603, harbourGuardSearchM);
	float harbourN1GuardX = harbourN1X + rmXMetersToFraction(harbourGuardOffM);   float harbourN1GuardZ = zLaneN + rmZMetersToFraction(harbourGuardOffLegM);
	float harbourN2GuardX = harbourN2X + rmXMetersToFraction(harbourGuardOffM);   float harbourN2GuardZ = zLaneN + rmZMetersToFraction(harbourGuardOffLegM);
	float harbourS1GuardX = harbourS1X + rmXMetersToFraction(harbourGuardOffM);   float harbourS1GuardZ = zLaneS - rmZMetersToFraction(harbourGuardOffLegM);
	float harbourS2GuardX = harbourS2X + rmXMetersToFraction(harbourGuardOffM);   float harbourS2GuardZ = zLaneS - rmZMetersToFraction(harbourGuardOffLegM);
	rmEchoInfo("LONDON guard spots asked (m): N1 " + rmXFractionToMeters(harbourN1GuardX) + "," + rmZFractionToMeters(harbourN1GuardZ) + " N2 " + rmXFractionToMeters(harbourN2GuardX) + "," + rmZFractionToMeters(harbourN2GuardZ) + " S1 " + rmXFractionToMeters(harbourS1GuardX) + "," + rmZFractionToMeters(harbourS1GuardZ) + " S2 " + rmXFractionToMeters(harbourS2GuardX) + "," + rmZFractionToMeters(harbourS2GuardZ));
	rmPlaceObjectDefAtLoc(harbourN1GuardDef, 0, harbourN1GuardX, harbourN1GuardZ);
	rmPlaceObjectDefAtLoc(harbourN2GuardDef, 0, harbourN2GuardX, harbourN2GuardZ);
	rmPlaceObjectDefAtLoc(harbourS1GuardDef, 0, harbourS1GuardX, harbourS1GuardZ);
	rmPlaceObjectDefAtLoc(harbourS2GuardDef, 0, harbourS2GuardX, harbourS2GuardZ);

	// ---- 9. CITY FLOOR: one straight quay per bank (wall line -> column 4's outer edge), streets, countryside
	quaySegment(0.0, wallS - rmZTilesToFraction(cityDepthTiles), 1.0, wallS, 0.7);
	quaySegment(0.0, wallN, 1.0, wallN + rmZTilesToFraction(cityDepthTiles), 0.7);
	countryside("countryside S", zRiver-rmZTilesToFraction(130), avoidPlateauShort);
	countryside("countryside N", zRiver+rmZTilesToFraction(130), avoidPlateauShort);

	rmSetStatusText("",0.50);

	// ---- 10. BLOCKS, Paris's order: 10.1 fixed doubles, 10.2 fixed singles, 10.3 the cell table, 10.4 resource
	// buildings in shuffled zones, 10.5 fillers (Academy, treasures), 10.6 houses in every free cell. Only Paris's
	// resource and treasure assets - no Paris native blocks (London's are Stuart / Parliament / Jewish), no city hall /
	// court / military / bastions.
	// Grouping files are the user's exports, referenced as they are: never a rotated copy (a block that must face the
	// other way is its own export, suffixed by its facing, e.g. Harbour_NW / _SE). London-only: EU_SPC_London_*,
	// EU_Native_Block_Stuart_01 / Parlam_01, EU_House_Block_Academy; every other file is shared with zpparis /
	// zpverseilles - never edited from here.
	int blockStPaul = cityBlock("st paul", "EU_SPC_London_StPaul");
	int blockMinster = cityBlock("minster", "EU_SPC_London_Minster");
	int blockStuart = cityBlock("stuart natives", "EU_Native_Block_Stuart_01");
	int blockParliament = cityBlock("parliament natives", "EU_Native_Block_Parlam_01");
	int blockTowerS = cityBlock("tower of london", "EU_SPC_London_Tower_01");
	int blockTowerN = cityBlock("tower of london north", "EU_SPC_London_Tower_02");   // the user's north-west Tower: red, its capturable flag and guard nugget BAKED
	int blockTrade = cityBlock("trade block", "EU_SPC_Block_Trade");                  // the 2024 trade block as exported (shared with the Steam Versailles tests); socket faces +z
	// the Figma's fixed blocks, one per bank: Park, Menagerie (nugget 98), Native Jewish, Factory (nugget 299),
	// Construction (Paris's "Empty Blocks") at the bridge landing where a random cell sometimes stayed empty
	int blockPark = cityBlock("park", "EU_House_Block_Park");
	int blockMenagerie = cityBlock("menagerie", "EU_Resource_Block_Menagerie");
	int blockJewish = cityBlock("jewish natives", "EU_Natives_Block_Jewish");
	int blockFactory = cityBlock("factory", "EU_Resource_Block_All1");
	int blockConstruction = cityBlock("Construction", "EU_SPC_Block_Constr");
	// Paris's resource buildings by zone: Centre = Market, Bank, Embassy; Outer = Gold Smelter; Suburbs = Mill (Paris's
	// Food1, in the Destilery's place - user 2026-09-18), Warehouse; Paris's Forester stays out of the city
	int blockMarket = cityBlock("market", "EU_Resource_Block_All2");
	int blockBank = cityBlock("bank", "EU_Resource_Block_Gold1");
	int blockEmbassy = cityBlock("Native Embassy", "EU_House_Block_Embassy");
	int blockGoldSmelter = cityBlock("Gold Smelter", "EU_Resource_Block_Gold2");
	int blockMill = cityBlock("Mill", "EU_Resource_Block_Food1");
	int blockWarehouse = cityBlock("Warehouse", "EU_Resource_Block_Wood1");
	// fillers: the Academy (nuggetmods zpNuggetAcademyLondon 604) and Paris's two treasure blocks (London's gallows, 606)
	int blockAcademy = cityBlock("Academy", "EU_House_Block_Academy");
	int blockTreasure1 = cityBlock("Treasure1", "EU_House_Block_Treasure1");
	int blockTreasure2 = cityBlock("Treasure2", "EU_House_Block_Treasure2");
	// the filler houses
	int blockHouse1 = cityBlock("house1", "EU_House_Block_01");
	int blockHouse2 = cityBlock("house2", "EU_House_Block_02");
	int blockHouse3 = cityBlock("house3", "EU_House_Block_03");
	int blockHouse4 = cityBlock("house4", "EU_House_Block_04");
	int blockHouse5 = cityBlock("house5", "EU_House_Block_05");
	int blockHouse6 = cityBlock("house6", "EU_House_Block_06");

	// ---- 10.1 fixed doubles: St Paul / Minster rows 1-2 x cols 1-2, Stuart / Parliament row 3 x cols 1-2, the
	// Towers rows 7-8 x cols 1-2 at the water (instances: the triggers need the Towers' ids). Each Tower's handle
	// (Istanbul's palace) is the EXPORT's own units, nothing is spawned by the script: the gate treasure each export
	// carries (NuggetDroppedWood, Tower_01 (-0.99, -13.4) / Tower_02 (0.99, 13.4)) takes nuggetmods zpNuggetTowerOfLondon
	// 605 (nuggetunit zpNuggetInvisible, ten Redcoats) through the latch set BEFORE both instances (Istanbul's guild
	// idiom; no grouping between them bakes a nugget). Neither export carries a capturable flag: the flag-driven
	// conversion family (13.3) is built only when a flag id exists.
	rmPlaceGroupingAtLoc(blockStPaul, 0, locX12, locZs12);
	// STUART: the export EU_Native_Block_Stuart_01 is 30 x 15 tiles (60 m across the rows, 30 m along a column) - it
	// does not fit the row 3 x cols 1-2 slot (30 x 62 m), so it takes rows 3-4 x col 1 and the south Park moves to
	// row 3 col 2 (10.2). Same four cells, nothing else moves. An export in Parliament's orientation (15 x 30) goes
	// back to (locX3, locZs12) with the Park back to (locX4, locZs1).
	rmPlaceGroupingAtLoc(blockStuart, 0, locX34, locZs1);
	rmSetNuggetDifficulty(605, 605);
	int towerSInst = rmPlaceGroupingInstanceAtLoc(blockTowerS, locX78, locZs12, 0);
	rmPlaceGroupingAtLoc(blockMinster, 0, locX12, locZn12);
	rmPlaceGroupingAtLoc(blockParliament, 0, locX3, locZn12);
	int towerNInst = rmPlaceGroupingInstanceAtLoc(blockTowerN, locX78, locZn12, 0);

	// ---- 10.2 fixed singles: trade row 1 col 3, Construction row 0 col 1, Park row 4 col 1 (south: row 3 col 2), Menagerie row 4 col 2,
	// Native Jewish row 6 col 3, Factory row 0 col 2 - nugget latches as Paris
	rmPlaceGroupingAtLoc(blockTrade, 0, locX1, locZs3);
	rmPlaceGroupingAtLoc(blockTrade, 0, locX1, locZn3);
	rmPlaceGroupingAtLoc(blockConstruction, 0, locX0, locZs1);
	rmPlaceGroupingAtLoc(blockConstruction, 0, locX0, locZn1);
	rmPlaceGroupingAtLoc(blockPark, 0, locX3, locZs2);   // south: row 3 col 2 while Stuart holds rows 3-4 x col 1 (10.1)
	rmPlaceGroupingAtLoc(blockPark, 0, locX4, locZn1);
	rmSetNuggetDifficulty(98, 98);
	int menagerieSInst = rmPlaceGroupingInstanceAtLoc(blockMenagerie, locX4, locZs2, 0);
	int menagerieNInst = rmPlaceGroupingInstanceAtLoc(blockMenagerie, locX4, locZn2, 0);
	rmPlaceGroupingAtLoc(blockJewish, 0, locX6, locZs3);
	rmPlaceGroupingAtLoc(blockJewish, 0, locX6, locZn3);
	rmSetNuggetDifficulty(299, 299);
	int factorySInst = rmPlaceGroupingInstanceAtLoc(blockFactory, locX0, locZs2, 0);
	int factoryNInst = rmPlaceGroupingInstanceAtLoc(blockFactory, locX0, locZn2, 0);

	rmSetStatusText("",0.70);

	// ---- 10.3 the cell table: 24 free cells per bank, the north bank the mirror of the south, each zone shuffled
	// on its own. Centre (6) = around the Basilicas and along the shores, Outer (5), Suburbs (13) = col 4 + the far corners.
	const int NUM_CELLS = 48;
	const int S_CENTER_START = 0;    const int S_CENTER_END = 5;
	const int S_OUTER_START = 6;     const int S_OUTER_END = 10;
	const int S_SUBURBS_START = 11;  const int S_SUBURBS_END = 23;
	const int N_CENTER_START = 24;   const int N_CENTER_END = 29;
	const int N_OUTER_START = 30;    const int N_OUTER_END = 34;
	const int N_SUBURBS_START = 35;  const int N_SUBURBS_END = 47;
	gCityLocs = xsArrayCreateVector(NUM_CELLS, cInvalidVector, "List of locations in the city");
	gCityLocsStatus = xsArrayCreateBool(NUM_CELLS, false, "Flags a loc as taken or not");
	//       idx  row     col S   col N
	// Centre: col 1 rows 5, 6 / col 2 rows 5, 6 / col 3 rows 2, 3
	cityCell(0,  locX5,  locZs1, locZn1);
	cityCell(1,  locX6,  locZs1, locZn1);
	cityCell(2,  locX5,  locZs2, locZn2);
	cityCell(3,  locX6,  locZs2, locZn2);
	cityCell(4,  locX2,  locZs3, locZn3);
	cityCell(5,  locX3,  locZs3, locZn3);
	// Outer: col 3 rows 4, 5 / col 1 row 00 / col 2 row 00 / col 3 row 0
	cityCell(6,  locX4,  locZs3, locZn3);
	cityCell(7,  locX5,  locZs3, locZn3);
	cityCell(8,  locX00, locZs1, locZn1);
	cityCell(9,  locX00, locZs2, locZn2);
	cityCell(10, locX0,  locZs3, locZn3);
	// Suburbs: col 4 every row / col 3 rows 00, 7, 8
	cityCell(11, locX00, locZs4, locZn4);
	cityCell(12, locX0,  locZs4, locZn4);
	cityCell(13, locX1,  locZs4, locZn4);
	cityCell(14, locX2,  locZs4, locZn4);
	cityCell(15, locX3,  locZs4, locZn4);
	cityCell(16, locX4,  locZs4, locZn4);
	cityCell(17, locX5,  locZs4, locZn4);
	cityCell(18, locX6,  locZs4, locZn4);
	cityCell(19, locX7,  locZs4, locZn4);
	cityCell(20, locX8,  locZs4, locZn4);
	cityCell(21, locX00, locZs3, locZn3);
	cityCell(22, locX7,  locZs3, locZn3);
	cityCell(23, locX8,  locZs3, locZn3);
	shuffle(gCityLocs, S_CENTER_START, S_CENTER_END);
	shuffle(gCityLocs, S_OUTER_START, S_OUTER_END);
	shuffle(gCityLocs, S_SUBURBS_START, S_SUBURBS_END);
	shuffle(gCityLocs, N_CENTER_START, N_CENTER_END);
	shuffle(gCityLocs, N_OUTER_START, N_OUTER_END);
	shuffle(gCityLocs, N_SUBURBS_START, N_SUBURBS_END);

	// ---- 10.4 the resource buildings (Paris's nugget latch 195): one list per zone, placed on both banks
	rmSetNuggetDifficulty(195, 195);
	int centerGroupings = xsArrayCreateInt(3, -1, "List of groupings for the city centre.");
	xsArraySetInt(centerGroupings, 0, blockMarket);
	xsArraySetInt(centerGroupings, 1, blockBank);
	xsArraySetInt(centerGroupings, 2, blockEmbassy);
	placeGroupings(centerGroupings, S_CENTER_START);
	placeGroupings(centerGroupings, N_CENTER_START);
	int outerGroupings = xsArrayCreateInt(1, -1, "List of groupings for the outer centre.");
	xsArraySetInt(outerGroupings, 0, blockGoldSmelter);
	placeGroupings(outerGroupings, S_OUTER_START);
	placeGroupings(outerGroupings, N_OUTER_START);
	int suburbGroupings = xsArrayCreateInt(2, -1, "List of suburbs groupings.");
	xsArraySetInt(suburbGroupings, 0, blockMill);
	xsArraySetInt(suburbGroupings, 1, blockWarehouse);
	placeGroupings(suburbGroupings, S_SUBURBS_START);
	placeGroupings(suburbGroupings, N_SUBURBS_START);

	// ---- 10.5 fillers: the first free cells of each bank in zone order - the Academy (604), then the two treasure
	// blocks with London's gallows nuggets (zpGallowsLondon1..3 = 606) in place of Paris's guillotines (192)
	rmSetNuggetDifficulty(604, 604);
	filler(blockAcademy, S_CENTER_START, S_SUBURBS_END);
	filler(blockAcademy, N_CENTER_START, N_SUBURBS_END);
	rmSetNuggetDifficulty(606, 606);
	filler(blockTreasure1, S_CENTER_START, S_SUBURBS_END);
	filler(blockTreasure2, S_CENTER_START, S_SUBURBS_END);
	filler(blockTreasure1, N_CENTER_START, N_SUBURBS_END);
	filler(blockTreasure2, N_CENTER_START, N_SUBURBS_END);

	// ---- 10.6 houses in every cell still free, the six Paris house blocks in turn
	int houseGroupings = xsArrayCreateInt(6, -1, "List of house groupings.");
	xsArraySetInt(houseGroupings, 0, blockHouse1);
	xsArraySetInt(houseGroupings, 1, blockHouse2);
	xsArraySetInt(houseGroupings, 2, blockHouse3);
	xsArraySetInt(houseGroupings, 3, blockHouse4);
	xsArraySetInt(houseGroupings, 4, blockHouse5);
	xsArraySetInt(houseGroupings, 5, blockHouse6);
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

	// ---- 11. RIVERSIDE DECORATIONS (Paris's EU_Riverside, turned for the x-running river: water side +z on the
	// south bank, -z on the north), centred on the wall line, four per bank along x: before the first harbour,
	// between the harbours, between the second harbour and the bridge, behind the bridge
	int riversideS = cityBlock("riverside south", "EU_SPC_London_Riverside_SE_01");
	int riversideN = cityBlock("riverside north", "EU_SPC_London_Riverside_NW_01");
	float decoZs = wallS;
	float decoZn = wallN;
	float decoX1 = rmXMetersToFraction(decoMouthXM);
	float decoX2 = (harbour1X + harbour2X) * 0.5;
	float decoX3 = (harbour2X + xRoad + rmXMetersToFraction(bridgeOffX) - rmXMetersToFraction(bridgeWestWallM)) * 0.5;
	float decoX4 = (xRoad + rmXMetersToFraction(bridgeOffX + bridgeEastWallM) + 1.0) * 0.5;
	rmPlaceGroupingAtLoc(riversideS, 0, decoX1, decoZs);
	rmPlaceGroupingAtLoc(riversideS, 0, decoX2, decoZs);
	rmPlaceGroupingAtLoc(riversideS, 0, decoX3, decoZs);
	rmPlaceGroupingAtLoc(riversideS, 0, decoX4, decoZs);
	rmPlaceGroupingAtLoc(riversideN, 0, decoX1, decoZn);
	rmPlaceGroupingAtLoc(riversideN, 0, decoX2, decoZn);
	rmPlaceGroupingAtLoc(riversideN, 0, decoX3, decoZn);
	rmPlaceGroupingAtLoc(riversideN, 0, decoX4, decoZn);

	rmSetStatusText("",0.80);

	// ---- 12. PLAYERS (Paris's placement transposed onto the z axis) ---------------------------------
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
	// 13. TRIGGERS, all at the end (Paris / Istanbul). Ids: object defs = rmGetUnitPlaced + instanceIdShiftIndividual,
	//     grouping instances = rmGetGroupingInstanceUnitByType + instanceIdShift; a baked nugget is queried by its
	//     nuggetmods <nuggetunit>, never by the authored placeholder (Istanbul).
	// ============================================================================================
	int harbourN1PostUnit = rmGetUnitPlaced(harbourN1PostDef, 0) + instanceIdShiftIndividual;
	int harbourN2PostUnit = rmGetUnitPlaced(harbourN2PostDef, 0) + instanceIdShiftIndividual;
	int harbourS1PostUnit = rmGetUnitPlaced(harbourS1PostDef, 0) + instanceIdShiftIndividual;
	int harbourS2PostUnit = rmGetUnitPlaced(harbourS2PostDef, 0) + instanceIdShiftIndividual;
	int harbourN1GuardUnit = rmGetUnitPlaced(harbourN1GuardDef, 0) + instanceIdShiftIndividual;
	int harbourN2GuardUnit = rmGetUnitPlaced(harbourN2GuardDef, 0) + instanceIdShiftIndividual;
	int harbourS1GuardUnit = rmGetUnitPlaced(harbourS1GuardDef, 0) + instanceIdShiftIndividual;
	int harbourS2GuardUnit = rmGetUnitPlaced(harbourS2GuardDef, 0) + instanceIdShiftIndividual;
	int menagerieSUnit = rmGetGroupingInstanceUnitByType(menagerieSInst, "zpSPCMenagerie") + instanceIdShift;
	int menagerieNUnit = rmGetGroupingInstanceUnitByType(menagerieNInst, "zpSPCMenagerie") + instanceIdShift;
	int menagerieSNugUnit = rmGetGroupingInstanceUnitByType(menagerieSInst, "zpNuggetInvisible") + instanceIdShift;   // nuggetmods 98
	int menagerieNNugUnit = rmGetGroupingInstanceUnitByType(menagerieNInst, "zpNuggetInvisible") + instanceIdShift;
	int factorySUnit = rmGetGroupingInstanceUnitByType(factorySInst, "zpSPCCapturableFactory") + instanceIdShift;
	int factoryNUnit = rmGetGroupingInstanceUnitByType(factoryNInst, "zpSPCCapturableFactory") + instanceIdShift;
	int factorySNugUnit = rmGetGroupingInstanceUnitByType(factorySInst, "zpNuggetInvisible") + instanceIdShift;       // nuggetmods 299
	int factoryNNugUnit = rmGetGroupingInstanceUnitByType(factoryNInst, "zpNuggetInvisible") + instanceIdShift;
	int towerSBldUnit = rmGetGroupingInstanceUnitByType(towerSInst, "zpSPCTowerOfLondon") + instanceIdShift;
	int towerNBldUnit = rmGetGroupingInstanceUnitByType(towerNInst, "zpSPCTowerOfLondon") + instanceIdShift;
	int towerSFlagUnit = rmGetGroupingInstanceUnitByType(towerSInst, "deSPCCapturableFlagCossack") + instanceIdShift;   // -1: no capturable flag in the exports yet
	int towerNFlagUnit = rmGetGroupingInstanceUnitByType(towerNInst, "deSPCCapturableFlagCossack") + instanceIdShift;
	int towerSNugUnit = rmGetGroupingInstanceUnitByType(towerSInst, "zpNuggetInvisible") + instanceIdShift;              // the gate treasure, resolved by 605
	int towerNNugUnit = rmGetGroupingInstanceUnitByType(towerNInst, "zpNuggetInvisible") + instanceIdShift;
	rmEchoInfo("LONDON ids: posts " + harbourN1PostUnit + " " + harbourN2PostUnit + " " + harbourS1PostUnit + " " + harbourS2PostUnit + " guards " + harbourN1GuardUnit + " " + harbourN2GuardUnit + " " + harbourS1GuardUnit + " " + harbourS2GuardUnit);
	rmEchoInfo("LONDON ids: menageries " + menagerieSUnit + " " + menagerieNUnit + " nuggets " + menagerieSNugUnit + " " + menagerieNNugUnit + " factories " + factorySUnit + " " + factoryNUnit + " nuggets " + factorySNugUnit + " " + factoryNNugUnit);
	rmEchoInfo("LONDON ids: towers " + towerSBldUnit + " " + towerNBldUnit + " flags " + towerSFlagUnit + " " + towerNFlagUnit + " nuggets " + towerSNugUnit + " " + towerNNugUnit);

	// ---- 13.1 startup: every capturable's AutoConvert suspended (Istanbul "Trade Harbours NoAutoConvert")
	rmCreateTrigger("London NoAutoConvert");
	suspendAutoConvert(harbourN1PostUnit);
	suspendAutoConvert(harbourN2PostUnit);
	suspendAutoConvert(harbourS1PostUnit);
	suspendAutoConvert(harbourS2PostUnit);
	suspendAutoConvert(menagerieSUnit);
	suspendAutoConvert(menagerieNUnit);
	suspendAutoConvert(factorySUnit);
	suspendAutoConvert(factoryNUnit);
	if (towerSFlagUnit >= 0)
		suspendAutoConvert(towerSFlagUnit);
	if (towerNFlagUnit >= 0)
		suspendAutoConvert(towerNFlagUnit);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ---- 13.2 releases: each guard nugget collectable -> its capturable converts again
	releaseOnNugget("Harbour N1 Convert ON", harbourN1GuardUnit, harbourN1PostUnit);
	releaseOnNugget("Harbour N2 Convert ON", harbourN2GuardUnit, harbourN2PostUnit);
	releaseOnNugget("Harbour S1 Convert ON", harbourS1GuardUnit, harbourS1PostUnit);
	releaseOnNugget("Harbour S2 Convert ON", harbourS2GuardUnit, harbourS2PostUnit);
	releaseOnNugget("Menagerie S Convert ON", menagerieSNugUnit, menagerieSUnit);
	releaseOnNugget("Menagerie N Convert ON", menagerieNNugUnit, menagerieNUnit);
	releaseOnNugget("Factory S Convert ON", factorySNugUnit, factorySUnit);
	releaseOnNugget("Factory N Convert ON", factoryNNugUnit, factoryNUnit);

	// ---- 13.3 the Towers (Istanbul's palace family), three passes per bank - only where the export carries a
	// capturable flag (none does today: both families are skipped)
	if (towerSFlagUnit >= 0)
	{
		towerConvCreate("S");
		towerUnlock("S", towerSNugUnit, towerSFlagUnit);
		towerConvFill("S", towerSFlagUnit, towerSBldUnit);
	}
	if (towerNFlagUnit >= 0)
	{
		towerConvCreate("N");
		towerUnlock("N", towerNNugUnit, towerNFlagUnit);
		towerConvFill("N", towerNFlagUnit, towerNBldUnit);
	}

	rmSetStatusText("",0.99);
} // END
