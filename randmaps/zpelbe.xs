// ELBE
// July 2025

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;
int evenOdd = -1;


include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

 string fish1 = "FishSalmon";

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
	int subCiv1=-1;
	int subCiv2=-1;
    int subCiv3=-1;

	if (rmAllocateSubCivs(4) == true)
	{
		subCiv0=rmGetCivID("zphansakontor");
		rmEchoInfo("subCiv0 is zphansakontor "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "zphansakontor");

		subCiv1=rmGetCivID("zphussites");
		rmEchoInfo("subCiv1 is zphussites "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "zphussites");
  
		subCiv2=rmGetCivID("zpprinceelector");
		rmEchoInfo("subCiv2 is zpprinceelector "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "zpprinceelector");

        subCiv3=rmGetCivID("NatPirates");
		rmEchoInfo("subCiv3 is NatPirates "+subCiv3);
		if (subCiv3 >= 0)
			rmSetSubCiv(3, "NatPirates");
	}

    int size = 400;
	if (PlayerNum >=3)
		size = 500;
	if (PlayerNum >=5)
		size = 600;
	if (PlayerNum >=7)
		size = 660;
	rmSetMapSize(size, size);
	// rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.5, 3.0);  // DAL - original
	
	rmSetMapElevationHeightBlend(1);
	
	// Picks a default water height
	rmSetSeaLevel(1.0);
   
   	// LIGHT SET

	rmSetLightingSet("cascade_range_skirmish");


	// Picks default terrain and water
	//rmSetMapElevationParameters(cElevTurbulence, 0.03, 5, 0.7, 4.0);
	//rmSetMapElevationParameters(cElevTurbulence, 0.05, 6, 0.7, 6.0);
	rmSetSeaType("ZP Hansa Baltic Ocean");
	rmEnableLocalWater(false);
	//rmSetBaseTerrainMix("nwt_grass1");
	//rmTerrainInitialize("nwterritory\ground_grass2_nwt", 1.0);
    //rmSetSeaType(seaType);
    rmTerrainInitialize("water");
	rmSetMapType("grass");
	rmSetMapType("water");
    rmSetMapType("default");
    rmSetMapType("centralEurope");
    rmSetMapType("euroTradeRouteCapture");
	rmSetMapType("piratehistoricalmap");

	chooseMercs();

	// Corner constraint.
	rmSetWorldCircleConstraint(true);

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

	// -------------Define constraints
	// These are used to have objects and areas avoid each other
	
	// Map edge constraints
	int playerEdgeConstraint=rmCreateBoxConstraint("player edge of map", rmXTilesToFraction(10), rmZTilesToFraction(10), 1.0-rmXTilesToFraction(10), 1.0-rmZTilesToFraction(10), 0.01);
	int longPlayerEdgeConstraint=rmCreateBoxConstraint("long avoid edge of map", rmXTilesToFraction(20), rmZTilesToFraction(20), 1.0-rmXTilesToFraction(20), 1.0-rmZTilesToFraction(20), 0.01);
	
	int avoidWater5 = rmCreateTerrainDistanceConstraint("avoid water very short", "Land", false, 5.0);
    int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 10.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 20.0);
	int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 30.0);
	int centerConstraint=rmCreateClassDistanceConstraint("stay away from center", rmClassID("center"), 30.0);
	int centerConstraintFar=rmCreateClassDistanceConstraint("stay away from center far", rmClassID("center"), 60.0);
	int circleConstraint=rmCreatePieConstraint("circle Constraint", 0.5, 0.5, 0, rmZFractionToMeters(0.47), rmDegreesToRadians(0), rmDegreesToRadians(360));
	int avoidLand = rmCreateTerrainDistanceConstraint("avoid land medium", "Water", false, 20.0);
	


	// Cardinal Directions
	int Northward=rmCreatePieConstraint("northMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(315), rmDegreesToRadians(135));
	int Southward=rmCreatePieConstraint("southMapConstraint", 0.5, 0.5, 0, rmZFractionToMeters(0.5), rmDegreesToRadians(135), rmDegreesToRadians(315));
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
    int flagEdgeConstraint=rmCreatePieConstraint("flag edge of map", 0.5, 0.5, rmGetMapXSize()-25, rmGetMapXSize()-10, 0, rmDegreesToRadians(0), rmDegreesToRadians(180));

	// Nature avoidance
	// int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 18.0);
	
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 20.0);
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
	int avoidNuggets=rmCreateClassDistanceConstraint("stuff avoids nuggets", rmClassID("nuggets"), 60.0);
	int deerConstraint=rmCreateTypeDistanceConstraint("avoid the deer", "deer", 40.0);
	int shortNuggetConstraint=rmCreateTypeDistanceConstraint("avoid nugget objects", "AbstractNugget", 7.0);
	int shortDeerConstraint=rmCreateTypeDistanceConstraint("short avoid the deer", "deer", 20.0);
	int mooseConstraint=rmCreateTypeDistanceConstraint("avoid the moose", "moose", 40.0);
	int avoidSheep=rmCreateTypeDistanceConstraint("sheep avoids sheep", "sheep", 55.0);
    int flagLand = rmCreateTerrainDistanceConstraint("flag vs land", "land", true, 11.0);

	// Decoration avoidance
	int avoidAll=rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);

	// Trade route avoidance.
	int avoidTradeRoute = rmCreateTradeRouteDistanceConstraint("trade route", 7.0);
	int shortAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("short trade route", 3.0);
	int avoidTradeRouteFar = rmCreateTradeRouteDistanceConstraint("trade route far", 8.0);
	int avoidTradeRouteFar2 = rmCreateTradeRouteDistanceConstraint("trade route far 2", 10.0);
	int avoidTradeRouteFar3 = rmCreateTradeRouteDistanceConstraint("trade route far 3", 12.0);
	int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 8.0);
	int farAvoidTradeSockets = rmCreateTypeDistanceConstraint("far avoid trade sockets", "sockettraderoute", 12.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
    int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 10.0);	
	int HCspawnLand = rmCreateTerrainDistanceConstraint("HC spawn away from land", "land", true, 12.0);
	int avoidTrainStationA = rmCreateTypeDistanceConstraint("avoid trainstation a", "spSocketTrainStationA", 8.0);
	int avoidTrainStationB = rmCreateTypeDistanceConstraint("avoid trainstation b", "spSocketTrainStationB", 8.0);
    int avoidHarbour = rmCreateTypeDistanceConstraint("avoid harbour", "zpSPCPortSocket", 20.0);
	int ObjectAvoidTradeRoute = rmCreateTradeRouteDistanceConstraint("object avoid trade route", 7.0);
	int whaleVsWhaleID=rmCreateTypeDistanceConstraint("whale v whale", "MinkeWhale", 50.0);
	int whaleLand = rmCreateTerrainDistanceConstraint("whale land", "land", true, 35.0);

	// Lake Constraints
	int greatLakesConstraint=rmCreateClassDistanceConstraint("avoid the great lakes", classGreatLake, 0.1);
	int farGreatLakesConstraint=rmCreateClassDistanceConstraint("far avoid the great lakes", classGreatLake, 20.0);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
	int avoidDeepWater=rmCreateClassDistanceConstraint("stuff avoids deep water", classDeepWater, 20.0);
	int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "SocketTradeRoute", 10.0);
	int avoidSocketMedium=rmCreateTypeDistanceConstraint("avoid socket medium", "Socket", 30.0);
   	int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 40.0);
    int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 30);
	int flagVsVenice1 = rmCreateTypeDistanceConstraint("flag avoid venice 1", "zpNativeWaterSpawnFlag1", 40.0);
  	int flagVsVenice2 = rmCreateTypeDistanceConstraint("flag avoid venice 2", "zpNativeWaterSpawnFlag2", 40.0);
	int saltVsSalt = rmCreateTypeDistanceConstraint("salt avoid same", "zpSaltMineWater", 30);
    int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 5.0);


	// Native Constraints
	int avoidSufi=rmCreateTypeDistanceConstraint("stay away from Sufi", "SocketCherokee", 70.0);
	int avoidMaltese=rmCreateTypeDistanceConstraint("stay away from Maltese", "zpSocketScientists", 45.0);
	int avoidJewish=rmCreateTypeDistanceConstraint("stay away from Jewish", "zpSPCSocketWesternVillage", 25.0);
	int avoidTownCenterFar=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 30.0);
	int avoidTradeSocket=rmCreateTypeDistanceConstraint("stay away from Trade Socket", "SocketTradeRoute", 40.0);
	int avoidTradeSocketShort=rmCreateTypeDistanceConstraint("stay away from Trade Socket Short", "SocketTradeRoute", 25.0);
	int avoidTradeRouteSocketMin = rmCreateTypeDistanceConstraint("trade route socket min", "SocketTradeRoute", 25.0);
	int avoidTradeSocketFar=rmCreateTypeDistanceConstraint("stay away from Trade Socket far", "SocketTradeRoute", 40.0);
	int avoidTradeSocketFar2=rmCreateTypeDistanceConstraint("stay away from Trade Socket far 2", "SocketTradeRoute", 45.0);
	int avoidTradeRouteMin = rmCreateTradeRouteDistanceConstraint("trade route min", 5.0);
	int avoidTownCenter=rmCreateTypeDistanceConstraint("avoid Town Center Far", "townCenter", 25.0);
	int avoidTownCenterShort=rmCreateTypeDistanceConstraint("avoid Town Center Short", "townCenter", 6.0);

	// KOTH
	int avoidKOTH=rmCreateTypeDistanceConstraint("avoid koth filler", "ypKingsHill", 12.0);

	// Special
	int avoidWall=rmCreateTypeDistanceConstraint("avoid wall", "AbstractWall", 5.0);
	int avoidBridge=rmCreateTypeDistanceConstraint("avoid bridge", "zpBridgeFace", 15.0);
	int avoidBridgeLong=rmCreateTypeDistanceConstraint("avoid bridge long", "zpBridgeFace", 70.0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.10);

	// Invisible Land Mass to dock Hansa city state groupings

	int landMassID = rmCreateArea("countryside S");
    rmSetAreaSize(landMassID , 0.15, 0.15);
    rmSetAreaLocation(landMassID , 0.5, 0.65);		
    rmSetAreaCoherence(landMassID , 1.0);
    rmSetAreaBaseHeight(landMassID, 2.0);
	rmSetAreaWarnFailure(landMassID, false);
    rmSetAreaMix(landMassID, "nwt_grass1");
    rmSetAreaElevationVariation(landMassID, 0.0);
	rmAddAreaInfluenceSegment(landMassID, 0.3, 0.65, 0.7, 0.65);
    rmBuildArea(landMassID ); 


	// ********************* Trade Routes *******************************

    // Trade route must be always placed as first
	int stopperID=rmCreateObjectDef("Armored Train Stopper");
	rmAddObjectDefItem(stopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID, true);
	rmSetObjectDefMinDistance(stopperID, 0.0);
	rmSetObjectDefMaxDistance(stopperID, 0.0);

	// River trade Route  

    int tradeRouteID = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
	
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.3);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.5);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.6);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.7);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.7);
	if (cNumberNonGaiaPlayers < 3){
		rmAddTradeRouteWaypoint(tradeRouteID, 0.59, 0.7);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.59, 0.6);
	}
	else if (cNumberNonGaiaPlayers == 5 || cNumberNonGaiaPlayers == 6){
		rmAddTradeRouteWaypoint(tradeRouteID, 0.57, 0.7);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.57, 0.6);
	}
	else{
		rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.7);
		rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.6);
	}
	if (cNumberNonGaiaPlayers <7){
		rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.5);
		if (cNumberNonGaiaPlayers <5){
			rmAddTradeRouteWaypoint(tradeRouteID, 0.5, 0.3);
		}
	}


    rmBuildTradeRoute(tradeRouteID, "river_trail");

    // Place train stopper, because without it the islands son't spawn
    vector socketLoc1 = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
    rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc1);

	// Hansa Trade Route

	int tradeRouteID2 = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
   
	if (cNumberNonGaiaPlayers >= 7){
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.2, 0.8);
	}
	else{
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.2, 0.9);
	}
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.25, 0.65+rmZTilesToFraction(22));
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.4, 0.65+rmZTilesToFraction(22));
	if (cNumberNonGaiaPlayers < 3 || cNumberNonGaiaPlayers >=7){
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.65+rmZTilesToFraction(22));
	}
	else{
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.5, 0.7+rmZTilesToFraction(22));
	}
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.6, 0.65+rmZTilesToFraction(22));
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.75, 0.65+rmZTilesToFraction(22));
	if (cNumberNonGaiaPlayers >= 7){
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.8, 0.8);
	}
	else{
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.8, 0.9);
	}
    rmBuildTradeRoute(tradeRouteID2, "water_trail");


	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);

	//  ************************** River ******************************

    // River must be defined before the islands are placed
	if (cNumberNonGaiaPlayers < 5)
		int riverID = rmRiverCreate(-1, "ZP Hansa Baltic Lake", 4, 4, 39, 39); //  (-1, "new england lake", 18, 14, 5, 5)
	else
		riverID = rmRiverCreate(-1, "ZP Hansa Baltic Lake", 4, 4, 59, 59); //  (-1, "new england lake", 18, 14, 5, 5)
    rmRiverAddWaypoint(riverID, 0.3, 0.65);
    rmRiverAddWaypoint(riverID, 0.7, 0.65);
	rmRiverBuild(riverID);

    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!! ISLANDS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	// Bridge
   	int bridgeSouth = rmCreateGrouping("bridge", "Bridge_universal_long");
    rmSetGroupingMinDistance(bridgeSouth, 0.00);
    rmSetGroupingMaxDistance(bridgeSouth, 0.00);
	rmAddGroupingToClass(bridgeSouth, rmClassID("classPlateau"));

	rmPlaceGroupingAtLoc(bridgeSouth, 0, 0.5, 0.12);

    rmDefineClass("classPlateau");

	// ************** Hanseatic Settlements **************

	int socketID=rmCreateObjectDef("sockets to dock Trade Posts");
	rmSetObjectDefTradeRouteID(socketID, tradeRouteID);
	rmAddObjectDefItem(socketID, "zpTradingPostCaptureNaval", 1, 0.0);
	rmSetObjectDefMinDistance(socketID, 0.0);
  	rmSetObjectDefMaxDistance(socketID, 0.5);

	int socketID2=rmCreateObjectDef("sockets to dock Trade Posts2");
	rmSetObjectDefTradeRouteID(socketID2, tradeRouteID2);
	rmAddObjectDefItem(socketID2, "zpTradingPostCaptureNaval", 1, 0.0);
	rmSetObjectDefMinDistance(socketID2, 0.0);
  	rmSetObjectDefMaxDistance(socketID2, 0.5);

	int socketID3=rmCreateObjectDef("sockets to dock Trade Posts3");
	rmSetObjectDefTradeRouteID(socketID3, tradeRouteID);
	rmAddObjectDefItem(socketID3, "zpTradingPostCaptureNaval", 1, 0.0);
	rmSetObjectDefMinDistance(socketID3, 0.0);
  	rmSetObjectDefMaxDistance(socketID3, 0.5);

	int socketID4=rmCreateObjectDef("sockets to dock Trade Posts4");
	rmSetObjectDefTradeRouteID(socketID4, tradeRouteID2);
	rmAddObjectDefItem(socketID4, "zpTradingPostCaptureNaval", 1, 0.0);
	rmSetObjectDefMinDistance(socketID4, 0.0);
  	rmSetObjectDefMaxDistance(socketID4, 0.5);

	if (cNumberNonGaiaPlayers >=7) {
		rmPlaceObjectDefAtLoc(socketID, 0, 0.4-rmXTilesToFraction(8), 0.65-rmZTilesToFraction(5));
		rmPlaceObjectDefAtLoc(socketID3, 0, 0.6+rmXTilesToFraction(8), 0.65-rmZTilesToFraction(5));
	}
	else {
		rmPlaceObjectDefAtLoc(socketID, 0, 0.4-rmXTilesToFraction(8), 0.65-rmZTilesToFraction(1));
		rmPlaceObjectDefAtLoc(socketID3, 0, 0.6+rmXTilesToFraction(8), 0.65-rmZTilesToFraction(1));
	}

	vector ControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(socketID, 0));
	vector ControllerLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(socketID3, 0));

    // Hansa City West
   	int hansaCityWest = rmCreateGrouping("hansa1", "Hansa_CityState_01");
    rmSetGroupingMinDistance(hansaCityWest, 0.00);
    rmSetGroupingMaxDistance(hansaCityWest, 0.00);
	rmAddGroupingToClass(hansaCityWest, rmClassID("classPlateau"));

	// Hansa City East
   	int hansaCityEast = rmCreateGrouping("hansa2", "Hansa_CityState_02");
    rmSetGroupingMinDistance(hansaCityEast, 0.00);
    rmSetGroupingMaxDistance(hansaCityEast, 0.00);
	rmAddGroupingToClass(hansaCityEast, rmClassID("classPlateau"));

	// Place settlements

	rmSetNuggetDifficulty(306, 306);

	int hansaInstanceID1 = rmPlaceGroupingInstanceAtLoc(hansaCityWest, rmXMetersToFraction(xsVectorGetX(ControllerLoc1))-rmXTilesToFraction(12), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1))+rmZTilesToFraction(5), 0);

	rmPlaceObjectDefAtLoc(socketID2, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc1))-rmXTilesToFraction(16), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1))+rmZTilesToFraction(16));

	int hansaInstanceID2 = rmPlaceGroupingInstanceAtLoc(hansaCityEast, rmXMetersToFraction(xsVectorGetX(ControllerLoc3))+rmXTilesToFraction(16), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3))+rmZTilesToFraction(6), 0);

	rmPlaceObjectDefAtLoc(socketID4, 0, rmXMetersToFraction(xsVectorGetX(ControllerLoc3))+rmXTilesToFraction(14), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3))+rmZTilesToFraction(17));


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
	int avoidGroupingCenter = rmCreateTypeDistanceConstraint("avoid grouping center", "zpHanseaticChurch", 25.0);
	int avoidGroupingCenterLong = rmCreateTypeDistanceConstraint("avoid grouping center long", "zpHanseaticChurch", 50.0);
	int avoidGroupingCenterWhale = rmCreateTypeDistanceConstraint("avoid grouping center whale", "zpCinematicRevealer", 60.0);
        

    // ***************** Player islands and terrain *****************

	// Invisible water areas

    int riverArea1 = rmCreateArea("riverArea1");
	rmSetAreaSize(riverArea1 , rmAreaTilesToFraction(2700), rmAreaTilesToFraction(2700));
	if (PlayerNum >=3)
    	rmSetAreaSize(riverArea1 , rmAreaTilesToFraction(3500), rmAreaTilesToFraction(3500));
	if (PlayerNum >=5)
		rmSetAreaSize(riverArea1 , rmAreaTilesToFraction(4500), rmAreaTilesToFraction(4500));
	if (PlayerNum >=7)
		rmSetAreaSize(riverArea1 , rmAreaTilesToFraction(6000), rmAreaTilesToFraction(6000));
    rmSetAreaLocation(riverArea1 , 0.5, 0.6);		
    rmSetAreaCoherence(riverArea1 , 0.6);
    rmSetAreaElevationVariation(riverArea1, 0.0);
	rmAddAreaToClass(riverArea1, classGreatLake);
	rmAddAreaInfluenceSegment(riverArea1, 0.5, 0.0, 0.5, 0.5);
	rmSetAreaObeyWorldCircleConstraint(riverArea1, false);
	rmSetAreaReveal(riverArea1, 1);
    rmBuildArea(riverArea1); 

	int centralLake = rmCreateArea("centralLake");
	rmSetAreaSize(centralLake , rmAreaTilesToFraction(7900), rmAreaTilesToFraction(7900));
	if (PlayerNum >=3)
    	rmSetAreaSize(centralLake , rmAreaTilesToFraction(11600), rmAreaTilesToFraction(11600));
	if (PlayerNum >=5)
		rmSetAreaSize(centralLake , rmAreaTilesToFraction(16500), rmAreaTilesToFraction(16500));
	if (PlayerNum >=7)
		rmSetAreaSize(centralLake , rmAreaTilesToFraction(21000), rmAreaTilesToFraction(21000));
    rmSetAreaLocation(centralLake , 0.5, 0.7);	
	rmAddAreaInfluenceSegment(centralLake, 0.2, 0.9, 0.5, 0.7);
	rmAddAreaInfluenceSegment(centralLake, 0.5, 0.7, 0.8, 0.9);
	rmAddAreaInfluenceSegment(centralLake, 0.8, 0.9, 0.2, 0.9);
    rmSetAreaCoherence(centralLake , 0.8);
    rmSetAreaElevationVariation(centralLake, 0.0);
	rmAddAreaToClass(centralLake, classDeepWater);
	rmSetAreaReveal(centralLake, 1);
    rmBuildArea(centralLake);

	// Player islands

	int playerIslandSouthID = rmCreateArea("playerIslandSouth");
    rmSetAreaSize(playerIslandSouthID, 0.33, 0.33);
    rmSetAreaCoherence(playerIslandSouthID, 1.0);
    rmSetAreaMix(playerIslandSouthID, "danish_grass1");
		rmAddAreaTerrainLayer(playerIslandSouthID, "new_england\shoreline3_ne", 0, 1);
		rmAddAreaTerrainLayer(playerIslandSouthID, "new_england\shoreline2_ne", 1, 2);
    rmSetAreaBaseHeight(playerIslandSouthID, 3);
    rmSetAreaHeightBlend(playerIslandSouthID, 2);
    rmSetAreaSmoothDistance(playerIslandSouthID, 6);
    rmSetAreaObeyWorldCircleConstraint(playerIslandSouthID, false);
	rmAddAreaConstraint(playerIslandSouthID, greatLakesConstraint);
	rmAddAreaConstraint(playerIslandSouthID, avoidDeepWater);
	rmAddAreaConstraint(playerIslandSouthID, avoidTradeRouteFar3);
	rmAddAreaConstraint(playerIslandSouthID, avoidGroupingCenter);
	rmAddAreaConstraint(playerIslandSouthID, avoidBridge);
    rmSetAreaLocation(playerIslandSouthID, 0.2, 0.2);
    rmBuildArea(playerIslandSouthID);

	int playerIslandNorthID = rmCreateArea("playerIslandNorth");
	rmSetAreaSize(playerIslandNorthID, 0.33, 0.33);
	rmSetAreaCoherence(playerIslandNorthID, 1.0);
	rmSetAreaMix(playerIslandNorthID, "danish_grass1");
		rmAddAreaTerrainLayer(playerIslandNorthID, "new_england\shoreline3_ne", 0, 1);
		rmAddAreaTerrainLayer(playerIslandNorthID, "new_england\shoreline2_ne", 1, 2);
	rmSetAreaBaseHeight(playerIslandNorthID, 3);
	rmSetAreaHeightBlend(playerIslandNorthID, 2);
	rmSetAreaSmoothDistance(playerIslandNorthID, 6);
	rmSetAreaObeyWorldCircleConstraint(playerIslandNorthID, false);
	rmAddAreaConstraint(playerIslandNorthID, greatLakesConstraint);
	rmAddAreaConstraint(playerIslandNorthID, avoidDeepWater);
	rmAddAreaConstraint(playerIslandNorthID, avoidTradeRouteFar3);
	rmAddAreaConstraint(playerIslandNorthID, avoidGroupingCenter);
	rmAddAreaConstraint(playerIslandNorthID, avoidBridge);
	rmSetAreaLocation(playerIslandNorthID, 0.8, 0.2);
	rmBuildArea(playerIslandNorthID);

	// Cliffs to dock the bridge

	int bridgeDockNorth = rmCreateArea("bridgeDockNorth"); // Cliff to dock the Elbe bridge
    rmSetAreaSize(bridgeDockNorth, rmAreaTilesToFraction(300), rmAreaTilesToFraction(300));
    rmSetAreaLocation(bridgeDockNorth, 0.5+rmXTilesToFraction(22), 0.12);
    rmSetAreaCoherence(bridgeDockNorth, 1.0);	
    rmSetAreaBaseHeight(bridgeDockNorth, 3.5);
    rmSetAreaCliffType(bridgeDockNorth, "ZP Elbe Cliff");
    rmSetAreaCliffEdge(bridgeDockNorth, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(bridgeDockNorth, 0, 0.0, 1.0);
    rmAddAreaToClass(bridgeDockNorth , rmClassID("classPlateau"));
    rmSetAreaObeyWorldCircleConstraint(bridgeDockNorth, false);
	//rmSetAreaCliffPainting(bridgeDockNorth, false, true, true, 1.5, true);
    rmBuildArea(bridgeDockNorth); 

	int bridgeDockSouth = rmCreateArea("bridgeDockSouth"); // Cliff to dock the Elbe bridge
    rmSetAreaSize(bridgeDockSouth, rmAreaTilesToFraction(300), rmAreaTilesToFraction(300));
    rmSetAreaLocation(bridgeDockSouth,0.5-rmXTilesToFraction(22), 0.12);
    rmSetAreaCoherence(bridgeDockSouth, 1.0);	
    rmSetAreaBaseHeight(bridgeDockSouth, 3.5);
    rmSetAreaCliffType(bridgeDockSouth, "ZP Elbe Cliff");
    rmSetAreaCliffEdge(bridgeDockSouth, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(bridgeDockSouth, 0, 0.0, 1.0);
    rmAddAreaToClass(bridgeDockSouth , rmClassID("classPlateau"));
    rmSetAreaObeyWorldCircleConstraint(bridgeDockSouth, false);
	//rmSetAreaCliffPainting(bridgeDockSouth, false, true, true, 1.5, true);
    rmBuildArea(bridgeDockSouth); 

	// Cliffs to dock trade harbours

	int shoreLineNorth = rmCreateArea("shoreLineNorth"); // Cliff to dock the Elbe bridge
    rmSetAreaSize(shoreLineNorth, rmAreaTilesToFraction(1300), rmAreaTilesToFraction(1300));
    rmSetAreaLocation(shoreLineNorth, 0.5+rmXTilesToFraction(27), 0.4);
    rmSetAreaCoherence(shoreLineNorth, 1.0);	
    rmSetAreaBaseHeight(shoreLineNorth, 3.5);
    rmSetAreaCliffType(shoreLineNorth, "ZP Elbe Cliff");
    rmSetAreaCliffEdge(shoreLineNorth, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(shoreLineNorth, 0, 0.0, 1.0);
    rmAddAreaToClass(shoreLineNorth , rmClassID("classPlateau"));
    rmSetAreaObeyWorldCircleConstraint(shoreLineNorth, false);
	//rmSetAreaCliffPainting(shoreLineNorth, false, true, true, 1.5, true);
    rmBuildArea(shoreLineNorth); 

	int shoreLineSouth = rmCreateArea("shoreLineSouth"); // Cliff to dock the Elbe bridge
    rmSetAreaSize(shoreLineSouth, rmAreaTilesToFraction(1300), rmAreaTilesToFraction(1300));
    rmSetAreaLocation(shoreLineSouth,0.5-rmXTilesToFraction(27), 0.3);
    rmSetAreaCoherence(shoreLineSouth, 1.0);	
    rmSetAreaBaseHeight(shoreLineSouth, 3.5);
    rmSetAreaCliffType(shoreLineSouth, "ZP Elbe Cliff");
    rmSetAreaCliffEdge(shoreLineSouth, 1, 1.0, 0.1, 1.0, 0);
    rmSetAreaCliffHeight(shoreLineSouth, 0, 0.0, 1.0);
    rmAddAreaToClass(shoreLineSouth , rmClassID("classPlateau"));
    rmSetAreaObeyWorldCircleConstraint(shoreLineSouth, false);
	//rmSetAreaCliffPainting(shoreLineSouth, false, true, true, 1.5, true);
    rmBuildArea(shoreLineSouth); 

	// Patch to dock the hansa city states

	int patchSouth = rmCreateArea("patchSouth");
    rmSetAreaSize(patchSouth, rmAreaTilesToFraction(500), rmAreaTilesToFraction(500));
    rmSetAreaCoherence(patchSouth, 1.0);
    rmSetAreaMix(patchSouth, "danish_grass1");
    rmSetAreaBaseHeight(patchSouth, 3);
    rmSetAreaHeightBlend(patchSouth, 1);
    rmSetAreaSmoothDistance(patchSouth, 3);
    rmSetAreaObeyWorldCircleConstraint(patchSouth, false);
	rmAddAreaConstraint(patchSouth, avoidWall);
	rmAddAreaConstraint(patchSouth, avoidDeepWater);
	rmAddAreaConstraint(patchSouth, avoidTradeRouteFar3);
    rmSetAreaLocation(patchSouth,rmXMetersToFraction(xsVectorGetX(ControllerLoc1))-rmXTilesToFraction(23), rmZMetersToFraction(xsVectorGetZ(ControllerLoc1))-rmZTilesToFraction(10));
    rmBuildArea(patchSouth);

	int patchNorth = rmCreateArea("patchNorth");
    rmSetAreaSize(patchNorth, rmAreaTilesToFraction(500), rmAreaTilesToFraction(500));
    rmSetAreaCoherence(patchNorth, 1.0);
    rmSetAreaMix(patchNorth, "danish_grass1");
    rmSetAreaBaseHeight(patchNorth, 3);
    rmSetAreaHeightBlend(patchNorth, 1);
    rmSetAreaSmoothDistance(patchNorth, 3);
    rmSetAreaObeyWorldCircleConstraint(patchNorth, false);
	rmAddAreaConstraint(patchNorth, avoidWall);
	rmAddAreaConstraint(patchNorth, avoidDeepWater);
	rmAddAreaConstraint(patchNorth, avoidTradeRouteFar3);
    rmSetAreaLocation(patchNorth,rmXMetersToFraction(xsVectorGetX(ControllerLoc3))+rmXTilesToFraction(20), rmZMetersToFraction(xsVectorGetZ(ControllerLoc3))-rmZTilesToFraction(10));
    rmBuildArea(patchNorth);

	// Elevated terrain

	int playerHillsSouthID = rmCreateArea("playerHillsSouth");
	rmSetAreaMix(playerHillsSouthID, "danish_grass1");
    rmSetAreaSize(playerHillsSouthID, 0.23, 0.23);
    rmSetAreaCoherence(playerHillsSouthID, 1.0);
    rmSetAreaBaseHeight(playerHillsSouthID, 3);
    rmSetAreaHeightBlend(playerHillsSouthID, 2);
    rmSetAreaSmoothDistance(playerHillsSouthID, 6);
    rmSetAreaObeyWorldCircleConstraint(playerHillsSouthID, false);
	rmAddAreaConstraint(playerHillsSouthID, avoidWater5);
	rmAddAreaConstraint(playerHillsSouthID, avoidGroupingCenter);
	rmAddAreaConstraint(playerHillsSouthID, avoidBridge);
	rmSetAreaElevationVariation(playerHillsSouthID, 6.0);
	rmSetAreaElevationType(playerHillsSouthID, cElevTurbulence);
	rmSetAreaElevationMinFrequency(playerHillsSouthID, 0.09);
	rmSetAreaElevationOctaves(playerHillsSouthID, 3);
	rmSetAreaElevationPersistence(playerHillsSouthID, 0.2);
	rmSetAreaElevationNoiseBias(playerHillsSouthID, 1);
    rmSetAreaLocation(playerHillsSouthID, 0.2, 0.2);
    rmBuildArea(playerHillsSouthID);

	int playerHillsNorthID = rmCreateArea("playerHillsNorth");
	rmSetAreaMix(playerHillsNorthID, "danish_grass1");
    rmSetAreaSize(playerHillsNorthID, 0.23, 0.23);
    rmSetAreaCoherence(playerHillsNorthID, 1.0);
    rmSetAreaBaseHeight(playerHillsNorthID, 3);
    rmSetAreaHeightBlend(playerHillsNorthID, 2);
    rmSetAreaSmoothDistance(playerHillsNorthID, 6);
    rmSetAreaObeyWorldCircleConstraint(playerHillsNorthID, false);
	rmAddAreaConstraint(playerHillsNorthID, avoidWater5);
	rmAddAreaConstraint(playerHillsNorthID, avoidGroupingCenter);
	rmAddAreaConstraint(playerHillsNorthID, avoidBridge);
	rmSetAreaElevationVariation(playerHillsNorthID, 6.0);
	rmSetAreaElevationType(playerHillsNorthID, cElevTurbulence);
	rmSetAreaElevationMinFrequency(playerHillsNorthID, 0.09);
	rmSetAreaElevationOctaves(playerHillsNorthID, 3);
	rmSetAreaElevationPersistence(playerHillsNorthID, 0.2);
	rmSetAreaElevationNoiseBias(playerHillsNorthID, 1);
    rmSetAreaLocation(playerHillsNorthID, 0.8, 0.2);
    rmBuildArea(playerHillsNorthID);

	int pirateIslandID = rmCreateArea("pirateIsland");
	if (cNumberNonGaiaPlayers<=4)
		rmSetAreaSize(pirateIslandID, rmAreaTilesToFraction(1200), rmAreaTilesToFraction(1200));
	else
		rmSetAreaSize(pirateIslandID, rmAreaTilesToFraction(1600), rmAreaTilesToFraction(1600));
	rmSetAreaCoherence(pirateIslandID, 0.7);
	rmSetAreaMix(pirateIslandID, "danish_grass1");
		rmAddAreaTerrainLayer(pirateIslandID, "new_england\shoreline3_ne", 0, 1);
		rmAddAreaTerrainLayer(pirateIslandID, "new_england\shoreline2_ne", 1, 2);
	rmSetAreaBaseHeight(pirateIslandID, 3);
	rmSetAreaHeightBlend(pirateIslandID, 2);
	rmSetAreaSmoothDistance(pirateIslandID, 6);
	rmSetAreaObeyWorldCircleConstraint(pirateIslandID, false);
	rmAddAreaConstraint(pirateIslandID, avoidTradeRouteFar3);
	rmSetAreaElevationVariation(pirateIslandID, 6.0);
	rmSetAreaElevationType(pirateIslandID, cElevTurbulence);
	rmSetAreaElevationMinFrequency(pirateIslandID, 0.09);
	rmSetAreaElevationOctaves(pirateIslandID, 3);
	rmSetAreaElevationPersistence(pirateIslandID, 0.2);
	rmSetAreaElevationNoiseBias(pirateIslandID, 1);
	rmSetAreaLocation(pirateIslandID, 0.5, 0.95);
	rmBuildArea(pirateIslandID);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.30);

	// ********************** Additional Natives *****************************

	// Pirates

	int pirateControllerID = rmCreateObjectDef("pirate controller");
	rmAddObjectDefItem(pirateControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmPlaceObjectDefAtLoc(pirateControllerID, 0, 0.5, 0.95-rmZTilesToFraction(12));

	vector pirateControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(pirateControllerID, 0));

	int piratesVillageID = rmCreateGrouping("pirate city", "pirate_village07");      
	rmPlaceGroupingAtLoc(piratesVillageID, 0, rmXMetersToFraction(xsVectorGetX(pirateControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(pirateControllerLoc1)), 1);
	
	int piratewaterflagID1 = rmCreateObjectDef("pirate water flag 1");
	rmAddObjectDefItem(piratewaterflagID1, "zpPirateWaterSpawnFlag1", 1, 1.0);
	rmAddClosestPointConstraint(flagLand);

	vector closeToVillage1 = rmFindClosestPointVector(pirateControllerLoc1, rmXFractionToMeters(1.0));
	rmPlaceObjectDefAtLoc(piratewaterflagID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1)));

	rmClearClosestPointConstraints();

	int pirateportID1 = -1;
	pirateportID1 = rmCreateGrouping("pirate port 1", "pirateport03");
	rmAddClosestPointConstraint(portOnShore);

	vector closeToVillage1a = rmFindClosestPointVector(pirateControllerLoc1, rmXFractionToMeters(1.0));
	rmPlaceGroupingAtLoc(pirateportID1, 0, rmXMetersToFraction(xsVectorGetX(closeToVillage1a)), rmZMetersToFraction(xsVectorGetZ(closeToVillage1a)));

	rmClearClosestPointConstraints();

	// KotH

	if(rmGetIsKOTH()) {
		int kingHillID = rmCreateObjectDef("king hill");
		rmAddObjectDefItem(kingHillID, "ypKingsHill", 1, 0.0);
		rmAddObjectDefConstraint(kingHillID, avoidAll);
		rmAddObjectDefConstraint(kingHillID, playerEdgeConstraint);
		rmAddObjectDefConstraint(kingHillID, avoidWater10);
		rmPlaceObjectDefInArea(kingHillID, 0, pirateIslandID, 1);
	}

	// Electors

	int electorControllerID = rmCreateObjectDef("elector controller 1");
	rmAddObjectDefItem(electorControllerID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(electorControllerID, 0.0);
	rmSetObjectDefMaxDistance(electorControllerID, 0.5);

	int electorControllerID2 = rmCreateObjectDef("elector controller 2");
	rmAddObjectDefItem(electorControllerID2, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefMinDistance(electorControllerID2, 0.0);
	rmSetObjectDefMaxDistance(electorControllerID2, 0.5);

	rmPlaceObjectDefAtLoc(electorControllerID, 0, 0.25, 0.4);
	rmPlaceObjectDefAtLoc(electorControllerID2, 0, 0.75, 0.4);

	vector electorControllerLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(electorControllerID, 0));
	vector electorControllerLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(electorControllerID2, 0));

	int spawnerID1 = rmCreateObjectDef("spawner 1");
	rmAddObjectDefItem(spawnerID1, "zpSPCWaterSpawnPoint", 1, 0.0);

	int spawnerID2 = rmCreateObjectDef("spawner 2");
	rmAddObjectDefItem(spawnerID2, "zpSPCWaterSpawnPoint", 1, 0.0);

	int southIslandVillage1 = rmCreateArea ("south island village 1");
	rmSetAreaSize(southIslandVillage1, rmAreaTilesToFraction(650.0), rmAreaTilesToFraction(650.0));
	rmSetAreaLocation(southIslandVillage1, rmXMetersToFraction(xsVectorGetX(electorControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(electorControllerLoc1)));
	rmSetAreaCoherence(southIslandVillage1, 0.8);
	rmSetAreaSmoothDistance(southIslandVillage1, 5);
	rmSetAreaBaseHeight(southIslandVillage1, 5.0);
	rmSetAreaCliffType(southIslandVillage1, "ZP Elbe Cliff");
	rmSetAreaCliffEdge(southIslandVillage1, 2, 0.40, 0.0, 0.0, 2); 
	rmSetAreaCliffHeight(southIslandVillage1, 2.0, 0.0, 0.5); 
	rmSetAreaElevationVariation(southIslandVillage1, 0.0);
	rmSetAreaCliffPainting(southIslandVillage1, false, true, true, 1.5, true);
	rmBuildArea(southIslandVillage1);

	int northIslandVillage1 = rmCreateArea ("north island village 1");
	rmSetAreaSize(northIslandVillage1, rmAreaTilesToFraction(650.0), rmAreaTilesToFraction(650.0));
	rmSetAreaLocation(northIslandVillage1, rmXMetersToFraction(xsVectorGetX(electorControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(electorControllerLoc2)));
	rmSetAreaCoherence(northIslandVillage1, 0.8);
	rmSetAreaSmoothDistance(northIslandVillage1, 5);
	rmSetAreaBaseHeight(northIslandVillage1, 5.0);
	rmSetAreaCliffType(northIslandVillage1, "ZP Elbe Cliff");
	rmSetAreaCliffEdge(northIslandVillage1, 2, 0.40, 0.0, 0.0, 2); 
	rmSetAreaCliffHeight(northIslandVillage1, 2.0, 0.0, 0.5); 
	rmSetAreaElevationVariation(northIslandVillage1, 0.0);
	rmSetAreaCliffPainting(northIslandVillage1, false, true, true, 1.5, true);
	rmBuildArea(northIslandVillage1);

	int electorCastleID = rmCreateGrouping("elector castle 1", "Elector_Bohemia_02");
	rmPlaceGroupingAtLoc(electorCastleID, 0, rmXMetersToFraction(xsVectorGetX(electorControllerLoc1)), rmZMetersToFraction(xsVectorGetZ(electorControllerLoc1)), 1);
	rmPlaceObjectDefAtLoc(spawnerID1, 0, 0.25, 0.4);

	int electorCastleID2 = rmCreateGrouping("elector castle 2", "Elector_Saxony_02");
	rmPlaceGroupingAtLoc(electorCastleID2, 0, rmXMetersToFraction(xsVectorGetX(electorControllerLoc2)), rmZMetersToFraction(xsVectorGetZ(electorControllerLoc2)), 1);
	rmPlaceObjectDefAtLoc(spawnerID2, 0, 0.75, 0.4);

	// Hussite Camps
	
	int hussiteCampType1 = rmRandInt(1,5);
	int hussiteCampType2 = rmRandInt(1,5);

	int hussiteCampID = rmCreateGrouping("hussite camp", "Hussite_Camp_0"+hussiteCampType1);
	rmPlaceGroupingAtLoc(hussiteCampID, 0, 0.35, 0.15, 1);

	int hussiteCampID2 = rmCreateGrouping("hussite camp 2", "Hussite_Camp_0"+hussiteCampType2);
	rmPlaceGroupingAtLoc(hussiteCampID2, 0, 0.65, 0.15, 1);

	// Trade sockets

	int socketID5=rmCreateObjectDef("sockets to dock Trade Posts5");
	rmSetObjectDefTradeRouteID(socketID5, tradeRouteID);
	rmAddObjectDefItem(socketID5, "zpTradingPostCaptureNavalLone", 1, 0.0);
	rmSetObjectDefMinDistance(socketID5, 0.0);
  	rmSetObjectDefMaxDistance(socketID5, 0.5);

	int socketID6=rmCreateObjectDef("sockets to dock Trade Posts6");	rmSetObjectDefTradeRouteID(socketID6, tradeRouteID2);
	rmSetObjectDefTradeRouteID(socketID6, tradeRouteID);
	rmAddObjectDefItem(socketID6, "zpTradingPostCaptureNavalLone", 1, 0.0);
	rmSetObjectDefMinDistance(socketID6, 0.0);
  	rmSetObjectDefMaxDistance(socketID6, 0.5);

	int nuggetID5=rmCreateObjectDef("nuggets to dock Trade Posts5");
	rmSetObjectDefTradeRouteID(nuggetID5, tradeRouteID);
	rmAddObjectDefItem(nuggetID5, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetID5, 4.0);
  	rmSetObjectDefMaxDistance(nuggetID5, 6.0);

	int nuggetID6=rmCreateObjectDef("nuggets to dock Trade Posts6");	rmSetObjectDefTradeRouteID(nuggetID6, tradeRouteID2);
	rmSetObjectDefTradeRouteID(nuggetID6, tradeRouteID);
	rmAddObjectDefItem(nuggetID6, "Nugget", 1, 0.0);
	rmSetObjectDefMinDistance(nuggetID6, 4.0);
  	rmSetObjectDefMaxDistance(nuggetID6, 6.0);
	
	rmSetNuggetDifficulty(101, 101);

	rmPlaceObjectDefAtLoc(socketID5, 0, 0.5+rmXTilesToFraction(11), 0.4);
	rmPlaceObjectDefAtLoc(socketID6, 0, 0.5-rmXTilesToFraction(11), 0.3);
	rmPlaceObjectDefAtLoc(nuggetID5, 0, 0.5+rmXTilesToFraction(11), 0.4);
	rmPlaceObjectDefAtLoc(nuggetID6, 0, 0.5-rmXTilesToFraction(11), 0.3);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.40);

	// ************************* Place Players *****************************
	
	// Place Town Centers
	rmSetTeamSpacingModifier(0.6);

    float teamStartLoc = rmRandFloat(0.0, 1.0);
	if(cNumberTeams > 2)
	{
		rmSetPlacementSection(0.23, 0.77);
		rmSetTeamSpacingModifier(0.75);
		rmPlacePlayersCircular(0.38, 0.42, 0);
	}
	else
	{
		if (PlayerNum == 2) {
			if (teamStartLoc > 0.5) {
				rmPlacePlayer(1, 0.15, 0.45);
				rmPlacePlayer(2, 0.85, 0.45);
			}
			else {
				rmPlacePlayer(1, 0.85, 0.45);
				rmPlacePlayer(2, 0.15, 0.45);
			}	
		}
		else {
			// 4 players in 2 teams
			if (teamStartLoc > 0.5)
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.23, 0.40);
				rmPlacePlayersCircular(0.38, 0.42, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.60, 0.77);
				rmPlacePlayersCircular(0.38, 0.42, rmDegreesToRadians(5.0));
			}
			else
			{
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.60, 0.77);
				rmPlacePlayersCircular(0.38, 0.42, rmDegreesToRadians(5.0));
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.23, 0.40);
				rmPlacePlayersCircular(0.38, 0.42, rmDegreesToRadians(5.0));
			}
		}
	}

	// Insert Players
	int TCfloat = -1;
	if (cNumberTeams == 2)
		TCfloat = 20;
	else 
		TCfloat = 135;

	int startingUnits = rmCreateStartingUnitsObjectDef(5.0);

	int TCID = rmCreateObjectDef("player TC");
		if (rmGetNomadStart())
			{
				rmAddObjectDefItem(TCID, "CoveredWagon", 1, 0.0);
			}
		else{
			rmAddObjectDefItem(TCID, "TownCenter", 1, 0.0);
	}

	int colonyShipID = 0;

	rmSetObjectDefMinDistance(TCID, 0.0);
	rmSetObjectDefMaxDistance(TCID, TCfloat);

	//Player resources
	int playerMineID = rmCreateObjectDef("player mine");
	rmAddObjectDefItem(playerMineID, "mine", 1, 0);
	rmSetObjectDefMinDistance(playerMineID, 10.0);
	rmSetObjectDefMaxDistance(playerMineID, 30.0);
	rmAddObjectDefConstraint(playerMineID, avoidImpassableLand); 

	int playerDeerID=rmCreateObjectDef("player deer");
	rmAddObjectDefItem(playerDeerID, "deer", rmRandInt(10,15), 10.0);
	rmSetObjectDefMinDistance(playerDeerID, 15.0);
	rmSetObjectDefMaxDistance(playerDeerID, 30.0);
	rmAddObjectDefConstraint(playerDeerID, avoidImpassableLand);
	rmSetObjectDefCreateHerd(playerDeerID, true);

	int playerTreeID = rmCreateObjectDef("player trees");
	rmAddObjectDefItem(playerTreeID, "TreeNorthwestTerritory", 15, 8.0);
	rmSetObjectDefMinDistance(playerTreeID, 15);
	rmSetObjectDefMaxDistance(playerTreeID, 25);
	rmAddObjectDefToClass(playerTreeID, classStartingResource);
	rmAddObjectDefToClass(playerTreeID, rmClassID("classForest"));
	rmAddObjectDefConstraint(playerTreeID, avoidStartingResources);
	rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);

	rmAddObjectDefConstraint(TCID, avoidTownCenter);
	rmAddObjectDefConstraint(TCID, playerEdgeConstraint);
	rmAddObjectDefConstraint(TCID, avoidImpassableLand);
	rmAddObjectDefConstraint(TCID, avoidSocketLong);

	for(i=1; <cNumberPlayers) {

		// Place town centers
		rmPlaceObjectDefAtLoc(TCID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
		vector TCLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(TCID, i));

		// Water flag placement rules
		colonyShipID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(colonyShipID, "HomeCityWaterSpawnFlag", 1, 1.0);
		rmAddObjectDefItem(colonyShipID, "zpHanseaticTradeship", 1, 10.0);
		if ( rmGetNomadStart())
		{
			if(rmGetPlayerCiv(i) == rmGetCivID("Ottomans"))
				rmAddObjectDefItem(colonyShipID, "Galley", 1, 10.0);
			else
				rmAddObjectDefItem(colonyShipID, "caravel", 1, 10.0);
		}
		rmAddClosestPointConstraint(flagEdgeConstraint);
		rmAddClosestPointConstraint(flagVsFlag);
		rmAddClosestPointConstraint(flagLand);
		rmAddClosestPointConstraint(avoidBridgeLong);
		vector closestPoint = rmFindClosestPointVector(TCLoc, rmXFractionToMeters(1.0));

		// Place resources
		rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
		rmPlaceObjectDefAtLoc(startingUnits, i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerMineID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerDeerID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
		rmPlaceObjectDefAtLoc(playerTreeID, 0, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));

		if(ypIsAsian(i) && rmGetNomadStart() == false)
			rmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, rmXMetersToFraction(xsVectorGetX(TCLoc)), rmZMetersToFraction(xsVectorGetZ(TCLoc)));
	}

	rmClearClosestPointConstraints();

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.50);

	// ************************* Place resources *****************************

	// Random Gold
	int randomGoldID = rmCreateObjectDef("random mine");
	rmAddObjectDefItem(randomGoldID, "Mine", 1, 0.0);
	rmSetObjectDefMinDistance(randomGoldID, 0.0);
	rmSetObjectDefMaxDistance(randomGoldID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(randomGoldID, avoidCoin);
	rmAddObjectDefConstraint(randomGoldID, avoidAll);
	rmAddObjectDefConstraint(randomGoldID, avoidTownCenterFar);
	rmAddObjectDefConstraint(randomGoldID, avoidSocketLong);
	rmAddObjectDefConstraint(randomGoldID, avoidWater20);
	rmAddObjectDefConstraint(randomGoldID, playerEdgeConstraint);
	rmPlaceObjectDefInArea(randomGoldID, 0,  playerIslandSouthID, cNumberNonGaiaPlayers*1.5);
	rmPlaceObjectDefInArea(randomGoldID, 0,  playerIslandNorthID, cNumberNonGaiaPlayers*1.5);

	// Forests

	int failCount = -1;
	int numTries = -1;

	// Define and place forests - north and south
	int forestTreeID = 0;

	numTries=52;
	if (cNumberNonGaiaPlayers >= 5)
		numTries = 66;
	if (cNumberNonGaiaPlayers >= 7)
		numTries = 80;
	failCount=0;
	for (i=0; <numTries)
		{   
		int northForest=rmCreateArea("northforest"+i);
		rmSetAreaWarnFailure(northForest, false);
		rmSetAreaSize(northForest, rmAreaTilesToFraction(200), rmAreaTilesToFraction(300));

		rmSetAreaForestType(northForest, "z34 German Forest");
		rmSetAreaForestDensity(northForest, 1.0);
		rmAddAreaToClass(northForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(northForest, 0.0);		//DAL more forest with more clumps
		rmSetAreaForestUnderbrush(northForest, 0.0);
		rmSetAreaCoherence(northForest, 0.4);
		rmAddAreaConstraint(northForest, avoidImportantItem); // DAL added, to try and make sure natives got on the map w/o override.
		rmAddAreaConstraint(northForest, shortAvoidCoin);
		rmAddAreaConstraint(northForest, avoidTownCenterFar);
		rmAddAreaConstraint(northForest, avoidPlateauShort);
		rmAddAreaConstraint(northForest, avoidAll);
		rmAddAreaConstraint(northForest, avoidWater10);
		rmAddAreaConstraint(northForest, forestConstraint);   // DAL adeed, to keep forests away from each other.
		rmAddAreaConstraint(northForest, Northward);			// DAL adeed, to keep forests in the north.
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

	
	numTries=52;
	if (cNumberNonGaiaPlayers >= 5)
		numTries = 66;
	if (cNumberNonGaiaPlayers >= 7)
		numTries = 80;
	failCount=0;
	for (i = 0; i < numTries; i++)
	{   
		int southForest = rmCreateArea("southForest" + i);
		rmSetAreaWarnFailure(southForest, false);
		rmSetAreaSize(southForest, rmAreaTilesToFraction(200), rmAreaTilesToFraction(300));
		rmSetAreaForestType(southForest, "z34 German Forest");
		rmSetAreaForestDensity(southForest, 1.0);
		rmAddAreaToClass(southForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(southForest, 0.0);
		rmSetAreaForestUnderbrush(southForest, 0.0);
		rmSetAreaCoherence(southForest, 0.4);
		rmAddAreaConstraint(southForest, avoidImportantItem); // DAL added, to try and make sure natives got on the map w/o override.
		rmAddAreaConstraint(southForest, shortAvoidCoin);
		rmAddAreaConstraint(southForest, avoidTownCenterFar);
		rmAddAreaConstraint(southForest, avoidPlateauShort);
		rmAddAreaConstraint(southForest, avoidWater10);
		rmAddAreaConstraint(southForest, avoidAll);
		rmAddAreaConstraint(southForest, forestConstraint);
		rmAddAreaConstraint(southForest, Southward);
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

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.60);

	// Berries

	int berriesID = rmCreateObjectDef("berries"+i);
	rmAddObjectDefItem(berriesID, "berrybush", 3, 4.0);
	rmSetObjectDefMinDistance(berriesID, 0.0);
	rmSetObjectDefMaxDistance(berriesID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(berriesID, avoidCoin);
	rmAddObjectDefConstraint(berriesID, avoidAll);
	rmAddObjectDefConstraint(berriesID, avoidTradeRoute);
	rmAddObjectDefConstraint(berriesID, avoidSocket);
	rmAddObjectDefConstraint(berriesID, avoidWater20);
	rmAddObjectDefConstraint(berriesID, Southward);
	rmPlaceObjectDefAtLoc(berriesID, 0, 0.5, 0.5);

	int berriesID2 = rmCreateObjectDef("berries 2"+i);
	rmAddObjectDefItem(berriesID2, "berrybush", 3, 4.0);
	rmSetObjectDefMinDistance(berriesID2, 0.0);
	rmSetObjectDefMaxDistance(berriesID2, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(berriesID2, avoidCoin);
	rmAddObjectDefConstraint(berriesID2, avoidAll);
	rmAddObjectDefConstraint(berriesID2, avoidTradeRoute);
	rmAddObjectDefConstraint(berriesID2, avoidSocket);
	rmAddObjectDefConstraint(berriesID2, avoidWater20);
	rmAddObjectDefConstraint(berriesID2, Northward);
	rmPlaceObjectDefAtLoc(berriesID2, 0, 0.5, 0.5);

	// Place some extra deer herds.  
	int deerHerdID=rmCreateObjectDef("northern deer herd");
	rmAddObjectDefItem(deerHerdID, "deer", rmRandInt(4,7), 6.0);
	rmSetObjectDefCreateHerd(deerHerdID, true);
	rmSetObjectDefMinDistance(deerHerdID, rmXFractionToMeters(0.03));
	rmSetObjectDefMaxDistance(deerHerdID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(deerHerdID, shortAvoidCoin);
	rmAddObjectDefConstraint(deerHerdID, avoidTradeSockets);
	rmAddObjectDefConstraint(deerHerdID, avoidTownCenterFar);
	rmAddObjectDefConstraint(deerHerdID, avoidWater20);
	rmAddObjectDefConstraint(deerHerdID, avoidAll);
	rmAddObjectDefConstraint(deerHerdID, avoidImpassableLand);
	rmAddObjectDefConstraint(deerHerdID, deerConstraint);
	rmAddObjectDefConstraint(deerHerdID, Northward);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(deerHerdID, 0, 0.5, 0.5);
	}

	int deerHerdID2=rmCreateObjectDef("southern deer herd");
	rmAddObjectDefItem(deerHerdID2, "deer", rmRandInt(4,7), 6.0);
	rmSetObjectDefCreateHerd(deerHerdID2, true);
	rmSetObjectDefMinDistance(deerHerdID2, rmXFractionToMeters(0.03));
	rmSetObjectDefMaxDistance(deerHerdID2, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(deerHerdID2, shortAvoidCoin);
	rmAddObjectDefConstraint(deerHerdID2, avoidTownCenterFar);
	rmAddObjectDefConstraint(deerHerdID2, avoidTradeSockets);
	rmAddObjectDefConstraint(deerHerdID2, avoidWater20);
	rmAddObjectDefConstraint(deerHerdID2, avoidAll);
	rmAddObjectDefConstraint(deerHerdID2, avoidImpassableLand);
	rmAddObjectDefConstraint(deerHerdID2, deerConstraint);
	rmAddObjectDefConstraint(deerHerdID2, Southward);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(deerHerdID2, 0, 0.5, 0.5);
	}

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.70);

	// **************** Nuggets *******************

	int nugget1= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 2);
	rmAddObjectDefToClass(nugget1, rmClassID("nuggets"));
	rmAddObjectDefConstraint(nugget1, shortPlayerConstraint);
	rmAddObjectDefConstraint(nugget1, avoidTownCenter);
	rmAddObjectDefConstraint(nugget1, avoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNuggets);
	rmAddObjectDefConstraint(nugget1, avoidTradeSockets);
	rmAddObjectDefConstraint(nugget1, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget1, avoidAll);
	rmAddObjectDefConstraint(nugget1, circleConstraint);
	rmPlaceObjectDefInArea(nugget1, 0,  playerIslandSouthID, cNumberNonGaiaPlayers*1.5);
	rmPlaceObjectDefInArea(nugget1, 0,  playerIslandNorthID, cNumberNonGaiaPlayers*1.5);

	int nugget2= rmCreateObjectDef("nugget medium"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 4);
	rmAddObjectDefToClass(nugget2, rmClassID("nuggets"));
	rmAddObjectDefConstraint(nugget2, shortPlayerConstraint);
	rmAddObjectDefConstraint(nugget2, avoidImpassableLand);
	rmAddObjectDefConstraint(nugget2, avoidNuggets);
	rmAddObjectDefConstraint(nugget2, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget2, avoidTownCenterFar);
	rmAddObjectDefConstraint(nugget2, circleConstraint);
	rmAddObjectDefConstraint(nugget2, avoidAll);
	rmAddObjectDefConstraint(nugget2,avoidWater20);
	rmPlaceObjectDefInArea(nugget2, 0,  playerIslandSouthID, cNumberNonGaiaPlayers/2);
	rmPlaceObjectDefInArea(nugget2, 0,  playerIslandNorthID, cNumberNonGaiaPlayers/2);
	rmPlaceObjectDefInArea(nugget2, 0,  pirateIslandID, 2);

	// Fishes

    int fishID=rmCreateObjectDef("fish 1");
	rmAddObjectDefItem(fishID, fish1, 1, 0.0);
	rmSetObjectDefMinDistance(fishID, 0.0);
	if (rmGetIsKOTH() == true)
		rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.4));
	else
		rmSetObjectDefMaxDistance(fishID, rmXFractionToMeters(0.45));
	rmAddObjectDefConstraint(fishID, avoidFish1);
	rmAddObjectDefConstraint(fishID, fishLand);
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 50+10*cNumberNonGaiaPlayers);

	int whaleID=rmCreateObjectDef("whale");
	rmAddObjectDefItem(whaleID, "MinkeWhale", 1, 0.0);
	rmSetObjectDefMinDistance(whaleID, 0.0);
	rmSetObjectDefMaxDistance(whaleID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(whaleID, whaleVsWhaleID);
	rmAddObjectDefConstraint(whaleID, whaleLand);
	rmAddObjectDefConstraint(whaleID, avoidGroupingCenterWhale);
	rmPlaceObjectDefAtLoc(whaleID, 0, 0.5, 0.5, 4*cNumberNonGaiaPlayers);

	// VILLAGE TREES
	int villageTreeID=rmCreateObjectDef("village tree");
	rmAddObjectDefItem(villageTreeID, "TreeNorthwestTerritory", 1, 0.0);
	rmAddObjectDefConstraint(villageTreeID, avoidAll);
	rmPlaceObjectDefInArea(villageTreeID, 0,  southIslandVillage1, 9);
	rmPlaceObjectDefInArea(villageTreeID, 0,  northIslandVillage1, 9);

   	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.80);

	// ____________________ LOCAL MERCENARIES ____________________
    rmDisableDefaultMercs(true);
    rmDisableCivTypeMercRestriction(true);
	rmEnableMerc("MercJaeger", -1);
	rmEnableMerc("deMercPandour", -1);
	rmEnableMerc("deMercGrenadier", -1);
    rmEnableMerc("zpMercTeutonicCavalry", -1);
    rmEnableMerc("MercGreatCannon", -1);

	// ------Triggers--------//

	// Unit IDxs

	int loneHarbourID1 = rmGetUnitPlaced(socketID5, 0)+1;
	int loneHarbourID2 = rmGetUnitPlaced(socketID6, 0)+1;

	int loneHarbourNuggetID1 = rmGetUnitPlaced(nuggetID5, 0)+1;
	int loneHarbourNuggetID2 = rmGetUnitPlaced(nuggetID6, 0)+1;

	int hansaFlag1 = rmGetGroupingInstanceUnitByType(hansaInstanceID1, "zpHansaWaterSpawnFlag1")+1;
	int hansaFlag2 = rmGetGroupingInstanceUnitByType(hansaInstanceID2, "zpHansaWaterSpawnFlag2")+1;

	int hansaSocket1 = rmGetGroupingInstanceUnitByType(hansaInstanceID1, "zpSPCSocketHansaKontorCitystate")+1;
	int hansaSocket2 = rmGetGroupingInstanceUnitByType(hansaInstanceID2, "zpSPCSocketHansaKontorCitystate")+1;

    int hansaCenter1 = rmGetGroupingInstanceUnitByType(hansaInstanceID1, "zpCinematicRevealer")+1;
	int hansaCenter2 = rmGetGroupingInstanceUnitByType(hansaInstanceID2, "zpCinematicRevealer")+1;

	int hansaChurch1 = rmGetGroupingInstanceUnitByType(hansaInstanceID1, "zpHanseaticChurch")+1;
	int hansaChurch2 = rmGetGroupingInstanceUnitByType(hansaInstanceID2, "zpHanseaticChurch")+1;

	int hansaTower11 = rmGetGroupingInstanceUnitByType(hansaInstanceID1, "deSPCSocketCityTower")+1;
	int hansaTower12 = rmGetGroupingInstanceUnitByType(hansaInstanceID1, "zpSPCSocketCityTowerClone")+1;
	int hansaTower21 = rmGetGroupingInstanceUnitByType(hansaInstanceID2, "deSPCSocketCityTower")+1;
	int hansaTower22 = rmGetGroupingInstanceUnitByType(hansaInstanceID2, "zpSPCSocketCityTowerClone")+1;

	int electorSocket1 = rmGetUnitPlaced(spawnerID1, 0);
	int electorSocket2 = rmGetUnitPlaced(spawnerID2, 0);

	int flag1 = rmGetUnitPlaced(piratewaterflagID1, 0);

	string pirate1ID = ""+(flag1-1);

	// Arrays

	// Castle Socket Array
	int castleSockets = xsArrayCreateInt(2, -1, "Castle Sockets");
	xsArraySetInt(castleSockets, 0, electorSocket1);
	xsArraySetInt(castleSockets, 1, electorSocket2);

	int castleSocketID = -1;

	// Hansa Socket Array
	int hansaSockets = xsArrayCreateInt(2, -1, "Hansa Sockets");
	xsArraySetInt(hansaSockets, 0, hansaSocket1);
	xsArraySetInt(hansaSockets, 1, hansaSocket2);

	int hansaSocketID = -1;

	// Hansa Flags Array
	int hansaFlags = xsArrayCreateInt(2, -1, "Hansa Flags");
	xsArraySetInt(hansaFlags, 0, hansaFlag1);
	xsArraySetInt(hansaFlags, 1, hansaFlag2);

	int hansaFlagID = -1;

	// Hansa Center Array
	int hansaCenters = xsArrayCreateInt(2, -1, "Hansa Centers");
	xsArraySetInt(hansaCenters, 0, hansaCenter1);
	xsArraySetInt(hansaCenters, 1, hansaCenter2);

	int hansaCenterID = -1;

	// Hansa Churches Array
	int hansaChurches = xsArrayCreateInt(2, -1, "Hansa Churches");
	xsArraySetInt(hansaChurches, 0, hansaChurch1);
	xsArraySetInt(hansaChurches, 1, hansaChurch2);

	int hansaChurchID = -1;

	// Strings

	string guardianUnit = "zpNatLandsknecht";

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>	
	rmSetStatusText("",0.90);

	rmCreateTrigger("Starting Techs");
	rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpElbeSetup"); // All in One
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",1);
		rmSetTriggerEffectParamInt("Level",1);
		rmAddTriggerEffect("Trade Route Set Level");
		rmSetTriggerEffectParamInt("TradeRoute",2);
		rmSetTriggerEffectParamInt("Level",1);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Conversion Suspend
	rmCreateTrigger("Buildings Convert OFF");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+loneHarbourID1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+loneHarbourID2);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+hansaSocket1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+hansaSocket2);
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
	rmSetTriggerConditionParam("UnitType",guardianUnit);
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

    rmCreateTrigger("Socket 2 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+hansaSocket2);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+hansaSocket2, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+hansaSocket2, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

    rmCreateTrigger("Harbour 1 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
    rmSetTriggerConditionParam("NuggetObject", ""+loneHarbourNuggetID1);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+loneHarbourID1, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

    rmCreateTrigger("Harbourt 2 Convert ON");
	rmAddTriggerCondition("Nugget Is Collectable");
    rmSetTriggerConditionParam("NuggetObject", ""+loneHarbourNuggetID2);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+loneHarbourID2, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

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
		rmCreateTrigger("Activate Tortuga"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpTheBlackFlag"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPiratesMedi"); //operator
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
		rmCreateTrigger("Activate Electors"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpPrinceElectorElect"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffPrinceElector"); //operator
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
		rmCreateTrigger("Activate Hussites"+k);
		rmAddTriggerCondition("ZP Tech Researching (XS)");
		rmSetTriggerConditionParam("TechID","cTechzpHussiteExpansion"); //operator
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffHussites"); //operator
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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Hansa"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Electors"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Hussites"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Tortuga"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

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

	// Prince Elector Increments
	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Elector Increase2"+k);
		rmCreateTrigger("Elector Decrease1"+k);

		rmSwitchToTrigger(rmTriggerID("Elector Increase2"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpElectorSiteIncrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Decrease1"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Elector Decrease1"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("ProtoUnit","zpElectorCenter");
		rmSetTriggerConditionParam("Op","<=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpElectorSiteDecrease"); //operator
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector_Increase2"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// ****************** Elector Convert ******************
	for (s=1; <= 2) {
		for (k=1; <= cNumberNonGaiaPlayers) {
			rmCreateTrigger("Elector"+s+"on Player"+k);
			rmCreateTrigger("Elector"+s+"off Player"+k);

			castleSocketID = xsArrayGetInt(castleSockets, s-1);
			rmSwitchToTrigger(rmTriggerID("Elector"+s+"on Player"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+castleSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+castleSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpElectorCenter");
			rmSetTriggerEffectParamInt("Dist",35);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector"+s+"off_Player"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("Elector"+s+"off Player"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+castleSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op","==");
			rmSetTriggerConditionParamInt("Count",0);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+castleSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpElectorCenter");
			rmSetTriggerEffectParamInt("Dist",35);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Elector"+s+"on_Player"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);
		}

	}

	// Pirate Ship Training

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("TrainPrivateer1ON Plr"+k);
		rmCreateTrigger("TrainPrivateer1OFF Plr"+k);
		rmCreateTrigger("TrainPrivateer1TIME Plr"+k);

		rmCreateTrigger("UniqueShip1TIMEPlr"+k);
		rmCreateTrigger("BlackbTrain1ONPlr"+k);
		rmCreateTrigger("BlackbTrain1OFFPlr"+k);
		rmCreateTrigger("GraceTrain1ONPlr"+k);
		rmCreateTrigger("GraceTrain1OFFPlr"+k);
		rmCreateTrigger("CaesarTrain1ONPlr"+k);
		rmCreateTrigger("CaesarTrain1OFFPlr"+k);

		rmSwitchToTrigger(rmTriggerID("TrainPrivateer1ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate1ID);
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
		rmSetTriggerConditionParamInt("Param1",1200);
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

		rmSwitchToTrigger(rmTriggerID("BlackbTrain1ONPlr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate1ID);
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
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BlackbTrain1ONPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("GraceTrain1ONPlr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate1ID);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCPirateGalleassProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainSultana1"); //operator
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
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("GraceTrain1ONPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("CaesarTrain1ONPlr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate1ID);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCNeptuneGalleyProxy");
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpTrainNeptune1"); //operator
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
		rmSetTriggerConditionParamInt("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("CaesarTrain1ONPlr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Pirates1on Player"+k);
		rmCreateTrigger("Pirates1off Player"+k);

		rmSwitchToTrigger(rmTriggerID("Pirates1on_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate1ID);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamFloat("Count",1);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",pirate1ID);
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
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",pirate1ID);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParamInt("Dist",35);
		rmSetTriggerConditionParam("UnitType","TradingPost");
		rmSetTriggerConditionParam("Op","==");
		rmSetTriggerConditionParamFloat("Count",0);
		rmAddTriggerEffect("Convert Units in Area");
		rmSetTriggerEffectParam("SrcObject",pirate1ID);
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
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Hansa Ship training
	for (s=1; <= 2) {
		for (k=1; <= cNumberNonGaiaPlayers) {
			rmCreateTrigger("TrainCog"+s+"ON Plr"+k);
			rmCreateTrigger("TrainCog"+s+"OFF Plr"+k);
			rmCreateTrigger("TrainCog"+s+"TIME Plr"+k);

			rmCreateTrigger("TrainFluyt"+s+"ON Plr"+k);
			rmCreateTrigger("TrainFluyt"+s+"OFF Plr"+k);
			rmCreateTrigger("TrainFluyt"+s+"TIME Plr"+k);

			hansaSocketID = xsArrayGetInt(hansaSockets, s-1);
			rmSwitchToTrigger(rmTriggerID("TrainCog"+s+"ON_Plr"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+hansaSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","zpHanseaticWarshipProxy");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			if (s==1) {
				rmSetTriggerEffectParam("TechID","cTechzpTrainHansaCog1"); //operator
			}
			else {
				rmSetTriggerEffectParam("TechID","cTechzpTrainHansaCog2"); //operator
			}
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainCog"+s+"OFF_Plr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainCog"+s+"TIME_Plr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("TrainCog"+s+"OFF_Plr"+k));
			rmAddTriggerCondition("Timer ms");
			rmSetTriggerConditionParamInt("Param1",1200);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainCog"+s+"ON_Plr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("TrainCog"+s+"TIME_Plr"+k));
			rmAddTriggerCondition("Timer ms");
			rmSetTriggerConditionParamFloat("Param1",200);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpReduceHansaCogBuildLimit"); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			if (s==1) {
				rmSetTriggerEffectParam("TechID","cTechzpTrainHansaCog1"); //operator
			}
			else {
				rmSetTriggerEffectParam("TechID","cTechzpTrainHansaCog2"); //operator
			}
			rmSetTriggerEffectParamInt("Status",0);
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("TrainFluyt"+s+"ON_Plr"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+hansaSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","zpHanseaticFluytProxy");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			if (s==1) {
				rmSetTriggerEffectParam("TechID","cTechzpTrainHansaFluyt1"); //operator
			}
			else {
				rmSetTriggerEffectParam("TechID","cTechzpTrainHansaFluyt2"); //operator
			}
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainFluyt"+s+"OFF_Plr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainFluyt"+s+"TIME_Plr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("TrainFluyt"+s+"OFF_Plr"+k));
			rmAddTriggerCondition("Timer ms");
			rmSetTriggerConditionParamInt("Param1",1200);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainFluyt"+s+"ON_Plr"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("TrainFluyt"+s+"TIME_Plr"+k));
			rmAddTriggerCondition("Timer ms");
			rmSetTriggerConditionParamFloat("Param1",200);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpReduceHansaFluytBuildLimit"); //operator
			rmSetTriggerEffectParamInt("Status",2);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			if (s==1) {
				rmSetTriggerEffectParam("TechID","cTechzpTrainHansaFluyt1"); //operator
			}
			else {
				rmSetTriggerEffectParam("TechID","cTechzpTrainHansaFluyt2"); //operator
			}
			rmSetTriggerEffectParamInt("Status",0);
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);
		}
	}

	// Specific for AI

	// AI Builds Pirate City States from Sockets
	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("BuildTower11_ON_Plr"+k);
		rmCreateTrigger("BuildTower11_OFF_Plr"+k);
		rmCreateTrigger("BuildTower12_ON_Plr"+k);
		rmCreateTrigger("BuildTower12_OFF_Plr"+k);
		rmCreateTrigger("BuildTower21_ON_Plr"+k);
		rmCreateTrigger("BuildTower21_OFF_Plr"+k);
		rmCreateTrigger("BuildTower22_ON_Plr"+k);
		rmCreateTrigger("BuildTower22_OFF_Plr"+k);

		rmSwitchToTrigger(rmTriggerID("BuildTower11_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+hansaTower11);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+hansaTower11);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower11_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower11_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower11_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower12_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+hansaTower12);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+hansaTower12);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower12_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower12_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower12_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower21_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+hansaTower21);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+hansaTower21);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower21_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower21_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower21_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower22_ON_Plr"+k));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject",""+hansaTower22);
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
		rmSetTriggerConditionParamInt("Dist",10);
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Socket Build");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("Socket",""+hansaTower22);
		rmSetTriggerEffectParam("Protounit","deSPCCityTower");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower22_OFF_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("BuildTower22_OFF_Plr"+k));
		rmAddTriggerCondition("Timer ms");
		rmSetTriggerConditionParamFloat("Param1",1200);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower22_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmCreateTrigger("AI_Check1_Plr"+k);
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower11_ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower12_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmCreateTrigger("AI_Check2_Plr"+k);
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower21_ON_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower22_ON_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Convert Hansa Settlements
	for (s=1; <= 2) {
		for (k=1; <= cNumberNonGaiaPlayers) {
			rmCreateTrigger("Hansa"+s+"ON Plr"+k);
			rmCreateTrigger("Hansa"+s+"OFF Plr"+k);

			hansaSocketID = xsArrayGetInt(hansaSockets, s-1);
			hansaCenterID = xsArrayGetInt(hansaCenters, s-1);
			hansaChurchID = xsArrayGetInt(hansaChurches, s-1);
			hansaFlagID = xsArrayGetInt(hansaFlags, s-1);
			rmSwitchToTrigger(rmTriggerID("Hansa"+s+"ON_Plr"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+hansaSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+hansaChurchID);
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+hansaFlagID);
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","deSPCSocketCityTower");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","deSPCCityTower");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","deSPCCityStateWall5Prop");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","deSPCCityStateWall2Prop");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","deSPCCityStateWall3Prop");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","deSPCCityStateWall4Prop");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","deSPCCityStateWallConnectorProp");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Hansa"+s+"OFF_Plr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainCog"+s+"ON_Plr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainFluyt"+s+"ON_Plr"+k));
			if (s == 1){
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("AI_Check1_Plr"+k));
			}
			else{
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("AI_Check2_Plr"+k));
			}
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("Hansa"+s+"OFF_Plr"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+hansaSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParamInt("Dist",35);
			rmSetTriggerConditionParam("Op","==");
			rmSetTriggerConditionParamInt("Count",0);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("PlayerID",0);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+hansaChurchID);
			rmSetTriggerEffectParamInt("PlayerID",0);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+hansaFlagID);
			rmSetTriggerEffectParamInt("PlayerID",0);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","deSPCSocketCityTower");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerClone");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","deSPCCityTower");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","deSPCCityStateWall5Prop");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","deSPCCityStateWall2Prop");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","deSPCCityStateWall3Prop");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","deSPCCityStateWall4Prop");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","deSPCCityStateWallConnectorProp");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+hansaCenterID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
			rmSetTriggerEffectParamInt("Dist",50);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Hansa"+s+"ON_Plr"+k));
			rmAddTriggerEffect("Disable Trigger");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainCog"+s+"ON_Plr"+k));
			rmAddTriggerEffect("Disable Trigger");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("TrainFluyt"+s+"ON_Plr"+k));
			if (s == 1){
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower11_ON_Plr"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower12_ON_Plr"+k));
			}
			else{
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower21_ON_Plr"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower22_ON_Plr"+k));
			}
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);
		}
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

	// AI Hussite Leaders

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Hussite Leader"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int hussiteLeader=-1;
	hussiteLeader = rmRandInt(1,3);

	if (hussiteLeader==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateHussitesZizka"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (hussiteLeader==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateHussitesKing"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (hussiteLeader==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateHussitesReformer"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// AI Elector Leaders

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Elector Leader"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int electorLeader=-1;
	electorLeader = rmRandInt(1,5);

	if (electorLeader==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorHabsburg"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (electorLeader==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorWittelsbach"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (electorLeader==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorWettin"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (electorLeader==4)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorHanover"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (electorLeader==5)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateElectorOldenburg"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
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
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}*/



	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>	
	rmSetStatusText("",0.99);	

} // END