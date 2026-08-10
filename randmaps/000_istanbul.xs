// ============================================================================
// 000_istanbul.xs  -  Istanbul city map (Age of Pirates)
// ----------------------------------------------------------------------------
// Layout source: Figma "AoE Maps", node 248:167 (drawn in MINIMAP orientation,
// rotated ~45 deg). Two rectangular city-block districts split by the central
// Bosphorus, a trade route down each bank, green land ringing the map for
// players. Structure mirrors zpparis (two cities either side of a water strip).
//
// MINIMAL (2026-08-10): water base + two trade routes + the raised, RECTANGULAR
// city-block terrain, shaped with BOX CONSTRAINTS + INFLUENCE SEGMENTS (the
// zpparis technique -- box clips the sides, the segment stretches it long).
// One size fits all. Blocks/natives/players/towers: next steps.
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
	rmDefineClass("classPlateau");
	rmDefineClass("classBlock");
	rmDefineClass("classStreet");

	// ---- BOX CONSTRAINTS: two RECTANGULAR districts ----------------------
	// Real-space NORTH district + SOUTH district; the +45 deg minimap turns
	// this N/S split into the Figma's upper-left / lower-right diagonal. The
	// boxes stay off the map edges so green land rings the city (player land).
	// Central strip z[0.42,0.58] stays open water = the Bosphorus.
	int cityNbox = rmCreateBoxConstraint("north city box", 0.14, 0.08, 0.86, 0.42, 0.01);
	int citySbox = rmCreateBoxConstraint("south city box", 0.14, 0.58, 0.86, 0.92, 0.01);

	// ---- TWO TRADE ROUTES: one down each bank of the channel (per Figma) --
	int tradeRouteN = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteN, 0.12, 0.40);
	rmAddTradeRouteWaypoint(tradeRouteN, 0.50, 0.40);
	rmAddTradeRouteWaypoint(tradeRouteN, 0.88, 0.40);
	rmBuildTradeRoute(tradeRouteN, "dirt");

	int tradeRouteS = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteS, 0.12, 0.60);
	rmAddTradeRouteWaypoint(tradeRouteS, 0.50, 0.60);
	rmAddTradeRouteWaypoint(tradeRouteS, 0.88, 0.60);
	rmBuildTradeRoute(tradeRouteS, "dirt");

	rmSetStatusText("", 0.45);

	// ---- CITY-BLOCK TERRAIN: two rectangular districts -------------------
	// Big budget + coherence 1.0 + box (clips sides) + a horizontal influence
	// segment (stretches it across the width) => a filled rectangle.
	int cityN = rmCreateArea("cityNorth");
	rmSetAreaSize(cityN, 0.6, 0.6);
	rmSetAreaLocation(cityN, 0.5, 0.25);
	rmSetAreaCoherence(cityN, 1.0);
	rmSetAreaBaseHeight(cityN, 3.0);
	rmAddAreaInfluenceSegment(cityN, 0.18, 0.25, 0.82, 0.25);
	rmSetAreaTerrainType(cityN, "city\ground1_cob_dark");
	rmSetAreaCliffType(cityN, "ZP City");
	rmSetAreaCliffEdge(cityN, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityN, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityN, cityNbox);
	rmAddAreaToClass(cityN, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityN, false);
	rmBuildArea(cityN);

	int cityS = rmCreateArea("citySouth");
	rmSetAreaSize(cityS, 0.6, 0.6);
	rmSetAreaLocation(cityS, 0.5, 0.75);
	rmSetAreaCoherence(cityS, 1.0);
	rmSetAreaBaseHeight(cityS, 3.0);
	rmAddAreaInfluenceSegment(cityS, 0.18, 0.75, 0.82, 0.75);
	rmSetAreaTerrainType(cityS, "city\ground1_cob_dark");
	rmSetAreaCliffType(cityS, "ZP City");
	rmSetAreaCliffEdge(cityS, 1, 1.0, 0.1, 1.0, 0);
	rmSetAreaCliffHeight(cityS, 0, 0.0, 1.0);
	rmAddAreaConstraint(cityS, citySbox);
	rmAddAreaToClass(cityS, rmClassID("classPlateau"));
	rmSetAreaObeyWorldCircleConstraint(cityS, false);
	rmBuildArea(cityS);

	rmSetStatusText("", 0.80);

	// ---- MINIMAL PLAYER PLACEMENT (stub so the map generates) ------------
	rmPlacePlayersCircular(0.42, 0.42, 0.0);

	rmSetStatusText("", 1.00);
}
