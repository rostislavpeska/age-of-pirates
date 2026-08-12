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

// Floating island, part 1: the invisible landmass the river will need.
// Deliberately larger than the gun, so it still covers the spot after the
// trade route snaps and the measured position moves a few tiles.
int gScaffoldIdx = 0;
void shoreScaffold(float x = 0.0, float z = 0.0)
{
	gScaffoldIdx = gScaffoldIdx + 1;
	int land = rmCreateArea("gun scaffold " + gScaffoldIdx);
	rmSetAreaSize(land, rmAreaTilesToFraction(700), rmAreaTilesToFraction(700));
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
void shoreRiver(float x = 0.0, float z = 0.0)
{
	int river = rmRiverCreate(-1, "ZP Black Sea Water", 4, 4, 24, 24);
	rmRiverAddWaypoint(river, x - 0.05, z);
	rmRiverAddWaypoint(river, x + 0.05, z);
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
	int   northCityDist   = 24;   // north lane -> north city, first block row
	int   southCityDist   = 26;   // south lane -> south city, first block row
	int   northGunDist    = 10;   // north lane -> north gun islands
	int   southGunDist    = 10;   // south lane -> south gun islands
	int   northTradeDist  = 9;   // north lane -> north trade harbour
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

	float cityHeight      = 3.0;  // was 2.0 in 000_istanbul at sea level 0.0

	// Gun facing is baked into the grouping XML:
	//   _01 -> orientz -1, muzzle points SOUTH (-z) -> use on the NORTH shore
	//   _02 -> orientz +1, muzzle points NORTH (+z) -> use on the SOUTH shore
	string gunNorthShore  = "IS_Shore_Fixed_Gun_01";
	string gunSouthShore  = "IS_Shore_Fixed_Gun_02";

	// Trade harbours: one per shore, centred between that shore's two guns.
	string tradeHarbourN  = "IS_Shore_Trade_01";
	string tradeHarbourS  = "IS_Shore_Trade_02";

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
	float colPitch = rmXTilesToFraction(blockPitch);
	float rowPitch = rmZTilesToFraction(blockPitch);
	float margin   = colPitch * 0.6;            // plateau margin around a grid
	// The shore that faces the trade route is pushed out further, so the quay
	// in front of the first block row is wider.
	float promenade = margin + rmZTilesToFraction(promenadeExtra);

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

	// ========================================================================
	//  4. TRADE ROUTES  ->  then MEASURE where they really are
	// ========================================================================
	int tradeRouteN = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteN, 1.0, nRouteAsk);
	rmAddTradeRouteWaypoint(tradeRouteN, 0.5, nRouteAsk);
	rmAddTradeRouteWaypoint(tradeRouteN, 0.0, nRouteAsk);
	rmBuildTradeRoute(tradeRouteN, "water_trail");

	int tradeRouteS = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteS, 0.0, sRouteAsk);
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
	float nz1 = nRouteZ + rmZTilesToFraction(northCityDist);
	float nz2 = nz1 + rowPitch;
	float nz3 = nz2 + rowPitch;
	float nz4 = nz3 + rowPitch;
	float nz5 = nz4 + rowPitch;

	float sz1 = sRouteZ - rmZTilesToFraction(southCityDist);
	float sz2 = sz1 - rowPitch;
	float sz3 = sz2 - rowPitch;
	float sz4 = sz3 - rowPitch;
	float sz5 = sz4 - rowPitch;

	// Gun islands sit out in the channel, at each island's inner corners.
	float nGunZ = nRouteZ + rmZTilesToFraction(northGunDist);
	float sGunZ = sRouteZ - rmZTilesToFraction(southGunDist);

	// Trade harbours sit on the same shores, midway between the two guns.
	float nTradeZ = nRouteZ + rmZTilesToFraction(northTradeDist);
	float sTradeZ = sRouteZ - rmZTilesToFraction(southTradeDist);

	// ========================================================================
	//  6. THE FOUR GUN ISLANDS  -  each facing the lane it guards
	// ========================================================================
	int gunNW = rmCreateGrouping("gun nw", gunNorthShore);
	int gunNE = rmCreateGrouping("gun ne", gunNorthShore);
	int gunSW = rmCreateGrouping("gun sw", gunSouthShore);
	int gunSE = rmCreateGrouping("gun se", gunSouthShore);
	int tradeN = rmCreateGrouping("trade harbour n", tradeHarbourN);
	int tradeS = rmCreateGrouping("trade harbour s", tradeHarbourS);

	// PHASE A - every river first (a later river would drown an earlier gun)
	shoreRiver(nx1, nGunZ);
	shoreRiver(nx5, nGunZ);
	shoreRiver(sx1, sGunZ);
	shoreRiver(sx5, sGunZ);
	shoreRiver(nx3, nTradeZ);
	shoreRiver(sx3, sTradeZ);

	// PHASE B - only now the guns go down
	placeShoreIsland(gunNW, nx1, nGunZ);
	placeShoreIsland(gunNE, nx5, nGunZ);
	placeShoreIsland(gunSW, sx1, sGunZ);
	placeShoreIsland(gunSE, sx5, sGunZ);
	placeShoreIsland(tradeN, nx3, nTradeZ);
	placeShoreIsland(tradeS, sx3, sTradeZ);

	rmSetStatusText("", 0.40);

	// ========================================================================
	//  7. THE CITY  -  painted last, over everything
	// ========================================================================

	// --- district terrain: a plateau bounded to its own grid ---------------
	int cityNbox = rmCreateBoxConstraint("north city box",
		nx1 - margin, nz1 - promenade, nx5 + margin, nz5 + margin, 0.01);
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
		sx1 - margin, sz5 - margin, sx5 + margin, sz1 + promenade, 0.01);
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

	rmSetStatusText("", 0.85);

	// ========================================================================
	//  8. PLAYERS  (stub)
	// ========================================================================
	rmPlacePlayersCircular(0.42, 0.42, 0.0);

	rmSetStatusText("", 1.00);
}
