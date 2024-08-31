// Riverina v1.0
// 08/2024

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

// Main entry point for random map script
void main(void)
{

	// Text
	// These status text lines are used to manually animate the map generation progress bar
	rmSetStatusText("",0.01); 
	
	// ____________________ General ____________________
	// Strings
	string wetType = "";
	string paintMix1 = "";
	string paintMix2 = "";
	string paintLand1 = "";
	string paintLand2 = "";
	string paintLand3 = "";
	string paintLand4 = "";
	string paintLand5 = "";
	string mntType = "";
	string cliffPaint1 = "";
	string cliffPaint2 = "";
	string forTesting = "";
	string treasureSet = "";
	string shineAlight = "";
	string toiletPaper = "";
	string food1 = "";
	string food2 = "";
	string food3 = "";
	string cattleType = "";
	string treeType1 = "";
	string treeType2 = "";
	string treeType3 = "";
	string natType1 = "";
	string natType2 = "";
	string natType3 = "";
	string natGrpName1 = "";
	string natGrpName2 = "";
	string natGrpName3 = "";
	
	wetType = "Amsterdam";	
	paintMix1 = "pampas_grassy";
	paintMix2 = "pampas_grassy";
	paintLand1 = "cave\cave_ground4";
	paintLand2 = "cave\cave_ground5";
	paintLand3 = "cave\cave_ground2";
	paintLand4 = "cave\cave_ground3";
	paintLand5 = "cave\cave_ground1";
	mntType = "cave";	
	cliffPaint1 = "cave\cave_ground4";	
	cliffPaint2 = "cave\cave_ground4";	
	forTesting = "testmix";	 
	treasureSet = "sonora";
	shineAlight = "deccan_skirmish";
	toiletPaper = "dirt";
	food1 = "zpRedKangaroo";
	food2 = "zpEmu";
	cattleType = "cow";
	treeType1 = "z87 Australian Woodland";
	treeType2 = "ypTreeEucalyptus";
	treeType3 = "TreeSonora";
	natType1 = "Apache";
	natGrpName1 = "native apache village ";

	// Define Natives
	int subCiv0=-1;
	int subCiv1=-1;


	subCiv0=rmGetCivID("AboriginalNatives");
	rmEchoInfo("subCiv0 is AboriginalNatives "+subCiv0);
	if (subCiv0 >= 0)
	rmSetSubCiv(0, "AboriginalNatives");

	subCiv1=rmGetCivID("PenalColony");
	rmEchoInfo("subCiv1 is PenalColony "+subCiv0);
	if (subCiv1 >= 0)
	rmSetSubCiv(1, "PenalColony");

	// Picks the map size
	int playerTiles=13000;
	if (PlayerNum == 4){
		playerTiles = 12700;
	}
	if (PlayerNum == 5){
		playerTiles = 12400;
	}
	if (PlayerNum >= 6){
		playerTiles = 11000;
	}
			
	int size=2.0*sqrt(PlayerNum*playerTiles);
	rmSetMapSize(size, size);

	// Elevation
	rmSetMapElevationParameters(cElevTurbulence, 0.02, 5, 0.7, 8.0);
	rmSetMapElevationHeightBlend(1);
	
	// Make the corners
	rmSetWorldCircleConstraint(false);
	
	// Picks a default water height
	rmSetSeaLevel(0.0);	// this is height of river surface compared to surrounding land. River depth is in the river XML.

	// Picks default terrain and water
	rmSetBaseTerrainMix(paintMix1);
	rmTerrainInitialize("grass");
	rmSetMapType("australia"); 
	rmSetMapType("grass");
	rmSetMapType("water");
	rmSetOceanReveal(false);
	rmSetWindMagnitude(3.5);
	rmSetLightingSet(shineAlight);

	// Choose Mercs
	chooseMercs();

	// Make it windy
	rmSetWindMagnitude(2.0);

	//Define some classes. These are used later for constraints.
	int classPlayer = rmDefineClass("player");
	int classPatch = rmDefineClass("patch");
	int classPatch2 = rmDefineClass("patch2");
	int classPatch3 = rmDefineClass("patch3");
	int classPatch4 = rmDefineClass("patch4");
	rmDefineClass("starting settlement");
	rmDefineClass("startingUnit");
	int classForest = rmDefineClass("Forest");
	int classGold = rmDefineClass("Gold");
	int classStartingResource = rmDefineClass("startingResource");
	int classIsland=rmDefineClass("island");
	int classCliff = rmDefineClass("Cliffs");
	int classNative = rmDefineClass("natives");
	int classRiverBank = rmDefineClass("riverBank");
	int classRiverBankUpper = rmDefineClass("riverBankUpper");
	int classMountains = rmDefineClass("Mountains");
	
	// Text
	rmSetStatusText("",0.10);
	
	// ____________________ Constraints ____________________
	// These are used to have objects and areas avoid each other

	// Map edge constraints
	int playerEdgeConstraint=rmCreatePieConstraint("player edge of map", 0.5, 0.5, rmXFractionToMeters(0.0), rmXFractionToMeters(0.45), rmDegreesToRadians(0), rmDegreesToRadians(360));
   
	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 6.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);
	int riverGrass = rmCreateTerrainMaxDistanceConstraint("stay near the water", "land", false, 6.0);
	int mediumAvoidImpassableLand=rmCreateTerrainDistanceConstraint("medium avoid impassable land", "Land", false, 12.0);

	// Cardinal Directions & Map placement
	int avoidEdge = rmCreatePieConstraint("Avoid Edge",0.5,0.5, rmXFractionToMeters(0.0),rmXFractionToMeters(0.48), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidEdgeMore = rmCreatePieConstraint("Avoid Edge More",0.5,0.5, rmXFractionToMeters(0.0),rmXFractionToMeters(0.45), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidCenter = rmCreatePieConstraint("Avoid Center",0.5,0.5,rmXFractionToMeters(0.28), rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int avoidCenterMin = rmCreatePieConstraint("Avoid Center min",0.5,0.5,rmXFractionToMeters(0.1), rmXFractionToMeters(0.5), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int stayCenter = rmCreatePieConstraint("Stay Center", 0.50, 0.50, rmXFractionToMeters(0.0), rmXFractionToMeters(0.28), rmDegreesToRadians(0),rmDegreesToRadians(360));
	int stayCenterMore = rmCreatePieConstraint("Stay Center more",0.45,0.45,rmXFractionToMeters(0.0), rmXFractionToMeters(0.26), rmDegreesToRadians(0),rmDegreesToRadians(360));

	int staySouthPart = rmCreatePieConstraint("Stay south part", 0.55, 0.55,rmXFractionToMeters(0.0), rmXFractionToMeters(0.60), rmDegreesToRadians(180),rmDegreesToRadians(360));
	int stayNorthHalf = rmCreatePieConstraint("Stay north half", 0.50, 0.50,rmXFractionToMeters(0.0), rmXFractionToMeters(0.50), rmDegreesToRadians(360),rmDegreesToRadians(180));
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 7.0);

	// Resource avoidance
	int avoidForestMed=rmCreateClassDistanceConstraint("avoid forest med", rmClassID("Forest"), 26.0);
	int avoidForest=rmCreateClassDistanceConstraint("avoid forest", rmClassID("Forest"), 20.0);
	int avoidForestFar=rmCreateClassDistanceConstraint("avoid forest far", rmClassID("Forest"), 34.0);
	int avoidForestVeryFar=rmCreateClassDistanceConstraint("avoid forest very far", rmClassID("Forest"), 50.0);
	int avoidForestShort=rmCreateClassDistanceConstraint("avoid forest short", rmClassID("Forest"), 10.0);
	int avoidForestMin=rmCreateClassDistanceConstraint("avoid forest min", rmClassID("Forest"), 4.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("Forest"), 25.0);
	int forestConstraintShort=rmCreateClassDistanceConstraint("object vs. forest", rmClassID("Forest"), 18.0);
	int avoidHunt2Far = rmCreateTypeDistanceConstraint("avoid hunt2 far", food2, 40.0);
	int avoidHunt2VeryFar = rmCreateTypeDistanceConstraint("avoid hunt2 very far", food2, 65.0);
	int avoidHunt2 = rmCreateTypeDistanceConstraint("avoid hunt2", food2, 36.0);
	int avoidHunt2Med = rmCreateTypeDistanceConstraint("avoid hunt2 med", food2, 30.0);
	int avoidHunt2Short = rmCreateTypeDistanceConstraint("avoid hunt2 short", food2, 20.0);
	int avoidHunt2Min = rmCreateTypeDistanceConstraint("avoid hunt2 min", food2, 10.0);	
	int avoidHunt1Far = rmCreateTypeDistanceConstraint("avoid hunt1 far", food1, 60.0);
	int avoidHunt1VeryFar = rmCreateTypeDistanceConstraint("avoid hunt1 very far", food1, 80.0);
	int avoidHunt1 = rmCreateTypeDistanceConstraint("avoid hunt1", food1, 50.0);
	int avoidHunt1Med = rmCreateTypeDistanceConstraint("avoid hunt1 med", food1, 30.0);
	int avoidHunt1Short = rmCreateTypeDistanceConstraint("avoid hunt1 short", food1, 20.0);
	int avoidHunt1Min = rmCreateTypeDistanceConstraint("avoid hunt1 min", food1, 10.0);
	int avoidGoldMed = rmCreateTypeDistanceConstraint("coin avoids coin", "gold", 30.0);
	int avoidGoldTypeShort = rmCreateTypeDistanceConstraint("coin avoids coin short", "gold", 20.0);
	int avoidGoldType = rmCreateTypeDistanceConstraint("coin avoids coin ", "gold", 45.0);
	int avoidGoldTypeMin = rmCreateTypeDistanceConstraint("coin avoids coin min ", "gold", 12.0);
	int avoidGoldTypeFar = rmCreateTypeDistanceConstraint("coin avoids coin far ", "gold", 52.0);
	int avoidGoldMin=rmCreateClassDistanceConstraint("min distance vs gold", rmClassID("Gold"), 8.0);
	int avoidGoldShort = rmCreateClassDistanceConstraint ("gold avoid gold short", rmClassID("Gold"), 16.0);
	int avoidGoldFar = rmCreateClassDistanceConstraint ("gold avoid gold far", rmClassID("Gold"), 50.0);
	int avoidGoldVeryFar = rmCreateClassDistanceConstraint ("gold avoid gold very far", rmClassID("Gold"), 80.0);
	int avoidNuggetMin = rmCreateTypeDistanceConstraint("nugget avoid nugget min", "AbstractNugget", 10.0);
	int avoidNuggetShort = rmCreateTypeDistanceConstraint("nugget avoid nugget short", "AbstractNugget", 20.0);
	int avoidNugget=rmCreateTypeDistanceConstraint("nugget avoid nugget", "AbstractNugget", 30.0);
	int avoidNuggetFar = rmCreateTypeDistanceConstraint("nugget avoid nugget Far", "AbstractNugget", 50.0);
	int avoidTownCenterVeryFar = rmCreateTypeDistanceConstraint("avoid Town Center Very Far", "townCenter", 85.0);
	int avoidTownCenterFar = rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 70.0);
	int avoidTownCenter = rmCreateTypeDistanceConstraint("avoid Town Center", "townCenter", 48.0); //46
	int avoidTownCenterMed = rmCreateTypeDistanceConstraint("avoid Town Center med", "townCenter", 60.0);
	int avoidTownCenterShort = rmCreateTypeDistanceConstraint("avoid Town Center short", "townCenter", 20.0);
	int avoidTownCenterMin = rmCreateTypeDistanceConstraint("avoid Town Center min", "townCenter", 18.0);
	int avoidStartingResources = rmCreateClassDistanceConstraint("avoid starting resources", rmClassID("startingResource"), 12.0);
	int avoidStartingResourcesShort = rmCreateClassDistanceConstraint("avoid starting resources short", rmClassID("startingResource"), 8.0);
	int avoidCliff = rmCreateClassDistanceConstraint("avoid cliff", classCliff, 20.0);
	int avoidCliffShort = rmCreateClassDistanceConstraint("avoid cliff short", classCliff, 4.0);
	int avoidCliffMed = rmCreateClassDistanceConstraint("avoid cliff medium", rmClassID("Cliffs"), 12.0);
	int avoidCliffFar = rmCreateClassDistanceConstraint("avoid cliff far", rmClassID("Cliffs"), 16.0);
	int avoidNatives = rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 8.0);
	int stayNatives = rmCreateClassDistanceConstraint("stuff stays near natives", rmClassID("natives"), 6.0);
	int avoidNativesFar = rmCreateClassDistanceConstraint("stuff avoids natives far", rmClassID("natives"), 12.0);
	int avoidCattle = rmCreateTypeDistanceConstraint("cow avoid cow", cattleType, 60+PlayerNum);
	int avoidMountains = rmCreateClassDistanceConstraint("avoid mountains", classMountains, 1.0);
	
	// Avoid impassable land
	int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 20.0);
	int avoidPatchMin = rmCreateClassDistanceConstraint("avoid patch min", rmClassID("patch"), 4.0);
	int avoidPatch2 = rmCreateClassDistanceConstraint("avoid patch2", rmClassID("patch2"), 20.0);
	int avoidPatch2Min = rmCreateClassDistanceConstraint("avoid patch2 min", rmClassID("patch2"), 4.0);
	int avoidPatch3 = rmCreateClassDistanceConstraint("avoid patch3", rmClassID("patch3"), 20.0);
	int avoidPatch3Min = rmCreateClassDistanceConstraint("avoid patch3 min", rmClassID("patch3"), 4.0);
	int avoidPatch4 = rmCreateClassDistanceConstraint("avoid patch4", rmClassID("patch4"), 4.0);
	int avoidPatch4Min = rmCreateClassDistanceConstraint("avoid patch4 min", rmClassID("patch4"), 20.0);
	int avoidIslandMin=rmCreateClassDistanceConstraint("avoid island min", classIsland, 8.0);
	int avoidIslandShort=rmCreateClassDistanceConstraint("avoid island short", classIsland, 12.0);
	int avoidIsland=rmCreateClassDistanceConstraint("avoid island", classIsland, 16.0);
	int avoidIslandFar=rmCreateClassDistanceConstraint("avoid island far", classIsland, 32.0);
	int stayIsland=rmCreateClassDistanceConstraint("stay island", classIsland, 0.0);
	int avoidWaterShort = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 0.1);
	int avoidWater = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWaterFar = rmCreateTerrainDistanceConstraint("avoid water far", "Land", false, 20.0);
	int stayNearWater = rmCreateTerrainMaxDistanceConstraint("stay near water ", "water", true, 24.0);
	int stayInWater = rmCreateTerrainMaxDistanceConstraint("stay in water ", "water", true, 0.0);
	
	// VP avoidance
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 30.0);
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 12.0);
	int avoidTradeRouteShort = rmCreateTradeRouteDistanceConstraint("trade route short", 6.0);
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 4.0);
	int avoidTradeRouteSocketMin = rmCreateTradeRouteDistanceConstraint("trade route socket min", 4.0);
	int avoidTradeRouteSocketShort = rmCreateTradeRouteDistanceConstraint("trade route socket short", 8.0);
	int avoidTradeRouteSocket = rmCreateTypeDistanceConstraint("avoid trade route socket", "socketTradeRoute", 12.0);
	int avoidTradeRouteSocketFar = rmCreateTypeDistanceConstraint("avoid trade route socket far", "socketTradeRoute", 30.0);

	// AoP Avoidance
	int riverBankConstraint=rmCreateClassDistanceConstraint("river banks avoid each other", classRiverBank, 25.0);
	int riverBankUpperConstraint=rmCreateClassDistanceConstraint("river banks upper avoid each other", classRiverBankUpper, 17.0);
	int avoidPenalColony=rmCreateTypeDistanceConstraint("stay away from Penal Colony", "zpSocketPenalColony", 25.0);
	int avoidAboriginals=rmCreateTypeDistanceConstraint("stay away from Aboriginals", "zpSocketAboriginals", 25.0);
	int avoidPenalColonyShort=rmCreateTypeDistanceConstraint("stay away from Penal Colony Short", "zpSocketPenalColony", 12.0);
	int avoidAboriginalsShort=rmCreateTypeDistanceConstraint("stay away from Aboriginals Short", "zpSocketAboriginals", 12.0);
	int avoidGold=rmCreateTypeDistanceConstraint("avoid gold", "MineGold", 25.0);
	int avoidKOTH=rmCreateTypeDistanceConstraint("stay away from Kings Hill", "ypKingsHill", 30.0);
	int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", "deFishNilePerch", 15.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 3.0);

	// ____________________ Player Placement ____________________
	int teamZeroCount = rmGetNumberPlayersOnTeam(0);
	int teamOneCount = rmGetNumberPlayersOnTeam(1);

	
	// ____________________ Map Parameters ____________________
	// Continent
	int continentID = rmCreateArea("continent");
	rmSetAreaLocation(continentID, 0.5, 0.5);
	rmSetAreaWarnFailure(continentID, false);
	rmSetAreaSize(continentID,0.99);
	rmSetAreaCoherence(continentID, 1.0);
	rmSetAreaBaseHeight(continentID, 4.0);
	rmSetAreaSmoothDistance(continentID, 10);
	rmSetAreaHeightBlend(continentID, 1);
	rmSetAreaObeyWorldCircleConstraint(continentID, false);
	rmSetAreaMix(continentID, paintMix2); 
	rmBuildArea(continentID); 

	// Text
	rmSetStatusText("",0.20);

	//--------------------------- Waterfalls terrain --------------------------------

	// Upper Area

	int upperEast=rmCreateArea("upper east");
	rmSetAreaLocation(upperEast, 0.75, 0.85);
	rmSetAreaSize(upperEast, 0.1, 0.1);
	rmSetAreaWarnFailure(upperEast, false);
	rmSetAreaCliffType(upperEast, "Pampas");
	rmSetAreaCliffEdge(upperEast, 4, 0.2, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(upperEast, 6.0, 2.0, 0.3);
	rmSetAreaCoherence(upperEast, 0.7);
	rmSetAreaSmoothDistance(upperEast, 12);
	rmAddAreaToClass(upperEast, classMountains);
	rmSetAreaHeightBlend(upperEast, 1);
	rmSetAreaCliffPainting(upperEast, false, false, true, 1.5, true);
	rmBuildArea(upperEast);

	int upperWest=rmCreateArea("upper west");
	rmSetAreaLocation(upperWest, 0.25, 0.85);
	rmSetAreaSize(upperWest, 0.1, 0.1);
	rmSetAreaWarnFailure(upperWest, false);
	rmSetAreaCliffType(upperWest, "Pampas");
	rmSetAreaCliffEdge(upperWest, 4, 0.2, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(upperWest, 6.0, 2.0, 0.3);
	rmSetAreaCoherence(upperWest, 0.7);
	rmSetAreaSmoothDistance(upperWest, 12);
	rmAddAreaToClass(upperWest, classMountains);
	rmSetAreaHeightBlend(upperWest, 1);
	rmSetAreaCliffPainting(upperWest, false, false, true, 1.5, true);
	rmBuildArea(upperWest);
	
	int upperAreaID=rmCreateArea("upper area");
	rmSetAreaLocation(upperAreaID, 0.5, 0.9);
	rmSetAreaSize(upperAreaID, 0.25, 0.25);
	rmSetAreaWarnFailure(upperAreaID, false);
	rmSetAreaElevationVariation(upperAreaID, 4.0);
	rmSetAreaElevationType(upperAreaID, cElevTurbulence);
	rmSetAreaElevationMinFrequency(upperAreaID, 0.09);
	rmSetAreaElevationOctaves(upperAreaID, 3);
	rmSetAreaElevationPersistence(upperAreaID, 0.2);
	rmSetAreaElevationNoiseBias(upperAreaID, 1);
	rmSetAreaCoherence(upperAreaID, 1.0);
	rmSetAreaSmoothDistance(upperAreaID, 30);
	rmSetAreaBaseHeight(upperAreaID, 8.0);
	rmAddAreaToClass(upperAreaID, classMountains);
	rmSetAreaHeightBlend(upperAreaID, 1);
	rmAddAreaInfluenceSegment(upperAreaID, 0.2, 0.9, 0.8, 0.9);
	rmBuildArea(upperAreaID);

	// Define upper trade route

	int tradeRouteID = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteID, 0.1, 0.8);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.2, 0.8);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.3, 0.9);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.7, 0.9);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.8, 0.8);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.9, 0.8);
	rmBuildTradeRoute(tradeRouteID, "dirt");

	int socket2ID=rmCreateObjectDef("sockets to dock Trade Posts Land");
	rmSetObjectDefTradeRouteID(socket2ID, tradeRouteID);
	rmAddObjectDefItem(socket2ID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socket2ID, true);
	rmSetObjectDefMinDistance(socket2ID, 2.0);
	rmSetObjectDefMaxDistance(socket2ID, 8.0);

	vector socketLoc2  = rmGetTradeRouteWayPoint(tradeRouteID, 0.1);

	// Waterfall lakes

	int downerLakeID=rmCreateArea("Downer Lake");
	rmSetAreaWaterType(downerLakeID, "ZP Riverina Waterfalls");
	rmSetAreaSize(downerLakeID, 0.05, 0.05);
	rmSetAreaCoherence(downerLakeID, 1.0);
	rmSetAreaLocation(downerLakeID, 0.5, 0.60);
	rmSetAreaSmoothDistance(downerLakeID, 10);
	rmBuildArea(downerLakeID);

	int upperLakeID=rmCreateArea("Upper Lake");
	rmSetAreaWaterType(upperLakeID, "ZP Riverina Waterfalls");
	if (cNumberNonGaiaPlayers == 6)
		rmSetAreaSize(upperLakeID, 0.043, 0.043);
	else if (cNumberNonGaiaPlayers == 8)
		rmSetAreaSize(upperLakeID, 0.044, 0.044);
	else
		rmSetAreaSize(upperLakeID, 0.05, 0.05);
	rmSetAreaCoherence(upperLakeID, 1.0);
	rmSetAreaBaseHeight(upperLakeID, 7.0);
	if (cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 5 || cNumberNonGaiaPlayers == 7 || cNumberNonGaiaPlayers == 4)
		rmSetAreaLocation(upperLakeID, 0.5, 0.85);
	else
		rmSetAreaLocation(upperLakeID, 0.5, 0.845);
	rmAddAreaToClass(upperLakeID, classMountains);
	rmSetAreaSmoothDistance(upperLakeID, 10);
	rmBuildArea(upperLakeID);

	// Upper River

	int upperRiverD=rmCreateArea("Upper River");
	rmSetAreaWaterType(upperRiverD, "ZP Riverina Waterfalls");
	rmSetAreaSize(upperRiverD, 0.06, 0.06);
	rmSetAreaCoherence(upperRiverD, 1.0);
	rmSetAreaBaseHeight(upperRiverD, 7.0);
	rmSetAreaLocation(upperRiverD, 0.5, 0.85);
	rmSetAreaSmoothDistance(upperRiverD, 10);
	rmAddAreaInfluenceSegment(upperRiverD, 0.7, 1.0, 0.5, 0.85);
	rmAddAreaInfluenceSegment(upperRiverD, 0.3, 1.0, 0.5, 0.85);
	rmBuildArea(upperRiverD);

	// Downer lake banks

	int leftBankDowner=rmCreateArea("left bank downer");
	rmSetAreaLocation(leftBankDowner, 0.6, 0.6);
	if (cNumberNonGaiaPlayers <=3 )
		rmSetAreaSize(leftBankDowner, 0.025, 0.025);
	else
		rmSetAreaSize(leftBankDowner, 0.033, 0.033);
	rmSetAreaWarnFailure(leftBankDowner, false);
	rmSetAreaCoherence(leftBankDowner, 0.99);
	rmSetAreaSmoothDistance(leftBankDowner, 12);
	rmSetAreaBaseHeight(leftBankDowner, 2.0);
	rmSetAreaMix(leftBankDowner, paintMix1);
	rmSetAreaHeightBlend(leftBankDowner, 8);
	rmAddAreaToClass(leftBankDowner, classRiverBank);
	rmSetAreaCliffPainting(leftBankDowner, true, false, true, 1.5, true);
	rmAddAreaInfluenceSegment(leftBankDowner, 0.6, 0.7, 0.6, 0.5);
	rmBuildArea(leftBankDowner);

	int rightBankDowner=rmCreateArea("right bank downer");
	rmSetAreaLocation(rightBankDowner, 0.4, 0.6);
	if (cNumberNonGaiaPlayers <=3 )
		rmSetAreaSize(rightBankDowner, 0.025, 0.025);
	else
		rmSetAreaSize(rightBankDowner, 0.033, 0.033);
	rmSetAreaWarnFailure(rightBankDowner, false);
	rmSetAreaCoherence(rightBankDowner, 0.99);
	rmSetAreaSmoothDistance(rightBankDowner, 12);
	rmSetAreaBaseHeight(rightBankDowner, 2.0);
	rmSetAreaMix(rightBankDowner, paintMix1);
	rmSetAreaHeightBlend(rightBankDowner, 8);
	rmAddAreaToClass(rightBankDowner, classRiverBank);
	rmSetAreaCliffPainting(rightBankDowner, true, false, true, 1.5, true);
	rmAddAreaInfluenceSegment(rightBankDowner, 0.4, 0.7, 0.4, 0.5);
	rmBuildArea(rightBankDowner);
	
	// Upper lake banks

	int middleBankUpper=rmCreateArea("middle bank upper");
	rmSetAreaLocation(middleBankUpper, 0.5, 0.9);
	if (cNumberNonGaiaPlayers <=3 )
		rmSetAreaSize(middleBankUpper, 0.025, 0.025);
	else
		rmSetAreaSize(middleBankUpper, 0.02, 0.02);
	rmSetAreaWarnFailure(middleBankUpper, false);
	rmSetAreaMix(middleBankUpper, paintMix1);
	rmSetAreaCoherence(middleBankUpper, 0.9);
	rmSetAreaSmoothDistance(middleBankUpper, 12);
	rmSetAreaBaseHeight(middleBankUpper, 8.0);
	rmSetAreaHeightBlend(middleBankUpper, 8);
	rmAddAreaToClass(middleBankUpper, classRiverBankUpper);
	rmAddAreaInfluenceSegment(middleBankUpper, 0.45, 1.0, 0.5, 0.85);
	rmAddAreaInfluenceSegment(middleBankUpper, 0.55, 1.0, 0.5, 0.85);
	rmAddAreaInfluenceSegment(middleBankUpper, 0.55, 1.0, 0.45, 1.0);
	rmBuildArea(middleBankUpper);

	int leftBankUpper=rmCreateArea("left bank upper");
	if (cNumberNonGaiaPlayers <=3)
		rmSetAreaLocation(leftBankUpper, 0.63, 0.9);
	else
		rmSetAreaLocation(leftBankUpper, 0.6, 0.9);
	rmSetAreaSize(leftBankUpper, 0.033, 0.033);
	rmSetAreaWarnFailure(leftBankUpper, false);
	rmSetAreaMix(leftBankUpper, paintMix1);
	rmSetAreaCoherence(leftBankUpper, 0.7);
	rmSetAreaSmoothDistance(leftBankUpper, 12);
	rmSetAreaBaseHeight(leftBankUpper, 8.0);
	rmSetAreaHeightBlend(leftBankUpper, 8);
	rmAddAreaToClass(leftBankUpper, classRiverBankUpper);
	rmAddAreaConstraint(leftBankUpper, riverBankUpperConstraint);
	rmAddAreaInfluenceSegment(leftBankUpper, 0.7, 1.0, 0.6, 0.74);
	rmBuildArea(leftBankUpper);

	int rightBankUpper=rmCreateArea("right bank upper");
	if (cNumberNonGaiaPlayers <=3)
		rmSetAreaLocation(rightBankUpper, 0.37, 0.9);
	else
		rmSetAreaLocation(rightBankUpper, 0.4, 0.9);
	rmSetAreaSize(rightBankUpper, 0.033, 0.033);
	rmSetAreaWarnFailure(rightBankUpper, false);
	rmSetAreaMix(rightBankUpper, paintMix1);
	rmSetAreaCoherence(rightBankUpper, 0.7);
	rmSetAreaSmoothDistance(rightBankUpper, 12);
	rmSetAreaBaseHeight(rightBankUpper, 8.0);
	rmSetAreaHeightBlend(rightBankUpper, 8);
	rmAddAreaToClass(rightBankUpper, classRiverBankUpper);
	rmAddAreaConstraint(rightBankUpper, riverBankUpperConstraint);
	rmAddAreaInfluenceSegment(rightBankUpper, 0.3, 1.0, 0.4, 0.74);
	rmBuildArea(rightBankUpper);

	rmSetStatusText("",0.30); 

	// Waterfall Groupings

	int waterfallGroupingID = -1;
	waterfallGroupingID = rmCreateGrouping("waterfall", "Waterfall");
	if (cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 6 || cNumberNonGaiaPlayers == 7 || cNumberNonGaiaPlayers == 8)
		rmPlaceGroupingAtLoc(waterfallGroupingID, 0, 0.5, 0.72);
	else if (cNumberNonGaiaPlayers == 5)
		rmPlaceGroupingAtLoc(waterfallGroupingID, 0, 0.5, 0.717);
	else
		rmPlaceGroupingAtLoc(waterfallGroupingID, 0, 0.5, 0.715);

	int waterfallBlockerID = -1;
	waterfallBlockerID = rmCreateGrouping("waterfall_blocker", "Waterfall_Blocker");
	if (cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 5 || cNumberNonGaiaPlayers == 6 || cNumberNonGaiaPlayers == 7 || cNumberNonGaiaPlayers == 8)
		rmPlaceGroupingAtLoc(waterfallBlockerID, 0, 0.5, 0.72);
	else
		rmPlaceGroupingAtLoc(waterfallBlockerID, 0, 0.5, 0.715);

	// Bridges

	int bridgeGroupingID = -1;
	bridgeGroupingID = rmCreateGrouping("river bridge", "mississippi_bridge_01");
	if (cNumberNonGaiaPlayers == 2 || cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 7 || cNumberNonGaiaPlayers == 5){
		rmPlaceGroupingAtLoc(bridgeGroupingID, 0, 0.42, 0.9+rmXMetersToFraction(10));
		rmPlaceGroupingAtLoc(bridgeGroupingID, 0, 0.575, 0.9+rmXMetersToFraction(10));
	}
	if (cNumberNonGaiaPlayers == 4 || cNumberNonGaiaPlayers == 8){
		rmPlaceGroupingAtLoc(bridgeGroupingID, 0, 0.42, 0.9+rmXMetersToFraction(2));
		rmPlaceGroupingAtLoc(bridgeGroupingID, 0, 0.575, 0.9+rmXMetersToFraction(2));
	}
	if (cNumberNonGaiaPlayers == 6){
		rmPlaceGroupingAtLoc(bridgeGroupingID, 0, 0.42, 0.9-rmXMetersToFraction(3));
		rmPlaceGroupingAtLoc(bridgeGroupingID, 0, 0.575, 0.9-rmXMetersToFraction(3));
	}

	int bridgeSite1 = rmCreateArea ("bridge site 1");
	rmSetAreaSize(bridgeSite1, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
	if (cNumberNonGaiaPlayers == 2 || cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 7 || cNumberNonGaiaPlayers == 5)
		rmSetAreaLocation(bridgeSite1, 0.42-rmXMetersToFraction(28), 0.9+rmXMetersToFraction(10));
	if (cNumberNonGaiaPlayers == 4 || cNumberNonGaiaPlayers == 8)
		rmSetAreaLocation(bridgeSite1, 0.42-rmXMetersToFraction(28), 0.9+rmXMetersToFraction(2));
	if (cNumberNonGaiaPlayers == 6)
		rmSetAreaLocation(bridgeSite1, 0.42-rmXMetersToFraction(28), 0.9-rmXMetersToFraction(3));
	rmSetAreaCoherence(bridgeSite1, 1);
	rmSetAreaMix(bridgeSite1, paintMix1);
	rmSetAreaSmoothDistance(bridgeSite1, 20);
	rmSetAreaBaseHeight(bridgeSite1, 8.0);
	rmBuildArea(bridgeSite1);

	int bridgeSite2 = rmCreateArea ("bridge site 2");
	rmSetAreaSize(bridgeSite2, rmAreaTilesToFraction(450.0), rmAreaTilesToFraction(550.0));
	if (cNumberNonGaiaPlayers == 2 || cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 7 || cNumberNonGaiaPlayers == 5)
		rmSetAreaLocation(bridgeSite2, 0.42+rmXMetersToFraction(20), 0.9+rmXMetersToFraction(10));
	if (cNumberNonGaiaPlayers == 4 || cNumberNonGaiaPlayers == 8)
		rmSetAreaLocation(bridgeSite2, 0.42+rmXMetersToFraction(20), 0.9+rmXMetersToFraction(2));
	if (cNumberNonGaiaPlayers == 6)
		rmSetAreaLocation(bridgeSite2, 0.42+rmXMetersToFraction(20), 0.9-rmXMetersToFraction(3));
	rmSetAreaCoherence(bridgeSite2, 1);
	rmSetAreaMix(bridgeSite2, paintMix1);
	rmSetAreaSmoothDistance(bridgeSite2, 20);
	rmSetAreaBaseHeight(bridgeSite2, 8.0);
	rmBuildArea(bridgeSite2);

	int bridgeSite3 = rmCreateArea ("bridge site 3");
	rmSetAreaSize(bridgeSite3, rmAreaTilesToFraction(550.0), rmAreaTilesToFraction(550.0));
	if (cNumberNonGaiaPlayers == 2 || cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 7 || cNumberNonGaiaPlayers == 5)
		rmSetAreaLocation(bridgeSite3, 0.575+rmXMetersToFraction(30), 0.9+rmXMetersToFraction(10));
	if (cNumberNonGaiaPlayers == 4 || cNumberNonGaiaPlayers == 8)
		rmSetAreaLocation(bridgeSite3, 0.575+rmXMetersToFraction(30), 0.9+rmXMetersToFraction(2));
	if (cNumberNonGaiaPlayers == 6)
		rmSetAreaLocation(bridgeSite3, 0.575+rmXMetersToFraction(30), 0.9-rmXMetersToFraction(3));
	rmSetAreaCoherence(bridgeSite3, 1);
	rmSetAreaMix(bridgeSite3, paintMix1);
	rmSetAreaSmoothDistance(bridgeSite3, 20);
	rmSetAreaBaseHeight(bridgeSite3, 8.0);
	rmBuildArea(bridgeSite3);

	int bridgeSite4 = rmCreateArea ("bridge site 4");
	rmSetAreaSize(bridgeSite4, rmAreaTilesToFraction(450.0), rmAreaTilesToFraction(450.0));
	if (cNumberNonGaiaPlayers == 2 || cNumberNonGaiaPlayers == 3 || cNumberNonGaiaPlayers == 7 || cNumberNonGaiaPlayers == 5 )
		rmSetAreaLocation(bridgeSite4, 0.575-rmXMetersToFraction(20), 0.9+rmXMetersToFraction(10));
	if (cNumberNonGaiaPlayers == 4 || cNumberNonGaiaPlayers == 8)
		rmSetAreaLocation(bridgeSite4, 0.575-rmXMetersToFraction(20), 0.9+rmXMetersToFraction(2));
	if (cNumberNonGaiaPlayers == 6)
		rmSetAreaLocation(bridgeSite4, 0.575-rmXMetersToFraction(20), 0.9-rmXMetersToFraction(3));
	rmSetAreaCoherence(bridgeSite4, 1);
	rmSetAreaMix(bridgeSite4, paintMix1);
	rmSetAreaSmoothDistance(bridgeSite4, 20);
	rmSetAreaBaseHeight(bridgeSite4, 8.0);
	rmBuildArea(bridgeSite4);

	// Place King's Hill
	if (rmGetIsKOTH() == true) {
		if (cNumberNonGaiaPlayers <=3 )
			ypKingsHillPlacer(0.5, 0.88, 0.00, 0);
		else
			ypKingsHillPlacer(0.5, 0.95, 0.00, 0);
	}

	// Trade Route Sockets

	socketLoc2  = rmGetTradeRouteWayPoint(tradeRouteID, 0.2);
	rmPlaceObjectDefAtPoint(socket2ID, 0, socketLoc2);

	if (cNumberNonGaiaPlayers > 2){
		socketLoc2  = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
		rmPlaceObjectDefAtPoint(socket2ID, 0, socketLoc2);
	}

	socketLoc2  = rmGetTradeRouteWayPoint(tradeRouteID, 0.8);
	rmPlaceObjectDefAtPoint(socket2ID, 0, socketLoc2);

	// Waterfall Cliffs

	int leftWaterfallCliff=rmCreateArea("left waterfall cliff");
	rmSetAreaLocation(leftWaterfallCliff, 0.45, 0.73);
	rmSetAreaSize(leftWaterfallCliff, 0.005, 0.005);
	rmSetAreaWarnFailure(leftWaterfallCliff, false);
	rmSetAreaCliffType(leftWaterfallCliff, "Pampas");
	rmSetAreaCliffEdge(leftWaterfallCliff, 1, 1.0, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(leftWaterfallCliff, 0.0, 0.0, 0.3);
	rmSetAreaCoherence(leftWaterfallCliff, 1.0);
	rmSetAreaSmoothDistance(leftWaterfallCliff, 12);
	rmSetAreaBaseHeight(leftWaterfallCliff, 8.0);
	rmSetAreaHeightBlend(leftWaterfallCliff, 1);
	rmAddAreaToClass(leftWaterfallCliff, classCliff);
	rmSetAreaCliffPainting(leftWaterfallCliff, true, false, true, 1.5, true);
	rmBuildArea(leftWaterfallCliff);

	int rightWaterfallCliff=rmCreateArea("right waterfall cliff");
	rmSetAreaLocation(rightWaterfallCliff, 0.55, 0.73);
	rmSetAreaSize(rightWaterfallCliff, 0.005, 0.005);
	rmSetAreaWarnFailure(rightWaterfallCliff, false);
	rmSetAreaCliffType(rightWaterfallCliff, "Pampas");
	rmSetAreaCliffEdge(rightWaterfallCliff, 1, 1.0, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(rightWaterfallCliff, 0.0, 0.0, 0.3);
	rmSetAreaCoherence(rightWaterfallCliff, 1.0);
	rmSetAreaSmoothDistance(rightWaterfallCliff, 12);
	rmSetAreaBaseHeight(rightWaterfallCliff, 8.0);
	rmSetAreaHeightBlend(rightWaterfallCliff, 1);
	rmAddAreaToClass(rightWaterfallCliff, classCliff);
	rmSetAreaCliffPainting(rightWaterfallCliff, true, false, true, 1.5, true);
	rmBuildArea(rightWaterfallCliff);

	int leftDecorativeCliff=rmCreateArea("left waterfall cliff irregular");
	rmSetAreaLocation(leftDecorativeCliff, 0.43, 0.72);
	rmSetAreaSize(leftDecorativeCliff, 0.006, 0.006);
	rmSetAreaWarnFailure(leftDecorativeCliff, false);
	rmSetAreaCliffType(leftDecorativeCliff, "Pampas");
	rmSetAreaCliffEdge(leftDecorativeCliff, 1, 1.0, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(leftDecorativeCliff, 0.0, 0.0, 0.3);
	rmSetAreaCoherence(leftDecorativeCliff, 0.5);
	rmSetAreaSmoothDistance(leftDecorativeCliff, 12);
	rmSetAreaBaseHeight(leftDecorativeCliff, 8.0);
	rmSetAreaHeightBlend(leftDecorativeCliff, 1);
	rmAddAreaConstraint(leftDecorativeCliff, avoidWaterShort);
	rmAddAreaToClass(leftDecorativeCliff, classCliff);
	rmSetAreaCliffPainting(leftDecorativeCliff, true, false, true, 1.5, true);
	rmBuildArea(leftDecorativeCliff);

	int rightDecorativeCliff=rmCreateArea("right waterfall cliff irregular");
	rmSetAreaLocation(rightDecorativeCliff, 0.57, 0.72);
	rmSetAreaSize(rightDecorativeCliff, 0.006, 0.006);
	rmSetAreaWarnFailure(rightDecorativeCliff, false);
	rmSetAreaCliffType(rightDecorativeCliff, "Pampas");
	rmSetAreaCliffEdge(rightDecorativeCliff, 1, 1.0, 0.0, 0.0, 0);
	rmSetAreaCliffHeight(rightDecorativeCliff, 0.0, 0.0, 0.3);
	rmSetAreaCoherence(rightDecorativeCliff, 0.5);
	rmSetAreaSmoothDistance(rightDecorativeCliff, 12);
	rmSetAreaBaseHeight(rightDecorativeCliff, 8.0);
	rmSetAreaHeightBlend(rightDecorativeCliff, 1);
	rmAddAreaConstraint(rightDecorativeCliff, avoidWaterShort);
	rmAddAreaToClass(rightDecorativeCliff, classCliff);
	rmSetAreaCliffPainting(rightDecorativeCliff, true, false, true, 1.5, true);
	rmBuildArea(rightDecorativeCliff);

	// Downer River

	int riverID2 = rmRiverCreate(-5, "ZP Riverina Waterfalls", 5, 2, 15, 15); //  (-1, "new england lake", 18, 14, 5, 5)
	rmRiverAddWaypoint(riverID2, 0.5, 0.55);
	rmRiverAddWaypoint(riverID2, 0.5, 0.5);
	rmRiverAddWaypoint(riverID2, 0.4, 0.4);
	rmRiverAddWaypoint(riverID2, 0.6, 0.2);
	rmRiverAddWaypoint(riverID2, 0.4, 0.0);
	rmRiverSetBankNoiseParams(riverID2, 0.00, 0, 0.0, 0.0, 0.0, 0.0);
	rmRiverSetShallowRadius(riverID2, 15);
	rmRiverAddShallow(riverID2, 0.9);
	rmRiverBuild(riverID2);  


	// River Trade route

	int tradeRouteID4 = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.6);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.4, 0.39);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.6, 0.19);
	rmAddTradeRouteWaypoint(tradeRouteID4, 0.4, 0.0);
	rmBuildTradeRoute(tradeRouteID4, "australia_river_trail");

	// River Banks

	int leftBankBig=rmCreateArea("left bank big");
	rmSetAreaLocation(leftBankBig, 0.7, 0.4);
	rmSetAreaSize(leftBankBig, 0.15, 0.15);
	rmSetAreaWarnFailure(leftBankBig, false);
	rmSetAreaCoherence(leftBankBig, 0.99);
	rmSetAreaSmoothDistance(leftBankBig, 12);
	rmSetAreaBaseHeight(leftBankBig, 1.0);
	rmSetAreaMix(leftBankBig, paintMix1);
	rmSetAreaHeightBlend(leftBankBig, 8);
	rmAddAreaConstraint(leftBankBig, avoidTradeRouteShort);
	rmAddAreaConstraint(leftBankBig, avoidCliff);
	rmAddAreaConstraint(leftBankBig, avoidMountains);
	rmAddAreaInfluenceSegment(leftBankBig, 0.6, 0.1, 0.7, 0.4);
	rmAddAreaInfluenceSegment(leftBankBig, 0.7, 0.4, 0.6, 0.5);
	rmBuildArea(leftBankBig);

	int rightBankBig=rmCreateArea("right bank big");
	rmSetAreaLocation(rightBankBig, 0.3, 0.4);
	rmSetAreaSize(rightBankBig, 0.15, 0.15);
	rmSetAreaWarnFailure(rightBankBig, false);
	rmSetAreaCoherence(rightBankBig, 0.99);
	rmSetAreaSmoothDistance(rightBankBig, 12);
	rmSetAreaBaseHeight(rightBankBig, 1.0);
	rmSetAreaMix(rightBankBig, paintMix1);
	rmSetAreaHeightBlend(rightBankBig, 8);
	rmAddAreaConstraint(rightBankBig, avoidTradeRouteShort);
	rmAddAreaConstraint(rightBankBig, avoidCliff);
	rmAddAreaConstraint(rightBankBig, avoidMountains);
	rmAddAreaInfluenceSegment(rightBankBig, 0.3, 0.0, 0.5, 0.3);
	rmAddAreaInfluenceSegment(rightBankBig, 0.5, 0.3, 0.4, 0.4);
	rmBuildArea(rightBankBig);

	// River Sockets

	int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID4);
	rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);
	rmSetObjectDefAllowOverlap(socketID, true);
	rmSetObjectDefMinDistance(socketID, 0.0);
	if (cNumberNonGaiaPlayers ==6)
		rmSetObjectDefMaxDistance(socketID, 9.0);
	else if (cNumberNonGaiaPlayers ==7)
		rmSetObjectDefMaxDistance(socketID, 10.0);
	else if (cNumberNonGaiaPlayers ==8)
		rmSetObjectDefMaxDistance(socketID, 13.0);
	else
		rmSetObjectDefMaxDistance(socketID, 6.0);

	rmPlaceObjectDefAtLoc(socketID, 0, 0.5-rmXMetersToFraction(25), 0.55);
	rmPlaceObjectDefAtLoc(socketID, 0, 0.4+rmXMetersToFraction(45), 0.45);
	rmPlaceObjectDefAtLoc(socketID, 0, 0.55-rmXMetersToFraction(23), 0.25-rmXMetersToFraction(23));
	if (cNumberNonGaiaPlayers >=7)
		rmPlaceObjectDefAtLoc(socketID, 0, 0.52+rmXMetersToFraction(15), 0.28+rmXMetersToFraction(15));
	else
		rmPlaceObjectDefAtLoc(socketID, 0, 0.55+rmXMetersToFraction(15), 0.25+rmXMetersToFraction(15));

	// Downer terrain

	int eastIsland=rmCreateArea("east island");
	rmSetAreaLocation(eastIsland, 0.8, 0.5);
	rmSetAreaSize(eastIsland, 0.25, 0.25);
	rmSetAreaWarnFailure(eastIsland, false);
	rmSetAreaCoherence(eastIsland, 0.99);
	rmSetAreaElevationVariation(eastIsland, 4.0);
	rmSetAreaElevationType(eastIsland, cElevTurbulence);
	rmSetAreaElevationMinFrequency(eastIsland, 0.09);
	rmSetAreaElevationOctaves(eastIsland, 3);
	rmSetAreaElevationPersistence(eastIsland, 0.2);
	rmSetAreaElevationNoiseBias(eastIsland, 1);
	rmSetAreaSmoothDistance(eastIsland, 30);
	rmSetAreaBaseHeight(eastIsland, 1.0);
	rmSetAreaMix(eastIsland, paintMix1);
	rmSetAreaHeightBlend(eastIsland, 8);
	rmAddAreaConstraint(eastIsland, avoidTradeRouteFar);
	rmAddAreaConstraint(eastIsland, avoidCliff);
	rmAddAreaConstraint(eastIsland, avoidMountains);
	rmBuildArea(eastIsland);

	int westIsland=rmCreateArea("west island");
	rmSetAreaLocation(westIsland, 0.2, 0.5);
	rmSetAreaSize(westIsland, 0.25, 0.25);
	rmSetAreaWarnFailure(westIsland, false);
	rmSetAreaCoherence(westIsland, 0.99);
	rmSetAreaElevationVariation(westIsland, 4.0);
	rmSetAreaElevationType(westIsland, cElevTurbulence);
	rmSetAreaElevationMinFrequency(westIsland, 0.09);
	rmSetAreaElevationOctaves(westIsland, 3);
	rmSetAreaElevationPersistence(westIsland, 0.2);
	rmSetAreaElevationNoiseBias(westIsland, 1);
	rmSetAreaSmoothDistance(westIsland, 30);
	rmSetAreaBaseHeight(westIsland, 1.0);
	rmSetAreaMix(westIsland, paintMix1);
	rmSetAreaHeightBlend(westIsland, 8);
	rmAddAreaConstraint(westIsland, avoidTradeRouteFar);
	rmAddAreaConstraint(westIsland, avoidCliff);
	rmAddAreaConstraint(westIsland, avoidMountains);
	rmBuildArea(westIsland);

	rmSetStatusText("",0.40); 

	//--------------------------- Natives --------------------------------

	// Penal Colonies

	int penalColony1Type = rmRandInt(1, 5);
	int penalColony2Type = rmRandInt(1, 5);
	int penalColony3Type = rmRandInt(1, 5);
	int penalColony4Type = rmRandInt(1, 5);

	int penalColony1ID = rmCreateGrouping("jewish 1", "Penal_Colony_0"+penalColony1Type);
	int penalColony2ID = rmCreateGrouping("jewish 2", "Penal_Colony_0"+penalColony2Type);
	int penalColony3ID = rmCreateGrouping("jewish 3", "Penal_Colony_0"+penalColony3Type);
	int penalColony4ID = rmCreateGrouping("jewish 4", "Penal_Colony_0"+penalColony4Type);
	
	rmSetGroupingMinDistance(penalColony1ID, 0);
	rmSetGroupingMaxDistance(penalColony1ID, 30);
	rmSetGroupingMinDistance(penalColony2ID, 0);
	rmSetGroupingMaxDistance(penalColony2ID, 30);
	rmSetGroupingMinDistance(penalColony3ID, 0);
	rmSetGroupingMaxDistance(penalColony3ID, 30);
	rmSetGroupingMinDistance(penalColony4ID, 0);
	rmSetGroupingMaxDistance(penalColony4ID, 30);

	if (cNumberNonGaiaPlayers >=6){
		rmPlaceGroupingAtLoc(penalColony1ID, 0, 0.2, 0.3, 1);
		rmPlaceGroupingAtLoc(penalColony2ID, 0, 0.8, 0.3, 1);
		rmPlaceGroupingAtLoc(penalColony3ID, 0, 0.2, 0.55, 1);
		rmPlaceGroupingAtLoc(penalColony4ID, 0, 0.8, 0.55, 1);
	}
	else {
		rmPlaceGroupingAtLoc(penalColony1ID, 0, 0.2, 0.4, 1);
		rmPlaceGroupingAtLoc(penalColony2ID, 0, 0.8, 0.4, 1);
	}

	//Aboriginal Villages

	int aboriginalVillage1Type = rmRandInt(1, 5);
	int aboriginalVillage2Type = rmRandInt(1, 5);

	int aboriginalVillage1ID = rmCreateGrouping("aboriginal 1", "Native_Aboriginal_0"+aboriginalVillage1Type);
	int aboriginalVillage2ID = rmCreateGrouping("aboriginal 2", "Native_Aboriginal_0"+aboriginalVillage2Type);
	
	rmSetGroupingMinDistance(aboriginalVillage1ID, 0);
	rmSetGroupingMaxDistance(aboriginalVillage1ID, 40);
	rmSetGroupingMinDistance(aboriginalVillage2ID, 0);
	rmSetGroupingMaxDistance(aboriginalVillage2ID, 40);

	rmAddGroupingConstraint(aboriginalVillage1ID, avoidTradeRouteSocketFar);
	rmAddGroupingConstraint(aboriginalVillage2ID, avoidTradeRouteSocketFar);

	rmPlaceGroupingAtLoc(aboriginalVillage1ID, 0, 0.3, 0.8, 1);
	rmPlaceGroupingAtLoc(aboriginalVillage2ID, 0, 0.7, 0.8, 1);

	rmSetStatusText("",0.50); 

	//---------------------------------- Place Players -----------------------------

	// Place Town Centers
	rmSetTeamSpacingModifier(0.6);

    float teamStartLoc = rmRandFloat(0.0, 1.0);
	if(cNumberTeams > 2)
	{
		rmSetPlacementSection(0.70, 0.30);
		rmSetTeamSpacingModifier(0.75);
		rmPlacePlayersCircular(0.30, 0.35, 0);
	}
	else
	{
		// 4 players in 2 teams
		if (teamStartLoc > 0.5)
		{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.20, 0.40);
			rmPlacePlayersCircular(0.30, 0.35, rmDegreesToRadians(5.0));
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.60, 0.80);
			rmPlacePlayersCircular(0.30, 0.35, rmDegreesToRadians(5.0));
		}
		else
		{
			rmSetPlacementTeam(0);
			rmSetPlacementSection(0.60, 0.80);
			rmPlacePlayersCircular(0.30, 0.35, rmDegreesToRadians(5.0));
			rmSetPlacementTeam(1);
			rmSetPlacementSection(0.20, 0.40);
			rmPlacePlayersCircular(0.30, 0.35, rmDegreesToRadians(5.0));
		}
	}

	// Insert Players
	int TCfloat = -1;
	if (cNumberTeams == 2)
		TCfloat = 35;
	else 
		TCfloat = 70;


	int TCID = rmCreateObjectDef("player TC");
	if (rmGetNomadStart())
		{
		rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
		}
	else{
		rmAddObjectDefItem(TCID, "TownCenter", 1, 0.0);
	}

	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, TCfloat);
	rmAddObjectDefConstraint(TCID, avoidTownCenterFar);
	rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, avoidImpassableLand);
	rmAddObjectDefConstraint(TCID, avoidPenalColony);
	rmAddObjectDefConstraint(TCID, avoidMountains);
	rmAddObjectDefConstraint(TCID, avoidWaterFar);
  

	//Player resources

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(startingUnits, 5.0);
	rmSetObjectDefMaxDistance(startingUnits, 10.0);
	rmAddObjectDefConstraint(startingUnits, avoidAll);
	rmAddObjectDefConstraint(startingUnits, avoidImpassableLand);

	int playerMineID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerMineID, "MineGold", 1, 0);
	rmSetObjectDefMinDistance(playerMineID, 10.0);
	rmSetObjectDefMaxDistance(playerMineID, 30.0);
	rmAddObjectDefConstraint(playerMineID, avoidImpassableLand); 

	int playerDeerID=rmCreateObjectDef("player deer");
	rmAddObjectDefItem(playerDeerID, food2, rmRandInt(7,10), 10.0);
	rmSetObjectDefMinDistance(playerDeerID, 15.0);
	rmSetObjectDefMaxDistance(playerDeerID, 30.0);
	rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
	rmSetObjectDefCreateHerd(playerDeerID, true);

	int playerNuggetID=rmCreateObjectDef("player nugget");
	rmAddObjectDefItem(playerNuggetID, "nugget", 1, 0.0);
	rmSetObjectDefMinDistance(playerNuggetID, 15.0);
	rmSetObjectDefMaxDistance(playerNuggetID, 18.0);
	rmAddObjectDefConstraint(playerNuggetID, avoidAll);
	rmAddObjectDefConstraint(playerNuggetID, avoidPenalColony);
	rmAddObjectDefConstraint(playerNuggetID, avoidImpassableLand);

	int playerLombardID=rmCreateObjectDef("player lombard");
	rmAddObjectDefItem(playerLombardID, "deLombard", 1, 0.0);
	rmSetObjectDefMinDistance(playerLombardID, 12.0);
	rmSetObjectDefMaxDistance(playerLombardID, 16.0);
	rmAddObjectDefConstraint(playerLombardID, avoidAll);
	rmAddObjectDefConstraint(playerLombardID, avoidPenalColony);
	rmAddObjectDefConstraint(playerLombardID, avoidImpassableLand);

	int playerSaloonID=rmCreateObjectDef("player saloon");
	rmAddObjectDefItem(playerSaloonID, "deTavern", 1, 0.0);
	rmSetObjectDefMinDistance(playerSaloonID, 12.0);
	rmSetObjectDefMaxDistance(playerSaloonID, 16.0);
	rmAddObjectDefConstraint(playerSaloonID, avoidAll);
	rmAddObjectDefConstraint(playerSaloonID, avoidImpassableLand);

	int playerCommunityPlazaID=rmCreateObjectDef("player community plaza");
	rmAddObjectDefItem(playerCommunityPlazaID, "CommunityPlaza", 1, 0.0);
	rmSetObjectDefMinDistance(playerCommunityPlazaID, 12.0);
	rmSetObjectDefMaxDistance(playerCommunityPlazaID, 16.0);
	rmAddObjectDefConstraint(playerCommunityPlazaID, avoidAll);
	rmAddObjectDefConstraint(playerCommunityPlazaID, avoidImpassableLand);

	int playerMonID=rmCreateObjectDef("player monastery");
	rmAddObjectDefItem(playerMonID, "ypMonastery", 1, 0.0);
	rmSetObjectDefMinDistance(playerMonID, 12.0);
	rmSetObjectDefMaxDistance(playerMonID, 16.0);
	rmAddObjectDefConstraint(playerMonID, avoidAll);
	rmAddObjectDefConstraint(playerMonID, avoidImpassableLand);

	int playerUSSaloonID=rmCreateObjectDef("player USsaloon");
	rmAddObjectDefItem(playerUSSaloonID, "Saloon", 1, 0.0);
	rmSetObjectDefMinDistance(playerUSSaloonID, 12.0);
	rmSetObjectDefMaxDistance(playerUSSaloonID, 16.0);
	rmAddObjectDefConstraint(playerUSSaloonID, avoidAll);
	rmAddObjectDefConstraint(playerUSSaloonID, avoidImpassableLand);

	int playerAfrTowerID=rmCreateObjectDef("player afr tower");
	rmAddObjectDefItem(playerAfrTowerID, "deTower", 1, 0.0);
	rmSetObjectDefMinDistance(playerAfrTowerID, 12.0);
	rmSetObjectDefMaxDistance(playerAfrTowerID, 16.0);
	rmAddObjectDefConstraint(playerAfrTowerID, avoidAll);
	rmAddObjectDefConstraint(playerAfrTowerID, avoidImpassableLand);

	int StartAreaTreeID=rmCreateObjectDef("starting trees");
	rmAddObjectDefItem(StartAreaTreeID, treeType2, 10, 12.0);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidAll);
	rmAddObjectDefConstraint(StartAreaTreeID, avoidImpassableLand);
	rmSetObjectDefMinDistance(StartAreaTreeID, 15.0);
	rmSetObjectDefMaxDistance(StartAreaTreeID, 25.0);

	rmSetStatusText("",0.60); 

	// Player placement

	for(i=1; <cNumberPlayers) {

		// Place town centers
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

		// Place resources
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerMineID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(StartAreaTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		// Place starting nugget
		rmSetNuggetDifficulty(1, 1);
		rmPlaceObjectDefAtLoc(playerNuggetID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		// Place additional buildings
		if (rmGetNomadStart() == false)
		{
			
			if (rmGetPlayerCiv(i) == rmGetCivID("DEItalians"))
				{
					rmPlaceObjectDefAtLoc(playerLombardID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
				}
			else if (rmGetPlayerCiv(i) == rmGetCivID("Chinese") || rmGetPlayerCiv(i) == rmGetCivID("Japanese") || rmGetPlayerCiv(i) == rmGetCivID("Indians"))
				{
					rmPlaceObjectDefAtLoc(playerMonID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
				}

			else if ( rmGetPlayerCiv(i) ==  rmGetCivID("XPIroquois") || rmGetPlayerCiv(i) ==  rmGetCivID("XPSioux") || rmGetPlayerCiv(i) == rmGetCivID("XPAztec") || rmGetPlayerCiv(i) == rmGetCivID("DEInca"))
				{
					rmPlaceObjectDefAtLoc(playerCommunityPlazaID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
				}
					
			else if (rmGetPlayerCiv(i) ==  rmGetCivID("DEAmericans") || rmGetPlayerCiv(i) ==  rmGetCivID("DEMexicans"))
				{
					rmPlaceObjectDefAtLoc(playerUSSaloonID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
				}
			else if (rmGetPlayerCiv(i) ==  rmGetCivID("DEEthiopians") || rmGetPlayerCiv(i) ==  rmGetCivID("DEHausa"))
				{
					rmPlaceObjectDefAtLoc(playerAfrTowerID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
				}
			else
				{
					rmPlaceObjectDefAtLoc(playerSaloonID, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
				}
		}

		if(ypIsAsian(i) && rmGetNomadStart() == false)
			rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
 
	}

	rmSetStatusText("",0.70); 

	// ----------------------------Forests-------------------------------

	int failCount = -1;
	int numTries = -1;

	// Define and place forests - north and south
	int forestTreeID = 0;

	numTries=10+5*cNumberNonGaiaPlayers;  // DAL - 4 here, 4 below
	failCount=0;
	for (i=0; <numTries)
		{   
		int northForest=rmCreateArea("northforest"+i);
		rmSetAreaWarnFailure(northForest, false);
		rmSetAreaSize(northForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));

		rmSetAreaForestType(northForest, treeType1);
		rmSetAreaForestDensity(northForest, 1.0);
		rmAddAreaToClass(northForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(northForest, 0.0);		//DAL more forest with more clumps
		rmSetAreaForestUnderbrush(northForest, 0.0);
		rmSetAreaCoherence(northForest, 0.4);
		
		rmAddAreaConstraint(northForest, avoidAll);
		rmAddAreaConstraint(northForest, avoidTownCenter);
		rmAddAreaConstraint(northForest, avoidPenalColony);
		rmAddAreaConstraint(northForest, avoidTradeRouteSocket);
		rmAddAreaConstraint(northForest, avoidAboriginals);
		rmAddAreaConstraint(northForest, avoidTradeRouteShort);
		rmAddAreaConstraint(northForest, avoidKOTH);
		if (cNumberNonGaiaPlayers <=3)
			rmAddAreaConstraint(northForest, avoidCliffShort);
		rmAddAreaConstraint(northForest, forestConstraint);   // DAL adeed, to keep forests away from each other.
		rmAddAreaConstraint(northForest, stayNorthHalf);				// DAL adeed, to keep forests in the north.
		if(rmBuildArea(northForest)==false)
		{
			// Stop trying once we fail 5 times in a row.  
			failCount++;
			if(failCount==5)
				break;
		}
		else
			failCount=0; 
	}

	
	numTries=20+5*cNumberNonGaiaPlayers;  // DAL - 4 here, 4 above.
	failCount=0;
	for (i = 0; i < numTries; i++)
	{   
		int southForest = rmCreateArea("southForest" + i);
		rmSetAreaWarnFailure(southForest, false);
		rmSetAreaSize(southForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));
		rmSetAreaForestType(southForest, treeType1);
		rmSetAreaForestDensity(southForest, 1.0);
		rmAddAreaToClass(southForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(southForest, 0.0);
		rmSetAreaForestUnderbrush(southForest, 0.0);
		rmSetAreaCoherence(southForest, 0.4);
		rmAddAreaConstraint(southForest, avoidAll);
		rmAddAreaConstraint(southForest, avoidTownCenter);
		rmAddAreaConstraint(southForest, avoidPenalColony);
		rmAddAreaConstraint(southForest, avoidTradeRouteSocket);
		rmAddAreaConstraint(southForest, avoidAboriginals);
		rmAddAreaConstraint(southForest, avoidTradeRouteShort);
		rmAddAreaConstraint(southForest, avoidKOTH);
		if (cNumberNonGaiaPlayers <=3)
			rmAddAreaConstraint(southForest, avoidCliffShort);
		rmAddAreaConstraint(southForest, forestConstraint);   // DAL adeed, to keep forests away from each other.
		rmAddAreaConstraint(southForest, staySouthPart);
		if (rmBuildArea(southForest) == false)
		{
			// Stop trying once we fail 5 times in a row.
			failCount++;
			if (failCount == 5)
				break;
		}
		else
			failCount = 0;
	}

	rmSetStatusText("",0.80); 

	// ----------------------------Resources-------------------------------

	// Mines

	int goldID = rmCreateObjectDef("random gold");
	rmAddObjectDefItem(goldID, "MineGold", 1, 0);
	rmSetObjectDefMinDistance(goldID, 0.0);
	rmSetObjectDefMaxDistance(goldID, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidWaterShort);
	rmAddObjectDefConstraint(goldID, avoidGold);
	rmAddObjectDefConstraint(goldID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(goldID, avoidPenalColony);
	rmAddObjectDefConstraint(goldID, avoidAboriginals);
	rmAddObjectDefConstraint(goldID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(goldID, avoidCliffShort);
	rmAddObjectDefConstraint(goldID, avoidTradeRouteSocket);
	rmPlaceObjectDefInArea(goldID, 0, upperAreaID, 2*cNumberNonGaiaPlayers);

	int gold2ID = rmCreateObjectDef("random gold 2");
	rmAddObjectDefItem(gold2ID, "MineGold", 1, 0);
	rmSetObjectDefMinDistance(gold2ID, 0.0);
	rmSetObjectDefMaxDistance(gold2ID, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(gold2ID, avoidAll);
	rmAddObjectDefConstraint(gold2ID, avoidWaterShort);
	rmAddObjectDefConstraint(gold2ID, avoidGold);
	rmAddObjectDefConstraint(gold2ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(gold2ID, avoidPenalColony);
	rmAddObjectDefConstraint(gold2ID, avoidAboriginals);
	rmAddObjectDefConstraint(gold2ID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(gold2ID, avoidTradeRouteSocket);
	rmPlaceObjectDefInArea(gold2ID, 0, eastIsland, cNumberNonGaiaPlayers/2);

	int gold3ID = rmCreateObjectDef("random gold 3");
	rmAddObjectDefItem(gold3ID, "MineGold", 1, 0);
	rmSetObjectDefMinDistance(gold3ID, 0.0);
	rmSetObjectDefMaxDistance(gold3ID, rmXFractionToMeters(0.3));
	rmAddObjectDefConstraint(gold3ID, avoidAll);
	rmAddObjectDefConstraint(gold3ID, avoidWaterShort);
	rmAddObjectDefConstraint(gold3ID, avoidGold);
	rmAddObjectDefConstraint(gold3ID, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(gold3ID, avoidPenalColony);
	rmAddObjectDefConstraint(gold3ID, avoidAboriginals);
	rmAddObjectDefConstraint(gold3ID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(gold3ID, avoidTradeRouteSocket);
	rmPlaceObjectDefInArea(gold3ID, 0, westIsland, cNumberNonGaiaPlayers/2);
	

	// Huntables North
	int foodID1=rmCreateObjectDef("random food");
	rmAddObjectDefItem(foodID1, food1, rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID1, 0);
	rmSetObjectDefMaxDistance(foodID1, rmXFractionToMeters(0.45));
	rmSetObjectDefMinDistance(foodID1, 0.0);
	rmSetObjectDefMaxDistance(foodID1, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID1, true);
	rmAddObjectDefConstraint(foodID1, avoidHunt1);
	rmAddObjectDefConstraint(foodID1, avoidAll);
	rmAddObjectDefConstraint(foodID1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(foodID1, stayNorthHalf);
	rmAddObjectDefConstraint(foodID1, avoidCliffShort);
	rmPlaceObjectDefAtLoc(foodID1, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3); 

	// Huntables South
	int foodID2=rmCreateObjectDef("random food 2");
	rmAddObjectDefItem(foodID2, food1, rmRandInt(6,7), 5.0);
	rmSetObjectDefMinDistance(foodID2, 0);
	rmSetObjectDefMaxDistance(foodID2, rmXFractionToMeters(0.45));
	rmSetObjectDefMinDistance(foodID2, 0.0);
	rmSetObjectDefMaxDistance(foodID2, rmXFractionToMeters(0.5));
	rmSetObjectDefCreateHerd(foodID2, true);
	rmAddObjectDefConstraint(foodID2, avoidHunt1);
	rmAddObjectDefConstraint(foodID2, avoidAll);
	rmAddObjectDefConstraint(foodID2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(foodID2, staySouthPart);	
	rmAddObjectDefConstraint(foodID2, avoidCliffShort);
	rmPlaceObjectDefAtLoc(foodID2, 0, 0.5, 0.5, cNumberNonGaiaPlayers*3); 


	// Tougher nuggets
	int nugget2= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget2, 0.0);
	rmSetObjectDefMaxDistance(nugget2, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget2, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNugget);
	rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget2, avoidAboriginalsShort);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2, avoidWaterShort);
	rmAddObjectDefConstraint(nugget2, avoidCliffShort);
	rmAddObjectDefConstraint(nugget2, playerEdgeConstraint);

	rmSetNuggetDifficulty(3, 4);
	rmPlaceObjectDefInArea(nugget2, 0, upperAreaID, cNumberNonGaiaPlayers);
	

	// Easier nuggets
	int nugget1= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget1, 0.0);
	rmSetNuggetDifficulty(2, 2);
	rmSetObjectDefMaxDistance(nugget1, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget1, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNugget);
	rmAddObjectDefConstraint(nugget1, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget1, avoidPenalColonyShort);
	rmAddObjectDefConstraint(nugget1, avoidAll);
	rmAddObjectDefConstraint(nugget1, avoidWater);
	rmAddObjectDefConstraint(nugget1, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget1, 0, eastIsland, cNumberNonGaiaPlayers);

	int nugget3= rmCreateObjectDef("nugget easy 2"); 
	rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nugget3, 0.0);
	rmSetNuggetDifficulty(2, 2);
	rmSetObjectDefMaxDistance(nugget3, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(nugget3, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nugget3, avoidNugget);
	rmAddObjectDefConstraint(nugget3, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget3, avoidPenalColonyShort);
	rmAddObjectDefConstraint(nugget3, avoidAll);
	rmAddObjectDefConstraint(nugget3, avoidWater);
	rmAddObjectDefConstraint(nugget3, playerEdgeConstraint);
	rmPlaceObjectDefInArea(nugget3, 0, westIsland, cNumberNonGaiaPlayers);

	// Fishes
	int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, "deFishNilePerch", 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmAddObjectDefConstraint(fishID, avoidCliff);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

	rmSetStatusText("",0.90); 


	// ------------------------------Triggers------------------------------//
	
	// Starting techs

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=0; <= cNumberNonGaiaPlayers) {
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpAustraliaMercenaries"); // Australian Mercenaries
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpEnableTradeRouteAustralian"); // Australian TR1
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpMapAustralian"); // Australian TR2
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",i);
	rmSetTriggerEffectParam("TechID","cTechzpNativeWaterTradeRoute"); // Australian TR2
	rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

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
	rmCreateTrigger("Activate Consulate Khmer"+k);
	rmAddTriggerCondition("ZP Player Civilization");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("Civilization","Khmers");
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpPickConsulateTechAvailable"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOnKhmers"); //operator
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
	rmCreateTrigger("Activate PenalColony"+k);
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpPenalColonyRevolt"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPenalColony"); //operator
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
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Consulate_Khmer"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_PenalColony"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// AI Penal Colony Leaders

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Australian Leader"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int AustralianLeader=-1;
	AustralianLeader = rmRandInt(1,3);

	if (AustralianLeader==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePenalColonyParkes"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (AustralianLeader==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePenalColonyCunningham"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (AustralianLeader==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulatePenalColonyLogan"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Amazing Waterfall

	for(k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Amazing Waterfall"+k);
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject","10");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","Unit");
	rmSetTriggerConditionParamInt("Dist",30);
	rmAddTriggerEffect("Revealer : Create");
	rmSetTriggerEffectParamInt("PlayerID",1);
	rmSetTriggerEffectParam("RevealerName", "Amazing_Waterfall"+k);
	rmSetTriggerEffectParam("RevealerLoc", rmXFractionToMeters(0.5)+",0,"+rmZFractionToMeters(0.72));
	rmSetTriggerEffectParamFloat("RevealerLOS",15);
	rmAddTriggerEffect("Send Chat");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("Message","Player "+k+" has discoveder amazing waterfall worth 100 XP");
	rmAddTriggerEffect("Grant Resources");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("ResName","XP");
	rmSetTriggerEffectParamInt("Amount",100);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Testing

	/*for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Test Plr"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "true");
	rmAddTriggerEffect("Set Tech Status");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParamFloat("TechID",537);
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Set Tech Status");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParamFloat("TechID",2804);
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Set Tech Status");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParamFloat("TechID",527);
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}*/


	// Text
	rmSetStatusText("",1.00);
	
} // END