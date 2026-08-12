// ============================================================================
// 000_gun_test.xs  -  Istanbul: two city islands + four floating gun islands
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
		while (pick >= total)
		{
			pick = pick - total;
		}

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
	rmSetAreaCliffType(top, gCliffType);
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
void shoreScaffold(float x = 0.0, float z = 0.0, int tiles = 700)
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
void shoreRiver(float x = 0.0, float z = 0.0, int width = 24, float reach = 0.05)
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


void main(void)
{
	rmSetStatusText("", 0.01);

	// ========================================================================
	//  TUNABLES  -  everything you are likely to change lives here
	// ========================================================================
	int   mapSize     = 600;    // metres, square

	// Where we ASK for the lanes. The engine will snap them; the real values
	// are measured further down and everything is built from those.
	float nRouteAsk   = 0.54;   // NORTH lane (higher Z = north), runs E -> W
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
	float balanceCliffX   = 0.47;
	float balanceCliffZ   = 0.02;   // lower = further back toward the edge
	float balanceCliffLen = 0.055;  // half-length E-W; this is what makes it
	                                // an ellipse instead of a circle
	float balanceCliffSize= 0.006; // area as a fraction of the map
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
	//   harbour 5  <- deco ->  harbour 3  <- deco ->  pirates
	int   decoNEDist       = 3;   // tiles out from the NE coast (same as the harbours)
	int   decoSWDist       = 4;  // tiles out from the SW coast (south island)
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
	rmSetWorldCircleConstraint(true);

	rmDefineClass("classPlateau");
	rmDefineClass("classBlock");
	rmDefineClass("classStreet");
	rmDefineClass("classCliff");


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
		nz3Ask + rmZTilesToFraction(northPirateBack), 1600);
	shoreScaffold(sx1 - flankProm - rmXTilesToFraction(southPirateDist),
		sz3Ask - rmZTilesToFraction(southPirateBack), 1600);

	// ========================================================================
	//  4. TRADE ROUTES  ->  then MEASURE where they really are
	// ========================================================================
	int tradeRouteN = rmCreateTradeRoute();
	// north lane
	rmAddTradeRouteWaypoint(tradeRouteN, 0.90, 0.90);   // NE corner
	rmAddTradeRouteWaypoint(tradeRouteN, 0.70, 0.76);   // past flank harbour
	rmAddTradeRouteWaypoint(tradeRouteN, 0.70, 0.54);   // into channel
	rmAddTradeRouteWaypoint(tradeRouteN, 0.50, 0.54);   // mid channel
	rmAddTradeRouteWaypoint(tradeRouteN, 0.25, 0.54);   // corner
	rmAddTradeRouteWaypoint(tradeRouteN, 0.00, 0.30);   // corner


	rmBuildTradeRoute(tradeRouteN, "water_trail");

	int tradeRouteS = rmCreateTradeRoute();
	// south lane
	rmAddTradeRouteWaypoint(tradeRouteS, 0.10, 0.10);   // SW corner
	rmAddTradeRouteWaypoint(tradeRouteS, 0.25, 0.25);   // past flank harbour
	rmAddTradeRouteWaypoint(tradeRouteS, 0.25, 0.46);   // into channel
	rmAddTradeRouteWaypoint(tradeRouteS, 0.50, 0.46);   // mid channel
	rmAddTradeRouteWaypoint(tradeRouteS, 0.75, 0.46);   // corner
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
	shoreRiver(nx1, nGunZ);
	shoreRiver(nx5, nGunZ);
	shoreRiver(sx1, sGunZ);
	shoreRiver(sx5, sGunZ);
	shoreRiver(nx3, nTradeZ);
	shoreRiver(sx3, sTradeZ);
	shoreRiver(nFlankX, nFlankZ);
	shoreRiver(sFlankX, sFlankZ);
	shoreRiver(nFlankX, nFlank2Z);
	shoreRiver(sFlankX, sFlank2Z);
	shoreRiver(nPirateX, nPirateZ, 34, 0.07);
	shoreRiver(sPirateX, sPirateZ, 34, 0.07);

	// PHASE B - only now the guns go down
	placeShoreIsland(gunNW, nx1, nGunZ);
	placeShoreIsland(gunNE, nx5, nGunZ);
	placeShoreIsland(gunSW, sx1, sGunZ);
	placeShoreIsland(gunSE, sx5, sGunZ);
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
	placeShoreIsland(pirateS, sPirateX, sPirateZ);   // south island, back of its coast

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
		nx1 - margin, nz1 - promenade, nx5 + flankProm, nz6 + margin, 0.01);
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
		sx1 - flankProm, sz6 - margin, sx5 + margin, sz1 + promenade, 0.01);
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
	int avoidStreet = rmCreateClassDistanceConstraint("hinterland off the street",
		rmClassID("classStreet"), 0.0);

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

	// --- the balancing cliff, BEFORE the trees so they can keep off it -----
	// stands on the south countryside already, so no land is laid (0)
	cliffMass(balanceCliffX, balanceCliffZ, 0, balanceCliffSize,
		balanceRise, balanceCliffLen);

	// trees stay one tile clear of the cliff
	// Distance here is METRES, not a map fraction - every shipped map passes
	// plain numbers (20.0, 30.0, 8.0) and not one passes a ToFraction helper.
	// 1 tile = 2 m, so one tile of clearance is 2.0.
	int avoidCliff = rmCreateClassDistanceConstraint("trees off the cliff",
		rmClassID("classCliff"), 5.0);

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
	int isAuditore  = rmCreateGrouping("is auditore",     "IS_Native_Block_Auditore");
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
	int natAuditore = rmCreateGrouping("native auditore", "IS_Native_Block_Auditore");

	int natID = 0;
	int natList = xsArrayCreateInt(4, 0, "istanbul natives");
	xsArraySetInt(natList, 0, natOrthodox);
	xsArraySetInt(natList, 1, natPhanar);
	xsArraySetInt(natList, 2, natSufi);
	xsArraySetInt(natList, 3, natAuditore);
	for (in = 0; < 4)
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

	int relNorth = natSufi;       int relSouth = natOrthodox;
	if (flipRel < 50) { relNorth = natOrthodox;  relSouth = natSufi; }

	int royNorth = natAuditore;   int roySouth = natPhanar;
	if (flipRoy < 50) { royNorth = natPhanar;    roySouth = natAuditore; }

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
	int fortN = rmCreateGrouping("fort north", "IS_SPC_Military");
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
	const int N_BACK_START   = 12;   const int N_BACK_END   = 18;   // rows 5 + 6
	const int S_CENTRE_START = 19;   const int S_CENTRE_END = 26;
	const int S_SUBURB_START = 27;   const int S_SUBURB_END = 30;   // row 4 only
	const int S_BACK_START   = 31;   const int S_BACK_END   = 37;   // rows 5 + 6
	const int NUM_CITY_LOCS  = 38;

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
	// north back: row 5 minus the construction corners, row 6 minus the forester
	xsArraySetVector(gCityLocs, 12, xsVectorSet(nx2, 0.0, nz5));   xsArraySetInt(gCityCode, 12, 205);
	xsArraySetVector(gCityLocs, 13, xsVectorSet(nx3, 0.0, nz5));   xsArraySetInt(gCityCode, 13, 305);
	xsArraySetVector(gCityLocs, 14, xsVectorSet(nx4, 0.0, nz5));   xsArraySetInt(gCityCode, 14, 405);
	xsArraySetVector(gCityLocs, 15, xsVectorSet(nx1, 0.0, nz6));   xsArraySetInt(gCityCode, 15, 106);
	xsArraySetVector(gCityLocs, 16, xsVectorSet(nx2, 0.0, nz6));   xsArraySetInt(gCityCode, 16, 206);
	xsArraySetVector(gCityLocs, 17, xsVectorSet(nx4, 0.0, nz6));   xsArraySetInt(gCityCode, 17, 406);
	xsArraySetVector(gCityLocs, 18, xsVectorSet(nx5, 0.0, nz6));   xsArraySetInt(gCityCode, 18, 506);
	// south centre: mirrored
	xsArraySetVector(gCityLocs, 19, xsVectorSet(sx2, 0.0, sz1));   xsArraySetInt(gCityCode, 19, 201);
	xsArraySetVector(gCityLocs, 20, xsVectorSet(sx1, 0.0, sz2));   xsArraySetInt(gCityCode, 20, 102);
	xsArraySetVector(gCityLocs, 21, xsVectorSet(sx4, 0.0, sz2));   xsArraySetInt(gCityCode, 21, 402);
	xsArraySetVector(gCityLocs, 22, xsVectorSet(sx5, 0.0, sz2));   xsArraySetInt(gCityCode, 22, 502);
	xsArraySetVector(gCityLocs, 23, xsVectorSet(sx1, 0.0, sz3));   xsArraySetInt(gCityCode, 23, 103);
	xsArraySetVector(gCityLocs, 24, xsVectorSet(sx2, 0.0, sz3));   xsArraySetInt(gCityCode, 24, 203);
	xsArraySetVector(gCityLocs, 25, xsVectorSet(sx4, 0.0, sz3));   xsArraySetInt(gCityCode, 25, 403);
	xsArraySetVector(gCityLocs, 26, xsVectorSet(sx5, 0.0, sz3));   xsArraySetInt(gCityCode, 26, 503);
	// south suburb: ROW 4 ONLY, mirrored
	xsArraySetVector(gCityLocs, 27, xsVectorSet(sx2, 0.0, sz4));   xsArraySetInt(gCityCode, 27, 204);
	xsArraySetVector(gCityLocs, 28, xsVectorSet(sx3, 0.0, sz4));   xsArraySetInt(gCityCode, 28, 304);
	xsArraySetVector(gCityLocs, 29, xsVectorSet(sx4, 0.0, sz4));   xsArraySetInt(gCityCode, 29, 404);
	xsArraySetVector(gCityLocs, 30, xsVectorSet(sx5, 0.0, sz4));   xsArraySetInt(gCityCode, 30, 504);
	// south back: mirrored, row 6 minus the forester
	xsArraySetVector(gCityLocs, 31, xsVectorSet(sx2, 0.0, sz5));   xsArraySetInt(gCityCode, 31, 205);
	xsArraySetVector(gCityLocs, 32, xsVectorSet(sx3, 0.0, sz5));   xsArraySetInt(gCityCode, 32, 305);
	xsArraySetVector(gCityLocs, 33, xsVectorSet(sx4, 0.0, sz5));   xsArraySetInt(gCityCode, 33, 405);
	xsArraySetVector(gCityLocs, 34, xsVectorSet(sx1, 0.0, sz6));   xsArraySetInt(gCityCode, 34, 106);
	xsArraySetVector(gCityLocs, 35, xsVectorSet(sx2, 0.0, sz6));   xsArraySetInt(gCityCode, 35, 206);
	xsArraySetVector(gCityLocs, 36, xsVectorSet(sx4, 0.0, sz6));   xsArraySetInt(gCityCode, 36, 406);
	xsArraySetVector(gCityLocs, 37, xsVectorSet(sx5, 0.0, sz6));   xsArraySetInt(gCityCode, 37, 506);

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
	// ---- CONSTRUCTION BLOCKS: the two z5 corners, fixed ------------------
	// One backs onto the pirate camp (the flank-coast corner), the other takes
	// the opposite corner of the suburb. Both cells are excluded from the
	// shuffle pool above, so nothing else can land on them.
	int constrPirateN = rmCreateGrouping("construction n pirate", "IS_SPC_Construction");
	rmSetGroupingMinDistance(constrPirateN, 0.0);  rmSetGroupingMaxDistance(constrPirateN, 0.5);
	rmAddGroupingToClass(constrPirateN, rmClassID("classBlock"));
	rmPlaceGroupingAtLoc(constrPirateN, 0, nx5, nz5);

	int constrCornerN = rmCreateGrouping("construction n corner", "IS_SPC_Construction");
	rmSetGroupingMinDistance(constrCornerN, 0.0);  rmSetGroupingMaxDistance(constrCornerN, 0.5);
	rmAddGroupingToClass(constrCornerN, rmClassID("classBlock"));
	rmPlaceGroupingAtLoc(constrCornerN, 0, nx1, nz5);

	int constrPirateS = rmCreateGrouping("construction s pirate", "IS_SPC_Construction");
	rmSetGroupingMinDistance(constrPirateS, 0.0);  rmSetGroupingMaxDistance(constrPirateS, 0.5);
	rmAddGroupingToClass(constrPirateS, rmClassID("classBlock"));
	rmPlaceGroupingAtLoc(constrPirateS, 0, sx1, sz5);

	int constrCornerS = rmCreateGrouping("construction s corner", "IS_SPC_Construction");
	rmSetGroupingMinDistance(constrCornerS, 0.0);  rmSetGroupingMaxDistance(constrCornerS, 0.5);
	rmAddGroupingToClass(constrCornerS, rmClassID("classBlock"));
	rmPlaceGroupingAtLoc(constrCornerS, 0, sx5, sz5);

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
	float decoNEX  = nx5 + flankProm + rmXTilesToFraction(decoNEDist);
	float decoNEZ1 = (nFlank2Z + nFlankZ) * 0.5;   // between harbour 5 and harbour 3
	float decoNEZ2 = (nFlankZ + nPirateZ) * 0.5;   // between harbour 3 and the pirates
	rmPlaceGroupingAtLoc(decoNE,  0, decoNEX, decoNEZ1);
	rmPlaceGroupingAtLoc(decoNE2, 0, decoNEX, decoNEZ2);

	// ---- SW coast of the south island: mirror of the NE pair --------------
	int decoSW  = rmCreateGrouping("deco shoreline sw 1", decoShorelineSW);
	rmSetGroupingMinDistance(decoSW, 0.0);
	rmSetGroupingMaxDistance(decoSW, 0.01);
	int decoSW2 = rmCreateGrouping("deco shoreline sw 2", decoShorelineSW);
	rmSetGroupingMinDistance(decoSW2, 0.0);
	rmSetGroupingMaxDistance(decoSW2, 0.01);

	float decoSWX  = sx1 - flankProm - rmXTilesToFraction(decoSWDist);
	float decoSWZ1 = (sFlank2Z + sFlankZ) * 0.5;   // between harbour 6 and harbour 4
	float decoSWZ2 = (sFlankZ + sPirateZ) * 0.5;   // between harbour 4 and the pirates
	rmPlaceGroupingAtLoc(decoSW,  0, decoSWX, decoSWZ1);
	rmPlaceGroupingAtLoc(decoSW2, 0, decoSWX, decoSWZ2);


	rmSetStatusText("", 0.85);

	// ========================================================================
	//  8. PLAYERS  (stub)
	// ========================================================================
	rmPlacePlayersCircular(0.42, 0.42, 0.0);

	// ========================================================================
	//  TRADE HARBOUR CONVERSION  (000_independence_war.xs idiom)
	// ------------------------------------------------------------------------
	// Every trade socket starts with AutoConvert SUSPENDED, so nobody can take
	// it while its guardian nugget still stands. Once that nugget becomes
	// collectable the matching trigger releases the suspension.
	// ========================================================================

	int unit_harbourSocketN = rmGetUnitPlaced(harbourSocketN, 0);
	int unit_nugHN = rmGetGroupingInstanceUnitByType(tradeNPlacement, "Nugget");
	int unit_harbourSocketS = rmGetUnitPlaced(harbourSocketS, 0);
	int unit_nugHS = rmGetGroupingInstanceUnitByType(tradeSPlacement, "Nugget");
	int unit_flankSocketN = rmGetUnitPlaced(flankSocketN, 0);
	int unit_nugH3 = rmGetGroupingInstanceUnitByType(trade3Placement, "Nugget");
	int unit_flankSocketS = rmGetUnitPlaced(flankSocketS, 0);
	int unit_nugH4 = rmGetGroupingInstanceUnitByType(trade4Placement, "Nugget");
	int unit_flank2SocketN = rmGetUnitPlaced(flank2SocketN, 0);
	int unit_nugH5 = rmGetGroupingInstanceUnitByType(trade5Placement, "Nugget");
	int unit_flank2SocketS = rmGetUnitPlaced(flank2SocketS, 0);
	int unit_nugH6 = rmGetGroupingInstanceUnitByType(trade6Placement, "Nugget");

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

	rmSetStatusText("", 1.00);
}
