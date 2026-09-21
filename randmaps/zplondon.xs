// ============================================================================
// zplondon.xs  -  London on the Paris rig (Figma sketch of 2026-09-17)
// ----------------------------------------------------------------------------
// The long axis is z (573 m + the reserved columns, see 0.), the Thames runs along x at the map's middle with
// a straight shoreline, the land route runs along z near the x = 1 edge; two
// block rows behind the road, eight in front, players at both z ends. The
// banks are mirrored. Editor twin: Steam Game\RandMaps\00000_zplondon.xs.
// History and open bugs: memory london-map-status / london-privateer-nugget-bug.
//
// BUILD ORDER (z positions are inherited from REAL trade-route objects; x is the AUTHORED road line since 2026-09-21)
//   0.5 the lobby: the landmark coin (defenderBank) and the Florence roles - team 1 defends (Minster + Parliament),
//      team 0 attacks (St Paul + Stuart) - up front, the gates take owners
//   1  nautical lane + fake stopper, real leg z per bank -> river centre, walls (law 1) - FIRST (Paris's gate order)
//   2  land route DEFINED on the asked line, not built                          (Paris: gates before the road)
//   3  the grid, derived from the asked road and the real walls (no placement)
//   3.5 the gates at fixed coordinates: six outer wall segments (their gates on the road line)
//   3.9 the land route BUILT through the gates, real x read back for the census, the bridge socket docked
//   4  the river (rect-map rule: z authored in size_x units), after the road
//   5  harbour posts docked on the lane, real positions read back              (law 1)
//   6  London Bridge, instance API, after the river (before the road with gates it did not spawn) (law 2)
//   7  harbour groupings hung off the real posts, instance API                  (law 2)
//   8  harbour guards: the vanilla Euro trade-route post nugget (101) on the quay behind each harbour; the post
//      is released by "Units in Area" (no guardian left around it), never by the object-def nugget's id
//   9  quays (one straight plateau per bank), streets, countryside; 9.5 the wall terrain twins after it (Florence)
//   10 blocks in Paris's order: the landmark coin (10.0), fixed doubles, fixed singles, zones, fillers, houses
//   11 riverside decorations, 12 players (12.1 roles: see 0.5; 12.2 seats by role on the reserved columns, 12.3 the interim line for the rest),
//      12.5 the wall hills (Florence's Italian Cliff between the gate segments of 3.5), 13 triggers (all at the end)
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
//   7  a river from rmRiverCreate floats NO collideable hull (ship, boat nugget, ship guardian) - tested
//      2026-09-18 with three water bodies; only a water-initialised map does, and that breaks the piers and
//      the bridge. Water units on the Thames: air / NonCollideable only. Guards on the water are out.
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

// ---- the Florence system (zpflorence.xs 41-67, zpverseilles.xs 41-67): the k-th player of a lobby team by lowest
// player id, handed back through a global - the file's own words below, verbatim.
// Get player order within a team

int g_zpTeamPlayerResult = -1;

void zpGetTeamPlayer(int teamOrder = -1, int teamID = -1)
{
    g_zpTeamPlayerResult = -1;
    if (teamOrder <= 0) {
        return;
    }

    int count = 0;
    int i = 0;
    for (i = 1; <= cNumberNonGaiaPlayers)
    {
        if (rmGetPlayerTeam(i) == teamID)
        {
            count = count + 1;
            if (count == teamOrder)
            {
                g_zpTeamPlayerResult = i;  // "return" via global
                return;
            }
        }
    }
    // not found => stays -1
}

// Florence's hill between two wall segments (zpflorence.xs 1485-1500, the wallCliffs loop body, one hill per call):
// Italian Cliff at height 8, kept 2 m off the city floor (classPlateau, which it joins), 4 m off the routes and off
// the walls themselves; the size is the caller's (Florence: 240 tiles for its 30-38 m gaps).
void wallCliff(string name = "", float x = 0.5, float z = 0.5, int tiles = 240, int avoidFloor = -1, int avoidRoute = -1, int avoidWalls = -1)
{
	int area = rmCreateArea(name);
	rmSetAreaSize(area, rmAreaTilesToFraction(tiles), rmAreaTilesToFraction(tiles));
	rmSetAreaObeyWorldCircleConstraint(area, false);
	rmAddAreaToClass(area, rmClassID("classPlateau"));
	rmAddAreaConstraint(area, avoidFloor);
	rmAddAreaConstraint(area, avoidRoute);
	rmAddAreaConstraint(area, avoidWalls);
	rmSetAreaCliffType(area, "Italian Cliff");
	rmAddAreaToClass(area, rmClassID("classCliff"));
	rmSetAreaCliffEdge(area, 1, 1, 0.0, 0.0, 2);
	rmSetAreaCliffHeight(area, 0, 0, 0.5);
	rmSetAreaBaseHeight(area, 8.0);
	rmSetAreaHeightBlend(area, 3);
	rmSetAreaCoherence(area, 0.93);
	rmSetAreaLocation(area, x, z);
	rmBuildArea(area);
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
// ("ZP City" cliff, height 0); the streets paint (Paris "streets" area) uses the same box; then Paris's second
// texture - the promenade band along the wall in the river's outerbank city_street_ground (Paris gets it by
// stopping its streets paint 4 m short of the water; here it is painted, paintM wide from the wall line wallZ
// toward the land, landSign +1.0 for the north bank / -1.0 for the south). Only the box constrains the
// plateau - plateau avoidance gapped the bridge.
int gQuayIdx = 0;
void quaySegment(float x1 = 0.0, float z1 = 0.0, float x2 = 1.0, float z2 = 1.0, float sizeFrac = 0.7, float wallZ = 0.5, float landSign = 1.0, float paintM = 4.0)
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
	float promZ1 = wallZ;
	float promZ2 = wallZ + landSign * rmZMetersToFraction(paintM);
	if (landSign < 0.0)
	{
		promZ1 = promZ2;
		promZ2 = wallZ;
	}
	int promBox = rmCreateBoxConstraint("promenade box " + gQuayIdx, x1, promZ1, x2, promZ2);
	int prom = rmCreateArea("promenade " + gQuayIdx);
	rmSetAreaSize(prom, 0.005, 0.005);   // below the strip's own share of the map (4 x 360 m = 0.007): ask < enclosed
	rmSetAreaLocation(prom, (x1 + x2) * 0.5, (promZ1 + promZ2) * 0.5);
	rmSetAreaCoherence(prom, 1.0);
	rmSetAreaTerrainType(prom, "city\ground1_city_street_ground");
	rmAddAreaInfluenceSegment(prom, x1 + (x2 - x1) * 0.02, (promZ1 + promZ2) * 0.5, x2 - (x2 - x1) * 0.02, (promZ1 + promZ2) * 0.5);
	rmAddAreaConstraint(prom, promBox);
	rmSetAreaObeyWorldCircleConstraint(prom, false);
	rmBuildArea(prom);
}

// Countryside behind one bank (Paris's area, the italy_cliff_top mix of the British maps), kept off the plateaus.
void countryside(string name = "", float z = 0.5, int constraint = -1)
{
	int area = rmCreateArea(name);
	rmSetAreaSize(area, 0.6, 0.6);
	rmSetAreaLocation(area, 0.5, z);
	rmSetAreaCoherence(area, 1.0);
	rmSetAreaBaseHeight(area, 1.0);
	rmAddAreaConstraint(area, constraint);
	rmSetAreaMix(area, "italy_cliff_top");   // Art/terrain/mix/italy_cliff_top - the British maps' countryside (user 2026-09-18; was nwt_grass1)
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

// A land treasure's object def, zpelbe.xs's "nuggets to dock Trade Posts" form: the "Nugget" placeholder, the
// nuggets.xml difficulty latched, min 0 / max maxM search. Define only - the spawn is a separate rmPlaceObjectDefAtLoc.
int landNuggetDef(string name = "", int difficulty = 0, float maxM = 0.0)
{
	int d = rmCreateObjectDef(name);
	rmAddObjectDefItem(d, "Nugget", 1, 0.0);
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

// "No Gaia guardian of this type left within distM of the unit -> its AutoConvert resumes": the harbour release that
// needs only the POST's id (performance_test.xs's "Units in Area" form). An object-def nugget's own id is not a
// safe trigger target: the nugget manager swaps the placeholder for the record's nuggetunit and adds the guardians.
void releaseWhenClear(string name = "", int unitId = -1, string guardianType = "", int distM = 0)
{
	rmCreateTrigger(name);
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject", "" + unitId);
	rmSetTriggerConditionParamInt("Player", 0);
	rmSetTriggerConditionParam("UnitType", guardianType);
	rmSetTriggerConditionParamInt("Dist", distM);
	rmSetTriggerConditionParam("Op", "==");
	rmSetTriggerConditionParamInt("Count", 0);
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
	// natives: Parliamentarians (zpSocketParliament in the Parliament block), the House of Stuart (zpSPCSocketStuart in
	// the Stuart block) and the Jewish quarter - London's own three, nothing inherited from Paris
	int subCiv0=-1;
	int subCiv1=-1;
	int subCiv2=-1;
	if (rmAllocateSubCivs(3) == true)
	{
		subCiv0=rmGetCivID("zpParliament");
		rmEchoInfo("subCiv0 is zpParliament "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "zpParliament");
		subCiv1=rmGetCivID("Stuart");
		rmEchoInfo("subCiv1 is Stuart "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "Stuart");
		subCiv2=rmGetCivID("jewish");
		rmEchoInfo("subCiv2 is jewish "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "jewish");
	}

	// Paris frame, long axis on z: 360 m = 6.6 + row 00 + 4 + row 0 + 10.2 + road + 3 + row 1 + 7 x 34 + 6.6
	// RESERVED COLUMNS (user 2026-09-20): each bank is Paris's four columns deep plus extraColumns more - city floor
	// and streets, no cells in the placement tables; only the 10.7 fixed blocks sit on them. x is full (the rows),
	// so the city can only grow along z. The map grows by ONE bank's worth of columns in total, so the countryside
	// gives up half of the growth: the strip beyond the last column is 108.5 m on Paris's frame and 60.5 m here
	// (user: "proportionally decrease the countryside"). One column = colPitchTiles (16 tiles) = 32 m.
	int extraColumns = 3;
	int extraColumnM = 32;
	int sizeX = 360;
	int baseSizeZ = 613;              // Paris's 573 + 40 m for two players (user 2026-09-21: 669 could not seat every countryside object; the 3-4 player frame is 749)
	if (cNumberNonGaiaPlayers >=3)
		baseSizeZ = 653;
	if (cNumberNonGaiaPlayers >=6)
		baseSizeZ = 773;
	int sizeZ = baseSizeZ + extraColumns * extraColumnM;   // ints only: 613 -> 709, 653 -> 749, 773 -> 869
	rmSetMapSize(sizeX, sizeZ);

	rmSetAllMapReveal(true);
	rmSetMapElevationHeightBlend(1);
	rmSetSeaLevel(0.0);
	rmSetLightingSet("Andes_Skirmish");   // Art/lightsets/Andes_Skirmish.lgt - distinct from Paris (user 2026-09-18; tried NorthwestTerritory_Skirmish, GreatLakes_Summer_Skirmish; was age3challenges09a)
	rmSetSeaType("great lakes2");
	rmEnableLocalWater(false);
	// the base ground is a PLAIN terrain type, not a mix - a base mix scatters its objects (italy_cliff_top's cliff
	// rocks and ferns) over every unpainted tile, seen in game 2026-09-21. new_england\cliff_inland_top_ne is one of the
	// three textures that mix paints (Art/terrain/mix/italy_cliff_top.xml: cliff_inland_top_ne 3, river1_ne 4,
	// cliff_side_ne 1) and the ground London's own exports carry (St Paul, Minster, the Towers, the big park).
	rmTerrainInitialize("new_england\cliff_inland_top_ne", 1.0);
	rmSetMapType("grass");
	rmSetMapType("land");
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
	int spawnSwitch = 0;   // set in 0.5 from the landmark coin (2026-09-21: no longer a coin of its own): 0 = team 1 north, 1 = team 1 south

	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 5.0);                            // 5+ player starts
	int avoidPlateauShort = rmCreateClassDistanceConstraint("avoid plateau short", rmClassID("classPlateau"), 4.0);   // countryside (Paris: 2.0) and the wall hills; 4.0 since 2026-09-21 - the hills' cliff faces spilled onto the streets at 2 m, 6 m was too much (user: extend this one, no new constraint)
	int avoidTradeRouteWall = rmCreateTradeRouteDistanceConstraint("trade route wall", 4.0);                          // Florence 358: the wall hills off the routes
	int avoidWall = rmCreateTypeDistanceConstraint("avoid wall object", "AbstractWall", 0.001);                       // Florence 378: the wall hills off the walls

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
	int   colFirstTiles = 11;      // wall line -> column 1 centre: Paris's 7 m promenade + half a block (Paris: column 27 tiles off the centre, wall at 16; London had 10 = 5 m, too narrow for pathing and spawns - user 2026-09-18)
	int   colPitchTiles = 16;      // 30 m block + 2 m street, columns along z
	int   cityDepthTiles = 67 + colPitchTiles * extraColumns;     // wall line -> the LAST column's outer edge (11 + 3 x 16 + half a block = 66.5 for Paris's four; + 16 per reserved column)
	float promenadePaintM = 4.0;   // Paris's second quay texture: its streets paint stops 4 m short of the water and the river's outerbank city_street_ground shows; London paints that band explicitly

	// T4. FILE FACTS - measured from the grouping exports, never tuned; re-measure when an export changes
	float bridgeOffX = 0.78;       float bridgeOffZ = 0.4;   // EU_SPC_London_Bridge (24x48) origin off (road, river): deck on the road, arches over the water
	float bridgeWestWallM = 22.0;  float bridgeEastWallM = 16.0;   // the bridge island's walls off its origin (riverside deco slots)
	float hNTopEdgeM = 12.0;       float hNPostWestM = 1.5233;   float hNPostToWaterM = 3.5141;   // EU_SPC_London_Harbour_NW_01: top z -8..+12, +z = shore; origin -> post west / toward the water
	float hSTopEdgeM = 10.0;       float hSPostWestM = 0.4970;   float hSPostToWaterM = 5.7479;   // EU_SPC_London_Harbour_SE_01: top z -10..+10, -z = shore
	// (both exports had every unit moved z +1 against the terrain on 2026-09-17, the post with them)

	// T5. handles and laws
	float laneLegM = 16.0;              // the nautical U: legs this far off the river centre
	float laneTurnFromRoadM = 80.0;     // the U's turn this far west of the road (in front of row 3; 60 m clear of the bridge)
	int   harbourGuardDifficulty = 101; // nuggets.xml euNuggetCapturable2: the vanilla European trade-route post guard (ypNuggetTradingPost + four deGuardianMusketeer, maptype westEurope) - zpelbe.xs uses it the same way
	float harbourGuardInM = 2.5;        // the guard nugget this far INTO the city off the bank's quay wall line = the middle of the 5 m promenade, at the harbour's x (behind the harbour building)
	float harbourGuardSearchM = 3.0;    // ... and the search radius around that spot: stays on the promenade (6 m let it wander off the harbour - user 2026-09-18)
	float decoMouthXM = 12.0;           // the first riverside deco (40 m) centred this far in: the mouth slot is only 26 m
	int   instanceIdShiftIndividual = 1;   // rmGetUnitPlaced (object defs) + this = engine unit id: the lane's trade ship is created between the controllers and the posts (census 2026-09-18 13:26: posts = engine ids 7-10 after six RM placements; zpelbe uses +1 the same way)
	string harbourGuardType = "deGuardianMusketeer";   // the 101 record's guardians - what the release trigger counts around the post
	int   harbourGuardReachM = 25;         // ... within this distance of the post (nugget ~14 m behind it + the guardian spread)
	int   instanceIdShift = 0;             // rmGetGroupingInstanceUnitByType (grouping instances) + this

	// ---- 0.5 THE LOBBY: the coin and the roles - the Florence system (zpflorence.xs 124-155, zpistanbulb.xs 5b),
	// resolved up front because the gates (3.5) take their owners from them. TEAM 1 DEFENDS, TEAM 0 ATTACKS - Florence's
	// own fixed binding (user 2026-09-21: Parliament holds London, the Stuarts come to reclaim it - the King left
	// Whitehall in January 1642 and his army was turned back at Turnham Green that November). The k-th DEFENDER is
	// the k-th-lowest player id on team 1, the k-th ATTACKER the same on team 0. The ONE coin, defenderBank, says
	// WHERE the defenders' city (Minster + Parliament, 10.0) stands; the teams' banks and spawnSwitch (the interim
	// line placement in 12.3 reads it) follow it, so roles, natives and seats can never disagree.
	// 2-TEAM LOBBIES ONLY: any other lobby leaves every role at -1 (Florence, Istanbul); nothing may hand a role to
	// the engine without Istanbul's gaia fallback (if (owner < 0) owner = 0).
	int defenderBank = rmRandInt(0, 1);   // the landmark coin: 0 = the south bank (wallS), 1 = the north bank (wallN) - 10.0 keys the city on it
	int defenderTeam = 1;
	int attackerTeam = 0;
	int northTeam = attackerTeam;
	int southTeam = defenderTeam;
	spawnSwitch = 1;                      // team 1 south
	if (defenderBank == 1)
	{
		northTeam = defenderTeam;
		southTeam = attackerTeam;
		spawnSwitch = 0;                  // team 1 north
	}
	int defenderCount = rmGetNumberPlayersOnTeam(defenderTeam);
	int attackerCount = rmGetNumberPlayersOnTeam(attackerTeam);
	zpGetTeamPlayer(1, defenderTeam);
	int firstDefender = g_zpTeamPlayerResult;
	zpGetTeamPlayer(2, defenderTeam);
	int secondDefender = g_zpTeamPlayerResult;
	zpGetTeamPlayer(3, defenderTeam);
	int thirdDefender = g_zpTeamPlayerResult;
	zpGetTeamPlayer(4, defenderTeam);
	int fourthDefender = g_zpTeamPlayerResult;
	zpGetTeamPlayer(5, defenderTeam);
	int fifthDefender = g_zpTeamPlayerResult;
	zpGetTeamPlayer(6, defenderTeam);
	int sixthDefender = g_zpTeamPlayerResult;
	zpGetTeamPlayer(7, defenderTeam);
	int seventhDefender = g_zpTeamPlayerResult;
	zpGetTeamPlayer(1, attackerTeam);
	int firstAttacker = g_zpTeamPlayerResult;
	zpGetTeamPlayer(2, attackerTeam);
	int secondAttacker = g_zpTeamPlayerResult;
	zpGetTeamPlayer(3, attackerTeam);
	int thirdAttacker = g_zpTeamPlayerResult;
	zpGetTeamPlayer(4, attackerTeam);
	int fourthAttacker = g_zpTeamPlayerResult;
	zpGetTeamPlayer(5, attackerTeam);
	int fifthAttacker = g_zpTeamPlayerResult;
	zpGetTeamPlayer(6, attackerTeam);
	int sixthAttacker = g_zpTeamPlayerResult;
	zpGetTeamPlayer(7, attackerTeam);
	int seventhAttacker = g_zpTeamPlayerResult;
	// One vs. All (zpflorence.xs 174-177): seven on one side
	int oneVsAll = 0;
	if (defenderCount >= 7 || attackerCount >= 7)
		oneVsAll = 1;
	rmEchoInfo("LONDON roles: spawnSwitch " + spawnSwitch + " defenderBank " + defenderBank + " defender team " + defenderTeam + " x" + defenderCount + " defenders " + firstDefender + " " + secondDefender + " " + thirdDefender + " " + fourthDefender + " " + fifthDefender + " " + sixthDefender + " " + seventhDefender);
	rmEchoInfo("LONDON roles: attacker team " + attackerTeam + " x" + attackerCount + " attackers " + firstAttacker + " " + secondAttacker + " " + thirdAttacker + " " + fourthAttacker + " " + fifthAttacker + " " + sixthAttacker + " " + seventhAttacker + " oneVsAll " + oneVsAll);


	rmSetStatusText("",0.10);

	// ---- 1. THE NAUTICAL LANE FIRST (law 1: before the river; user 2026-09-21, Paris's gate order: before the land
	// route too - see 2 / 3.5 / 3.9), zpvenicecity's water_trail, Venice's fake stopper docked
	// on it (zpSPCWaterSpawnPoint at waypoint 0.5, AllowOverlap, min / max 0: "without it the islands don't spawn"),
	// then one docked controller per leg - their read-back z is the only z this map trusts from here on
	float zRiver = zRiverAsk;   // asked; the real centre is measured below from the lane's legs
	float xRoad = roadAsk;      // the road's x is AUTHORED from here on (Paris: gates at fixed coordinates, the road built through them in 3.9)
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

	// ---- 2. THE LAND ROUTE, DEFINED AND NOT YET BUILT (Paris's gate order, zpparis.xs 309-350: the gates go down at
	// fixed coordinates first, the road is built through them afterwards - a gate placed on a built road fails, as the
	// park's path blocks did on 2026-09-21). x = the asked line roadAsk = xRoad, the coordinate every placement uses;
	// the real x is read back in 3.9 for the census only.
	int tradeRouteID = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteID, roadAsk, 0.0);
	rmAddTradeRouteWaypoint(tradeRouteID, roadAsk, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID, roadAsk, 1.0);

	rmSetStatusText("",0.20);

	// ---- 3. THE GRID, from the asked road line and the real walls (nothing is placed here) ----------
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
	// the reserved columns 5-7 (extraColumns): grid locations only - no cityCell, no grouping, the quay paints them
	int col5 = colFirstTiles + colPitchTiles * 4;
	int col6 = colFirstTiles + colPitchTiles * 5;
	int col7 = colFirstTiles + colPitchTiles * 6;
	float locZs5 = wallS-rmZTilesToFraction(col5);
	float locZs6 = wallS-rmZTilesToFraction(col6);
	float locZs7 = wallS-rmZTilesToFraction(col7);
	float locZn5 = wallN+rmZTilesToFraction(col5);
	float locZn6 = wallN+rmZTilesToFraction(col6);
	float locZn7 = wallN+rmZTilesToFraction(col7);
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

	// ---- 3.5 THE GATES, BEFORE THE ROAD (user 2026-09-21, Paris's order zpparis.xs 309-350): the wall gates the
	// road will pass go down now at fixed coordinates, and the road is built through them in 3.9. (London Bridge
	// tried the same and did not spawn - it is back in 6, after the river, with socket placeholders.)
	// THE OUTER WALLS - Florence's system (zpflorence.xs 406-424 the gate segments at 0.2 / 0.5 / 0.8; the Italian
	// Cliff hills between them are 12.5). Three gate segments per bank on the city's outer edge: over the land route,
	// at the centre, and mirroring the route about the centre. The export's gate sits at its centre (SPCFortGate at
	// x -0.2 m; London's clones of IT_wall_*_player), so a segment centred on the road line puts its gate on the road.
	// The south bank's line faces -z (the SE export), the north bank's +z (the NW export); each bank's walls belong
	// to its team's first player - Florence gives them to firstDefender / firstAttacker - gaia in any other lobby
	// (Istanbul's fallback). Segment centre wallOutTiles beyond the last column's outer edge: the wall line inside the
	// export is 4 tiles toward the city, so the line stands 4 tiles out and 4.5 tiles off the player blocks (Florence:
	// 2 and 4.5).
	int wallOutTiles = 8;
	int wallGateS = rmCreateGrouping("wall se", "EU_SPC_London_Wall_SE_01");   // IT_wall_se_player without the Florentian flags, London's passable city ground
	rmSetGroupingMinDistance(wallGateS, 0.00);
	rmSetGroupingMaxDistance(wallGateS, 0.00);
	rmAddGroupingToClass(wallGateS, rmClassID("classBlock"));
	int wallGateN = rmCreateGrouping("wall nw", "EU_SPC_London_Wall_NW_01");   // IT_wall_nw_player without the Roman flags, the same ground
	rmSetGroupingMinDistance(wallGateN, 0.00);
	rmSetGroupingMaxDistance(wallGateN, 0.00);
	rmAddGroupingToClass(wallGateN, rmClassID("classBlock"));
	int wallOwnerS = firstAttacker;
	int wallOwnerN = firstDefender;
	if (defenderBank == 0)
	{
		wallOwnerS = firstDefender;
		wallOwnerN = firstAttacker;
	}
	if (wallOwnerS < 0) wallOwnerS = 0;
	if (wallOwnerN < 0) wallOwnerN = 0;
	float wallZS = wallS - rmZTilesToFraction(cityDepthTiles + wallOutTiles);
	float wallZN = wallN + rmZTilesToFraction(cityDepthTiles + wallOutTiles);
	float xGateMirror = 1.0 - xRoad;
	rmPlaceGroupingAtLoc(wallGateS, wallOwnerS, xRoad, wallZS);
	rmPlaceGroupingAtLoc(wallGateS, wallOwnerS, 0.5, wallZS);
	rmPlaceGroupingAtLoc(wallGateS, wallOwnerS, xGateMirror, wallZS);
	rmPlaceGroupingAtLoc(wallGateN, wallOwnerN, xRoad, wallZN);
	rmPlaceGroupingAtLoc(wallGateN, wallOwnerN, 0.5, wallZN);
	rmPlaceGroupingAtLoc(wallGateN, wallOwnerN, xGateMirror, wallZN);
	rmEchoInfo("LONDON walls: gates at x " + rmXFractionToMeters(xRoad) + " / 180 / " + rmXFractionToMeters(xGateMirror) + " m, lines at z " + rmZFractionToMeters(wallZS) + " / " + rmZFractionToMeters(wallZN) + " m, owners " + wallOwnerS + " / " + wallOwnerN);


	// ---- 3.9 THE LAND ROUTE BUILT through the gates; the real x read back from two docked controllers for the
	// census (it is NOT used - every placement sits on the asked line; a straight three-waypoint route should not
	// drift), then the one socket, docked on London Bridge at the crossing
	rmBuildTradeRoute(tradeRouteID, "dirt");
	routePoint(tradeRouteID, 0.25);
	float road25X = gRealX;
	routePoint(tradeRouteID, 0.75);
	float road75X = gRealX;
	float xRoadReal = (road25X + road75X) * 0.5;
	rmEchoInfo("LONDON road x: asked " + roadAsk + " -> real " + xRoadReal + " (placements use the asked line)");
	routeSocket(tradeRouteID, xRoad, zRiver);   // the one socket: on London Bridge, at the crossing

	// ---- 4. THE RIVER (rect-map rule: river z is read in size_x units -> true z metres / sizeX); after the road
	// (law 1) ----------------------------------------------------------------------------------------------
	int riverMain = rmRiverCreate(-1, "ZP London River", 4, 4, riverRadius, riverRadius);   // data/waterbodies2.xml: ZP Paris River's clone with the Thames colours (user 2026-09-18)
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

	// ---- 6. LONDON BRIDGE (law 2): deck on the road, arches over the river; deck height 4.949 - back here after the
	// river and the posts (2026-09-21: placed before the road with baked gates it did not spawn; the walls did). Its two
	// landing spots carry zpInvisibleGateSocket placeholders (the export's, in place of the old zpSPCWaterSpawnPoint)
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

	// ---- 8. THE HARBOUR GUARDS: one LAND nugget per harbour, the vanilla European trade-route post guard (law 7 rules
	// the water out) - nuggets.xml difficulty 101 = ypNuggetTradingPost + four deGuardianMusketeer, zpelbe.xs's form -
	// defined first, spawned after, on the quay harbourGuardInM inside the bank's wall line at the harbour's x.
	// The post is released when no guardian is left around it (13.2, "Units in Area" on the post - the nugget's own id
	// is not a safe target). The asked spots and the raw rmGetUnitPlaced ids are echoed for the census.
	int harbourN1GuardDef = landNuggetDef("harbour guard north 1", harbourGuardDifficulty, harbourGuardSearchM);
	int harbourN2GuardDef = landNuggetDef("harbour guard north 2", harbourGuardDifficulty, harbourGuardSearchM);
	int harbourS1GuardDef = landNuggetDef("harbour guard south 1", harbourGuardDifficulty, harbourGuardSearchM);
	int harbourS2GuardDef = landNuggetDef("harbour guard south 2", harbourGuardDifficulty, harbourGuardSearchM);
	float harbourN1GuardX = harbourN1X;   float harbourN1GuardZ = wallN + rmZMetersToFraction(harbourGuardInM);
	float harbourN2GuardX = harbourN2X;   float harbourN2GuardZ = wallN + rmZMetersToFraction(harbourGuardInM);
	float harbourS1GuardX = harbourS1X;   float harbourS1GuardZ = wallS - rmZMetersToFraction(harbourGuardInM);
	float harbourS2GuardX = harbourS2X;   float harbourS2GuardZ = wallS - rmZMetersToFraction(harbourGuardInM);
	rmEchoInfo("LONDON guard spots asked (m): N1 " + rmXFractionToMeters(harbourN1GuardX) + "," + rmZFractionToMeters(harbourN1GuardZ) + " N2 " + rmXFractionToMeters(harbourN2GuardX) + "," + rmZFractionToMeters(harbourN2GuardZ) + " S1 " + rmXFractionToMeters(harbourS1GuardX) + "," + rmZFractionToMeters(harbourS1GuardZ) + " S2 " + rmXFractionToMeters(harbourS2GuardX) + "," + rmZFractionToMeters(harbourS2GuardZ));
	rmPlaceObjectDefAtLoc(harbourN1GuardDef, 0, harbourN1GuardX, harbourN1GuardZ);
	rmPlaceObjectDefAtLoc(harbourN2GuardDef, 0, harbourN2GuardX, harbourN2GuardZ);
	rmPlaceObjectDefAtLoc(harbourS1GuardDef, 0, harbourS1GuardX, harbourS1GuardZ);
	rmPlaceObjectDefAtLoc(harbourS2GuardDef, 0, harbourS2GuardX, harbourS2GuardZ);

	// ---- 9. CITY FLOOR: one straight quay per bank (wall line -> column 4's outer edge), streets + the promenade
	// band (Paris's two quay textures), countryside
	quaySegment(0.0, wallS - rmZTilesToFraction(cityDepthTiles), 1.0, wallS, 0.7, wallS, -1.0, promenadePaintM);
	quaySegment(0.0, wallN, 1.0, wallN + rmZTilesToFraction(cityDepthTiles), 0.7, wallN, 1.0, promenadePaintM);
	countryside("countryside S", zRiver-rmZTilesToFraction(130 + colPitchTiles * extraColumns / 2), avoidPlateauShort);   // 130 tiles on the 573 frame + half the reserved depth = the same 26.5 m off the edge
	countryside("countryside N", zRiver+rmZTilesToFraction(130 + colPitchTiles * extraColumns / 2), avoidPlateauShort);

	// ---- 9.5 THE WALL TERRAIN, after the countryside (Florence 720-736: the wall exports' ground again, as terrain-
	// only twins placed at the same six spots, so the countryside mix painted over the footprints in 9 gives way to
	// the walls' own ground; user 2026-09-21). London's clones of IT_wall_*_terrain_player carry the passable city
	// ground and the export's single zpSPCWaterSpawnPoint, placed as Florence places them (gaia).
	int wallTerrainS = rmCreateGrouping("wall se terrain", "EU_SPC_London_Wall_SE_Terrain_01");
	rmSetGroupingMinDistance(wallTerrainS, 0.00);
	rmSetGroupingMaxDistance(wallTerrainS, 0.00);
	rmAddGroupingToClass(wallTerrainS, rmClassID("classBlock"));
	int wallTerrainN = rmCreateGrouping("wall nw terrain", "EU_SPC_London_Wall_NW_Terrain_01");
	rmSetGroupingMinDistance(wallTerrainN, 0.00);
	rmSetGroupingMaxDistance(wallTerrainN, 0.00);
	rmAddGroupingToClass(wallTerrainN, rmClassID("classBlock"));
	rmPlaceGroupingAtLoc(wallTerrainS, 0, xRoad, wallZS);
	rmPlaceGroupingAtLoc(wallTerrainS, 0, 0.5, wallZS);
	rmPlaceGroupingAtLoc(wallTerrainS, 0, xGateMirror, wallZS);
	rmPlaceGroupingAtLoc(wallTerrainN, 0, xRoad, wallZN);
	rmPlaceGroupingAtLoc(wallTerrainN, 0, 0.5, wallZN);
	rmPlaceGroupingAtLoc(wallTerrainN, 0, xGateMirror, wallZN);

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
	int blockTrade = cityBlock("trade block", "EU_SPC_Block_Trade_02");               // London's variant of the 2024 trade block: units AND terrain turned a quarter (x,z -> z,-x) so the socket faces +x = the road from row 1 (user 2026-09-19; the shared original faces +z)
	// the Figma's fixed blocks, one per bank: Park, Menagerie (nugget 98), Native Jewish, Factory (nugget 299),
	// Construction (Paris's "Empty Blocks") at the bridge landing where a random cell sometimes stayed empty
	int blockPark = cityBlock("park", "EU_House_Block_Park");
	int blockMenagerie = cityBlock("menagerie", "EU_Resource_Block_Menagerie");
	int blockJewish = cityBlock("jewish natives", "EU_Natives_Block_Jewish");
	int blockFactory = cityBlock("factory", "EU_Resource_Block_All1");
	int blockConstruction = cityBlock("Construction", "EU_SPC_Block_Constr");
	// Paris's resource buildings by zone: Centre = Market, Bank, Embassy; Outer = Gold Smelter; Suburbs = the Cherry
	// Orchard block (Food5 = Paris's Food2 with its Vineyards as Cherry Orchards - user 2026-09-21; it replaced Paris's
	// Food1 mill, which had taken the Destilery's place on 2026-09-18), Warehouse; Paris's Forester stays out of the city
	int blockMarket = cityBlock("market", "EU_Resource_Block_All2");
	int blockBank = cityBlock("bank", "EU_Resource_Block_Gold1");
	int blockEmbassy = cityBlock("Native Embassy", "EU_House_Block_Embassy");
	int blockGoldSmelter = cityBlock("Gold Smelter", "EU_Resource_Block_Gold2");
	int blockMill = cityBlock("Cherry Orchard", "EU_Resource_Block_Food5");
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

	// ---- 10.0 THE LANDMARK COIN (user 2026-09-21): the DEFENDERS' city is Minster + Parliament, the ATTACKERS'
	// St Paul + the House of Stuart, on whichever bank the coin says - 0.5 keys the roles on it. Each natives block
	// keeps its own 2 x 2 (rows 3-4 x cols 1-2) with the Park and the Menagerie, and exports are never rotated (house
	// rule), so a block faces the same way in world space on either bank:
	//   STUART (30 x 15 tiles = rows 3-4 x one column): the palace faces -z - socket, fountains and flag are its -z
	//   forecourt - so the Park sits on its -z side and the Menagerie behind the Park: south bank Stuart col 1, Park
	//   row 3 col 2, Menagerie row 4 col 2; north bank Stuart col 2, Park row 3 col 1, Menagerie row 4 col 1.
	//   PARLIAMENT (15 x 30 = row 3 x cols 1-2, the socket facing -x): the Park (col 1) and the Menagerie (col 2)
	//   on its row-4 side on either bank - x is not mirrored between the banks.
	//   ST PAUL / MINSTER (32 x 32, the basilica centred, facing -z): the 2-column centre of rows 1-2, either bank.
	// defenderBank is rolled in 0.5 (0 = the south bank (wallS), 1 = the north bank (wallN)); locations by LANDMARK:
	// defenderBank 0 = Minster + Parliament south (Parliament layout), St Paul + Stuart north (Stuart's north layout)
	float locZMinster = locZs12;         float locZStPaul = locZn12;
	float locZParliament = locZs12;      float locZStuart = locZn2;         // Stuart north: col 2, its forecourt (-z) toward the Park in col 1
	float locZParliamentPark = locZs1;   float locZStuartPark = locZn1;
	float locZsMenagerie = locZs2;       float locZnMenagerie = locZn1;     // per BANK: the S / N instance handles feed the triggers
	if (defenderBank == 1)
	{
		locZMinster = locZn12;           locZStPaul = locZs12;
		locZParliament = locZn12;        locZStuart = locZs1;              // Stuart south: col 1, the Park in col 2
		locZParliamentPark = locZn1;     locZStuartPark = locZs2;
		locZsMenagerie = locZs2;         locZnMenagerie = locZn2;
	}
	rmEchoInfo("LONDON landmarks: defenderBank " + defenderBank + " (0 south, 1 north) - Minster + Parliament there (team 1), St Paul + Stuart opposite (team 0)");

	// ---- 10.1 fixed doubles, by the coin: St Paul / Minster rows 1-2 x cols 1-2, Stuart rows 3-4 x one column,
	// Parliament row 3 x cols 1-2, the Towers rows 7-8 x cols 1-2 at the water on their own banks (instances: the
	// triggers need the Towers' ids). Each Tower's handle (Istanbul's palace) is the EXPORT's own units, nothing is
	// spawned by the script: the gate treasure each export carries (NuggetDroppedWood, Tower_01 (-0.99, -13.4) /
	// Tower_02 (0.99, 13.4)) takes nuggetmods zpNuggetTowerOfLondon 605 (nuggetunit zpNuggetInvisible, ten Redcoats)
	// through the latch set BEFORE both instances (Istanbul's guild idiom; no grouping between them bakes a nugget).
	// Neither export carries a capturable flag: the flag-driven conversion family (13.3) is built only when a flag id
	// exists. Call order = unit ids (header law): unchanged, only the z of the coin-keyed calls moves.
	rmPlaceGroupingAtLoc(blockStPaul, 0, locX12, locZStPaul);
	rmPlaceGroupingAtLoc(blockStuart, 0, locX34, locZStuart);
	rmSetNuggetDifficulty(605, 605);
	int towerSInst = rmPlaceGroupingInstanceAtLoc(blockTowerS, locX78, locZs12, 0);
	rmPlaceGroupingAtLoc(blockMinster, 0, locX12, locZMinster);
	rmPlaceGroupingAtLoc(blockParliament, 0, locX3, locZParliament);
	int towerNInst = rmPlaceGroupingInstanceAtLoc(blockTowerN, locX78, locZn12, 0);

	// ---- 10.2 fixed singles: trade row 1 col 3, Construction row 0 col 1, the Parks and the Menageries by the coin
	// (10.0: Stuart's Park row 3 beside its forecourt, Parliament's row 4 col 1; the Menageries row 4, col 2 except
	// on a north Stuart bank, col 1), Native Jewish row 6 col 3, Factory row 0
	// col 2 - nugget latches as Paris
	rmPlaceGroupingAtLoc(blockTrade, 0, locX1, locZs3);
	rmPlaceGroupingAtLoc(blockTrade, 0, locX1, locZn3);
	rmPlaceGroupingAtLoc(blockConstruction, 0, locX0, locZs1);
	rmPlaceGroupingAtLoc(blockConstruction, 0, locX0, locZn1);
	rmPlaceGroupingAtLoc(blockPark, 0, locX3, locZStuartPark);       // Stuart's Park, on the palace's forecourt side
	rmPlaceGroupingAtLoc(blockPark, 0, locX4, locZParliamentPark);   // Parliament's Park, on its row-4 side
	rmSetNuggetDifficulty(98, 98);
	int menagerieSInst = rmPlaceGroupingInstanceAtLoc(blockMenagerie, locX4, locZsMenagerie, 0);
	int menagerieNInst = rmPlaceGroupingInstanceAtLoc(blockMenagerie, locX4, locZnMenagerie, 0);
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

	// ---- 10.7 THE RESERVED COLUMNS' FIXED BLOCKS (user 2026-09-20), placed after every id-sensitive placement of
	// section 10 (ids are positional - header law): the big park EU_SPC_Park_big (the user's export, 32 x 32 tiles =
	// a 2 x 2 block) on rows 00-0 x cols 5-6 at the +x end of each bank; behind it, in column 7, one house block on
	// row 00 and the Food4 mill (berry bushes, user 2026-09-21) on row 0 under Paris's resource latch 195. Every other
	// cell of cols 5-7 stays empty.
	int blockParkBig = cityBlock("park big", "EU_SPC_Park_big");
	int blockMillFood4 = cityBlock("Mill Food4", "EU_Resource_Block_Food4");
	// the park's road edge sits 1 m further from the trade route than row 0's (user 2026-09-21: placed over the
	// route, the park's path blocks made the whole grouping fail silently; 1 m off the route and it places)
	float parkOffRoadM = 1.0;
	float locX000 = (locX00 + locX0) * 0.5 + rmXMetersToFraction(parkOffRoadM);   // the 2-row centre behind the road (34 + 30 = 64 m, the export's 64 m) + 1 m
	float locZs56 = wallS-rmZTilesToFraction(col5+col6)*0.5;         // the 2-column centre: cols 5-6 span the 64 m from column 4's edge
	float locZn56 = wallN+rmZTilesToFraction(col5+col6)*0.5;
	// the park's baked treasure (the export's NuggetDroppedWood placeholder, user 2026-09-21) is the Royal Huntsman on
	// his rock among the wolves - nuggetmods zpRockRoyalHuntsman 607 - on both banks, through the latch set before
	// the two placements (the guild idiom); the mill's 195 latch follows
	rmSetNuggetDifficulty(607, 607);
	rmPlaceGroupingAtLoc(blockParkBig, 0, locX000, locZs56);
	rmPlaceGroupingAtLoc(blockParkBig, 0, locX000, locZn56);
	rmPlaceGroupingAtLoc(blockHouse1, 0, locX00, locZs7);
	rmPlaceGroupingAtLoc(blockHouse1, 0, locX00, locZn7);
	rmSetNuggetDifficulty(195, 195);
	rmPlaceGroupingAtLoc(blockMillFood4, 0, locX0, locZs7);
	rmPlaceGroupingAtLoc(blockMillFood4, 0, locX0, locZn7);

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

	// ---- 12. PLAYERS (12.1 ROLES: resolved in 0.5, before the gates) ----------------------------------
	// ---- 12.2 SEATS BY ROLE (user 2026-09-21, the Figma strip): each team's players sit on THEIR bank's reserved
	// columns 5-7 in the user's EU_SPC_Player_London block (30 x 45 tiles = 2 rows x 3 columns, the Town Center at its
	// centre), one block per 2-row pair, cumulative by head-count: the first player rows 7-8 (BLUE, the far end), the
	// second rows 3-4 (RED), the third rows 5-6 (YELLOW), the fourth rows 1-2 (PURPLE, at the road). Defenders on the
	// defender bank (10.0's coin), attackers on the other. Teams of five and more: ON HOLD (user) - such lobbies, and
	// any non-2-team lobby, keep the interim line placement in 12.3 with Paris's command posts.
	int blockPlayerLondon = cityBlock("player london", "EU_SPC_Player_London");
	float locX56 = (locX5 + locX6) * 0.5;
	float locZdSeat = locZs6;       // the 3-column centre of cols 5-7
	float locZaSeat = locZn6;
	if (defenderBank == 1)
	{
		locZdSeat = locZn6;
		locZaSeat = locZs6;
	}
	int seatsByRole = 0;
	if (cNumberTeams == 2 && defenderCount <= 4 && attackerCount <= 4)
		seatsByRole = 1;
	if (seatsByRole == 1)
	{
		rmPlacePlayer(firstDefender, locX78, locZdSeat);
		if (defenderCount >= 2) rmPlacePlayer(secondDefender, locX34, locZdSeat);
		if (defenderCount >= 3) rmPlacePlayer(thirdDefender, locX56, locZdSeat);
		if (defenderCount >= 4) rmPlacePlayer(fourthDefender, locX12, locZdSeat);
		rmPlacePlayer(firstAttacker, locX78, locZaSeat);
		if (attackerCount >= 2) rmPlacePlayer(secondAttacker, locX34, locZaSeat);
		if (attackerCount >= 3) rmPlacePlayer(thirdAttacker, locX56, locZaSeat);
		if (attackerCount >= 4) rmPlacePlayer(fourthAttacker, locX12, locZaSeat);
	}
	rmEchoInfo("LONDON seats: seatsByRole " + seatsByRole + " defenders at z " + rmZFractionToMeters(locZdSeat) + " m, attackers at z " + rmZFractionToMeters(locZaSeat) + " m");

	// ---- 12.3 INTERIM PLACEMENT (Paris's placement transposed onto the z axis), spawnSwitch set in 0.5 from the
	// landmark coin (team 1 on the defenders' bank) - only when 12.2 seats nobody --------------------------------
	// z anchored in METRES from the map edge: 36 m for every player count = 24 m beyond the last column's outer edge
	// (the strip is 60.5 m; Paris's 0.07 / 0.10 fractions of the old frame were 40 / 57 m). Floats only - law 4.
	float zPlEdgeM = 36.0;
	float zPlNear = rmZMetersToFraction(zPlEdgeM);
	float zPlLine = rmZMetersToFraction(zPlEdgeM);
	float zPlNearFar = 1.0 - zPlNear;
	float zPlLineFar = 1.0 - zPlLine;
	if (seatsByRole == 0 && cNumberTeams == 2){
		if (spawnSwitch ==0){
			if (PlayerNum == 2)
			{
				rmPlacePlayer(1, 0.35, zPlNear);
				rmPlacePlayer(2, 0.65, zPlNearFar);
			}
			if (PlayerNum == 3 || PlayerNum == 4)
			{
				rmSetPlacementTeam(0);
				rmPlacePlayersLine(0.23, zPlLine, 0.73, zPlLine, 0, 0);
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.73, zPlLineFar, 0.23, zPlLineFar, 0, 0);
			}
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.10, zPlLine, 0.75, zPlLine, 0, 0);
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.90, zPlLineFar, 0.25, zPlLineFar, 0, 0);
		}
		else{
			if (PlayerNum == 2)
			{
				rmPlacePlayer(2, 0.35, zPlNear);
				rmPlacePlayer(1, 0.65, zPlNearFar);
			}
			if (PlayerNum == 3 || PlayerNum == 4)
			{
				rmSetPlacementTeam(1);
				rmPlacePlayersLine(0.23, zPlLine, 0.73, zPlLine, 0, 0);
				rmSetPlacementTeam(0);
				rmPlacePlayersLine(0.73, zPlLineFar, 0.23, zPlLineFar, 0, 0);
			}
			rmSetPlacementTeam(1);
			rmPlacePlayersLine(0.10, zPlLine, 0.75, zPlLine, 0, 0);
			rmSetPlacementTeam(0);
			rmPlacePlayersLine(0.90, zPlLineFar, 0.25, zPlLineFar, 0, 0);
		}
	}
	if (seatsByRole == 0 && cNumberTeams != 2){
		rmPlacePlayersLine(0.10, zPlLine, 0.75, zPlLine, 0, 0);
	}

	int playerStart = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(playerStart, 7.0);
	rmSetObjectDefMaxDistance(playerStart, 12.0);
	int aiStartUrban = rmCreateObjectDef("is city map");
	rmAddObjectDefItem(aiStartUrban, "zpAIStartUrbanMap", 1, 0.0);

	// the seated player's kit is the block itself (Istanbul's start block: the export's own Town Center, owner = the
	// player); its baked treasure is a LEVEL 1 nugget (user 2026-09-21) - the latch Istanbul (2506) and Florence (1266)
	// set before their start blocks; nuggetmods picks the level-1 entry, the export's placeholder proto is not what
	// spawns. The unseated player keeps Paris's command post.
	rmSetNuggetDifficulty(1, 1);
	for(i=1; < cNumberNonGaiaPlayers + 1) {
		int id=rmCreateArea("Player"+i);
		rmSetPlayerArea(i, id);
		if (seatsByRole == 1)
		{
			rmPlaceGroupingAtLoc(blockPlayerLondon, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		}
		else
		{
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
		}
		rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		rmPlaceObjectDefAtLoc(aiStartUrban, i, 0.5, 0.5);
	}
	// starting hunt / gold / berries and every map resource: deliberately absent at the layout stage

	// ---- 12.5 THE WALL HILLS - Florence's wallCliffs (zpflorence.xs 1485-1526) between the gate segments placed in
	// 3.5: Italian Cliff, one per gap, straddling the wall line 3 tiles inside the segment centre.
	// the hills: one per gap - edge to the road segment, road to centre, centre to mirror, mirror to edge (a segment
	// is 37 tiles = 74 m wide, half of it wallHalfX). London's gaps are not Florence's (user 2026-09-21): the two
	// EDGE gaps are 43.8 m (road 279.2 m + 37 -> the x = 1 edge; its mirror), the two INNER gaps 25.2 m, so the
	// edge hills are big enough to reach the map edge and the inner ones small enough to sit between two segments
	// (a hill of N tiles is ~ a disc of diameter 2 * sqrt(4 N / pi) m: 360 -> 43 m, 200 -> 32 m; Florence's 240 -> 35 m).
	int hillEdgeTiles = 360;    // user 2026-09-21: halfway between Florence's 240 and the first 480 - the 480 / 160 contrast was too big
	int hillInnerTiles = 200;
	float wallHalfX = rmXMetersToFraction(37.0);
	float hillX1 = (1.0 + xRoad + wallHalfX) * 0.5;
	float hillX2 = (xRoad + 0.5) * 0.5;
	float hillX3 = (0.5 + xGateMirror) * 0.5;
	float hillX4 = (xGateMirror - wallHalfX) * 0.5;
	float hillZS = wallS - rmZTilesToFraction(cityDepthTiles + wallOutTiles - 3);
	float hillZN = wallN + rmZTilesToFraction(cityDepthTiles + wallOutTiles - 3);
	wallCliff("wall hill S1", hillX1, hillZS, hillEdgeTiles, avoidPlateauShort, avoidTradeRouteWall, avoidWall);
	wallCliff("wall hill S2", hillX2, hillZS, hillInnerTiles, avoidPlateauShort, avoidTradeRouteWall, avoidWall);
	wallCliff("wall hill S3", hillX3, hillZS, hillInnerTiles, avoidPlateauShort, avoidTradeRouteWall, avoidWall);
	wallCliff("wall hill S4", hillX4, hillZS, hillEdgeTiles, avoidPlateauShort, avoidTradeRouteWall, avoidWall);
	wallCliff("wall hill N1", hillX1, hillZN, hillEdgeTiles, avoidPlateauShort, avoidTradeRouteWall, avoidWall);
	wallCliff("wall hill N2", hillX2, hillZN, hillInnerTiles, avoidPlateauShort, avoidTradeRouteWall, avoidWall);
	wallCliff("wall hill N3", hillX3, hillZN, hillInnerTiles, avoidPlateauShort, avoidTradeRouteWall, avoidWall);
	wallCliff("wall hill N4", hillX4, hillZN, hillEdgeTiles, avoidPlateauShort, avoidTradeRouteWall, avoidWall);

	// ============================================================================================
	// 13. TRIGGERS, all at the end (Paris / Istanbul). Ids: object defs = rmGetUnitPlaced + instanceIdShiftIndividual,
	//     grouping instances = rmGetGroupingInstanceUnitByType + instanceIdShift; a baked nugget is queried by its
	//     nuggetmods <nuggetunit>, never by the authored placeholder (Istanbul).
	// ============================================================================================
	int harbourN1PostUnit = rmGetUnitPlaced(harbourN1PostDef, 0) + instanceIdShiftIndividual;
	int harbourN2PostUnit = rmGetUnitPlaced(harbourN2PostDef, 0) + instanceIdShiftIndividual;
	int harbourS1PostUnit = rmGetUnitPlaced(harbourS1PostDef, 0) + instanceIdShiftIndividual;
	int harbourS2PostUnit = rmGetUnitPlaced(harbourS2PostDef, 0) + instanceIdShiftIndividual;
	int harbourN1GuardUnit = rmGetUnitPlaced(harbourN1GuardDef, 0);   // raw placeholder ids, echoed for the census only (no trigger targets them)
	int harbourN2GuardUnit = rmGetUnitPlaced(harbourN2GuardDef, 0);
	int harbourS1GuardUnit = rmGetUnitPlaced(harbourS1GuardDef, 0);
	int harbourS2GuardUnit = rmGetUnitPlaced(harbourS2GuardDef, 0);
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

	// ---- 13.2 releases: harbours when their guardians are gone (by area around the post); Menageries and Factories
	// when their baked nugget is collectable
	releaseWhenClear("Harbour N1 Convert ON", harbourN1PostUnit, harbourGuardType, harbourGuardReachM);
	releaseWhenClear("Harbour N2 Convert ON", harbourN2PostUnit, harbourGuardType, harbourGuardReachM);
	releaseWhenClear("Harbour S1 Convert ON", harbourS1PostUnit, harbourGuardType, harbourGuardReachM);
	releaseWhenClear("Harbour S2 Convert ON", harbourS2PostUnit, harbourGuardType, harbourGuardReachM);
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


	// ---- 14. Parliamentarians (Orthodox pattern): starting techs, the leader choice, the AI roll ----------------
	// 14.1 starting techs for everybody: London setup (Military Camp) + no standard revolutions (Paris idiom)
	rmCreateTrigger("LondonStartingTechs");
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpLondonSetup");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpForbidRevolutions");
		rmSetTriggerEffectParamInt("Status", 2);
	}
	// the bridge's two zpInvisibleGateSocket placeholders become SPCFortGate the moment the game starts: zpConverGate
	// (techtreemods, shadow: turns every zpInvisibleGateSocket into an SPCFortGate) fired for gaia, the socket's owner -
	// zpcivilwar.xs 1491-1494 does the same in its starting-techs trigger (user 2026-09-21)
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", 0);
	rmSetTriggerEffectParam("TechID", "cTechzpConverGate");
	rmSetTriggerEffectParamInt("Status", 2);
	// gaia flies the London flag and is called City of London (Paris: the Bourbon flag + "City of Paris"); the House of
	// Stuart civ carries the London flag texture in civmods, its Royal Standard lives only on the zpStuartFlag unit
	rmAddTriggerEffect("Player : Override Civilization for Flag");
	rmSetTriggerEffectParamInt("Player", 0);
	rmSetTriggerEffectParam("Civilization", "Stuart");
	rmAddTriggerEffect("Player : Override Civilization Name");
	rmSetTriggerEffectParamInt("Player", 0);
	rmSetTriggerEffectParam("StringID", "503502");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// 14.1a EXTENDED HOUSE OF STUART (zpistanbulb.xs "ExtendedPhanar"): the extension sleeps in the data until a map flips
	// cTechzpExtendedStuart - it drops Highland Charge to a small button at p0 c4 (zpNatStuartHighlandChargeSmall). Always on
	// London, every player. Trigger name without spaces.
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("ExtendedStuart" + k);
		rmAddTriggerCondition("Always");
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpExtendedStuart");
		rmSetTriggerEffectParamInt("Status", 2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// 14.1b the balance / returner family (zpparis.xs "NATIVE POLITICIANS", map-politician-triggers Rule 0): every
	// switcher grants cTechzpBigButtonResearchDecrease so its big button researches instantly - Cheat Returner hands
	// the cost back 10 ms later; the two Italian triggers repay the villager / gondola shipments the faction big
	// buttons zero out. Priority 2 (the switchers are 4), armed only by the switchers' Fire Events.
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("Italian Vilager Balance" + k);
		rmAddTriggerCondition("ZP Player Civilization");
		rmSetTriggerConditionParamInt("Player", k);
		rmSetTriggerConditionParam("Civilization", "DEItalians");
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpItalianSettlerBallance");
		rmSetTriggerEffectParamInt("Status", 2);
		rmSetTriggerPriority(2);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(false);
		rmSetTriggerLoop(false);

		rmCreateTrigger("Italian Gondola Balance" + k);
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID", k);
		rmSetTriggerConditionParam("TechID", "cTechDEHCGondolas");
		rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpItalianGondolaBallance");
		rmSetTriggerEffectParamInt("Status", 2);
		rmSetTriggerPriority(2);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(false);
		rmSetTriggerLoop(false);

		rmCreateTrigger("Cheat Returner" + k);   // Paris: "Speed Always Wins Returner"
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1", 10);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpBigButtonResearchIncrease");
		rmSetTriggerEffectParamInt("Status", 2);
		rmSetTriggerPriority(2);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(false);
		rmSetTriggerLoop(false);
	}

	// 14.1c the Asian civs' consulate switchers (zpparis.xs "Activate Consulate <civ>"): gated on the civ and on
	// cTechzpPickConsulateTechAvailable, they turn that civ's consulate page on, research the pick instantly and
	// fire the returner; the human check below arms them
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("Activate Consulate Japan" + k);
		rmAddTriggerCondition("ZP Player Civilization");
		rmSetTriggerConditionParamInt("Player", k);
		rmSetTriggerConditionParam("Civilization", "Japanese");
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID", "cTechzpPickConsulateTechAvailable");
		rmSetTriggerConditionParamInt("PlayerID", k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpTurnConsulateOnJapanese");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpBigButtonResearchDecrease");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Pick Consulate Tech");
		rmSetTriggerEffectParamInt("Player", k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner" + k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
	}
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("Activate Consulate China" + k);
		rmAddTriggerCondition("ZP Player Civilization");
		rmSetTriggerConditionParamInt("Player", k);
		rmSetTriggerConditionParam("Civilization", "Chinese");
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID", "cTechzpPickConsulateTechAvailable");
		rmSetTriggerConditionParamInt("PlayerID", k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpTurnConsulateOnChinese");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpBigButtonResearchDecrease");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Pick Consulate Tech");
		rmSetTriggerEffectParamInt("Player", k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner" + k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
	}
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("Activate Consulate India" + k);
		rmAddTriggerCondition("ZP Player Civilization");
		rmSetTriggerConditionParamInt("Player", k);
		rmSetTriggerConditionParam("Civilization", "Indians");
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID", "cTechzpPickConsulateTechAvailable");
		rmSetTriggerConditionParamInt("PlayerID", k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpTurnConsulateOnIndian");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpBigButtonResearchDecrease");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Pick Consulate Tech");
		rmSetTriggerEffectParamInt("Player", k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner" + k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
	}
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("Activate Consulate Khmer" + k);
		rmAddTriggerCondition("ZP Player Civilization");
		rmSetTriggerConditionParamInt("Player", k);
		rmSetTriggerConditionParam("Civilization", "Khmers");
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID", "cTechzpPickConsulateTechAvailable");
		rmSetTriggerConditionParamInt("PlayerID", k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpTurnConsulateOnKhmers");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpBigButtonResearchDecrease");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Pick Consulate Tech");
		rmSetTriggerEffectParamInt("Player", k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner" + k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
	}

	// 14.2 the Grand Remonstrance big button -> the Parliament card set -> the pick dialog (Venice "Activate Orthodox")
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("Activate Parliament" + k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID", "cTechzpParliamentRemonstrance");
		rmSetTriggerConditionParamInt("PlayerID", k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpTurnConsulateOffParliament");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpBigButtonResearchDecrease");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Pick Consulate Tech");
		rmSetTriggerEffectParamInt("Player", k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Vilager_Balance" + k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Gondola_Balance" + k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner" + k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
	}
	// 14.3 the Jewish quarter: Star of David big button -> the Jewish card set -> the pick dialog (Versailles "Activate Jewish")
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("Activate Jewish" + k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID", "cTechzpJewishStar");
		rmSetTriggerConditionParamInt("PlayerID", k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpTurnConsulateOffJewish");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpBigButtonResearchDecrease");
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Pick Consulate Tech");
		rmSetTriggerEffectParamInt("Player", k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Vilager_Balance" + k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Gondola_Balance" + k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner" + k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
	}
	// human players get the dialog; the AI rolls a leader instead (14.4)
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("Human Check Plr" + k);
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player", k);
		rmSetTriggerConditionParam("MyBool", "true");
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", k);
		rmSetTriggerEffectParam("TechID", "cTechzpIsPirateMap");   // the mod's map flag, every mod map's human check grants it (Paris)
		rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Japan" + k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_China" + k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_India" + k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Khmer" + k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Parliament" + k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Jewish" + k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}
	// 14.4 AI leader roll (Venice "ZP Pick Orthodox Captain")
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("PickParliamentLeader" + k);
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player", k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerCondition("Tech Status Equals");
		rmSetTriggerConditionParamInt("PlayerID", k);
		rmSetTriggerConditionParamInt("TechID", 586);
		rmSetTriggerConditionParamInt("Status", 2);
		int parliamentLeader = rmRandInt(1, 3);
		if (parliamentLeader == 1)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID", k);
			rmSetTriggerEffectParam("TechID", "cTechzpConsulateParliamentCromwell");
			rmSetTriggerEffectParamInt("Status", 2);
		}
		if (parliamentLeader == 2)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID", k);
			rmSetTriggerEffectParam("TechID", "cTechzpConsulateParliamentInchiquin");
			rmSetTriggerEffectParamInt("Status", 2);
		}
		if (parliamentLeader == 3)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID", k);
			rmSetTriggerEffectParam("TechID", "cTechzpConsulateParliamentMyddelton");
			rmSetTriggerEffectParamInt("Status", 2);
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// 14.5 AI Jewish faction roll (Versailles "ZP Pick Jewish Fraction")
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("PickJewishFraction" + k);
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player", k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerCondition("Tech Status Equals");
		rmSetTriggerConditionParamInt("PlayerID", k);
		rmSetTriggerConditionParamInt("TechID", 586);
		rmSetTriggerConditionParamInt("Status", 2);
		int jewishFraction = rmRandInt(1, 3);
		if (jewishFraction == 1)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID", k);
			rmSetTriggerEffectParam("TechID", "cTechzpConsulateJewishAmericans");
			rmSetTriggerEffectParamInt("Status", 2);
		}
		if (jewishFraction == 2)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID", k);
			rmSetTriggerEffectParam("TechID", "cTechzpConsulateJewishRussians");
			rmSetTriggerEffectParamInt("Status", 2);
		}
		if (jewishFraction == 3)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID", k);
			rmSetTriggerEffectParam("TechID", "cTechzpConsulateJewishGermans");
			rmSetTriggerEffectParamInt("Status", 2);
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}



	// ---- 15. the Commonwealth (Paris / Independence War soft revolution): any Parliament leader turns the player's flag
	// and name into the British Commonwealth (zpRevCommonwealth carries the Parliamentarian flag), plays the revolution
	// music and the strategy warning; the message comes from zpCommonwealthRevolutionShadow. No settler transform.
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("Revolution_MusicEnd" + k);
		rmAddTriggerCondition("Timer");
		rmSetTriggerConditionParamInt("Param1", 5);
		rmAddTriggerEffect("Music Play");
		rmSetTriggerPriority(1);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(false);
		rmSetTriggerLoop(false);
	}
	for (k=1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("Flag Cromwell" + k);
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID", k);
		rmSetTriggerConditionParam("TechID", "cTechzpConsulateParliamentCromwell");
		rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Player : Override Civilization for Flag");
		rmSetTriggerEffectParamInt("Player", k);
		rmSetTriggerEffectParam("Civilization", "zpRevCommonwealth");
		rmAddTriggerEffect("Player : Override Civilization Name");
		rmSetTriggerEffectParamInt("Player", k);
		rmSetTriggerEffectParam("StringID", "503531");
		rmAddTriggerEffect("Music Filename");
		rmSetTriggerEffectParam("Music", "ypack\music\strategy\Revolootin.mp3");
		rmSetTriggerEffectParamFloat("Duration", 0.5);
		rmAddTriggerEffect("Sound Timer");
		rmSetTriggerEffectParamInt("Time", 61000);
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd" + k));
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset", "UI_Strategywarning");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		rmCreateTrigger("Flag Inchiquin" + k);
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID", k);
		rmSetTriggerConditionParam("TechID", "cTechzpConsulateParliamentInchiquin");
		rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Player : Override Civilization for Flag");
		rmSetTriggerEffectParamInt("Player", k);
		rmSetTriggerEffectParam("Civilization", "zpRevCommonwealth");
		rmAddTriggerEffect("Player : Override Civilization Name");
		rmSetTriggerEffectParamInt("Player", k);
		rmSetTriggerEffectParam("StringID", "503531");
		rmAddTriggerEffect("Music Filename");
		rmSetTriggerEffectParam("Music", "ypack\music\strategy\Revolootin.mp3");
		rmSetTriggerEffectParamFloat("Duration", 0.5);
		rmAddTriggerEffect("Sound Timer");
		rmSetTriggerEffectParamInt("Time", 61000);
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd" + k));
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset", "UI_Strategywarning");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		rmCreateTrigger("Flag Myddelton" + k);
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID", k);
		rmSetTriggerConditionParam("TechID", "cTechzpConsulateParliamentMyddelton");
		rmSetTriggerConditionParamInt("Status", 2);
		rmAddTriggerEffect("Player : Override Civilization for Flag");
		rmSetTriggerEffectParamInt("Player", k);
		rmSetTriggerEffectParam("Civilization", "zpRevCommonwealth");
		rmAddTriggerEffect("Player : Override Civilization Name");
		rmSetTriggerEffectParamInt("Player", k);
		rmSetTriggerEffectParam("StringID", "503531");
		rmAddTriggerEffect("Music Filename");
		rmSetTriggerEffectParam("Music", "ypack\music\strategy\Revolootin.mp3");
		rmSetTriggerEffectParamFloat("Duration", 0.5);
		rmAddTriggerEffect("Sound Timer");
		rmSetTriggerEffectParamInt("Time", 61000);
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd" + k));
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset", "UI_Strategywarning");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	rmSetStatusText("",0.99);
} // END
