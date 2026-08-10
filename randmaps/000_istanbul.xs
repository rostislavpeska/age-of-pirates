// ============================================================================
// 000_istanbul.xs  -  Istanbul city map (Age of Pirates)
// ----------------------------------------------------------------------------
// Layout source: Figma "AoE Maps", node 248:167 (minimap orientation, +45).
// Two city-block districts split by the central Black Sea / Bosphorus, a
// trade route down each bank, green land ringing the map for players.
// Measured from the Figma: each district is a ~6x5 grid of ~40 m blocks
// (grid A center minimap-frac 0.255,0.314 ; grid B 0.721,0.642). Structure
// and block set mirror zpparis (EU_*_Block_* on a fixed grid).
//
// This pass: Black Sea water base + two trade routes + two RECTANGULAR
// districts (box + influence segment) + the 6x5 CITY-BLOCK GRID on each.
// One size fits all. Natives / players / towers: next steps.
// ============================================================================

void main(void)
{
	rmSetStatusText("", 0.01);

	// ---- MAP SIZE (one size fits all) ------------------------------------
	int size = 500;
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

	// ---- BOX CONSTRAINTS: two RECTANGULAR districts ----------------------
	// Real-space NORTH + SOUTH split; the +45 minimap turns it into the
	// Figma upper-left / lower-right diagonal. Central strip z[0.44,0.56]
	// stays open water = the Bosphorus. Boxes leave green land left/right.
	int cityNbox = rmCreateBoxConstraint("north city box", 0.26, 0.05, 0.74, 0.45, 0.01);
	int citySbox = rmCreateBoxConstraint("south city box", 0.26, 0.55, 0.74, 0.95, 0.01);

	// ---- TWO TRADE ROUTES: one down each bank of the channel (per Figma) --
	int tradeRouteN = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteN, 0.14, 0.42);
	rmAddTradeRouteWaypoint(tradeRouteN, 0.50, 0.42);
	rmAddTradeRouteWaypoint(tradeRouteN, 0.86, 0.42);
	rmBuildTradeRoute(tradeRouteN, "dirt");

	int tradeRouteS = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteS, 0.14, 0.58);
	rmAddTradeRouteWaypoint(tradeRouteS, 0.50, 0.58);
	rmAddTradeRouteWaypoint(tradeRouteS, 0.86, 0.58);
	rmBuildTradeRoute(tradeRouteS, "dirt");

	rmSetStatusText("", 0.35);

	// ---- CITY-BLOCK TERRAIN: two rectangular districts -------------------
	int cityN = rmCreateArea("cityNorth");
	rmSetAreaSize(cityN, 0.5, 0.5);
	rmSetAreaLocation(cityN, 0.5, 0.25);
	rmSetAreaCoherence(cityN, 1.0);
	rmSetAreaBaseHeight(cityN, 3.0);
	rmAddAreaInfluenceSegment(cityN, 0.30, 0.25, 0.70, 0.25);
	rmSetAreaTerrainType(cityN, "city\ground1_cob_dark");
	rmSetAreaCliffType(cityN, "ZP City");
	rmSetAreaCliffEdge(cityN, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityN, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityN, cityNbox);
	rmAddAreaToClass(cityN, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityN, false);
	rmBuildArea(cityN);

	int cityS = rmCreateArea("citySouth");
	rmSetAreaSize(cityS, 0.5, 0.5);
	rmSetAreaLocation(cityS, 0.5, 0.75);
	rmSetAreaCoherence(cityS, 1.0);
	rmSetAreaBaseHeight(cityS, 3.0);
	rmAddAreaInfluenceSegment(cityS, 0.30, 0.75, 0.70, 0.75);
	rmSetAreaTerrainType(cityS, "city\ground1_cob_dark");
	rmSetAreaCliffType(cityS, "ZP City");
	rmSetAreaCliffEdge(cityS, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityS, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityS, citySbox);
	rmAddAreaToClass(cityS, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityS, false);
	rmBuildArea(cityS);

	rmSetStatusText("", 0.55);

	// ---- CITY-BLOCK GROUPINGS (the Paris block set) ----------------------
	int b0 = rmCreateGrouping("blk house1", "EU_House_Block_01");
	int b1 = rmCreateGrouping("blk house2", "EU_House_Block_02");
	int b2 = rmCreateGrouping("blk food",   "EU_Resource_Block_Food1");
	int b3 = rmCreateGrouping("blk gold",   "EU_Resource_Block_Gold1");
	int b4 = rmCreateGrouping("blk wood",   "EU_Resource_Block_Wood1");
	int b5 = rmCreateGrouping("blk house3", "EU_House_Block_03");
	int b6 = rmCreateGrouping("blk market", "EU_Resource_Block_All2");
	int b7 = rmCreateGrouping("blk house4", "EU_House_Block_04");

	int blockArr = xsArrayCreateInt(8, 0, "block types");
	xsArraySetInt(blockArr, 0, b0);
	xsArraySetInt(blockArr, 1, b1);
	xsArraySetInt(blockArr, 2, b2);
	xsArraySetInt(blockArr, 3, b3);
	xsArraySetInt(blockArr, 4, b4);
	xsArraySetInt(blockArr, 5, b5);
	xsArraySetInt(blockArr, 6, b6);
	xsArraySetInt(blockArr, 7, b7);

	// place exactly on the grid (min/max distance 0), block class
	// (C-style for with an inline-declared counter -- the only loop form
	//  proven valid in the shipped maps, e.g. zpparis shuffle())
	rmSetGroupingMinDistance(b0, 0.0); rmSetGroupingMaxDistance(b0, 0.0); rmAddGroupingToClass(b0, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b1, 0.0); rmSetGroupingMaxDistance(b1, 0.0); rmAddGroupingToClass(b1, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b2, 0.0); rmSetGroupingMaxDistance(b2, 0.0); rmAddGroupingToClass(b2, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b3, 0.0); rmSetGroupingMaxDistance(b3, 0.0); rmAddGroupingToClass(b3, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b4, 0.0); rmSetGroupingMaxDistance(b4, 0.0); rmAddGroupingToClass(b4, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b5, 0.0); rmSetGroupingMaxDistance(b5, 0.0); rmAddGroupingToClass(b5, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b6, 0.0); rmSetGroupingMaxDistance(b6, 0.0); rmAddGroupingToClass(b6, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b7, 0.0); rmSetGroupingMaxDistance(b7, 0.0); rmAddGroupingToClass(b7, rmClassID("classBlock"));

	// ---- 6x5 BLOCK GRID on each district (~40 m spacing = 0.08 frac) -----
	// Temp vars declared ONCE (no re-declaration across loops); loop
	// counters use unique names with the inline C-style form proven in the
	// shipped maps (zpparis shuffle: for(int i=end; i>start; i--)).
	float spacing = 0.08;
	int typeIdx = 0;
	float bx = 0.0;
	float bz = 0.0;
	int g = 0;

	// North district grid, centred on (0.5, 0.25)
	for (int cn = 0; cn < 6; cn++)
	{
		for (int rn = 0; rn < 5; rn++)
		{
			bx = 0.5 - spacing * 2.5 + cn * spacing;
			bz = 0.25 - spacing * 2.0 + rn * spacing;
			g = xsArrayGetInt(blockArr, typeIdx);
			rmPlaceGroupingAtLoc(g, 0, bx, bz);
			typeIdx = typeIdx + 1;
			if (typeIdx >= 8) { typeIdx = 0; }
		}
	}

	// South district grid, centred on (0.5, 0.75)
	for (int cs = 0; cs < 6; cs++)
	{
		for (int rs = 0; rs < 5; rs++)
		{
			bx = 0.5 - spacing * 2.5 + cs * spacing;
			bz = 0.75 - spacing * 2.0 + rs * spacing;
			g = xsArrayGetInt(blockArr, typeIdx);
			rmPlaceGroupingAtLoc(g, 0, bx, bz);
			typeIdx = typeIdx + 1;
			if (typeIdx >= 8) { typeIdx = 0; }
		}
	}

	rmSetStatusText("", 0.85);

	// ---- MINIMAL PLAYER PLACEMENT (stub so the map generates) ------------
	rmPlacePlayersCircular(0.42, 0.42, 0.0);

	rmSetStatusText("", 1.00);
}
