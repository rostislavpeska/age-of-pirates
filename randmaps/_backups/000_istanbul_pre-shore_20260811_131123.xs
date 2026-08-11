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

// Cycling block picker for the city grid. Point gCityBlocks at the block
// array once, then each cityBlock(x, z) drops the next block type at that
// cell and advances the cursor (wraps after the 9 types).
int gCityBlocks   = -1;
int gCityBlockIdx = 0;
void cityBlock(float x = 0.0, float z = 0.0)
{
	rmPlaceGroupingAtLoc(xsArrayGetInt(gCityBlocks, gCityBlockIdx), 0, x, z);
	gCityBlockIdx = gCityBlockIdx + 1;
	if (gCityBlockIdx >= xsArrayGetSize(gCityBlocks)) { gCityBlockIdx = 0; }
}

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

	// ---- CITY GRID COORDINATES (Versailles / Paris / Florence style) ----
	// 5 columns x1..x5, west->east, centred on 0.5 (shared by both districts).
	// 5 rows per district, measured from that side's trade route: z1 hugs the
	// route, z5 is the row farthest inland. North rows step north (-z), south
	// rows step south (+z). Pure float maths only - never intVar*floatVar,
	// which XS truncates to 0 and would collapse the whole grid onto one point.
	float colPitch = rmXTilesToFraction(17);   // ~34 m between columns
	float rowPitch = rmZTilesToFraction(17);   // ~34 m between rows
	float rowDist  = rmZTilesToFraction(18);   // route -> nearest row (z1)
	float margin   = colPitch * 0.6;           // plateau margin around the grid

	float x1 = 0.5 - colPitch * 2.0;           // columns, west -> east
	float x2 = 0.5 - colPitch;
	float x3 = 0.5;
	float x4 = 0.5 + colPitch;
	float x5 = 0.5 + colPitch * 2.0;

	float nz1 = nRouteZ - rowDist;             // NORTH rows: z1 hugs the route,
	float nz2 = nz1 - rowPitch;                //             z5 is inland (north)
	float nz3 = nz2 - rowPitch;
	float nz4 = nz3 - rowPitch;
	float nz5 = nz4 - rowPitch;

	float sz1 = sRouteZ + rowDist;             // SOUTH rows: z1 hugs the route,
	float sz2 = sz1 + rowPitch;                //             z5 is inland (south)
	float sz3 = sz2 + rowPitch;
	float sz4 = sz3 + rowPitch;
	float sz5 = sz4 + rowPitch;

	rmSetStatusText("", 0.30);

	// ---- DISTRICT TERRAIN sized to each grid -----------------------------
	// Box constraint bounds the plateau to the grid extent (+margin); the
	// influence segment stretches the coherent blob into a filled rectangle.
	int cityNbox = rmCreateBoxConstraint("north city box",
		x1 - margin, nz5 - margin, x5 + margin, nz1 + margin, 0.01);
	int cityN = rmCreateArea("cityNorth");
	rmSetAreaSize(cityN, 0.4, 0.4);
	rmSetAreaLocation(cityN, x3, nz3);
	rmSetAreaCoherence(cityN, 1.0);
	rmSetAreaBaseHeight(cityN, 2.0);
	rmAddAreaInfluenceSegment(cityN, x1, nz3, x5, nz3);
	rmSetAreaTerrainType(cityN, "city\ground1_cob");
	rmSetAreaCliffType(cityN, "ZP City Italian");
	rmSetAreaCliffEdge(cityN, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityN, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityN, cityNbox);
	rmAddAreaToClass(cityN, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityN, false);
	rmBuildArea(cityN);

	int citySbox = rmCreateBoxConstraint("south city box",
		x1 - margin, sz1 - margin, x5 + margin, sz5 + margin, 0.01);
	int cityS = rmCreateArea("citySouth");
	rmSetAreaSize(cityS, 0.4, 0.4);
	rmSetAreaLocation(cityS, x3, sz3);
	rmSetAreaCoherence(cityS, 1.0);
	rmSetAreaBaseHeight(cityS, 2.0);
	rmAddAreaInfluenceSegment(cityS, x1, sz3, x5, sz3);
	rmSetAreaTerrainType(cityS, "city\ground1_cob");
	rmSetAreaCliffType(cityS, "ZP City Italian");
	rmSetAreaCliffEdge(cityS, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityS, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityS, citySbox);
	rmAddAreaToClass(cityS, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityS, false);
	rmBuildArea(cityS);

	rmSetStatusText("", 0.55);

	// ---- IS_ CITY BLOCK GROUPINGS  (the full set - all 24) ---------------
	// Every Istanbul block that exists, defined and configured grid-ready:
	// min 0, max 0.5, classBlock - the zpparis/zpverseilles convention
	// (max 0 is only for unique structures like walls/bridges). Grouped by
	// kind; gCityBlocks is the registry the placement draws from.
	// Houses (10)
	int isHouse01   = rmCreateGrouping("is house 01",    "IS_House_Block_01");
	int isHouse02   = rmCreateGrouping("is house 02",    "IS_House_Block_02");
	int isHouse03   = rmCreateGrouping("is house 03",    "IS_House_Block_03");
	int isHouse04   = rmCreateGrouping("is house 04",    "IS_House_Block_04");
	int isHouse05   = rmCreateGrouping("is house 05",    "IS_House_Block_05");
	int isHouse06   = rmCreateGrouping("is house 06",    "IS_House_Block_06");
	int isEmbassy   = rmCreateGrouping("is embassy",     "IS_House_Block_Embassy");
	int isPark      = rmCreateGrouping("is park",        "IS_House_Block_Park");
	int isTreasure1 = rmCreateGrouping("is treasure 01", "IS_House_Block_Treasure_01");
	int isTreasure2 = rmCreateGrouping("is treasure 02", "IS_House_Block_Treasure_02");
	// Resources (7)
	int isResAll1   = rmCreateGrouping("is res all 1",   "IS_Resource_Block_All1");
	int isResAll2   = rmCreateGrouping("is res all 2",   "IS_Resource_Block_All2");
	int isFood      = rmCreateGrouping("is food",        "IS_Resource_Block_Food1");
	int isGold      = rmCreateGrouping("is gold",        "IS_Resource_Block_Gold1");
	int isMenagere  = rmCreateGrouping("is menagere",    "IS_Resource_Block_Menagere");
	int isMosque    = rmCreateGrouping("is mosque",      "IS_Resource_Block_Mosque");
	int isWood      = rmCreateGrouping("is wood",        "IS_Resource_Block_Wood_01");
	// Natives (5)
	int isAuditore  = rmCreateGrouping("is auditore",    "IS_Native_Block_Auditore");
	int isOrthodox  = rmCreateGrouping("is orthodox",    "IS_Native_Block_Orthodox");
	int isPhanar    = rmCreateGrouping("is phanar",      "IS_Native_Block_Phanar");
	int isPirates   = rmCreateGrouping("is pirates",     "IS_Native_Block_Pirates");
	int isSufi      = rmCreateGrouping("is sufi",        "IS_Native_Block_Sufi");
	// Special (2)
	int isSpcCity   = rmCreateGrouping("is spc istanbul", "IS_SPC_Istanbul");
	int isSpcMil    = rmCreateGrouping("is spc military", "IS_SPC_Military");

	// registry: index -> grouping (placement draws blocks from here)
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

	// configure every block the same, grid-ready (zpparis/zpverseilles style)
	int isg = 0;
	for (int ib = 0; ib < 24; ib++)
	{
		isg = xsArrayGetInt(gCityBlocks, ib);
		rmSetGroupingMinDistance(isg, 0.0);
		rmSetGroupingMaxDistance(isg, 0.5);
		rmAddGroupingToClass(isg, rmClassID("classBlock"));
	}

	// The whole city, cell by cell: columns x1..x5 (west->east), rows z1
	// (hugging the route) to z5 (farthest inland). One block per cell; the
	// block MIX cycles through the set and is still a placeholder.
	// NORTH district
	cityBlock(x1, nz1); cityBlock(x2, nz1); cityBlock(x3, nz1); cityBlock(x4, nz1); cityBlock(x5, nz1);
	cityBlock(x1, nz2); cityBlock(x2, nz2); cityBlock(x3, nz2); cityBlock(x4, nz2); cityBlock(x5, nz2);
	cityBlock(x1, nz3); cityBlock(x2, nz3); cityBlock(x3, nz3); cityBlock(x4, nz3); cityBlock(x5, nz3);
	cityBlock(x1, nz4); cityBlock(x2, nz4); cityBlock(x3, nz4); cityBlock(x4, nz4); cityBlock(x5, nz4);
	cityBlock(x1, nz5); cityBlock(x2, nz5); cityBlock(x3, nz5); cityBlock(x4, nz5); cityBlock(x5, nz5);
	// SOUTH district
	cityBlock(x1, sz1); cityBlock(x2, sz1); cityBlock(x3, sz1); cityBlock(x4, sz1); cityBlock(x5, sz1);
	cityBlock(x1, sz2); cityBlock(x2, sz2); cityBlock(x3, sz2); cityBlock(x4, sz2); cityBlock(x5, sz2);
	cityBlock(x1, sz3); cityBlock(x2, sz3); cityBlock(x3, sz3); cityBlock(x4, sz3); cityBlock(x5, sz3);
	cityBlock(x1, sz4); cityBlock(x2, sz4); cityBlock(x3, sz4); cityBlock(x4, sz4); cityBlock(x5, sz4);
	cityBlock(x1, sz5); cityBlock(x2, sz5); cityBlock(x3, sz5); cityBlock(x4, sz5); cityBlock(x5, sz5);

	rmSetStatusText("", 0.85);

	// ---- MINIMAL PLAYER PLACEMENT (stub so the map generates) ------------
	rmPlacePlayersCircular(0.42, 0.42, 0.0);

	rmSetStatusText("", 1.00);
}
