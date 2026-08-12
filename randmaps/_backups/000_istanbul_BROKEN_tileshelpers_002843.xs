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

// Tiles -> fraction, SIGN SAFE.
// rmXTilesToFraction / rmZTilesToFraction do not handle a negative argument -
// every value <= 0 comes back the same, so a knob like "-10" silently did
// nothing and "-50" did exactly the same nothing. These pass a positive number
// to the engine and negate the result themselves.
float tilesX(int t = 0)
{
	if (t < 0)
	{
		return(0.0 - rmXTilesToFraction(0 - t));
	}
	return(rmXTilesToFraction(t));
}

float tilesZ(int t = 0)
{
	if (t < 0)
	{
		return(0.0 - rmZTilesToFraction(0 - t));
	}
	return(rmZTilesToFraction(t));
}

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
	return(rmZMetersToFraction(xsVectorGetZ(loc)));
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
	int   southGunDist    = 10;   // south lane -> south gun islands
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
	int   flankPromExtra  = 1;    // extra tiles of shoreline on the FLANK coast
	                              // that carries trade harbours 3 and 4

	float cityHeight      = 3.0;  // was 2.0 in 000_istanbul at sea level 0.0

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
	float northHarbourOffX = -0.0716;
	float northHarbourOffZ = -7.5912;
	float southHarbourOffX = -2.3773;
	float southHarbourOffZ =  3.1930;
	// Flank harbours: north uses the Trade_04 XML, south uses Trade_03.
	float northFlankOffX   =  4.2043;
	float northFlankOffZ   = -4.2629;
	float southFlankOffX   = -7.3477;
	float southFlankOffZ   = -0.6680;

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
	int   southFlankDist  = 2;    // out from the south island's SW coast
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
	string decoShoreline  = "IS_Deco_Shoreline_N";
	//   ...Nudge   = fine tune along the shore, tiles (- west / + east)
	//   decoShoreIn = tiles inland from the water's edge. Small = right at the
	//                 waterline; the piece is 12 tiles deep, so ~2 keeps its
	//                 water side on the shore.
	int   decoWestNudge   = 0;
	int   decoEastNudge   = 0;
	int   decoShoreIn     = -50;

	string piratesNorth   = "IS_Shore_Pirates_02";
	string piratesSouth   = "IS_Shore_Pirates_01";
	int   northPirateDist = 4;    // tiles out from that coast
	int   northPirateBack = 34;   // tiles along the coast, away from the channel
	int   southPirateDist = 4;
	int   southPirateBack = 34;

	int   northBendOut    = 13;
	int   northBendAlong  = 4;
	int   southBendOut    = 13;
	int   southBendAlong  = 4;

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
	rmSetWorldCircleConstraint(true);

	rmDefineClass("classPlateau");
	rmDefineClass("classBlock");
	rmDefineClass("classStreet");

	rmSetStatusText("", 0.08);

	// ========================================================================
	//  2. COLUMNS  -  east/west only, so they need no route measurement
	// ========================================================================
	float colPitch = tilesX(blockPitch);
	float rowPitch = tilesZ(blockPitch);
	float margin   = colPitch * 0.6;            // plateau margin around a grid
	// The shore that faces the trade route is pushed out further, so the quay
	// in front of the first block row is wider.
	float promenade = margin + tilesZ(promenadeExtra);
	// the flank coast that carries harbours 3 / 4 gets its own wider quay
	float flankProm = margin + tilesX(flankPromExtra);

	// Shared column skeleton, west -> east, centred on the channel.
	float x1 = 0.5 - colPitch * 2.0;
	float x2 = 0.5 - colPitch;
	float x3 = 0.5;
	float x4 = 0.5 + colPitch;
	float x5 = 0.5 + colPitch * 2.0;

	// Each island owns a copy of those columns, shifted by its own nudge.
	float nDX = tilesX(northCityShiftX);
	float sDX = tilesX(southCityShiftX);

	float nx1 = x1 + nDX;   float nx2 = x2 + nDX;   float nx3 = x3 + nDX;
	float nx4 = x4 + nDX;   float nx5 = x5 + nDX;

	float sx1 = x1 + sDX;   float sx2 = x2 + sDX;   float sx3 = x3 + sDX;
	float sx4 = x4 + sDX;   float sx5 = x5 + sDX;

	// ---- NOMINAL ISLAND GEOMETRY -----------------------------------------
	// The lanes do not exist yet, so anything needed before they are built
	// (scaffolds, trade route waypoints) is derived from the REQUESTED lane
	// positions. Measured values take over afterwards.
	float nz3Ask = nRouteAsk + tilesZ(northCityDist) + rowPitch + rowPitch
		+ tilesZ(northFlankAlong);
	float sz3Ask = sRouteAsk - tilesZ(southCityDist) - rowPitch - rowPitch
		+ tilesZ(southFlankAlong);
	// where each lane bends around its island's flank harbour (clear of its hull)
	// the corner sits out past the harbour AND up the coast, so the waypoint
	// never lands on the harbour itself
	float nBendX = nx5 + flankProm + tilesX(northFlankDist + northBendOut);
	float sBendX = sx1 - flankProm - tilesX(southFlankDist + southBendOut);
	float nBendZ = nz3Ask + tilesZ(northBendAlong);
	float sBendZ = sz3Ask - tilesZ(southBendAlong);

	// ========================================================================
	//  3. GUN SCAFFOLDS  -  built before any river exists
	// ------------------------------------------------------------------------
	// These use the REQUESTED lane positions, because the routes do not exist
	// yet. That is fine: a scaffold is ~19 tiles across against a 9-tile gun,
	// so it still covers the spot after the lane snaps a few tiles.
	// ========================================================================
	shoreScaffold(nx1, nRouteAsk + tilesZ(northGunDist));
	shoreScaffold(nx5, nRouteAsk + tilesZ(northGunDist));
	shoreScaffold(sx1, sRouteAsk - tilesZ(southGunDist));
	shoreScaffold(sx5, sRouteAsk - tilesZ(southGunDist));
	shoreScaffold(nx3, nRouteAsk + tilesZ(northTradeDist));
	shoreScaffold(sx3, sRouteAsk - tilesZ(southTradeDist));
	// flank harbours: x needs no lane, z uses the nominal middle row (z3)
	shoreScaffold(nx5 + flankProm + tilesX(northFlankDist), nz3Ask);
	shoreScaffold(sx1 - flankProm - tilesX(southFlankDist), sz3Ask);
	shoreScaffold(nx5 + flankProm + tilesX(northFlankDist),
		nz3Ask - tilesZ(northFlank2Toward));
	shoreScaffold(sx1 - flankProm - tilesX(southFlankDist),
		sz3Ask + tilesZ(southFlank2Toward));
	shoreScaffold(nx5 + flankProm + tilesX(northPirateDist),
		nz3Ask + tilesZ(northPirateBack), 1600);
	shoreScaffold(sx1 - flankProm - tilesX(southPirateDist),
		sz3Ask - tilesZ(southPirateBack), 1600);

	// ========================================================================
	//  4. TRADE ROUTES  ->  then MEASURE where they really are
	// ========================================================================
	int tradeRouteN = rmCreateTradeRoute();
	// Curves around the north island: enters at the NE, sweeps past the flank
	// harbour, bends down to the channel, then runs the straight middle west.
	rmAddTradeRouteWaypoint(tradeRouteN, 0.9, 0.9);
	rmAddTradeRouteWaypoint(tradeRouteN, nBendX, nBendZ);
	rmAddTradeRouteWaypoint(tradeRouteN, nBendX, nRouteAsk);
	rmAddTradeRouteWaypoint(tradeRouteN, 0.5, nRouteAsk);
	rmAddTradeRouteWaypoint(tradeRouteN, 0.0, nRouteAsk);
	rmBuildTradeRoute(tradeRouteN, "water_trail");

	int tradeRouteS = rmCreateTradeRoute();
	// Mirror image on the south island: in from the SW past its flank harbour,
	// bend up to the channel, then the straight middle east.
	rmAddTradeRouteWaypoint(tradeRouteS, 0.1, 0.1);
	rmAddTradeRouteWaypoint(tradeRouteS, sBendX, sBendZ);
	rmAddTradeRouteWaypoint(tradeRouteS, sBendX, sRouteAsk);
	rmAddTradeRouteWaypoint(tradeRouteS, 0.5, sRouteAsk);
	rmAddTradeRouteWaypoint(tradeRouteS, 1.0, sRouteAsk);
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
	float nz1 = nRouteZ + tilesZ(northCityDist);
	float nz2 = nz1 + rowPitch;
	float nz3 = nz2 + rowPitch;
	float nz4 = nz3 + rowPitch;
	float nz5 = nz4 + rowPitch;

	float sz1 = sRouteZ - tilesZ(southCityDist);
	float sz2 = sz1 - rowPitch;
	float sz3 = sz2 - rowPitch;
	float sz4 = sz3 - rowPitch;
	float sz5 = sz4 - rowPitch;

	// Gun islands sit out in the channel, at each island's inner corners.
	float nGunZ = nRouteZ + tilesZ(northGunDist);
	float sGunZ = sRouteZ - tilesZ(southGunDist);

	// Trade harbours sit on the same shores, midway between the two guns.
	float nTradeZ = nRouteZ + tilesZ(northTradeDist);
	float sTradeZ = sRouteZ - tilesZ(southTradeDist);

	// Flank harbours: middle of each island's flank coast (row z3).
	float nFlankX = nx5 + flankProm + tilesX(northFlankDist);
	float sFlankX = sx1 - flankProm - tilesX(southFlankDist);
	float nFlankZ = nz3 + tilesZ(northFlankAlong);
	float sFlankZ = sz3 + tilesZ(southFlankAlong);

	// pirate camps: same coasts, pushed to the back of each island
	// second flank harbours - identical X to 3 / 4, their own row
	float nFlank2Z = nz3 - tilesZ(northFlank2Toward);
	float sFlank2Z = sz3 + tilesZ(southFlank2Toward);

	float nPirateX = nx5 + flankProm + tilesX(northPirateDist);
	float sPirateX = sx1 - flankProm - tilesX(southPirateDist);
	float nPirateZ = nz3 + tilesZ(northPirateBack);
	float sPirateZ = sz3 - tilesZ(southPirateBack);

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
		nFlankX  + rmXMetersToFraction(northFlankOffX),
		nFlank2Z + rmZMetersToFraction(northFlankOffZ));
	vector flank2LocN = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(flank2SocketN, 0));

	placeShoreIsland(trade5,
		rmXMetersToFraction(xsVectorGetX(flank2LocN)) - rmXMetersToFraction(northFlankOffX),
		rmZMetersToFraction(xsVectorGetZ(flank2LocN)) - rmZMetersToFraction(northFlankOffZ));

	int flank2SocketS = rmCreateObjectDef("flank harbour 6 socket");
	rmSetObjectDefTradeRouteID(flank2SocketS, tradeRouteS);
	rmAddObjectDefItem(flank2SocketS, "zpTradingPostCaptureNavalOriental", 1, 0.0);
	rmSetObjectDefMinDistance(flank2SocketS, 0.0);
	rmSetObjectDefMaxDistance(flank2SocketS, 0.5);
	rmPlaceObjectDefAtLoc(flank2SocketS, 0,
		sFlankX  + rmXMetersToFraction(southFlankOffX),
		sFlank2Z + rmZMetersToFraction(southFlankOffZ));
	vector flank2LocS = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(flank2SocketS, 0));

	placeShoreIsland(trade6,
		rmXMetersToFraction(xsVectorGetX(flank2LocS)) - rmXMetersToFraction(southFlankOffX),
		rmZMetersToFraction(xsVectorGetZ(flank2LocS)) - rmZMetersToFraction(southFlankOffZ));

	placeShoreIsland(pirateN, nPirateX, nPirateZ);   // north island, back of its coast
	placeShoreIsland(pirateS, sPirateX, sPirateZ);   // south island, back of its coast

	int flankSocketN = rmCreateObjectDef("flank harbour socket north");
	rmSetObjectDefTradeRouteID(flankSocketN, tradeRouteN);
	rmAddObjectDefItem(flankSocketN, "zpTradingPostCaptureNavalOriental", 1, 0.0);
	rmSetObjectDefMinDistance(flankSocketN, 0.0);
	rmSetObjectDefMaxDistance(flankSocketN, 0.5);
	rmPlaceObjectDefAtLoc(flankSocketN, 0,
		nFlankX + rmXMetersToFraction(northFlankOffX),
		nFlankZ + rmZMetersToFraction(northFlankOffZ));
	vector flankLocN = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(flankSocketN, 0));

	placeShoreIsland(trade3,
		rmXMetersToFraction(xsVectorGetX(flankLocN)) - rmXMetersToFraction(northFlankOffX),
		rmZMetersToFraction(xsVectorGetZ(flankLocN)) - rmZMetersToFraction(northFlankOffZ));

	int flankSocketS = rmCreateObjectDef("flank harbour socket south");
	rmSetObjectDefTradeRouteID(flankSocketS, tradeRouteS);
	rmAddObjectDefItem(flankSocketS, "zpTradingPostCaptureNavalOriental", 1, 0.0);
	rmSetObjectDefMinDistance(flankSocketS, 0.0);
	rmSetObjectDefMaxDistance(flankSocketS, 0.5);
	rmPlaceObjectDefAtLoc(flankSocketS, 0,
		sFlankX + rmXMetersToFraction(southFlankOffX),
		sFlankZ + rmZMetersToFraction(southFlankOffZ));
	vector flankLocS = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(flankSocketS, 0));

	placeShoreIsland(trade4,
		rmXMetersToFraction(xsVectorGetX(flankLocS)) - rmXMetersToFraction(southFlankOffX),
		rmZMetersToFraction(xsVectorGetZ(flankLocS)) - rmZMetersToFraction(southFlankOffZ));
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
		nx3     + rmXMetersToFraction(northHarbourOffX),
		nTradeZ + rmZMetersToFraction(northHarbourOffZ));
	vector harbourLocN = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(harbourSocketN, 0));

	float tradeNX = rmXMetersToFraction(xsVectorGetX(harbourLocN)) - rmXMetersToFraction(northHarbourOffX);
	float tradeNZ = rmZMetersToFraction(xsVectorGetZ(harbourLocN)) - rmZMetersToFraction(northHarbourOffZ);
	placeShoreIsland(tradeN, tradeNX, tradeNZ);

	int harbourSocketS = rmCreateObjectDef("harbour socket south");
	rmSetObjectDefTradeRouteID(harbourSocketS, tradeRouteS);
	rmAddObjectDefItem(harbourSocketS, "zpTradingPostCaptureNavalOriental", 1, 0.0);
	rmSetObjectDefMinDistance(harbourSocketS, 0.0);
	rmSetObjectDefMaxDistance(harbourSocketS, 0.5);
	rmPlaceObjectDefAtLoc(harbourSocketS, 0,
		sx3     + rmXMetersToFraction(southHarbourOffX),
		sTradeZ + rmZMetersToFraction(southHarbourOffZ));
	vector harbourLocS = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(harbourSocketS, 0));

	placeShoreIsland(tradeS,
		rmXMetersToFraction(xsVectorGetX(harbourLocS)) - rmXMetersToFraction(southHarbourOffX),
		rmZMetersToFraction(xsVectorGetZ(harbourLocS)) - rmZMetersToFraction(southHarbourOffZ));

	rmSetStatusText("", 0.40);

	// ========================================================================
	//  7. THE CITY  -  painted last, over everything
	// ========================================================================

	// --- district terrain: a plateau bounded to its own grid ---------------
	int cityNbox = rmCreateBoxConstraint("north city box",
		nx1 - margin, nz1 - promenade, nx5 + flankProm, nz5 + margin, 0.01);
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
	rmAddAreaToClass(cityN, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityN, false);
	rmBuildArea(cityN);

	int citySbox = rmCreateBoxConstraint("south city box",
		sx1 - flankProm, sz5 - margin, sx5 + margin, sz1 + promenade, 0.01);
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
	rmAddAreaToClass(cityS, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityS, false);
	rmBuildArea(cityS);

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

	// --- the two 5 x 5 grids, row by row -----------------------------------
	// NORTH island: row 1 hugs the north lane, row 5 is farthest inland.
	cityBlock(nx1, nz1); cityBlock(nx2, nz1); cityBlock(nx3, nz1); cityBlock(nx4, nz1); cityBlock(nx5, nz1);
	cityBlock(nx1, nz2); cityBlock(nx2, nz2); cityBlock(nx3, nz2); cityBlock(nx4, nz2); cityBlock(nx5, nz2);
	cityBlock(nx1, nz3); cityBlock(nx2, nz3); cityBlock(nx3, nz3); cityBlock(nx4, nz3); cityBlock(nx5, nz3);
	cityBlock(nx1, nz4); cityBlock(nx2, nz4); cityBlock(nx3, nz4); cityBlock(nx4, nz4); cityBlock(nx5, nz4);
	cityBlock(nx1, nz5); cityBlock(nx2, nz5); cityBlock(nx3, nz5); cityBlock(nx4, nz5); cityBlock(nx5, nz5);

	// SOUTH island: row 1 hugs the south lane, row 5 is farthest inland.
	cityBlock(sx1, sz1); cityBlock(sx2, sz1); cityBlock(sx3, sz1); cityBlock(sx4, sz1); cityBlock(sx5, sz1);
	cityBlock(sx1, sz2); cityBlock(sx2, sz2); cityBlock(sx3, sz2); cityBlock(sx4, sz2); cityBlock(sx5, sz2);
	cityBlock(sx1, sz3); cityBlock(sx2, sz3); cityBlock(sx3, sz3); cityBlock(sx4, sz3); cityBlock(sx5, sz3);
	cityBlock(sx1, sz4); cityBlock(sx2, sz4); cityBlock(sx3, sz4); cityBlock(sx4, sz4); cityBlock(sx5, sz4);
	cityBlock(sx1, sz5); cityBlock(sx2, sz5); cityBlock(sx3, sz5); cityBlock(sx4, sz5); cityBlock(sx5, sz5);

	// ---- shoreline decoration, after every block is down ------------------
	int decoN = rmCreateGrouping("deco shoreline west", decoShoreline);
	rmSetGroupingMinDistance(decoN, 0.0);
	rmSetGroupingMaxDistance(decoN, 0.01);
	int decoN2 = rmCreateGrouping("deco shoreline east", decoShoreline);
	rmSetGroupingMinDistance(decoN2, 0.0);
	rmSetGroupingMaxDistance(decoN2, 0.01);

	// Sequence along the canal shore:  gun -> deco -> trade -> deco -> gun
	// Each deco sits halfway between a corner gun (nx1 / nx5) and the trade
	// harbour's REAL x, so it keeps its place even when the socket shifts.
	float decoZ = nz1 - promenade + tilesZ(decoShoreIn);
	float decoWestX = (nx1 + tradeNX) * 0.5 + tilesX(decoWestNudge);
	float decoEastX = (nx5 + tradeNX) * 0.5 + tilesX(decoEastNudge);
	rmEchoInfo("deco: nz1=" + nz1 + " promenade=" + promenade + " decoShoreIn=" + decoShoreIn);
	rmEchoInfo("deco: decoZ=" + decoZ + " westX=" + decoWestX + " eastX=" + decoEastX + " tradeNX=" + tradeNX);
	rmPlaceGroupingAtLoc(decoN,  0, decoWestX, decoZ);
	rmPlaceGroupingAtLoc(decoN2, 0, decoEastX, decoZ);

	rmSetStatusText("", 0.85);

	// ========================================================================
	//  8. PLAYERS  (stub)
	// ========================================================================
	rmPlacePlayersCircular(0.42, 0.42, 0.0);

	rmSetStatusText("", 1.00);
}
