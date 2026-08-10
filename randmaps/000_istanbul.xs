// ============================================================================
// 000_istanbul.xs  -  Istanbul city map (Age of Pirates)
// ----------------------------------------------------------------------------
// Layout source: Figma "AoE Maps", node 248:167 -- two diagonal city-block
// grids split by the Bosphorus, NW district and SE district.
//
// MINIMAL v1 (2026-08-10). Only three things, on purpose:
//   1. water base (the Bosphorus fills the whole map)
//   2. two trade routes (one main street through each district)
//   3. the raised city-block TERRAIN for the two districts (walled + paved)
//
// One size fits all -- fixed square map, no per-player scaling.
// City-block groupings, natives, sockets, players: NOT here yet (next steps).
// ============================================================================

void main(void)
{
	rmSetStatusText("", 0.01);

	// ---- MAP SIZE (one size fits all) ------------------------------------
	int size = 500;
	rmSetMapSize(size, size);
	rmSetMapElevationHeightBlend(1);

	// ---- WATER BASE ------------------------------------------------------
	// The Bosphorus is the base: the whole map starts as water and the two
	// city districts are raised out of it (same recipe as the island maps).
	rmSetSeaLevel(0.0);
	rmSetSeaType("great lakes2");
	rmTerrainInitialize("water");
	rmSetLightingSet("age3challenges09a");
	rmSetMapType("water");
	rmSetMapType("land");
	rmSetWorldCircleConstraint(true);

	rmSetStatusText("", 0.15);

	// ---- CLASSES ---------------------------------------------------------
	rmDefineClass("classPlateau");   // the walled city ground
	rmDefineClass("classBlock");     // city-block groupings (later)
	rmDefineClass("classStreet");    // paved streets (later)

	// ---- TWO TRADE ROUTES ------------------------------------------------
	// One main street per district, running NE->SW parallel to the Bosphorus
	// and passing through the district centre so the blocks can line up on it.
	int tradeRouteNW = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteNW, 0.50, 0.08);
	rmAddTradeRouteWaypoint(tradeRouteNW, 0.32, 0.32);
	rmAddTradeRouteWaypoint(tradeRouteNW, 0.08, 0.50);
	rmBuildTradeRoute(tradeRouteNW, "dirt");

	int tradeRouteSE = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteSE, 0.92, 0.50);
	rmAddTradeRouteWaypoint(tradeRouteSE, 0.68, 0.68);
	rmAddTradeRouteWaypoint(tradeRouteSE, 0.50, 0.92);
	rmBuildTradeRoute(tradeRouteSE, "dirt");

	rmSetStatusText("", 0.45);

	// ---- CITY-BLOCK TERRAIN: two raised districts ------------------------
	// Raised land (base height above the water), walled with the ZP City
	// cliff edge, paved with city cobblestone. This is the ground the city
	// blocks will be placed onto next.

	int cityNW = rmCreateArea("cityNW");
	rmSetAreaSize(cityNW, 0.06, 0.06);
	rmSetAreaLocation(cityNW, 0.32, 0.32);
	rmSetAreaCoherence(cityNW, 1.0);
	rmSetAreaBaseHeight(cityNW, 3.0);
	rmSetAreaTerrainType(cityNW, "city\ground1_cob_dark");
	rmSetAreaCliffType(cityNW, "ZP City");
	rmSetAreaCliffEdge(cityNW, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityNW, 0, 0.0, 1.0);
	rmAddAreaToClass(cityNW, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityNW, false);
	rmBuildArea(cityNW);

	int citySE = rmCreateArea("citySE");
	rmSetAreaSize(citySE, 0.06, 0.06);
	rmSetAreaLocation(citySE, 0.68, 0.68);
	rmSetAreaCoherence(citySE, 1.0);
	rmSetAreaBaseHeight(citySE, 3.0);
	rmSetAreaTerrainType(citySE, "city\ground1_cob_dark");
	rmSetAreaCliffType(citySE, "ZP City");
	rmSetAreaCliffEdge(citySE, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(citySE, 0, 0.0, 1.0);
	rmAddAreaToClass(citySE, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(citySE, false);
	rmBuildArea(citySE);

	rmSetStatusText("", 0.80);

	// ---- MINIMAL PLAYER PLACEMENT (stub so the map generates) ------------
	// Real Istanbul spawns come later (players start inside the districts).
	rmPlacePlayersCircular(0.42, 0.42, 0.0);

	rmSetStatusText("", 1.00);
}
