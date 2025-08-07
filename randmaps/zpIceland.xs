// Iceland
// 08/2025

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

// Main entry point for random map script
void main(void)
{
	// Map loading
	rmSetStatusText("", 0.01); 
	
	// ---------------------------------------------------
	// ******************** General **********************
	// ---------------------------------------------------
	
	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);

	// Strings
    string startShipType1 = "zpSPCRowboat";
    string startShipType2 = "zpCorvette";
    string toiletPaper = "water_trail";
    string wetTypeSea = "ZP Iceland";
    string wetTypeLake = "ZP Iceland Lake";
    string initLand = "water";
    string paintMix0 = "great_lakes_ice";
    string paintMix1 = "rockies_snowa";		// italy_snow_grass_blenda
    string paintMix2 = "italy_snow_grass";
    string paintMix3 = "italy_snow";
    string paintMix4 = "araucania_snow_b";
    string paintMix5 = "siberia_grass_snowb";	// italy_snow_dirt
    string paintMix6 = "italy_snow_forest";
    string paintMix7 = "rockies_snow_forest";
    string paintMix8 = "araucania_snow_b";		// italy_snow_cliff
    string forTesting = "testmix";
    string treasureSet = "northEurope";
	string treasureSet2 = "icelandWater";
    string aopMapType = "piratehistoricalmap";
	string tradeRouteMapType = "euroTradeRouteCapture";
    string shineAlight = "spcjc4aflashback";
	string volcanoLight = "pcjc4brain";
    string huntType = "caribou";
    string fishies = "FishSalmon";
    string treeType1 = "TreeGreatLakesSnow";
    string treeType2 = "ypTreeHimalayas";
    string treeType3 = "TreeNewEnglandSnow";
    string treeType4 = "TreeRockiesSnow";
    string mntType = "New England Snow";
    string volcCliffLow = "ZP Iceland Low";
    string volcCliffMid = "ZP Iceland Medium";
    string volcCliffHigh = "ZP Iceland High";
    string volcCliffCrater = "ZP Hawaii Crater";
    string volcTerrainLow = "lava\volcano_snow";
    string volcTerrainHigh = "lava\volcano_dirt";
    string volcTerrainCrater = "lava\crater";
    string volcTerrainCraterPass = "lava\crater_passable";
    string volcTerrainLava = "lava\lavaflow";
    string brushType1 = "UnderBrushRockiesSnow";
    string brushType2 = "UnderBrushPatagoniaSnow";
    string brushType3 = "UnderbrushSnow";
	string natType1 = "NatPirates";
	string natType2 = "zpScientists";
	string natType3 = "zphansakontor";
	string natGrpName1 = "pirate_village0";		// 7 and 8
	string natGrpName2 = "Scientist_Lab0";		// 1 and 2
	string natGrpName3 = "Hansa_Unknown_0";		// 1 and 2

	// Set up natives
	int subCiv0 = rmGetCivID(natType1);
	int subCiv1 = rmGetCivID(natType2);
	int subCiv2 = rmGetCivID(natType3);
	rmSetSubCiv(0, natType1);
	rmSetSubCiv(1, natType2);
	rmSetSubCiv(2, natType3);

	// Picks the map size
//	int playerTiles = -1;
//	if (PlayerNum <= 8)
//		playerTiles = 20000;
//	if (PlayerNum <= 6)
//		playerTiles = 22000;
//	if (PlayerNum <= 4)
//		playerTiles = 26000;
//	if (PlayerNum <= 2)
//		playerTiles = 28000;
//	int size = 2.0*sqrt(PlayerNum*playerTiles);

	int size = -1;
	if (PlayerNum <= 8)
		size = 800;
	if (PlayerNum <= 6)
		size = 725;
	if (PlayerNum <= 4)
		size = 645;
	if (PlayerNum <= 2)
		size = 475;
	rmSetMapSize(size, size);
	
	// Make the corners
	rmSetWorldCircleConstraint(false);
	
	// Picks a default water height
	rmSetSeaLevel(0);	// this is height of river surface compared to surrounding land. River depth is in the river XML.

	// Picks default terrain and water
    rmSetSeaType(wetTypeSea);
    rmTerrainInitialize(initLand, 0);
    rmSetMapType(treasureSet);
	rmSetMapType(treasureSet2);
    rmSetMapType(tradeRouteMapType);
	rmSetMapType(aopMapType);
    rmSetMapType("grass");
    rmSetMapType("water");
    rmSetLightingSet(shineAlight);
    rmSetGlobalSnow(0.333);
    rmSetOceanReveal(true);

	// Choose mercs
	chooseMercs();
	
	// Make it snow
	rmSetGlobalSnow(0.50);
  
	// Define some classes
	int classPlateau = rmDefineClass("plateau");
	int classCliff = rmDefineClass("cliffs");
	int classPlayer = rmDefineClass("player");
	int classPatch = rmDefineClass("patch");
	int classForest = rmDefineClass("Forest");
	int classGold = rmDefineClass("Gold");
	int classStartingResource = rmDefineClass("startingResource");
	int classIsland = rmDefineClass("island");
	int classNative = rmDefineClass("natives");
	int classProp = rmDefineClass("props");
	int classHansa = rmDefineClass("hansa");
	int classPirateIsland = rmDefineClass("pirateIsland");
	int classMainIsland = rmDefineClass("mainIsland");
	int classCave = rmDefineClass("cave");
	int classSea = rmDefineClass("sea");
	
	// ---------------------------------------------------
	// ****************** Constraints ********************
	// ---------------------------------------------------
   
	// Pie constraints
	int avoidEdge = rmCreatePieConstraint("avoid edge", 0.50, 0.50, rmXFractionToMeters(0), rmXFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidEdgeMore = rmCreatePieConstraint("avoid edge More", 0.50, 0.50, rmXFractionToMeters(0), rmXFractionToMeters(0.42), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidCenter = rmCreatePieConstraint("avoid center", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.5), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidCenterMin = rmCreatePieConstraint("avoid center min", 0.50, 0.50, rmXFractionToMeters(0.10), rmXFractionToMeters(0.5), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int stayCenter = rmCreatePieConstraint("stay center", 0.50, 0.50, rmXFractionToMeters(0.05), rmXFractionToMeters(0.20), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int stayCenterMin = rmCreatePieConstraint("stay center min", 0.50, 0.50, rmXFractionToMeters(0.05), rmXFractionToMeters(0.15), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int stayNWQ = rmCreatePieConstraint("stay nw quadrant", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(340), rmDegreesToRadians(020));
	int stayNEQ = rmCreatePieConstraint("stay ne quadrant", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(070), rmDegreesToRadians(110));
	int staySEQ = rmCreatePieConstraint("stay se quadrant", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(160), rmDegreesToRadians(200));
	int staySWQ = rmCreatePieConstraint("stay sw quadrant", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(250), rmDegreesToRadians(290));
	int stayNW = rmCreatePieConstraint("stay nw", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(315), rmDegreesToRadians(045));
	int stayNE = rmCreatePieConstraint("stay ne", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(045), rmDegreesToRadians(135));
	int staySE = rmCreatePieConstraint("stay se", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(135), rmDegreesToRadians(225));
	int staySW = rmCreatePieConstraint("stay sw", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(225), rmDegreesToRadians(315));
	int stayN = rmCreatePieConstraint("stay nor", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(020), rmDegreesToRadians(070));
	int stayE = rmCreatePieConstraint("stay est", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(110), rmDegreesToRadians(160));
	int stayS = rmCreatePieConstraint("stay sud", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(200), rmDegreesToRadians(250));
	int stayW = rmCreatePieConstraint("stay wst", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(290), rmDegreesToRadians(340));
	int staySouthShore = rmCreatePieConstraint("stay south shore", 0.50, 0.50, rmXFractionToMeters(0.15), rmXFractionToMeters(0.48), rmDegreesToRadians(135), rmDegreesToRadians(315));

	// Resource avoidance
	int avoidForestFar = rmCreateClassDistanceConstraint("avoid forest far", classForest, 36);
	int avoidForest = rmCreateClassDistanceConstraint("avoid forest", classForest, 24);
	int avoidForestMed = rmCreateClassDistanceConstraint("avoid forest med", classForest, 18);
	int avoidForestShort = rmCreateClassDistanceConstraint("avoid forest short", classForest, 8);
	int avoidForestMin = rmCreateClassDistanceConstraint("avoid forest min", classForest, 4);
	int forestConstraint = rmCreateClassDistanceConstraint("forest vs. forest", classForest, 18);
	int forestConstraintShort = rmCreateClassDistanceConstraint("object vs. forest", classForest, 12);
	int avoidHunt = rmCreateTypeDistanceConstraint("avoid hunt", huntType, 40);
	int avoidHuntFar = rmCreateTypeDistanceConstraint("avoid hunt far", huntType, 64);
	int avoidHuntShort = rmCreateTypeDistanceConstraint("avoid hunt short", huntType, 18);
	int avoidHuntMin = rmCreateTypeDistanceConstraint("avoid hunt min", huntType, 8);
	int avoidGoldMin = rmCreateClassDistanceConstraint("min distance vs gold", classGold, 4);
	int avoidGoldShort = rmCreateClassDistanceConstraint ("gold avoid gold short", classGold, 8);
	int avoidGold = rmCreateClassDistanceConstraint ("gold avoid gold med", classGold, 48);
	int avoidGoldFar = rmCreateClassDistanceConstraint ("gold avoid gold far", classGold, 72);
	int avoidGoldVeryFar = rmCreateClassDistanceConstraint ("gold avoid gold very far", classGold, 90);
	int avoidNuggetMin = rmCreateTypeDistanceConstraint("nugget avoid nugget min", "AbstractNugget", 4);
	int avoidNuggetShort = rmCreateTypeDistanceConstraint("nugget avoid nugget short", "AbstractNugget", 8);
	int avoidNugget = rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 36);
	int avoidNuggetFar = rmCreateTypeDistanceConstraint("nugget avoid nugget Far", "AbstractNugget", 48);
	int avoidNuggetVeryFar = rmCreateTypeDistanceConstraint("nugget avoid nugget very far", "AbstractNugget", 64);
	int avoidStartingResourcesFar = rmCreateClassDistanceConstraint("avoid starting resources far", classStartingResource, 20+5*PlayerNum);
	int avoidStartingResources = rmCreateClassDistanceConstraint("avoid starting resources", classStartingResource, 12);
	int avoidStartingResourcesShort = rmCreateClassDistanceConstraint("avoid starting resources short", classStartingResource, 8);
	int avoidStartingResourcesMin = rmCreateClassDistanceConstraint("avoid starting resources min", classStartingResource, 4);
    int avoidNativesMin = rmCreateClassDistanceConstraint("stuff avoids natives min", classNative, 2);
    int avoidNativesShort = rmCreateClassDistanceConstraint("stuff avoids natives short", classNative, 4);
    int avoidNativesNil = rmCreateClassDistanceConstraint("stuff avoids natives nil", classNative, 0);
    int avoidNatives = rmCreateClassDistanceConstraint("stuff avoids natives", classNative, 8);
    int avoidNativesFar = rmCreateClassDistanceConstraint("stuff avoids natives far", classNative, 24);
    int avoidProp = rmCreateClassDistanceConstraint("props avoid props", classProp, 8);
	int avoidGroupingCenter = rmCreateTypeDistanceConstraint("avoid grouping center", "zpCinematicRevealer", 22);
	int avoidWall=rmCreateTypeDistanceConstraint("avoid wall", "zpHarbourPathBlock3", 4);
    int avoidHansa = rmCreateClassDistanceConstraint("stuff avoids hansa", classHansa, 30);
	int avoidWhale=rmCreateTypeDistanceConstraint("avoid whale", "MinkeWhale", 90);
	int avoidWhaleMin=rmCreateTypeDistanceConstraint("avoid whale min", "MinkeWhale", 4);
	int avoidFish=rmCreateTypeDistanceConstraint("avoid fish", fishies, 16);
	int avoidFishShort=rmCreateTypeDistanceConstraint("avoid fish short", fishies, 8);
	int avoidFishMin=rmCreateTypeDistanceConstraint("avoid fish min", fishies, 2);

	// Land and water constraints
	int avoidImpassableLand = rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4);
	int avoidImpassableLandFar=rmCreateTerrainDistanceConstraint("far avoid impassable land", "Land", false, 8);
	int avoidImpassableLandShort = rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2);
	int avoidImpassableLandMin = rmCreateTerrainDistanceConstraint("min avoid impassable land", "Land", false, 1);
	int avoidImpassableLandNil=rmCreateTerrainDistanceConstraint("avoid impassable land nil", "Land", false, 0.2);
	int avoidPlateau = rmCreateClassDistanceConstraint("avoid plateau", classPlateau, 8);
	int avoidCliffShort = rmCreateClassDistanceConstraint("avoid cliff short", classCliff, 4);
	int avoidCliff = rmCreateClassDistanceConstraint("avoid cliff", classCliff, 8);
	int avoidCliffFar = rmCreateClassDistanceConstraint("avoid cliff far", classCliff, 16);
	int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", classPatch, 8);
	int avoidPatchFar = rmCreateClassDistanceConstraint("avoid patch far", classPatch, 16);
	int avoidIslandMin = rmCreateClassDistanceConstraint("avoid island min", classIsland, 2);
	int avoidIslandShort = rmCreateClassDistanceConstraint("avoid island short", classIsland, 4);
	int avoidIsland = rmCreateClassDistanceConstraint("avoid island", classIsland, 8);
	int avoidIslandFar = rmCreateClassDistanceConstraint("avoid island far", classIsland, 20);
	int stayIsland = rmCreateClassDistanceConstraint("stay island", classIsland, 0);
    int avoidWaterFar  =  rmCreateTerrainDistanceConstraint("avoid water far", "water", true, 24);
    int avoidWater  =  rmCreateTerrainDistanceConstraint("avoid water", "water", true, 8);
    int avoidWaterShort  =  rmCreateTerrainDistanceConstraint("avoid water short", "water", true, 4);
    int avoidWaterMin  =  rmCreateTerrainDistanceConstraint("avoid water min", "water", true, 1);
    int avoidWaterNil = rmCreateTerrainDistanceConstraint("avoid water nil", "water", true, 0);
	int avoidLand = rmCreateTerrainDistanceConstraint("stuff avoids land", "land", true, 8);
	int avoidLandShort = rmCreateTerrainDistanceConstraint("stuff avoids land short", "land", true, 1.5);
	int stayNearWater = rmCreateTerrainMaxDistanceConstraint("stay near water ", "land", false, 10);
	int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 9);
	int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 18);
	int avoidPirateIslands=rmCreateClassDistanceConstraint("stuff avoids pirate island", classPirateIsland, 3);
	int avoidPirateIslandsFar=rmCreateClassDistanceConstraint("stuff avoids pirate island far", classPirateIsland, 20);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 5.5);
	int avoidMainIsland=rmCreateClassDistanceConstraint("stuff avoids main island", classMainIsland, 15);
	int avoidCave=rmCreateClassDistanceConstraint("stuff avoids cave", classCave, 4);
	int avoidCaveFar=rmCreateClassDistanceConstraint("stuff avoids cave far", classCave, rmXFractionToMeters(0.065));
	int avoidSea=rmCreateClassDistanceConstraint("stuff avoids sea", classSea, 1.7);

	// VP avoidance
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 8);
	int avoidTradeRouteSocketMin = rmCreateTradeRouteDistanceConstraint("trade route socket min", 2);
	int avoidTradeRouteSocketShort = rmCreateTradeRouteDistanceConstraint("trade route socket short", 4);
	int avoidTradeRouteSocket = rmCreateTypeDistanceConstraint("avoid trade route socket", "socketTradeRoute", 8);
	int avoidTradeRouteSocketFar = rmCreateTypeDistanceConstraint("avoid trade route socket far", "socketTradeRoute", 16);
	int cliffAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("cliff trade route", 2);

	//int cliffMaxHeight = rmCreateMaxHeightConstraint("cliff maxHeight", 6);
	
	// ---------------------------------------------------
	// **************** Player placement *****************
	// ---------------------------------------------------

	int leftTeam = -1;
	int rightTeam = -1;

	if (TeamNum == 2)
	{
		if (rmRandFloat(0,1) <= 0.50)
		{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.09-0.04*teamZeroCount, 0.09);
			rmSetTeamSpacingModifier(0.50);
			rmPlacePlayersCircular(0.44, 0.44, 0);
			leftTeam = 0;

			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.16, 0.16+0.04*teamOneCount);
			rmSetTeamSpacingModifier(0.50);
			rmPlacePlayersCircular(0.44, 0.44, 0);	
			rightTeam = 1;
		}
		else
		{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.16, 0.16+0.04*teamZeroCount);
			rmSetTeamSpacingModifier(0.50);
			rmPlacePlayersCircular(0.44, 0.44, 0);	
			leftTeam = 1;

			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.09-0.04*teamOneCount, 0.09);
			rmSetTeamSpacingModifier(0.50);
			rmPlacePlayersCircular(0.44, 0.44, 0);
			rightTeam = 0;
		}
	}
	else
	{
		if (cNumberNonGaiaPlayers <=5)
		{
			rmSetTeamSpacingModifier(0.50);
			rmSetPlacementSection(0.125-0.04*PlayerNum, 0.125+0.04*PlayerNum);
			rmPlacePlayersCircular(0.44, 0.44, 0);
		}
		else
		{
			rmSetTeamSpacingModifier(0.50);
			rmSetPlacementSection(0.125-0.05*PlayerNum, 0.125+0.05*PlayerNum);
			rmPlacePlayersCircular(0.44, 0.44, 0);
		}
	}

	// Map loading
	rmSetStatusText("", 0.10);

	// ---------------------------------------------------
	// ************** City state placement ***************
	// ---------------------------------------------------

	float sockLocX = 0.21;
	float sockLocY = 0.21;

	// Place land mass - needs to be placed before the trade route
	int landMassID = rmCreateArea("land mass");
    rmSetAreaSize(landMassID , rmAreaTilesToFraction(1900));
    rmSetAreaLocation(landMassID , sockLocX+rmXTilesToFraction(12), sockLocY+rmZTilesToFraction(12));
    rmSetAreaCoherence(landMassID , 1);
    rmSetAreaBaseHeight(landMassID, 2);
    rmSetAreaWarnFailure(landMassID, false);
    rmSetAreaMix(landMassID, paintMix2);
    rmBuildArea(landMassID ); 

	// Trade Route
	int tradeRouteID = rmCreateTradeRoute();

	// Define fake stopper (without it the Venetian islands don't spawn)
    int fakeStopperID=rmCreateObjectDef("TradeShipStopperFake");
    rmAddObjectDefItem(fakeStopperID, "zpSPCWaterSpawnPoint", 1, 0);
    rmSetObjectDefAllowOverlap(fakeStopperID, true);
    rmSetObjectDefMinDistance(fakeStopperID, 0);
    rmSetObjectDefMaxDistance(fakeStopperID, 0); 

//	rmSetObjectDefTradeRouteID(fakeStopperID, tradeRouteID);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.00, 0.55);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.10, 0.45);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.10, 0.30);
	rmAddTradeRouteWaypoint(tradeRouteID, sockLocX-rmXTilesToFraction(8), sockLocY-rmZTilesToFraction(8));
	rmAddTradeRouteWaypoint(tradeRouteID, 0.30, 0.10);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.45, 0.10);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.55, 0.00);
	rmBuildTradeRoute(tradeRouteID, toiletPaper);

    // Place fake train stopper, because without it the islands don't spawn
    vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.50);
    rmPlaceObjectDefAtPoint(fakeStopperID, 0, socketLoc1);

	int riverID = rmRiverCreate(-1, wetTypeLake, 4, 4, 34, 34);
	rmRiverAddWaypoint(riverID, sockLocX, sockLocY);
	rmRiverAddWaypoint(riverID, sockLocX+rmXTilesToFraction(30), sockLocY+rmZTilesToFraction(30));
	rmRiverBuild(riverID);

	int socketID=rmCreateObjectDef("sockets to dock trade posts");
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmAddObjectDefItem(socketID, "zpTradingPostCaptureNaval", 1, 0);
	rmAddObjectDefToClass(socketID, classHansa);
	rmSetObjectDefMinDistance(socketID, 0);
	rmSetObjectDefMaxDistance(socketID, 0);
	rmPlaceObjectDefAtLoc(socketID, 0, sockLocX, sockLocY);

	vector controlLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(socketID, 0));

	int hansaIcelandID = rmCreateGrouping("hansa post", "Hansa_Iceland");
    rmSetGroupingMinDistance(hansaIcelandID, 0.00);
    rmSetGroupingMaxDistance(hansaIcelandID, 0.50);
	rmAddGroupingToClass(hansaIcelandID, classNative);

	rmSetNuggetDifficulty(294, 294);

    int hansaInstanceID = rmPlaceGroupingInstanceAtLoc(hansaIcelandID, rmXMetersToFraction(xsVectorGetX(controlLoc1))+rmXTilesToFraction(8), rmZMetersToFraction(xsVectorGetZ(controlLoc1))+rmZTilesToFraction(11), 0);

	// ---------------------------------------------------
	// **************** Underwater cave ******************
	// ---------------------------------------------------

	int waterCaveAreaIDLarge=rmCreateArea("UnderwaterArea Large");
	rmSetAreaWaterType(waterCaveAreaIDLarge, "ZP Iceland Transparent 3");
	rmSetAreaSize(waterCaveAreaIDLarge, rmAreaTilesToFraction(5800));
	rmSetAreaCoherence(waterCaveAreaIDLarge, 1);
	rmSetAreaLocation(waterCaveAreaIDLarge, 0.72, 0.72);
	rmSetAreaSmoothDistance(waterCaveAreaIDLarge, 10);
	rmBuildArea(waterCaveAreaIDLarge);

	int waterCaveAreaIDMedium=rmCreateArea("UnderwaterArea Medium");
	rmSetAreaWaterType(waterCaveAreaIDMedium, "ZP Iceland Transparent 2");
	rmSetAreaSize(waterCaveAreaIDMedium, rmAreaTilesToFraction(4500));
	rmSetAreaCoherence(waterCaveAreaIDMedium, 1);
	rmSetAreaLocation(waterCaveAreaIDMedium, 0.72, 0.72);
	rmSetAreaSmoothDistance(waterCaveAreaIDMedium, 10);
	rmBuildArea(waterCaveAreaIDMedium);

	int waterCaveAreaID=rmCreateArea("UnderwaterArea");
	rmSetAreaWaterType(waterCaveAreaID, "ZP Iceland Transparent");
	rmSetAreaSize(waterCaveAreaID, rmAreaTilesToFraction(3500));
	rmSetAreaCoherence(waterCaveAreaID, 1);
	rmSetAreaLocation(waterCaveAreaID, 0.72, 0.72);
	rmSetAreaSmoothDistance(waterCaveAreaID, 10);
	rmAddAreaToClass(waterCaveAreaID, classIsland);
	rmBuildArea(waterCaveAreaID);

	// Treasures tier 15

	for (i=0; < 4)
	{
		int nuggetDiverID = rmCreateObjectDef("nugget diver"+i); 
		rmAddObjectDefItem(nuggetDiverID, "ypNuggetBoat", 1, 0);
		rmSetObjectDefMinDistance(nuggetDiverID, 33);
		rmSetObjectDefMaxDistance(nuggetDiverID, 35);
		if (i<3)
			rmSetNuggetDifficulty(15,16);
		else
			rmSetNuggetDifficulty(17,17);
		rmAddObjectDefConstraint(nuggetDiverID, avoidNugget);
		rmAddObjectDefConstraint(nuggetDiverID, avoidLand);
		rmAddObjectDefConstraint(nuggetDiverID, avoidStartingResources);	
		rmAddObjectDefConstraint(nuggetDiverID, avoidNatives); 
		rmAddObjectDefConstraint(nuggetDiverID, avoidEdge); 
		rmAddObjectDefConstraint(nuggetDiverID, avoidWhaleMin); 
		rmPlaceObjectDefAtLoc(nuggetDiverID, 0, 0.72, 0.72-rmXTilesToFraction(6), 1);
	}

	int underwaterCaveID = rmCreateGrouping("underwater crater", "underwater_volcano");
	rmAddGroupingToClass(underwaterCaveID, classCave);
	rmPlaceGroupingAtLoc(underwaterCaveID, 1, 0.72, 0.72, 1);
	
	// Fake grouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4);
	rmAddObjectDefToClass(fakeGroupingLock, classStartingResource);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.85, 0.85);

	// Map loading
	rmSetStatusText("", 0.20);

	// ---------------------------------------------------
	// ****************** Pirate sites *******************
	// ---------------------------------------------------

	int numPirates = 3;

	int pirateControllerID1 = rmCreateObjectDef("pirate controller 1");
	rmAddObjectDefItem(pirateControllerID1, "zpSPCWaterSpawnPoint", 1, 0);

	int pirateControllerID2 = rmCreateObjectDef("pirate controller 2");
	rmAddObjectDefItem(pirateControllerID2, "zpSPCWaterSpawnPoint", 1, 0);

	int pirateControllerID3 = rmCreateObjectDef("pirate controller 3");
	rmAddObjectDefItem(pirateControllerID3, "zpSPCWaterSpawnPoint", 1, 0);

	rmPlaceObjectDefAtLoc(pirateControllerID1, 0, 0.60, 0.60);
	rmPlaceObjectDefAtLoc(pirateControllerID2, 0, 0.15, 0.58);
	rmPlaceObjectDefAtLoc(pirateControllerID3, 0, 0.58, 0.15);

	vector pirateControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(pirateControllerID1, 0));
	vector pirateControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(pirateControllerID2, 0));
	vector pirateControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(pirateControllerID3, 0));

	for (i=1; <= numPirates)
	{ 
		int pirateSiteID = rmCreateArea ("pirate_site"+i);
		rmSetAreaSize(pirateSiteID, rmAreaTilesToFraction(600));
		rmSetAreaMix(pirateSiteID, paintMix2);
		rmAddAreaTerrainLayer(pirateSiteID, "saguenay\shoreline1_sag", 0, 1);
		rmAddAreaTerrainLayer(pirateSiteID, "patagonia\ground_snow1_pat", 1, 2);
		rmSetAreaCoherence(pirateSiteID, 1);
		rmSetAreaSmoothDistance(pirateSiteID, 15);
		rmSetAreaBaseHeight(pirateSiteID, 2);
		rmAddAreaToClass(pirateSiteID, classPirateIsland);
		if (i==1)
		{
			rmSetAreaLocation(pirateSiteID, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc1)));
		}
		if (i==2)
		{
			rmSetAreaLocation(pirateSiteID, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc2)));
		}
		if (i==3)
		{
			rmSetAreaLocation(pirateSiteID, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc3)));
		}
		rmBuildArea(pirateSiteID);
	}

	// ---------------------------------------------------
	// *************** Build the island ******************
	// ---------------------------------------------------

	int icelandID = rmCreateArea("iceland");
	rmSetAreaSize(icelandID, 0.28);
	rmSetAreaLocation(icelandID, 0.50, 0.50);
	rmAddAreaInfluenceSegment(icelandID, 0.65, 0.35, 0.35, 0.65);
//	rmAddAreaInfluenceSegment(icelandID, 0.65, 0.35, 0.40, 0.40);
	rmAddAreaInfluenceSegment(icelandID, 0.40, 0.40, 0.35, 0.70);
	rmAddAreaInfluenceSegment(icelandID, 0.40, 0.40, 0.70, 0.35);
	rmSetAreaMix(icelandID, paintMix2);
	rmAddAreaTerrainLayer(icelandID, "saguenay\shoreline1_sag", 0, 1);
	rmAddAreaTerrainLayer(icelandID, "patagonia\ground_snow1_pat", 1, 2);
	rmSetAreaWarnFailure(icelandID, false);
	rmAddAreaToClass(icelandID, classIsland);
	rmAddAreaToClass(icelandID, classMainIsland);
	rmSetAreaCoherence(icelandID, 0.45);
	rmSetAreaSmoothDistance(icelandID, 10);
	rmSetAreaElevationType(icelandID, cElevTurbulence);
	rmSetAreaElevationVariation(icelandID, 2.5);
	rmSetAreaBaseHeight(icelandID, 2);
	rmSetAreaElevationMinFrequency(icelandID, 0.09);
	rmSetAreaElevationOctaves(icelandID, 3);
	rmSetAreaElevationPersistence(icelandID, 0.4);      
	rmSetAreaObeyWorldCircleConstraint(icelandID, false);
	rmAddAreaConstraint(icelandID, avoidIslandShort);
	rmAddAreaConstraint(icelandID, avoidPirateIslands);
	rmAddAreaConstraint(icelandID, avoidCaveFar);
	rmAddAreaConstraint(icelandID, avoidEdgeMore);
	rmAddAreaConstraint(icelandID, avoidTradeRoute);
	rmAddAreaConstraint(icelandID, avoidHansa);
	rmSetAreaMinBlobs(icelandID, 1);
	rmSetAreaMaxBlobs(icelandID, 5);
	rmSetAreaMinBlobDistance(icelandID, 20);
	rmSetAreaMaxBlobDistance(icelandID, 20);
	rmSetAreaHeightBlend(icelandID, 1.5);
//	rmAddAreaConstraint(icelandID, avoidGroupingCenter);
	rmBuildArea(icelandID);

	int cityCountrySide = rmCreateArea("countryside");
    rmSetAreaSize(cityCountrySide, rmAreaTilesToFraction(1200));
    rmSetAreaCoherence(cityCountrySide, 1);
    rmSetAreaMix(cityCountrySide, paintMix2);
    rmSetAreaBaseHeight(cityCountrySide, 2);
    rmSetAreaHeightBlend(cityCountrySide, 1);
    rmSetAreaSmoothDistance(cityCountrySide, 3);
	rmAddAreaConstraint(cityCountrySide, avoidWall);
    rmSetAreaLocation(cityCountrySide, rmXMetersToFraction(xsVectorGetX(controlLoc1))+rmXTilesToFraction(20), rmZMetersToFraction(xsVectorGetZ(controlLoc1))+rmZTilesToFraction(20));
    rmBuildArea(cityCountrySide);

	int stayInPaint = -1;
	int paintPatchID = -1;
	int patchcount = -1;

	for (i= 0; < 2)
	{
		int paintLayerID = rmCreateArea("paint layers"+i);
		rmSetAreaLocation(paintLayerID, 0.45, 0.45);
		if (i == 0)
		{
			rmSetAreaSize(paintLayerID, 0.15);
			rmSetAreaMix(paintLayerID, paintMix1);
			rmSetAreaBaseHeight(paintLayerID, 3);
		}
		else
		{
			rmSetAreaSize(paintLayerID, 0.08);
			rmSetAreaMix(paintLayerID, paintMix1);
			rmSetAreaBaseHeight(paintLayerID, 4);
		}
		rmSetAreaWarnFailure(paintLayerID, false);
		rmSetAreaCoherence(paintLayerID, 0.39);
		rmSetAreaObeyWorldCircleConstraint(paintLayerID, false);
		rmAddAreaConstraint(paintLayerID, avoidWaterFar);
		rmBuildArea(paintLayerID);

		stayInPaint = rmCreateAreaMaxDistanceConstraint("stay in paint"+i, paintLayerID, 0);

		if (i == 0)
			patchcount = 16*PlayerNum;
		else
			patchcount = 10*PlayerNum;

		for (j=0; < patchcount)
    	{
    	    paintPatchID = rmCreateArea("paint patch"+i+j);
			if (i == 0)
			{
	    	    rmSetAreaSize(paintPatchID, rmAreaTilesToFraction(20), rmAreaTilesToFraction(30));
				rmSetAreaMix(paintPatchID, paintMix5);
				rmAddAreaConstraint(paintPatchID, avoidCenter);
				rmAddAreaConstraint(paintPatchID, avoidPatch);
			}
			else
			{
    	    	rmSetAreaSize(paintPatchID, rmAreaTilesToFraction(55), rmAreaTilesToFraction(69));
				rmSetAreaMix(paintPatchID, paintMix8);
//				rmAddAreaConstraint(paintPatchID, avoidPatchFar);
				rmAddAreaConstraint(paintPatchID, avoidPatch);
			}
    	    rmAddAreaToClass(paintPatchID, classPatch);
    	    rmSetAreaCoherence(paintPatchID, 0);
    	    rmSetAreaWarnFailure(paintPatchID, false);
			rmSetAreaObeyWorldCircleConstraint(paintPatchID, false);
    	    rmSetAreaMinBlobs(paintPatchID, 1);
    	    rmSetAreaMaxBlobs(paintPatchID, 5);
    	    rmSetAreaMinBlobDistance(paintPatchID, 8);
    	    rmSetAreaMaxBlobDistance(paintPatchID, 16);
			rmAddAreaConstraint(paintPatchID, stayInPaint);
    	    rmBuildArea(paintPatchID); 
    	}
	}

	// Cliffs
	int classAvoidance = rmDefineClass("avoidance");

	int avoidTHisID=rmCreateArea("avoid this island");
	rmSetAreaSize(avoidTHisID, 0.10);
	rmSetAreaLocation(avoidTHisID, 0.45, 0.45);
	rmAddAreaInfluenceSegment(avoidTHisID, 0.30, 0.70, 0.70, 0.30);
	rmAddAreaInfluenceSegment(avoidTHisID, 0.45, 0.45, 0.65, 0.20);
	rmAddAreaInfluenceSegment(avoidTHisID, 0.45, 0.45, 0.20, 0.65);
	rmAddAreaInfluenceSegment(avoidTHisID, 0.45, 0.45, 0.55, 0.55);
	rmAddAreaInfluenceSegment(avoidTHisID, 0.37, 0.77, 0.77, 0.37);
	rmAddAreaToClass(avoidTHisID, classAvoidance);
//	rmSetAreaMix(avoidTHisID, forTesting);
	rmSetAreaCoherence(avoidTHisID, 1.00);
	rmBuildArea(avoidTHisID); 

	int cliffcount = 2;
	int brushcount = 2;
	if (rmGetIsKOTH() == true)
	{
		cliffcount = 2;
		brushcount = 2;
	}
	int stayNearCliff = -1;
	int playerResourceGroupID = -1;
	int playerResourcePatchID = -1;
	int stayInPlayerResourcePatch = -1;
	int playerresourcecount = 1;
	int stayInCliff = -1;
	int avoidRamp = -1;
	int cliffPaintID = -1;
	int cliffPatchID = -1;
	int cliffDecorID = -1;
	int randbrushcount1 = -1;
	int randbrushcount2 = -1;
	int randbrushcount3 = -1;
	int snowtreecount = 1.5*PlayerNum;
	int cliffForestPatchID = -1;
	int stayInCliffForestPatch = -1;
	int cliffForestTreeID = -1;
	int cliffNuggetID = -1;

	int seaAreaID = rmCreateArea("sea area");
	rmSetAreaSize(seaAreaID, 0.4);
	rmSetAreaCoherence(seaAreaID, 1.0);
	rmAddAreaConstraint(seaAreaID, avoidLandShort);
	rmSetAreaLocation(seaAreaID, 0.80, 0.80);
	rmAddAreaToClass(seaAreaID, classSea);
	rmBuildArea(seaAreaID);

	for (i= 0; < cliffcount)
	{
		if (TeamNum == 2)
		{
			if (i == 0)
			{
				if (leftTeam == 0)
					playerresourcecount = teamZeroCount;
				if (leftTeam == 1)
					playerresourcecount = teamOneCount;
			}
			else
			{
				if (rightTeam == 0)
					playerresourcecount = teamZeroCount;
				if (rightTeam == 1)
					playerresourcecount = teamOneCount;
			}
		}
		else
		{
			if (PlayerNum >= 3)
				playerresourcecount = 2;
			if (PlayerNum >= 5)
				playerresourcecount = 3;
			if (PlayerNum >= 7)
				playerresourcecount = 4;
		}

		int cliffID = rmCreateArea("cliff"+i);
		if (i <= 1)
			rmSetAreaSize(cliffID, 0.07);
		else
			rmSetAreaSize(cliffID, 0.03);
//		rmSetAreaReveal(cliffID, 01);
		rmSetAreaWarnFailure(cliffID, false);
		rmSetAreaObeyWorldCircleConstraint(cliffID, false);
		rmSetAreaCliffType(cliffID, mntType);
		rmSetAreaCliffPainting(cliffID, true, true, true, 0.5 , false); //  paintGround,  paintOutsideEdge,  paintSide,  minSideHeight,  paintInsideEdge
		rmSetAreaCliffHeight(cliffID, 7, 0.0, 0.8); 
		rmSetAreaCliffEdge(cliffID, 1, 1.00, 0.0, 0.30, 0); //0.30
		rmAddAreaCliffEdgeAvoidClass(cliffID, classAvoidance, 20);
		rmSetAreaCoherence(cliffID, 0.8);
		rmAddAreaToClass(cliffID, classCliff);
		rmAddAreaConstraint(cliffID, avoidWaterMin);
		//rmSetAreaBaseHeight(cliffID, 3);
		//rmSetAreaHeightBlend(cliffID, 2);
		rmAddAreaConstraint(cliffID, avoidCliffFar);
		rmAddAreaConstraint(cliffID, avoidNatives);
		rmAddAreaConstraint(cliffID, avoidPirateIslandsFar);
		//rmAddAreaConstraint(cliffID, cliffMaxHeight);
		if (i == 0)
		{
			rmSetAreaLocation(cliffID, 0.40, 0.80);
			rmAddAreaInfluenceSegment(cliffID, 0.65, 0.80, 0.15, 0.80);
		}
		else
		{
			rmSetAreaLocation(cliffID, 0.80, 0.40);
			rmAddAreaInfluenceSegment(cliffID, 0.80, 0.65, 0.80, 0.15);
		}
		rmSetAreaHeightBlend(cliffID, 1);
		rmSetAreaTerrainType(cliffID, "california\fakecalifgrassmix_cal");	// for testing
		rmBuildArea(cliffID);

		stayNearCliff = rmCreateAreaMaxDistanceConstraint("stay near cliff"+i, cliffID, 4);
		stayInCliff = rmCreateAreaMaxDistanceConstraint("stay in cliff"+i, cliffID, 0);
		avoidRamp = rmCreateCliffRampDistanceConstraint("avoid ramp"+i, cliffID, 8);

        cliffPaintID = rmCreateArea("cliff paint"+i);
        rmSetAreaWarnFailure(cliffPaintID, false);
		rmSetAreaObeyWorldCircleConstraint(cliffPaintID, true);
        rmSetAreaSize(cliffPaintID, 0.08);
		rmSetAreaMix(cliffPaintID, paintMix3);
        rmSetAreaCoherence(cliffPaintID, 1.00);
		rmAddAreaConstraint(cliffPaintID, stayNearCliff);
		rmBuildArea(cliffPaintID);

		if (i <= 1)
			patchcount = 8*PlayerNum;
		else
			patchcount = 4*PlayerNum;

		for (j=0; < patchcount)
    	{
    	    cliffPatchID = rmCreateArea("cliff patch"+i+j);
    	    rmSetAreaSize(cliffPatchID, rmAreaTilesToFraction(22), rmAreaTilesToFraction(33));
			rmSetAreaMix(cliffPatchID, paintMix2);
    	    rmAddAreaToClass(cliffPatchID, classPatch);
    	    rmSetAreaCoherence(cliffPatchID, 0);
    	    rmSetAreaWarnFailure(cliffPatchID, false);
			rmSetAreaObeyWorldCircleConstraint(cliffPatchID, false);
    	    rmSetAreaMinBlobs(cliffPatchID, 1);
    	    rmSetAreaMaxBlobs(cliffPatchID, 5);
    	    rmSetAreaMinBlobDistance(cliffPatchID, 8);
    	    rmSetAreaMaxBlobDistance(cliffPatchID, 16);
			rmAddAreaConstraint(cliffPatchID, avoidPatch);
			rmAddAreaConstraint(cliffPatchID, stayInCliff);
			rmAddAreaConstraint(cliffPatchID, avoidWater);
    	    rmBuildArea(cliffPatchID); 
    	}

		for (x=0; < playerresourcecount)
	    {
	        playerResourcePatchID = rmCreateArea("cliff forest patch"+i+x);
	        rmSetAreaWarnFailure(playerResourcePatchID, false);
			rmSetAreaObeyWorldCircleConstraint(playerResourcePatchID, false);
	        rmSetAreaSize(playerResourcePatchID, rmAreaTilesToFraction(123));
	        rmSetAreaMix(playerResourcePatchID, paintMix6);
	        rmSetAreaReveal(playerResourcePatchID, 01);
	        rmSetAreaCoherence(playerResourcePatchID, 0.69);
			rmSetAreaSmoothDistance(playerResourcePatchID, 5);
			rmAddAreaConstraint(playerResourcePatchID, stayInCliff);
			rmAddAreaConstraint(playerResourcePatchID, avoidRamp);
			rmAddAreaConstraint(playerResourcePatchID, avoidForest);
			rmAddAreaConstraint(playerResourcePatchID, avoidWater);
			rmAddAreaConstraint(playerResourcePatchID, avoidImpassableLandFar);
			rmAddAreaConstraint(playerResourcePatchID, avoidStartingResourcesFar);
			rmBuildArea(playerResourcePatchID);

			stayInPlayerResourcePatch = rmCreateAreaMaxDistanceConstraint("stay in player res patch"+i+x, playerResourcePatchID, 0);

			for (y=0; < 1)
			{
				playerResourceGroupID = rmCreateObjectDef("player resource group"+i+x+y);
				rmAddObjectDefItem(playerResourceGroupID, "deMineCoalBuildable", 2, 10);
				rmAddObjectDefItem(playerResourceGroupID, treeType4, 4, 10);
				rmAddObjectDefItem(playerResourceGroupID, huntType, 6, 10);
				rmSetObjectDefMinDistance(playerResourceGroupID, rmXFractionToMeters(0.00));
				rmSetObjectDefMaxDistance(playerResourceGroupID, rmXFractionToMeters(0.50));
				rmAddObjectDefToClass(playerResourceGroupID, classStartingResource);
				rmAddObjectDefToClass(playerResourceGroupID, classGold);
				rmAddObjectDefConstraint(playerResourceGroupID, avoidImpassableLand);
				rmAddObjectDefConstraint(playerResourceGroupID, avoidWater);
				rmAddObjectDefConstraint(playerResourceGroupID, stayInPlayerResourcePatch);
				rmSetObjectDefCreateHerd(playerResourceGroupID, false);
				rmSetObjectDefAllowOverlap(playerResourceGroupID, true);
				if (i == 0)
					rmPlaceObjectDefAtLoc(playerResourceGroupID, 0, 0.40, 0.80, 1);
				else
					rmPlaceObjectDefAtLoc(playerResourceGroupID, 0, 0.80, 0.40, 1);
			}
		}

		for (q= 0; < brushcount)
		{
			randbrushcount1 = rmRandInt(00,05);
			randbrushcount2 = rmRandInt(05,10);
			randbrushcount3 = rmRandInt(15,15);

			cliffDecorID = rmCreateObjectDef("cliff decor"+i+q);
			rmAddObjectDefItem(cliffDecorID, brushType1, randbrushcount1, 10);
			rmAddObjectDefItem(cliffDecorID, brushType2, randbrushcount2-randbrushcount1, 10);
			rmAddObjectDefItem(cliffDecorID, brushType3, randbrushcount3-(randbrushcount2+randbrushcount1), 10);
			rmAddObjectDefItem(cliffDecorID, "PropBlizzard", 1, 0);
			rmSetObjectDefMinDistance(cliffDecorID, rmXFractionToMeters(0.00));
			rmSetObjectDefMaxDistance(cliffDecorID, rmXFractionToMeters(0.50));
			rmAddObjectDefToClass(cliffDecorID, classForest);
			rmAddObjectDefToClass(cliffDecorID, classProp);
			rmAddObjectDefConstraint(cliffDecorID, avoidProp);
			rmAddObjectDefConstraint(cliffDecorID, stayInCliff);
			rmAddObjectDefConstraint(cliffDecorID, avoidNatives);
			rmAddObjectDefConstraint(cliffDecorID, avoidRamp);
			rmAddObjectDefConstraint(cliffDecorID, avoidWater);
			if (i <= 1)
				rmPlaceObjectDefAtLoc(cliffDecorID, 0, 0.50, 0.50, 5);
			else
				rmPlaceObjectDefAtLoc(cliffDecorID, 0, 0.50, 0.50, 2);
		}

		for (n=0; < snowtreecount)
	    {
	        cliffForestPatchID = rmCreateArea("cliff forest patch"+i+n);
	        rmSetAreaWarnFailure(cliffForestPatchID, false);
			rmSetAreaObeyWorldCircleConstraint(cliffForestPatchID, false);
	        rmSetAreaSize(cliffForestPatchID, rmAreaTilesToFraction(44));
	        rmSetAreaMix(cliffForestPatchID, paintMix6);
	        rmSetAreaCoherence(cliffForestPatchID, 0.2);
			rmSetAreaSmoothDistance(cliffForestPatchID, 5);
			rmAddAreaConstraint(cliffForestPatchID, stayInCliff);
			rmAddAreaConstraint(cliffForestPatchID, avoidRamp);
			rmAddAreaConstraint(cliffForestPatchID, avoidForest);
			rmAddAreaConstraint(cliffForestPatchID, avoidGoldShort);
			rmAddAreaConstraint(cliffForestPatchID, avoidWater);
			rmAddAreaConstraint(cliffForestPatchID, avoidImpassableLandShort);
			rmAddAreaConstraint(cliffForestPatchID, avoidStartingResources);
			rmBuildArea(cliffForestPatchID);

			stayInCliffForestPatch = rmCreateAreaMaxDistanceConstraint("stay in cliff forest patch"+i+n, cliffForestPatchID, 0);

			for (p=0; < 2)
			{
				cliffForestTreeID = rmCreateObjectDef("cliff trees"+i+n+p);
				rmAddObjectDefItem(cliffForestTreeID, brushType1, 6, 4);
				rmAddObjectDefItem(cliffForestTreeID, treeType4, 2, 4);
				rmSetObjectDefMinDistance(cliffForestTreeID, rmXFractionToMeters(0.00));
				rmSetObjectDefMaxDistance(cliffForestTreeID, rmXFractionToMeters(0.48));
				rmAddObjectDefToClass(cliffForestTreeID, classForest);
				rmAddObjectDefConstraint(cliffForestTreeID, stayInCliffForestPatch);
				rmAddObjectDefConstraint(cliffForestTreeID, avoidWater);
				rmAddObjectDefConstraint(cliffForestTreeID, avoidImpassableLand);
				rmPlaceObjectDefAtLoc(cliffForestTreeID, 0, 0.50, 0.50, 1);
			}
	    }

		for (t=0; < PlayerNum)
		{
			cliffNuggetID = rmCreateObjectDef("nugget cliff"+i+t); 
			rmAddObjectDefItem(cliffNuggetID, "Nugget", 1, 0);
			rmSetObjectDefMinDistance(cliffNuggetID, 0);
			rmSetObjectDefMaxDistance(cliffNuggetID, rmXFractionToMeters(0.5));
			rmSetNuggetDifficulty(1,1);
			rmAddObjectDefConstraint(cliffNuggetID, stayInCliff);
			rmAddObjectDefConstraint(cliffNuggetID, avoidNuggetVeryFar);
			rmAddObjectDefConstraint(cliffNuggetID, avoidImpassableLandShort); 
			rmAddObjectDefConstraint(cliffNuggetID, avoidWater); 
			rmAddObjectDefConstraint(cliffNuggetID, avoidStartingResourcesShort); 
			rmPlaceObjectDefAtLoc(cliffNuggetID, 0, 0.50, 0.50, 1);
		}
	}

	// Map loading
	rmSetStatusText("", 0.30);

	// ---------------------------------------------------
	// ******************** Volcano **********************
	// ---------------------------------------------------

	float volcPlaceX = 0.42;
	float volcPlaceY = 0.42;

	// Lava flows
	int lavaflowID = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(lavaflowID);
	rmAddTradeRouteWaypoint(lavaflowID, volcPlaceX, volcPlaceY);
	rmAddTradeRouteWaypoint(lavaflowID, volcPlaceX+rmXTilesToFraction(15), volcPlaceY);

	bool placedLavaflowID = rmBuildTradeRoute(lavaflowID, "lava_flow");

	int lavaflowID2 = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(lavaflowID2);
	rmAddTradeRouteWaypoint(lavaflowID2, volcPlaceX, volcPlaceY);
	rmAddTradeRouteWaypoint(lavaflowID2, volcPlaceX, volcPlaceY+rmXTilesToFraction(15));

	bool placedLavaflowID2 = rmBuildTradeRoute(lavaflowID2, "lava_flow");

	int lavaflowID3 = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(lavaflowID3);
	rmAddTradeRouteWaypoint(lavaflowID3, volcPlaceX, volcPlaceY);
	rmAddTradeRouteWaypoint(lavaflowID3, volcPlaceX-rmXTilesToFraction(15), volcPlaceY);

	bool placedLavaflowID3 = rmBuildTradeRoute(lavaflowID3, "lava_flow");

	int lavaflowID4 = rmCreateTradeRoute();
	rmSetObjectDefTradeRouteID(lavaflowID4);
	rmAddTradeRouteWaypoint(lavaflowID4, volcPlaceX, volcPlaceY);
	rmAddTradeRouteWaypoint(lavaflowID4, volcPlaceX, volcPlaceY-rmXTilesToFraction(15));

	bool placedLavaflowID4 = rmBuildTradeRoute(lavaflowID4, "lava_flow");

	int volcanoX=rmCreateObjectDef("volcano X coordinate");
	rmAddObjectDefItem(volcanoX, "zpSPCWaterSpawnPoint", 1, 0);
	rmSetObjectDefAllowOverlap(volcanoX, true);

	int volcanoZ=rmCreateObjectDef("volcano Z coordinate");
	rmAddObjectDefItem(volcanoZ, "zpSPCWaterSpawnPoint", 1, 0);
	rmSetObjectDefAllowOverlap(volcanoZ, true);

	vector coordinateLoc1  = rmGetTradeRouteWayPoint(lavaflowID, 0.1);
	vector coordinateLoc2  = rmGetTradeRouteWayPoint(lavaflowID2, 0.1);
	rmPlaceObjectDefAtPoint(volcanoX, 0, coordinateLoc1);
	rmPlaceObjectDefAtPoint(volcanoZ, 0, coordinateLoc2);

	vector volcanoVectorX = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(volcanoZ, 0));
	vector volcanoVectorZ = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(volcanoX, 0));

	float volcLocX = rmXMetersToFraction(xsVectorGetX(volcanoVectorX));
	float volcLocY = rmZMetersToFraction(xsVectorGetZ(volcanoVectorZ));

	// Constraints to keep mines in orientation to volcano
	int staySouthClose = rmCreatePieConstraint("stay south close", volcLocX, volcLocY, rmXFractionToMeters(0.01), rmXFractionToMeters(0.15), rmDegreesToRadians(150), rmDegreesToRadians(300));
	int stayNorthClose = rmCreatePieConstraint("stay north close", volcLocX, volcLocY, rmXFractionToMeters(0.01), rmXFractionToMeters(0.15), rmDegreesToRadians(330), rmDegreesToRadians(120));
	int stayWestClose = rmCreatePieConstraint("stay west close", volcLocX, volcLocY, rmXFractionToMeters(0.01), rmXFractionToMeters(0.15), rmDegreesToRadians(240), rmDegreesToRadians(030));
	int stayEastClose = rmCreatePieConstraint("stay east close", volcLocX, volcLocY, rmXFractionToMeters(0.01), rmXFractionToMeters(0.15), rmDegreesToRadians(060), rmDegreesToRadians(210));
	int staySouthWMed = rmCreatePieConstraint("stay south west med", volcLocX, volcLocY, rmXFractionToMeters(0.15), rmXFractionToMeters(0.30), rmDegreesToRadians(230), rmDegreesToRadians(315));
	int staySouthEMed = rmCreatePieConstraint("stay south east med", volcLocX, volcLocY, rmXFractionToMeters(0.15), rmXFractionToMeters(0.30), rmDegreesToRadians(135), rmDegreesToRadians(220));
	int staySouthMed = rmCreatePieConstraint("stay south med", volcLocX, volcLocY, rmXFractionToMeters(0.15), rmXFractionToMeters(0.30), rmDegreesToRadians(150), rmDegreesToRadians(300));
	int stayNorthMed = rmCreatePieConstraint("stay north med", volcLocX, volcLocY, rmXFractionToMeters(0.15), rmXFractionToMeters(0.30), rmDegreesToRadians(330), rmDegreesToRadians(120));
	int stayWestMed = rmCreatePieConstraint("stay west med", volcLocX, volcLocY, rmXFractionToMeters(0.15), rmXFractionToMeters(0.30), rmDegreesToRadians(240), rmDegreesToRadians(030));
	int stayEastMed = rmCreatePieConstraint("stay east med", volcLocX, volcLocY, rmXFractionToMeters(0.15), rmXFractionToMeters(0.30), rmDegreesToRadians(060), rmDegreesToRadians(210));

	// Build the volcano
	int volcanoID = -1;
	int volcanoTerrainID = -1;

	for (i= 0; < 22)
	{
		volcanoID = rmCreateArea("building the volcano"+i);
		if (i <= 1)			// base cliffs
		{
			if (i == 0)		// level 1
			{
				if (cNumberNonGaiaPlayers <= 2)
					rmSetAreaSize(volcanoID, rmAreaTilesToFraction(2000));
				else
					rmSetAreaSize(volcanoID, rmAreaTilesToFraction(2500));
				rmSetAreaCoherence(volcanoID, .6);
				rmSetAreaCliffType(volcanoID, volcCliffLow);
				rmSetAreaCliffEdge(volcanoID, 4, 0.16, 0.0, 0.0, 2); 
				rmSetAreaCliffHeight(volcanoID, 3, 0.1, 0.5);
			}
			else			// level 2
			{
				rmSetAreaSize(volcanoID, rmAreaTilesToFraction(1600));
				rmSetAreaCoherence(volcanoID, .7);
				rmSetAreaCliffType(volcanoID, volcCliffLow);
				rmAddAreaConstraint(volcanoID, cliffAvoidTradeRoute);
				rmSetAreaTerrainType(volcanoID, volcTerrainLow);
				rmSetAreaCliffEdge(volcanoID, 1, 1.00, 0.0, 0.0, 2); 
				rmSetAreaCliffHeight(volcanoID, 4, 0.1, 0.5);
				rmAddAreaToClass(volcanoID, classCliff);
			}
			rmSetAreaHeightBlend(volcanoID, 0);
			rmSetAreaElevationVariation(volcanoID, 4);
			rmSetAreaCliffPainting(volcanoID, true, true, true, 1.5, true);
			rmSetAreaLocation(volcanoID, volcLocX, volcLocY);
		}
		else if (i == 2)	// level 3
		{
			rmSetAreaSize(volcanoID, rmAreaTilesToFraction(900));
			rmSetAreaTerrainType(volcanoID, volcTerrainLow);
			rmSetAreaBaseHeight(volcanoID, 10);
			rmSetAreaHeightBlend(volcanoID, 2);
			rmSetAreaSmoothDistance(volcanoID, 50);
			rmSetAreaCoherence(volcanoID, .7);
			rmSetAreaLocation(volcanoID, volcLocX, volcLocY);
		}
		else if (i <= 6)	// level 3 cliffs
		{
			rmSetAreaSize(volcanoID, rmAreaTilesToFraction(160));
			rmSetAreaElevationVariation(volcanoID, 5);
			rmSetAreaCoherence(volcanoID, .6);
			rmSetAreaHeightBlend(volcanoID, 0);
			rmSetAreaCliffType(volcanoID, volcCliffMid);
			rmAddAreaConstraint(volcanoID, cliffAvoidTradeRoute);
			rmSetAreaTerrainType(volcanoID, volcTerrainLow);
			rmSetAreaCliffEdge(volcanoID, 1, 1.00, 0.0, 0.0, 2); 
			rmSetAreaCliffPainting(volcanoID, true, true, true, 1.5, true);
			rmSetAreaCliffHeight(volcanoID, 3, 0.1, 0.5);
			if (i == 3)
				rmSetAreaLocation(volcanoID, volcLocX+rmXTilesToFraction(7), volcLocY-rmXTilesToFraction(7));
			else if (i == 4)
				rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(7), volcLocY-rmXTilesToFraction(7));
			else if (i == 5)
				rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(7), volcLocY+rmXTilesToFraction(7));
			else
				rmSetAreaLocation(volcanoID, volcLocX+rmXTilesToFraction(7), volcLocY+rmXTilesToFraction(7));
		}
		else if (i == 7)	// level 4
		{
			rmSetAreaSize(volcanoID, rmAreaTilesToFraction(550));
			rmSetAreaLocation(volcanoID, volcLocX, volcLocY);
			rmSetAreaTerrainType(volcanoID, volcTerrainLow);
			rmSetAreaBaseHeight(volcanoID, 14);
			rmSetAreaHeightBlend(volcanoID, 2);
			rmSetAreaSmoothDistance(volcanoID, 40);
			rmSetAreaCoherence(volcanoID, .8);
		}
		else if (i <= 11)	// level 4 cliffs
		{
			rmSetAreaSize(volcanoID, rmAreaTilesToFraction(50));
			rmSetAreaElevationVariation(volcanoID, 5);
			rmSetAreaCoherence(volcanoID, .6);
			rmSetAreaHeightBlend(volcanoID, 0);
			rmSetAreaCliffType(volcanoID, volcCliffHigh);
			rmAddAreaConstraint(volcanoID, cliffAvoidTradeRoute);
			rmSetAreaTerrainType(volcanoID, volcTerrainLow);
			rmSetAreaCliffEdge(volcanoID, 1, 1.00, 0.0, 0.0, 2); 
			rmSetAreaCliffPainting(volcanoID, true, true, true, 1.5, true);
			rmSetAreaCliffHeight(volcanoID, 3, 0.1, 0.5);
			if (i == 8)
				rmSetAreaLocation(volcanoID, volcLocX+rmXTilesToFraction(7), volcLocY-rmXTilesToFraction(7));
			else if (i == 9)
				rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(7), volcLocY-rmXTilesToFraction(7));
			else if (i == 10)
				rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(7), volcLocY+rmXTilesToFraction(7));
			else
				rmSetAreaLocation(volcanoID, volcLocX+rmXTilesToFraction(7), volcLocY+rmXTilesToFraction(7));
		}
		else if (i == 12)	// level 5
		{
			rmSetAreaSize(volcanoID, rmAreaTilesToFraction(450));
			rmSetAreaLocation(volcanoID, volcLocX, volcLocY);
			rmSetAreaTerrainType(volcanoID, volcTerrainLow);
			rmSetAreaBaseHeight(volcanoID, 18);
			rmSetAreaSmoothDistance(volcanoID, 40);
			rmSetAreaHeightBlend(volcanoID, 2);
			rmSetAreaCoherence(volcanoID, .8);
		}
		else if (i <= 16)	// peak
		{
			rmSetAreaSize(volcanoID, rmAreaTilesToFraction(20));
			rmSetAreaElevationVariation(volcanoID, 5);
			rmSetAreaCoherence(volcanoID, .6);
			rmSetAreaHeightBlend(volcanoID, 0);
			rmSetAreaCliffType(volcanoID, volcCliffHigh);
			rmAddAreaConstraint(volcanoID, cliffAvoidTradeRoute);
			rmSetAreaTerrainType(volcanoID, volcTerrainLow);
			rmSetAreaCliffEdge(volcanoID, 1, 1.00, 0.0, 0.0, 2); 
			rmSetAreaCliffPainting(volcanoID, true, true, true, 1.5, true);
			rmSetAreaCliffHeight(volcanoID, 2, 0.1, 0.5);
			rmSetAreaElevationVariation(volcanoID, 3);
			if (i == 13)
				rmSetAreaLocation(volcanoID, volcLocX+rmXTilesToFraction(5), volcLocY-rmXTilesToFraction(5));
			else if (i == 14)
				rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(5), volcLocY-rmXTilesToFraction(5));
			else if (i == 15)
				rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(5), volcLocY+rmXTilesToFraction(5));
			else
				rmSetAreaLocation(volcanoID, volcLocX+rmXTilesToFraction(5), volcLocY+rmXTilesToFraction(5));
		}
		else if (i <= 20)	// dip
		{
			if (i == 17)
			{
				rmSetAreaSize(volcanoID, rmAreaTilesToFraction(120));
				rmSetAreaTerrainType(volcanoID, volcTerrainCrater);
				rmSetAreaBaseHeight(volcanoID, 22);
				rmSetAreaCoherence(volcanoID, 0.9);
			}
			else if (i == 18)
			{
				rmSetAreaSize(volcanoID, rmAreaTilesToFraction(230));
				rmSetAreaTerrainType(volcanoID, volcTerrainCrater);
				rmSetAreaCoherence(volcanoID, 1);
			}
			else if (i == 19)
			{
				rmSetAreaSize(volcanoID, rmAreaTilesToFraction(50));
				rmSetAreaCliffType(volcanoID, volcCliffCrater);
				rmSetAreaCliffPainting(volcanoID, false, true, true, 1.5, false);
				rmSetAreaCliffHeight(volcanoID, -5, 0.1, 0.5);
				rmSetAreaCliffEdge(volcanoID, 1, 1.0, 0.0, 1.0, 0);
				rmSetAreaCoherence(volcanoID, 1);
			}
			else
			{
				rmSetAreaSize(volcanoID, rmAreaTilesToFraction(50));
				rmSetAreaTerrainType(volcanoID, volcTerrainCraterPass);
				rmSetAreaCoherence(volcanoID, 1);
			}
			rmSetAreaLocation(volcanoID, volcLocX, volcLocY);
		}
		else	// lava
		{
			rmSetAreaSize(volcanoID, rmAreaTilesToFraction(25));
			rmSetAreaLocation(volcanoID, volcLocX-rmXTilesToFraction(1), volcLocY);
			rmSetAreaTerrainType(volcanoID, volcTerrainLava);
			rmSetAreaCoherence(volcanoID, 1);
		}
		rmAddAreaToClass(volcanoID, classPlateau);
		rmSetAreaWarnFailure(volcanoID, false);
		rmSetAreaObeyWorldCircleConstraint(volcanoID, false);
		rmBuildArea(volcanoID);

		volcanoTerrainID=rmCreateArea("painting the volcano"+i); 
		if (i == 0)
		{
			rmSetAreaSize(volcanoTerrainID, 0.035);
			rmSetAreaCoherence(volcanoTerrainID, 0.6);
			rmSetAreaMix(volcanoTerrainID, paintMix4);
		}
		else if (i == 1)
		{
			rmSetAreaSize(volcanoTerrainID, rmAreaTilesToFraction(500));
			rmSetAreaCoherence(volcanoTerrainID, 1);
			rmSetAreaMix(volcanoTerrainID, paintMix4);
		}
		else if (i == 2)
		{
			rmSetAreaSize(volcanoTerrainID, rmAreaTilesToFraction(700));
			rmSetAreaCoherence(volcanoTerrainID, 0.8);
			rmSetAreaTerrainType(volcanoTerrainID, volcTerrainHigh);
		}
		rmSetAreaLocation(volcanoTerrainID, volcLocX, volcLocY);
		rmSetAreaObeyWorldCircleConstraint(volcanoTerrainID, false);
		if (i <= 2)
			rmBuildArea(volcanoTerrainID);
	}

	// Volcano crater
	int volcanoCraterID = rmCreateGrouping("crater", "volcano_crater_noground");
	rmPlaceGroupingAtLoc(volcanoCraterID, 1, volcLocX-rmXTilesToFraction(1), volcLocY, 1);

	int volcanoControllerID = rmCreateObjectDef("volcano controller 1");
	rmAddObjectDefItem(volcanoControllerID, "zpSPCWaterSpawnPoint", 1, 0);
	rmPlaceObjectDefAtLoc(volcanoControllerID, 0, volcLocX, volcLocY);

	int volcanoAvoider = rmCreateObjectDef("ai avoider"); 
	if (cNumberNonGaiaPlayers <= 2)
	    rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderS", 1, 0);
	else if(cNumberNonGaiaPlayers <= 4)
		rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderM", 1, 0);
	else if(cNumberNonGaiaPlayers <= 6)
		rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderL", 1, 0);
	else
		rmAddObjectDefItem(volcanoAvoider, "zpVolcanoAvoiderXL", 1, 0);
	rmPlaceObjectDefAtLoc(volcanoAvoider, 0, volcLocX, volcLocY);

	//King's island
	if (rmGetIsKOTH() == true)
	{
		float xLoc = 0.3;
		float yLoc = 0.3;
		float walk = 0.00;

		int kingIslandID = rmCreateArea("king's island");
		rmSetAreaSize(kingIslandID, 0.01);
		rmSetAreaLocation(kingIslandID, xLoc, yLoc);
		rmSetAreaMix(kingIslandID, paintMix2);
		rmSetAreaReveal(kingIslandID, 01);
		rmAddAreaToClass(kingIslandID, classIsland);
		rmSetAreaBaseHeight(kingIslandID, 2);
		rmSetAreaCoherence(kingIslandID, 1);
		rmBuildArea(kingIslandID); 
	
		// Place king's hill
		ypKingsHillPlacer(xLoc, yLoc, walk, 0);
		rmEchoInfo("XLOC = "+xLoc);
		rmEchoInfo("XLOC = "+yLoc);
	}

	int avoidKOTH = rmCreateAreaDistanceConstraint("avoid KOTH", kingIslandID, 6);
	int stayKOTH = rmCreateAreaMaxDistanceConstraint("stay in KOTH", kingIslandID, 0);
	
	// Map loading
	rmSetStatusText("", 0.40);

	// ---------------------------------------------------
	// ***************** Starting Units ******************
	// ---------------------------------------------------

	int startingUnits = rmCreateStartingUnitsObjectDef(5);

	int dinghyID = rmCreateObjectDef("player TC");
	rmAddObjectDefItem(dinghyID, startShipType1, 1, 0);
	rmAddObjectDefToClass(dinghyID, classStartingResource);
	rmSetObjectDefGarrisonStartingUnits(dinghyID, true);
	rmSetObjectDefMinDistance(dinghyID, 0);
	rmSetObjectDefMaxDistance(dinghyID, 0);

	// Place starting objects
	for(i=1; <numPlayer)
	{
		rmPlaceObjectDefAtLoc(dinghyID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(dinghyID, i));

		rmAddPlayerResource(i, "wood", 200);
		rmAddPlayerResource(i, "XP", 100);

		int startingShipID=rmCreateObjectDef("starting transport ship"+i);
		rmAddObjectDefItem(startingShipID, startShipType2, 1, 5);
		rmAddObjectDefItem(startingShipID, "CoveredWagon", 1, 0);
		rmAddObjectDefItem(startingShipID, "deDockWagon", 1, 0);
		if (rmGetPlayerCiv(i) == rmGetCivID("Japanese"))
			rmAddObjectDefItem(startingShipID, "ypBerryWagon1", 1, 0);
		rmSetObjectDefGarrisonStartingUnits(startingShipID, true);
		rmSetObjectDefGarrisonSecondaryUnits(startingShipID, true);
		rmPlaceObjectDefAtLoc(startingShipID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		int waterFlag = rmCreateObjectDef("HC water flag "+i);
		rmAddObjectDefItem(waterFlag, "HomeCityWaterSpawnFlag", 1, 0);
		rmSetObjectDefMinDistance(waterFlag, 1);
		rmSetObjectDefMaxDistance(waterFlag, 8);
		rmPlaceObjectDefAtLoc(waterFlag, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i), 1);
	}

	// ---------------------------------------------------
	// ***************** Place villages ******************
	// ---------------------------------------------------

	// Pirates
	for (i=1; <= numPirates)
	{
		int pirateTerrainID = rmCreateArea ("pirate_terrain"+i);
		rmSetAreaSize(pirateTerrainID, rmAreaTilesToFraction(400));
		rmSetAreaMix(pirateTerrainID, paintMix2);
		rmSetAreaCoherence(pirateTerrainID, 1);
		rmSetAreaSmoothDistance(pirateTerrainID, 15);
		rmSetAreaBaseHeight(pirateTerrainID, 2);
		rmAddAreaToClass(pirateTerrainID, classPirateIsland);
		if (i==1)
		{
			rmSetAreaLocation(pirateTerrainID, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc1))-rmXTilesToFraction(6), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc1))-rmZTilesToFraction(6));
		}
		if (i==2)
		{
			rmSetAreaLocation(pirateTerrainID, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc2))+rmXTilesToFraction(10), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc2)));
		}
		if (i==3)
		{
			rmSetAreaLocation(pirateTerrainID, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc3))+rmZTilesToFraction(10));
		}
		rmBuildArea(pirateTerrainID);
	}

	// Inventors
	int inventorVariation = rmRandInt(1, 2);
	int inventorsVillageID = rmCreateGrouping("inventor city", "scientist_lab0"+inventorVariation);
	rmAddGroupingToClass(inventorsVillageID, classNative);
	rmPlaceGroupingAtLoc(inventorsVillageID, 0, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc1)), 1);
	
	int inventorwaterflagID1 = rmCreateObjectDef("inventor water flag 1");
	rmAddObjectDefItem(inventorwaterflagID1, "zpNativeWaterSpawnFlag1", 1, 1);
	rmAddClosestPointConstraint(flagLand);
	rmAddClosestPointConstraint(avoidMainIsland);

	vector closeToVillage1 = rmFindClosestPointVector(pirateControllerLoc1, rmXFractionToMeters(1));
	rmPlaceObjectDefAtLoc(inventorwaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

	rmClearClosestPointConstraints();

	int pirateportID1 = -1;
	pirateportID1 = rmCreateGrouping("pirate port 1", "Platform_Universal");
	rmAddClosestPointConstraint(portOnShore);

	vector closeToVillage1a = rmFindClosestPointVector(pirateControllerLoc1, rmXFractionToMeters(1));
	rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));

	rmClearClosestPointConstraints();

	// Pirates 1
	int pirateVariation = rmRandInt(7, 8);
	int piratesVillageID1 = rmCreateGrouping("pirate city", "Pirate_Village0"+pirateVariation);
	rmAddGroupingToClass(piratesVillageID1, classNative);
	rmPlaceGroupingAtLoc(piratesVillageID1, 0, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc2)), 1);
	
	int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
	rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1);
	rmAddClosestPointConstraint(flagLand);
	rmAddClosestPointConstraint(avoidMainIsland);

	vector closeToVillage2 = rmFindClosestPointVector(pirateControllerLoc2, rmXFractionToMeters(1));
	rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2)));

	rmClearClosestPointConstraints();

	int pirateportID2 = -1;
	pirateportID2 = rmCreateGrouping("pirate port 2", "Platform_Universal");
	rmAddClosestPointConstraint(portOnShore);

	vector closeToVillage2a = rmFindClosestPointVector(pirateControllerLoc2, rmXFractionToMeters(1));
	rmPlaceGroupingAtLoc(pirateportID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage2a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage2a)));

	rmClearClosestPointConstraints();

	// Pirates 2
	int pirateVariation2 = 9-pirateVariation;
	int piratesVillageID2 = rmCreateGrouping("pirate city 2", "Pirate_Village0"+pirateVariation2);
	rmAddGroupingToClass(piratesVillageID2, classNative);
	rmPlaceGroupingAtLoc(piratesVillageID2, 0, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc3)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc3)), 1);
	
	int piratewaterflagID2 = rmCreateObjectDef("pirate water flag 2");
	rmAddObjectDefItem(piratewaterflagID2, "zpPirateWaterSpawnFlag2", 1, 1);
	rmAddClosestPointConstraint(flagLand);
	rmAddClosestPointConstraint(avoidMainIsland);

	vector closeToVillage3 = rmFindClosestPointVector(pirateControllerLoc3, rmXFractionToMeters(1));
	rmPlaceObjectDefAtLoc(piratewaterflagID2, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3)));

	rmClearClosestPointConstraints();

	int pirateportID3 = -1;
	pirateportID3 = rmCreateGrouping("pirate port 3", "Platform_Universal");
	rmAddClosestPointConstraint(portOnShore);

	vector closeToVillage3a = rmFindClosestPointVector(pirateControllerLoc3, rmXFractionToMeters(1));
	rmPlaceGroupingAtLoc(pirateportID3, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage3a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage3a)));

	rmClearClosestPointConstraints();

	// Map loading
	rmSetStatusText("", 0.50);

	// ---------------------------------------------------
	// **************** Island resources *****************
	// ---------------------------------------------------

	// Quartz mines 
	int crystalcount = 2+PlayerNum;  
		
	for(i=0; < crystalcount)
	{
		int quartzMineID = rmCreateObjectDef("quartz mine"+i);
		rmAddObjectDefItem(quartzMineID, "zpQuarzmine", 1, 0);
		rmSetObjectDefMinDistance(quartzMineID, rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(quartzMineID, rmXFractionToMeters(0.45));
		rmAddObjectDefToClass(quartzMineID, classGold);
		rmAddObjectDefConstraint(quartzMineID, avoidGold);
		rmAddObjectDefConstraint(quartzMineID, avoidWater);
		rmAddObjectDefConstraint(quartzMineID, avoidCliff);
		rmAddObjectDefConstraint(quartzMineID, avoidPlateau);
		rmAddObjectDefConstraint(quartzMineID, avoidImpassableLand);
		rmAddObjectDefConstraint(quartzMineID, avoidNativesShort);
		if (i < crystalcount/2)
			rmAddObjectDefConstraint(quartzMineID, stayWestClose);
		else
			rmAddObjectDefConstraint(quartzMineID, stayEastClose);
		rmPlaceObjectDefAtLoc(quartzMineID, 0, 0.50, 0.50);
	}

	// Gold mines 
	int goldcount = 2+PlayerNum;  
		
	for(i=0; < goldcount)
	{
		int goldMineID = rmCreateObjectDef("gold mine"+i);
		rmAddObjectDefItem(goldMineID, "MineGold", 1, 0);
		rmSetObjectDefMinDistance(goldMineID, rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(goldMineID, rmXFractionToMeters(0.45));
		rmAddObjectDefToClass(goldMineID, classGold);
		rmAddObjectDefConstraint(goldMineID, avoidGoldFar);
		rmAddObjectDefConstraint(goldMineID, avoidWater);
		rmAddObjectDefConstraint(goldMineID, avoidCliff);
		rmAddObjectDefConstraint(goldMineID, avoidPlateau);
		rmAddObjectDefConstraint(goldMineID, avoidImpassableLand);
		rmAddObjectDefConstraint(goldMineID, avoidNatives);
		if (i < goldcount/2)
			rmAddObjectDefConstraint(goldMineID, staySouthWMed);
		else
			rmAddObjectDefConstraint(goldMineID, staySouthEMed);
		rmPlaceObjectDefAtLoc(goldMineID, 0, 0.50, 0.50);
	}

	// Shipwrecks 
	int shipcount = 4+PlayerNum;  
		
	for(i=0; < shipcount)
	{
		int shipwreckID = rmCreateObjectDef("shipwreck"+i);
		rmAddObjectDefItem(shipwreckID, "zpShipwreckWoodLand", 1, 0);
		rmSetObjectDefMinDistance(shipwreckID, rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(shipwreckID, rmXFractionToMeters(0.45));
		rmAddObjectDefToClass(shipwreckID, classForest);
		rmAddObjectDefConstraint(shipwreckID, avoidForestFar);
		rmAddObjectDefConstraint(shipwreckID, avoidGoldMin);
//		rmAddObjectDefConstraint(shipwreckID, avoidWaterMin);
		rmAddObjectDefConstraint(shipwreckID, stayNearWater);
		rmAddObjectDefConstraint(shipwreckID, avoidCliff);
		rmAddObjectDefConstraint(shipwreckID, avoidPlateau);
//		rmAddObjectDefConstraint(shipwreckID, avoidImpassableLandShort);
		rmAddObjectDefConstraint(shipwreckID, avoidNativesShort);
		rmAddObjectDefConstraint(shipwreckID, avoidPirateIslands);
		if (i <= 1)
			rmAddObjectDefConstraint(shipwreckID, stayN);
		else
			rmAddObjectDefConstraint(shipwreckID, staySouthShore);
		rmPlaceObjectDefAtLoc(shipwreckID, 0, 0.50, 0.50);
	}
		
	// Map loading
	rmSetStatusText("", 0.60);

	// Main forest patches
	int forestcount = 5*PlayerNum;
	int forestPatchID = -1;
	int stayInForestPatch = -1;
	int forestTreeID = -1;
	int randtreecount1 = -1;
	int randtreecount2 = -1;
	int randtreecount3 = -1;
	int randtreecount4 = -1;

	for (i=0; < forestcount)
    {
        forestPatchID = rmCreateArea("main forest patch"+i);
        rmSetAreaWarnFailure(forestPatchID, false);
		rmSetAreaObeyWorldCircleConstraint(forestPatchID, false);
        rmSetAreaSize(forestPatchID, rmAreaTilesToFraction(64));
        rmSetAreaMix(forestPatchID, paintMix7);
        rmSetAreaCoherence(forestPatchID, 0.2);
		rmSetAreaSmoothDistance(forestPatchID, 5);
		rmAddAreaConstraint(forestPatchID, avoidPlateau);
		rmAddAreaConstraint(forestPatchID, avoidNatives);
		rmAddAreaConstraint(forestPatchID, avoidForest);
		rmAddAreaConstraint(forestPatchID, avoidGoldMin);
		rmAddAreaConstraint(forestPatchID, avoidCliffFar);
		rmAddAreaConstraint(forestPatchID, avoidImpassableLandShort);
		rmAddAreaConstraint(forestPatchID, avoidWaterFar);
		if (i < forestcount/4)
			rmAddAreaConstraint(forestPatchID, staySouthMed);
		else if (i < forestcount/2)
			rmAddAreaConstraint(forestPatchID, stayNorthMed);
		else if (i < 3*forestcount/4)
			rmAddAreaConstraint(forestPatchID, stayEastMed);
		else
			rmAddAreaConstraint(forestPatchID, stayWestMed);
		rmBuildArea(forestPatchID);

		stayInForestPatch = rmCreateAreaMaxDistanceConstraint("stay in forest patch"+i, forestPatchID, 0);

		for (j=0; < 2)
		{
			randtreecount1 = rmRandInt(1,4);
			randtreecount2 = rmRandInt(4,5);
			randtreecount3 = rmRandInt(5,8);
			randtreecount4 = rmRandInt(8,8);

			forestTreeID = rmCreateObjectDef("forest trees"+i+j);
			rmAddObjectDefItem(forestTreeID, brushType1, 10, 8);
			rmAddObjectDefItem(forestTreeID, treeType1, randtreecount1, 6);
			rmAddObjectDefItem(forestTreeID, treeType2, randtreecount2-randtreecount1, 6);
			rmAddObjectDefItem(forestTreeID, treeType3, randtreecount3-(randtreecount2+randtreecount1), 6);
			rmAddObjectDefItem(forestTreeID, treeType4, randtreecount4-(randtreecount3+randtreecount2+randtreecount1), 6);
			rmSetObjectDefMinDistance(forestTreeID, rmXFractionToMeters(0.00));
			rmSetObjectDefMaxDistance(forestTreeID, rmXFractionToMeters(0.48));
			rmAddObjectDefToClass(forestTreeID, classForest);
			rmAddObjectDefConstraint(forestTreeID, stayInForestPatch);
			rmAddObjectDefConstraint(forestTreeID, avoidPlateau);
			rmAddObjectDefConstraint(forestTreeID, avoidCliff);
			rmAddObjectDefConstraint(forestTreeID, avoidWater);
			rmAddObjectDefConstraint(forestTreeID, avoidImpassableLand);
			rmPlaceObjectDefAtLoc(forestTreeID, 0, 0.50, 0.50, 1);
		}
    }

	// Map loading
	rmSetStatusText("", 0.70);

	// Herds 
	int herdcount = 2+PlayerNum;
		
	for (i=0; < herdcount)
	{
		int islandHerdID = rmCreateObjectDef("island herd"+i);
		rmAddObjectDefItem(islandHerdID, huntType, 12, 6);
		rmSetObjectDefMinDistance(islandHerdID, rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(islandHerdID, rmXFractionToMeters(0.48));
		rmSetObjectDefCreateHerd(islandHerdID, true);
		rmAddObjectDefConstraint(islandHerdID, avoidForestMin);
		rmAddObjectDefConstraint(islandHerdID, avoidGoldShort);
		rmAddObjectDefConstraint(islandHerdID, avoidCliffFar);
		rmAddObjectDefConstraint(islandHerdID, avoidNatives);
		rmAddObjectDefConstraint(islandHerdID, avoidWater);
		rmAddObjectDefConstraint(islandHerdID, avoidPlateau);
		rmAddObjectDefConstraint(islandHerdID, avoidHuntFar);
		if (i == 0)
			rmAddObjectDefConstraint(islandHerdID, stayNWQ);
		else if (i == 1)
			rmAddObjectDefConstraint(islandHerdID, stayNEQ);
		else
			rmAddObjectDefConstraint(islandHerdID, staySouthMed);
		rmPlaceObjectDefAtLoc(islandHerdID, 0, 0.50, 0.50, 1);	
	}

	// Map loading
	rmSetStatusText("", 0.80);

	// Treasures tier 4
	int treasure4count = 4;
	if (PlayerNum <= 4)
		treasure4count = 0;
	
	for (i=0; < treasure4count)
	{
		int nugget4ID = rmCreateObjectDef("nugget 4"+i); 
		rmAddObjectDefItem(nugget4ID, "Nugget", 1, 0);
		rmSetObjectDefMinDistance(nugget4ID, 0);
		rmSetObjectDefMaxDistance(nugget4ID, rmXFractionToMeters(0.5));
		rmSetNuggetDifficulty(4,4);
		rmAddObjectDefConstraint(nugget4ID, avoidNuggetFar);
		rmAddObjectDefConstraint(nugget4ID, avoidGoldMin);
		rmAddObjectDefConstraint(nugget4ID, avoidForestMin);	
		rmAddObjectDefConstraint(nugget4ID, avoidPlateau); 
		rmAddObjectDefConstraint(nugget4ID, avoidCliff); 
		rmAddObjectDefConstraint(nugget4ID, avoidImpassableLand); 
		rmAddObjectDefConstraint(nugget4ID, avoidWater); 
		rmAddObjectDefConstraint(nugget4ID, avoidHuntMin); 
		rmAddObjectDefConstraint(nugget4ID, avoidNatives); 
		if (i == 0)
			rmAddObjectDefConstraint(nugget4ID, staySouthClose); 
		if (i == 1)
			rmAddObjectDefConstraint(nugget4ID, stayNorthClose); 
		if (i == 2)
			rmAddObjectDefConstraint(nugget4ID, stayWestClose); 
		if (i == 3)
			rmAddObjectDefConstraint(nugget4ID, stayEastClose); 
		rmPlaceObjectDefAtLoc(nugget4ID, 0, 0.50, 0.50, 1);
	}

	// Treasures tier 3
	int treasure3count = PlayerNum;
	if (PlayerNum <= 2)
		treasure3count = 0;

	for (i=0; < treasure3count)
	{
		int nugget3ID = rmCreateObjectDef("nugget 3"+i); 
		rmAddObjectDefItem(nugget3ID, "Nugget", 1, 0);
		rmSetObjectDefMinDistance(nugget3ID, 0);
		rmSetObjectDefMaxDistance(nugget3ID, rmXFractionToMeters(0.5));
		rmSetNuggetDifficulty(3,3);
		if (treasure4count == 0)
			rmAddObjectDefConstraint(nugget3ID, avoidNuggetFar);
		else
			rmAddObjectDefConstraint(nugget3ID, avoidNugget);
		rmAddObjectDefConstraint(nugget3ID, avoidGoldMin);
		rmAddObjectDefConstraint(nugget3ID, avoidForestMin);	
		rmAddObjectDefConstraint(nugget3ID, avoidPlateau); 
		rmAddObjectDefConstraint(nugget3ID, avoidCliff); 
		rmAddObjectDefConstraint(nugget3ID, avoidImpassableLand); 
		rmAddObjectDefConstraint(nugget3ID, avoidWater); 
		rmAddObjectDefConstraint(nugget3ID, avoidHuntMin); 
		rmAddObjectDefConstraint(nugget3ID, avoidNatives); 
		if (i == 0)
			rmAddObjectDefConstraint(nugget3ID, stayNWQ);
		else if (i == 1)
			rmAddObjectDefConstraint(nugget3ID, stayNEQ);
		else if (i == 2)
			rmAddObjectDefConstraint(nugget3ID, staySEQ);
		else if (i == 3)
			rmAddObjectDefConstraint(nugget3ID, staySWQ);
		else
			rmAddObjectDefConstraint(nugget3ID, staySouthMed);
		rmPlaceObjectDefAtLoc(nugget3ID, 0, 0.50, 0.50, 1);
	}

	// Treasures tier 2
	int treasure2count = 2*PlayerNum;

	for (i=0; < treasure2count)
	{
		int nugget2ID = rmCreateObjectDef("nugget 2"+i); 
		rmAddObjectDefItem(nugget2ID, "Nugget", 1, 0);
		rmSetObjectDefMinDistance(nugget2ID, 0);
		rmSetObjectDefMaxDistance(nugget2ID, rmXFractionToMeters(0.48));
		rmSetNuggetDifficulty(2,2);
		if (treasure3count == 0)
			rmAddObjectDefConstraint(nugget2ID, avoidNuggetVeryFar);
		else
			rmAddObjectDefConstraint(nugget2ID, avoidNuggetFar);
		rmAddObjectDefConstraint(nugget2ID, avoidGoldMin);
		rmAddObjectDefConstraint(nugget2ID, avoidForestMin);	
		rmAddObjectDefConstraint(nugget2ID, avoidPlateau); 
		rmAddObjectDefConstraint(nugget2ID, avoidCliff); 
		rmAddObjectDefConstraint(nugget2ID, avoidImpassableLand); 
		rmAddObjectDefConstraint(nugget2ID, avoidWater); 
		rmAddObjectDefConstraint(nugget2ID, avoidHuntMin); 
		rmPlaceObjectDefAtLoc(nugget2ID, 0, 0.50, 0.50, 1);
	}

	// Map loading
	rmSetStatusText("", 0.90);

	// ---------------------------------------------------
	// ****************** Sea resources ******************
	// ---------------------------------------------------

	// Whales
	int whalecount = 4+PlayerNum;

	for (i=0; < whalecount)
	{
		int whaleID=rmCreateObjectDef("whale"+i);
		rmAddObjectDefItem(whaleID, "MinkeWhale", 1, 0);
		rmSetObjectDefMinDistance(whaleID, rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.48));
		if (i == 0)
			rmAddObjectDefConstraint(whaleID, stayNWQ);
		if (i == 1)
			rmAddObjectDefConstraint(whaleID, stayNEQ);
		if (i == 2)
			rmAddObjectDefConstraint(whaleID, staySEQ);
		if (i == 3)
			rmAddObjectDefConstraint(whaleID, staySWQ);
		rmAddObjectDefConstraint(whaleID, avoidLand);
		rmAddObjectDefConstraint(whaleID, avoidCaveFar);
		rmAddObjectDefConstraint(whaleID, avoidNativesFar);
		rmAddObjectDefConstraint(whaleID, avoidWhale);
		rmAddObjectDefConstraint(whaleID, avoidEdge);
		rmAddObjectDefConstraint(whaleID, avoidStartingResources);
		rmPlaceObjectDefAtLoc(whaleID, 0, 0.50, 0.50, 1);
	}

	// Fish
	int fishcount = 15*PlayerNum;

	for (i=0; < fishcount)
	{
		int fishID = rmCreateObjectDef("fish"+i);
		rmAddObjectDefItem(fishID, fishies, 3, 8);
		rmSetObjectDefMinDistance(fishID, rmXFractionToMeters(0.00));
		rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.48));
		if (i < fishcount/4)
			rmAddObjectDefConstraint(fishID, stayNW);
		else if (i < fishcount/2)
			rmAddObjectDefConstraint(fishID, stayNE);
		else if (i < 3*fishcount/4)
			rmAddObjectDefConstraint(fishID, staySE);
		else
			rmAddObjectDefConstraint(fishID, staySW);
		rmAddObjectDefConstraint(fishID, avoidLand);
		rmAddObjectDefConstraint(fishID, avoidCave);
		rmAddObjectDefConstraint(fishID, avoidEdge);
		rmAddObjectDefConstraint(fishID, avoidFish);
		rmAddObjectDefConstraint(fishID, avoidWhaleMin);
		rmAddObjectDefConstraint(fishID, avoidStartingResources);
		rmAddObjectDefConstraint(fishID, avoidNuggetMin);
		rmPlaceObjectDefAtLoc(fishID, 0, 0.50, 0.50, 1);
	}

	// Treasures tier 6
	int treasure6count = 4+cNumberNonGaiaPlayers;

	for (i=0; < treasure6count)
	{
		int nugget6ID = rmCreateObjectDef("nugget 6"+i); 
		rmAddObjectDefItem(nugget6ID, "ypNuggetBoat", 1, 0);
		rmSetObjectDefMinDistance(nugget6ID, 0);
		rmSetObjectDefMaxDistance(nugget6ID, rmXFractionToMeters(0.48));
		rmSetNuggetDifficulty(6,6);
		rmAddObjectDefConstraint(nugget6ID, avoidNuggetVeryFar);
		rmAddObjectDefConstraint(nugget6ID, avoidLand);
		rmAddObjectDefConstraint(nugget6ID, avoidStartingResources);	
		rmAddObjectDefConstraint(nugget6ID, avoidCave); 
		rmAddObjectDefConstraint(nugget6ID, avoidNatives); 
		rmAddObjectDefConstraint(nugget6ID, avoidTradeRoute); 
		rmAddObjectDefConstraint(nugget6ID, avoidEdge); 
		rmAddObjectDefConstraint(nugget6ID, avoidWhaleMin); 
		if (i < treasure6count/4)
			rmAddObjectDefConstraint(nugget6ID, stayN);
		else if (i < treasure6count/2)
			rmAddObjectDefConstraint(nugget6ID, stayE);
		else if (i < treasure6count*3/4)
			rmAddObjectDefConstraint(nugget6ID, stayS);
		else
			rmAddObjectDefConstraint(nugget6ID, stayW);
		rmPlaceObjectDefAtLoc(nugget6ID, 0, 0.50, 0.50, 1);
	}

	// Treasures tier 5
	int treasure5count = 4;

	for (i=0; < treasure5count)
	{
		int nugget5ID = rmCreateObjectDef("nugget 5"+i); 
		rmAddObjectDefItem(nugget5ID, "ypNuggetBoat", 1, 0);
		rmSetObjectDefMinDistance(nugget5ID, 0);
		rmSetObjectDefMaxDistance(nugget5ID, rmXFractionToMeters(0.48));
		rmSetNuggetDifficulty(5,5);
		rmAddObjectDefConstraint(nugget5ID, avoidNuggetFar);
		rmAddObjectDefConstraint(nugget5ID, avoidLand);
		rmAddObjectDefConstraint(nugget5ID, avoidStartingResources);	
		rmAddObjectDefConstraint(nugget5ID, avoidCave); 
		rmAddObjectDefConstraint(nugget5ID, avoidNatives); 
		rmAddObjectDefConstraint(nugget5ID, avoidTradeRoute); 
		rmAddObjectDefConstraint(nugget5ID, avoidEdge); 
		rmAddObjectDefConstraint(nugget5ID, avoidWhaleMin); 
		if (i == 0)
			rmAddObjectDefConstraint(nugget5ID, stayNWQ);
		if (i == 1)
			rmAddObjectDefConstraint(nugget5ID, stayNEQ);
		if (i == 2)
			rmAddObjectDefConstraint(nugget5ID, staySEQ);
		if (i == 3)
			rmAddObjectDefConstraint(nugget5ID, staySWQ);
		rmPlaceObjectDefAtLoc(nugget5ID, 0, 0.50, 0.50, 1);
	}

	// Map loading
	rmSetStatusText("",0.95);

	// ******************* Triggers ***********************

	// Variables

	int eruptionLenght = 140;
	int eqAreaDamage = 20;
	int islandSize = 200;
	int gapMin = 700;
	int gapMax = 1200;
	int eruptionBreakInitial = rmRandInt(420,720);
	int eruptionBreak1 = rmRandInt(gapMin,gapMax);
	int eruptionBreak2 = rmRandInt(gapMin,gapMax);
	int eruptionBreak3 = rmRandInt(gapMin,gapMax);
	int eruptionBreak4 = rmRandInt(gapMin,gapMax);
	int eruptionBreak5 = rmRandInt(gapMin,gapMax);

	string volcanoCenterID = ""+(rmGetUnitPlaced(volcanoControllerID, 0));

	int hansaSocket1 = rmGetGroupingInstanceUnitByType(hansaInstanceID, "zpSPCSocketHansaKontorCityState")+1;
	int hansaCenter1 = rmGetGroupingInstanceUnitByType(hansaInstanceID, "zpCinematicRevealer")+1;
	
	string guardianUnit1 = "zpBuccaneerGuard";
	string guardianUnit2 = "zpPirateGuard";

	int flag1 = rmGetGroupingInstanceUnitByType(hansaInstanceID, "zpHansaWaterSpawnFlag1")+1;
	int flag2 = rmGetUnitPlaced(inventorwaterflagID1, 0);
	int flag3 = rmGetUnitPlaced(piratewaterflagID1, 0);
	int flag4 = rmGetUnitPlaced(piratewaterflagID2, 0);

	string inventorSocket = ""+(flag2-1);
	string pirate1Socket = ""+(flag3-1);
	string pirate2Socket = ""+(flag4-1);

	if (cNumberNonGaiaPlayers <=6) {
		eruptionLenght = 120;
		islandSize = 180;
		eqAreaDamage = 24;
	}

	if (cNumberNonGaiaPlayers <=4) {
		eruptionLenght = 100;
		islandSize = 160;
		eqAreaDamage = 30;
	}

	if (cNumberNonGaiaPlayers <=2) {
		eruptionLenght = 80;
		islandSize = 120;
		eqAreaDamage = 40;
	}

	// Triggers

	rmCreateTrigger("Tasmania_Counter");
	rmCreateTrigger("Tasmania_Normalize");

	rmSwitchToTrigger(rmTriggerID("Tasmania_Counter"));
	for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpTasmaniaStart"); // Blocks ship attack
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","TasmaniaCounter");
	rmSetTriggerEffectParamInt("Start", 120);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg", "Ship attack enabled in");
	rmSetTriggerEffectParamInt("Event", rmTriggerID("Tasmania_Normalize"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Tasmania_Normalize"));
	for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpTasmaniaPlay"); // Normalize ships
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParamInt("Level",1);
		for(i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpNorthDivingBell");
		rmSetTriggerEffectParamInt("Status",2);
		}
		for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpIslandScientists");
		rmSetTriggerEffectParamInt("Status",2);
		}
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","Eruption");
	rmSetTriggerEffectParamInt("Value",1);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Conversion Suspend
	rmCreateTrigger("Buildings Convert OFF");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+hansaSocket1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Socket 1 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+hansaSocket1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit1);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+hansaSocket1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit2);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+hansaSocket1, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+hansaSocket1, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Volcano trigger definition
	rmCreateTrigger("Volcano_StartInitial");
	rmCreateTrigger("Volcano_Start1");
	rmCreateTrigger("Volcano_Start2");
	rmCreateTrigger("Volcano_Start3");
	rmCreateTrigger("Volcano_Start4");
	rmCreateTrigger("Volcano_Start5");

	rmCreateTrigger("Volcano_Lava");
	rmCreateTrigger("Volcano_Lava_Death");
	rmCreateTrigger("Volcano_Lava_Delay1");
	rmCreateTrigger("Volcano_Lava_Delay2");
	rmCreateTrigger("Volcano_Lava_Delay3");
	rmCreateTrigger("Volcano_Lava_Delay4");
	rmCreateTrigger("Volcano_Lava_Delay5");
	rmCreateTrigger("Volcano_Lava_Transform");

	rmCreateTrigger("Volcano_Short");
	rmCreateTrigger("Volcano_Short2");
	rmCreateTrigger("Volcano_Medium");
	rmCreateTrigger("Volcano_Long");
	rmCreateTrigger("Volcano_UltraLong");
	rmCreateTrigger("Volcano_XXLong");
	rmCreateTrigger("Volcano_Stop");
	rmCreateTrigger("Volcano_Damage");

	rmCreateTrigger("Volcano_Music1");
	rmCreateTrigger("Volcano_Music2");
	rmCreateTrigger("Volcano_Music3");
	rmCreateTrigger("Volcano_MusicEnd");

	// Volcano Music

	rmSwitchToTrigger(rmTriggerID("Volcano_Music1"));
	rmAddTriggerEffect("Music Filename");
	rmSetTriggerEffectParam("Music","music\battle\BubbleChum.mp3"); // Music Filename
	rmSetTriggerEffectParamFloat("Duration",4.0);
	rmAddTriggerEffect("Sound Timer");
	rmSetTriggerEffectParamInt("Time", 50000);
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music2"));
	rmSetTriggerPriority(1);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Music2"));
	rmAddTriggerEffect("Music Filename");
	rmSetTriggerEffectParam("Music","music\battle\CamelsStrawsAndBacks.mp3"); // Music Filename
	rmSetTriggerEffectParamFloat("Duration",2.0);
	if (cNumberNonGaiaPlayers >=6){
	rmAddTriggerEffect("Sound Timer");
	rmSetTriggerEffectParamInt("Time", 60000);
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music3"));
	}
	rmSetTriggerPriority(1);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);

	if (cNumberNonGaiaPlayers >=6){
	rmSwitchToTrigger(rmTriggerID("Volcano_Music3"));
	rmAddTriggerEffect("Music Filename");
	rmSetTriggerEffectParam("Music","music\battle\Ruinion.mp3"); // Music Filename
	rmSetTriggerEffectParamFloat("Duration",2.0);
	rmSetTriggerPriority(1);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);
	}

	rmSwitchToTrigger(rmTriggerID("Volcano_MusicEnd"));
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",5);
	rmAddTriggerEffect("Music Play");
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music2"));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music3"));
	rmSetTriggerPriority(1);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);

	// Volcano Area Damage

	rmSwitchToTrigger(rmTriggerID("Volcano_Damage"));
	for(i=1; <= cNumberNonGaiaPlayers) {
	rmAddTriggerEffect("Damage Units in Area");
	rmSetTriggerEffectParam("SrcObject",volcanoCenterID);
	rmSetTriggerEffectParamInt("Player",i);
	rmSetTriggerEffectParam("UnitType","Unit");
	rmSetTriggerEffectParamFloat("Dist",islandSize);
	rmSetTriggerEffectParamFloat("Damage",eqAreaDamage);
	rmAddTriggerEffect("Damage Units in Area");
	rmSetTriggerEffectParam("SrcObject",volcanoCenterID);
	rmSetTriggerEffectParamInt("Player",i);
	rmSetTriggerEffectParam("UnitType","Building");
	rmSetTriggerEffectParamFloat("Dist",islandSize);
	rmSetTriggerEffectParamFloat("Damage",20*eqAreaDamage);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Volcano random starts

	rmSwitchToTrigger(rmTriggerID("Volcano_StartInitial"));
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","Eruption");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",eruptionBreakInitial);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
	rmAddTriggerEffect("Set Lighting");
	rmSetTriggerEffectParam("SetName", volcanoLight);
	rmSetTriggerEffectParamFloat("FadeTime",5.0);
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",3.0);
	rmSetTriggerEffectParamFloat("Strength",0.4);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","VolcanoEruption");
	rmSetTriggerEffectParamInt("Start",eruptionLenght);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg", "Volcano eruption");
	rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","Eruption");
	rmSetTriggerEffectParamInt("Value",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start1"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

	rmAddTriggerEffect("Send Chat");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("Message","The Volcano is waking up!");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Start1"));
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","Eruption");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",eruptionBreak1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
	rmAddTriggerEffect("Set Lighting");
	rmSetTriggerEffectParam("SetName","carribean");
	rmSetTriggerEffectParamFloat("FadeTime",5.0);
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",3.0);
	rmSetTriggerEffectParamFloat("Strength",0.4);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","VolcanoEruption");
	rmSetTriggerEffectParamInt("Start",eruptionLenght);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg", "Volcano eruption");
	rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","Eruption");
	rmSetTriggerEffectParamInt("Value",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start2"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

	rmAddTriggerEffect("Send Chat");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("Message","The Volcano is waking up!");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Start2"));
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","Eruption");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",eruptionBreak2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
	rmAddTriggerEffect("Set Lighting");
	rmSetTriggerEffectParam("SetName","carribean");
	rmSetTriggerEffectParamFloat("FadeTime",5.0);
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",3.0);
	rmSetTriggerEffectParamFloat("Strength",0.4);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","VolcanoEruption");
	rmSetTriggerEffectParamInt("Start",eruptionLenght);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg", "Volcano eruption");
	rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","Eruption");
	rmSetTriggerEffectParamInt("Value",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start3"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

	rmAddTriggerEffect("Send Chat");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("Message","The Volcano is waking up!");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Start3"));
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","Eruption");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",eruptionBreak3);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
	rmAddTriggerEffect("Set Lighting");
	rmSetTriggerEffectParam("SetName","carribean");
	rmSetTriggerEffectParamFloat("FadeTime",5.0);
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",3.0);
	rmSetTriggerEffectParamFloat("Strength",0.4);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","VolcanoEruption");
	rmSetTriggerEffectParamInt("Start",eruptionLenght);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg", "Volcano eruption");
	rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","Eruption");
	rmSetTriggerEffectParamInt("Value",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start4"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

	rmAddTriggerEffect("Send Chat");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("Message","The Volcano is waking up!");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Start4"));
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","Eruption");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",eruptionBreak4);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
	rmAddTriggerEffect("Set Lighting");
	rmSetTriggerEffectParam("SetName","carribean");
	rmSetTriggerEffectParamFloat("FadeTime",5.0);
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",3.0);
	rmSetTriggerEffectParamFloat("Strength",0.4);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","VolcanoEruption");
	rmSetTriggerEffectParamInt("Start",eruptionLenght);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg", "Volcano eruption");
	rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","Eruption");
	rmSetTriggerEffectParamInt("Value",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start5"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

	rmAddTriggerEffect("Send Chat");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("Message","The Volcano is waking up!");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Start5"));
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","Eruption");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",eruptionBreak5);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoActive"); // Activates Volcano
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short"));
	rmAddTriggerEffect("Set Lighting");
	rmSetTriggerEffectParam("SetName","carribean");
	rmSetTriggerEffectParamFloat("FadeTime",5.0);
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",3.0);
	rmSetTriggerEffectParamFloat("Strength",0.4);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","VolcanoEruption");
	rmSetTriggerEffectParamInt("Start",eruptionLenght);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg", "Volcano eruption");
	rmSetTriggerEffectParamInt("Event", rmTriggerID("Volcano_Stop"));
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","Eruption");
	rmSetTriggerEffectParamInt("Value",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start1"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Music1"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava"));

	rmAddTriggerEffect("Send Chat");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("Message","The Volcano is waking up!");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Volcano Lava Flow

	rmSwitchToTrigger(rmTriggerID("Volcano_Lava"));

	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",3);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",4);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",5);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay1"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Death"));
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","Eruption");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",3);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",4);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",5);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Player : Override Culture for Art");
	rmSetTriggerEffectParamInt("Player",0);
	rmSetTriggerEffectParam("Culture","WesternEurope");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay1"));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",volcanoCenterID);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon");
	rmSetTriggerConditionParamInt("Dist",20.0);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",20);

	rmAddTriggerEffect("Player : Override Culture for Art");
	rmSetTriggerEffectParamInt("Player",0);
	rmSetTriggerEffectParam("Culture","Chinese");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay2"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay2"));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",volcanoCenterID);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon2");
	rmSetTriggerConditionParamInt("Dist",20.0);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",20);

	rmAddTriggerEffect("Player : Override Culture for Art");
	rmSetTriggerEffectParamInt("Player",0);
	rmSetTriggerEffectParam("Culture","Japanese");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay3"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay3"));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",volcanoCenterID);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon3");
	rmSetTriggerConditionParamInt("Dist",20.0);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",20);

	rmAddTriggerEffect("Player : Override Culture for Art");
	rmSetTriggerEffectParamInt("Player",0);
	rmSetTriggerEffectParam("Culture","Indian");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay4"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay4"));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",volcanoCenterID);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon4");
	rmSetTriggerConditionParamInt("Dist",20.0);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",20);

	rmAddTriggerEffect("Player : Override Culture for Art");
	rmSetTriggerEffectParamInt("Player",0);
	rmSetTriggerEffectParam("Culture","Mediterranean");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Delay5"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Delay5"));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",volcanoCenterID);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpLavaSpawnerTradeWagon5");
	rmSetTriggerConditionParamInt("Dist",20.0);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",20);

	rmAddTriggerEffect("Player : Override Culture for Art");
	rmSetTriggerEffectParamInt("Player",0);
	rmSetTriggerEffectParam("Culture","EasternEurope");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("Volcano_Lava_Transform"));
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",15);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoLavaBack");
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Volcano Eruption Phases

	rmSwitchToTrigger(rmTriggerID("Volcano_Short"));
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",20);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeShort"); 
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Medium"));
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",2.0);
	rmSetTriggerEffectParamFloat("Strength",0.2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Volcano_Medium"));
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",20);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeMedium");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",2.0);
	rmSetTriggerEffectParamFloat("Strength",0.2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	if (cNumberNonGaiaPlayers <=2){
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
	}
	else{
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Long"));
	}
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	if (cNumberNonGaiaPlayers >=3){
	rmSwitchToTrigger(rmTriggerID("Volcano_Long"));
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",20);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeLong");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",2.0);
	rmSetTriggerEffectParamFloat("Strength",0.2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	if (cNumberNonGaiaPlayers <=4){
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
	}
	else{
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_UltraLong"));
	}
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	if (cNumberNonGaiaPlayers >=5){
	rmSwitchToTrigger(rmTriggerID("Volcano_UltraLong"));
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",20);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeUltraLong");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",2.0);
	rmSetTriggerEffectParamFloat("Strength",0.2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
	if (cNumberNonGaiaPlayers <=6){
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
	}
	else{
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_XXLong"));
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	if (cNumberNonGaiaPlayers >=7){
	rmSwitchToTrigger(rmTriggerID("Volcano_XXLong"));
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",20);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeXXLong");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",2.0);
	rmSetTriggerEffectParamFloat("Strength",0.2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Damage"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Short2"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	rmSwitchToTrigger(rmTriggerID("Volcano_Short2"));
	rmAddTriggerCondition("Timer");
	rmSetTriggerConditionParamInt("Param1",20);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoRangeShort");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",1.5);
	rmSetTriggerEffectParamFloat("Strength",0.2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Transform"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Volcano stop

	rmSwitchToTrigger(rmTriggerID("Volcano_Stop"));
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpVolcanoPassive"); // Desctivates Volcano
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Start"));
	rmAddTriggerEffect("Set Lighting");
	rmSetTriggerEffectParam("SetName",shineAlight);
	rmSetTriggerEffectParamFloat("FadeTime",5.0);
	rmAddTriggerEffect("Shake Camera");
	rmSetTriggerEffectParamFloat("Duration",1.0);
	rmSetTriggerEffectParamFloat("Strength",0.1);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Earthquake");
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","Eruption");
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("FadeOutMusic");
	rmSetTriggerEffectParamFloat("Duration",4.0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_MusicEnd"));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Death"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Update Sockets

	rmCreateTrigger("I Update Sockets");
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",0);
	rmSetTriggerConditionParam("Protounit","deTradingGalleon");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Death"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("II Update Sockets");
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID",0);
	rmSetTriggerConditionParam("Protounit","deTradingFluyt");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Volcano_Lava_Death"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Update ports

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Update TR Plr"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpHansaTradeRouteUpgrade");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParamInt("Level",2);
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParamInt("Level",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// ******************* Politicians *******************

	// Italian Vilager Balance

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Italian Vilager Balance"+k);
	rmAddTriggerCondition("ZP Player Civilization");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("Civilization","DEItalians");
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpItalianSettlerBallance");
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(2);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Italian Gondola Balance"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechDEHCGondolas");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpItalianGondolaBallance");
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(2);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(false);
	rmSetTriggerLoop(false);
	}

	// Speed Always Wins Returner

		for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Cheat Returner"+k);
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",10);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchIncrease");
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(2);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(false);
		rmSetTriggerLoop(false);
		}

	// Consulate - Tradingpost politician switcher

		for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Activate Consulate Japan"+k);
		rmAddTriggerCondition("ZP Player Civilization");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("Civilization","Japanese");
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnJapanese"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Pick Consulate Tech");
		rmSetTriggerEffectParamInt("Player",k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
		}

		for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Activate Consulate China"+k);
		rmAddTriggerCondition("ZP Player Civilization");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("Civilization","Chinese");
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnChinese"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Pick Consulate Tech");
		rmSetTriggerEffectParamInt("Player",k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
		}

		for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Activate Consulate India"+k);
		rmAddTriggerCondition("ZP Player Civilization");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("Civilization","Indians");
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnIndian"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Pick Consulate Tech");
		rmSetTriggerEffectParamInt("Player",k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
		}

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Activate Tortuga"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpTheBlackFlag"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPiratesBaltic"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Pick Consulate Tech");
		rmSetTriggerEffectParamInt("Player",k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Vilager_Balance"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Gondola_Balance"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Activate Hansa"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpHansaExpansion"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffHansa"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Pick Consulate Tech");
		rmSetTriggerEffectParamInt("Player",k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Vilager_Balance"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Gondola_Balance"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Activate Scientists"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpPickScientist"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffScientists"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpBigButtonResearchDecrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Pick Consulate Tech");
		rmSetTriggerEffectParamInt("Player",k);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Vilager_Balance"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Italian_Gondola_Balance"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Cheat_Returner"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(true);
	}

	// Specific for human players

	for(k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Human Check Plr"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "true");
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpIsPirateMap"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Japan"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_China"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_India"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Tortuga"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Scientists"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Hansa"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Privateer training

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("TrainPrivateer1ON Plr"+k);
	rmCreateTrigger("TrainPrivateer1OFF Plr"+k);
	rmCreateTrigger("TrainPrivateer1TIME Plr"+k);


	rmCreateTrigger("TrainPrivateer2ON Plr"+k);
	rmCreateTrigger("TrainPrivateer2OFF Plr"+k);
	rmCreateTrigger("TrainPrivateer2TIME Plr"+k);

	rmSwitchToTrigger(rmTriggerID("TrainPrivateer2ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate2Socket); // Unique Object ID Village 4
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpPrivateerProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2OFF_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2TIME_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivateer2OFF_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivateer2TIME_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpPrivateerBuildLimitReduceShadow"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer2"); //operator
	rmSetTriggerEffectParamInt("Status",0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1Socket); // Unique Object ID Village 3
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpPrivateerProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer1"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1OFF_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1TIME_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivateer1OFF_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("TrainPrivateer1TIME_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpPrivateerBuildLimitReduceShadow"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainPrivateer1"); //operator
	rmSetTriggerEffectParamInt("Status",0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Unique ship Training

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("UniqueShip1TIMEPlr"+k);

	rmCreateTrigger("BlackbTrain1ONPlr"+k);
	rmCreateTrigger("BlackbTrain1OFFPlr"+k);

	rmCreateTrigger("GraceTrain1ONPlr"+k);
	rmCreateTrigger("GraceTrain1OFFPlr"+k);

	rmCreateTrigger("CaesarTrain1ONPlr"+k);
	rmCreateTrigger("CaesarTrain1OFFPlr"+k);

	rmCreateTrigger("PirateDestroyerTrain1ONPlr"+k);
	rmCreateTrigger("PirateDestroyerTrain1OFFPlr"+k);

	
	rmCreateTrigger("UniqueShip2TIMEPlr"+k);

	rmCreateTrigger("BlackbTrain2ONPlr"+k);
	rmCreateTrigger("BlackbTrain2OFFPlr"+k);

	rmCreateTrigger("GraceTrain2ONPlr"+k);
	rmCreateTrigger("GraceTrain2OFFPlr"+k);

	rmCreateTrigger("CaesarTrain2ONPlr"+k);
	rmCreateTrigger("CaesarTrain2OFFPlr"+k);

	rmCreateTrigger("PirateDestroyerTrain2ONPlr"+k);
	rmCreateTrigger("PirateDestroyerTrain2OFFPlr"+k);
	
	rmSwitchToTrigger(rmTriggerID("UniqueShip2TIMEPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpReducePirateShipsBuildLimit"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BlackbTrain2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate2Socket);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCQueenAnneProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainQueenAnne2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BlackbTrain2OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("GraceTrain2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate2Socket); // Unique Object ID Village 4
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCBlackPearlProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainBlackPearl2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("GraceTrain2OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("CaesarTrain2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate2Socket);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCRevenantSteamerProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainRevenantSteamer2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("CaesarTrain2OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("PirateDestroyerTrain2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate2Socket);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCPirateDestroyerProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainPirateDestroyer2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("PirateDestroyerTrain2OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("PirateDestroyerTrain2OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("PirateDestroyerTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	

	// Build limit reducer
	rmSwitchToTrigger(rmTriggerID("UniqueShip1TIMEPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpReducePirateShipsBuildLimit"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Blackbeard
	rmSwitchToTrigger(rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1Socket);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCQueenAnneProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainQueenAnne1"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BlackbTrain1OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Grace
	rmSwitchToTrigger(rmTriggerID("GraceTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1Socket); // Unique Object ID Village 3
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCBlackPearlProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainBlackPearl1"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("GraceTrain1OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Caesar
	rmSwitchToTrigger(rmTriggerID("CaesarTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1Socket);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCRevenantSteamerProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainRevenantSteamer1"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("CaesarTrain1OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Destroyer
	rmSwitchToTrigger(rmTriggerID("PirateDestroyerTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1Socket);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCPirateDestroyerProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainPirateDestroyer1"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("PirateDestroyerTrain1OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("PirateDestroyerTrain1OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("PirateDestroyerTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	}


	// Pirate trading post activation

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Pirates1on Player"+k);
	rmCreateTrigger("Pirates1off Player"+k);

	rmSwitchToTrigger(rmTriggerID("Pirates1on_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1Socket); // Unique Object ID Village 3
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",pirate1Socket); // Unique Object ID Village 3
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag1");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("PirateDestroyerTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate1Socket); // Unique Object ID Village 3
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",pirate1Socket); // Unique Object ID Village 3
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag1");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1on_Player"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer1ON_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("PirateDestroyerTrain1ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Pirates2on Player"+k);
	rmCreateTrigger("Pirates2off Player"+k);

	rmSwitchToTrigger(rmTriggerID("Pirates2on_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate2Socket); // Unique Object ID Village 4
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",pirate2Socket); // Unique Object ID Village 4
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag2");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("PirateDestroyerTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates2off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",pirate2Socket); // Unique Object ID Village 4
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",pirate2Socket); // Unique Object ID Village 4
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpPirateWaterSpawnFlag2");
	rmSetTriggerEffectParamInt("Dist",100);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2on_Player"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainPrivateer2ON_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain2ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain2ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain2ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("PirateDestroyerTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("TrainCog1ON Plr"+k);
		rmCreateTrigger("TrainCog1OFF Plr"+k);
		rmCreateTrigger("TrainCog1TIME Plr"+k);

		rmCreateTrigger("TrainFluyt1ON Plr"+k);
		rmCreateTrigger("TrainFluyt1OFF Plr"+k);
		rmCreateTrigger("TrainFluyt1TIME Plr"+k);

		rmSwitchToTrigger(rmTriggerID("TrainCog1ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+hansaSocket1);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpHanseaticWarshipProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainHansaCog1"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainCog1OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainCog1TIME_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainCog1OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainCog1ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainCog1TIME_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpReduceHansaCogBuildLimit"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainHansaCog1"); //operator
		rmSetTriggerEffectParamInt("Status",0);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainFluyt1ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+hansaSocket1);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpHanseaticFluytProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainHansaFluyt1"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainFluyt1OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainFluyt1TIME_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainFluyt1OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainFluyt1ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainFluyt1TIME_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpReduceHansaFluytBuildLimit"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainHansaFluyt1"); //operato
		rmSetTriggerEffectParamInt("Status",0);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Convert Hansa Settlement
	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Hansa1ON Plr"+k);
		rmCreateTrigger("Hansa1OFF Plr"+k);

		rmSwitchToTrigger(rmTriggerID("Hansa1ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+hansaSocket1);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+hansaCenter1);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+flag1);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+hansaCenter1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+hansaCenter1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Hansa1OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainCog1ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainFluyt1ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Hansa1OFF_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+hansaSocket1);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamInt("Count",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+hansaCenter1);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+flag1);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+hansaCenter1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+hansaCenter1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Hansa1ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainCog1ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainFluyt1ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Submarine Training

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("TrainSubmarine1ON Plr"+k);
		rmCreateTrigger("TrainSubmarine1OFF Plr"+k);
		rmCreateTrigger("TrainSubmarine1TIME Plr"+k);

		rmCreateTrigger("Nautilus1TIMEPlr"+k);
		rmCreateTrigger("Nautilus1ONPlr"+k);
		rmCreateTrigger("Nautilus1OFFPlr"+k);

		rmSwitchToTrigger(rmTriggerID("TrainSubmarine1ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",inventorSocket); // Unique Object ID Village 1
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSubmarineProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status Conditional (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechCondition","cTechzpTransformNemoSubmarines"); //operator
		rmSetTriggerEffectParam("Tech1ID","cTechzpTrainSubmarineSPC1"); //operator
		rmSetTriggerEffectParam("Tech2ID","cTechzpTrainSubmarine1"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1TIME_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainSubmarine1OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainSubmarine1TIME_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpReduceSubmarineBuildLimit"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainSubmarine1"); //operator
		rmSetTriggerEffectParamInt("Status",0);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		// Build limit reducer 1
		rmSwitchToTrigger(rmTriggerID("Nautilus1TIMEPlr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpReduceNautilusBuildLimit"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		// Nautilus 1
		rmSwitchToTrigger(rmTriggerID("Nautilus1ONPlr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",inventorSocket); // Unique Object ID Village 1
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpNautilusProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status Conditional (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
    	rmSetTriggerEffectParam("TechCondition","cTechzpTransformNemoSubmarines"); //operator
		rmSetTriggerEffectParam("Tech1ID","cTechzpTrainNautilusSPC1"); //operator
    	rmSetTriggerEffectParam("Tech2ID","cTechzpTrainNautilus1"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1TIMEPlr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1OFFPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Nautilus1OFFPlr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

	}

	// Renegade trading post activation

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Renegades1on Player"+k);
		rmCreateTrigger("Renegades1off Player"+k);

		rmSwitchToTrigger(rmTriggerID("Renegades1on_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",inventorSocket); // Unique Object ID Village 1
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",inventorSocket); // Unique Object ID Village 1
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
		rmSetTriggerEffectParamInt("Dist",100);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Renegades1off_Player"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Renegades1off_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",inventorSocket); // Unique Object ID Village 1
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",inventorSocket); // Unique Object ID Village 1
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpNativeWaterSpawnFlag1");
		rmSetTriggerEffectParamInt("Dist",100);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Renegades1on_Player"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainSubmarine1ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Nautilus1ONPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// AI Pirate Captains

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Pirate Captain"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int pirateCaptain=-1;
	pirateCaptain = rmRandInt(1,3);

	if (pirateCaptain==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBlackbeard"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (pirateCaptain==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesGrace"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (pirateCaptain==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePiratesBeauregard"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// AI Hansa Leaders

	for (k=1; <= cNumberNonGaiaPlayers) {
	if (rmGetPlayerTeam(k) == 0) {
		rmCreateTrigger("ZP_Iniciate_Revolution"+k);
		rmCreateTrigger("ZP_Execute_Revolution"+k);
		rmCreateTrigger("ZP_Timer_Revolution"+k);

		rmSwitchToTrigger(rmTriggerID("ZP_Iniciate_Revolution"+k));
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechIndustrialize");
		rmSetTriggerConditionParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ZP_Timer_Revolution"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ZP_Timer_Revolution"+k));
		rmAddTriggerCondition("Timer");
		rmSetTriggerConditionParamInt("Param1",10);
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechzpNativeVenetians");
		rmSetTriggerConditionParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("ZP_Execute_Revolution"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("ZP_Execute_Revolution"+k));
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechzpNativeVenetians");
		rmSetTriggerConditionParamInt("Status",2);

		int revFraction=-1;
		revFraction = rmRandInt(1,3);

		if (revFraction==1)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateHansaWestern"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (revFraction==2)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateHansaCentral"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (revFraction==3)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateHansaEast"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}
	}

	// AI Renegade Captains

		for (k=1; <= cNumberNonGaiaPlayers) {

		rmCreateTrigger("ZP Pick Renegade Captain"+k);
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerCondition("Tech Status Equals");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParamInt("TechID",586);
		rmSetTriggerConditionParamInt("Status",2);

		int renegadeCaptain=-1;
		renegadeCaptain = rmRandInt(1,3);

		if (renegadeCaptain==1)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistNemo"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (renegadeCaptain==2)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistValentine"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (renegadeCaptain==3)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistkhora"); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpAIAirshipSetup"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		}
	
} // END
	
	