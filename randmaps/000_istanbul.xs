// ============================================================================
// 000_istanbul.xs  -  Istanbul city map (Age of Pirates)
// ----------------------------------------------------------------------------
// Layout source: Figma "AoE Maps", node 248:167. The Figma is drawn in
// MINIMAP orientation (rotated ~45 deg like the in-game minimap), so the two
// rotated block grids are AXIS-ALIGNED rectangles in real map space: a WEST
// district and an EAST district split by the central Bosphorus channel, with
// a trade route running down each bank of the water (structure mirrors
// zpparis: two cities either side of a central water strip).
//
// MINIMAL v2 (2026-08-10). Only three things, on purpose:
//   1. water base (Bosphorus fills the map)
//   2. two trade routes, one down each bank of the channel (per Figma)
//   3. the raised, RECTANGULAR city-block terrain for the two districts,
//      shaped with BOX CONSTRAINTS (the zpparis technique)
//
// One size fits all -- fixed square map. Blocks/natives/players: next steps.
// ============================================================================

void main(void)
{
	rmSetStatusText("", 0.01);

	// ---- MAP SIZE (one size fits all) ------------------------------------
	int size = 500;
	rmSetMapSize(size, size);
	rmSetMapElevationHeightBlend(1);

	// ---- WATER BASE (the Bosphorus) --------------------------------------
	rmSetSeaLevel(0.0);
	rmSetSeaType("great lakes2");
	rmTerrainInitialize("water");
	rmSetLightingSet("age3challenges09a");
	rmSetMapType("water");
	rmSetMapType("land");
	rmSetWorldCircleConstraint(true);

	rmSetStatusText("", 0.15);

	// ---- CLASSES ---------------------------------------------------------
	rmDefineClass("classPlateau");   // walled city ground
	rmDefineClass("classBlock");     // city-block groupings (later)
	rmDefineClass("classStreet");    // paved streets (later)

	// ---- BOX CONSTRAINTS: the two districts are RECTANGLES ----------------
	// A big area budget + high coherence + a box constraint fills the box as
	// a clean rectangle (the zpparis city technique). Central strip
	// x[0.42,0.58] is left as open water = the Bosphorus.
	int westCityBox = rmCreateBoxConstraint("west city box", 0.06, 0.12, 0.42, 0.88, 0.01);
	int eastCityBox = rmCreateBoxConstraint("east city box", 0.58, 0.12, 0.94, 0.88, 0.01);

	// ---- TWO TRADE ROUTES: one down each bank of the channel (per Figma) --
	int tradeRouteWest = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteWest, 0.40, 0.06);
	rmAddTradeRouteWaypoint(tradeRouteWest, 0.40, 0.50);
	rmAddTradeRouteWaypoint(tradeRouteWest, 0.40, 0.94);
	rmBuildTradeRoute(tradeRouteWest, "dirt");

	int tradeRouteEast = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteEast, 0.60, 0.06);
	rmAddTradeRouteWaypoint(tradeRouteEast, 0.60, 0.50);
	rmAddTradeRouteWaypoint(tradeRouteEast, 0.60, 0.94);
	rmBuildTradeRoute(tradeRouteEast, "dirt");

	rmSetStatusText("", 0.45);

	// ---- CITY-BLOCK TERRAIN: two rectangular districts -------------------
	int cityWest = rmCreateArea("cityWest");
	rmSetAreaSize(cityWest, 0.5, 0.5);
	rmSetAreaLocation(cityWest, 0.24, 0.5);
	rmSetAreaCoherence(cityWest, 1.0);
	rmSetAreaBaseHeight(cityWest, 3.0);
	rmSetAreaTerrainType(cityWest, "city\ground1_cob_dark");
	rmSetAreaCliffType(cityWest, "ZP City");
	rmSetAreaCliffEdge(cityWest, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityWest, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityWest, westCityBox);
	rmAddAreaToClass(cityWest, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityWest, false);
	rmBuildArea(cityWest);

	int cityEast = rmCreateArea("cityEast");
	rmSetAreaSize(cityEast, 0.5, 0.5);
	rmSetAreaLocation(cityEast, 0.76, 0.5);
	rmSetAreaCoherence(cityEast, 1.0);
	rmSetAreaBaseHeight(cityEast, 3.0);
	rmSetAreaTerrainType(cityEast, "city\ground1_cob_dark");
	rmSetAreaCliffType(cityEast, "ZP City");
	rmSetAreaCliffEdge(cityEast, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityEast, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityEast, eastCityBox);
	rmAddAreaToClass(cityEast, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityEast, false);
	rmBuildArea(cityEast);

	rmSetStatusText("", 0.80);

	// ---- MINIMAL PLAYER PLACEMENT (stub so the map generates) ------------
	rmPlacePlayersCircular(0.42, 0.42, 0.0);

	rmSetStatusText("", 1.00);
}
