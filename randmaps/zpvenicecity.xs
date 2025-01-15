// Venice City Map
// December 2024

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;
int evenOdd = -1;

include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

string fish1 = "ypFishTuna";

void main(void)
{
	// Text
	// These status text lines are used to manually animate the map generation progress bar
	rmSetStatusText("",0.01);

	// Choose summer or winter 

	//		seasonPicker = 0.77; 		// for testing
	float seasonPicker = rmRandFloat(0,1);//rmRandFloat(0,1); //high # is snow, low is spring

   	//Chooses which natives appear on the map
	int subCiv0=-1;

	if (rmAllocateSubCivs(1) == true)
	{
		subCiv0=rmGetCivID("zpvenetians");
		rmEchoInfo("subCiv0 is zpvenetians "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "zpvenetians");
	}

    int sizeZ = 400;
	int sizeX = 460;
	if (cNumberNonGaiaPlayers > 2){
		sizeX = 500;
	}
	if (cNumberNonGaiaPlayers > 4){
		sizeX = 560;
	}
	if (cNumberNonGaiaPlayers > 6){
		sizeX = 620;
	}

	rmSetMapSize(sizeX, sizeZ);
	
	rmSetMapElevationHeightBlend(1);
	
	// Picks a default water height
	rmSetSeaLevel(1.0);

	rmSetAllMapReveal(true);
   
   	// LIGHT SET

	rmSetLightingSet("Florida_Skirmish");


	// Picks default terrain and water
	rmSetSeaType("ZP Venice Lagoon");
	rmEnableLocalWater(false);
    rmTerrainInitialize("water");
	rmSetMapType("water");
    rmSetMapType("piratehistoricalmap");
    rmSetMapType("mediEurope");
    rmSetMapType("euroTradeRouteCapture");

	chooseMercs();

	// Corner constraint.
	rmSetWorldCircleConstraint(false);

   	// Define some classes. These are used later for constraints.
	int classPlayer=rmDefineClass("player");
	rmDefineClass("classHill");
	rmDefineClass("classPatch");
	rmDefineClass("starting settlement");
	rmDefineClass("startingUnit");
	rmDefineClass("classForest");
	rmDefineClass("importantItem");
	rmDefineClass("natives");
	rmDefineClass("classCliff");
	rmDefineClass("secrets");
	rmDefineClass("nuggets");
	rmDefineClass("center");
	rmDefineClass("tradeIslands");
	int classGreatLake=rmDefineClass("great lake");
	int classDeepWater=rmDefineClass("deep lake");
	int classStartingResource = rmDefineClass("startingResource");
    int classMountains=rmDefineClass("mountains");
	int classPortSite=rmDefineClass("portSite");
	int classBlock=rmDefineClass("classBlock");

	// -------------Define constraints
	// These are used to have objects and areas avoid each other
	
	// Map edge constraints
	int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
	int longPlayerEdgeConstraint=rmCreateBoxConstraint("long avoid edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
	
    int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 10.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 30.0);
	int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 30.0);
	int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 60.0);
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidLand = rmCreateTerrainDistanceConstraint("avoid land medium", "Water", false, 20.0);
	
	// Cardinal Directions
	int Northward=rmCreateBoxConstraint("stay in the city", 0.5, 1.0, 1.0, 0.0);
	int Southward=rmCreateBoxConstraint("stay in the city", 0.5, 1.0, 0.0, 0.0);
	int Eastward=rmCreatePieConstraint("eastMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(45), rmDegreesToRadians(225));
	int Westward=rmCreatePieConstraint("westMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(225), rmDegreesToRadians(45));

	// Player constraints
	int playerConstraintForest=rmCreateClassDistanceConstraint("forests kinda stay away from players", classPlayer, 20.0);
	int longPlayerConstraint=rmCreateClassDistanceConstraint("land stays away from players", classPlayer, 70.0);  
	int mediumPlayerConstraint=rmCreateClassDistanceConstraint("medium stay away from players", classPlayer, 40.0);  
	int playerConstraint=rmCreateClassDistanceConstraint("stay away from players", classPlayer, 45.0);
	int shortPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players short", classPlayer, 20.0);
	int avoidTradeIslands=rmCreateClassDistanceConstraint("stay away from trade islands", rmClassID("tradeIslands"), 40.0);
	int smallMapPlayerConstraint=rmCreateClassDistanceConstraint("stay away from players a lot", classPlayer, 70.0);
	int avoidStartingResources = rmCreateClassDistanceConstraint("avoid starting resources", rmClassID("startingResource"), 8.0);
	int avoidStartingResourcesMin = rmCreateClassDistanceConstraint("avoid starting resources min", rmClassID("startingResource"), 2.0);
	int avoidStartingResourcesShort = rmCreateClassDistanceConstraint("avoid starting resources short", rmClassID("startingResource"), 4.0);
    int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);  

	// Nature avoidance
	
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 25.0);
	int avoidResource=rmCreateTypeDistanceConstraint("resource avoid resource", "resource", 20.0);
	int avoidCoin=rmCreateTypeDistanceConstraint("avoid coin", "Mine", 30.0);
	int shortAvoidCoin=rmCreateTypeDistanceConstraint("short avoid coin", "gold", 10.0);
	int avoidStartResource=rmCreateTypeDistanceConstraint("start resource no overlap", "resource", 10.0);
    int avoidMountains=rmCreateClassDistanceConstraint("stuff avoids mountains", classMountains, 20.0);

	// Avoid impassable land
	int avoidImpassableLand=rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 6.0);
	int shortAvoidImpassableLand=rmCreateTerrainDistanceConstraint("short avoid impassable land", "Land", false, 2.0);
	int longAvoidImpassableLand=rmCreateTerrainDistanceConstraint("long avoid impassable land", "Land", false, 10.0);
	int hillConstraint=rmCreateClassDistanceConstraint("hill vs. hill", rmClassID("classHill"), 10.0);
	int shortHillConstraint=rmCreateClassDistanceConstraint("patches vs. hill", rmClassID("classHill"), 5.0);
	int patchConstraint=rmCreateClassDistanceConstraint("patch vs. patch", rmClassID("classPatch"), 5.0);
	int avoidCliffs=rmCreateClassDistanceConstraint("cliff vs. cliff", rmClassID("classCliff"), 30.0);
	int avoidWater4 = rmCreateTerrainDistanceConstraint("avoid water", "Land", false, 4.0);
	int nearShore=rmCreateTerrainMaxDistanceConstraint("near shore", "water", false, 20.0);

	// Unit avoidance
	int avoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units", rmClassID("startingUnit"), 45.0);
	int shortAvoidStartingUnits=rmCreateClassDistanceConstraint("objects avoid starting units short", rmClassID("startingUnit"), 10.0);
	int avoidImportantItem=rmCreateClassDistanceConstraint("secrets etc avoid each other", rmClassID("importantItem"), 10.0);
	int avoidNativesShort=rmCreateClassDistanceConstraint("stuff avoids natives short", rmClassID("natives"), 8.0);
	int avoidNatives=rmCreateClassDistanceConstraint("stuff avoids natives", rmClassID("natives"), 30.0);
	int avoidSecrets=rmCreateClassDistanceConstraint("stuff avoids secrets", rmClassID("secrets"), 20.0);
	int avoidNuggets=rmCreateTypeDistanceConstraint("nugget avoid nugget", "abstractNugget", 30.0);
	int deerConstraint=rmCreateTypeDistanceConstraint("avoid the deer", "deer", 40.0);
	int shortNuggetConstraint=rmCreateTypeDistanceConstraint("avoid nugget objects", "AbstractNugget", 7.0);
	int shortDeerConstraint=rmCreateTypeDistanceConstraint("short avoid the deer", "deer", 20.0);
	int mooseConstraint=rmCreateTypeDistanceConstraint("avoid the moose", "moose", 40.0);
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 55.0);
    int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 11.0);
    int avoidRandomBerries=rmCreateTypeDistanceConstraint("avoid random berries", "berrybush", 50.0);	//Attempting to spread them out more evenly.

	// Decoration avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

	// Trade route avoidance.
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 7.0);
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("short trade route", 3.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 8.0);
	int avoidTradeRouteFar2 = rmCreateTradeRouteDistanceConstraint("trade route far 2", 10.0);
	int avoidTradeRouteMax = rmCreateTradeRouteDistanceConstraint("trade route max", 30.0);
	int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 8.0);
	int farAvoidTradeSockets = rmCreateTypeDistanceConstraint("far avoid trade sockets", "sockettraderoute", 12.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
    int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 10.0);	
	int HCspawnLand = rmCreateTerrainDistanceConstraint("HC spawn away from land", "land", true, 12.0);
	int avoidTrainStationA = rmCreateTypeDistanceConstraint("avoid trainstation a", "spSocketTrainStationA", 8.0);
	int avoidTrainStationB = rmCreateTypeDistanceConstraint("avoid trainstation b", "spSocketTrainStationB", 8.0);
    int avoidHarbour = rmCreateTypeDistanceConstraint("avoid harbour", "zpSPCPortSocket", 20.0);
	int avoidBridge = rmCreateTypeDistanceConstraint("avoid bridge", "zpRuinWallSmall", 10.0);

	// Lake Constraints
	int greatLakesConstraint=rmCreateClassDistanceConstraint("avoid the great lakes", classGreatLake, 5.0);
	int farGreatLakesConstraint=rmCreateClassDistanceConstraint("far avoid the great lakes", classGreatLake, 20.0);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
	int avoidDeepWater=rmCreateClassDistanceConstraint("stuff avoids deep water", classDeepWater, 30.0);
	int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "SocketTradeRoute", 10.0);
   	int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 50.0);
    int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 10);
	int flagVsVenice1 = rmCreateTypeDistanceConstraint("flag avoid venice 1", "zpNativeWaterSpawnFlag1", 40.0);
  	int flagVsVenice2 = rmCreateTypeDistanceConstraint("flag avoid venice 2", "zpNativeWaterSpawnFlag2", 40.0);
	int saltVsSalt = rmCreateTypeDistanceConstraint("salt avoid same", "zpSaltMineWater", 30);
    int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 5.0);


	// Native Constraints
	int avoidSufi=rmCreateTypeDistanceConstraint("stay away from Sufi", "SocketCherokee", 70.0);
	int avoidMaltese=rmCreateTypeDistanceConstraint("stay away from Maltese", "zpSocketScientists", 45.0);
	int avoidJewish=rmCreateTypeDistanceConstraint("stay away from Jewish", "zpSPCSocketWesternVillage", 25.0);
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 40.0);
	int avoidTradeSocket=rmCreateTypeDistanceConstraint("stay away from Trade Socket", "SocketTradeRoute", 40.0);
	int avoidTradeSocketShort=rmCreateTypeDistanceConstraint("stay away from Trade Socket Short", "SocketTradeRoute", 25.0);
	int avoidTradeRouteSocketMin = rmCreateTypeDistanceConstraint("trade route socket min", "SocketTradeRoute", 25.0);
	int avoidTradeSocketFar=rmCreateTypeDistanceConstraint("stay away from Trade Socket far", "SocketTradeRoute", 40.0);
	int avoidTradeSocketFar2=rmCreateTypeDistanceConstraint("stay away from Trade Socket far 2", "SocketTradeRoute", 45.0);
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 5.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 25.0);
	int avoidTownCenterShort=rmCreateTypeDistanceConstraint("avoid Town Center Short", "townCenter", 6.0);

	// Venice Constraints
	int avoidPathBlock=rmCreateTypeDistanceConstraint("avoid pathblock", "HarbourPathBlock", 6.0);
	int avoidControllerShort=rmCreateTypeDistanceConstraint("stay away from Controller Short", "zpSPCWaterSpawnPoint", 20.0);

	// Additional Constraints - based on dansil original constraints
    int cityConstraint = rmCreateBoxConstraint("stay in the city", 0.2, 0.0, 0.8, 1.0);
    int citySouthConstraint = rmCreateBoxConstraint("stay in the city south", 0.2, 0.0, 0.453, 1.0);
    int cityNorthConstraint = rmCreateBoxConstraint("stay in the city north", 0.557, 0.0, 0.8, 1.0);

    int classPatch = rmDefineClass("patch");
    int avoidPatch = rmCreateClassDistanceConstraint("avoid patch", rmClassID("patch"), 22.0);
    int avoidPlateauShort = rmCreateClassDistanceConstraint("avoid patch 1", rmClassID("classPlateau"), 1.0);
    int classCenter = rmDefineClass("center");
    int avoidCenter = rmCreateClassDistanceConstraint("avoid center", rmClassID("center"), 6.0);
    int circleConstraint2=rmCreatePieConstraint("circle Constraint2", 0.5, 0.5, 0, rmZFractionToMeters(0.48), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidFixedGun=rmCreateTypeDistanceConstraint("avoid fixed gun", "zpSPCFixedGunSocket", 20.0);
	int avoidBuilding=rmCreateTypeDistanceConstraint("avoid building", "Building", 20.0);
	int avoidBlockLong =rmCreateClassDistanceConstraint("stuff vs. blocks long", rmClassID("classBlock"), 10.0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.10);

	// ************** INVISIBLE TERRAIN LAYERS ************

	// Create invisible areas to place correctly Venice Grouping and future terrain

	int landMassID = rmCreateArea("land mass 1");
    rmSetAreaSize(landMassID , rmAreaTilesToFraction(13000), rmAreaTilesToFraction(13000));
    rmSetAreaLocation(landMassID , 0.5, 0.5);		
    rmSetAreaCoherence(landMassID , 1.0);
    rmSetAreaBaseHeight(landMassID, 2.0);
	rmSetAreaWarnFailure(landMassID, false);
    rmSetAreaMix(landMassID, "italy_grass");
    rmSetAreaElevationVariation(landMassID, 0.0);
	rmAddAreaInfluenceSegment(landMassID, 0.55, 1.0, 0.55, 0.5);
	rmAddAreaInfluenceSegment(landMassID, 0.55, 0.5, 0.45, 0.5);
	rmAddAreaInfluenceSegment(landMassID, 0.45, 0.5, 0.45, 0.0);
    rmBuildArea(landMassID ); 

	int landMassID2 = rmCreateArea("land mass 2");
    rmSetAreaSize(landMassID2 , rmAreaTilesToFraction(22000), rmAreaTilesToFraction(22000));
    rmSetAreaLocation(landMassID2 , 0.5, 0.5);		
    rmSetAreaCoherence(landMassID2 , 1.0);
    rmSetAreaBaseHeight(landMassID2, 2.0);
	rmSetAreaWarnFailure(landMassID2, false);
    rmSetAreaMix(landMassID2, "italy_grass");
    rmSetAreaElevationVariation(landMassID2, 0.0);
	rmAddAreaInfluenceSegment(landMassID2, 0.5-rmXTilesToFraction(80), 0.5, 0.5+rmXTilesToFraction(80), 0.5);
    rmBuildArea(landMassID2 ); 

	int veniceArea = rmCreateArea("veniceArea");
    rmSetAreaSize(veniceArea , rmAreaTilesToFraction(17000), rmAreaTilesToFraction(17000));
    rmSetAreaLocation(veniceArea , 0.5, 0.5);		
    rmSetAreaCoherence(veniceArea , 0.8);
    rmSetAreaElevationVariation(veniceArea, 0.0);
	rmAddAreaConstraint(veniceArea, avoidControllerShort);
	rmAddAreaToClass(veniceArea, classGreatLake);
    rmBuildArea(veniceArea); 
	

	// ********* Trade Route *******************

	// Build Trade Route

	int tradeRouteID = rmCreateTradeRoute();  
    rmAddTradeRouteWaypoint(tradeRouteID, 0.5-rmXTilesToFraction(11), 1.0);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.5-rmXTilesToFraction(11), 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5+rmXTilesToFraction(11), 0.5);
    rmAddTradeRouteWaypoint(tradeRouteID, 0.5+rmXTilesToFraction(11), 0.0);
    rmBuildTradeRoute(tradeRouteID, "water_trail");

	// define fake stopper (without it the Venetian islands don't spawn)
	int fakeStopperID=rmCreateObjectDef("TradeShipStopperFake");
	rmAddObjectDefItem(fakeStopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(fakeStopperID, true);
	rmSetObjectDefMinDistance(fakeStopperID, 0.0);
	rmSetObjectDefMaxDistance(fakeStopperID, 0.0); 

    // Place fake train stopper, because without it the islands son't spawn
	vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
	rmPlaceObjectDefAtPoint(fakeStopperID, 0, socketLoc1);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);


	//  ************************** River ******************************

    // River must be defined before the islands are placed
	if (cNumberNonGaiaPlayers ==3 || cNumberNonGaiaPlayers ==4)
    	int riverID = rmRiverCreate(-1, "ZP Venice Lagoon Shore", 4, 4, 68, 68); //  (-1, "new england lake", 18, 14, 5, 5)
	else if (cNumberNonGaiaPlayers ==5 || cNumberNonGaiaPlayers ==6)
    	riverID = rmRiverCreate(-1, "ZP Venice Lagoon Shore", 4, 4, 85, 85); //  (-1, "new england lake", 18, 14, 5, 5)
	else if (cNumberNonGaiaPlayers >6)
    	riverID = rmRiverCreate(-1, "ZP Venice Lagoon Shore", 4, 4, 105, 105); //  (-1, "new england lake", 18, 14, 5, 5)
	else
		riverID = rmRiverCreate(-1, "ZP Venice Lagoon Shore", 4, 4, 45, 45); //  (-1, "new england lake", 18, 14, 5, 5)
    rmRiverAddWaypoint(riverID, 0.5, 1.0);
	rmRiverAddWaypoint(riverID, 0.5, 0.0);
	rmRiverBuild(riverID);

	int riverID2 = rmRiverCreate(-1, "ZP Venice Lagoon Shore", 4, 4, 68, 68); //  (-1, "new england lake", 18, 14, 5, 5)
    rmRiverAddWaypoint(riverID2, 0.0, 0.5);
    rmRiverAddWaypoint(riverID2, 1.0, 0.5);
	rmRiverBuild(riverID2);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.30);

    // ************************** PLACE VENICE *****************************

    rmDefineClass("classPlateau");

	// Venetian Tradee Sockets

	int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmAddObjectDefItem(socketID, "zpTradingPostCaptureNaval", 1, 0.0);
	rmSetObjectDefMinDistance(socketID, 0.0);
  	rmSetObjectDefMaxDistance(socketID, 3.0);
	rmAddObjectDefConstraint(socketID, avoidPathBlock);

	int socketID2=rmCreateObjectDef("sockets to dock Trade Posts2");
	rmSetObjectDefTradeRouteID(socketID2, tradeRouteID);
	rmAddObjectDefItem(socketID2, "zpTradingPostCaptureNaval", 1, 0.0);
	rmSetObjectDefMinDistance(socketID2, 0.0);
  	rmSetObjectDefMaxDistance(socketID2, 3.0);
	rmAddObjectDefConstraint(socketID2, avoidPathBlock);

	int socketID3=rmCreateObjectDef("sockets to dock Trade Posts3");
	rmSetObjectDefTradeRouteID(socketID3, tradeRouteID);
	rmAddObjectDefItem(socketID3, "zpTradingPostCaptureNaval", 1, 0.0);
	rmSetObjectDefMinDistance(socketID3, 0.0);
  	rmSetObjectDefMaxDistance(socketID3, 3.0);
	rmAddObjectDefConstraint(socketID3, avoidPathBlock);

	int socketID4=rmCreateObjectDef("sockets to dock Trade Posts4");
	rmSetObjectDefTradeRouteID(socketID4, tradeRouteID);
	rmAddObjectDefItem(socketID4, "zpTradingPostCaptureNaval", 1, 0.0);
	rmSetObjectDefMinDistance(socketID4, 0.0);
  	rmSetObjectDefMaxDistance(socketID4, 3.0);
	rmAddObjectDefConstraint(socketID4, avoidPathBlock);

	// Place Trade route sockets
    if (cNumberNonGaiaPlayers <=2){
		rmPlaceObjectDefAtLoc(socketID, 0, 0.5+rmXTilesToFraction(2), 0.62);
		rmPlaceObjectDefAtLoc(socketID2, 0, 0.5+rmXTilesToFraction(1), 0.11);
		rmPlaceObjectDefAtLoc(socketID3, 0, 0.5-rmXTilesToFraction(19), 0.66);
		rmPlaceObjectDefAtLoc(socketID4, 0, 0.5+rmXTilesToFraction(21), 0.35);
	}
	else if (cNumberNonGaiaPlayers ==3 || cNumberNonGaiaPlayers ==4){
		rmPlaceObjectDefAtLoc(socketID, 0, 0.5+rmXTilesToFraction(1), 0.62);
		rmPlaceObjectDefAtLoc(socketID2, 0, 0.5+rmXTilesToFraction(5), 0.11);
		rmPlaceObjectDefAtLoc(socketID3, 0, 0.5-rmXTilesToFraction(20), 0.66);
		rmPlaceObjectDefAtLoc(socketID4, 0, 0.5+rmXTilesToFraction(24), 0.35);
	}
	else{
		rmPlaceObjectDefAtLoc(socketID, 0, 0.5-rmXTilesToFraction(1), 0.62);
		rmPlaceObjectDefAtLoc(socketID2, 0, 0.5+rmXTilesToFraction(1), 0.11);
		rmPlaceObjectDefAtLoc(socketID3, 0, 0.5-rmXTilesToFraction(22), 0.66);
		rmPlaceObjectDefAtLoc(socketID4, 0, 0.5+rmXTilesToFraction(22), 0.35);
	}
	
	vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(socketID, 0));
	vector ControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(socketID2, 0));
	vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(socketID3, 0));
	vector ControllerLoc4 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(socketID4, 0));

	rmSetNuggetDifficulty(298, 298);

	int islandVariation = rmRandInt(0, 1);
	int peninsulaVariation = rmRandInt(0, 1);

	// San Marco
	if (islandVariation == 0)
		int veniceSanMarco = rmCreateGrouping("bridge1", "Venice_Island_01");
	else
		veniceSanMarco = rmCreateGrouping("bridge1", "Venice_Island_01B");
    rmSetGroupingMinDistance(veniceSanMarco, 0.00);
    rmSetGroupingMaxDistance(veniceSanMarco, 0.01);
	rmAddGroupingToClass(veniceSanMarco, rmClassID("classPlateau"));

	int veniceInstanceID1 = rmPlaceGroupingInstanceAtLoc(veniceSanMarco, rmXMetersToFraction(xsVectorGetX(ControllerLoc1))+rmXTilesToFraction(22), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1))+rmZTilesToFraction(16), 0);

	//San Giorgio
	if (islandVariation == 0)
		int veniceSanGiorgio = rmCreateGrouping("bridge2", "Venice_Island_02");
	else
		veniceSanGiorgio = rmCreateGrouping("bridge2", "Venice_Island_02B");
    rmSetGroupingMinDistance(veniceSanGiorgio, 0.00);
    rmSetGroupingMaxDistance(veniceSanGiorgio, 0.00);
	rmAddGroupingToClass(veniceSanGiorgio, rmClassID("classPlateau"));

	int veniceInstanceID2 = rmPlaceGroupingInstanceAtLoc(veniceSanGiorgio, rmXMetersToFraction(xsVectorGetX(ControllerLoc2))-rmXTilesToFraction(16), rmZMetersToFraction(xsVectorGetZ(ControllerLoc2))+rmZTilesToFraction(24), 0);

	// Academia
	if (peninsulaVariation == 0)
		int veniceAcademia = rmCreateGrouping("bridge3", "Venice_Island_03");
	else
		veniceAcademia = rmCreateGrouping("bridge3", "Venice_Island_03B");
    rmSetGroupingMinDistance(veniceAcademia, 0.00);
    rmSetGroupingMaxDistance(veniceAcademia, 0.00);
	rmAddGroupingToClass(veniceAcademia, rmClassID("classPlateau"));

	int veniceInstanceID3 = rmPlaceGroupingInstanceAtLoc(veniceAcademia, rmXMetersToFraction(xsVectorGetX(ControllerLoc3))-rmXTilesToFraction(19), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3))-rmZTilesToFraction(21), 0);

	// San Polo
	if (peninsulaVariation == 0)
		int veniceSanPolo = rmCreateGrouping("bridge4", "Venice_Island_04");
	else
		veniceSanPolo = rmCreateGrouping("bridge4", "Venice_Island_04B");
    rmSetGroupingMinDistance(veniceSanPolo, 0.00);
    rmSetGroupingMaxDistance(veniceSanPolo, 0.01);
	rmAddGroupingToClass(veniceSanPolo, rmClassID("classPlateau"));

	int veniceInstanceID4 = rmPlaceGroupingInstanceAtLoc(veniceSanPolo, rmXMetersToFraction(xsVectorGetX(ControllerLoc4))+rmXTilesToFraction(21), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4))+rmZTilesToFraction(15), 0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.40);

	// ******************* Player Islands **********************

	//North Area

	int shoreLineNorth = rmCreateArea("shore North"); // Cliff to dock the Venice bridge
    rmSetAreaSize(shoreLineNorth, rmAreaTilesToFraction(400), rmAreaTilesToFraction(400));
    rmSetAreaLocation(shoreLineNorth, rmXMetersToFraction(xsVectorGetX(ControllerLoc4))+rmXTilesToFraction(52), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4))+rmZTilesToFraction(4));
    rmSetAreaCoherence(shoreLineNorth, 1.0);	
    rmSetAreaBaseHeight(shoreLineNorth, 3.0);
    rmSetAreaCliffType(shoreLineNorth, "Italian Cliff");
    rmSetAreaCliffEdge(shoreLineNorth, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(shoreLineNorth, 0, 0.0, 1.0);
    rmAddAreaToClass(shoreLineNorth , rmClassID("classPlateau"));
    rmSetAreaObeyWorldCircleConstraint(shoreLineNorth, false);
	rmSetAreaCliffPainting(shoreLineNorth, false, true, true, 1.5, true);
    rmBuildArea(shoreLineNorth); 

	int NorthIslandID = rmCreateArea("north island"); 
    rmSetAreaSize(NorthIslandID , 0.20, 0.20);
    rmSetAreaLocation(NorthIslandID , 0.95, 0.5);		
    rmSetAreaCoherence(NorthIslandID , 1.0);
    rmSetAreaBaseHeight(NorthIslandID, 3.0);
	rmSetAreaWarnFailure(NorthIslandID, false);
    rmSetAreaMix(NorthIslandID, "italy_grass");
		rmAddAreaTerrainLayer(NorthIslandID, "caribbean\ground_shoreline1_crb", 0, 3);
    rmSetAreaElevationVariation(NorthIslandID, 3.0);
    rmSetAreaElevationType(NorthIslandID, cElevTurbulence);
	rmSetAreaElevationMinFrequency(NorthIslandID, 0.09);
	rmSetAreaElevationOctaves(NorthIslandID, 3);
	rmSetAreaElevationPersistence(NorthIslandID, 0.2);
	rmSetAreaElevationNoiseBias(NorthIslandID, 1);
	rmAddAreaConstraint(NorthIslandID, greatLakesConstraint);
	rmAddAreaConstraint(NorthIslandID, avoidFixedGun);
	rmAddAreaConstraint(NorthIslandID, avoidTradeRoute);
	rmSetAreaSmoothDistance(NorthIslandID, 10);
	rmSetAreaHeightBlend(NorthIslandID, 2.0);
    rmBuildArea(NorthIslandID ); 

	int shoreTerrainNorth = rmCreateArea("shore Terrain North");
    rmSetAreaSize(shoreTerrainNorth, rmAreaTilesToFraction(450), rmAreaTilesToFraction(450));
    rmSetAreaLocation(shoreTerrainNorth, rmXMetersToFraction(xsVectorGetX(ControllerLoc4))+rmXTilesToFraction(54), rmZMetersToFraction(xsVectorGetZ(ControllerLoc4))+rmZTilesToFraction(4));
    rmSetAreaCoherence(shoreTerrainNorth, 1.0);	
   	rmSetAreaMix(shoreTerrainNorth, "italy_grass");
    rmBuildArea(shoreTerrainNorth); 

	// South Area

	int shoreLineSouth = rmCreateArea("shore South"); // Cliff to dock the 
    rmSetAreaSize(shoreLineSouth, rmAreaTilesToFraction(400), rmAreaTilesToFraction(400));
    rmSetAreaLocation(shoreLineSouth, rmXMetersToFraction(xsVectorGetX(ControllerLoc3))-rmXTilesToFraction(56), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3))-rmZTilesToFraction(13));	
    rmSetAreaCoherence(shoreLineSouth, 1.0);	
    rmSetAreaBaseHeight(shoreLineSouth, 3.0);
    rmSetAreaCliffType(shoreLineSouth, "Italian Cliff");
    rmSetAreaCliffEdge(shoreLineSouth, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(shoreLineSouth, 0, 0.0, 1.0);
    rmAddAreaToClass(shoreLineSouth , rmClassID("classPlateau"));
    rmSetAreaObeyWorldCircleConstraint(shoreLineSouth, false);
	rmSetAreaCliffPainting(shoreLineSouth, false, true, true, 1.5, true);
    rmBuildArea(shoreLineSouth); 

	int SouthIslandID = rmCreateArea("south island");
    rmSetAreaSize(SouthIslandID , 0.20, 0.20);
    rmSetAreaLocation(SouthIslandID , 0.05, 0.5);		
    rmSetAreaCoherence(SouthIslandID , 1.0);
    rmSetAreaBaseHeight(SouthIslandID, 3.0);
	rmSetAreaWarnFailure(SouthIslandID, false);
    rmSetAreaMix(SouthIslandID, "italy_grass");
		rmAddAreaTerrainLayer(SouthIslandID, "caribbean\ground_shoreline1_crb", 0, 3);
    rmSetAreaElevationVariation(SouthIslandID, 3.0);
    rmSetAreaElevationType(SouthIslandID, cElevTurbulence);
	rmSetAreaElevationMinFrequency(SouthIslandID, 0.09);
	rmSetAreaElevationOctaves(SouthIslandID, 3);
	rmSetAreaElevationPersistence(SouthIslandID, 0.2);
	rmSetAreaElevationNoiseBias(SouthIslandID, 1);
	rmAddAreaConstraint(SouthIslandID, greatLakesConstraint);
	rmAddAreaConstraint(SouthIslandID, avoidFixedGun);
	rmAddAreaConstraint(SouthIslandID, avoidTradeRoute);
	rmSetAreaSmoothDistance(SouthIslandID, 10);
	rmSetAreaHeightBlend(SouthIslandID, 2.0);
    rmBuildArea(SouthIslandID );

	int shoreTerrainSouth = rmCreateArea("shore Terrain South");
    rmSetAreaSize(shoreTerrainSouth, rmAreaTilesToFraction(450), rmAreaTilesToFraction(450));
    rmSetAreaLocation(shoreTerrainSouth, rmXMetersToFraction(xsVectorGetX(ControllerLoc3))-rmXTilesToFraction(58), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3))-rmZTilesToFraction(13));	
    rmSetAreaCoherence(shoreTerrainSouth, 1.0);	
   	rmSetAreaMix(shoreTerrainSouth, "italy_grass");
    rmBuildArea(shoreTerrainSouth); 

	int southIslandConstraint=rmCreateAreaConstraint("south island constraint", SouthIslandID);
    int northIslandConstraint=rmCreateAreaConstraint("north island constraint", NorthIslandID);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.50);

	// ************************** Place Players ****************************

	float spawnSwitch = rmRandInt(0,1);
	int weirdSpawn = 0;
    
    if (spawnSwitch ==0){
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.64, 0.86);
		rmPlacePlayersCircular(0.44, 0.44, rmDegreesToRadians(5.0));
		rmSetPlacementTeam(1);
		rmSetPlacementSection(0.14, 0.36);
		rmPlacePlayersCircular(0.44, 0.44, rmDegreesToRadians(5.0));
	}
	else{
		rmSetPlacementTeam(1);
		rmSetPlacementSection(0.64, 0.86);
		rmPlacePlayersCircular(0.44, 0.44, rmDegreesToRadians(5.0));
		rmSetPlacementTeam(0);
		rmSetPlacementSection(0.14, 0.36);
		rmPlacePlayersCircular(0.44, 0.44, rmDegreesToRadians(5.0));
	}

	if ( rmGetNumberPlayersOnTeam(0)>4 ||  rmGetNumberPlayersOnTeam(1)>4)
	weirdSpawn = 1;


	// Town Centrer Start

	int playerStart = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(playerStart, 7.0);
	rmSetObjectDefMaxDistance(playerStart, 12.0);

	// Player Resources

	int foodID = rmCreateObjectDef("starting hunt");
	rmAddObjectDefItem(foodID, "deer", 9, 6.0);
	rmSetObjectDefMinDistance(foodID, 12.0);
	rmSetObjectDefMaxDistance(foodID, 14.0);
	rmSetObjectDefCreateHerd(foodID, true);
	rmAddObjectDefConstraint(foodID, avoidWater10);

	int goldID = rmCreateObjectDef("starting gold");
	rmAddObjectDefItem(goldID, "Mine", 1, 2.0);
	rmSetObjectDefMinDistance(goldID, 14.0);
	rmSetObjectDefMaxDistance(goldID, 15.0);
	rmAddObjectDefConstraint(goldID, avoidTradeRouteMin);
	rmAddObjectDefConstraint(goldID, avoidAll);
	rmAddObjectDefConstraint(goldID, avoidWater10);

	int berryID = rmCreateObjectDef("starting berries");
	rmAddObjectDefItem(berryID, "BerryBush", 5, 4.0);
	rmSetObjectDefMinDistance(berryID, 16.0);
	rmSetObjectDefMaxDistance(berryID, 17.0);
	rmAddObjectDefConstraint(berryID, shortAvoidCoin);
	rmAddObjectDefConstraint(berryID, avoidAll);
	rmAddObjectDefConstraint(berryID, avoidWater10);

	// Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.65);

	//place tcs
    
    for(i=1; < cNumberNonGaiaPlayers + 1) {

		if (weirdSpawn==0){
			int playerID=rmCreateArea("player "+i);
			rmSetPlayerArea(i, playerID);
			rmSetAreaSize(playerID, rmAreaTilesToFraction(700));
			rmSetAreaLocPlayer(playerID, i);
			rmSetAreaWarnFailure(playerID, false);
			rmSetAreaCoherence(playerID, 1.0);
			rmSetAreaBaseHeight(playerID, 3.5);
			rmSetAreaSmoothDistance(playerID, 15);
			rmEchoInfo("Team area"+i);
			rmBuildArea(playerID); 

			int playerFortID = -1;
			playerFortID = rmCreateGrouping("player fort", "malta_player_fort2");
			rmAddGroupingToClass(playerFortID, rmClassID("classBlock"));  
			rmPlaceGroupingAtLoc(playerFortID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i), 1);
		}

		else{
			int id=rmCreateArea("Player"+i);
			rmSetPlayerArea(i, id);

			int startID = rmCreateObjectDef("object"+i);
			rmAddObjectDefItem(startID, "TownCenter", 1, 2.0);
			rmSetObjectDefMinDistance(startID, 0.0);
			rmSetObjectDefMaxDistance(startID, 10.0);
			rmAddObjectDefConstraint(startID, avoidTradeRouteMin);
			rmAddObjectDefConstraint(startID, avoidWater20);

			rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		}

		rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		vector TCLocation=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(startID, i));

		int waterSpawnPointID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(waterSpawnPointID, "HomeCityWaterSpawnFlag", 1, 0.0);
        rmSetObjectDefMinDistance(waterSpawnPointID, 2.0);
	    rmSetObjectDefMaxDistance(waterSpawnPointID, 20.0); 
        rmAddObjectDefConstraint(waterSpawnPointID, flagLand);
        rmAddObjectDefConstraint(waterSpawnPointID, flagVsFlag);

        if (spawnSwitch ==0){
            if(rmGetPlayerTeam(i) == 1)
                rmPlaceObjectDefAtLoc(waterSpawnPointID, i, 0.5+rmXTilesToFraction(72), 0.5+rmZTilesToFraction(20));
            else
                rmPlaceObjectDefAtLoc(waterSpawnPointID, i, 0.5-rmXTilesToFraction(72), 0.5-rmZTilesToFraction(20));
        }
        else{
            if(rmGetPlayerTeam(i) == 0)
                rmPlaceObjectDefAtLoc(waterSpawnPointID, i, 0.5+rmXTilesToFraction(72), 0.5+rmZTilesToFraction(20));
            else
                rmPlaceObjectDefAtLoc(waterSpawnPointID, i, 0.5-rmXTilesToFraction(72), 0.5-rmZTilesToFraction(20));
        }

	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.60);

	// ****************** Map resources *******************

	// Mines

	for(i=0; < cNumberNonGaiaPlayers*1.5){
		int northMineID = rmCreateObjectDef("north mine "+i);
		rmAddObjectDefItem(northMineID, "Mine", 1, 0.0);
		rmSetObjectDefMinDistance(northMineID, 0.0);
		rmSetObjectDefMaxDistance(northMineID, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(northMineID, avoidCoin);
		rmAddObjectDefConstraint(northMineID, avoidAll);
		rmAddObjectDefConstraint(northMineID, avoidTownCenterFar);
		rmAddObjectDefConstraint(northMineID, avoidWater10);
		rmAddObjectDefConstraint(northMineID, northIslandConstraint);
		rmAddObjectDefConstraint(northMineID, playerEdgeConstraint);
		rmAddObjectDefConstraint(northMineID, avoidBlockLong);
		rmPlaceObjectDefAtLoc(northMineID, 0, 0.5, 0.5);

	} 

	for(i=0; < cNumberNonGaiaPlayers*1.5){
		int southMineID = rmCreateObjectDef("south mine "+i);
		rmAddObjectDefItem(southMineID, "Mine", 1, 0.0);
		rmSetObjectDefMinDistance(southMineID, 0.0);
		rmSetObjectDefMaxDistance(southMineID, rmXFractionToMeters(0.45));
		rmAddObjectDefConstraint(southMineID, avoidCoin);
		rmAddObjectDefConstraint(southMineID, avoidAll);
		rmAddObjectDefConstraint(southMineID, avoidTownCenterFar);
		rmAddObjectDefConstraint(southMineID, avoidWater10);
		rmAddObjectDefConstraint(southMineID, southIslandConstraint);
		rmAddObjectDefConstraint(southMineID, playerEdgeConstraint);
		rmAddObjectDefConstraint(southMineID, avoidBlockLong);
		rmPlaceObjectDefAtLoc(southMineID, 0, 0.5, 0.5);

	}

	// Forests
	int forestTreeID = 0;
	int numTries=6+3*cNumberNonGaiaPlayers;
	int failCount=0;
	for (i=0; <numTries) {   
		int forest=rmCreateArea("forest "+i);
		rmSetAreaWarnFailure(forest, false);
		rmSetAreaSize(forest, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
		rmSetAreaForestType(forest, "Italian Forest");
		rmSetAreaForestDensity(forest, 0.6);
		rmSetAreaForestClumpiness(forest, 0.4);
		rmSetAreaForestUnderbrush(forest, 0.0);
		rmSetAreaMinBlobs(forest, 1);
		rmSetAreaMaxBlobs(forest, 5);
		rmSetAreaMinBlobDistance(forest, 16.0);
		rmSetAreaMaxBlobDistance(forest, 40.0);
		rmSetAreaCoherence(forest, 0.4);
		rmSetAreaSmoothDistance(forest, 10);
		rmAddAreaToClass(forest, rmClassID("classForest")); 
		rmAddAreaConstraint(forest, forestConstraint);
		rmAddAreaConstraint(forest, avoidAll);
		rmAddAreaConstraint(forest, avoidTownCenter);
		rmAddAreaConstraint(forest, avoidPlateauShort);
        rmAddAreaConstraint(forest, Northward);
		rmAddAreaConstraint(forest, shortAvoidImpassableLand); 
		if(rmBuildArea(forest)==false) {
		// Stop trying once we fail 3 times in a row.
		failCount++;
		
		if(failCount==5)
			break;
		}

	else
			failCount=0; 
	} 

    int failCount2=0;
    for (i=0; <numTries) {   
		int forest2=rmCreateArea("forest2 "+i);
		rmSetAreaWarnFailure(forest2, false);
		rmSetAreaSize(forest2, rmAreaTilesToFraction(150), rmAreaTilesToFraction(400));
		rmSetAreaForestType(forest2, "Italian Forest");
		rmSetAreaForestDensity(forest2, 0.6);
		rmSetAreaForestClumpiness(forest2, 0.4);
		rmSetAreaForestUnderbrush(forest2, 0.0);
		rmSetAreaMinBlobs(forest2, 1);
		rmSetAreaMaxBlobs(forest2, 5);
		rmSetAreaMinBlobDistance(forest2, 16.0);
		rmSetAreaMaxBlobDistance(forest2, 40.0);
		rmSetAreaCoherence(forest2, 0.4);
		rmSetAreaSmoothDistance(forest2, 10);
		rmAddAreaToClass(forest2, rmClassID("classforest")); 
		rmAddAreaConstraint(forest2, forestConstraint);
		rmAddAreaConstraint(forest2, avoidAll);
		rmAddAreaConstraint(forest2, avoidTownCenter);
		rmAddAreaConstraint(forest2, avoidPlateauShort);
        rmAddAreaConstraint(forest2, Southward);
		rmAddAreaConstraint(forest2, shortAvoidImpassableLand); 
		if(rmBuildArea(forest2)==false) {
		// Stop trying once we fail 3 times in a row.
		failCount2++;
		
		if(failCount2==5)
			break;
		}

	else
			failCount2=0; 
	} 

    // Scattered BERRRIES		
	int berriesID=rmCreateObjectDef("random berries");
	rmAddObjectDefItem(berriesID, "berrybush", rmRandInt(5,8), 6.0);  // (3,5) is unit count range.  10.0 is float cluster - the range area the objects can be placed.
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, avoidTownCenter);
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, avoidRandomBerries);
	rmAddObjectDefConstraint(berriesID, avoidImpassableLand);
    rmAddObjectDefConstraint(berriesID, avoidWater10);
	rmAddObjectDefConstraint(berriesID, avoidBlockLong);
	rmPlaceObjectDefInArea(berriesID, 0, NorthIslandID, cNumberNonGaiaPlayers);
    rmPlaceObjectDefInArea(berriesID, 0, SouthIslandID, cNumberNonGaiaPlayers);

	int food1ID=rmCreateObjectDef("huntable1");
	rmAddObjectDefItem(food1ID, "Deer", rmRandInt(8,10), 6.0);
	rmSetObjectDefCreateHerd(food1ID, true);
	rmSetObjectDefMinDistance(food1ID, 0.0);
	rmSetObjectDefMaxDistance(food1ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food1ID, avoidAll);
	rmAddObjectDefConstraint(food1ID, avoidTownCenter);
	rmAddObjectDefConstraint(food1ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food1ID, southIslandConstraint);
	rmAddObjectDefConstraint(food1ID, deerConstraint);
    rmAddObjectDefConstraint(food1ID, avoidWater10);
	rmAddObjectDefConstraint(food1ID, avoidBlockLong);

	int food2ID=rmCreateObjectDef("huntable2");
	rmAddObjectDefItem(food2ID, "Deer", rmRandInt(8,10), 6.0);
	rmSetObjectDefCreateHerd(food2ID, true);
	rmSetObjectDefMinDistance(food2ID, 0.0);
	rmSetObjectDefMaxDistance(food2ID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(food2ID, avoidAll);
	rmAddObjectDefConstraint(food2ID, avoidTownCenter);
	rmAddObjectDefConstraint(food2ID, avoidImpassableLand);
	rmAddObjectDefConstraint(food2ID, northIslandConstraint);
	rmAddObjectDefConstraint(food2ID, deerConstraint);
    rmAddObjectDefConstraint(food2ID, avoidWater10);
	rmAddObjectDefConstraint(food2ID, avoidBlockLong);

	rmPlaceObjectDefAtLoc(food1ID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);
	rmPlaceObjectDefAtLoc(food2ID, 0, 0.5, 0.5, 2*cNumberNonGaiaPlayers);

	// Nuggets

	int nuggetHard= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nuggetHard, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(104, 104);
	rmAddObjectDefConstraint(nuggetHard, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHard, avoidAll);
	rmAddObjectDefConstraint(nuggetHard, avoidNuggets);
	rmAddObjectDefConstraint(nuggetHard, avoidTownCenterFar);
	rmAddObjectDefConstraint(nuggetHard, playerEdgeConstraint);
    rmAddObjectDefConstraint(nuggetHard, avoidWater20);
	rmAddObjectDefConstraint(nuggetHard, avoidBlockLong);
	rmPlaceObjectDefInArea(nuggetHard, 0, SouthIslandID, 1+cNumberNonGaiaPlayers/2);

	int nuggetHardNorth= rmCreateObjectDef("nugget hard north"); 
	rmAddObjectDefItem(nuggetHardNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(104, 104);
	rmAddObjectDefConstraint(nuggetHardNorth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidAll);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetHardNorth, playerEdgeConstraint);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidTownCenterFar);
    rmAddObjectDefConstraint(nuggetHardNorth, avoidWater20);
	rmAddObjectDefConstraint(nuggetHardNorth, avoidBlockLong);
	rmPlaceObjectDefInArea(nuggetHardNorth, 0, NorthIslandID, 1+cNumberNonGaiaPlayers/2);

	int nuggetNorth= rmCreateObjectDef("nugget easy north"); 
	rmAddObjectDefItem(nuggetNorth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmAddObjectDefConstraint(nuggetNorth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetNorth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetNorth, avoidAll);
	rmAddObjectDefConstraint(nuggetNorth, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetNorth, playerEdgeConstraint);
    rmAddObjectDefConstraint(nuggetNorth, avoidWater10);
	rmAddObjectDefConstraint(nuggetNorth, avoidBlockLong);
	rmPlaceObjectDefInArea(nuggetNorth, 0, SouthIslandID, 2+cNumberNonGaiaPlayers);

	int nuggetSouth= rmCreateObjectDef("nugget easy south"); 
	rmAddObjectDefItem(nuggetSouth, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmAddObjectDefConstraint(nuggetSouth, shortAvoidImpassableLand);
	rmAddObjectDefConstraint(nuggetSouth, avoidNuggets);
	rmAddObjectDefConstraint(nuggetSouth, avoidTownCenter);
	rmAddObjectDefConstraint(nuggetSouth, avoidAll);
	rmAddObjectDefConstraint(nuggetSouth, playerEdgeConstraint);
    rmAddObjectDefConstraint(nuggetSouth, avoidWater10);
	rmAddObjectDefConstraint(nuggetSouth, avoidBlockLong);
	rmPlaceObjectDefInArea(nuggetSouth, 0, NorthIslandID, 2+cNumberNonGaiaPlayers);


	// Fishes

	int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, fish1, 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmAddObjectDefConstraint(fishID, avoidBuilding);
	rmAddObjectDefConstraint(fishID, avoidPathBlock);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 70);

	// ____________________ LOCAL MERCENARIES ____________________
	rmDisableDefaultMercs(true);
	rmDisableCivTypeMercRestriction(true);
	rmEnableMerc("MercSwissPikeman", -1);
	rmEnableMerc("MercLandsknecht", -1);
	rmEnableMerc("MercElmeti", -1);
	rmEnableMerc("MercGreatCannon", -1);
	rmEnableMerc("deMercCannoneer", -1);
	rmEnableMerc("deMercPistoleer", -1);

	rmForbidTradeMonopoly(true);

	// ____________________ MAP OBJECTIVES ____________________
    rmObjectiveScreenSetTitle(302118);
    rmObjectiveScreenSetGoal(302119);
    rmObjectiveAdd(302120, 302121, true, true, true);

   	// ************************* TRIGGERS ******************************

	//----- Define Variables -----

	int veniceSocket1 = rmGetGroupingInstanceUnitByType(veniceInstanceID1, "zpSPCSocketVeniceCityState");
	int veniceSocket2 = rmGetGroupingInstanceUnitByType(veniceInstanceID2, "zpSPCSocketVeniceCityState");
	int veniceSocket3 = rmGetGroupingInstanceUnitByType(veniceInstanceID3, "zpSPCSocketVeniceCityState");
	int veniceSocket4 = rmGetGroupingInstanceUnitByType(veniceInstanceID4, "zpSPCSocketVeniceCityState");

	int veniceSocketMod1 = veniceSocket1+1;
	int veniceSocketMod2 = veniceSocket2+1;
	int veniceSocketMod3 = veniceSocket3+1;
	int veniceSocketMod4 = veniceSocket4+1;

	int veniceBasilica1 = rmGetGroupingInstanceUnitByType(veniceInstanceID1, "zpSPCSanMarco");
	int veniceBasilica2 = rmGetGroupingInstanceUnitByType(veniceInstanceID2, "zpGreatBasilica");
	int veniceBasilica3 = rmGetGroupingInstanceUnitByType(veniceInstanceID3, "zpGreatBasilica");
	int veniceBasilica4 = rmGetGroupingInstanceUnitByType(veniceInstanceID4, "zpGreatBasilica");

	int veniceProduction1 = rmGetGroupingInstanceUnitByType(veniceInstanceID1, "deSPCGreatBank");
	int veniceProduction2 = rmGetGroupingInstanceUnitByType(veniceInstanceID2, "deSPCGreatBank");
	int veniceProduction3 = rmGetGroupingInstanceUnitByType(veniceInstanceID3, "zpSPCCapturableFactoryMed");
	int veniceProduction4 = rmGetGroupingInstanceUnitByType(veniceInstanceID4, "zpSPCCapturableFactoryMed");

	if (islandVariation ==0){
		int veniceMonastery1 = rmGetGroupingInstanceUnitByType(veniceInstanceID1, "zpSPCCathedral");
		int veniceMonastery2 = rmGetGroupingInstanceUnitByType(veniceInstanceID2, "zpJesuitCathedral");
	}
	else{
		veniceMonastery1 = rmGetGroupingInstanceUnitByType(veniceInstanceID1, "zpJesuitCathedral");
		veniceMonastery2 = rmGetGroupingInstanceUnitByType(veniceInstanceID2, "zpSPCCathedral");
	}

	int veniceFixedGun1 = rmGetGroupingInstanceUnitByType(veniceInstanceID1, "zpSPCFixedGunBase");
	int veniceFixedGun2 = rmGetGroupingInstanceUnitByType(veniceInstanceID2, "zpSPCFixedGunBase");

	if (peninsulaVariation ==0){
		int veniceMonastery3 = rmGetGroupingInstanceUnitByType(veniceInstanceID3, "zpCathedralOrthodox");
		int veniceMonastery4 = rmGetGroupingInstanceUnitByType(veniceInstanceID4, "zpPalazoAuditore");
	}
	else{
		veniceMonastery3 = rmGetGroupingInstanceUnitByType(veniceInstanceID3, "zpPalazoAuditore");
		veniceMonastery4 = rmGetGroupingInstanceUnitByType(veniceInstanceID4, "zpCathedralOrthodox");
	}

	int veniceCenter1 = rmGetGroupingInstanceUnitByType(veniceInstanceID1, "zpSPCWaterSpawnPoint");
	int veniceCenter2 = rmGetGroupingInstanceUnitByType(veniceInstanceID2, "zpSPCWaterSpawnPoint");
	int veniceCenter3 = rmGetGroupingInstanceUnitByType(veniceInstanceID3, "zpSPCWaterSpawnPoint");
	int veniceCenter4 = rmGetGroupingInstanceUnitByType(veniceInstanceID4, "zpSPCWaterSpawnPoint");

	int veniceCenterB1 = rmGetGroupingInstanceUnitByType(veniceInstanceID1, "zpSPCWaterSpawnPointB");
	int veniceCenterB2 = rmGetGroupingInstanceUnitByType(veniceInstanceID2, "zpSPCWaterSpawnPointB");
	int veniceCenterB3 = rmGetGroupingInstanceUnitByType(veniceInstanceID3, "zpSPCWaterSpawnPointB");
	int veniceCenterB4 = rmGetGroupingInstanceUnitByType(veniceInstanceID4, "zpSPCWaterSpawnPointB");

	int veniceNugget1 = rmGetGroupingInstanceUnitByType(veniceInstanceID1, "zpNuggetInvisible");
	int veniceNugget2 = rmGetGroupingInstanceUnitByType(veniceInstanceID2, "zpNuggetInvisible");
	int veniceNugget3 = rmGetGroupingInstanceUnitByType(veniceInstanceID3, "zpNuggetInvisible");
	int veniceNugget4 = rmGetGroupingInstanceUnitByType(veniceInstanceID4, "zpNuggetInvisible");

	int veniceFixedGunSocket1 = rmGetGroupingInstanceUnitByType(veniceInstanceID1, "zpSPCFixedGunSocket");
	int veniceFixedGunSocket2 = rmGetGroupingInstanceUnitByType(veniceInstanceID2, "zpSPCFixedGunSocket");

	int veniceTower31 = rmGetGroupingInstanceUnitByType(veniceInstanceID3, "deSPCSocketCityTower");
	int veniceTower32 = rmGetGroupingInstanceUnitByType(veniceInstanceID3, "zpSPCSocketCityTowerClone");
	int veniceTower41 = rmGetGroupingInstanceUnitByType(veniceInstanceID4, "deSPCSocketCityTower");
	int veniceTower42 = rmGetGroupingInstanceUnitByType(veniceInstanceID4, "zpSPCSocketCityTowerClone");


	int veniceBasilicaMod1 = veniceBasilica1+1;
	int veniceBasilicaMod2 = veniceBasilica2+1;
	int veniceBasilicaMod3 = veniceBasilica3+1;
	int veniceBasilicaMod4 = veniceBasilica4+1;

	int veniceProductionMod1 = veniceProduction1+1;
	int veniceProductionMod2 = veniceProduction2+1;
	int veniceProductionMod3 = veniceProduction3+1;
	int veniceProductionMod4 = veniceProduction4+1;

	int veniceMonasteryMod1 = veniceMonastery1+1;
	int veniceMonasteryMod2 = veniceMonastery2+1;
	int veniceMonasteryMod3 = veniceMonastery3+1;
	int veniceMonasteryMod4 = veniceMonastery4+1;

	int veniceFixedGunMod1 = veniceFixedGun1+1;
	int veniceFixedGunMod2 = veniceFixedGun2+1;

	int veniceCenterMod1 = veniceCenter1+1;
	int veniceCenterMod2 = veniceCenter2+1;
	int veniceCenterMod3 = veniceCenter3+1;
	int veniceCenterMod4 = veniceCenter4+1;

	int veniceCenterModB1 = veniceCenterB1+1;
	int veniceCenterModB2 = veniceCenterB2+1;
	int veniceCenterModB3 = veniceCenterB3+1;
	int veniceCenterModB4 = veniceCenterB4+1;

	int veniceNuggetMod1 = veniceNugget1+1;
	int veniceNuggetMod2 = veniceNugget2+1;
	int veniceNuggetMod3 = veniceNugget3+1;
	int veniceNuggetMod4 = veniceNugget4+1;

	int veniceFixedGunSocketMod1 = veniceFixedGunSocket1+1;
	int veniceFixedGunSocketMod2 = veniceFixedGunSocket2+1;

	int veniceTower31Mod = veniceTower31+1;
	int veniceTower32Mod = veniceTower32+1;
	int veniceTower41Mod = veniceTower41+1;
	int veniceTower42Mod = veniceTower42+1;

	int cityStateSockets = xsArrayCreateInt(4, -1, "City State Sockets");
    xsArraySetInt(cityStateSockets, 0, veniceSocketMod1);
    xsArraySetInt(cityStateSockets, 1, veniceSocketMod2);
    xsArraySetInt(cityStateSockets, 2, veniceSocketMod3);
    xsArraySetInt(cityStateSockets, 3, veniceSocketMod4);

	int cityStateCenters = xsArrayCreateInt(4, -1, "City State Centers");
    xsArraySetInt(cityStateCenters, 0, veniceCenterMod1);
    xsArraySetInt(cityStateCenters, 1, veniceCenterMod2);
    xsArraySetInt(cityStateCenters, 2, veniceCenterMod3);
    xsArraySetInt(cityStateCenters, 3, veniceCenterMod4);

	int socketCityStateID = -1;
	int centerCityStateID = -1;

	vector veniceLoc1 = rmGetUnitPosition(veniceCenter1);
	vector veniceLoc2 = rmGetUnitPosition(veniceCenter2);
	vector veniceLoc3 = rmGetUnitPosition(veniceCenter3);
	vector veniceLoc4 = rmGetUnitPosition(veniceCenter4);

	vector veniceSocketLoc1 = rmGetUnitPosition(veniceSocket1);
	vector veniceSocketLoc2 = rmGetUnitPosition(veniceSocket2);
	vector veniceSocketLoc3 = rmGetUnitPosition(veniceSocket3);
	vector veniceSocketLoc4 = rmGetUnitPosition(veniceSocket4);

	string guardianUnit = "deSPCCityGuard";

	// Victory Timer
	int victoryCountDown = 480;
	int socketMinimapFlareDuration = 10;

	// Starting techs

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechdeEUMapUpdateVisuals"); // Europen Map
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID", i);
        rmSetTriggerEffectParam("TechID","cTechzpEnableSPCCityStateTechsClone"); // Mercenaries
        rmSetTriggerEffectParamInt("Status", 2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
        rmSetTriggerEffectParamInt("PlayerID", i);
        rmSetTriggerEffectParam("TechID","cTechzpBonusVenetians"); // Mercenaries
        rmSetTriggerEffectParamInt("Status", 2);
	}
	rmAddTriggerEffect("Player : Override Civilization for Flag");
	rmSetTriggerEffectParamInt("Player",0);
	rmSetTriggerEffectParam("Civilization","zpVenetians");
	rmAddTriggerEffect("Player : Override Civilization Name");
	rmSetTriggerEffectParamInt("Player",0);
	rmSetTriggerEffectParam("StringID","302124");
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParamInt("Level",1);

	for(k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AI Techs"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpSPCVeniceCityStatesAI"); // Only for the AI to train the city state units from sockets
	rmSetTriggerEffectParamInt("Status",2);
	}

	// Conversion Suspend
	rmCreateTrigger("Buildings Convert OFF");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+veniceSocketMod1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+veniceSocketMod2);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+veniceSocketMod3);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+veniceSocketMod4);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

    rmCreateTrigger("Socket 1 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+veniceSocketMod1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+veniceSocketMod1, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+veniceSocketMod1, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

    rmCreateTrigger("Socket 2 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+veniceSocketMod2);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+veniceSocketMod2, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+veniceSocketMod2, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Socket 3 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+veniceSocketMod3);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+veniceSocketMod3, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+veniceSocketMod3, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

    rmCreateTrigger("Socket 4 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+veniceSocketMod4);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+veniceSocketMod4, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+veniceSocketMod4, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Victory Conditions

	for(i = 1; < cNumberTeams+1){
        rmCreateTrigger("TeamVictory"+i);
		rmCreateTrigger("Victory_Counter"+i);
		rmCreateTrigger("Victory_Counter_OFF"+i);
	}

    for(i = 1; < cNumberTeams+1){
        // Team Victory 
		rmSwitchToTrigger(rmTriggerID("TeamVictory"+i));
		rmAddTriggerEffect("Team Victory");
        rmSetTriggerEffectParamInt("TeamID", i);
        rmSetTriggerPriority(4); 
        rmSetTriggerActive(false);
        rmSetTriggerRunImmediately(true);
        rmSetTriggerLoop(false);

        // Victory Counter
		rmSwitchToTrigger(rmTriggerID("Victory_Counter"+i));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID",i);
		rmSetTriggerConditionParam("Protounit","zpTradingPostCaptureNaval");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",3);
		rmAddTriggerEffect("Counter:Add Timer");
		rmSetTriggerEffectParam("Name","VictoryCounter"+i);
		rmSetTriggerEffectParamInt("Start", victoryCountDown);
		rmSetTriggerEffectParamInt("Stop",0);
		rmSetTriggerEffectParamInt("Event", rmTriggerID("TeamVictory"+i));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Victory_Counter_OFF"+i));
		rmAddTriggerEffect("Counter Set Text Team");
        rmSetTriggerEffectParam("Name", "VictoryCounter"+i);
        rmSetTriggerEffectParam("Msg", "{302138}");
        rmSetTriggerEffectParam("EnemyMsg", "{302139}");
        rmSetTriggerEffectParamInt("RefTeamID", i);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Victory_Counter_OFF"+i));
		rmAddTriggerCondition("Team Unit Count");
		rmSetTriggerConditionParamInt("TeamID",i);
		rmSetTriggerConditionParam("Protounit","zpTradingPostCaptureNaval");
		rmSetTriggerConditionParam("Op","<");
		rmSetTriggerConditionParamInt("Count",3);
		rmAddTriggerEffect("Counter Stop");
		rmSetTriggerEffectParam("Name","VictoryCounter"+i);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Victory_Counter"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

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

	// Update ports

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Update TR Plr"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpVeniceTradeRouteUpgrade");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParamInt("Level",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
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
		rmCreateTrigger("Activate Venice"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpVenetianExpansion"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffVenice"); //operator
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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Venice"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Galley training

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("TrainGalley1ON Plr"+k);
		rmCreateTrigger("TrainGalley1OFF Plr"+k);
		rmCreateTrigger("TrainGalley1TIME Plr"+k);

		rmCreateTrigger("TrainGalley2ON Plr"+k);
		rmCreateTrigger("TrainGalley2OFF Plr"+k);
		rmCreateTrigger("TrainGalley2TIME Plr"+k);

		rmCreateTrigger("TrainGalley3ON Plr"+k);
		rmCreateTrigger("TrainGalley3OFF Plr"+k);
		rmCreateTrigger("TrainGalley3TIME Plr"+k);

		rmCreateTrigger("TrainGalley4ON Plr"+k);
		rmCreateTrigger("TrainGalley4OFF Plr"+k);
		rmCreateTrigger("TrainGalley4TIME Plr"+k);

		rmSwitchToTrigger(rmTriggerID("TrainGalley4ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod4);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpVeniceGalleyProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley4"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley4OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley4TIME_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainGalley4OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley4ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainGalley4TIME_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpVeniceGalleyBuildLimitReduceShadow"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley4"); //operator
		rmSetTriggerEffectParamInt("Status",0);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainGalley3ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod3);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpVeniceGalleyProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley3"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley3OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley3TIME_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainGalley3OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley3ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainGalley3TIME_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpVeniceGalleyBuildLimitReduceShadow"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley3"); //operator
		rmSetTriggerEffectParamInt("Status",0);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);


		rmSwitchToTrigger(rmTriggerID("TrainGalley2ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod2);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpVeniceGalleyProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley2"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley2OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley2TIME_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainGalley2OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley2ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainGalley2TIME_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpVeniceGalleyBuildLimitReduceShadow"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley2"); //operator
		rmSetTriggerEffectParamInt("Status",0);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainGalley1ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod1);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpVeniceGalleyProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley1"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1TIME_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainGalley1OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("TrainGalley1TIME_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpVeniceGalleyBuildLimitReduceShadow"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainVeniceGalley1"); //operator
		rmSetTriggerEffectParamInt("Status",0);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Galeass Training

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("trainGalleass1ON Plr"+k);
		rmCreateTrigger("trainGalleass1OFF Plr"+k);
		rmCreateTrigger("trainGalleass1TIME Plr"+k);

		rmCreateTrigger("trainGalleass2ON Plr"+k);
		rmCreateTrigger("trainGalleass2OFF Plr"+k);
		rmCreateTrigger("trainGalleass2TIME Plr"+k);

		rmCreateTrigger("trainGalleass3ON Plr"+k);
		rmCreateTrigger("trainGalleass3OFF Plr"+k);
		rmCreateTrigger("trainGalleass3TIME Plr"+k);

		rmCreateTrigger("trainGalleass4ON Plr"+k);
		rmCreateTrigger("trainGalleass4OFF Plr"+k);
		rmCreateTrigger("trainGalleass4TIME Plr"+k);

		rmSwitchToTrigger(rmTriggerID("trainGalleass4ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod4);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpGalleassProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass4"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass4OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass4TIME_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("trainGalleass4OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass4ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		
		rmSwitchToTrigger(rmTriggerID("trainGalleass4TIME_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpGalleassBuildLimitReduceShadow"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass4"); //operator
		rmSetTriggerEffectParamInt("Status",0);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("trainGalleass3ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod3);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpGalleassProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass3"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass3OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass3TIME_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("trainGalleass3OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass3ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		
		rmSwitchToTrigger(rmTriggerID("trainGalleass3TIME_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpGalleassBuildLimitReduceShadow"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass3"); //operator
		rmSetTriggerEffectParamInt("Status",0);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("trainGalleass2ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod2);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpGalleassProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass2"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass2OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass2TIME_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("trainGalleass2OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass2ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
		
		rmSwitchToTrigger(rmTriggerID("trainGalleass2TIME_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpGalleassBuildLimitReduceShadow"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass2"); //operator
		rmSetTriggerEffectParamInt("Status",0);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("trainGalleass1ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod1);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpGalleassProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass1"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1OFF_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1TIME_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("trainGalleass1OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("trainGalleass1TIME_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",200);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpGalleassBuildLimitReduceShadow"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainGalleass1"); //operator
		rmSetTriggerEffectParamInt("Status",0);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// AI Builds City states

	// AI Builds Pirate City States from Sockets
	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("BuildFixedGun1_ON_Plr"+k);
	rmCreateTrigger("BuildFixedGun1_OFF_Plr"+k);
	rmCreateTrigger("BuildFixedGun2_ON_Plr"+k);
	rmCreateTrigger("BuildFixedGun2_OFF_Plr"+k);
	rmCreateTrigger("BuildTower31_ON_Plr"+k);
	rmCreateTrigger("BuildTower31_OFF_Plr"+k);
	rmCreateTrigger("BuildTower32_ON_Plr"+k);
	rmCreateTrigger("BuildTower32_OFF_Plr"+k);
	rmCreateTrigger("BuildTower41_ON_Plr"+k);
	rmCreateTrigger("BuildTower41_OFF_Plr"+k);
	rmCreateTrigger("BuildTower42_ON_Plr"+k);
	rmCreateTrigger("BuildTower42_OFF_Plr"+k);

	rmSwitchToTrigger(rmTriggerID("BuildFixedGun1_ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+veniceFixedGunSocketMod1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCFixedGunAIProxy");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("Socket",""+veniceFixedGunSocketMod1);
	rmSetTriggerEffectParam("Protounit","zpSPCFixedGun");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun1_OFF_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BuildFixedGun1_OFF_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun1_ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BuildFixedGun2_ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+veniceFixedGunSocketMod2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCFixedGunAIProxy");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("Socket",""+veniceFixedGunSocketMod2);
	rmSetTriggerEffectParam("Protounit","zpSPCFixedGun");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun2_OFF_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BuildFixedGun2_OFF_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun2_ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BuildTower31_ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+veniceTower31Mod);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("Socket",""+veniceTower31Mod);
	rmSetTriggerEffectParam("Protounit","deSPCCityTower");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower31_OFF_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BuildTower31_OFF_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower31_ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BuildTower32_ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+veniceTower32Mod);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("Socket",""+veniceTower32Mod);
	rmSetTriggerEffectParam("Protounit","deSPCCityTower");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower32_OFF_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BuildTower32_OFF_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower32_ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BuildTower41_ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+veniceTower41Mod);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("Socket",""+veniceTower41Mod);
	rmSetTriggerEffectParam("Protounit","deSPCCityTower");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower41_OFF_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BuildTower41_OFF_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower41_ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BuildTower42_ON_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+veniceTower42Mod);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Socket Build");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("Socket",""+veniceTower42Mod);
	rmSetTriggerEffectParam("Protounit","deSPCCityTower");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower42_OFF_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("BuildTower42_OFF_Plr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower42_ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	}

	// Specific for AI

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AI_Check1_Plr"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun1_ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("AI_Check2_Plr"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun2_ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("AI_Check3_Plr"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower31_ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower32_ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("AI_Check4_Plr"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower41_ON_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower42_ON_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Venice City States

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Venice1on Player"+k);
		rmCreateTrigger("Venice1off Player"+k);

		rmCreateTrigger("Venice2on Player"+k);
		rmCreateTrigger("Venice2off Player"+k);

		rmCreateTrigger("Venice3on Player"+k);
		rmCreateTrigger("Venice3off Player"+k);

		rmCreateTrigger("Venice4on Player"+k);
		rmCreateTrigger("Venice4off Player"+k);

		rmSwitchToTrigger(rmTriggerID("Venice1on_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod1);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceSocketMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag1");
		rmSetTriggerEffectParamInt("Dist",150);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceBasilicaMod1);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceProductionMod1);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceMonasteryMod1);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceFixedGunMod1);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceFixedGunMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFixedGun");
		rmSetTriggerEffectParamInt("Dist",10);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceFixedGunMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFixedGunSocket");
		rmSetTriggerEffectParamInt("Dist",10);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCinematicRevealer");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		if (islandVariation == 0)
			rmSetTriggerEffectParam("TechID","cTechzpUnlockCathedralMaltese"); // Maltese
		else
			rmSetTriggerEffectParam("TechID","cTechzpUnlockCathedralJesuit"); // Jesuit
		rmSetTriggerEffectParamInt("Status",2);
		for(x=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Flare Minimap");
			rmSetTriggerEffectParamInt("PlayerID", x, false);
			rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
			rmSetTriggerEffectParam("Position", ""+xsVectorGetX(veniceLoc1)+","+xsVectorGetY(veniceLoc1)+","+xsVectorGetZ(veniceLoc1), false);
			rmSetTriggerEffectParam("Flash", "True", false);
		}

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice1off_Player"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AI_Check1_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Venice1off_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod1);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceSocketMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag1");
		rmSetTriggerEffectParamInt("Dist",150);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceBasilicaMod1);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceProductionMod1);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceMonasteryMod1);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceFixedGunMod1);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceFixedGunMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCFixedGun");
		rmSetTriggerEffectParamInt("Dist",10);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceFixedGunMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCFixedGunSocket");
		rmSetTriggerEffectParamInt("Dist",10);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCinematicRevealer");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod1);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		if (islandVariation == 0)
			rmSetTriggerEffectParam("TechID","cTechzpLockCathedralMaltese"); // Maltese
		else
			rmSetTriggerEffectParam("TechID","cTechzpLockCathedralJesuit"); // Jesuit
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Flare Minimap");
		rmSetTriggerEffectParamInt("PlayerID", k, false);
		rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
		rmSetTriggerEffectParam("Position", ""+xsVectorGetX(veniceLoc1)+","+xsVectorGetY(veniceLoc1)+","+xsVectorGetZ(veniceLoc1), false);
		rmSetTriggerEffectParam("Flash", "True", false);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice1on_Player"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley1ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass1ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun1_ON_Plr"+k));
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Venice2on_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod2);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceSocketMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag2");
		rmSetTriggerEffectParamInt("Dist",150);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceBasilicaMod2);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceProductionMod2);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceMonasteryMod2);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceFixedGunMod2);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceFixedGunMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFixedGun");
		rmSetTriggerEffectParamInt("Dist",10);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceFixedGunMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCFixedGunSocket");
		rmSetTriggerEffectParamInt("Dist",10);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCinematicRevealer");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		if (islandVariation == 1)
			rmSetTriggerEffectParam("TechID","cTechzpUnlockCathedralMaltese"); // Maltese
		else
			rmSetTriggerEffectParam("TechID","cTechzpUnlockCathedralJesuit"); // Jesuit
		rmSetTriggerEffectParamInt("Status",2);
		for(x=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Flare Minimap");
			rmSetTriggerEffectParamInt("PlayerID", x, false);
			rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
			rmSetTriggerEffectParam("Position", ""+xsVectorGetX(veniceLoc2)+","+xsVectorGetY(veniceLoc2)+","+xsVectorGetZ(veniceLoc2), false);
			rmSetTriggerEffectParam("Flash", "True", false);
		}

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice2off_Player"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley2ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass2ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AI_Check2_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Venice2off_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod2);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceSocketMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag2");
		rmSetTriggerEffectParamInt("Dist",150);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceBasilicaMod2);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceProductionMod2);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceMonasteryMod2);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceFixedGunMod2);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceFixedGunMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCFixedGun");
		rmSetTriggerEffectParamInt("Dist",10);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceFixedGunMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCFixedGunSocket");
		rmSetTriggerEffectParamInt("Dist",10);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCinematicRevealer");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod2);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		if (islandVariation == 1)
			rmSetTriggerEffectParam("TechID","cTechzpLockCathedralMaltese"); // Maltese
		else
			rmSetTriggerEffectParam("TechID","cTechzpLockCathedralJesuit"); // Jesuit
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Flare Minimap");
		rmSetTriggerEffectParamInt("PlayerID", k, false);
		rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
		rmSetTriggerEffectParam("Position", ""+xsVectorGetX(veniceLoc2)+","+xsVectorGetY(veniceLoc2)+","+xsVectorGetZ(veniceLoc2), false);
		rmSetTriggerEffectParam("Flash", "True", false);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice2on_Player"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley2ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass2ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun2_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Venice3on_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod3);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceSocketMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag3");
		rmSetTriggerEffectParamInt("Dist",150);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceBasilicaMod3);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceProductionMod3);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceMonasteryMod3);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","deSPCSocketCityTower");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","deSPCCityTower");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCinematicRevealer");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterModB3);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
		rmSetTriggerEffectParamInt("Dist",10);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		if (peninsulaVariation == 0)
			rmSetTriggerEffectParam("TechID","cTechzpUnlockCathedraOrthodox"); // Orthodox
		else
			rmSetTriggerEffectParam("TechID","cTechzpUnlockPalazzoAuditore"); // Auditore
		rmSetTriggerEffectParamInt("Status",2);
		for(x=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Flare Minimap");
			rmSetTriggerEffectParamInt("PlayerID", x, false);
			rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
			rmSetTriggerEffectParam("Position", ""+xsVectorGetX(veniceLoc3)+","+xsVectorGetY(veniceLoc3)+","+xsVectorGetZ(veniceLoc3), false);
			rmSetTriggerEffectParam("Flash", "True", false);
		}

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice3off_Player"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley3ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass3ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AI_Check3_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Venice3off_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod3);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceSocketMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag3");
		rmSetTriggerEffectParamInt("Dist",150);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceBasilicaMod3);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceProductionMod3);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceMonasteryMod3);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","deSPCSocketCityTower");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","deSPCCityTower");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCinematicRevealer");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterModB3);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
		rmSetTriggerEffectParamInt("Dist",10);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		if (peninsulaVariation == 0)
			rmSetTriggerEffectParam("TechID","cTechzpLockCathedralOrthodox"); // Orthodox
		else
			rmSetTriggerEffectParam("TechID","cTechzpLockPalazzoAuditore"); // Auditore
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Flare Minimap");
		rmSetTriggerEffectParamInt("PlayerID", k, false);
		rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
		rmSetTriggerEffectParam("Position", ""+xsVectorGetX(veniceLoc3)+","+xsVectorGetY(veniceLoc3)+","+xsVectorGetZ(veniceLoc3), false);
		rmSetTriggerEffectParam("Flash", "True", false);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice3on_Player"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley3ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass3ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower31_ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower32_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Venice4on_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod4);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceSocketMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag4");
		rmSetTriggerEffectParamInt("Dist",150);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceBasilicaMod4);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceProductionMod4);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceMonasteryMod4);
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","deSPCSocketCityTower");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","deSPCCityTower");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCinematicRevealer");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterModB4);
		rmSetTriggerEffectParamInt("SrcPlayer",0);
		rmSetTriggerEffectParamInt("TrgPlayer",k);
		rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
		rmSetTriggerEffectParamInt("Dist",10);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		if (peninsulaVariation == 1)
			rmSetTriggerEffectParam("TechID","cTechzpUnlockCathedraOrthodox"); // Orthodox
		else
			rmSetTriggerEffectParam("TechID","cTechzpUnlockPalazzoAuditore"); // Auditore
		rmSetTriggerEffectParamInt("Status",2);
		for(x=1; <= cNumberNonGaiaPlayers) {
			rmAddTriggerEffect("Flare Minimap");
			rmSetTriggerEffectParamInt("PlayerID", x, false);
			rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
			rmSetTriggerEffectParam("Position", ""+xsVectorGetX(veniceLoc4)+","+xsVectorGetY(veniceLoc4)+","+xsVectorGetZ(veniceLoc4), false);
			rmSetTriggerEffectParam("Flash", "True", false);
		}

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice4off_Player"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley4ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass4ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AI_Check4_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Venice4off_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+veniceSocketMod4);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceSocketMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpVenetianWaterSpawnFlag4");
		rmSetTriggerEffectParamInt("Dist",150);

		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceBasilicaMod4);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceProductionMod4);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert");
		rmSetTriggerEffectParam("SrcObject",""+veniceMonasteryMod4);
		rmSetTriggerEffectParamInt("PlayerID",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","deSPCSocketCityTower");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","deSPCCityTower");
		rmSetTriggerEffectParamInt("Dist",50);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCinematicRevealer");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterMod4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
		rmSetTriggerEffectParamInt("Dist",60);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",""+veniceCenterModB4);
		rmSetTriggerEffectParamInt("SrcPlayer",k);
		rmSetTriggerEffectParamInt("TrgPlayer",0);
		rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
		rmSetTriggerEffectParamInt("Dist",10);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		if (peninsulaVariation == 1)
			rmSetTriggerEffectParam("TechID","cTechzpLockCathedralOrthodox"); // Orthodox
		else
			rmSetTriggerEffectParam("TechID","cTechzpLockPalazzoAuditore"); // Auditore
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Flare Minimap");
		rmSetTriggerEffectParamInt("PlayerID", k, false);
		rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
		rmSetTriggerEffectParam("Position", ""+xsVectorGetX(veniceLoc4)+","+xsVectorGetY(veniceLoc4)+","+xsVectorGetZ(veniceLoc4), false);
		rmSetTriggerEffectParam("Flash", "True", false);

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Venice4on_Player"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainGalley4ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("trainGalleass4ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower41_ON_Plr"+k));
		rmAddTriggerEffect("Disable Trigger");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower42_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
   	}

   // Venice City States Heal

	// Venice City States

	for (s=1; <= 4) {
		for (k=1; <= cNumberNonGaiaPlayers) {		
			socketCityStateID = xsArrayGetInt(cityStateSockets, s-1);
			centerCityStateID = xsArrayGetInt(cityStateCenters, s-1);
			rmCreateTrigger("City State "+s+" Heal"+k);
			rmAddTriggerCondition("Team Player Controls Socket");
			rmSetTriggerConditionParamInt("PlayerID", 1, false);
			rmSetTriggerConditionParamInt("Socket", socketCityStateID, false);
			rmAddTriggerCondition("Tech Status Equals");
			rmSetTriggerConditionParamInt("PlayerID", k, false);
			rmSetTriggerConditionParamInt("TechID", rmGetTechID("DEPapalBlessingShadow"), false);
			rmSetTriggerConditionParamInt("Status", 2, false);
			rmAddTriggerCondition("Timer ms");
            rmSetTriggerConditionParamInt("Param1", 1000, false);
			rmAddTriggerEffect("Heal Units Percent in Area");
			rmSetTriggerEffectParamInt("SrcObject", centerCityStateID, false);
			rmSetTriggerEffectParamInt("Player", k, false);
			rmSetTriggerEffectParam("UnitType", "LogicalTypeGarrisonInShips", false);
			rmSetTriggerEffectParamFloat("Dist", 50, false);
			rmSetTriggerEffectParamFloat("HealPct", 1.00, false);
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(true);
		}
   	}

	// AI Venice Leaders

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
			rmSetTriggerEffectParam("TechID","cTechzpConsulateVeniceDolphin"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (revFraction==2)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateVeniceContarini"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		if (revFraction==3)
		{
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpConsulateVeniceCornaro"); //operator
			rmSetTriggerEffectParamInt("Status",2);
		}
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}
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
rmSetTriggerPriority(4);
rmSetTriggerActive(true);
rmSetTriggerRunImmediately(true);
rmSetTriggerLoop(false);
}*/




    
	




	
    
	
} // END