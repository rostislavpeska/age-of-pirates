// ============================================================================
// zpistanbulb.xs  -  Istanbul: two city islands + four floating gun islands
// CANONICAL FILE (repo). Root 000_istanbul.xs / 000_gun_test.xs are copies
// synced from this one after every edit - never edit those directly.
// ----------------------------------------------------------------------------
// HOW THE FLOATING ISLANDS WORK (guide 19.7):
//   The engine cannot place an island on open water. It CAN place a grouping
//   as a "bridge" over a river, and a river needs land. So each gun gets:
//        a small invisible landmass  ->  a river that drowns it  ->  the gun
//   dropped on top. What you see floating is the grouping's own baked terrain
//   (platform 5.5 m, moat 0 m). A zpSPCWaterSpawnPoint docked on a real trade
//   route is mandatory - without it nothing spawns at all.
//
// HOW POSITIONS ARE MEASURED (the Versailles rule - NEVER guess):
//   A trade route does NOT land on the waypoint you ask for; the engine snaps
//   it (measured: asked z=0.543, got z=0.529 - about 4 tiles out). So we place
//   a CONTROLLER on each route, read its REAL position back with
//   rmGetUnitPosition(), and derive every row, island and gun from that.
//   The requested values below are only a starting hint for the engine.
//
// BUILD ORDER IS LOAD-BEARING - do not reshuffle:
//   1. gun scaffolds   (landmasses must exist before any river)
//   2. trade routes + controllers  -> read the REAL lane positions
//   3. gun islands     (river first, then the grouping on top of it)
//   4. the city        (painted LAST, so no river can ever flood it)
//   5. players
//
// ALL TUNABLES ARE IN ONE PLACE: see "TUNABLES" at the top of main().
// Distances are in TILES; 1 tile = 2 m, so on this 600 m map a 1-tile nudge is
// invisible - 3..8 tiles is the range where you actually see a shift.
// XS trap: never write intVar * floatVar, it truncates to 0. Pass ints to
// rmXTilesToFraction() / rmZTilesToFraction() instead.
// ============================================================================


// ----------------------------------------------------------------------------
//  HELPERS
// ----------------------------------------------------------------------------


// The city grid draws block types from this registry one after another,
// wrapping around when it runs out.
int gCityBlocks   = -1;
int gCityBlockIdx = 0;
void cityBlock(float x = 0.0, float z = 0.0)
{
	rmPlaceGroupingAtLoc(xsArrayGetInt(gCityBlocks, gCityBlockIdx), 0, x, z);
	gCityBlockIdx = gCityBlockIdx + 1;
	if (gCityBlockIdx >= xsArrayGetSize(gCityBlocks)) { gCityBlockIdx = 0; }
}

// ---- Paris-style zone placement (0000_paris_dansil.xs, lines 19-45) ------
// gCityLocs holds every free city cell as a vector, grouped into zone index
// ranges. Each zone is shuffled on its own, then a zone grouping list is
// walked into its shuffled slots - so a building always lands in its correct
// district, but never in the same cell twice running.
int gCityLocs       = -1;
int gCityLocsStatus = -1;

void shuffle(int arrayID = -1, int start = -1, int end = -1)
{
	for (int i = end; i > start; i--)
	{
		int j = rmRandInt(start, end);
		vector temp = xsArrayGetVector(arrayID, i);
		xsArraySetVector(arrayID, i, xsArrayGetVector(arrayID, j));
		xsArraySetVector(arrayID, j, temp);
	}
}

void placeGroupings(int groupingsArrayID = -1, int startIndex = -1)
{
	for (i = 0; < xsArrayGetSize(groupingsArrayID))
	{
		int grouping = xsArrayGetInt(groupingsArrayID, i);
		vector loc = xsArrayGetVector(gCityLocs, startIndex + i);
		rmPlaceGroupingAtLoc(grouping, 0, xsVectorGetX(loc), xsVectorGetZ(loc));
		xsArraySetBool(gCityLocsStatus, startIndex + i, true);
	}
}

// Place a grouping in the first free cell within the given index range.
// Returns false when the range has no free cell left. Cells already used by a
// fixed or zone placement are marked in gCityLocsStatus, so nothing overlaps.
bool filler(int groupingID = -1, int startIndex = -1, int endIndex = -1)
{
	for (i = startIndex; <= endIndex)
	{
		bool taken = xsArrayGetBool(gCityLocsStatus, i);
		if (taken) continue;
		vector loc = xsArrayGetVector(gCityLocs, i);
		rmPlaceGroupingAtLoc(groupingID, 0, xsVectorGetX(loc), xsVectorGetZ(loc));
		xsArraySetBool(gCityLocsStatus, i, true);
		return true;
	}

	return false;
}

// ---- Houses: never two of the same side by side --------------------------
// gCityCode carries each cell's grid position as col*100 + row, and is
// shuffled in lockstep with gCityLocs so the two never drift apart.
// The house type is then derived from that position:
//        type = (col + 2*row + offset) mod 6
// A neighbour along x differs by 1, a neighbour along z by 2, so two adjacent
// cells can never land on the same type. offset is rolled per island, which
// slides the whole weave around without breaking the guarantee.
int gCityCode    = -1;
int gHouseBlocks = -1;

void shuffleCells(int start = -1, int end = -1)
{
	for (int i = end; i > start; i--)
	{
		int j = rmRandInt(start, end);
		vector tempLoc = xsArrayGetVector(gCityLocs, i);
		xsArraySetVector(gCityLocs, i, xsArrayGetVector(gCityLocs, j));
		xsArraySetVector(gCityLocs, j, tempLoc);
		int tempCode = xsArrayGetInt(gCityCode, i);
		xsArraySetInt(gCityCode, i, xsArrayGetInt(gCityCode, j));
		xsArraySetInt(gCityCode, j, tempCode);
	}
}

void fillHouses(int startIndex = -1, int endIndex = -1, int offset = 0)
{
	int total = xsArrayGetSize(gHouseBlocks);
	for (i = startIndex; <= endIndex)
	{
		bool taken = xsArrayGetBool(gCityLocsStatus, i);
		if (taken) continue;

		int code = xsArrayGetInt(gCityCode, i);
		int col  = code / 100;
		int row  = code - col * 100;

		int pick = col + row + row + offset;
		// wrap into [0, total) - pick is at most 22 (col 5 + 2*row 12 + offset 5)
		// and total >= 6, so four bounded subtractions always suffice (no while:
		// zero corpus uses in either reference corpus)
		if (pick >= total) pick = pick - total;
		if (pick >= total) pick = pick - total;
		if (pick >= total) pick = pick - total;
		if (pick >= total) pick = pick - total;

		vector loc = xsArrayGetVector(gCityLocs, i);
		rmPlaceGroupingAtLoc(xsArrayGetInt(gHouseBlocks, pick), 0,
			xsVectorGetX(loc), xsVectorGetZ(loc));
		xsArraySetBool(gCityLocsStatus, i, true);
	}
}

// ---- CLIFF MASSES --------------------------------------------------------
// Style shared by every cliff on the map. Set once at the top of main from the
// knobs, so the helper below can reach them (XS functions cannot see locals).
string gCliffType = "Italian Cliff";
string gCliffTypeImpassable = "ZP Italian Impassable";
string gCliffMix  = "italy_grass_dry";
float  gCliffBase = 3.0;
int    gCliffIdx  = 0;

// ONE call builds a whole cliff mass: its land AND its cliff top.
// They are deliberately not separable - this map is water-initialised, so a
// cliff with no land under it silently builds nothing, and land with no cliff
// on top is just a bare island. Keeping them in one function means a cliff
// mass is all-or-nothing.
//   x, z       where it sits, as map fractions (0..1)
//   landTiles  land laid down first. 0 = it already stands on land.
//   size       cliff top area, as a fraction of the map
//   rise       metres it stands above gCliffBase
//   halfLen    >0 stretches it E-W into a ridge; 0 leaves it round
void cliffMass(float x = 0.0, float z = 0.0, int landTiles = 0,
               float size = 0.006, float rise = 6.0, float halfLen = 0.0)
{
	gCliffIdx = gCliffIdx + 1;

	if (landTiles > 0)
	{
		int land = rmCreateArea("cliff land " + gCliffIdx);
		rmSetAreaWarnFailure(land, false);
		rmSetAreaSize(land, rmAreaTilesToFraction(landTiles), rmAreaTilesToFraction(landTiles));
		rmSetAreaLocation(land, x, z);
		rmSetAreaCoherence(land, 1.0);
		rmSetAreaBaseHeight(land, gCliffBase);
		rmSetAreaMix(land, gCliffMix);
		rmSetAreaElevationVariation(land, 0.0);
		rmSetAreaObeyWorldCircleConstraint(land, false);
		rmBuildArea(land);
	}

	int top = rmCreateArea("cliff top " + gCliffIdx);
	rmSetAreaWarnFailure(top, false);
	rmSetAreaSize(top, size, size);
	rmSetAreaLocation(top, x, z);
	if (halfLen > 0.0)
	{
		rmAddAreaInfluenceSegment(top, x - halfLen, z, x + halfLen, z);
	}
	rmSetAreaCoherence(top, 1.0);
	rmSetAreaBaseHeight(top, gCliffBase + rise);
	rmSetAreaCliffType(top, gCliffTypeImpassable);
	rmSetAreaCliffEdge(top, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(top, 0, 0.0, 1.0);
	rmSetAreaMix(top, gCliffMix);
	rmAddAreaToClass(top, rmClassID("classPlateau"));
	rmAddAreaToClass(top, rmClassID("classCliff"));
	rmSetAreaObeyWorldCircleConstraint(top, false);
	rmBuildArea(top);
}

// Floating island, part 1: the invisible landmass the river will need.
// Deliberately larger than the gun, so it still covers the spot after the
// trade route snaps and the measured position moves a few tiles.
int gScaffoldIdx = 0;
void shoreScaffold(float x = 0.0, float z = 0.0, int tiles = 650)
{
	gScaffoldIdx = gScaffoldIdx + 1;
	int land = rmCreateArea("gun scaffold " + gScaffoldIdx);
	rmSetAreaSize(land, rmAreaTilesToFraction(tiles), rmAreaTilesToFraction(tiles));
	rmSetAreaLocation(land, x, z);
	rmSetAreaCoherence(land, 1.0);
	rmSetAreaBaseHeight(land, 2.0);
	rmSetAreaWarnFailure(land, false);
	rmSetAreaMix(land, "italy_grass");
	rmSetAreaElevationVariation(land, 0.0);
	rmSetAreaObeyWorldCircleConstraint(land, false);
	rmBuildArea(land);
}

// Floating island, part 2: drown the scaffold under a river.
// CRITICAL: every river must be built BEFORE any gun is placed. A river built
// after a grouping drowns that grouping - interleaving river/gun/river/gun
// leaves only the last gun alive.
void shoreRiver(float x = 0.0, float z = 0.0, int width = 15, float reach = 0.05)
{
	int river = rmRiverCreate(-1, "ZP Black Sea Water", 4, 4, width, width);
	rmRiverAddWaypoint(river, x - reach, z);
	rmRiverAddWaypoint(river, x + reach, z);
	rmRiverBuild(river);
}

// Floating island, part 3: drop the gun grouping onto the drowned scaffold.
void placeShoreIsland(int grouping = -1, float x = 0.0, float z = 0.0)
{
	rmSetGroupingMinDistance(grouping, 0.0);
	rmSetGroupingMaxDistance(grouping, 0.01);
	rmAddGroupingToClass(grouping, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(grouping, 0, x, z);
}

// Drop a controller onto a trade route and report where it REALLY landed.
// This is the only trustworthy source of a lane's position.
int gControllerIdx = 0;
float routeRealZ(int tradeRouteID = -1)
{
	gControllerIdx = gControllerIdx + 1;
	int ctrl = rmCreateObjectDef("route controller " + gControllerIdx);
	rmAddObjectDefItem(ctrl, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefTradeRouteID(ctrl, tradeRouteID);
	rmSetObjectDefAllowOverlap(ctrl, true);
	rmSetObjectDefMinDistance(ctrl, 0.0);
	rmSetObjectDefMaxDistance(ctrl, 0.0);
	rmPlaceObjectDefAtPoint(ctrl, 0, rmGetTradeRouteWayPoint(tradeRouteID, 0.5));

	vector loc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(ctrl, 0));
	return rmZMetersToFraction(xsVectorGetZ(loc));
}


// One Home City water flag on a fixed spot, owned by the given player.
// The spot is a plain literal pair at the call site - tune it by editing
// the two numbers, the countryside-column mechanism.
int gFlagIdx = 0;
void placeWaterFlag(int p = -1, float x = 0.0, float z = 0.0)
{
	gFlagIdx = gFlagIdx + 1;
	int flag = rmCreateObjectDef("water flag " + gFlagIdx);
	rmAddObjectDefItem(flag, "HomeCityWaterSpawnFlag", 1, 0.0);
	rmSetObjectDefMinDistance(flag, 0.0);
	rmSetObjectDefMaxDistance(flag, 1.0);
	rmPlaceObjectDefAtLoc(flag, p, x, z);
}

void main(void)
{
	rmSetStatusText("", 0.01);

	// ========================================================================
	//  NATIVE SUBCIVS  -  the zp_z_zflorence.xs idiom (its lines 28-47).
	//  Every native whose socket spawns on this map: the four city blocks
	//  (Auditore / Orthodox / Phanar / Sufi), the cossack countryside camps
	//  and the pirate shore camps + city block.
	// ========================================================================
	int subCiv0 = -1;
	int subCiv1 = -1;
	int subCiv2 = -1;
	int subCiv3 = -1;
	int subCiv4 = -1;
	int subCiv5 = -1;
	if (rmAllocateSubCivs(6) == true)
	{
		subCiv0 = rmGetCivID("Auditore");
		rmEchoInfo("subCiv0 is Auditore " + subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "Auditore");

		subCiv1 = rmGetCivID("zpOrthodox");
		rmEchoInfo("subCiv1 is zpOrthodox " + subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "zpOrthodox");

		subCiv2 = rmGetCivID("Phanar");
		rmEchoInfo("subCiv2 is Phanar " + subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "Phanar");

		subCiv3 = rmGetCivID("SPCSufi");
		rmEchoInfo("subCiv3 is SPCSufi " + subCiv3);
		if (subCiv3 >= 0)
			rmSetSubCiv(3, "SPCSufi");

		subCiv4 = rmGetCivID("zpCossacks");
		rmEchoInfo("subCiv4 is zpCossacks " + subCiv4);
		if (subCiv4 >= 0)
			rmSetSubCiv(4, "zpCossacks");

		subCiv5 = rmGetCivID("NatPirates");
		rmEchoInfo("subCiv5 is NatPirates " + subCiv5);
		if (subCiv5 >= 0)
			rmSetSubCiv(5, "NatPirates");
	}

	// ========================================================================
	//  TUNABLES  -  everything you are likely to change lives here
	// ========================================================================
	int   mapSize     = 600;    // metres, square

	// Where we ASK for the lanes. The engine will snap them; the real values
	// are measured further down and everything is built from those.
	float nRouteAsk   = 0.51;   // NORTH lane (higher Z = north), runs E -> W
	float sRouteAsk   = 0.46;   // SOUTH lane (lower Z = south), runs W -> E

	int   blockPitch      = 17;   // tiles between block centres (columns & rows)

	// ---- DISTANCE FROM THE TRADE ROUTE, IN TILES -------------------------
	// How far each thing sits from ITS OWN lane. Bigger = further from the
	// lane. Always positive. Nothing to add up, no signs to flip.
	int   northCityDist   = 26;   // north lane -> north city, first block row
	int   southCityDist   = 26;   // south lane -> south city, first block row
	int   northGunDist    = 10;   // north lane -> north gun islands
	int   southGunDist    = 9;   // south lane -> south gun islands
	int   northTradeDist  = 11;   // north lane -> north trade harbour
	int   southTradeDist  = 10;   // south lane -> south trade harbour

	// ---- SIDEWAYS SHIFT, IN TILES ----------------------------------------
	// Positive = EAST, negative = WEST, 0 = centred on the map.
	int   northCityShiftX = 0;  // north city, 10 tiles west
	int   southCityShiftX =  -10;   // south city, centred

	// ---- CITY TERRAIN HEIGHT ---------------------------------------------
	// This map floats its islands, which needs sea level 1.0 - one higher than
	// the original Istanbul (0.0), so the districts are raised by the same 1.0.
	int   promenadeExtra  = 2;    // extra tiles of shoreline on the lane-facing
	                              // edge of BOTH islands (room for props/objects)
	int   flankPromExtra  = 2;    // extra tiles of shoreline on the FLANK coast
	                              // that carries trade harbours 3 and 4

	// ---- CITY EXTENSION toward the countryside ---------------------------
	// Each island grows this many tiles toward its wall flank (north: WEST,
	// south: EAST). The flank cliffs constrain off the street, so they mold
	// around the extended city and the walls stand ON city ground.
	int   cityExtendTilesN = 15;
	int   cityExtendTilesS = 15;

	float cityHeight      = 3.0;  // was 2.0 in 000_istanbul at sea level 0.0

	// ---- THE HINTERLAND: what turns each island into a peninsula ---------
	// Grassy country behind each district, running from the back row out to the
	// map edge, so the city is joined to land instead of floating. Same height
	// as the city, so the two meet flush; Italian cliffs on its own shores.
	int   hinterReach     = 90;   // tiles of country behind row 6, toward the edge
	int   hinterWiden     = 14;   // tiles it spreads past the city on each side
	int   hinterSetback   = 0;    // extra tiles to hold the grass back off row 6.
	                              // The seam already sits at the plateau's outer
	                              // edge (row 6 centre + margin); raise this only
	                              // if the grass still creeps onto the back row.
	string hinterMix      = "italy_grass_dry";   // Black Sea's paintMix
	string hinterCliff    = "Italian Cliff";     // Florence's wall/shore cliff
	// THE WOODS: a bunch of trees dropped at a point, scattered inside a
	// radius. Forest AREAS put themselves where they liked on this map, so the
	// trees are placed the way every other object here is placed - explicit
	// point, explicit spread. deTreeCypress is what the mod's own anatolia
	// branch uses, and the census proves the proto spawns on this map.
	string hinterTree     = "deTreeCypress";
	// One tree per placement, stepped across the countryside in a grid.
	// Single-tree placement is the thing that demonstrably works here, so the
	// loop just repeats it. Steps are whole tiles, and the accumulators are
	// floats - int * float truncates to 0 in XS.
	int   treeCols        = 34;   // trees along the shore
	int   treeRows        = 5;    // trees inland (countryside is ~17 tiles)
	int   treeStepTiles   = 3;    // tiles between grid points
	int   treesPerSpot    = 4;    // trees dropped at one spot
	float treeSpotSpread  = 5.0;  // metres they cluster
	int   treeJitter      = 4;    // tiles a tree may wander off its point.
	                              // Bigger than the step, so neighbouring
	                              // trees swap places and the rows dissolve.

	// WHERE THE WOODS GO - plain map fractions, nothing computed.
	// X: 0.0 west -> 1.0 east.   Z: 0.0 south -> 1.0 north.
	// The countryside strips lie at roughly z 0.94..1.00 (north) and
	// z 0.06..0.00 (south); island centres are x 0.50 north, x 0.47 south.
	// To move a wood, edit its two numbers. That is the whole mechanism.
	float forestNX        = 0.50;
	float forestNZ        = 0.97;
	float forestSX        = 0.47;
	float forestSZ        = 0.03;

	// ---- SOUTH/NORTH BALANCE --------------------------------------------
	// The two lanes snap asymmetrically, so the south peninsula ends up with
	// more country behind it than the north. NOTHING is repositioned to fix
	// that: a cliff takes the surplus back, and cliff is ground you cannot
	// build on. Its spot is hardcoded below - no measuring, no constraints.
	// Hardcoded. X: 0.0 west -> 1.0 east.  Z: 0.0 south -> 1.0 north.
	// The south countryside runs z 0.06 -> 0.00, island centre is x 0.47.
	// (the southern balancing cliff was removed - the hinterlands are equal
	//  now, so it was redundant. balanceRise below is still used by the flank
	//  cliffs and all four wall docks.)
	float balanceRise     = 6.0;   // how high it stands over the country


	// hand the cliff style to the file-scope helper
	gCliffType = hinterCliff;
	gCliffMix  = hinterMix;
	gCliffBase = cityHeight;

	// Gun facing is baked into the grouping XML:
	//   _01 -> orientz -1, muzzle points SOUTH (-z) -> use on the NORTH shore
	//   _02 -> orientz +1, muzzle points NORTH (+z) -> use on the SOUTH shore
	string gunNorthShore  = "IS_Shore_Fixed_Gun_01";
	string gunSouthShore  = "IS_Shore_Fixed_Gun_02";

	// Trade harbours: one per shore, centred between that shore's two guns.
	string tradeHarbourN  = "IS_Shore_Trade_01";
	string tradeHarbourS  = "IS_Shore_Trade_02";

	// Where the capturable socket sits INSIDE each trade grouping, in METRES
	// from the grouping centre. Read out of the XML before the socket was
	// stripped from it; the grouping is hung off the real socket by this offset.
	// ---- HARBOUR SOCKET GEOMETRY (metres) --------------------------------
	// TWO independent, separately editable steps per harbour:
	//   1) SocketOff - where the SOCKET is dropped, relative to that harbour's
	//                  anchor point (the spot the Dist/Along knobs computed)
	//   2) GroupOff  - where the GROUPING sits, relative to where the socket
	//                  ACTUALLY ended up after docking onto its lane
	// Change either one on its own. Defaults reproduce the original XML layout:
	// SocketOff = the socket's own position inside that grouping's XML, and
	// GroupOff  = the exact opposite, so the harbour wraps back around it.
	//
	// hN = north lane harbour (Trade_01)     hS = south lane harbour (Trade_02)
	// h3 = north flank (Trade_04)            h4 = south flank (Trade_03)
	// h5 = north flank 2 (Trade_04)          h6 = south flank 2 (Trade_03)
	float hNSocketOffX = -0.0716;   float hNSocketOffZ = -7.5912;
	float hNGroupOffX  =  0.0716;   float hNGroupOffZ  =  7.5912;

	float hSSocketOffX = -2.3773;   float hSSocketOffZ =  3.1930;
	float hSGroupOffX  =  2.3773;   float hSGroupOffZ  = -3.1930;

	float h3SocketOffX =  4.2043;   float h3SocketOffZ = -4.2629;
	float h3GroupOffX  = -4.2043;   float h3GroupOffZ  =  4.2629;

	float h4SocketOffX = -7.3477;   float h4SocketOffZ = -0.6680;
	float h4GroupOffX  =  7.3477;   float h4GroupOffZ  =  0.6680;

	float h5SocketOffX =  4.2043;   float h5SocketOffZ = -4.2629;
	float h5GroupOffX  = -4.2043;   float h5GroupOffZ  =  4.2629;

	float h6SocketOffX = -7.3477;   float h6SocketOffZ = -0.6680;
	float h6GroupOffX  =  7.3477;   float h6GroupOffZ  =  0.6680;

	// Trade harbours 3 & 4 sit on the FLANK coasts, not the lane side. The
	// minimap is rotated 45 deg, so an island's code +x edge reads as its
	// NORTH-EAST coast and its code -x edge as the SOUTH-WEST coast.
	string tradeHarbour3  = "IS_Shore_Trade_04";   // north island, NE coast
	string tradeHarbour4  = "IS_Shore_Trade_03";   // south island, SW coast
	// Harbour 3 / 4 placement, two axes each:
	//   ...FlankDist  = tiles OUT from the coast   (bigger = further into water)
	//   ...FlankAlong = tiles ALONG the coast      (+ = north, - = south)
	//                   0 = centred on the island's middle row
	int   northFlankDist  = 2;    // out from the north island's NE coast
	int   northFlankAlong = 2;    // along that coast
	int   southFlankDist  = 4;    // out from the south island's SW coast
	int   southFlankAlong = 0;    // along that coast

	// Where each lane turns the corner around its flank harbour. Measured FROM
	// THE HARBOUR, so the lane keeps its distance when you move the harbour.
	//   ...BendOut   = tiles further out into the water (harbour hull is ~9)
	//   ...BendAlong = tiles further along the coast, away from the channel
	// Pirate camps: same flank coast as harbours 3 / 4, but at the BACK of the
	// island, away from the channel. They are big (23x25 tiles), so they get a
	// bigger scaffold and a wider river than the harbours.
	// Second flank harbour on each coast: SAME distance out from the city as
	// harbour 3 / 4, but its own position along the coast.
	//   ...Flank2Toward = tiles along the coast TOWARD the channel
	//                     34 = two block rows = level with the first block line
	string tradeHarbour5  = "IS_Shore_Trade_04";   // north island, 2nd flank harbour
	string tradeHarbour6  = "IS_Shore_Trade_03";   // south island, 2nd flank harbour
	int   northFlank2Toward = 34;
	int   southFlank2Toward = 34;

	// Shoreline decoration on the NORTH island's canal-facing shore, one piece
	// between each fixed gun and the trade harbour. Placed on LAND, after all
	// city blocks. Tune these by hand - all values are in TILES:
	//   ...Along = along the shore, from the island's centre column
	//              (negative = west, positive = east)
	//   decoShoreIn = tiles inland from the water's edge (bigger = further
	//              onto the island, smaller/negative = closer to the water)
	string decoShoreline  = "IS_Deco_Shoreline_N";   // north island
	string decoShorelineS = "IS_Deco_Shoreline_S";   // south island, 180 deg turned
	string decoShorelineNE = "IS_Deco_Shoreline_NE"; // north island NE coast
	string decoShorelineSW = "IS_Deco_Shoreline_SW"; // south island SW coast, 180 deg turned

	// NE coast pieces sit in the gaps along that shore:
	//   harbour 5  <- deco ->  harbour 3  <- deco ->  pirates  <- deco (behind)
	int   decoNEDist       = 3;   // tiles out from the NE coast (same as the harbours)
	int   decoSWDist       = 4;  // tiles out from the SW coast (south island)
	// third piece BEHIND the pirate grouping, further from the channel; the
	// pirates span ~25 t along the coast, so 20 clears their half + the deco's
	int   decoNEBehindPir  = 18;  // tiles beyond the pirate centre (north)
	int   decoSWBehindPir  = 18;  // tiles beyond the pirate centre (south)

	// Deco lighthouse (zpPropWaterTower - the lighthouse model as a prop),
	// one per island on the OPEN-SEA harbour corner - where the canal quay
	// meets the flank coast (NOT the channel-bend corner, that end is cliffs).
	// Anchored on MEASURED references, all values PLAIN POSITIVE TILES:
	//   lightNAlongX = from the flank coast line (nx5 + flankProm) further
	//                  EAST out to sea (bigger = further off the corner;
	//                  3 = the harbour line, same as the NE deco pieces)
	//   lightNOffZ   = from the north LANE toward the city
	//                  (bigger = further inland, 11 = the quay-wall line)
	// South island is the 180 deg turn: from its flank coast line further
	// WEST, and from the south lane toward its city.
	int   lightNAlongX     = 0;
	int   lightNOffZ       = 14;
	int   lightSAlongX     = 1;
	int   lightSOffZ       = 13;
	// All three are PLAIN POSITIVE DISTANCES IN TILES - negative values do not
	// work in this engine, so nothing here ever needs a minus sign.
	//   decoNLaneDist    = from the north LANE toward the city.
	//                     bigger = further from the water, deeper into the city
	//   decoNWestFromGun = from the WEST gun, eastward along the shore
	//   decoNEastFromGun = from the EAST gun, westward along the shore
	//                     bigger = closer to the trade harbour in the middle
	// NORTH island
	int   decoNLaneDist    = 11;
	int   decoNWestFromGun = 17;
	int   decoNEastFromGun = 17;
	// SOUTH island - its own set, so the two shores tune independently
	int   decoSLaneDist    = 11;
	int   decoSWestFromGun = 17;
	int   decoSEastFromGun = 17;

	string piratesNorth   = "IS_Shore_Pirates_02";
	string piratesSouth   = "IS_Shore_Pirates_01";
	int   northPirateDist = 5;    // tiles out from that coast
	int   northPirateBack = 34;   // tiles along the coast, away from the channel
	int   southPirateDist = 5;
	int   southPirateBack = 34;


	// ========================================================================
	//  1. MAP + WATER
	// ========================================================================
	rmSetMapSize(mapSize, mapSize);
	rmSetMapElevationHeightBlend(1);

	// This water setup is what lets groupings float. Changing it - above all
	// the sea level and the shoreless lagoon - kills the effect.
	rmSetSeaLevel(1.0);
	rmSetSeaType("ZP Black Sea Lagoon");    // shoreless: keeps baked terrain
	rmEnableLocalWater(false);
	rmTerrainInitialize("water");
	rmSetLightingSet("age3challenges09a");
	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetMapType("eastEurope");
	rmSetMapType("default");
	rmSetMapType("piratehistoricalmap");
	rmSetMapType("eurotradeRouteCapture");
	// the treasure-house nuggets are the DEFAULT ones, picked from this table
	rmSetMapType("mediEurope");

	// Full reveal from the start (zp_z_zparis.xs 122).
	rmSetAllMapReveal(true);

	// _________________ Map Objectives ______________________________
	// zp_z_zparis.xs 1873-1879 shape. Paris adds one objective per team;
	// both sides here share the same goal, so it is a single entry with no
	// rmObjectiveSetTeam - it shows for everyone.
	rmObjectiveScreenSetTitle(303339);
	rmObjectiveScreenSetGoal(303340);
	rmObjectiveAdd(303341, 303342, true, true, true);
	rmSetWorldCircleConstraint(true);

	rmDefineClass("classPlateau");
	rmDefineClass("classBlock");
	rmDefineClass("classStreet");
	rmDefineClass("classCliff");
	rmDefineClass("classGun");

	// ========================================================================
	//  1b. GENERIC CONSTRAINTS - every order-free constraint DEFINED here,
	//  once (the reference convention: type/terrain/box/pie constraints and
	//  class constraints on the classes above). A constraint is only
	//  EVALUATED when something is placed against it, so where it is defined
	//  changes nothing about the layout. Area-tied constraints (the guard
	//  areas) and boxes computed from measured lanes stay with their areas.
	//  Values are user-tuned - copied here byte-identical, do not re-tune.
	// ========================================================================

	// -- streets and cliffs --
	int avoidStreet = rmCreateClassDistanceConstraint("hinterland off the street",
		rmClassID("classStreet"), 0.0);
	// cliffs are 6 m higher and their faces + smoothing paint OUTSIDE their
	// own cells - 8 m keeps all of that off the promenade
	int cliffOffStreet = rmCreateClassDistanceConstraint("cliffs off the street",
		rmClassID("classStreet"), 1.0);
	int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 9.0);
	// trees stay one tile clear of the cliff
	// Distance here is METRES, not a map fraction - every shipped map passes
	// plain numbers (20.0, 30.0, 8.0) and not one passes a ToFraction helper.
	// 1 tile = 2 m, so one tile of clearance is 2.0.
	int avoidCliff = rmCreateClassDistanceConstraint("trees off the cliff",
		rmClassID("classCliff"), 5.0);

	// -- walls and docks --
	int avoidWallObj = rmCreateTypeDistanceConstraint("avoid wall object",
		"AbstractWall", 0.01);
	int avoidWallObjLong = rmCreateTypeDistanceConstraint("avoid wall object long",
	"AbstractWall", 2.00);
	// resource standoff: treasures/herds/mines stay visually clear of the
	// ramparts (0.01/1.0 above are the user-tuned fill fences - untouched)
	int avoidWallObjXL = rmCreateTypeDistanceConstraint("avoid wall object xl",
	"AbstractWall", 20.0);
	int avoidWallObjTree = rmCreateTypeDistanceConstraint("avoid wall object trees",
	"AbstractWall", 10.0);
	int dockAvoidBlocks = rmCreateClassDistanceConstraint("docks off city blocks",
		rmClassID("classBlock"), 8.0);
	// class, not unit type: still holds if the cannon proto changes later
	int dockAvoidGunClass = rmCreateClassDistanceConstraint("docks off the guns",
		rmClassID("classGun"), 6.0);

	// -- countryside fill --
	int fillAvoidCliff = rmCreateClassDistanceConstraint("fill off cliffs",
		rmClassID("classCliff"), 10.0);

	// -- world circle --
	// keep countryside objects INSIDE the world circle (a treasure was
	// spawning half in the void at the rim) - Black Sea's pie idiom, r 0.46
	int insideWorld = rmCreatePieConstraint("inside the world circle", 0.5, 0.5,
		rmXFractionToMeters(0.0), rmXFractionToMeters(0.46),
		rmDegreesToRadians(0), rmDegreesToRadians(360));

	// -- resource spacing --
	int treeVsTree = rmCreateTypeDistanceConstraint("tree clump v tree clump", "deTreeCypress", 20.0);
	// trees keep the socket approaches clear (000_blacksea.xs 242 idiom -
	// "Socket" is the abstract type all sockets carry); a clump centre 20 m
	// out keeps its widest items ~9 m off the socket ring
	int avoidSocketTrees = rmCreateTypeDistanceConstraint("trees off sockets", "Socket", 20.0);
	int mineVsMine = rmCreateTypeDistanceConstraint("mine v mine", "MineCopper", 70.0);
	int deerVsDeer = rmCreateTypeDistanceConstraint("herd v herd", "Deer", 40.0);
	int fishVsFish = rmCreateTypeDistanceConstraint("fish v fish", "FishSardine", 18.0);
	int whaleVsWhale = rmCreateTypeDistanceConstraint("whale v whale", "HumpbackWhale", 50.0);
	int fishOffLand = rmCreateTerrainDistanceConstraint("fish off land", "Water", false, 6.0);
	int whaleOffLand = rmCreateTerrainDistanceConstraint("whale off land", "Water", false, 25.0);
	int nugVsNug = rmCreateTypeDistanceConstraint("nugget v nugget", "AbstractNugget", 60.0);

	// -- sea life --
	// sea life keeps clear of the forts - zpcaribbeanwars 156-158 idiom
	int avoidKotH = rmCreateTypeDistanceConstraint("fish off the water fort", "zpKingsHillNaval", 15.0);
	int avoidKotHLong = rmCreateTypeDistanceConstraint("whales off the water fort", "zpKingsHillNaval", 25.0);
	int avoidHarbourPlat = rmCreateTypeDistanceConstraint("fish off harbour platforms", "zpHarbourPlatform", 20.0);
	int avoidKotHMedi = rmCreateTypeDistanceConstraint("fish off the medi fort", "zpKingsHillNavalMedi", 15.0);
	int avoidKotHMediLong = rmCreateTypeDistanceConstraint("whales off the medi fort", "zpKingsHillNavalMedi", 25.0);
	// NE box = the Black Sea side (north lane entry waters), SW box = the
	// Mediterranean side (south lane entry waters).
	int seaBoxNE = rmCreateBoxConstraint("black sea side", 0.62, 0.52, 0.98, 0.98, 0.01);
	int seaBoxSW = rmCreateBoxConstraint("mediterranean side", 0.02, 0.02, 0.38, 0.48, 0.01);


	rmSetStatusText("", 0.08);

	// ========================================================================
	//  2. COLUMNS  -  east/west only, so they need no route measurement
	// ========================================================================
	float colPitch = rmXTilesToFraction(blockPitch);
	float rowPitch = rmZTilesToFraction(blockPitch);
	float margin   = colPitch * 0.6;            // plateau margin around a grid
	// The shore that faces the trade route is pushed out further, so the quay
	// in front of the first block row is wider.
	float promenade = margin + rmZTilesToFraction(promenadeExtra);
	// the flank coast that carries harbours 3 / 4 gets its own wider quay
	float flankProm = margin + rmXTilesToFraction(flankPromExtra);

	// Shared column skeleton, west -> east, centred on the channel.
	float x1 = 0.5 - colPitch * 2.0;
	float x2 = 0.5 - colPitch;
	float x3 = 0.5;
	float x4 = 0.5 + colPitch;
	float x5 = 0.5 + colPitch * 2.0;

	// Each island owns a copy of those columns, shifted by its own nudge.
	float nDX = rmXTilesToFraction(northCityShiftX);
	float sDX = rmXTilesToFraction(southCityShiftX);

	float nx1 = x1 + nDX;   float nx2 = x2 + nDX;   float nx3 = x3 + nDX;
	float nx4 = x4 + nDX;   float nx5 = x5 + nDX;

	float sx1 = x1 + sDX;   float sx2 = x2 + sDX;   float sx3 = x3 + sDX;
	float sx4 = x4 + sDX;   float sx5 = x5 + sDX;

	// ---- NOMINAL ISLAND GEOMETRY -----------------------------------------
	// The lanes do not exist yet, so anything needed before they are built
	// (scaffolds, trade route waypoints) is derived from the REQUESTED lane
	// positions. Measured values take over afterwards.
	float nz3Ask = nRouteAsk + rmZTilesToFraction(northCityDist) + rowPitch + rowPitch
		+ rmZTilesToFraction(northFlankAlong);
	float sz3Ask = sRouteAsk - rmZTilesToFraction(southCityDist) - rowPitch - rowPitch
		+ rmZTilesToFraction(southFlankAlong);
	// where each lane bends around its island's flank harbour (clear of its hull)
	// the corner sits out past the harbour AND up the coast, so the waypoint
	// never lands on the harbour itself

	// ========================================================================
	//  3. GUN SCAFFOLDS  -  built before any river exists
	// ------------------------------------------------------------------------
	// These use the REQUESTED lane positions, because the routes do not exist
	// yet. That is fine: a scaffold is ~19 tiles across against a 9-tile gun,
	// so it still covers the spot after the lane snaps a few tiles.
	// ========================================================================
	shoreScaffold(nx1, nRouteAsk + rmZTilesToFraction(northGunDist));
	shoreScaffold(nx5, nRouteAsk + rmZTilesToFraction(northGunDist));
	shoreScaffold(sx1, sRouteAsk - rmZTilesToFraction(southGunDist));
	shoreScaffold(sx5, sRouteAsk - rmZTilesToFraction(southGunDist));
	shoreScaffold(nx3, nRouteAsk + rmZTilesToFraction(northTradeDist));
	shoreScaffold(sx3, sRouteAsk - rmZTilesToFraction(southTradeDist));
	// flank harbours: x needs no lane, z uses the nominal middle row (z3)
	shoreScaffold(nx5 + flankProm + rmXTilesToFraction(northFlankDist), nz3Ask);
	shoreScaffold(sx1 - flankProm - rmXTilesToFraction(southFlankDist), sz3Ask);
	shoreScaffold(nx5 + flankProm + rmXTilesToFraction(northFlankDist),
		nz3Ask - rmZTilesToFraction(northFlank2Toward));
	shoreScaffold(sx1 - flankProm - rmXTilesToFraction(southFlankDist),
		sz3Ask + rmZTilesToFraction(southFlank2Toward));
	shoreScaffold(nx5 + flankProm + rmXTilesToFraction(northPirateDist),
		nz3Ask + rmZTilesToFraction(northPirateBack), 1100);
	shoreScaffold(sx1 - flankProm - rmXTilesToFraction(southPirateDist),
		sz3Ask - rmZTilesToFraction(southPirateBack), 1100);
	// ground for the third deco piece BEHIND each pirate camp - 20 t past the
	// pirate centre is beyond the 1100-disc rim (r ~18.7 t), so without these
	// the deco stands over open water and silently never spawns
	shoreScaffold(nx5 + flankProm + rmXTilesToFraction(northPirateDist),
		nz3Ask + rmZTilesToFraction(northPirateBack + decoNEBehindPir));
	shoreScaffold(sx1 - flankProm - rmXTilesToFraction(southPirateDist),
		sz3Ask - rmZTilesToFraction(southPirateBack + decoSWBehindPir));

	// ========================================================================
	//  4. TRADE ROUTES  ->  then MEASURE where they really are
	// ========================================================================
	int tradeRouteN = rmCreateTradeRoute();
	// north lane
	rmAddTradeRouteWaypoint(tradeRouteN, 0.90, 0.90);   // NE corner
	rmAddTradeRouteWaypoint(tradeRouteN, 0.70, 0.76);   // past flank harbour
	rmAddTradeRouteWaypoint(tradeRouteN, 0.70, nRouteAsk);   // into channel
	rmAddTradeRouteWaypoint(tradeRouteN, 0.50, nRouteAsk);   // mid channel
	rmAddTradeRouteWaypoint(tradeRouteN, 0.25, nRouteAsk);   // corner
	rmAddTradeRouteWaypoint(tradeRouteN, 0.00, 0.30);   // corner


	rmBuildTradeRoute(tradeRouteN, "water_trail");

	int tradeRouteS = rmCreateTradeRoute();
	// south lane
	rmAddTradeRouteWaypoint(tradeRouteS, 0.10, 0.10);   // SW corner
	rmAddTradeRouteWaypoint(tradeRouteS, 0.25, 0.25);   // past flank harbour
	rmAddTradeRouteWaypoint(tradeRouteS, 0.25, sRouteAsk);   // into channel
	rmAddTradeRouteWaypoint(tradeRouteS, 0.50, sRouteAsk);   // mid channel
	rmAddTradeRouteWaypoint(tradeRouteS, 0.75, sRouteAsk);   // corner
	rmAddTradeRouteWaypoint(tradeRouteS, 1.00, 0.70);   

	rmBuildTradeRoute(tradeRouteS, "water_trail");

	// One controller per lane. The north one doubles as the mandatory
	// water-spawn stopper. Their read-back positions are the ONLY numbers we
	// trust from here on.
	float nRouteZ = routeRealZ(tradeRouteN);
	float sRouteZ = routeRealZ(tradeRouteS);

	rmEchoInfo("north lane: asked " + nRouteAsk + "  ->  real " + nRouteZ);
	rmEchoInfo("south lane: asked " + sRouteAsk + "  ->  real " + sRouteZ);

	rmSetStatusText("", 0.25);

	// ========================================================================
	//  5. ROWS + GUN POSITIONS  -  all measured from the REAL lanes
	// ========================================================================
	// Rows: z1 is the row nearest its lane, z5 the one farthest inland.
	float nz1 = nRouteZ + rmZTilesToFraction(northCityDist);
	float nz2 = nz1 + rowPitch;
	float nz3 = nz2 + rowPitch;
	float nz4 = nz3 + rowPitch;
	float nz5 = nz4 + rowPitch;
	// Row 6: the back row. Land is built for it and its cells are defined, but
	// nothing is ever placed there - see the ROW 6 table further down.
	float nz6 = nz5 + rowPitch;

	float sz1 = sRouteZ - rmZTilesToFraction(southCityDist);
	float sz2 = sz1 - rowPitch;
	float sz3 = sz2 - rowPitch;
	float sz4 = sz3 - rowPitch;
	float sz5 = sz4 - rowPitch;
	float sz6 = sz5 - rowPitch;

	// Gun islands sit out in the channel, at each island's inner corners.
	float nGunZ = nRouteZ + rmZTilesToFraction(northGunDist);
	float sGunZ = sRouteZ - rmZTilesToFraction(southGunDist);

	// Trade harbours sit on the same shores, midway between the two guns.
	float nTradeZ = nRouteZ + rmZTilesToFraction(northTradeDist);
	float sTradeZ = sRouteZ - rmZTilesToFraction(southTradeDist);

	// Flank harbours: middle of each island's flank coast (row z3).
	float nFlankX = nx5 + flankProm + rmXTilesToFraction(northFlankDist);
	float sFlankX = sx1 - flankProm - rmXTilesToFraction(southFlankDist);
	float nFlankZ = nz3 + rmZTilesToFraction(northFlankAlong);
	float sFlankZ = sz3 + rmZTilesToFraction(southFlankAlong);

	// pirate camps: same coasts, pushed to the back of each island
	// second flank harbours - identical X to 3 / 4, their own row
	float nFlank2Z = nz3 - rmZTilesToFraction(northFlank2Toward);
	float sFlank2Z = sz3 + rmZTilesToFraction(southFlank2Toward);

	float nPirateX = nx5 + flankProm + rmXTilesToFraction(northPirateDist);
	float sPirateX = sx1 - flankProm - rmXTilesToFraction(southPirateDist);
	float nPirateZ = nz3 + rmZTilesToFraction(northPirateBack);
	float sPirateZ = sz3 - rmZTilesToFraction(southPirateBack);

	// ========================================================================
	//  5b. PLAYERS - the Florence system (zp_z_zflorence.xs 51-160)
	// ========================================================================
	// Roles, not lobby seats: the k-th defender is the k-th-lowest player ID
	// on the NORTH team, the k-th attacker the same on the SOUTH team. WHICH
	// lobby team holds which island is a coin flip per generation (sideRoll),
	// so team 1 can start north or south. Seats per team size:
	//   1 player  -> the harbour corner seat (flank sea + pirate camp)
	//   2 players -> harbour corner + the mid countryside spot by the gate
	//   3 players -> both city seats + 1 countryside
	//   4 and up  -> both city seats + the countryside column, as before
	// 2-TEAM MAPS ONLY - other configs place nobody, exactly like Florence.
	int sideRoll = rmRandInt(0, 1);
	int northTeam = 1;
	int southTeam = 0;
	if (sideRoll == 1)
	{
		northTeam = 0;
		southTeam = 1;
	}
	int northCount = rmGetNumberPlayersOnTeam(northTeam);
	int southCount = rmGetNumberPlayersOnTeam(southTeam);
	int firstDefender = -1;   int firstAttacker = -1;
	int secondDefender = -1;   int secondAttacker = -1;
	int thirdDefender = -1;   int thirdAttacker = -1;
	int fourthDefender = -1;   int fourthAttacker = -1;
	int fifthDefender = -1;   int fifthAttacker = -1;
	int sixthDefender = -1;   int sixthAttacker = -1;
	int seventhDefender = -1;   int seventhAttacker = -1;

	for (pf = 1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == northTeam) { firstDefender = pf; break; } }
	for (pf = firstDefender+1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == northTeam) { secondDefender = pf; break; } }
	for (pf = secondDefender+1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == northTeam) { thirdDefender = pf; break; } }
	for (pf = thirdDefender+1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == northTeam) { fourthDefender = pf; break; } }
	for (pf = fourthDefender+1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == northTeam) { fifthDefender = pf; break; } }
	for (pf = fifthDefender+1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == northTeam) { sixthDefender = pf; break; } }
	for (pf = sixthDefender+1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == northTeam) { seventhDefender = pf; break; } }
	for (pf = 1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == southTeam) { firstAttacker = pf; break; } }
	for (pf = firstAttacker+1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == southTeam) { secondAttacker = pf; break; } }
	for (pf = secondAttacker+1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == southTeam) { thirdAttacker = pf; break; } }
	for (pf = thirdAttacker+1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == southTeam) { fourthAttacker = pf; break; } }
	for (pf = fourthAttacker+1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == southTeam) { fifthAttacker = pf; break; } }
	for (pf = fifthAttacker+1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == southTeam) { sixthAttacker = pf; break; } }
	for (pf = sixthAttacker+1; <= cNumberNonGaiaPlayers) { if (rmGetPlayerTeam(pf) == southTeam) { seventhAttacker = pf; break; } }

	int outN = 0;
	int outS = 0;
	int citySeatsN = 1;
	int citySeatsS = 1;
	int outFirstDef = -1;
	int outFirstAtt = -1;
	if (cNumberTeams == 2)
	{
		// city seats, row 5. The HARBOUR corner - (nx5,nz5) north, its 180 deg
		// turn (sx1,sz5) south - borders the flank sea and the pirate camp, so
		// a team's FIRST seat is there whenever it fields 1 or 2 players (a
		// 2-player team keeps ONE city seat; its second player starts on the
		// countryside instead). From 3 players up both city seats fill exactly
		// as before: first at the wall-side column (nx2 / sx4, the concept
		// scenario), second at the harbour corner.
		if (northCount >= 3) citySeatsN = 2;
		if (southCount >= 3) citySeatsS = 2;
		if (citySeatsN == 1)
		{
			rmPlacePlayer(firstDefender, nx5, nz5);
		}
		if (citySeatsN == 2)
		{
			rmPlacePlayer(firstDefender, nx2, nz5);
			rmPlacePlayer(secondDefender, nx5, nz5);
		}
		if (citySeatsS == 1)
		{
			rmPlacePlayer(firstAttacker, sx1, sz5);
		}
		if (citySeatsS == 2)
		{
			rmPlacePlayer(firstAttacker, sx4, sz5);
			rmPlacePlayer(secondAttacker, sx1, sz5);
		}

		// countryside column outside each wall: separate literals per count,
		// evenly spread, every spot >= 36 m from every lane segment incl. snap.
		// South is NOT a point-mirror of north (the island sits 10 t west); its
		// column is derived in its own frame.
		// The FIRST countryside player is the team's SECOND member when it
		// fields exactly 2, the third member from 3 up.
		outFirstDef = thirdDefender;
		if (northCount == 2) outFirstDef = secondDefender;
		outFirstAtt = thirdAttacker;
		if (southCount == 2) outFirstAtt = secondAttacker;
		outN = northCount - citySeatsN;
		outS = southCount - citySeatsS;
		if (outN == 1)
		{
			rmPlacePlayer(outFirstDef, 0.220, 0.750);
		}
		if (outN == 2)
		{
			rmPlacePlayer(thirdDefender, 0.220, 0.680);
			rmPlacePlayer(fourthDefender, 0.220, 0.820);
		}
		if (outN == 3)
		{
			rmPlacePlayer(thirdDefender, 0.220, 0.660);
			rmPlacePlayer(fourthDefender, 0.220, 0.750);
			rmPlacePlayer(fifthDefender, 0.220, 0.840);
		}
		if (outN == 4)
		{
			rmPlacePlayer(thirdDefender, 0.220, 0.640);
			rmPlacePlayer(fourthDefender, 0.220, 0.715);
			rmPlacePlayer(fifthDefender, 0.220, 0.790);
			rmPlacePlayer(sixthDefender, 0.220, 0.860);
		}
		if (outN == 5)
		{
			rmPlacePlayer(thirdDefender, 0.220, 0.640);
			rmPlacePlayer(fourthDefender, 0.220, 0.695);
			rmPlacePlayer(fifthDefender, 0.220, 0.750);
			rmPlacePlayer(sixthDefender, 0.220, 0.805);
			rmPlacePlayer(seventhDefender, 0.220, 0.860);
		}
		if (outS == 1)
		{
			rmPlacePlayer(outFirstAtt, 0.745, 0.250);
		}
		if (outS == 2)
		{
			rmPlacePlayer(thirdAttacker, 0.745, 0.320);
			rmPlacePlayer(fourthAttacker, 0.745, 0.180);
		}
		if (outS == 3)
		{
			rmPlacePlayer(thirdAttacker, 0.745, 0.340);
			rmPlacePlayer(fourthAttacker, 0.745, 0.250);
			rmPlacePlayer(fifthAttacker, 0.745, 0.160);
		}
		if (outS == 4)
		{
			rmPlacePlayer(thirdAttacker, 0.745, 0.360);
			rmPlacePlayer(fourthAttacker, 0.745, 0.285);
			rmPlacePlayer(fifthAttacker, 0.745, 0.210);
			rmPlacePlayer(sixthAttacker, 0.745, 0.140);
		}
		if (outS == 5)
		{
			rmPlacePlayer(thirdAttacker, 0.745, 0.360);
			rmPlacePlayer(fourthAttacker, 0.745, 0.305);
			rmPlacePlayer(fifthAttacker, 0.745, 0.250);
			rmPlacePlayer(sixthAttacker, 0.745, 0.195);
			rmPlacePlayer(seventhAttacker, 0.745, 0.140);
		}
	}

	// ========================================================================
	//  6. THE FOUR GUN ISLANDS  -  each facing the lane it guards
	// ========================================================================
	int gunNW = rmCreateGrouping("gun nw", gunNorthShore);
	int gunNE = rmCreateGrouping("gun ne", gunNorthShore);
	int gunSW = rmCreateGrouping("gun sw", gunSouthShore);
	int gunSE = rmCreateGrouping("gun se", gunSouthShore);
	int tradeN = rmCreateGrouping("trade harbour n", tradeHarbourN);
	int tradeS = rmCreateGrouping("trade harbour s", tradeHarbourS);
	int trade3 = rmCreateGrouping("trade harbour 3", tradeHarbour3);
	int trade4 = rmCreateGrouping("trade harbour 4", tradeHarbour4);
	int trade5 = rmCreateGrouping("trade harbour 5", tradeHarbour5);
	int trade6 = rmCreateGrouping("trade harbour 6", tradeHarbour6);
	int pirateN = rmCreateGrouping("pirates north", piratesNorth);
	int pirateS = rmCreateGrouping("pirates south", piratesSouth);

	// PHASE A - every river first (a later river would drown an earlier gun)
	// CHANNEL RIVERS SIT 3-4 TILES LANE-WARD OF THEIR SCAFFOLDS. Width 13
	// puts a river edge 6.5 t from centre; unshifted, that edge reaches
	// 1.7-3.7 t INTO the city promenade band (fronts at z 0.586 / 0.414)
	// and the carved/terraced rim there is the sand-beach artifact. The
	// shift clears the promenade; the lane side still covers the scaffold.
	shoreRiver(nx1, nGunZ - rmZTilesToFraction(3));
	shoreRiver(nx5, nGunZ - rmZTilesToFraction(3));
	shoreRiver(sx1, sGunZ + rmZTilesToFraction(3));
	shoreRiver(sx5, sGunZ + rmZTilesToFraction(3));
	shoreRiver(nx3, nTradeZ - rmZTilesToFraction(4));
	shoreRiver(sx3, sTradeZ + rmZTilesToFraction(4));
	shoreRiver(nFlankX, nFlankZ);
	shoreRiver(sFlankX, sFlankZ);
	shoreRiver(nFlankX, nFlank2Z);
	shoreRiver(sFlankX, sFlank2Z);
	// pirate platform is 25 t; scaffold 900 = disc 33.9 t; river 36x28
	// uses the same cover ratios the gun rivers prove out (edge under-
	// cover -3 t/side is the proven-safe regime, over-cover breaks shores)
	shoreRiver(nPirateX, nPirateZ, 28, 0.06);
	shoreRiver(sPirateX, sPirateZ, 28, 0.06);

	// PHASE B - only now the guns go down
	// classGun BEFORE placement, so the class constraint below sees them
	rmAddGroupingToClass(gunNW, rmClassID("classGun"));
	rmAddGroupingToClass(gunNE, rmClassID("classGun"));
	rmAddGroupingToClass(gunSW, rmClassID("classGun"));
	rmAddGroupingToClass(gunSE, rmClassID("classGun"));
	// ANTI-SHIP GUN SOCKETS. The gun groupings now carry zpSocketAntiShipGun
	// instead of a finished gun, so each island is placed as an INSTANCE -
	// only an instance placement can be queried back by type. The socket ids
	// are derived in the UNIT IDS block (:2745) as
	//     rmGetGroupingInstanceUnitByType(...) + instanceIdShift
	// exactly like the factories, forts, menageries and harbour nuggets. They
	// therefore inherit the SAME shift as every other instance query on this
	// map - if instanceIdShift is ever re-measured, these move with it.
	// GUN OWNERS - the countryside players of each team, per the standing rule:
	//   1 countryside player  -> that player holds BOTH guns on their side
	//   2 countryside players -> one gun each
	//   3 or more             -> only the first two get a gun; the rest none
	// The first countryside player is the team's SECOND member when it fields
	// exactly 2, and the THIRD member from 3 up (the same derivation the
	// countryside column uses at :924-927).
	int gunOwnerN1 = -1;   int gunOwnerN2 = -1;
	int gunOwnerS1 = -1;   int gunOwnerS2 = -1;
	if (northCount == 1) { gunOwnerN1 = firstDefender;  gunOwnerN2 = firstDefender; }
	if (northCount == 2) { gunOwnerN1 = secondDefender; gunOwnerN2 = secondDefender; }
	if (northCount == 3) { gunOwnerN1 = thirdDefender;  gunOwnerN2 = thirdDefender; }
	if (northCount >= 4) { gunOwnerN1 = thirdDefender;  gunOwnerN2 = fourthDefender; }
	if (southCount == 1) { gunOwnerS1 = firstAttacker;  gunOwnerS2 = firstAttacker; }
	if (southCount == 2) { gunOwnerS1 = secondAttacker; gunOwnerS2 = secondAttacker; }
	if (southCount == 3) { gunOwnerS1 = thirdAttacker;  gunOwnerS2 = thirdAttacker; }
	if (southCount >= 4) { gunOwnerS1 = thirdAttacker;  gunOwnerS2 = fourthAttacker; }
	// Non-2-team lobbies resolve nobody; fall back to gaia so placement still
	// succeeds exactly as it did before this system existed.
	if (gunOwnerN1 < 0) gunOwnerN1 = 0;
	if (gunOwnerN2 < 0) gunOwnerN2 = 0;
	if (gunOwnerS1 < 0) gunOwnerS1 = 0;
	if (gunOwnerS2 < 0) gunOwnerS2 = 0;

	// PLACEMENT. INSTANCE placement, exactly like the factories (:1839), the
	// forts (:1818), the menageries (:1951) and the trade harbours (:1133) -
	// all of which are this same floating-island construction. The instance
	// handle is what lets the UNIT IDS block query the socket back BY TYPE.
	// Player comes LAST in rmPlaceGroupingInstanceAtLoc (guide 9999-10000),
	// which is what makes the island and its socket belong to the countryside
	// player instead of gaia.
	rmSetGroupingMinDistance(gunNW, 0.0);   rmSetGroupingMaxDistance(gunNW, 0.01);
	rmSetGroupingMinDistance(gunNE, 0.0);   rmSetGroupingMaxDistance(gunNE, 0.01);
	rmSetGroupingMinDistance(gunSW, 0.0);   rmSetGroupingMaxDistance(gunSW, 0.01);
	rmSetGroupingMinDistance(gunSE, 0.0);   rmSetGroupingMaxDistance(gunSE, 0.01);
	rmAddGroupingToClass(gunNW, rmClassID("classPlateau"));
	rmAddGroupingToClass(gunNE, rmClassID("classPlateau"));
	rmAddGroupingToClass(gunSW, rmClassID("classPlateau"));
	rmAddGroupingToClass(gunSE, rmClassID("classPlateau"));
	int gunNWPlacement = rmPlaceGroupingInstanceAtLoc(gunNW, nx1, nGunZ, gunOwnerN1);
	int gunNEPlacement = rmPlaceGroupingInstanceAtLoc(gunNE, nx5, nGunZ, gunOwnerN2);
	int gunSWPlacement = rmPlaceGroupingInstanceAtLoc(gunSW, sx1, sGunZ, gunOwnerS1);
	int gunSEPlacement = rmPlaceGroupingInstanceAtLoc(gunSE, sx5, sGunZ, gunOwnerS2);

	rmEchoInfo("gun owners: N1="+gunOwnerN1+" N2="+gunOwnerN2+" S1="+gunOwnerS1+" S2="+gunOwnerS2);
	// --- FLANK HARBOURS 3 / 4, same Venice trick as 1 / 2 -----------------
	// Their lane now curves around this coast, so each socket can dock onto it.
	int flank2SocketN = rmCreateObjectDef("flank harbour 5 socket");
	rmSetObjectDefTradeRouteID(flank2SocketN, tradeRouteN);
	rmAddObjectDefItem(flank2SocketN, "zpTradingPostCaptureNavalOriental", 1, 0.0);
	rmSetObjectDefMinDistance(flank2SocketN, 0.0);
	rmSetObjectDefMaxDistance(flank2SocketN, 0.5);
	rmPlaceObjectDefAtLoc(flank2SocketN, 0,
		nFlankX  + rmXMetersToFraction(h5SocketOffX),
		nFlank2Z + rmZMetersToFraction(h5SocketOffZ));
	vector flank2LocN = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(flank2SocketN, 0));

	// Trade harbour treasures.
	rmSetNuggetDifficulty(517, 517);
	// INSTANCE placement: its baked Nugget must stay targetable
	rmSetGroupingMinDistance(trade5, 0.0);
	rmSetGroupingMaxDistance(trade5, 0.01);
	rmAddGroupingToClass(trade5, rmClassID("classPlateau"));
	int trade5Placement = rmPlaceGroupingInstanceAtLoc(trade5,
		rmXMetersToFraction(xsVectorGetX(flank2LocN)) + rmXMetersToFraction(h5GroupOffX),
		rmZMetersToFraction(xsVectorGetZ(flank2LocN)) + rmZMetersToFraction(h5GroupOffZ), 0);

	int flank2SocketS = rmCreateObjectDef("flank harbour 6 socket");
	rmSetObjectDefTradeRouteID(flank2SocketS, tradeRouteS);
	rmAddObjectDefItem(flank2SocketS, "zpTradingPostCaptureNavalOriental", 1, 0.0);
	rmSetObjectDefMinDistance(flank2SocketS, 0.0);
	rmSetObjectDefMaxDistance(flank2SocketS, 0.5);
	rmPlaceObjectDefAtLoc(flank2SocketS, 0,
		sFlankX  + rmXMetersToFraction(h6SocketOffX),
		sFlank2Z + rmZMetersToFraction(h6SocketOffZ));
	vector flank2LocS = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(flank2SocketS, 0));

	// INSTANCE placement: its baked Nugget must stay targetable
	rmSetGroupingMinDistance(trade6, 0.0);
	rmSetGroupingMaxDistance(trade6, 0.01);
	rmAddGroupingToClass(trade6, rmClassID("classPlateau"));
	int trade6Placement = rmPlaceGroupingInstanceAtLoc(trade6,
		rmXMetersToFraction(xsVectorGetX(flank2LocS)) + rmXMetersToFraction(h6GroupOffX),
		rmZMetersToFraction(xsVectorGetZ(flank2LocS)) + rmZMetersToFraction(h6GroupOffZ), 0);

	placeShoreIsland(pirateN, nPirateX, nPirateZ);   // north island, back of its coast
	// PIRATE WATER FLAG - outside the grouping (a grouping selects as a
	// single unit, so a flag inside it can never be targeted). Same authored
	// spot it had in the camp XML. Socket is the grouping's LAST unit, so
	// socket id = flag id - 1 (000_independence_war.xs 1605-1617, verified).
	// CONVENTIONS: ints only, positive metre offsets, ""+id built inline.
	int pirateFlagDefN = rmCreateObjectDef("pirate water flag north");
	rmAddObjectDefItem(pirateFlagDefN, "zpPirateWaterSpawnFlag1", 1, 1.0);
	rmPlaceObjectDefAtLoc(pirateFlagDefN, 0,
		nPirateX + rmXMetersToFraction(13.2335),
		nPirateZ - rmZMetersToFraction(14.3030));

	placeShoreIsland(pirateS, sPirateX, sPirateZ);   // south island, back of its coast
	int pirateFlagDefS = rmCreateObjectDef("pirate water flag south");
	rmAddObjectDefItem(pirateFlagDefS, "zpPirateWaterSpawnFlag2", 1, 1.0);
	rmPlaceObjectDefAtLoc(pirateFlagDefS, 0,
		sPirateX - rmXMetersToFraction(13.5373),
		sPirateZ + rmZMetersToFraction(16.0665));


	int flankSocketN = rmCreateObjectDef("flank harbour socket north");
	rmSetObjectDefTradeRouteID(flankSocketN, tradeRouteN);
	rmAddObjectDefItem(flankSocketN, "zpTradingPostCaptureNavalOriental", 1, 0.0);
	rmSetObjectDefMinDistance(flankSocketN, 0.0);
	rmSetObjectDefMaxDistance(flankSocketN, 0.5);
	rmPlaceObjectDefAtLoc(flankSocketN, 0,
		nFlankX + rmXMetersToFraction(h3SocketOffX),
		nFlankZ + rmZMetersToFraction(h3SocketOffZ));
	vector flankLocN = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(flankSocketN, 0));

	// INSTANCE placement: its baked Nugget must stay targetable
	rmSetGroupingMinDistance(trade3, 0.0);
	rmSetGroupingMaxDistance(trade3, 0.01);
	rmAddGroupingToClass(trade3, rmClassID("classPlateau"));
	int trade3Placement = rmPlaceGroupingInstanceAtLoc(trade3,
		rmXMetersToFraction(xsVectorGetX(flankLocN)) + rmXMetersToFraction(h3GroupOffX),
		rmZMetersToFraction(xsVectorGetZ(flankLocN)) + rmZMetersToFraction(h3GroupOffZ), 0);

	int flankSocketS = rmCreateObjectDef("flank harbour socket south");
	rmSetObjectDefTradeRouteID(flankSocketS, tradeRouteS);
	rmAddObjectDefItem(flankSocketS, "zpTradingPostCaptureNavalOriental", 1, 0.0);
	rmSetObjectDefMinDistance(flankSocketS, 0.0);
	rmSetObjectDefMaxDistance(flankSocketS, 0.5);
	rmPlaceObjectDefAtLoc(flankSocketS, 0,
		sFlankX + rmXMetersToFraction(h4SocketOffX),
		sFlankZ + rmZMetersToFraction(h4SocketOffZ));
	vector flankLocS = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(flankSocketS, 0));

	// INSTANCE placement: its baked Nugget must stay targetable
	rmSetGroupingMinDistance(trade4, 0.0);
	rmSetGroupingMaxDistance(trade4, 0.01);
	rmAddGroupingToClass(trade4, rmClassID("classPlateau"));
	int trade4Placement = rmPlaceGroupingInstanceAtLoc(trade4,
		rmXMetersToFraction(xsVectorGetX(flankLocS)) + rmXMetersToFraction(h4GroupOffX),
		rmZMetersToFraction(xsVectorGetZ(flankLocS)) + rmZMetersToFraction(h4GroupOffZ), 0);
	// --- TRADE HARBOURS, the Venice way ----------------------------------
	// A capturable socket never works as part of a grouping (guide 19.7 step 5),
	// so it is placed SEPARATELY first, at the exact spot it used to occupy in
	// the XML. Tied to its trade route it docks itself onto the lane; the
	// grouping is then hung off its REAL position by the same offset, so the
	// harbour always lands wrapped around its own socket.
	int harbourSocketN = rmCreateObjectDef("harbour socket north");
	rmSetObjectDefTradeRouteID(harbourSocketN, tradeRouteN);
	rmAddObjectDefItem(harbourSocketN, "zpTradingPostCaptureNavalOriental", 1, 0.0);
	rmSetObjectDefMinDistance(harbourSocketN, 0.0);
	rmSetObjectDefMaxDistance(harbourSocketN, 0.5);
	rmPlaceObjectDefAtLoc(harbourSocketN, 0,
		nx3     + rmXMetersToFraction(hNSocketOffX),
		nTradeZ + rmZMetersToFraction(hNSocketOffZ));
	vector harbourLocN = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(harbourSocketN, 0));

	float tradeNX = rmXMetersToFraction(xsVectorGetX(harbourLocN)) + rmXMetersToFraction(hNGroupOffX);
	float tradeNZ = rmZMetersToFraction(xsVectorGetZ(harbourLocN)) + rmZMetersToFraction(hNGroupOffZ);
	// INSTANCE placement: its baked Nugget must stay targetable
	rmSetGroupingMinDistance(tradeN, 0.0);
	rmSetGroupingMaxDistance(tradeN, 0.01);
	rmAddGroupingToClass(tradeN, rmClassID("classPlateau"));
	int tradeNPlacement = rmPlaceGroupingInstanceAtLoc(tradeN,
		tradeNX,
		tradeNZ, 0);

	int harbourSocketS = rmCreateObjectDef("harbour socket south");
	rmSetObjectDefTradeRouteID(harbourSocketS, tradeRouteS);
	rmAddObjectDefItem(harbourSocketS, "zpTradingPostCaptureNavalOriental", 1, 0.0);
	rmSetObjectDefMinDistance(harbourSocketS, 0.0);
	rmSetObjectDefMaxDistance(harbourSocketS, 0.5);
	rmPlaceObjectDefAtLoc(harbourSocketS, 0,
		sx3     + rmXMetersToFraction(hSSocketOffX),
		sTradeZ + rmZMetersToFraction(hSSocketOffZ));
	vector harbourLocS = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(harbourSocketS, 0));

	float tradeSX = rmXMetersToFraction(xsVectorGetX(harbourLocS)) + rmXMetersToFraction(hSGroupOffX);
	float tradeSZ = rmZMetersToFraction(xsVectorGetZ(harbourLocS)) + rmZMetersToFraction(hSGroupOffZ);
	// INSTANCE placement: its baked Nugget must stay targetable
	rmSetGroupingMinDistance(tradeS, 0.0);
	rmSetGroupingMaxDistance(tradeS, 0.01);
	rmAddGroupingToClass(tradeS, rmClassID("classPlateau"));
	int tradeSPlacement = rmPlaceGroupingInstanceAtLoc(tradeS,
		tradeSX,
		tradeSZ, 0);

	rmSetStatusText("", 0.40);

	// ========================================================================
	//  7. THE CITY  -  painted last, over everything
	// ========================================================================

	// --- district terrain: a plateau bounded to its own grid ---------------
	// The box reaches nz6, so the island carries the empty back row as land.
	int cityNbox = rmCreateBoxConstraint("north city box",
		nx1 - margin - rmXTilesToFraction(cityExtendTilesN),
		nz1 - promenade, nx5 + flankProm, nz6 + margin, 0.01);
	int cityN = rmCreateArea("cityNorth");
	rmSetAreaSize(cityN, 0.4, 0.4);
	rmSetAreaLocation(cityN, nx3, nz3);
	rmSetAreaCoherence(cityN, 1.0);
	rmSetAreaBaseHeight(cityN, cityHeight);
	rmAddAreaInfluenceSegment(cityN, nx1, nz3, nx5, nz3);
	rmSetAreaTerrainType(cityN, "city\ground1_cob");
	rmSetAreaCliffType(cityN, "ZP City Italian");
	rmSetAreaCliffEdge(cityN, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityN, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityN, cityNbox);
	rmAddAreaToClass(cityN, rmClassID("classStreet"));
	rmAddAreaToClass(cityN, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityN, false);
	rmBuildArea(cityN);

	int citySbox = rmCreateBoxConstraint("south city box",
		sx1 - flankProm, sz6 - margin,
		sx5 + margin + rmXTilesToFraction(cityExtendTilesS),
		sz1 + promenade, 0.01);
	int cityS = rmCreateArea("citySouth");
	rmSetAreaSize(cityS, 0.4, 0.4);
	rmSetAreaLocation(cityS, sx3, sz3);
	rmSetAreaCoherence(cityS, 1.0);
	rmSetAreaBaseHeight(cityS, cityHeight);
	rmAddAreaInfluenceSegment(cityS, sx1, sz3, sx5, sz3);
	rmSetAreaTerrainType(cityS, "city\ground1_cob");
	rmSetAreaCliffType(cityS, "ZP City Italian");
	rmSetAreaCliffEdge(cityS, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityS, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityS, citySbox);
	rmAddAreaToClass(cityS, rmClassID("classStreet"));
	rmAddAreaToClass(cityS, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityS, false);
	rmBuildArea(cityS);

	// --- the hinterland: grassy country that makes each island a peninsula --
	// Built AFTER the districts, so classStreet already exists on the map and
	// the country can be told to keep off it. Distance 0.0 means it stops the
	// instant it touches the cobbles: flush against the street, never over it.
	// Same base height as the city, so there is no step where the two meet.

	float hinterDeep = rmZTilesToFraction(hinterReach);
	float hinterSide = rmXTilesToFraction(hinterWiden);
	// Where the grass is allowed to start. nz6 / sz6 are the row-6 cell CENTRES;
	// the district plateau runs a further "margin" past them, which is exactly
	// how much of row 6 the country used to swallow. Start at that outer edge.
	float hinterEdgeN = nz6 + margin + rmZTilesToFraction(hinterSetback);
	float hinterEdgeS = sz6 - margin - rmZTilesToFraction(hinterSetback);

	// How much room each peninsula ACTUALLY has: from its seam out to its
	// own map edge. hinterReach is only a cap - the map holds far less than
	// 90 tiles behind row 6, and anything sized off hinterDeep instead of
	// this lands beyond the world edge and silently builds nothing.
	float northRoom = 1.0 - hinterEdgeN;
	float southRoom = hinterEdgeS;
	if (northRoom > hinterDeep) { northRoom = hinterDeep; }
	if (southRoom > hinterDeep) { southRoom = hinterDeep; }

	// NORTH: runs from the back row out toward the top edge, aligned on x with
	// the district (its own promenade margins included) plus hinterWiden.
	int hinterNbox = rmCreateBoxConstraint("north hinterland box",
		nx1 - margin - hinterSide, hinterEdgeN,
		nx5 + flankProm + hinterSide, hinterEdgeN + northRoom, 0.01);
	int hinterN = rmCreateArea("hinterlandNorth");
	rmSetAreaSize(hinterN, 0.4, 0.4);
	rmSetAreaLocation(hinterN, nx3, hinterEdgeN + northRoom * 0.5);
	rmSetAreaCoherence(hinterN, 1.0);
	rmSetAreaBaseHeight(hinterN, cityHeight);
	rmSetAreaHeightBlend(hinterN, 2);
	rmSetAreaSmoothDistance(hinterN, 10);
	rmAddAreaInfluenceSegment(hinterN, nx1, hinterEdgeN, nx5, hinterEdgeN);
	rmSetAreaMix(hinterN, hinterMix);
	rmSetAreaCliffType(hinterN, hinterCliff);
	rmSetAreaCliffEdge(hinterN, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(hinterN, 0, 0.0, 1.0);
	rmAddAreaConstraint(hinterN, hinterNbox);
	rmAddAreaConstraint(hinterN, avoidStreet);
	rmAddAreaToClass(hinterN, rmClassID("classPlateau"));
	// city class too: the flank cliffs constrain off classStreet, so the
	// back countryside is now protected from them like the city itself
	rmAddAreaToClass(hinterN, rmClassID("classStreet"));
	rmSetAreaObeyWorldCircleConstraint(hinterN, false);
	rmBuildArea(hinterN);

	// SOUTH: the mirror, running toward the bottom edge.
	int hinterSbox = rmCreateBoxConstraint("south hinterland box",
		sx1 - flankProm - hinterSide, hinterEdgeS - southRoom,
		sx5 + margin + hinterSide, hinterEdgeS, 0.01);
	int hinterS = rmCreateArea("hinterlandSouth");
	rmSetAreaSize(hinterS, 0.4, 0.4);
	rmSetAreaLocation(hinterS, sx3, hinterEdgeS - southRoom * 0.5);
	rmSetAreaCoherence(hinterS, 1.0);
	rmSetAreaBaseHeight(hinterS, cityHeight);
	rmSetAreaHeightBlend(hinterS, 2);
	rmSetAreaSmoothDistance(hinterS, 10);
	rmAddAreaInfluenceSegment(hinterS, sx1, hinterEdgeS, sx5, hinterEdgeS);
	rmSetAreaMix(hinterS, hinterMix);
	rmSetAreaCliffType(hinterS, hinterCliff);
	rmSetAreaCliffEdge(hinterS, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(hinterS, 0, 0.0, 1.0);
	rmAddAreaConstraint(hinterS, hinterSbox);
	rmAddAreaConstraint(hinterS, avoidStreet);
	rmAddAreaToClass(hinterS, rmClassID("classPlateau"));
	// city class too: the flank cliffs constrain off classStreet, so the
	// back countryside is now protected from them like the city itself
	rmAddAreaToClass(hinterS, rmClassID("classStreet"));
	rmSetAreaObeyWorldCircleConstraint(hinterS, false);
	rmBuildArea(hinterS);


	// --- top terrain layer: italy_grass_dry over the whole countryside -----
	// Painted last of the terrain, so it covers the cliff area too; no height
	// or cliff calls, this only lays the mix down.
	int grassTopN = rmCreateArea("grassTopN");
	rmSetAreaSize(grassTopN, 0.4, 0.4);
	rmSetAreaLocation(grassTopN, nx3, hinterEdgeN + northRoom * 0.5);
	rmSetAreaCoherence(grassTopN, 1.0);
	rmSetAreaMix(grassTopN, hinterMix);
	rmAddAreaConstraint(grassTopN, hinterNbox);
	rmSetAreaObeyWorldCircleConstraint(grassTopN, false);
	rmBuildArea(grassTopN);

	int grassTopS = rmCreateArea("grassTopS");
	rmSetAreaSize(grassTopS, 0.4, 0.4);
	rmSetAreaLocation(grassTopS, sx3, hinterEdgeS - southRoom * 0.5);
	rmSetAreaCoherence(grassTopS, 1.0);
	rmSetAreaMix(grassTopS, hinterMix);
	rmAddAreaConstraint(grassTopS, hinterSbox);
	rmSetAreaObeyWorldCircleConstraint(grassTopS, false);
	rmBuildArea(grassTopS);

	// ===== FLANK CLIFFS, GUARD-AREA DESIGN ==================================
	// Two INVISIBLE areas (no height, no terrain - they paint nothing) lie
	// along the trade route corridors, each traced by just two influence
	// segments taken straight from the lane waypoints, coherence 0.6 so their
	// outline is blobby and DIFFERENT EVERY SEED. The cliffs then have no
	// shape of their own at all: perfectly coherent, no segments, no points -
	// they simply flood the pocket left between the city (flush) and the
	// guards. Wild edge, zero procedural surprises on the cliff itself.

	// --- the two invisible lane guards (the red ovals) ---------------------
	int guardW = rmCreateArea("west lane guard");
	rmSetAreaWarnFailure(guardW, false);
	rmSetAreaSize(guardW, 0.05, 0.05);
	rmSetAreaCoherence(guardW, 0.6);
	// TEST ONLY: raised above sea + painted, so the guard is visible.
	// Remove these two lines to make it invisible again.
	//rmSetAreaBaseHeight(guardW, 2.0);
	//rmSetAreaMix(guardW, "italy_grass");
	rmSetAreaLocation(guardW, 0.25, nRouteAsk);
	// along the north lane's west run...
	rmAddAreaInfluenceSegment(guardW, 0.50, nRouteAsk, 0.25, nRouteAsk);
	// ...and the north lane's west exit diagonal
	rmAddAreaInfluenceSegment(guardW, 0.25, nRouteAsk, 0.00, 0.30);
	rmSetAreaObeyWorldCircleConstraint(guardW, false);
	rmBuildArea(guardW);

	int guardE = rmCreateArea("east lane guard");
	rmSetAreaWarnFailure(guardE, false);
	rmSetAreaSize(guardE, 0.05, 0.05);
	rmSetAreaCoherence(guardE, 0.6);
	// TEST ONLY: raised above sea + painted, so the guard is visible.
	// Remove these two lines to make it invisible again.
	//rmSetAreaBaseHeight(guardE, 2.0);
	//rmSetAreaMix(guardE, "italy_grass");
	rmSetAreaLocation(guardE, 0.75, sRouteAsk);
	// along the south lane's east run...
	rmAddAreaInfluenceSegment(guardE, 0.50, sRouteAsk, 0.75, sRouteAsk);
	// ...and the south lane's east exit diagonal
	rmAddAreaInfluenceSegment(guardE, 0.75, sRouteAsk, 1.00, 0.70);
	rmSetAreaObeyWorldCircleConstraint(guardE, false);
	rmBuildArea(guardE);

	// cliffs keep a small gap off the guards; the guards carry the lanes
	// fallback only - the guards carry the lanes; this catches an overlap
	// if a route snaps somewhere a guard blob happens to miss
	int cliffLaneFallback = rmCreateTradeRouteDistanceConstraint("cliff lane fallback", 8.0);
	// the countryside sits flush (0.0) because it is AT city height; the
	int avoidGuardW = rmCreateAreaDistanceConstraint("off west guard", guardW, 4.0);
	int avoidGuardE = rmCreateAreaDistanceConstraint("off east guard", guardE, 4.0);
	int avoidGuardW_far = rmCreateAreaDistanceConstraint("off west guard far", guardW, 13.0);
	int avoidGuardE_far = rmCreateAreaDistanceConstraint("off east guard far", guardE, 13.0);
	int avoidGuardW_far2 = rmCreateAreaDistanceConstraint("off west guard far 2", guardW, 22.0);
	int avoidGuardE_far2 = rmCreateAreaDistanceConstraint("off east guard far 2", guardE, 22.0);

	// --- the cliffs: coherent blobs shaped ONLY by the constraints ---------
	int wildW = rmCreateArea("west flank cliff");
	rmSetAreaWarnFailure(wildW, false);
	// over-ask on purpose: the pocket between city, guard and rim is the
	// shape; the ask just has to be big enough to flood it
	rmSetAreaSize(wildW, 0.155, 0.155);
	rmSetAreaCoherence(wildW, 1.0);
	rmSetAreaLocation(wildW, 0.20, 0.75);
	rmSetAreaBaseHeight(wildW, cityHeight + balanceRise);
	rmSetAreaSmoothDistance(wildW, 5);
	rmSetAreaMix(wildW, hinterMix);
	rmSetAreaCliffType(wildW, gCliffTypeImpassable);
	rmSetAreaCliffEdge(wildW, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(wildW, 0, 0.0, 1.0);
	// no classCliff: the filler flows over this mass; open WATER is the
	// filler's outer fence instead (avoid-water constraint)
	// same constraint the back countryside uses: flush to the cobbles
	rmAddAreaConstraint(wildW, cliffOffStreet);
	rmAddAreaConstraint(wildW, cliffLaneFallback);
	rmAddAreaConstraint(wildW, avoidGuardW);
	rmAddAreaConstraint(wildW, avoidGuardE);
	rmSetAreaObeyWorldCircleConstraint(wildW, false);
	rmBuildArea(wildW);

	int wildE = rmCreateArea("east flank cliff");
	rmSetAreaWarnFailure(wildE, false);
	rmSetAreaSize(wildE, 0.15, 0.15);
	rmSetAreaCoherence(wildE, 1.0);
	rmSetAreaLocation(wildE, 0.80, 0.25);
	rmSetAreaBaseHeight(wildE, cityHeight + balanceRise);
	rmSetAreaSmoothDistance(wildE, 5);
	rmSetAreaMix(wildE, hinterMix);
	rmSetAreaCliffType(wildE, gCliffTypeImpassable);
	rmSetAreaCliffEdge(wildE, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(wildE, 0, 0.0, 1.0);
	// no classCliff: the filler flows over this mass; open WATER is the
	// filler's outer fence instead (avoid-water constraint)
	rmAddAreaConstraint(wildE, cliffOffStreet);
	rmAddAreaConstraint(wildE, cliffLaneFallback);
	rmAddAreaConstraint(wildE, avoidGuardW);
	rmAddAreaConstraint(wildE, avoidGuardE);
	rmSetAreaObeyWorldCircleConstraint(wildE, false);
	rmBuildArea(wildE);

// --- the cliffs: coherent blobs shaped ONLY by the constraints ---------
	int wildLowW = rmCreateArea("west flank cliff LOW");
	rmSetAreaWarnFailure(wildLowW, false);
	// over-ask on purpose: the pocket between city, guard and rim is the
	// shape; the ask just has to be big enough to flood it
	rmSetAreaSize(wildLowW, 0.145, 0.145);
	rmSetAreaCoherence(wildLowW, 1.0);
	rmSetAreaLocation(wildLowW, 0.20, 0.75);
	rmSetAreaBaseHeight(wildLowW, cityHeight);
	rmSetAreaSmoothDistance(wildLowW, 5);
	rmSetAreaMix(wildLowW, hinterMix);
	rmSetAreaCliffType(wildLowW, hinterCliff);
	rmSetAreaCliffEdge(wildLowW, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(wildLowW, 0, 0.0, 1.0);
	// no classCliff: the countryside FILLER must lie over this mass, and
	// its avoid-cliff constraint would otherwise reject every seed here
	// same constraint the back countryside uses: flush to the cobbles
	rmAddAreaConstraint(wildLowW, cliffOffStreet);
	rmAddAreaConstraint(wildLowW, cliffLaneFallback);
	rmAddAreaConstraint(wildLowW, avoidGuardW_far);
	//rmAddAreaConstraint(wildLowW, avoidWater10);
	rmAddAreaConstraint(wildLowW, avoidGuardE);
	rmSetAreaObeyWorldCircleConstraint(wildLowW, false);
	rmBuildArea(wildLowW);

	int wildLowE = rmCreateArea("east flank cliff LOW");
	rmSetAreaWarnFailure(wildLowE, false);
	rmSetAreaSize(wildLowE, 0.145, 0.145);
	rmSetAreaCoherence(wildLowE, 1.0);
	rmSetAreaLocation(wildLowE, 0.80, 0.25);
	rmSetAreaBaseHeight(wildLowE, cityHeight);
	rmSetAreaSmoothDistance(wildLowE, 5);
	rmSetAreaMix(wildLowE, hinterMix);
	rmSetAreaCliffType(wildLowE, hinterCliff);
	rmSetAreaCliffEdge(wildLowE, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(wildLowE, 0, 0.0, 1.0);
	// no classCliff: the countryside FILLER must lie over this mass, and
	// its avoid-cliff constraint would otherwise reject every seed here
	rmAddAreaConstraint(wildLowE, cliffOffStreet);
	rmAddAreaConstraint(wildLowE, cliffLaneFallback);
	rmAddAreaConstraint(wildLowE, avoidGuardW_far);
	rmAddAreaConstraint(wildLowE, avoidGuardE_far);
	//rmAddAreaConstraint(wildLowE, avoidWater10);
	rmSetAreaObeyWorldCircleConstraint(wildLowE, false);
	rmBuildArea(wildLowE);


	




	// --- trees, placed one at a time across each countryside ---------------
	// Four kinds of tree, one object def each, picked at random per spot.
	// Every proto here is one the census has already seen spawn on this map
	// or on Black Sea. Item count and cluster are your 4 / 5.0.
	int oneTree = rmCreateObjectDef("tree cypress");
	rmAddObjectDefItem(oneTree, hinterTree, treesPerSpot, treeSpotSpread);
	rmSetObjectDefMinDistance(oneTree, 0.0);
	rmSetObjectDefMaxDistance(oneTree, rmXTilesToFraction(treeJitter));
	rmSetObjectDefAllowOverlap(oneTree, true);
	rmAddObjectDefConstraint(oneTree, avoidCliff);
	int treeCarib = rmCreateObjectDef("tree caribbean");
	rmAddObjectDefItem(treeCarib, "TreeCaribbean", treesPerSpot, treeSpotSpread);
	rmSetObjectDefMinDistance(treeCarib, 0.0);
	rmSetObjectDefMaxDistance(treeCarib, rmXTilesToFraction(treeJitter));
	rmSetObjectDefAllowOverlap(treeCarib, true);
	rmAddObjectDefConstraint(treeCarib, avoidCliff);
	int treeLakes = rmCreateObjectDef("tree great lakes");
	rmAddObjectDefItem(treeLakes, "TreeGreatLakes", treesPerSpot, treeSpotSpread);
	rmSetObjectDefMinDistance(treeLakes, 0.0);
	rmSetObjectDefMaxDistance(treeLakes, rmXTilesToFraction(treeJitter));
	rmSetObjectDefAllowOverlap(treeLakes, true);
	rmAddObjectDefConstraint(treeLakes, avoidCliff);
	int treeEuca = rmCreateObjectDef("tree eucalyptus");
	rmAddObjectDefItem(treeEuca, "ypTreeEucalyptus", treesPerSpot, treeSpotSpread);
	rmSetObjectDefMinDistance(treeEuca, 0.0);
	rmSetObjectDefMaxDistance(treeEuca, rmXTilesToFraction(treeJitter));
	rmSetObjectDefAllowOverlap(treeEuca, true);
	rmAddObjectDefConstraint(treeEuca, avoidCliff);

	// Weighted draw: one slot = one chance in eight. Caribbean is the palm,
	// so it gets a single slot - any more and the countryside reads jungle.
	// To retune, move a slot from one kind to another.
	int gTreeKinds = xsArrayCreateInt(8, -1, "tree kinds");
	xsArraySetInt(gTreeKinds, 0, oneTree);     // cypress   3/8
	xsArraySetInt(gTreeKinds, 1, oneTree);
	xsArraySetInt(gTreeKinds, 2, oneTree);
	xsArraySetInt(gTreeKinds, 3, treeLakes);   // greatlakes 2/8
	xsArraySetInt(gTreeKinds, 4, treeLakes);
	xsArraySetInt(gTreeKinds, 5, treeEuca);    // eucalyptus 2/8
	xsArraySetInt(gTreeKinds, 6, treeEuca);
	xsArraySetInt(gTreeKinds, 7, treeCarib);   // caribbean  1/8

	float treeStepX = rmXTilesToFraction(treeStepTiles);
	float treeStepZ = rmZTilesToFraction(treeStepTiles);
	float tx = 0.0;
	float tz = 0.0;

	// north countryside: start just past the plateau edge, walk inland
	tz = hinterEdgeN + treeStepZ;
	for (tr = 0; < treeRows)
	{
		tx = nx1 - margin;
		for (tc = 0; < treeCols)
		{
			rmPlaceObjectDefAtLoc(xsArrayGetInt(gTreeKinds, rmRandInt(0, 7)),
				0, tx, tz, 1);
			tx = tx + treeStepX;
		}
		tz = tz + treeStepZ;
	}

	// south countryside: mirror, walking the other way
	tz = hinterEdgeS - treeStepZ;
	for (tr = 0; < treeRows)
	{
		tx = sx1 - flankProm;
		for (tc = 0; < treeCols)
		{
			rmPlaceObjectDefAtLoc(xsArrayGetInt(gTreeKinds, rmRandInt(0, 7)),
				0, tx, tz, 1);
			tx = tx + treeStepX;
		}
		tz = tz - treeStepZ;
	}



	rmSetStatusText("", 0.60);

	// --- the 24 Istanbul block groupings -----------------------------------
	int isHouse01   = rmCreateGrouping("is house 01",     "IS_House_Block_01");
	int isHouse02   = rmCreateGrouping("is house 02",     "IS_House_Block_02");
	int isHouse03   = rmCreateGrouping("is house 03",     "IS_House_Block_03");
	int isHouse04   = rmCreateGrouping("is house 04",     "IS_House_Block_04");
	int isHouse05   = rmCreateGrouping("is house 05",     "IS_House_Block_05");
	int isHouse06   = rmCreateGrouping("is house 06",     "IS_House_Block_06");
	int isEmbassy   = rmCreateGrouping("is embassy",      "IS_House_Block_Embassy");
	int isPark      = rmCreateGrouping("is park",         "IS_House_Block_Park");
	int isTreasure1 = rmCreateGrouping("is treasure 01",  "IS_House_Block_Treasure_01");
	int isTreasure2 = rmCreateGrouping("is treasure 02",  "IS_House_Block_Treasure_02");
	int isResAll1   = rmCreateGrouping("is res all 1",    "IS_Resource_Block_All1");
	int isResAll2   = rmCreateGrouping("is res all 2",    "IS_Resource_Block_All2");
	int isFood      = rmCreateGrouping("is food",         "IS_Resource_Block_Food1");
	int isGold      = rmCreateGrouping("is gold",         "IS_Resource_Block_Gold1");
	int isMenagere  = rmCreateGrouping("is menagere",     "IS_Resource_Block_Menagere");
	int isMosque    = rmCreateGrouping("is mosque",       "IS_Resource_Block_Mosque");
	int isWood      = rmCreateGrouping("is wood",         "IS_Resource_Block_Wood_01");
	int isAuditore  = rmCreateGrouping("is auditore",     "IS_Native_Block_Auditore_N");
	int isOrthodox  = rmCreateGrouping("is orthodox",     "IS_Native_Block_Orthodox");
	int isPhanar    = rmCreateGrouping("is phanar",       "IS_Native_Block_Phanar");
	int isPirates   = rmCreateGrouping("is pirates",      "IS_Native_Block_Pirates");
	int isSufi      = rmCreateGrouping("is sufi",         "IS_Native_Block_Sufi");
	int isSpcCity   = rmCreateGrouping("is spc istanbul", "IS_SPC_Istanbul");
	int isSpcMil    = rmCreateGrouping("is spc military", "IS_SPC_Military");

	gCityBlocks = xsArrayCreateInt(24, 0, "istanbul blocks");
	xsArraySetInt(gCityBlocks,  0, isHouse01);
	xsArraySetInt(gCityBlocks,  1, isHouse02);
	xsArraySetInt(gCityBlocks,  2, isHouse03);
	xsArraySetInt(gCityBlocks,  3, isHouse04);
	xsArraySetInt(gCityBlocks,  4, isHouse05);
	xsArraySetInt(gCityBlocks,  5, isHouse06);
	xsArraySetInt(gCityBlocks,  6, isEmbassy);
	xsArraySetInt(gCityBlocks,  7, isPark);
	xsArraySetInt(gCityBlocks,  8, isTreasure1);
	xsArraySetInt(gCityBlocks,  9, isTreasure2);
	xsArraySetInt(gCityBlocks, 10, isResAll1);
	xsArraySetInt(gCityBlocks, 11, isResAll2);
	xsArraySetInt(gCityBlocks, 12, isFood);
	xsArraySetInt(gCityBlocks, 13, isGold);
	xsArraySetInt(gCityBlocks, 14, isMenagere);
	xsArraySetInt(gCityBlocks, 15, isMosque);
	xsArraySetInt(gCityBlocks, 16, isWood);
	xsArraySetInt(gCityBlocks, 17, isAuditore);
	xsArraySetInt(gCityBlocks, 18, isOrthodox);
	xsArraySetInt(gCityBlocks, 19, isPhanar);
	xsArraySetInt(gCityBlocks, 20, isPirates);
	xsArraySetInt(gCityBlocks, 21, isSufi);
	xsArraySetInt(gCityBlocks, 22, isSpcCity);
	xsArraySetInt(gCityBlocks, 23, isSpcMil);

	// every block configured the same way: exact spot, grid-ready
	int blockID = 0;
	for (int i = 0; i < 24; i++)
	{
		blockID = xsArrayGetInt(gCityBlocks, i);
		rmSetGroupingMinDistance(blockID, 0.0);
		rmSetGroupingMaxDistance(blockID, 0.5);
		rmAddGroupingToClass(blockID, rmClassID("classBlock"));
	}

	// ---- THE GRAND BAZAAR: centre cell of each 5 x 5 grid -----------------
	// IS_Resource_Block_All2 - 15x15, 155 units, the market block.
	int bazaarN = rmCreateGrouping("grand bazaar north", "IS_Resource_Block_All2");
	rmSetGroupingMinDistance(bazaarN, 0.0);
	rmSetGroupingMaxDistance(bazaarN, 0.5);
	rmAddGroupingToClass(bazaarN, rmClassID("classBlock"));
	rmPlaceGroupingAtLoc(bazaarN, 0, nx3, nz3);

	int bazaarS = rmCreateGrouping("grand bazaar south", "IS_Resource_Block_All2");
	rmSetGroupingMinDistance(bazaarS, 0.0);
	rmSetGroupingMaxDistance(bazaarS, 0.5);
	rmAddGroupingToClass(bazaarS, rmClassID("classBlock"));
	rmPlaceGroupingAtLoc(bazaarS, 0, sx3, sz3);

	// ---- THE GREAT MOSQUES: one row from the bazaar toward the channel ----
	// Row z2 sits between the bazaar (z3) and the quay row (z1), same centre
	// column, so mosque and bazaar line up on the island's spine.
	int mosqueN = rmCreateGrouping("great mosque north", "IS_Resource_Block_Mosque");
	rmSetGroupingMinDistance(mosqueN, 0.0);
	rmSetGroupingMaxDistance(mosqueN, 0.5);
	rmAddGroupingToClass(mosqueN, rmClassID("classBlock"));
	rmPlaceGroupingAtLoc(mosqueN, 0, nx3, nz2);

	int mosqueS = rmCreateGrouping("great mosque south", "IS_Resource_Block_Mosque");
	rmSetGroupingMinDistance(mosqueS, 0.0);
	rmSetGroupingMaxDistance(mosqueS, 0.5);
	rmAddGroupingToClass(mosqueS, rmClassID("classBlock"));
	rmPlaceGroupingAtLoc(mosqueS, 0, sx3, sz2);

	// ---- THE PARKS: same centre column, the row right on the canal --------
	int parkN = rmCreateGrouping("park north", "IS_House_Block_Park");
	rmSetGroupingMinDistance(parkN, 0.0);
	rmSetGroupingMaxDistance(parkN, 0.5);
	rmAddGroupingToClass(parkN, rmClassID("classBlock"));
	rmPlaceGroupingAtLoc(parkN, 0, nx3, nz1);

	int parkS = rmCreateGrouping("park south", "IS_House_Block_Park");
	rmSetGroupingMinDistance(parkS, 0.0);
	rmSetGroupingMaxDistance(parkS, 0.5);
	rmAddGroupingToClass(parkS, rmClassID("classBlock"));
	rmPlaceGroupingAtLoc(parkS, 0, sx3, sz1);

	// ---- NATIVES: two per island, flanking the park on the canal shore ----
	// EUROPE = north island (Orthodox + Phanar), ASIA = south island (Sufi +
	// Auditore). Each pair is one RELIGIOUS and one ROYAL block, and a single
	// coin flip swaps which of the two takes the west slot on BOTH islands -
	// the 0000_paris_dansil.xs idiom (its lines 887-891).
	int natOrthodox = rmCreateGrouping("native orthodox", "IS_Native_Block_Orthodox");
	int natPhanar   = rmCreateGrouping("native phanar",   "IS_Native_Block_Phanar");
	int natSufi     = rmCreateGrouping("native sufi",     "IS_Native_Block_Sufi");
	// _N = 90 deg turned clones: the originals carry their socket on the SOUTH
	// edge, which faces the strait on the north island (easy to hit by ship -
	// game asymmetry). The turn moves it to the WEST edge, the side Phanar
	// always has. Orthodox/Sufi keep originals in the south; Auditore_N has a
	// CENTRAL socket (user-edited) and serves BOTH islands - no original left.
	int natOrthodoxN = rmCreateGrouping("native orthodox n", "IS_Native_Block_Orthodox_N");
	int natSufiN     = rmCreateGrouping("native sufi n",     "IS_Native_Block_Sufi_N");
	int natAuditoreN = rmCreateGrouping("native auditore n", "IS_Native_Block_Auditore_N");

	int natID = 0;
	int natList = xsArrayCreateInt(6, 0, "istanbul natives");
	xsArraySetInt(natList, 0, natOrthodox);
	xsArraySetInt(natList, 1, natPhanar);
	xsArraySetInt(natList, 2, natSufi);
	xsArraySetInt(natList, 3, natOrthodoxN);
	xsArraySetInt(natList, 4, natSufiN);
	xsArraySetInt(natList, 5, natAuditoreN);
	for (in = 0; < 6)
	{
		natID = xsArrayGetInt(natList, in);
		rmSetGroupingMinDistance(natID, 0.0);
		rmSetGroupingMaxDistance(natID, 0.5);
		rmAddGroupingToClass(natID, rmClassID("classBlock"));
	}

	// THE ONLY RULE: each island gets one RELIGIOUS and one ROYAL block.
	// Everything else is rolled, so the natives move between islands too:
	//   flipRel   - which religious (Orthodox / Sufi) takes the north island
	//   flipRoy   - which royal     (Phanar / Auditore) takes the north island
	//   flipSlotN - north island: does the religious sit west or east
	//   flipSlotS - same question on the south island
	// 4 independent coins = 16 layouts, every one of them legal.
	int flipRel   = rmRandInt(0, 100);
	int flipRoy   = rmRandInt(0, 100);
	int flipSlotN = rmRandInt(0, 100);
	int flipSlotS = rmRandInt(0, 100);

	int relNorth = natSufiN;      int relSouth = natOrthodox;
	if (flipRel < 50) { relNorth = natOrthodoxN;  relSouth = natSufi; }

	int royNorth = natAuditoreN;  int roySouth = natPhanar;
	if (flipRoy < 50) { royNorth = natPhanar;     roySouth = natAuditoreN; }

	int nWest = royNorth;         int nEast = relNorth;
	if (flipSlotN < 50) { nWest = relNorth;  nEast = royNorth; }

	int sWest = roySouth;         int sEast = relSouth;
	if (flipSlotS < 50) { sWest = relSouth;  sEast = roySouth; }

	rmEchoInfo("natives: flipRel=" + flipRel + " flipRoy=" + flipRoy
		+ " slotN=" + flipSlotN + " slotS=" + flipSlotS);

	// canal row (z1), pushed out to the OUTER columns so the two natives sit
	// at opposite ends of the waterfront with the park between them
	rmPlaceGroupingAtLoc(nWest, 0, nx1, nz1);
	rmPlaceGroupingAtLoc(nEast, 0, nx5, nz1);
	rmPlaceGroupingAtLoc(sWest, 0, sx1, sz1);
	rmPlaceGroupingAtLoc(sEast, 0, sx5, sz1);

	// ---- THE FORT: one fixed cell on the canal row -----------------------
	// It used to roll between the two gaps beside the park, which left the other
	// gap empty. Now it owns one gap outright; the other is a normal pool cell.
	// INSTANCE placement so its units can be targeted later.
	// The fort garrison: zpNuggetFortIstanbul, the Bohemian Castle cut down by
	// two (10 bodies / 12 points against its 12 / 14, cavalry counting double).
	rmSetNuggetDifficulty(520, 520);
	// _N = z-mirrored clone: the fort tower sits on the +z corner, which is
	// the waterside on the SOUTH island but inland up north - the mirror
	// puts the north tower on the strait like its southern twin
	int fortN = rmCreateGrouping("fort north", "IS_SPC_Military_N");
	rmSetGroupingMinDistance(fortN, 0.0);
	rmSetGroupingMaxDistance(fortN, 0.5);
	rmAddGroupingToClass(fortN, rmClassID("classBlock"));
	int fortPlacementN = rmPlaceGroupingInstanceAtLoc(fortN, nx2, nz1, 0);

	int fortS = rmCreateGrouping("fort south", "IS_SPC_Military");
	rmSetGroupingMinDistance(fortS, 0.0);
	rmSetGroupingMaxDistance(fortS, 0.5);
	rmAddGroupingToClass(fortS, rmClassID("classBlock"));
	int fortPlacementS = rmPlaceGroupingInstanceAtLoc(fortS, sx4, sz1, 0);

	// ---- THE FACTORIES: the corner cell backing onto the pirate camp ------
	// One row in from the back: row z4, on the flank-coast side. The pirates
	// are level with z5, so the factory sits one row channel-ward of them.
	// north island -> its +x (NE) side, south island -> its -x (SW) side.
	int factoryN = rmCreateGrouping("factory north", "IS_Resource_Block_All1");
	rmSetGroupingMinDistance(factoryN, 0.0);
	rmSetGroupingMaxDistance(factoryN, 0.5);
	rmAddGroupingToClass(factoryN, rmClassID("classBlock"));
	// INSTANCE placement (0000_Aztec_city.xs idiom): returns an id so specific
	// units inside the block can be targeted later with
	//     rmGetGroupingInstanceUnitByType(factoryPlacementN, "<proto>")
	// NOTE the argument order - player comes LAST here, not second.
	rmSetNuggetDifficulty(516, 516);   // factory treasure
	int factoryPlacementN = rmPlaceGroupingInstanceAtLoc(factoryN, nx5, nz4, 0);

	int factoryS = rmCreateGrouping("factory south", "IS_Resource_Block_All1");
	rmSetGroupingMinDistance(factoryS, 0.0);
	rmSetGroupingMaxDistance(factoryS, 0.5);
	rmAddGroupingToClass(factoryS, rmClassID("classBlock"));
	int factoryPlacementS = rmPlaceGroupingInstanceAtLoc(factoryS, sx1, sz4, 0);

	// ---- CITY CELL TABLE: every free cell, grouped by zone ---------------
	// NOT in here (fixed placements): the x3 spine (park/mosque/bazaar), the
	// menagerie beside the mosque, the fort and the two natives on z1, the
	// factory on z4, the two construction blocks on the z5 corners, and the
	// FORESTER, which now owns the middle cell of row 6 (x3,z6).
	// ROWS 5 AND 6 ARE THEIR OWN ZONE (*_BACK): houses only. Resource
	// buildings go through placeGroupings() into *_SUBURB, which is row 4
	// ONLY, so nothing economic can reach the back rows.
	// Each cell stores col*100 + row for the no-repeat house weave.
	const int N_CENTRE_START =  0;   const int N_CENTRE_END =  7;
	const int N_SUBURB_START =  8;   const int N_SUBURB_END = 11;   // row 4 only
	const int N_BACK_START   = 12;   const int N_BACK_END   = 20;   // rows 5 + 6
	const int S_CENTRE_START = 21;   const int S_CENTRE_END = 28;
	const int S_SUBURB_START = 29;   const int S_SUBURB_END = 32;   // row 4 only
	const int S_BACK_START   = 33;   const int S_BACK_END   = 41;   // rows 5 + 6
	const int NUM_CITY_LOCS  = 42;

	gCityLocs       = xsArrayCreateVector(NUM_CITY_LOCS, cInvalidVector, "city cells");
	gCityLocsStatus = xsArrayCreateBool(NUM_CITY_LOCS, false, "city cells taken");
	gCityCode       = xsArrayCreateInt(NUM_CITY_LOCS, 0, "city cell col*100+row");

	// north centre: the free z1 gap, then z2/z3 minus the menagerie cell
	xsArraySetVector(gCityLocs,  0, xsVectorSet(nx4, 0.0, nz1));   xsArraySetInt(gCityCode,  0, 401);
	xsArraySetVector(gCityLocs,  1, xsVectorSet(nx1, 0.0, nz2));   xsArraySetInt(gCityCode,  1, 102);
	xsArraySetVector(gCityLocs,  2, xsVectorSet(nx2, 0.0, nz2));   xsArraySetInt(gCityCode,  2, 202);
	xsArraySetVector(gCityLocs,  3, xsVectorSet(nx5, 0.0, nz2));   xsArraySetInt(gCityCode,  3, 502);
	xsArraySetVector(gCityLocs,  4, xsVectorSet(nx1, 0.0, nz3));   xsArraySetInt(gCityCode,  4, 103);
	xsArraySetVector(gCityLocs,  5, xsVectorSet(nx2, 0.0, nz3));   xsArraySetInt(gCityCode,  5, 203);
	xsArraySetVector(gCityLocs,  6, xsVectorSet(nx4, 0.0, nz3));   xsArraySetInt(gCityCode,  6, 403);
	xsArraySetVector(gCityLocs,  7, xsVectorSet(nx5, 0.0, nz3));   xsArraySetInt(gCityCode,  7, 503);
	// north suburb: ROW 4 ONLY, minus the factory corner
	xsArraySetVector(gCityLocs,  8, xsVectorSet(nx1, 0.0, nz4));   xsArraySetInt(gCityCode,  8, 104);
	xsArraySetVector(gCityLocs,  9, xsVectorSet(nx2, 0.0, nz4));   xsArraySetInt(gCityCode,  9, 204);
	xsArraySetVector(gCityLocs, 10, xsVectorSet(nx3, 0.0, nz4));   xsArraySetInt(gCityCode, 10, 304);
	xsArraySetVector(gCityLocs, 11, xsVectorSet(nx4, 0.0, nz4));   xsArraySetInt(gCityCode, 11, 404);
	// north back: FULL row 5 (edge cells 105/505 fill with houses whenever
	// no player start / constr block claims them first), row 6 minus forester
	xsArraySetVector(gCityLocs, 12, xsVectorSet(nx1, 0.0, nz5));   xsArraySetInt(gCityCode, 12, 105);
	xsArraySetVector(gCityLocs, 13, xsVectorSet(nx2, 0.0, nz5));   xsArraySetInt(gCityCode, 13, 205);
	xsArraySetVector(gCityLocs, 14, xsVectorSet(nx3, 0.0, nz5));   xsArraySetInt(gCityCode, 14, 305);
	xsArraySetVector(gCityLocs, 15, xsVectorSet(nx4, 0.0, nz5));   xsArraySetInt(gCityCode, 15, 405);
	xsArraySetVector(gCityLocs, 16, xsVectorSet(nx5, 0.0, nz5));   xsArraySetInt(gCityCode, 16, 505);
	xsArraySetVector(gCityLocs, 17, xsVectorSet(nx1, 0.0, nz6));   xsArraySetInt(gCityCode, 17, 106);
	xsArraySetVector(gCityLocs, 18, xsVectorSet(nx2, 0.0, nz6));   xsArraySetInt(gCityCode, 18, 206);
	xsArraySetVector(gCityLocs, 19, xsVectorSet(nx4, 0.0, nz6));   xsArraySetInt(gCityCode, 19, 406);
	xsArraySetVector(gCityLocs, 20, xsVectorSet(nx5, 0.0, nz6));   xsArraySetInt(gCityCode, 20, 506);

	// south centre + suburb
	xsArraySetVector(gCityLocs, 21, xsVectorSet(sx2, 0.0, sz1));   xsArraySetInt(gCityCode, 21, 201);
	xsArraySetVector(gCityLocs, 22, xsVectorSet(sx1, 0.0, sz2));   xsArraySetInt(gCityCode, 22, 102);
	xsArraySetVector(gCityLocs, 23, xsVectorSet(sx4, 0.0, sz2));   xsArraySetInt(gCityCode, 23, 402);
	xsArraySetVector(gCityLocs, 24, xsVectorSet(sx5, 0.0, sz2));   xsArraySetInt(gCityCode, 24, 502);
	xsArraySetVector(gCityLocs, 25, xsVectorSet(sx1, 0.0, sz3));   xsArraySetInt(gCityCode, 25, 103);
	xsArraySetVector(gCityLocs, 26, xsVectorSet(sx2, 0.0, sz3));   xsArraySetInt(gCityCode, 26, 203);
	xsArraySetVector(gCityLocs, 27, xsVectorSet(sx4, 0.0, sz3));   xsArraySetInt(gCityCode, 27, 403);
	xsArraySetVector(gCityLocs, 28, xsVectorSet(sx5, 0.0, sz3));   xsArraySetInt(gCityCode, 28, 503);
	xsArraySetVector(gCityLocs, 29, xsVectorSet(sx2, 0.0, sz4));   xsArraySetInt(gCityCode, 29, 204);
	xsArraySetVector(gCityLocs, 30, xsVectorSet(sx3, 0.0, sz4));   xsArraySetInt(gCityCode, 30, 304);
	xsArraySetVector(gCityLocs, 31, xsVectorSet(sx4, 0.0, sz4));   xsArraySetInt(gCityCode, 31, 404);
	xsArraySetVector(gCityLocs, 32, xsVectorSet(sx5, 0.0, sz4));   xsArraySetInt(gCityCode, 32, 504);

	// south back: mirrored, full row 5, row 6 minus the forester
	xsArraySetVector(gCityLocs, 33, xsVectorSet(sx1, 0.0, sz5));   xsArraySetInt(gCityCode, 33, 105);
	xsArraySetVector(gCityLocs, 34, xsVectorSet(sx2, 0.0, sz5));   xsArraySetInt(gCityCode, 34, 205);
	xsArraySetVector(gCityLocs, 35, xsVectorSet(sx3, 0.0, sz5));   xsArraySetInt(gCityCode, 35, 305);
	xsArraySetVector(gCityLocs, 36, xsVectorSet(sx4, 0.0, sz5));   xsArraySetInt(gCityCode, 36, 405);
	xsArraySetVector(gCityLocs, 37, xsVectorSet(sx5, 0.0, sz5));   xsArraySetInt(gCityCode, 37, 505);
	xsArraySetVector(gCityLocs, 38, xsVectorSet(sx1, 0.0, sz6));   xsArraySetInt(gCityCode, 38, 106);
	xsArraySetVector(gCityLocs, 39, xsVectorSet(sx2, 0.0, sz6));   xsArraySetInt(gCityCode, 39, 206);
	xsArraySetVector(gCityLocs, 40, xsVectorSet(sx4, 0.0, sz6));   xsArraySetInt(gCityCode, 40, 406);
	xsArraySetVector(gCityLocs, 41, xsVectorSet(sx5, 0.0, sz6));   xsArraySetInt(gCityCode, 41, 506);
	// shuffled in lockstep with gCityCode so cell and grid position stay paired
	shuffleCells(N_CENTRE_START, N_CENTRE_END);
	shuffleCells(N_SUBURB_START, N_SUBURB_END);
	shuffleCells(N_BACK_START, N_BACK_END);
	shuffleCells(S_CENTRE_START, S_CENTRE_END);
	shuffleCells(S_SUBURB_START, S_SUBURB_END);
	shuffleCells(S_BACK_START, S_BACK_END);
	// ---- CENTRE ZONE (rows z1-z3): bank, embassy, menagerie --------------
	// bank + embassy flank the mosque on z2, menagerie beside the bazaar on z3
	int bankN = rmCreateGrouping("bank north", "IS_Resource_Block_Gold1");
	rmSetGroupingMinDistance(bankN, 0.0);
	rmSetGroupingMaxDistance(bankN, 0.5);
	rmAddGroupingToClass(bankN, rmClassID("classBlock"));
	int bankS = rmCreateGrouping("bank south", "IS_Resource_Block_Gold1");
	rmSetGroupingMinDistance(bankS, 0.0);
	rmSetGroupingMaxDistance(bankS, 0.5);
	rmAddGroupingToClass(bankS, rmClassID("classBlock"));

	int embassyN = rmCreateGrouping("embassy north", "IS_House_Block_Embassy");
	rmSetGroupingMinDistance(embassyN, 0.0);
	rmSetGroupingMaxDistance(embassyN, 0.5);
	rmAddGroupingToClass(embassyN, rmClassID("classBlock"));
	int embassyS = rmCreateGrouping("embassy south", "IS_House_Block_Embassy");
	rmSetGroupingMinDistance(embassyS, 0.0);
	rmSetGroupingMaxDistance(embassyS, 0.5);
	rmAddGroupingToClass(embassyS, rmClassID("classBlock"));

	int menagerieN = rmCreateGrouping("menagerie north", "IS_Resource_Block_Menagere");
	rmSetGroupingMinDistance(menagerieN, 0.0);
	rmSetGroupingMaxDistance(menagerieN, 0.5);
	rmAddGroupingToClass(menagerieN, rmClassID("classBlock"));
	// fixed: right beside the mosque, on the flank-coast side of the spine
	rmSetNuggetDifficulty(98, 98);     // menagerie treasure
	int menageriePlacementN = rmPlaceGroupingInstanceAtLoc(menagerieN, nx4, nz2, 0);

	int menagerieS = rmCreateGrouping("menagerie south", "IS_Resource_Block_Menagere");
	rmSetGroupingMinDistance(menagerieS, 0.0);
	rmSetGroupingMaxDistance(menagerieS, 0.5);
	rmAddGroupingToClass(menagerieS, rmClassID("classBlock"));
	int menageriePlacementS = rmPlaceGroupingInstanceAtLoc(menagerieS, sx2, sz2, 0);

	// ---- THE WALLS: between each city and its countryside ----------------
	// One wall per island, INSTANCE-placed on the flank cliff. Four knobs,
	// all in TILES, all positive, separate per island:
	//   wallOutTiles*  distance past the city's countryside-facing edge
	//   wallOffTiles*  slide along the island; + = toward the BACK (row 6)
	// North island: countryside is WEST, back is +z. South: EAST, back is -z.
	int   wallOutTilesN = 6;
	int   wallOffTilesN = 2;
	int   wallOutTilesS = 6;
	int   wallOffTilesS = 1;

	// wall positions (shared by both wall placements)
	float wallXN = nx1 - margin - rmXTilesToFraction(wallOutTilesN);
	float wallZN = (nz3 + nz4) * 0.5 + rmZTilesToFraction(wallOffTilesN);
	float wallXS = sx5 + margin + rmXTilesToFraction(wallOutTilesS);
	float wallZS = (sz3 + sz4) * 0.5 - rmZTilesToFraction(wallOffTilesS);

	int wallSW = rmCreateGrouping("wall sw", "IS_Wall_SW");
	rmSetGroupingMinDistance(wallSW, 0.0);
	rmSetGroupingMaxDistance(wallSW, 0.5);
	int wallPlacementSW = rmPlaceGroupingInstanceAtLoc(wallSW, wallXN, wallZN, 0);

	// the 180-degree clone, on the south island's east flank
	int wallNE = rmCreateGrouping("wall ne", "IS_Wall_NE");
	rmSetGroupingMinDistance(wallNE, 0.0);
	rmSetGroupingMaxDistance(wallNE, 0.5);
	int wallPlacementNE = rmPlaceGroupingInstanceAtLoc(wallNE, wallXS, wallZS, 0);

	// ---- CITY PLAYERS: TC block + 2x2 buildable area ---------------------
	// Each city player gets IS_SPC_PlayerStart (carries a baked TownCenter,
	// the Florence way) on row 5 plus THREE IS_SPC_Block_Constr around it:
	// one beside the TC on row 5, two behind on row 6 - a 2x2 per player on
	// north columns {1,2} and {4,5}, rotated 180 deg on the south island
	// ({5,4} and {2,1}). The middle column stays in the house pool.
	// Placed BEFORE the house weave: houses skip occupied cells, so an empty
	// city slot fills with houses - no fallback branches needed.
	int blockStartCity = rmCreateGrouping("player city start", "IS_SPC_PlayerStart");
	rmSetGroupingMinDistance(blockStartCity, 0.0);
	rmSetGroupingMaxDistance(blockStartCity, 0.5);
	rmAddGroupingToClass(blockStartCity, rmClassID("classBlock"));
	int blockConstrCity = rmCreateGrouping("player city constr", "IS_SPC_Block_Constr");
	rmSetGroupingMinDistance(blockConstrCity, 0.0);
	rmSetGroupingMaxDistance(blockConstrCity, 0.5);
	rmAddGroupingToClass(blockConstrCity, rmClassID("classBlock"));

	// difficulty latch for anything baked in the start blocks - without this
	// they inherit the menagerie's 98 from the latch above
	rmSetNuggetDifficulty(1, 1);

	if (cNumberTeams == 2)
	{
		// blocks mirror the seat logic: one city seat = the harbour-corner
		// block + its own constr cells only; the wall-side columns stay in
		// the house pool. Two seats = the exact original sequence.
		if (citySeatsN == 2)
		{
			rmPlaceGroupingAtLoc(blockStartCity, firstDefender, nx2, nz5);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, nx1, nz5);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, nx1, nz6);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, nx2, nz6);
			rmPlaceGroupingAtLoc(blockStartCity, secondDefender, nx5, nz5);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, nx4, nz5);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, nx4, nz6);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, nx5, nz6);
		}
		if (citySeatsN == 1)
		{
			rmPlaceGroupingAtLoc(blockStartCity, firstDefender, nx5, nz5);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, nx4, nz5);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, nx4, nz6);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, nx5, nz6);
		}
		if (citySeatsS == 2)
		{
			rmPlaceGroupingAtLoc(blockStartCity, firstAttacker, sx4, sz5);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, sx5, sz5);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, sx5, sz6);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, sx4, sz6);
			rmPlaceGroupingAtLoc(blockStartCity, secondAttacker, sx1, sz5);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, sx2, sz5);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, sx2, sz6);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, sx1, sz6);
		}
		if (citySeatsS == 1)
		{
			rmPlaceGroupingAtLoc(blockStartCity, firstAttacker, sx1, sz5);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, sx2, sz5);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, sx2, sz6);
			rmPlaceGroupingAtLoc(blockConstrCity, 0, sx1, sz6);
		}
	}

	// ---- SUBURB ZONE blocks ----------------------------------------------
	int millN = rmCreateGrouping("mill north", "IS_Resource_Block_Food1");
	rmSetGroupingMinDistance(millN, 0.0);  rmSetGroupingMaxDistance(millN, 0.5);
	rmAddGroupingToClass(millN, rmClassID("classBlock"));
	int millS = rmCreateGrouping("mill south", "IS_Resource_Block_Food1");
	rmSetGroupingMinDistance(millS, 0.0);  rmSetGroupingMaxDistance(millS, 0.5);
	rmAddGroupingToClass(millS, rmClassID("classBlock"));

	int woodN = rmCreateGrouping("wood north", "IS_Resource_Block_Wood_01");
	rmSetGroupingMinDistance(woodN, 0.0);  rmSetGroupingMaxDistance(woodN, 0.5);
	rmAddGroupingToClass(woodN, rmClassID("classBlock"));
	int woodS = rmCreateGrouping("wood south", "IS_Resource_Block_Wood_01");
	rmSetGroupingMinDistance(woodS, 0.0);  rmSetGroupingMaxDistance(woodS, 0.5);
	rmAddGroupingToClass(woodS, rmClassID("classBlock"));

	// ---- ZONE LISTS: each building takes a random cell OF ITS ZONE --------
	int nCentreBlocks = xsArrayCreateInt(2, -1, "north centre blocks");
	xsArraySetInt(nCentreBlocks, 0, bankN);
	xsArraySetInt(nCentreBlocks, 1, embassyN);
	rmSetNuggetDifficulty(518, 518);   // embassy treasure
	placeGroupings(nCentreBlocks, N_CENTRE_START);

	int sCentreBlocks = xsArrayCreateInt(2, -1, "south centre blocks");
	xsArraySetInt(sCentreBlocks, 0, bankS);
	xsArraySetInt(sCentreBlocks, 1, embassyS);
	placeGroupings(sCentreBlocks, S_CENTRE_START);

	int nSuburbBlocks = xsArrayCreateInt(1, -1, "north suburb blocks");
	xsArraySetInt(nSuburbBlocks, 0, millN);
	placeGroupings(nSuburbBlocks, N_SUBURB_START);
	// forester: fixed on the middle cell of row 6, out of the pool
	rmPlaceGroupingAtLoc(woodN, 0, nx3, nz6);

	int sSuburbBlocks = xsArrayCreateInt(1, -1, "south suburb blocks");
	xsArraySetInt(sSuburbBlocks, 0, millS);
	placeGroupings(sSuburbBlocks, S_SUBURB_START);
	rmPlaceGroupingAtLoc(woodS, 0, sx3, sz6);

	// ---- TREASURES: one of each per island, random cell -------------------
	// Paris idiom (lines 1057-1059): filler() drops them into the first free
	// cell of the shuffled range, so their spot changes every seed. They go in
	// BEFORE the houses so they always get a slot.
	// Treasure houses draw from the Istanbul city set: the six Florence city
	// nuggets (difficulty 303) cloned as 519 with Janissary / Haramija guards,
	// plus a 519 guillotine entry matching the proto these groupings bake.
	rmSetNuggetDifficulty(519, 519);
	filler(isTreasure1, N_CENTRE_START, N_SUBURB_END);
	filler(isTreasure2, N_CENTRE_START, N_SUBURB_END);
	filler(isTreasure1, S_CENTRE_START, S_SUBURB_END);
	filler(isTreasure2, S_CENTRE_START, S_SUBURB_END);

	// ---- HOUSES: fill every cell the zone lists did not use ---------------
	// Paris idiom (0000_paris_dansil.xs lines 1062-1085): pick a random house
	// type, drop it in the first free cell, repeat until the range is full.
	// Only the variable cells in gCityLocs are candidates - the spine, natives,
	// fort, factory and construction corners were never added to the table.
	int houseGroupings = xsArrayCreateInt(6, -1, "house block list");
	xsArraySetInt(houseGroupings, 0, isHouse01);
	xsArraySetInt(houseGroupings, 1, isHouse02);
	xsArraySetInt(houseGroupings, 2, isHouse03);
	xsArraySetInt(houseGroupings, 3, isHouse04);
	xsArraySetInt(houseGroupings, 4, isHouse05);
	xsArraySetInt(houseGroupings, 5, isHouse06);

	gHouseBlocks = houseGroupings;
	fillHouses(N_CENTRE_START, N_BACK_END, rmRandInt(0, 5));
	fillHouses(S_CENTRE_START, S_BACK_END, rmRandInt(0, 5));

	// ---- WALL-DOCK CLIFFS - Paris idiom, built LAST -----------------------
	// Placed AFTER every city block, so no dock can deform a cell a block
	// still needs (the no-spawn risk), and dockAvoidBlocks now reacts to the
	// PLACED blocks. Derived numbers, not guesses:
	//   channel gap wall-end->promenade = 14.2 t; back gap ->hinterland = 12.2 t
	//   seal area ~284 t worst case -> dockSizeTiles 550 = ~2x slack, r 13.2 t
	//   sea docks sit 6 t sea-ward AND 6 t away from the gun (seed 33 m from
	//   the nearest gun unit; 24 m gun field blankets the river approach)
	int   dockSizeTiles = 450;
	// The two BACK-END docks (1 and 4) reach the map edge, so they need more
	// volume than the sea-side pair to close the gap against the wall.
	int   dockSizeTilesBack = 780;
	int   wallDockTiles = 47;  // back-end seed distance past the wall end
	int   dockSeaTiles  = 1;   // sea-dock x-offset off the wall line

	// north wall, back end
	int dock1 = rmCreateArea("wall dock 1");
	rmSetAreaWarnFailure(dock1, false);
	rmSetAreaSize(dock1, rmAreaTilesToFraction(dockSizeTilesBack),
		rmAreaTilesToFraction(dockSizeTilesBack));
	rmSetAreaCoherence(dock1, 0.93);
	rmSetAreaLocation(dock1, wallXN, wallZN + rmZTilesToFraction(wallDockTiles));
	// Reach the NORTH map edge so nothing can walk round the back of the wall.
	// Not bigger - just elongated onto the edge (the guardW/guardE idiom).
	rmAddAreaInfluenceSegment(dock1, wallXN, wallZN + rmZTilesToFraction(wallDockTiles),
		wallXN, 1.0);
	rmSetAreaBaseHeight(dock1, cityHeight + balanceRise);
	rmSetAreaHeightBlend(dock1, 3);
	rmSetAreaMix(dock1, hinterMix);
	rmSetAreaCliffType(dock1, gCliffTypeImpassable);
	rmSetAreaCliffEdge(dock1, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(dock1, 0, 0.0, 1.0);
	rmAddAreaToClass(dock1, rmClassID("classCliff"));
	rmAddAreaConstraint(dock1, avoidWallObj);
	rmAddAreaConstraint(dock1, dockAvoidBlocks);
	rmAddAreaConstraint(dock1, cliffLaneFallback);
	rmAddAreaConstraint(dock1, avoidGuardW);
	rmAddAreaConstraint(dock1, avoidGuardE);
	rmSetAreaObeyWorldCircleConstraint(dock1, false);
	rmBuildArea(dock1);

	// north wall, channel end - out at sea, clear of the gun
	int dock2 = rmCreateArea("wall dock 2");
	rmSetAreaWarnFailure(dock2, false);
	rmSetAreaSize(dock2, rmAreaTilesToFraction(dockSizeTiles),
		rmAreaTilesToFraction(dockSizeTiles));
	rmSetAreaCoherence(dock2, 0.93);
	// centred in the MEASURED water band (front .. real lane) so the seed
	// survives any +/-4 t route snap - never derived from the ASKED lane
	rmSetAreaLocation(dock2, wallXN - rmXTilesToFraction(dockSeaTiles),
		(nz1 - promenade + nRouteZ) * 0.5 + rmZTilesToFraction(13));
	rmSetAreaBaseHeight(dock2, cityHeight + balanceRise);
	rmSetAreaHeightBlend(dock2, 3);
	rmSetAreaMix(dock2, hinterMix);
	rmSetAreaCliffType(dock2, gCliffTypeImpassable);
	rmSetAreaCliffEdge(dock2, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(dock2, 0, 0.0, 1.0);
	rmAddAreaToClass(dock2, rmClassID("classCliff"));
	rmAddAreaConstraint(dock2, avoidWallObj);
	rmAddAreaConstraint(dock2, dockAvoidBlocks);
	rmAddAreaConstraint(dock2, dockAvoidGunClass);
	rmAddAreaConstraint(dock2, cliffLaneFallback);
	rmSetAreaObeyWorldCircleConstraint(dock2, false);
	rmBuildArea(dock2);

	// south wall, channel end - the mirror
	int dock3 = rmCreateArea("wall dock 3");
	rmSetAreaWarnFailure(dock3, false);
	rmSetAreaSize(dock3, rmAreaTilesToFraction(dockSizeTiles),
		rmAreaTilesToFraction(dockSizeTiles));
	rmSetAreaCoherence(dock3, 0.93);
	rmSetAreaLocation(dock3, wallXS + rmXTilesToFraction(dockSeaTiles),
		(sz1 + promenade + sRouteZ) * 0.5 - rmZTilesToFraction(11));
	rmSetAreaBaseHeight(dock3, cityHeight + balanceRise);
	rmSetAreaHeightBlend(dock3, 3);
	rmSetAreaMix(dock3, hinterMix);
	rmSetAreaCliffType(dock3, gCliffTypeImpassable);
	rmSetAreaCliffEdge(dock3, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(dock3, 0, 0.0, 1.0);
	rmAddAreaToClass(dock3, rmClassID("classCliff"));
	rmAddAreaConstraint(dock3, avoidWallObj);
	rmAddAreaConstraint(dock3, dockAvoidBlocks);
	rmAddAreaConstraint(dock3, dockAvoidGunClass);
	rmAddAreaConstraint(dock3, cliffLaneFallback);
	rmSetAreaObeyWorldCircleConstraint(dock3, false);
	rmBuildArea(dock3);

	// south wall, back end
	int dock4 = rmCreateArea("wall dock 4");
	rmSetAreaWarnFailure(dock4, false);
	rmSetAreaSize(dock4, rmAreaTilesToFraction(dockSizeTilesBack),
		rmAreaTilesToFraction(dockSizeTilesBack));
	rmSetAreaCoherence(dock4, 0.93);
	rmSetAreaLocation(dock4, wallXS, wallZS - rmZTilesToFraction(wallDockTiles));
	// ...and dock4 reaches the SOUTH map edge, the mirror of dock1.
	rmAddAreaInfluenceSegment(dock4, wallXS, wallZS - rmZTilesToFraction(wallDockTiles),
		wallXS, 0.0);
	rmSetAreaBaseHeight(dock4, cityHeight + balanceRise);
	rmSetAreaHeightBlend(dock4, 3);
	rmSetAreaMix(dock4, hinterMix);
	rmSetAreaCliffType(dock4, gCliffTypeImpassable);
	rmSetAreaCliffEdge(dock4, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(dock4, 0, 0.0, 1.0);
	rmAddAreaToClass(dock4, rmClassID("classCliff"));
	rmAddAreaConstraint(dock4, avoidWallObj);
	rmAddAreaConstraint(dock4, dockAvoidBlocks);
	rmAddAreaConstraint(dock4, cliffLaneFallback);
	rmAddAreaConstraint(dock4, avoidGuardW);
	rmAddAreaConstraint(dock4, avoidGuardE);
	rmSetAreaObeyWorldCircleConstraint(dock4, false);
	rmBuildArea(dock4);

	// ---- COUNTRYSIDE FILLER - the valley floors --------------------------
	// Built LAST, so it sees every cliff (wild masses, terraces, wall docks).
	// Floods the landlocked valleys at city height with dry grass and gentle
	// elevation; the constraints are the shape:
	//   fillAvoidCliff    2 m off classCliff - hugs the cliff feet
	//   avoidWallObj      0.001 m off the WALL BUILDINGS only - the fill
	//                     overflows the rest of the wall grouping
	//   cliffLaneFallback 8 m lane insurance so raised ground can never pave
	//                     a trade route (stated addition beyond your two)

	// west valley, between city, wall, terraces and wild cliffs
	int fillW = rmCreateArea("countryside fill w");
	rmSetAreaWarnFailure(fillW, false);
	// over-ask: the cliff and building constraints ARE the shape
	rmSetAreaSize(fillW, 0.13, 0.13);
	rmSetAreaCoherence(fillW, 1.0);
	rmSetAreaLocation(fillW, 0.20, 0.75);
	rmSetAreaBaseHeight(fillW, cityHeight);
	rmSetAreaHeightBlend(fillW, 2);
	rmSetAreaSmoothDistance(fillW, 5);
	rmSetAreaMix(fillW, hinterMix);
	rmSetAreaElevationType(fillW, cElevTurbulence);
	rmSetAreaElevationVariation(fillW, 6.0);
	rmAddAreaConstraint(fillW, fillAvoidCliff);
	rmAddAreaConstraint(fillW, avoidGuardW_far2);
	rmAddAreaConstraint(fillW, avoidGuardE_far2);
	rmAddAreaConstraint(fillW, avoidWallObj);
	rmAddAreaConstraint(fillW, avoidWallObjLong);
	//rmAddAreaConstraint(fillW, cliffLaneFallback);
	//rmSetAreaObeyWorldCircleConstraint(fillW, false);
	rmBuildArea(fillW);

	// east valley - the mirror
	int fillE = rmCreateArea("countryside fill e");
	rmSetAreaWarnFailure(fillE, false);
	// over-ask: the cliff and building constraints ARE the shape
	rmSetAreaSize(fillE, 0.13, 0.13);
	rmSetAreaCoherence(fillE, 1.0);
	rmSetAreaLocation(fillE, 0.80, 0.25);
	rmSetAreaBaseHeight(fillE, cityHeight);
	rmSetAreaHeightBlend(fillE, 2);
	rmSetAreaSmoothDistance(fillE, 5);
	rmSetAreaMix(fillE, hinterMix);
	rmSetAreaElevationType(fillE, cElevTurbulence);
	rmSetAreaElevationVariation(fillE, 6.0);
	rmAddAreaConstraint(fillE, fillAvoidCliff);
	rmAddAreaConstraint(fillE, avoidGuardW_far2);
	rmAddAreaConstraint(fillE, avoidGuardE_far2);
	rmAddAreaConstraint(fillE, avoidWallObj);
	rmAddAreaConstraint(fillE, avoidWallObjLong);
	//rmAddAreaConstraint(fillE, cliffLaneFallback);
	//rmSetAreaObeyWorldCircleConstraint(fillE, false);
	rmBuildArea(fillE);



	// --- the two 5 x 5 grids, row by row -----------------------------------
	// ===== BLOCK PLACEMENT COMMENTED OUT for the restructure =====
	// Everything else is intact: grid coordinates (nx1..nx5 / nz1..nz5, sx/sz),
	// all 24 IS_ grouping definitions, the registry and the min/max/class rules.
	// Un-comment these lines to put the city back exactly as it was.
	// NORTH island: row 1 hugs the north lane, row 5 is farthest inland.
//	cityBlock(nx1, nz1); cityBlock(nx2, nz1); cityBlock(nx3, nz1); cityBlock(nx4, nz1); cityBlock(nx5, nz1);
//	cityBlock(nx1, nz2); cityBlock(nx2, nz2); cityBlock(nx3, nz2); cityBlock(nx4, nz2); cityBlock(nx5, nz2);
//	cityBlock(nx1, nz3); cityBlock(nx2, nz3); cityBlock(nx3, nz3); cityBlock(nx4, nz3); cityBlock(nx5, nz3);
//	cityBlock(nx1, nz4); cityBlock(nx2, nz4); cityBlock(nx3, nz4); cityBlock(nx4, nz4); cityBlock(nx5, nz4);
//	cityBlock(nx1, nz5); cityBlock(nx2, nz5); cityBlock(nx3, nz5); cityBlock(nx4, nz5); cityBlock(nx5, nz5);

	// SOUTH island: row 1 hugs the south lane, row 5 is farthest inland.
//	cityBlock(sx1, sz1); cityBlock(sx2, sz1); cityBlock(sx3, sz1); cityBlock(sx4, sz1); cityBlock(sx5, sz1);
//	cityBlock(sx1, sz2); cityBlock(sx2, sz2); cityBlock(sx3, sz2); cityBlock(sx4, sz2); cityBlock(sx5, sz2);
//	cityBlock(sx1, sz3); cityBlock(sx2, sz3); cityBlock(sx3, sz3); cityBlock(sx4, sz3); cityBlock(sx5, sz3);
//	cityBlock(sx1, sz4); cityBlock(sx2, sz4); cityBlock(sx3, sz4); cityBlock(sx4, sz4); cityBlock(sx5, sz4);
//	cityBlock(sx1, sz5); cityBlock(sx2, sz5); cityBlock(sx3, sz5); cityBlock(sx4, sz5); cityBlock(sx5, sz5);

	// ---- shoreline decoration, after every block is down ------------------
	int decoN = rmCreateGrouping("deco shoreline west", decoShoreline);
	rmSetGroupingMinDistance(decoN, 0.0);
	rmSetGroupingMaxDistance(decoN, 0.01);
	int decoN2 = rmCreateGrouping("deco shoreline east", decoShoreline);
	rmSetGroupingMinDistance(decoN2, 0.0);
	rmSetGroupingMaxDistance(decoN2, 0.01);

	// Sequence along the canal shore:  gun -> deco -> trade -> deco -> gun
	// Measured from the lane and from each gun, so every knob stays positive.
	float decoZ = nRouteZ + rmZTilesToFraction(decoNLaneDist);
	float decoWestX = nx1 + rmXTilesToFraction(decoNWestFromGun);
	float decoEastX = nx5 - rmXTilesToFraction(decoNEastFromGun);
	// SOUTH island: the same three distances, mirrored - its lane is on the
	// other side, so the island runs -z and its guns are sx1 / sx5.
	int decoS  = rmCreateGrouping("deco shoreline s west", decoShorelineS);
	rmSetGroupingMinDistance(decoS, 0.0);
	rmSetGroupingMaxDistance(decoS, 0.01);
	int decoS2 = rmCreateGrouping("deco shoreline s east", decoShorelineS);
	rmSetGroupingMinDistance(decoS2, 0.0);
	rmSetGroupingMaxDistance(decoS2, 0.01);

	float decoSZ = sRouteZ - rmZTilesToFraction(decoSLaneDist);
	float decoSWestX = sx1 + rmXTilesToFraction(decoSWestFromGun);
	float decoSEastX = sx5 - rmXTilesToFraction(decoSEastFromGun);

	rmEchoInfo("deco: nRouteZ=" + nRouteZ + " decoNLaneDist=" + decoNLaneDist);
	rmEchoInfo("deco: decoZ=" + decoZ + " westX=" + decoWestX + " eastX=" + decoEastX + " tradeNX=" + tradeNX);
	rmPlaceGroupingAtLoc(decoN,  0, decoWestX, decoZ);
	rmPlaceGroupingAtLoc(decoN2, 0, decoEastX, decoZ);
	rmPlaceGroupingAtLoc(decoS,  0, decoSWestX, decoSZ);
	rmPlaceGroupingAtLoc(decoS2, 0, decoSEastX, decoSZ);

	// ---- NE coast of the north island: one piece per gap ------------------
	int decoNE  = rmCreateGrouping("deco shoreline ne 1", decoShorelineNE);
	rmSetGroupingMinDistance(decoNE, 0.0);
	rmSetGroupingMaxDistance(decoNE, 0.01);
	int decoNE2 = rmCreateGrouping("deco shoreline ne 2", decoShorelineNE);
	rmSetGroupingMinDistance(decoNE2, 0.0);
	rmSetGroupingMaxDistance(decoNE2, 0.01);

	// same coast line as the flank harbours, and the midpoint of each gap
	int decoNE3 = rmCreateGrouping("deco shoreline ne 3", decoShorelineNE);
	rmSetGroupingMinDistance(decoNE3, 0.0);
	rmSetGroupingMaxDistance(decoNE3, 0.01);

	float decoNEX  = nx5 + flankProm + rmXTilesToFraction(decoNEDist);
	float decoNEZ1 = (nFlank2Z + nFlankZ) * 0.5;   // between harbour 5 and harbour 3
	float decoNEZ2 = (nFlankZ + nPirateZ) * 0.5;   // between harbour 3 and the pirates
	float decoNEZ3 = nPirateZ + rmZTilesToFraction(decoNEBehindPir);   // behind the pirates
	rmPlaceGroupingAtLoc(decoNE,  0, decoNEX, decoNEZ1);
	rmPlaceGroupingAtLoc(decoNE2, 0, decoNEX, decoNEZ2);
	rmPlaceGroupingAtLoc(decoNE3, 0, decoNEX, decoNEZ3);

	// ---- SW coast of the south island: mirror of the NE pair --------------
	int decoSW  = rmCreateGrouping("deco shoreline sw 1", decoShorelineSW);
	rmSetGroupingMinDistance(decoSW, 0.0);
	rmSetGroupingMaxDistance(decoSW, 0.01);
	int decoSW2 = rmCreateGrouping("deco shoreline sw 2", decoShorelineSW);
	rmSetGroupingMinDistance(decoSW2, 0.0);
	rmSetGroupingMaxDistance(decoSW2, 0.01);

	int decoSW3 = rmCreateGrouping("deco shoreline sw 3", decoShorelineSW);
	rmSetGroupingMinDistance(decoSW3, 0.0);
	rmSetGroupingMaxDistance(decoSW3, 0.01);

	float decoSWX  = sx1 - flankProm - rmXTilesToFraction(decoSWDist);
	float decoSWZ1 = (sFlank2Z + sFlankZ) * 0.5;   // between harbour 6 and harbour 4
	float decoSWZ2 = (sFlankZ + sPirateZ) * 0.5;   // between harbour 4 and the pirates
	float decoSWZ3 = sPirateZ - rmZTilesToFraction(decoSWBehindPir);   // behind the pirates
	rmPlaceGroupingAtLoc(decoSW,  0, decoSWX, decoSWZ1);
	rmPlaceGroupingAtLoc(decoSW2, 0, decoSWX, decoSWZ2);
	rmPlaceGroupingAtLoc(decoSW3, 0, decoSWX, decoSWZ3);

	// ---- deco lighthouses on the harbour-wall corners ---------------------
	// a GROUPING like the other IS_ deco (loose XML in Game/RandMaps/groupings,
	// so a NEW file needs a game restart before it loads)
	int lightN = rmCreateGrouping("deco lighthouse n", "IS_Deco_Lighthouse");
	rmSetGroupingMinDistance(lightN, 0.0);
	rmSetGroupingMaxDistance(lightN, 0.01);
	int lightS = rmCreateGrouping("deco lighthouse s", "IS_Deco_Lighthouse");
	rmSetGroupingMinDistance(lightS, 0.0);
	rmSetGroupingMaxDistance(lightS, 0.01);

	float lightNX = nx5 + flankProm + rmXTilesToFraction(lightNAlongX);
	float lightNZ = nRouteZ + rmZTilesToFraction(lightNOffZ);
	float lightSX = sx1 - flankProm - rmXTilesToFraction(lightSAlongX);
	float lightSZ = sRouteZ - rmZTilesToFraction(lightSOffZ);
	rmPlaceGroupingAtLoc(lightN, 0, lightNX, lightNZ);
	rmPlaceGroupingAtLoc(lightS, 0, lightSX, lightSZ);


	rmSetStatusText("", 0.85);

	// ========================================================================
	//  8. PLAYERS  (stub)
	// ========================================================================
	rmPlacePlayersCircular(0.42, 0.42, 0.0);

	// keeps objects off EVERY cliff top by height: countryside ground is
	// cityHeight (+2 variation), the cliffs stand at +6 and +14 - a class
	// constraint would miss the wild masses (deliberately not in classCliff)
	int belowCliffs = rmCreateMaxHeightConstraint("below the cliffs", cityHeight + 2.5);
	// ---- PLAYER KIT (zp_z_zparis.xs 1504-1566) ---------------------------
	// City players already own a baked TownCenter via their start block; the
	// countryside players get deSPCCommandPost as their starting TC plus the
	// Paris hunt/mine/berry set on their clearing.
	int fakeLock = rmCreateObjectDef("fake grouping lock");
	rmAddObjectDefItem(fakeLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	// ON LAND, like Paris (their 0.5,0.65 is city ground). In water these
	// 20 points are LIVE water-spawn machinery and hijack the shore-
	// grouping chain - that broke the pirate camps.
	rmPlaceObjectDefAtLoc(fakeLock, 0, nx3, nz3);

	int playerStartUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(playerStartUnits, 7.0);
	rmSetObjectDefMaxDistance(playerStartUnits, 12.0);

	int huntDef = rmCreateObjectDef("starting hunt");
	rmAddObjectDefItem(huntDef, "Deer", rmRandInt(6, 7), 6.0);
	rmAddObjectDefItem(huntDef, "ypGoat", rmRandInt(2, 3), 5.0);
	rmSetObjectDefMinDistance(huntDef, 12.0);
	rmSetObjectDefMaxDistance(huntDef, 14.0);
	rmAddObjectDefConstraint(huntDef, belowCliffs);
	rmSetObjectDefCreateHerd(huntDef, true);

	int mineDef = rmCreateObjectDef("starting gold");
	rmAddObjectDefItem(mineDef, "MineCopper", 1, 2.0);
	rmSetObjectDefMinDistance(mineDef, 14.0);
	rmSetObjectDefMaxDistance(mineDef, 15.0);
	rmAddObjectDefConstraint(mineDef, belowCliffs);

	int berryDef = rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(berryDef, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryDef, 16.0);
	rmSetObjectDefMaxDistance(berryDef, 17.0);
	rmAddObjectDefConstraint(berryDef, belowCliffs);

	int aiUrban = rmCreateObjectDef("is city map");
	rmAddObjectDefItem(aiUrban, "zpAIStartUrbanMap", 1, 0.0);

	if (cNumberTeams == 2)
	{
		for (pk = 1; <= cNumberNonGaiaPlayers)
		{
			int pArea = rmCreateArea("Player" + pk);
			rmSetPlayerArea(pk, pArea);
			rmPlaceObjectDefAtLoc(playerStartUnits, pk,
				rmPlayerLocXFraction(pk), rmPlayerLocZFraction(pk));
			rmPlaceObjectDefAtLoc(aiUrban, pk, 0.5, 0.5);
			bool pkInCity = false;
			if (pk == firstDefender) pkInCity = true;
			if (pk == firstAttacker) pkInCity = true;
			if (pk == secondDefender && citySeatsN == 2) pkInCity = true;
			if (pk == secondAttacker && citySeatsS == 2) pkInCity = true;
			if (pkInCity == false)
			{
				int postDef = rmCreateObjectDef("command post " + pk);
				rmAddObjectDefItem(postDef, "deSPCCommandPost", 1, 2.0);
				rmSetObjectDefMinDistance(postDef, 0.0);
				rmSetObjectDefMaxDistance(postDef, 1.0);
				rmPlaceObjectDefAtLoc(postDef, pk,
					rmPlayerLocXFraction(pk), rmPlayerLocZFraction(pk));
				rmPlaceObjectDefAtLoc(huntDef, pk,
					rmPlayerLocXFraction(pk), rmPlayerLocZFraction(pk));
				rmPlaceObjectDefAtLoc(mineDef, pk,
					rmPlayerLocXFraction(pk), rmPlayerLocZFraction(pk));
				rmPlaceObjectDefAtLoc(berryDef, pk,
					rmPlayerLocXFraction(pk), rmPlayerLocZFraction(pk));
			}
		}
	}


	// ---- COSSACK CAMPS - placed AFTER the final valley terrain -----------
	// Build order is the fix: built early, the wild cliff masses (which do
	// not avoid classPlateau) flooded over the camp islands and re-carved
	// the ground AFTER the walls spawned - the walls ended up under cliffs.
	// Built last, nothing can touch their ground again.
	// their ground: a plain flat grass island at city height - no cliff
	// rim (the camps stand on ordinary ground, per the design).
	int campIsleW = rmCreateArea("campIsleW");
	rmSetAreaWarnFailure(campIsleW, false);
	rmSetAreaSize(campIsleW, rmAreaTilesToFraction(450), rmAreaTilesToFraction(450));
	rmSetAreaLocation(campIsleW, 0.07, 0.60);
	rmSetAreaCoherence(campIsleW, 1.0);
	rmSetAreaBaseHeight(campIsleW, cityHeight);
	rmSetAreaMix(campIsleW, hinterMix);
	rmSetAreaElevationVariation(campIsleW, 0.0);
	rmAddAreaToClass(campIsleW, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(campIsleW, false);
	rmBuildArea(campIsleW);

	int campIsleE = rmCreateArea("campIsleE");
	rmSetAreaWarnFailure(campIsleE, false);
	rmSetAreaSize(campIsleE, rmAreaTilesToFraction(450), rmAreaTilesToFraction(450));
	rmSetAreaLocation(campIsleE, 0.93, 0.40);
	rmSetAreaCoherence(campIsleE, 1.0);
	rmSetAreaBaseHeight(campIsleE, cityHeight);
	rmSetAreaMix(campIsleE, hinterMix);
	rmSetAreaElevationVariation(campIsleE, 0.0);
	rmAddAreaToClass(campIsleE, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(campIsleE, false);
	rmBuildArea(campIsleE);

	// cossack camps: random variant 1-5, the Black Sea idiom
	// (000_blacksea.xs 750-751 + 816). SocketCossacks is baked in.
	int cossackCampWType = rmRandInt(1, 5);
	int cossackCampEType = rmRandInt(1, 5);
	int cossackCampW = rmCreateGrouping("cossack camp w", "Cossack_Camp_0" + cossackCampWType);
	int cossackCampE = rmCreateGrouping("cossack camp e", "Cossack_Camp_0" + cossackCampEType);
	placeShoreIsland(cossackCampW, 0.07, 0.60);
	placeShoreIsland(cossackCampE, 0.93, 0.40);

	// ---- COUNTRYSIDE RESOURCES - the Versailles idiom --------------------
	// zp_z_verseilles.xs 1594-1630: objects scattered rmPlaceObjectDefInArea
	// into the named countryside areas, spaced by type constraints. All the
	// target areas exist by now (terraces, filler, back hinterland).
	// resource abundance grows with the lobby: 1 at 4 players, 2 at 8
	int resScale = cNumberNonGaiaPlayers / 4;

	// tree clumps: the map's own mix, cypress-led (Paris countrysideTrees style)
	int contTrees = rmCreateObjectDef("countryside trees");
	rmAddObjectDefItem(contTrees, "deTreeCypress", rmRandInt(7, 9), 10.0);
	rmAddObjectDefItem(contTrees, "TreeGreatLakes", rmRandInt(3, 5), 11.0);
	rmAddObjectDefItem(contTrees, "ypTreeEucalyptus", rmRandInt(2, 4), 9.0);
	rmAddObjectDefConstraint(contTrees, treeVsTree);
	rmAddObjectDefConstraint(contTrees, avoidSocketTrees);
	rmAddObjectDefConstraint(contTrees, dockAvoidBlocks);
	rmAddObjectDefConstraint(contTrees, avoidWallObjTree);
	rmAddObjectDefConstraint(contTrees, belowCliffs);
	rmAddObjectDefConstraint(contTrees, avoidWallObj);
	rmAddObjectDefConstraint(contTrees, cliffLaneFallback);
	rmPlaceObjectDefInArea(contTrees, 0, wildLowW, 10);
	rmPlaceObjectDefInArea(contTrees, 0, wildLowE, 10);
	rmPlaceObjectDefInArea(contTrees, 0, fillW, 7);
	rmPlaceObjectDefInArea(contTrees, 0, fillE, 7);
	rmPlaceObjectDefInArea(contTrees, 0, hinterN, 5);
	rmPlaceObjectDefInArea(contTrees, 0, hinterS, 5);

	// copper on the countryside
	int contMine = rmCreateObjectDef("countryside copper");
	rmAddObjectDefItem(contMine, "MineCopper", 1, 0.0);
	rmAddObjectDefConstraint(contMine, mineVsMine);
	rmAddObjectDefConstraint(contMine, dockAvoidBlocks);
	rmAddObjectDefConstraint(contMine, avoidWallObjXL);
	rmAddObjectDefConstraint(contMine, belowCliffs);
	rmAddObjectDefConstraint(contMine, insideWorld);
	rmAddObjectDefConstraint(contMine, avoidWallObj);
	rmAddObjectDefConstraint(contMine, cliffLaneFallback);
	rmPlaceObjectDefInArea(contMine, 0, wildLowW, 2 + resScale);
	rmPlaceObjectDefInArea(contMine, 0, wildLowE, 2 + resScale);
	rmPlaceObjectDefInArea(contMine, 0, fillW, 1 + resScale);
	rmPlaceObjectDefInArea(contMine, 0, fillE, 1 + resScale);

	// regional hunts: deer herds and goat herds
	int contDeer = rmCreateObjectDef("countryside deer");
	rmAddObjectDefItem(contDeer, "Deer", rmRandInt(6, 8), 6.0);
	rmSetObjectDefCreateHerd(contDeer, true);
	rmAddObjectDefConstraint(contDeer, deerVsDeer);
	rmAddObjectDefConstraint(contDeer, dockAvoidBlocks);
	rmAddObjectDefConstraint(contDeer, avoidWallObjXL);
	rmAddObjectDefConstraint(contDeer, belowCliffs);
	rmAddObjectDefConstraint(contDeer, insideWorld);
	rmAddObjectDefConstraint(contDeer, cliffLaneFallback);
	rmPlaceObjectDefInArea(contDeer, 0, wildLowW, 2 + resScale);
	rmPlaceObjectDefInArea(contDeer, 0, wildLowE, 2 + resScale);
	rmPlaceObjectDefInArea(contDeer, 0, fillW, 1 + resScale);
	rmPlaceObjectDefInArea(contDeer, 0, fillE, 1 + resScale);

	int contGoat = rmCreateObjectDef("countryside goats");
	rmAddObjectDefItem(contGoat, "ypGoat", rmRandInt(3, 5), 5.0);
	rmSetObjectDefCreateHerd(contGoat, true);
	rmAddObjectDefConstraint(contGoat, deerVsDeer);
	rmAddObjectDefConstraint(contGoat, dockAvoidBlocks);
	rmAddObjectDefConstraint(contGoat, avoidWallObjXL);
	rmAddObjectDefConstraint(contGoat, belowCliffs);
	rmAddObjectDefConstraint(contGoat, insideWorld);
	rmAddObjectDefConstraint(contGoat, cliffLaneFallback);
	rmPlaceObjectDefInArea(contGoat, 0, wildLowW, 1 + resScale);
	rmPlaceObjectDefInArea(contGoat, 0, wildLowE, 1 + resScale);
	rmPlaceObjectDefInArea(contGoat, 0, fillW, 1);
	rmPlaceObjectDefInArea(contGoat, 0, fillE, 1);

	// fish and whales - Black Sea's block (000_blacksea.xs 1266-1288) with
	// Aegean protos: sardines along the shores, humpbacks in open water
	// ---- WATER FORTS - the zpcaribbeanwars.xs KotH castle (its 261-267) ---
	// One per sea, the south one turned 180 deg through the map centre.
	// Placed BEFORE the fish and whales so their avoid constraints react to
	// the placed fort units (grouping loads from the profile folder).
	// MEASURED clear water: the old (0.80, 0.86) sat 15 m off the north
	// trade lane's (0.90,0.90) starting leg - the route corridor ate the
	// fort. These spots keep 58+ m from BOTH route polylines, radius 0.44.
	float waterFortNX = 0.88;   // Black Sea fort - tune both, south derives
	float waterFortNZ = 0.72;
	int waterFortN = rmCreateGrouping("water fort north", "Caribbean_Naval_KotH_Istanbul");
	rmSetGroupingMinDistance(waterFortN, 0.00);
	rmSetGroupingMaxDistance(waterFortN, 0.01);
	rmAddGroupingToClass(waterFortN, rmClassID("classPlateau"));
	// INSTANCE placement, so the baked treasure can be queried back by type -
	// the same call the gun islands, factories and harbours use. The nugget is
	// INSIDE the grouping (never dropped on top of it), which is what makes the
	// guardian galleys spawn with the fort instead of fighting its footprint.
	// Difficulty 601 latches nuggetmods zpNuggetWaterFort = 2x
	// zpGuardianCorsairGalley; restored to 519 after both forts are down.
	rmSetNuggetDifficulty(601, 601);
	int waterFortNPlacement = rmPlaceGroupingInstanceAtLoc(waterFortN, waterFortNX, waterFortNZ, 0);

	int waterFortS = rmCreateGrouping("water fort south", "Caribbean_Naval_KotH_medi");
	rmSetGroupingMinDistance(waterFortS, 0.00);
	rmSetGroupingMaxDistance(waterFortS, 0.01);
	rmAddGroupingToClass(waterFortS, rmClassID("classPlateau"));
	int waterFortSPlacement = rmPlaceGroupingInstanceAtLoc(waterFortS, 1.0 - waterFortNX, 1.0 - waterFortNZ, 0);
	rmSetNuggetDifficulty(519, 519);

	// conversion anchors - one invisible revealer per fort at the knob spot;
	// ids take instanceIdShiftIndividual, all trigger conditions and
	// converts anchor here and act BY TYPE - no grouping-id arithmetic
	int fortMarkDefN = rmCreateObjectDef("water fort marker north");
	rmAddObjectDefItem(fortMarkDefN, "zpCinematicRevealer", 1, 0.0);
	rmPlaceObjectDefAtLoc(fortMarkDefN, 0, waterFortNX, waterFortNZ);
	int fortMarkDefS = rmCreateObjectDef("water fort marker south");
	rmAddObjectDefItem(fortMarkDefS, "zpCinematicRevealer", 1, 0.0);
	rmPlaceObjectDefAtLoc(fortMarkDefS, 0, 1.0 - waterFortNX, 1.0 - waterFortNZ);
	// Flare positions: the map's own readback idiom (:265, :1099, :1157...).
	// Duration name and value copied from 000_caribbeanwars.xs 991.
	int socketMinimapFlareDuration = 10;
	vector waterFortLocN = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(fortMarkDefN, 0));
	vector waterFortLocS = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(fortMarkDefS, 0));



	int fishSolo = rmCreateObjectDef("sea fish solo");
	rmAddObjectDefItem(fishSolo, "FishSardine", 1, 0.0);
	rmSetObjectDefMinDistance(fishSolo, 0.0);
	rmSetObjectDefMaxDistance(fishSolo, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishSolo, fishVsFish);
	rmAddObjectDefConstraint(fishSolo, fishOffLand);
	rmAddObjectDefConstraint(fishSolo, avoidKotH);
	rmAddObjectDefConstraint(fishSolo, avoidKotHMedi);
	rmAddObjectDefConstraint(fishSolo, avoidHarbourPlat);
	rmPlaceObjectDefAtLoc(fishSolo, 0, 0.5, 0.5, 12 + cNumberNonGaiaPlayers);
	int fishPair = rmCreateObjectDef("sea fish pair");
	rmAddObjectDefItem(fishPair, "FishSardine", 2, 4.0);
	rmSetObjectDefMinDistance(fishPair, 0.0);
	rmSetObjectDefMaxDistance(fishPair, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishPair, fishVsFish);
	rmAddObjectDefConstraint(fishPair, fishOffLand);
	rmAddObjectDefConstraint(fishPair, avoidKotH);
	rmAddObjectDefConstraint(fishPair, avoidKotHMedi);
	rmAddObjectDefConstraint(fishPair, avoidHarbourPlat);
	rmPlaceObjectDefAtLoc(fishPair, 0, 0.5, 0.5, 16 + cNumberNonGaiaPlayers);
	int fishSchool = rmCreateObjectDef("sea fish school");
	rmAddObjectDefItem(fishSchool, "FishSardine", 3, 5.0);
	rmSetObjectDefMinDistance(fishSchool, 0.0);
	rmSetObjectDefMaxDistance(fishSchool, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishSchool, fishVsFish);
	rmAddObjectDefConstraint(fishSchool, fishOffLand);
	rmAddObjectDefConstraint(fishSchool, avoidKotH);
	rmAddObjectDefConstraint(fishSchool, avoidKotHMedi);
	rmAddObjectDefConstraint(fishSchool, avoidHarbourPlat);
	rmPlaceObjectDefAtLoc(fishSchool, 0, 0.5, 0.5, 16 + cNumberNonGaiaPlayers);

	// whales: one pod per sea, box-fenced so they stay OUT of the strait.

	int whaleN = rmCreateObjectDef("whales black sea");
	rmAddObjectDefItem(whaleN, "HumpbackWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleN, 0.0);
	rmSetObjectDefMaxDistance(whaleN, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(whaleN, whaleVsWhale);
	rmAddObjectDefConstraint(whaleN, whaleOffLand);
	rmAddObjectDefConstraint(whaleN, avoidKotHLong);
	rmAddObjectDefConstraint(whaleN, avoidKotHMediLong);
	rmAddObjectDefConstraint(whaleN, seaBoxNE);
	rmPlaceObjectDefAtLoc(whaleN, 0, 0.80, 0.78, 3 + resScale * 2);

	int whaleS = rmCreateObjectDef("whales mediterranean");
	rmAddObjectDefItem(whaleS, "HumpbackWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleS, 0.0);
	rmSetObjectDefMaxDistance(whaleS, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(whaleS, whaleVsWhale);
	rmAddObjectDefConstraint(whaleS, whaleOffLand);
	rmAddObjectDefConstraint(whaleS, avoidKotHLong);
	rmAddObjectDefConstraint(whaleS, avoidKotHMediLong);
	rmAddObjectDefConstraint(whaleS, seaBoxSW);
	rmPlaceObjectDefAtLoc(whaleS, 0, 0.20, 0.22, 3 + resScale * 2);

	// countryside treasures: Versailles scatter, OUR 519 Ottoman nugget set
	// (the map-type pool has no difficulty 1-2 - that empty-pool trap again)
	rmSetNuggetDifficulty(519, 519);
	int nuggetCountry = rmCreateObjectDef("countryside treasure");
	rmAddObjectDefItem(nuggetCountry, "Nugget", 1, 0.0);
	rmAddObjectDefConstraint(nuggetCountry, nugVsNug);
	rmAddObjectDefConstraint(nuggetCountry, dockAvoidBlocks);
	rmAddObjectDefConstraint(nuggetCountry, avoidWallObjXL);
	rmAddObjectDefConstraint(nuggetCountry, belowCliffs);
	rmAddObjectDefConstraint(nuggetCountry, insideWorld);
	rmAddObjectDefConstraint(nuggetCountry, avoidWallObj);
	rmAddObjectDefConstraint(nuggetCountry, cliffLaneFallback);
	rmPlaceObjectDefInArea(nuggetCountry, 0, wildLowW, 2 + resScale);
	rmPlaceObjectDefInArea(nuggetCountry, 0, wildLowE, 2 + resScale);
	rmPlaceObjectDefInArea(nuggetCountry, 0, fillW, 1 + resScale);
	rmPlaceObjectDefInArea(nuggetCountry, 0, fillE, 1 + resScale);

	// ========================================================================
	//  PLAYER WATER FLAGS - fixed slots per TEAM MATE 1..7.
	//  Defenders hold the NORTH island, so their flags stand in the BLACK
	//  SEA; attackers get the MEDITERRANEAN - always their own sea, even
	//  when the enemy sea is physically closer. The side swap re-keys the
	//  roles, so the flags follow the team automatically.
	//  Mates 1-3: off the MOLO HEADS - the three flank shoreline deco
	//  piers, derived from the SAME measured anchors (decoNE/SW), pushed
	//  flagMoloOut tiles further seaward. MEASURED from the grouping XML:
	//  the pier head plank sits +8.06 m seaward of the grouping centre on
	//  its mid line, so N = 7 t (14 m) puts the flag ~6 m off the head.
	//  Move a pier, the flag follows.
	//  Mates 4-7: the water band between the countryside shoreline and
	//  the naval KotH fort, strung shore -> fort, plain literal pairs.
	//  HARD LAW - radius: rmSetWorldCircleConstraint(true) drops any spot
	//  further than ~half the map from (0.5, 0.5) SILENTLY. Measured on
	//  this map: r 0.469 spawns, r 0.512 does not. Keep literals <= 0.455;
	//  Slot order per coast: hinter-flank pier (behind the pirates) FIRST,
	//  middle pier second, strait-side pier third. South open-water piers
	//  go 10 t out; its hinter pier is capped at flagMoloOutS3 = 6: the
	//  island sits 10 t west, so that pier is near the rim, and 6 t is the
	//  most that keeps the flag under the proven-spawn radius (~0.466 vs
	//  the 0.469 measured bound). More seaward = silent drop; if it must
	//  move visually, shift its Z channel-ward instead.
	// ========================================================================
	if (cNumberTeams == 2)
	{
		int flagMoloOutN = 7;
		int flagMoloOutS = 10;
		int flagMoloOutS3 = 6;   // radius ceiling - see the HARD LAW above
		float flagNEX = decoNEX + rmXTilesToFraction(flagMoloOutN);
		float flagSWX = decoSWX - rmXTilesToFraction(flagMoloOutS);
		float flagSWX3 = decoSWX - rmXTilesToFraction(flagMoloOutS3);
		placeWaterFlag(firstDefender, flagNEX, decoNEZ3);
		// middle-pier flags sit 2 t channel-ward, clear of the pirate buoy
		if (northCount >= 2) placeWaterFlag(secondDefender, flagNEX, decoNEZ2 - rmZTilesToFraction(2));
		if (northCount >= 3) placeWaterFlag(thirdDefender, flagNEX, decoNEZ1);
		if (northCount >= 4) placeWaterFlag(fourthDefender, 0.76, 0.86);
		if (northCount >= 5) placeWaterFlag(fifthDefender, 0.80, 0.82);
		if (northCount >= 6) placeWaterFlag(sixthDefender, 0.84, 0.78);
		if (northCount >= 7) placeWaterFlag(seventhDefender, 0.76, 0.81);

		placeWaterFlag(firstAttacker, flagSWX3, decoSWZ3);
		if (southCount >= 2) placeWaterFlag(secondAttacker, flagSWX, decoSWZ2 + rmZTilesToFraction(2));
		if (southCount >= 3) placeWaterFlag(thirdAttacker, flagSWX, decoSWZ1);
		if (southCount >= 4) placeWaterFlag(fourthAttacker, 0.22, 0.15);
		if (southCount >= 5) placeWaterFlag(fifthAttacker, 0.18, 0.18);
		if (southCount >= 6) placeWaterFlag(sixthAttacker, 0.16, 0.22);
		if (southCount >= 7) placeWaterFlag(seventhAttacker, 0.22, 0.19);
	}

	// ========================================================================
	//  UNIT IDS - every id a trigger targets, derived HERE and nowhere else
	// ------------------------------------------------------------------------
	//  THE LAW (zp_z_zparis.xs 1685-1757 / 000_independence_war.xs 1601-1631):
	//    rmGetUnitPlaced (object defs)          = + instanceIdShiftIndividual
	//    rmGetGroupingInstanceUnitByType        = +1  (Paris applies it to
	//                                             EVERY instance query)
	//    grouping-adjacent arithmetic (pirates) = socket is the LAST camp
	//                                             unit, flag placed next:
	//                                             socket = flag + 1 (in-game
	//                                             verified on this map)
	//  Nugget protos are the nuggetmods <nuggetunit> of the latched
	//  difficulty: 517 harbours = ypNuggetTradingPost, 516/520/98 = the
	//  invisible nugget. NEVER the authored placeholder proto.
	// ========================================================================
	int instanceIdShift = 2;
	// Individually placed object defs need their own shift. It is also 2 today,
	// but it is a SEPARATE number: it tracks single rmPlaceObjectDef* placements,
	// while instanceIdShift tracks rmGetGroupingInstanceUnitByType queries. They
	// drifted apart once the fort groupings started baking a guardian treasure.
	int instanceIdShiftIndividual = 2;

	// -- placed object defs: + instanceIdShiftIndividual --
	int unit_harbourSocketN = rmGetUnitPlaced(harbourSocketN, 0) + instanceIdShiftIndividual;
	int unit_harbourSocketS = rmGetUnitPlaced(harbourSocketS, 0) + instanceIdShiftIndividual;
	int unit_flankSocketN = rmGetUnitPlaced(flankSocketN, 0) + instanceIdShiftIndividual;
	int unit_flankSocketS = rmGetUnitPlaced(flankSocketS, 0) + instanceIdShiftIndividual;
	int unit_flank2SocketN = rmGetUnitPlaced(flank2SocketN, 0) + instanceIdShiftIndividual;
	int unit_flank2SocketS = rmGetUnitPlaced(flank2SocketS, 0) + instanceIdShiftIndividual;
	int pirateFlagN = rmGetUnitPlaced(pirateFlagDefN, 0) + instanceIdShiftIndividual;
	int pirateFlagS = rmGetUnitPlaced(pirateFlagDefS, 0) + instanceIdShiftIndividual;
	// The fort groupings now bake a guardian treasure, so the markers placed
	// after them are no longer raw-exact - they take the map's shift like
	// every other queried id.
	int fortMarkN = rmGetUnitPlaced(fortMarkDefN, 0) + instanceIdShiftIndividual;
	int fortMarkS = rmGetUnitPlaced(fortMarkDefS, 0) + instanceIdShiftIndividual;
	int unit_waterFortNugN = rmGetGroupingInstanceUnitByType(waterFortNPlacement, "zpNuggetInvisibleWater") + instanceIdShift;
	int unit_waterFortNugS = rmGetGroupingInstanceUnitByType(waterFortSPlacement, "zpNuggetInvisibleWater") + instanceIdShift;
	rmEchoInfo("water fort treasures: N="+unit_waterFortNugN+" S="+unit_waterFortNugS);

	// -- grouping-adjacent: pirate sockets --
	int pirateSocketN = pirateFlagN+1;
	int pirateSocketS = pirateFlagS+1;

	// -- anti-ship gun sockets: instance query + the same shift as the rest --
	int gunSocketNW = rmGetGroupingInstanceUnitByType(gunNWPlacement, "zpSocketAntiShipGun") + instanceIdShift;
	int gunSocketNE = rmGetGroupingInstanceUnitByType(gunNEPlacement, "zpSocketAntiShipGun") + instanceIdShift;
	int gunSocketSW = rmGetGroupingInstanceUnitByType(gunSWPlacement, "zpSocketAntiShipGun") + instanceIdShift;
	int gunSocketSE = rmGetGroupingInstanceUnitByType(gunSEPlacement, "zpSocketAntiShipGun") + instanceIdShift;
	rmEchoInfo("gun sockets: NW="+gunSocketNW+" NE="+gunSocketNE+" SW="+gunSocketSW+" SE="+gunSocketSE);

	// -- grouping instance queries: +1, the Paris law --
	int unit_nugHN = rmGetGroupingInstanceUnitByType(tradeNPlacement, "ypNuggetTradingPost") + instanceIdShift;
	int unit_nugHS = rmGetGroupingInstanceUnitByType(tradeSPlacement, "ypNuggetTradingPost") + instanceIdShift;
	int unit_nugH3 = rmGetGroupingInstanceUnitByType(trade3Placement, "ypNuggetTradingPost") + instanceIdShift;
	int unit_nugH4 = rmGetGroupingInstanceUnitByType(trade4Placement, "ypNuggetTradingPost") + instanceIdShift;
	int unit_nugH5 = rmGetGroupingInstanceUnitByType(trade5Placement, "ypNuggetTradingPost") + instanceIdShift;
	int unit_nugH6 = rmGetGroupingInstanceUnitByType(trade6Placement, "ypNuggetTradingPost") + instanceIdShift;
	int unit_menagBN = rmGetGroupingInstanceUnitByType(menageriePlacementN, "zpSPCMenagerie") + instanceIdShift;
	int unit_menagNugN = rmGetGroupingInstanceUnitByType(menageriePlacementN, "zpNuggetInvisible") + instanceIdShift;
	int unit_menagBS = rmGetGroupingInstanceUnitByType(menageriePlacementS, "zpSPCMenagerie") + instanceIdShift;
	int unit_menagNugS = rmGetGroupingInstanceUnitByType(menageriePlacementS, "zpNuggetInvisible") + instanceIdShift;
	int unit_factBN = rmGetGroupingInstanceUnitByType(factoryPlacementN, "zpSPCCapturableFactoryFlorence") + instanceIdShift;
	int unit_factNugN = rmGetGroupingInstanceUnitByType(factoryPlacementN, "zpNuggetInvisible") + instanceIdShift;
	int unit_factBS = rmGetGroupingInstanceUnitByType(factoryPlacementS, "zpSPCCapturableFactoryFlorence") + instanceIdShift;
	int unit_factNugS = rmGetGroupingInstanceUnitByType(factoryPlacementS, "zpNuggetInvisible") + instanceIdShift;
	int unit_fortFlagN = rmGetGroupingInstanceUnitByType(fortPlacementN, "zpSPCCapturableFlagInvisible") + instanceIdShift;
	int unit_fortNugN = rmGetGroupingInstanceUnitByType(fortPlacementN, "zpNuggetInvisible") + instanceIdShift;
	int unit_fortFlagS = rmGetGroupingInstanceUnitByType(fortPlacementS, "zpSPCCapturableFlagInvisible") + instanceIdShift;
	int unit_fortNugS = rmGetGroupingInstanceUnitByType(fortPlacementS, "zpNuggetInvisible") + instanceIdShift;

	rmEchoInfo("pirate ids north: flag="+pirateFlagN+" socket="+pirateSocketN);
	rmEchoInfo("pirate ids south: flag="+pirateFlagS+" socket="+pirateSocketS);
	rmEchoInfo("water fort markers: N=" + fortMarkN + " S=" + fortMarkS);
	rmEchoInfo("factory ids: BN=" + unit_factBN + " BS=" + unit_factBS);


	// Paris order (zp_z_zparis.xs 1763 vs 1873): Starting Techs is defined
	// BEFORE every suspend trigger - techs churn first, suspensions stick.
	int st = 0;
	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for (st = 1; <= cNumberNonGaiaPlayers)
	{
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", st);
	rmSetTriggerEffectParam("TechID", "cTechzpBosporusMapSetup");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", st);
	rmSetTriggerEffectParam("TechID", "cTechdeEUMapUpdateVisuals"); // European Embassy - zp_z_zparis.xs 1810
	rmSetTriggerEffectParamInt("Status", 2);
	}
	// gaia gets ONLY the visual tech (zp_z_zparis.xs fires it for i=0..N;
	// no reference map ever fires a SETUP tech for gaia - its unit-churning
	// effects at startup are what reset AutoConvert suspensions)
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", 0);
	rmSetTriggerEffectParam("TechID", "cTechdeEUMapUpdateVisuals");
	rmSetTriggerEffectParamInt("Status", 2);
	// GAIA IDENTITY. The zp_z_zparis.xs 2038-2044 pair: Paris flies SPCBourbon
	// and calls itself "City of Paris" (301968); the Bosporus flies the
	// Sultanate (zpSultanate, data/civmods.xml) and calls itself
	// "City of Istanbul" (303337).
	rmAddTriggerEffect("Player : Override Civilization for Flag");
	rmSetTriggerEffectParamInt("Player", 0);
	rmSetTriggerEffectParam("Civilization", "zpSultanate");
	rmAddTriggerEffect("Player : Override Civilization Name");
	rmSetTriggerEffectParamInt("Player", 0);
	rmSetTriggerEffectParam("StringID", "303337");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ========================================================================
	//  ANTI-SHIP GUNS  -  prebuilt at load, then rebuildable from the socket
	// ------------------------------------------------------------------------
	// The gun groupings ship a SOCKET, not a gun. "Socket Build" (zpazteccity.xs
	// 1597-1610) constructs the gun on it during load with RunImmediately, so a
	// player never sees an empty socket at the start - only a finished gun.
	// When that gun dies the engine returns the socket, and because the socket
	// carries socketcapture.tactics (AutoConvert) whoever stands next to it
	// takes it and may build their own gun. No id arithmetic anywhere.
	//
	// TRIGGER NAMES: no spaces at all (000_caribbeanwars.xs 2202 idiom), so
	// create and rmTriggerID lookup match exactly - the editor-passes /
	// Skirmish-fails class the nugget-targeting skill warns about.
	// ========================================================================
	// ONE TRIGGER PER PLAYER. zpazteccity's Defender_Setup0 carries its four
	// Socket Build effects for a SINGLE player (firstDefender). Packing several
	// different PlayerIDs into one trigger does not work - the trigger is
	// authored per player, so each owner gets their own. Every non-gaia player
	// gets a trigger; a player who owns no gun simply gets an empty one.
	int gk = 0;
	for (gk = 1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("AntiShipGunsPrebuilt"+gk);
		rmSwitchToTrigger(rmTriggerID("AntiShipGunsPrebuilt"+gk));
		if (gunOwnerN1 == gk)
		{
			rmAddTriggerEffect("Socket Build");
			rmSetTriggerEffectParamInt("PlayerID", gk);
			rmSetTriggerEffectParam("Socket", ""+gunSocketNW);
			rmSetTriggerEffectParam("Protounit", "zpAntiShipGun");
		}
		if (gunOwnerN2 == gk)
		{
			rmAddTriggerEffect("Socket Build");
			rmSetTriggerEffectParamInt("PlayerID", gk);
			rmSetTriggerEffectParam("Socket", ""+gunSocketNE);
			rmSetTriggerEffectParam("Protounit", "zpAntiShipGun");
		}
		if (gunOwnerS1 == gk)
		{
			rmAddTriggerEffect("Socket Build");
			rmSetTriggerEffectParamInt("PlayerID", gk);
			rmSetTriggerEffectParam("Socket", ""+gunSocketSW);
			rmSetTriggerEffectParam("Protounit", "zpAntiShipGun");
		}
		if (gunOwnerS2 == gk)
		{
			rmAddTriggerEffect("Socket Build");
			rmSetTriggerEffectParamInt("PlayerID", gk);
			rmSetTriggerEffectParam("Socket", ""+gunSocketSE);
			rmSetTriggerEffectParam("Protounit", "zpAntiShipGun");
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// AI ENABLEMENT. cTechzpSPCIstanbulSocketsAI enables zpSPCFixedGunAIProxy
	// and CommandAdds it onto zpSocketAntiShipGun, which is how the AI "trains"
	// at a socket. Granted to NON-HUMAN players only, exactly as
	// 000_caribbeanwars.xs 1024-1032 does it.
	for (gk = 1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("AntiShipGunAITech"+gk);
		rmSwitchToTrigger(rmTriggerID("AntiShipGunAITech"+gk));
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player", gk);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID", gk);
		rmSetTriggerEffectParam("TechID", "cTechzpSPCIstanbulSocketsAI");
		rmSetTriggerEffectParamInt("Status", 2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// AI REBUILD.  Three triggers per player per socket, the 000_caribbeanwars.xs
	// 2202-2270 + 2332-2340 architecture, hardened for FOUR sockets and up to
	// eight possible owners (caribbeanwars has two sockets and one owner each).
	//
	//  _AICHECK  fires once for a NON-HUMAN player and arms that player's four
	//            ON triggers. Without this kick nothing ever starts - ON and OFF
	//            are both created inactive, so they can only be entered by a
	//            Fire Event. This was missing and is why AI never rebuilt.
	//  _ON       arms and then WAITS until both of its conditions hold:
	//              1. player k OWNS this socket (Units in Area on the socket
	//                 proto itself, radius 2) - this is the routing gate. With
	//                 four sockets and many players the proxy test alone is not
	//                 enough; without it a player could answer a proxy near a
	//                 socket that is not theirs, and Socket Build performs NO
	//                 ownership check of its own.
	//              2. player k has just trained the proxy next to it.
	//            Because a waiting trigger keeps evaluating, ownership is
	//            re-tested continuously - a socket captured mid-game starts
	//            working for its new owner with no extra plumbing.
	//  _OFF      debounces for 1200 ms then re-arms ON, so the pair survives
	//            every subsequent destruction.
	for (gk = 1; <= cNumberNonGaiaPlayers)
	{
		rmCreateTrigger("ASGunAICheck_Plr"+gk);
		rmCreateTrigger("ASGunNW_ON_Plr"+gk);   rmCreateTrigger("ASGunNW_OFF_Plr"+gk);
		rmCreateTrigger("ASGunNE_ON_Plr"+gk);   rmCreateTrigger("ASGunNE_OFF_Plr"+gk);
		rmCreateTrigger("ASGunSW_ON_Plr"+gk);   rmCreateTrigger("ASGunSW_OFF_Plr"+gk);
		rmCreateTrigger("ASGunSE_ON_Plr"+gk);   rmCreateTrigger("ASGunSE_OFF_Plr"+gk);

		rmSwitchToTrigger(rmTriggerID("ASGunAICheck_Plr"+gk));
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player", gk);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ASGunNW_ON_Plr"+gk));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ASGunNE_ON_Plr"+gk));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ASGunSW_ON_Plr"+gk));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ASGunSE_ON_Plr"+gk));
		rmSetTriggerPriority(4);
		// SELF-STARTING. caribbeanwars leaves its AI_Check inactive because a
		// CAPTURE trigger fires it (:2445) - its city states begin as gaia. Our
		// sockets are already owned at map start, so no capture ever happens and
		// an inactive check would never run. Active(true) is what ignites the
		// whole chain, matching this map's own working triggers (:3086).
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ASGunNW_ON_Plr"+gk));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject", ""+gunSocketNW);
		rmSetTriggerConditionParamInt("Player", gk);
		rmSetTriggerConditionParam("UnitType", "zpSocketAntiShipGun");
		rmSetTriggerConditionParamInt("Dist", 2);
		rmSetTriggerConditionParam("Op", ">=");
		rmSetTriggerConditionParamInt("Count", 1);
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject", ""+gunSocketNW);
		rmSetTriggerConditionParamInt("Player", gk);
		rmSetTriggerConditionParam("UnitType", "zpSPCFixedGunAIProxy");
		rmSetTriggerConditionParamInt("Dist", 10);
		rmSetTriggerConditionParam("Op", ">=");
		rmSetTriggerConditionParamInt("Count", 1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID", gk);
		rmSetTriggerEffectParam("Socket", ""+gunSocketNW);
		rmSetTriggerEffectParam("Protounit", "zpAntiShipGun");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ASGunNW_OFF_Plr"+gk));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ASGunNW_OFF_Plr"+gk));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1", 1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ASGunNW_ON_Plr"+gk));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ASGunNE_ON_Plr"+gk));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject", ""+gunSocketNE);
		rmSetTriggerConditionParamInt("Player", gk);
		rmSetTriggerConditionParam("UnitType", "zpSocketAntiShipGun");
		rmSetTriggerConditionParamInt("Dist", 2);
		rmSetTriggerConditionParam("Op", ">=");
		rmSetTriggerConditionParamInt("Count", 1);
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject", ""+gunSocketNE);
		rmSetTriggerConditionParamInt("Player", gk);
		rmSetTriggerConditionParam("UnitType", "zpSPCFixedGunAIProxy");
		rmSetTriggerConditionParamInt("Dist", 10);
		rmSetTriggerConditionParam("Op", ">=");
		rmSetTriggerConditionParamInt("Count", 1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID", gk);
		rmSetTriggerEffectParam("Socket", ""+gunSocketNE);
		rmSetTriggerEffectParam("Protounit", "zpAntiShipGun");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ASGunNE_OFF_Plr"+gk));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ASGunNE_OFF_Plr"+gk));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1", 1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ASGunNE_ON_Plr"+gk));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ASGunSW_ON_Plr"+gk));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject", ""+gunSocketSW);
		rmSetTriggerConditionParamInt("Player", gk);
		rmSetTriggerConditionParam("UnitType", "zpSocketAntiShipGun");
		rmSetTriggerConditionParamInt("Dist", 2);
		rmSetTriggerConditionParam("Op", ">=");
		rmSetTriggerConditionParamInt("Count", 1);
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject", ""+gunSocketSW);
		rmSetTriggerConditionParamInt("Player", gk);
		rmSetTriggerConditionParam("UnitType", "zpSPCFixedGunAIProxy");
		rmSetTriggerConditionParamInt("Dist", 10);
		rmSetTriggerConditionParam("Op", ">=");
		rmSetTriggerConditionParamInt("Count", 1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID", gk);
		rmSetTriggerEffectParam("Socket", ""+gunSocketSW);
		rmSetTriggerEffectParam("Protounit", "zpAntiShipGun");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ASGunSW_OFF_Plr"+gk));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ASGunSW_OFF_Plr"+gk));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1", 1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ASGunSW_ON_Plr"+gk));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ASGunSE_ON_Plr"+gk));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject", ""+gunSocketSE);
		rmSetTriggerConditionParamInt("Player", gk);
		rmSetTriggerConditionParam("UnitType", "zpSocketAntiShipGun");
		rmSetTriggerConditionParamInt("Dist", 2);
		rmSetTriggerConditionParam("Op", ">=");
		rmSetTriggerConditionParamInt("Count", 1);
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject", ""+gunSocketSE);
		rmSetTriggerConditionParamInt("Player", gk);
		rmSetTriggerConditionParam("UnitType", "zpSPCFixedGunAIProxy");
		rmSetTriggerConditionParamInt("Dist", 10);
		rmSetTriggerConditionParam("Op", ">=");
		rmSetTriggerConditionParamInt("Count", 1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID", gk);
		rmSetTriggerEffectParam("Socket", ""+gunSocketSE);
		rmSetTriggerEffectParam("Protounit", "zpAntiShipGun");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ASGunSE_OFF_Plr"+gk));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ASGunSE_OFF_Plr"+gk));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1", 1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ASGunSE_ON_Plr"+gk));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// ========================================================================
	//  TRADE HARBOUR CONVERSION  (000_independence_war.xs idiom)
	// ------------------------------------------------------------------------
	// Every trade socket starts with AutoConvert SUSPENDED, so nobody can take
	// it while its guardian nugget still stands. Once that nugget becomes
	// collectable the matching trigger releases the suspension.
	// ========================================================================


	rmCreateTrigger("Trade Harbours NoAutoConvert");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_harbourSocketN);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_harbourSocketS);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_flankSocketN);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_flankSocketS);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_flank2SocketN);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_flank2SocketS);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour 1 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_nugHN);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_harbourSocketN, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour 2 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_nugHS);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_harbourSocketS, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour 3 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_nugH3);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_flankSocketN, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour 4 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_nugH4);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_flankSocketS, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour 5 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_nugH5);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_flank2SocketN, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Harbour 6 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_nugH6);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_flank2SocketS, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);





	// ========================================================================
	//  PRODUCTION BUILDING CONVERSION  (zp_z_zparis.xs 1872-1961 idiom)
	// ------------------------------------------------------------------------
	//  Menagerie + factory: AutoConvert suspended from the start, released
	//  when the guardian nugget becomes collectable - the same idiom as the
	//  trade harbours above. Instance ids are used AS-IS, matching the
	//  harbour code (NO Paris-style +1 on this map).
	//  Fort: simplified hybrid - nugget collectable releases the invisible
	//  capturable flag (NO gate/outpost destruction conditions like Paris);
	//  once a player owns the flag, the fort units convert to them and
	//  cTechzpConvertWallIndian transforms Indian stable/barracks into the
	//  functional Paris units (art kept Indian via 000_istanbul.mods.xml)
	//  and the tower prop into deSPCEuroTower, 1:1 as Paris.
	// ========================================================================

	rmCreateTrigger("Production Convert OFF");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_menagBN);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_menagBS);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_factBN);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_factBS);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagN);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagS);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Menagerie N Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_menagNugN);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_menagBN, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Menagerie S Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_menagNugS);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_menagBS, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Factory N Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_factNugN);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_factBN, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Factory S Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_factNugS);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_factBS, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Fort N Unlock Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_fortNugN);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagN, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Fort S Unlock Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_fortNugS);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagS, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	int fc = 0;
	int fd = 0;
	for (fc = 1; <= cNumberNonGaiaPlayers)
	{
	rmCreateTrigger("Fort N Plr" + fc);
	rmCreateTrigger("Fort S Plr" + fc);

	rmSwitchToTrigger(rmTriggerID("Fort_N_Plr" + fc));
	rmAddTriggerCondition("Units Owned");
	rmSetTriggerConditionParam("SrcObject", ""+unit_fortFlagN);
	rmSetTriggerConditionParamInt("Player", fc);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagN);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpIndianFortCornerProp");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagN);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpIndianFortWallSmallProp");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagN);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpIndianFortWallMediumProp");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagN);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpSPCFortStableProp");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagN);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpSPCFortBarracksProp");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagN);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpSPCFortTowerProp");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagN);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpPassableGateIndian");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagN);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpParisFlagNoIcon");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", fc);
	rmSetTriggerEffectParam("TechID", "cTechzpConvertWallIndian");
	rmSetTriggerEffectParamInt("Status", 2);
	for (fd = 1; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Fort_N_Plr" + fd));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Fort_S_Plr" + fc));
	rmAddTriggerCondition("Units Owned");
	rmSetTriggerConditionParam("SrcObject", ""+unit_fortFlagS);
	rmSetTriggerConditionParamInt("Player", fc);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagS);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpIndianFortCornerProp");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagS);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpIndianFortWallSmallProp");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagS);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpIndianFortWallMediumProp");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagS);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpSPCFortStableProp");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagS);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpSPCFortBarracksProp");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagS);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpSPCFortTowerProp");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagS);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpPassableGateIndian");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject", ""+unit_fortFlagS);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", fc);
	rmSetTriggerEffectParam("UnitType", "zpParisFlagNoIcon");
	rmSetTriggerEffectParamInt("Dist", 35);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", fc);
	rmSetTriggerEffectParam("TechID", "cTechzpConvertWallIndian");
	rmSetTriggerEffectParamInt("Status", 2);
	for (fd = 1; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Fort_S_Plr" + fd));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}


	// ========================================================================
	//  WATER FORT CONVERSION  (zpcaribbeanwars.xs 1042-1087, victory stripped)
	// ------------------------------------------------------------------------
	//  Uncontested-presence capture, each fort INDEPENDENT: >=1 own warship
	//  and 0 enemy warships within 25 m of the fort's marker converts the
	//  castle + city-state flags (15 m, from any owner incl. gaia). The
	//  winner's trigger stays consumed; everyone else's re-arms - the
	//  caribbeanwars tug-of-war. North = Black Sea (zpKingsHillNaval),
	//  south = Mediterranean (zpKingsHillNavalMedi clone).
	// ========================================================================

	for (fc = 1; <= cNumberNonGaiaPlayers)
	{
	rmCreateTrigger("FortConvN Plr" + fc);
	}
	for (fc = 1; <= cNumberNonGaiaPlayers)
	{
	rmSwitchToTrigger(rmTriggerID("FortConvN_Plr" + fc));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject", ""+fortMarkN);
	rmSetTriggerConditionParamInt("Player", fc);
	rmSetTriggerConditionParamInt("Dist", 25);
	rmSetTriggerConditionParam("UnitType", "AbstractWarShip");
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamFloat("Count", 1);
	for (fd = 1; <= cNumberNonGaiaPlayers)
	{
		if (fd != fc)
		{
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject", ""+fortMarkN);
			rmSetTriggerConditionParamInt("Player", fd);
			rmSetTriggerConditionParamInt("Dist", 25);
			rmSetTriggerConditionParam("UnitType", "AbstractWarShip");
			rmSetTriggerConditionParam("Op", "==");
			rmSetTriggerConditionParamFloat("Count", 0);
		}
	}
	for (fd = 0; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject", ""+fortMarkN);
		rmSetTriggerEffectParamInt("SrcPlayer", fd);
		rmSetTriggerEffectParamInt("TrgPlayer", fc);
		rmSetTriggerEffectParam("UnitType", "zpKingsHillNaval");
		rmSetTriggerEffectParamInt("Dist", 20);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject", ""+fortMarkN);
		rmSetTriggerEffectParamInt("SrcPlayer", fd);
		rmSetTriggerEffectParamInt("TrgPlayer", fc);
		rmSetTriggerEffectParam("UnitType", "zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist", 20);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject", ""+fortMarkN);
		rmSetTriggerEffectParamInt("SrcPlayer", fd);
		rmSetTriggerEffectParamInt("TrgPlayer", fc);
		rmSetTriggerEffectParam("UnitType", "zpSPCCapturableFlagInvisibleNaval");
		rmSetTriggerEffectParamInt("Dist", 20);
	}
	for (fd = 1; <= cNumberNonGaiaPlayers)
	{
		if (fd != fc)
		{
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("FortConvN_Plr" + fd));
		}
	}
	for (fd = 1; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerEffect("Flare Minimap");
		rmSetTriggerEffectParamInt("PlayerID", fd, false);
		rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
		rmSetTriggerEffectParam("Position", ""+xsVectorGetX(waterFortLocN)+","+xsVectorGetY(waterFortLocN)+","+xsVectorGetZ(waterFortLocN), false);
		rmSetTriggerEffectParam("Flash", "True", false);
	}
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset", "SheepFound");
	rmSetTriggerPriority(4);
	// LOCKED until the fort treasure is collected - FortNUnlock/FortSUnlock
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	for (fc = 1; <= cNumberNonGaiaPlayers)
	{
	rmCreateTrigger("FortConvS Plr" + fc);
	}
	for (fc = 1; <= cNumberNonGaiaPlayers)
	{
	rmSwitchToTrigger(rmTriggerID("FortConvS_Plr" + fc));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject", ""+fortMarkS);
	rmSetTriggerConditionParamInt("Player", fc);
	rmSetTriggerConditionParamInt("Dist", 25);
	rmSetTriggerConditionParam("UnitType", "AbstractWarShip");
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamFloat("Count", 1);
	for (fd = 1; <= cNumberNonGaiaPlayers)
	{
		if (fd != fc)
		{
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject", ""+fortMarkS);
			rmSetTriggerConditionParamInt("Player", fd);
			rmSetTriggerConditionParamInt("Dist", 25);
			rmSetTriggerConditionParam("UnitType", "AbstractWarShip");
			rmSetTriggerConditionParam("Op", "==");
			rmSetTriggerConditionParamFloat("Count", 0);
		}
	}
	for (fd = 0; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject", ""+fortMarkS);
		rmSetTriggerEffectParamInt("SrcPlayer", fd);
		rmSetTriggerEffectParamInt("TrgPlayer", fc);
		rmSetTriggerEffectParam("UnitType", "zpKingsHillNavalMedi");
		rmSetTriggerEffectParamInt("Dist", 20);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject", ""+fortMarkS);
		rmSetTriggerEffectParamInt("SrcPlayer", fd);
		rmSetTriggerEffectParamInt("TrgPlayer", fc);
		rmSetTriggerEffectParam("UnitType", "zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist", 20);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject", ""+fortMarkS);
		rmSetTriggerEffectParamInt("SrcPlayer", fd);
		rmSetTriggerEffectParamInt("TrgPlayer", fc);
		rmSetTriggerEffectParam("UnitType", "zpSPCCapturableFlagInvisibleNaval");
		rmSetTriggerEffectParamInt("Dist", 20);
	}
	for (fd = 1; <= cNumberNonGaiaPlayers)
	{
		if (fd != fc)
		{
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("FortConvS_Plr" + fd));
		}
	}
	for (fd = 1; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerEffect("Flare Minimap");
		rmSetTriggerEffectParamInt("PlayerID", fd, false);
		rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
		rmSetTriggerEffectParam("Position", ""+xsVectorGetX(waterFortLocS)+","+xsVectorGetY(waterFortLocS)+","+xsVectorGetZ(waterFortLocS), false);
		rmSetTriggerEffectParam("Flash", "True", false);
	}
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset", "SheepFound");
	rmSetTriggerPriority(4);
	// LOCKED until the fort treasure is collected - FortNUnlock/FortSUnlock
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// ========================================================================
	//  WATER FORT UNLOCK  -  guardians first, then the fort can change hands
	// ------------------------------------------------------------------------
	//  The forts have no AutoConvert action; capture is entirely trigger-driven
	//  by FortConvN/S_Plr. So the guard is simply that those triggers start
	//  INACTIVE and are ignited here once "Nugget Is Collectable" reports the
	//  fort treasure claimed - the same condition the harbours use at :3122,
	//  which releases a suspend instead.
	//  These two MUST be Active(true): they are the only igniters in the chain,
	//  and an inactive igniter would leave both forts permanently uncapturable.
	// ========================================================================
	int fu = 0;
	rmCreateTrigger("FortNUnlock");
	rmSwitchToTrigger(rmTriggerID("FortNUnlock"));
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_waterFortNugN);
	for (fu = 1; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("FortConvN_Plr" + fu));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("FortSUnlock");
	rmSwitchToTrigger(rmTriggerID("FortSUnlock"));
	rmAddTriggerCondition("Nugget Is Collectable");
	rmSetTriggerConditionParam("NuggetObject", ""+unit_waterFortNugS);
	for (fu = 1; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("FortConvS_Plr" + fu));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ========================================================================
	//  KOTH VICTORY  -  hold BOTH water forts for 10 minutes
	// ------------------------------------------------------------------------
	//  zp_z_zparis.xs 2298-2440 shape, unchanged. Paris counts ONE invisible
	//  flag across its three landmark groupings and tests ">= 3"; both water
	//  forts carry one zpSPCCapturableFlagInvisibleNaval, so "hold both" is
	//  ">= 2" - a single condition, and its exact negation "< 2" for the OFF.
	//  The counter's Event param is what fires TeamVictory - not a Fire Event.
	//  Counter text reuses {303290} "King of the Sea Victory in".
	// ========================================================================
	int victoryCountDown = 600;
	int vt = 0;
	for (vt = 1; < cNumberTeams+1)
	{
		rmCreateTrigger("TeamVictory"+vt);
		rmCreateTrigger("Victory_Counter"+vt);
		rmCreateTrigger("Victory_Counter_OFF"+vt);
	}
	for (vt = 1; < cNumberTeams+1)
	{
		rmSwitchToTrigger(rmTriggerID("TeamVictory"+vt));
		rmAddTriggerEffect("Team Victory");
		rmSetTriggerEffectParamInt("TeamID", vt);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Victory_Counter"+vt));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID", vt);
		rmSetTriggerConditionParam("Protounit", "zpSPCCapturableFlagInvisibleNaval");
		rmSetTriggerConditionParam("Op", ">=");
		rmSetTriggerConditionParamInt("Count", 2);
		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name", "VictoryCounter"+vt);
		rmSetTriggerEffectParamInt("Start", victoryCountDown);
		rmSetTriggerEffectParamInt("Stop", 0);
		rmSetTriggerEffectParam("Msg", "{303290}");
		rmSetTriggerEffectParamInt("Event", rmTriggerID("TeamVictory"+vt));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Victory_Counter_OFF"+vt));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Victory_Counter_OFF"+vt));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID", vt);
		rmSetTriggerConditionParam("Protounit", "zpSPCCapturableFlagInvisibleNaval");
		rmSetTriggerConditionParam("Op", "<");
		rmSetTriggerConditionParamInt("Count", 2);
		rmAddTriggerEffect("Counter Stop");
		rmSetTriggerEffectParam("Name", "VictoryCounter"+vt);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Victory_Counter"+vt));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// ========================================================================
	//  PIRATE CAMP TRIGGERS  (zp_mediterranean.xs idiom, its 1546-1885)
	// ------------------------------------------------------------------------
	//  A TradingPost on a camp socket converts that camps water spawn flag
	//  to the owner (pirate ships arrive there); losing the post hands the
	//  flag back to gaia. The zpPrivateerProxy trained at the post trips the
	//  train tech (slot 1 north / slot 2 south). Socket + flag unit ids come
	//  from the water-flag defs placed right after each camp grouping
	//  (socket = flag id - 1, the Independence War idiom).
	//  Plus the consulate hack: humans get cTechzpIsPirateMap and the
	//  asian-civ consulate pages; The Black Flag opens the Tortuga swap.
	// ========================================================================
	int pt = 0;
	for (pt = 1; <= cNumberNonGaiaPlayers)
	{
	rmCreateTrigger("PiratesNon Player" + pt);
	rmCreateTrigger("PiratesNoff Player" + pt);
	rmCreateTrigger("PiratesSon Player" + pt);
	rmCreateTrigger("PiratesSoff Player" + pt);
	rmCreateTrigger("TrainPrivNON Plr" + pt);
	rmCreateTrigger("TrainPrivNOFF Plr" + pt);
	rmCreateTrigger("TrainPrivNTIME Plr" + pt);
	rmCreateTrigger("TrainPrivSON Plr" + pt);
	rmCreateTrigger("TrainPrivSOFF Plr" + pt);
	rmCreateTrigger("TrainPrivSTIME Plr" + pt);
	rmCreateTrigger("UniqueShipNTIME Plr" + pt);
	rmCreateTrigger("BlackbTrainNON Plr" + pt);
	rmCreateTrigger("BlackbTrainNOFF Plr" + pt);
	rmCreateTrigger("GraceTrainNON Plr" + pt);
	rmCreateTrigger("GraceTrainNOFF Plr" + pt);
	rmCreateTrigger("CaesarTrainNON Plr" + pt);
	rmCreateTrigger("CaesarTrainNOFF Plr" + pt);
	rmCreateTrigger("UniqueShipSTIME Plr" + pt);
	rmCreateTrigger("BlackbTrainSON Plr" + pt);
	rmCreateTrigger("BlackbTrainSOFF Plr" + pt);
	rmCreateTrigger("GraceTrainSON Plr" + pt);
	rmCreateTrigger("GraceTrainSOFF Plr" + pt);
	rmCreateTrigger("CaesarTrainSON Plr" + pt);
	rmCreateTrigger("CaesarTrainSOFF Plr" + pt);
	rmCreateTrigger("Human Check Plr" + pt);
	rmCreateTrigger("Activate Consulate Japanese" + pt);
	rmCreateTrigger("Activate Consulate Chinese" + pt);
	rmCreateTrigger("Activate Consulate Indians" + pt);
	rmCreateTrigger("Activate Tortuga" + pt);

	rmSwitchToTrigger(rmTriggerID("PiratesNon_Player" + pt));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+pirateSocketN);
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParamInt("Dist", 35);
	rmSetTriggerConditionParam("UnitType", "TradingPost");
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamFloat("Count", 1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+pirateSocketN);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", pt);
	rmSetTriggerEffectParam("UnitType", "zpPirateWaterSpawnFlag1");
	rmSetTriggerEffectParamInt("Dist", 150);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("PiratesNoff_Player" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivNON_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrainNON_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrainNON_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrainNON_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("PiratesNoff_Player" + pt));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+pirateSocketN);
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParamInt("Dist", 35);
	rmSetTriggerConditionParam("UnitType", "TradingPost");
	rmSetTriggerConditionParam("Op", "==");
	rmSetTriggerConditionParamFloat("Count", 0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+pirateSocketN);
	rmSetTriggerEffectParamInt("SrcPlayer", pt);
	rmSetTriggerEffectParamInt("TrgPlayer", 0);
	rmSetTriggerEffectParam("UnitType", "zpPirateWaterSpawnFlag1");
	rmSetTriggerEffectParamInt("Dist", 150);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("PiratesNon_Player" + pt));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivNON_Plr" + pt));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrainNON_Plr" + pt));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrainNON_Plr" + pt));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrainNON_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("PiratesSon_Player" + pt));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+pirateSocketS);
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParamInt("Dist", 35);
	rmSetTriggerConditionParam("UnitType", "TradingPost");
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamFloat("Count", 1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+pirateSocketS);
	rmSetTriggerEffectParamInt("SrcPlayer", 0);
	rmSetTriggerEffectParamInt("TrgPlayer", pt);
	rmSetTriggerEffectParam("UnitType", "zpPirateWaterSpawnFlag2");
	rmSetTriggerEffectParamInt("Dist", 150);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("PiratesSoff_Player" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivSON_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrainSON_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrainSON_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrainSON_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("PiratesSoff_Player" + pt));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+pirateSocketS);
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParamInt("Dist", 35);
	rmSetTriggerConditionParam("UnitType", "TradingPost");
	rmSetTriggerConditionParam("Op", "==");
	rmSetTriggerConditionParamFloat("Count", 0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+pirateSocketS);
	rmSetTriggerEffectParamInt("SrcPlayer", pt);
	rmSetTriggerEffectParamInt("TrgPlayer", 0);
	rmSetTriggerEffectParam("UnitType", "zpPirateWaterSpawnFlag2");
	rmSetTriggerEffectParamInt("Dist", 150);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("PiratesSon_Player" + pt));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivSON_Plr" + pt));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrainSON_Plr" + pt));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrainSON_Plr" + pt));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrainSON_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivNON_Plr" + pt));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+pirateSocketN);
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParam("UnitType", "zpPrivateerProxy");
	rmSetTriggerConditionParamInt("Dist", 35);
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamInt("Count", 1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTrainPrivateer1");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivNOFF_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivNTIME_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivNOFF_Plr" + pt));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1", 1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivNON_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivNTIME_Plr" + pt));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1", 200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpPrivateerBuildLimitReduceShadow");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTrainPrivateer1");
	rmSetTriggerEffectParamInt("Status", 0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("UniqueShipNTIME_Plr" + pt));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1", 200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpReducePirateShipsBuildLimit");
	rmSetTriggerEffectParamInt("Status", 2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BlackbTrainNON_Plr" + pt));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+pirateSocketN);
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParam("UnitType", "zpSPCQueenAnneProxy");
	rmSetTriggerConditionParamInt("Dist", 35);
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamInt("Count", 1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTrainQueenAnne1");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShipNTIME_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrainNOFF_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BlackbTrainNOFF_Plr" + pt));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1", 1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrainNON_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("GraceTrainNON_Plr" + pt));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+pirateSocketN);
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParam("UnitType", "zpSPCBlackPearlProxy");
	rmSetTriggerConditionParamInt("Dist", 35);
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamInt("Count", 1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTrainBlackPearl1");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShipNTIME_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrainNOFF_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("GraceTrainNOFF_Plr" + pt));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1", 1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrainNON_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("CaesarTrainNON_Plr" + pt));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+pirateSocketN);
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParam("UnitType", "zpSPCNeptuneGalleyProxy");
	rmSetTriggerConditionParamInt("Dist", 35);
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamInt("Count", 1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTrainNeptune1");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShipNTIME_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrainNOFF_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("CaesarTrainNOFF_Plr" + pt));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1", 1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrainNON_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivSON_Plr" + pt));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+pirateSocketS);
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParam("UnitType", "zpPrivateerProxy");
	rmSetTriggerConditionParamInt("Dist", 35);
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamInt("Count", 1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTrainPrivateer2");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivSOFF_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivSTIME_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivSOFF_Plr" + pt));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1", 1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivSON_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivSTIME_Plr" + pt));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1", 200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpPrivateerBuildLimitReduceShadow");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTrainPrivateer2");
	rmSetTriggerEffectParamInt("Status", 0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("UniqueShipSTIME_Plr" + pt));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1", 200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpReducePirateShipsBuildLimit");
	rmSetTriggerEffectParamInt("Status", 2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BlackbTrainSON_Plr" + pt));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+pirateSocketS);
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParam("UnitType", "zpSPCQueenAnneProxy");
	rmSetTriggerConditionParamInt("Dist", 35);
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamInt("Count", 1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTrainQueenAnne2");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShipSTIME_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrainSOFF_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BlackbTrainSOFF_Plr" + pt));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1", 1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrainSON_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("GraceTrainSON_Plr" + pt));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+pirateSocketS);
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParam("UnitType", "zpSPCBlackPearlProxy");
	rmSetTriggerConditionParamInt("Dist", 35);
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamInt("Count", 1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTrainBlackPearl2");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShipSTIME_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrainSOFF_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("GraceTrainSOFF_Plr" + pt));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1", 1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrainSON_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("CaesarTrainSON_Plr" + pt));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+pirateSocketS);
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParam("UnitType", "zpSPCNeptuneGalleyProxy");
	rmSetTriggerConditionParamInt("Dist", 35);
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamInt("Count", 1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTrainNeptune2");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShipSTIME_Plr" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrainSOFF_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("CaesarTrainSOFF_Plr" + pt));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1", 1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrainSON_Plr" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Human_Check_Plr" + pt));
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParam("MyBool", "true");
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpIsPirateMap");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Japanese" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Chinese" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Indians" + pt));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Tortuga" + pt));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Activate_Consulate_Japanese" + pt));
	rmAddTriggerCondition("ZP Player Civilization");
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParam("Civilization", "Japanese");
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID", "cTechzpPickConsulateTechAvailable");
	rmSetTriggerConditionParamInt("PlayerID", pt);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTurnConsulateOnJapanese");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpBigButtonResearchDecrease");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("ZP Pick Consulate Tech");
	rmSetTriggerEffectParamInt("Player", pt);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(true);

	rmSwitchToTrigger(rmTriggerID("Activate_Consulate_Chinese" + pt));
	rmAddTriggerCondition("ZP Player Civilization");
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParam("Civilization", "Chinese");
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID", "cTechzpPickConsulateTechAvailable");
	rmSetTriggerConditionParamInt("PlayerID", pt);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTurnConsulateOnChinese");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpBigButtonResearchDecrease");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("ZP Pick Consulate Tech");
	rmSetTriggerEffectParamInt("Player", pt);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(true);

	rmSwitchToTrigger(rmTriggerID("Activate_Consulate_Indians" + pt));
	rmAddTriggerCondition("ZP Player Civilization");
	rmSetTriggerConditionParamInt("Player", pt);
	rmSetTriggerConditionParam("Civilization", "Indians");
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID", "cTechzpPickConsulateTechAvailable");
	rmSetTriggerConditionParamInt("PlayerID", pt);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTurnConsulateOnIndian");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpBigButtonResearchDecrease");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("ZP Pick Consulate Tech");
	rmSetTriggerEffectParamInt("Player", pt);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(true);

	rmSwitchToTrigger(rmTriggerID("Activate_Tortuga" + pt));
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID", "cTechzpTheBlackFlag");
	rmSetTriggerConditionParamInt("PlayerID", pt);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpTurnConsulateOffPirates");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID", pt);
	rmSetTriggerEffectParam("TechID", "cTechzpBigButtonResearchDecrease");
	rmSetTriggerEffectParamInt("Status", 2);
	rmAddTriggerEffect("ZP Pick Consulate Tech");
	rmSetTriggerEffectParamInt("Player", pt);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(true);
	}

	rmSetStatusText("", 1.00);
}
