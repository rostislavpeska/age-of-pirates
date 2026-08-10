// ============================================================================
// 000_istanbul.xs  -  Istanbul city map (Age of Pirates)
// ----------------------------------------------------------------------------
// Layout source: Figma "AoE Maps", node 248:167 (minimap orientation, +45).
// Two 5x5 city-block districts split by the central Black Sea / Bosphorus.
//
// Built the VERSAILLES way: the two trade routes are placed FIRST, IN THE
// WATER (the Bosphorus shipping lanes); their centre points are read back as
// reference fractions (nRouteZ / sRouteZ), and every block row and the
// district terrain is then measured FROM the routes as route +/- tile
// offsets. Resized to 600x600 to fit the two grids + channel + green land.
//
// One size fits all. Trade sockets / natives / players / towers: next steps.
// ============================================================================

void main(void)
{
	rmSetStatusText("", 0.01);

	// ---- MAP SIZE (resized for the block system) -------------------------
	int size = 600;
	rmSetMapSize(size, size);
	rmSetMapElevationHeightBlend(1);

	// ---- WATER BASE: the Black Sea / Bosphorus ---------------------------
	rmSetSeaLevel(0.0);
	rmSetSeaType("ZP Black Sea Lagoon");
	rmTerrainInitialize("water");
	rmSetLightingSet("age3challenges09a");
	rmSetMapType("water");
	rmSetMapType("land");
	rmSetWorldCircleConstraint(true);

	rmSetStatusText("", 0.12);

	// ---- CLASSES ---------------------------------------------------------
	rmDefineClass("classPlateau");
	rmDefineClass("classBlock");
	rmDefineClass("classStreet");

	// ---- TWO WATER-TRAIL TRADE ROUTES, OPPOSITE DIRECTIONS --------------
	// Placed first, in the Bosphorus; everything is measured from them
	// (Versailles). North route runs WEST->EAST, south route EAST->WEST.
	int tradeRouteN = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteN, 0.0, 0.46);
	rmAddTradeRouteWaypoint(tradeRouteN, 0.5, 0.46);
	rmAddTradeRouteWaypoint(tradeRouteN, 1.0, 0.46);
	rmBuildTradeRoute(tradeRouteN, "water_trail");

	int tradeRouteS = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteS, 1.0, 0.54);
	rmAddTradeRouteWaypoint(tradeRouteS, 0.5, 0.54);
	rmAddTradeRouteWaypoint(tradeRouteS, 0.0, 0.54);
	rmBuildTradeRoute(tradeRouteS, "water_trail");

	// ---- READ THE ROUTE CENTRES AS REFERENCE FRACTIONS (Versailles) ------
	vector nRoutePt = rmGetTradeRouteWayPoint(tradeRouteN, 0.5);
	float nRouteZ = rmZMetersToFraction(xsVectorGetZ(nRoutePt));
	vector sRoutePt = rmGetTradeRouteWayPoint(tradeRouteS, 0.5);
	float sRouteZ = rmZMetersToFraction(xsVectorGetZ(sRoutePt));

	// ---- DISTRICT GEOMETRY, all measured from the routes -----------------
	// LAYOUT NOT FINAL: sizes/positions are a first pass; the districts are
	// held well back from the routes so the water lanes stay clear.
	float gap    = rmZTilesToFraction(16);    // route -> district edge
	float halfW  = rmXTilesToFraction(45);    // district half-width  (x)
	float halfH  = rmZTilesToFraction(40);    // district half-height (z)
	float nCz    = nRouteZ - gap - halfH;     // north district centre z
	float sCz    = sRouteZ + gap + halfH;     // south district centre z

	rmSetStatusText("", 0.30);

	// ---- DISTRICT TERRAIN, measured from the routes ----------------------
	// LAYOUT NOT FINAL: two rectangular districts, one either side of the
	// Bosphorus, held back by `gap`. Box + influence segment => a rectangle.
	int cityNbox = rmCreateBoxConstraint("north city box",
		0.5 - halfW, nCz - halfH, 0.5 + halfW, nCz + halfH, 0.01);
	int cityN = rmCreateArea("cityNorth");
	rmSetAreaSize(cityN, 0.4, 0.4);
	rmSetAreaLocation(cityN, 0.5, nCz);
	rmSetAreaCoherence(cityN, 1.0);
	rmSetAreaBaseHeight(cityN, 3.0);
	rmAddAreaInfluenceSegment(cityN, 0.5 - halfW, nCz, 0.5 + halfW, nCz);
	rmSetAreaTerrainType(cityN, "city\ground1_cob_dark");
	rmSetAreaCliffType(cityN, "ZP City");
	rmSetAreaCliffEdge(cityN, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityN, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityN, cityNbox);
	rmAddAreaToClass(cityN, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityN, false);
	rmBuildArea(cityN);

	int citySbox = rmCreateBoxConstraint("south city box",
		0.5 - halfW, sCz - halfH, 0.5 + halfW, sCz + halfH, 0.01);
	int cityS = rmCreateArea("citySouth");
	rmSetAreaSize(cityS, 0.4, 0.4);
	rmSetAreaLocation(cityS, 0.5, sCz);
	rmSetAreaCoherence(cityS, 1.0);
	rmSetAreaBaseHeight(cityS, 3.0);
	rmAddAreaInfluenceSegment(cityS, 0.5 - halfW, sCz, 0.5 + halfW, sCz);
	rmSetAreaTerrainType(cityS, "city\ground1_cob_dark");
	rmSetAreaCliffType(cityS, "ZP City");
	rmSetAreaCliffEdge(cityS, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityS, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityS, citySbox);
	rmAddAreaToClass(cityS, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityS, false);
	rmBuildArea(cityS);

	rmSetStatusText("", 0.55);

	// ---- ISTANBUL (IS_) CITY BLOCKS -- random fill, NO GRID --------------
	// LAYOUT NOT FINAL: for now just scatter the Istanbul blocks across each
	// district (rmPlaceGroupingInArea). avoidBlock keeps them from
	// overlapping; the exact block mix/positions are placeholders.
	int avoidBlock = rmCreateClassDistanceConstraint("blocks avoid blocks",
		rmClassID("classBlock"), 26.0);

	int isHouse1 = rmCreateGrouping("is house1", "IS_House_Block_01");
	int isHouse2 = rmCreateGrouping("is house2", "IS_House_Block_02");
	int isHouse3 = rmCreateGrouping("is house3", "IS_House_Block_03");
	int isHouse4 = rmCreateGrouping("is house4", "IS_House_Block_04");
	int isFood   = rmCreateGrouping("is food",   "IS_Resource_Block_Food1");
	int isGold   = rmCreateGrouping("is gold",   "IS_Resource_Block_Gold1");
	int isWood   = rmCreateGrouping("is wood",   "IS_Resource_Block_Wood_01");
	int isMosque = rmCreateGrouping("is mosque", "IS_Resource_Block_Mosque");
	int isSufi   = rmCreateGrouping("is sufi",   "IS_Native_Block_Sufi");

	int isArr = xsArrayCreateInt(9, 0, "istanbul blocks");
	xsArraySetInt(isArr, 0, isHouse1);
	xsArraySetInt(isArr, 1, isHouse2);
	xsArraySetInt(isArr, 2, isHouse3);
	xsArraySetInt(isArr, 3, isHouse4);
	xsArraySetInt(isArr, 4, isFood);
	xsArraySetInt(isArr, 5, isGold);
	xsArraySetInt(isArr, 6, isWood);
	xsArraySetInt(isArr, 7, isMosque);
	xsArraySetInt(isArr, 8, isSufi);

	int isg = 0;
	for (int ib = 0; ib < 9; ib++)
	{
		isg = xsArrayGetInt(isArr, ib);
		rmSetGroupingMinDistance(isg, 0.0);
		rmSetGroupingMaxDistance(isg, 0.5);
		rmAddGroupingToClass(isg, rmClassID("classBlock"));
		rmAddGroupingConstraint(isg, avoidBlock);
		// scatter a few of each into both districts (random placement)
		rmPlaceGroupingInArea(isg, 0, cityN, 2);
		rmPlaceGroupingInArea(isg, 0, cityS, 2);
	}

	rmSetStatusText("", 0.85);

	// ---- MINIMAL PLAYER PLACEMENT (stub so the map generates) ------------
	rmPlacePlayersCircular(0.42, 0.42, 0.0);

	rmSetStatusText("", 1.00);
}
