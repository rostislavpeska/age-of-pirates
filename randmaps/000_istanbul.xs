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

	// ---- TWO TRADE ROUTES IN THE WATER (the Bosphorus lanes) -------------
	// Placed first; everything else is measured from them (Versailles).
	int tradeRouteN = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteN, 0.0, 0.46);
	rmAddTradeRouteWaypoint(tradeRouteN, 0.5, 0.46);
	rmAddTradeRouteWaypoint(tradeRouteN, 1.0, 0.46);
	rmBuildTradeRoute(tradeRouteN, "dirt");

	int tradeRouteS = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteS, 0.0, 0.54);
	rmAddTradeRouteWaypoint(tradeRouteS, 0.5, 0.54);
	rmAddTradeRouteWaypoint(tradeRouteS, 1.0, 0.54);
	rmBuildTradeRoute(tradeRouteS, "dirt");

	// ---- READ THE ROUTE CENTRES AS REFERENCE FRACTIONS (Versailles) ------
	vector nRoutePt = rmGetTradeRouteWayPoint(tradeRouteN, 0.5);
	float nRouteZ = rmZMetersToFraction(xsVectorGetZ(nRoutePt));
	vector sRoutePt = rmGetTradeRouteWayPoint(tradeRouteS, 0.5);
	float sRouteZ = rmZMetersToFraction(xsVectorGetZ(sRoutePt));

	// ---- BLOCK-GRID GEOMETRY, all measured from the routes ---------------
	float step    = rmXTilesToFraction(16);   // 32 m block pitch (both axes)
	float gap     = rmZTilesToFraction(12);   // route -> first block row
	float colStart = 0.5 - step * 2.0;        // 5 columns centred on 0.5
	float nFirstZ = nRouteZ - gap;            // north district grows NORTH
	float sFirstZ = sRouteZ + gap;            // south district grows SOUTH
	float m       = step * 0.6;               // terrain margin around the grid

	rmSetStatusText("", 0.30);

	// ---- DISTRICT TERRAIN, measured from the routes ----------------------
	int cityNbox = rmCreateBoxConstraint("north city box",
		colStart - m, nFirstZ + m,
		colStart + step * 4.0 + m, nFirstZ - step * 4.0 - m, 0.01);
	int cityN = rmCreateArea("cityNorth");
	rmSetAreaSize(cityN, 0.4, 0.4);
	rmSetAreaLocation(cityN, 0.5, nFirstZ - step * 2.0);
	rmSetAreaCoherence(cityN, 1.0);
	rmSetAreaBaseHeight(cityN, 3.0);
	rmAddAreaInfluenceSegment(cityN, colStart, nFirstZ - step * 2.0,
		colStart + step * 4.0, nFirstZ - step * 2.0);
	rmSetAreaTerrainType(cityN, "city\ground1_cob_dark");
	rmSetAreaCliffType(cityN, "ZP City");
	rmSetAreaCliffEdge(cityN, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityN, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityN, cityNbox);
	rmAddAreaToClass(cityN, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityN, false);
	rmBuildArea(cityN);

	int citySbox = rmCreateBoxConstraint("south city box",
		colStart - m, sFirstZ - m,
		colStart + step * 4.0 + m, sFirstZ + step * 4.0 + m, 0.01);
	int cityS = rmCreateArea("citySouth");
	rmSetAreaSize(cityS, 0.4, 0.4);
	rmSetAreaLocation(cityS, 0.5, sFirstZ + step * 2.0);
	rmSetAreaCoherence(cityS, 1.0);
	rmSetAreaBaseHeight(cityS, 3.0);
	rmAddAreaInfluenceSegment(cityS, colStart, sFirstZ + step * 2.0,
		colStart + step * 4.0, sFirstZ + step * 2.0);
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

	rmSetGroupingMinDistance(b0, 0.0); rmSetGroupingMaxDistance(b0, 0.0); rmAddGroupingToClass(b0, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b1, 0.0); rmSetGroupingMaxDistance(b1, 0.0); rmAddGroupingToClass(b1, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b2, 0.0); rmSetGroupingMaxDistance(b2, 0.0); rmAddGroupingToClass(b2, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b3, 0.0); rmSetGroupingMaxDistance(b3, 0.0); rmAddGroupingToClass(b3, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b4, 0.0); rmSetGroupingMaxDistance(b4, 0.0); rmAddGroupingToClass(b4, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b5, 0.0); rmSetGroupingMaxDistance(b5, 0.0); rmAddGroupingToClass(b5, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b6, 0.0); rmSetGroupingMaxDistance(b6, 0.0); rmAddGroupingToClass(b6, rmClassID("classBlock"));
	rmSetGroupingMinDistance(b7, 0.0); rmSetGroupingMaxDistance(b7, 0.0); rmAddGroupingToClass(b7, rmClassID("classBlock"));

	int blockArr = xsArrayCreateInt(8, 0, "block types");
	xsArraySetInt(blockArr, 0, b0);
	xsArraySetInt(blockArr, 1, b1);
	xsArraySetInt(blockArr, 2, b2);
	xsArraySetInt(blockArr, 3, b3);
	xsArraySetInt(blockArr, 4, b4);
	xsArraySetInt(blockArr, 5, b5);
	xsArraySetInt(blockArr, 6, b6);
	xsArraySetInt(blockArr, 7, b7);

	// ---- 5x5 BLOCK GRID per district, positions measured from the routes -
	int typeIdx = 0;
	float bx = 0.0;
	float bz = 0.0;
	int g = 0;

	// North district: rows grow NORTH from nFirstZ (decreasing z)
	for (int cn = 0; cn < 5; cn++)
	{
		for (int rn = 0; rn < 5; rn++)
		{
			bx = colStart + cn * step;
			bz = nFirstZ - rn * step;
			g = xsArrayGetInt(blockArr, typeIdx);
			rmPlaceGroupingAtLoc(g, 0, bx, bz);
			typeIdx = typeIdx + 1;
			if (typeIdx >= 8) { typeIdx = 0; }
		}
	}

	// South district: rows grow SOUTH from sFirstZ (increasing z)
	for (int cs = 0; cs < 5; cs++)
	{
		for (int rs = 0; rs < 5; rs++)
		{
			bx = colStart + cs * step;
			bz = sFirstZ + rs * step;
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
