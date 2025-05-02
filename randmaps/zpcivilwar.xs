// CIVIL WAR
// April 2025

int TeamNum = cNumberTeams;
int PlayerNum = cNumberNonGaiaPlayers;
int numPlayer = cNumberPlayers;
int evenOdd = -1;


include "mercenaries.xs";
include "ypAsianInclude.xs";
include "ypKOTHInclude.xs";

 string fish1 = "ypFishCarp";

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

	if (rmAllocateSubCivs(3) == true)
	{
		subCiv0=rmGetCivID("zpscientists");
		rmEchoInfo("subCiv0 is mzpscientists "+subCiv0);
		if (subCiv0 >= 0)
			rmSetSubCiv(0, "zpscientists");

		subCiv1=rmGetCivID("zpwesternvillage");
		rmEchoInfo("subCiv1 is zpwesternvillage "+subCiv1);
		if (subCiv1 >= 0)
			rmSetSubCiv(1, "zpwesternvillage");
  
		subCiv2=rmGetCivID("cherokee");
		rmEchoInfo("subCiv2 is cherokee "+subCiv2);
		if (subCiv2 >= 0)
			rmSetSubCiv(2, "cherokee");
	}


    int size = 500;
	if (PlayerNum >=5)
		size = 600;
	if (PlayerNum >=7)
		size = 660;
	rmSetMapSize(size, size);
	// rmSetMapElevationParameters(cElevTurbulence, 0.4, 6, 0.5, 3.0);  // DAL - original
	
	rmSetMapElevationHeightBlend(1);
	
	// Picks a default water height
	rmSetSeaLevel(0.0);
   
   	// LIGHT SET

	rmSetLightingSet("honshu_Skirmish");


	// Picks default terrain and water
	rmSetMapElevationParameters(cElevTurbulence, 0.03, 5, 0.7, 4.0);
	//rmSetMapElevationParameters(cElevTurbulence, 0.05, 6, 0.7, 6.0);
	rmSetSeaType("great lakes2");
	rmEnableLocalWater(false);
	rmSetBaseTerrainMix("nwt_grass2");
	rmTerrainInitialize("deccan\ground_grass3_deccan", 1.0);
	rmSetMapType("bayou");
	rmSetMapType("grass");
	rmSetMapType("water");
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
	rmDefineClass("classPlateau");
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
	
    int avoidWater10 = rmCreateTerrainDistanceConstraint("avoid water short", "Land", false, 2.0);
	int avoidWater20 = rmCreateTerrainDistanceConstraint("avoid water medium", "Land", false, 10.0);
	int avoidWater30 = rmCreateTerrainDistanceConstraint("avoid water long", "Land", false, 15.0);
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
    int flagEdgeConstraint = rmCreatePieConstraint("flags away from edge of map", 0.5, 0.5, rmGetMapXSize()-200, rmGetMapXSize()-100, 0, 0, 0);  

	// Nature avoidance
	// int fishVsFishID=rmCreateTypeDistanceConstraint("fish v fish", "fish", 18.0);
	
	int forestObjConstraint=rmCreateTypeDistanceConstraint("forest obj", "all", 6.0);
	int forestConstraint=rmCreateClassDistanceConstraint("forest vs. forest", rmClassID("classForest"), 19.0);
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
	int avoidTradeSockets = rmCreateTypeDistanceConstraint("avoid trade sockets", "sockettraderoute", 8.0);
	int farAvoidTradeSockets = rmCreateTypeDistanceConstraint("far avoid trade sockets", "sockettraderoute", 12.0);
	int fishLand = rmCreateTerrainDistanceConstraint("fish land", "land", true, 6.0);
    int avoidFish1=rmCreateTypeDistanceConstraint("fish v fish", fish1, 15.0);	
	int HCspawnLand = rmCreateTerrainDistanceConstraint("HC spawn away from land", "land", true, 12.0);
	int avoidTrainStationA = rmCreateTypeDistanceConstraint("avoid trainstation a", "spSocketTrainStationA", 8.0);
	int avoidTrainStationB = rmCreateTypeDistanceConstraint("avoid trainstation b", "spSocketTrainStationB", 8.0);
    int avoidHarbour = rmCreateTypeDistanceConstraint("avoid harbour", "zpSPCPortSocket", 20.0);
	int avoidBridge = rmCreateTypeDistanceConstraint("avoid bridge", "zpRuinWallSmall", 10.0);

	// Lake Constraints
	int greatLakesConstraint=rmCreateClassDistanceConstraint("avoid the great lakes", classGreatLake, 0.1);
	int farGreatLakesConstraint=rmCreateClassDistanceConstraint("far avoid the great lakes", classGreatLake, 20.0);
	int portOnShore = rmCreateTerrainDistanceConstraint("port vs land", "land", true, 3.5);
	int avoidDeepWater=rmCreateClassDistanceConstraint("stuff avoids deep water", classDeepWater, 1.0);
	int avoidSocket=rmCreateTypeDistanceConstraint("avoid socket", "SocketTradeRoute", 10.0);
   	int avoidSocketLong=rmCreateTypeDistanceConstraint("avoid socket long", "Socket", 50.0);
    int flagVsFlag = rmCreateTypeDistanceConstraint("flag avoid same", "HomeCityWaterSpawnFlag", 30);
	int flagVsVenice1 = rmCreateTypeDistanceConstraint("flag avoid venice 1", "zpNativeWaterSpawnFlag1", 40.0);
  	int flagVsVenice2 = rmCreateTypeDistanceConstraint("flag avoid venice 2", "zpNativeWaterSpawnFlag2", 40.0);
	int saltVsSalt = rmCreateTypeDistanceConstraint("salt avoid same", "zpSaltMineWater", 30);
    int ferryOnShore=rmCreateTerrainMaxDistanceConstraint("ferry v. water", "water", true, 5.0);


	// Native Constraints
	int avoidcherokee=rmCreateTypeDistanceConstraint("stay away from cherokee", "SocketCherokee", 70.0);
	int avoidscientists=rmCreateTypeDistanceConstraint("stay away from scientists", "zpSocketScientists", 45.0);
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

	int avoidPlateauShort = rmCreateClassDistanceConstraint("avoid patch 1", rmClassID("classPlateau"), 1.0);
	int avoidPlateau = rmCreateClassDistanceConstraint("avoid patch 2", rmClassID("classPlateau"), 7.0);
	int avoidPathBlock = rmCreateTypeDistanceConstraint("avoid path block", "SPCPathBlock3", 7.0);

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.10);


   	float playerFraction=rmAreaTilesToFraction(850);


	// ********************* Trade Route *******************************

    // Trade route must be always placed as first
	int stopperID=rmCreateObjectDef("Armored Train Stopper");
	rmAddObjectDefItem(stopperID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperID, true);
	rmSetObjectDefMinDistance(stopperID, 0.0);
	rmSetObjectDefMaxDistance(stopperID, 0.0);  

	int stopper2ID=rmCreateObjectDef("Armored Train Stopper2");
	rmAddObjectDefItem(stopper2ID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopper2ID, true);
	rmSetObjectDefMinDistance(stopper2ID, 0.0);
	rmSetObjectDefMaxDistance(stopper2ID, 0.0);

	int stopper3ID=rmCreateObjectDef("Armored Train Stopper3");
	rmAddObjectDefItem(stopper3ID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopper3ID, true);
	rmSetObjectDefMinDistance(stopper3ID, 0.0);
	rmSetObjectDefMaxDistance(stopper3ID, 0.0);

	int stopperBridge1ID=rmCreateObjectDef("Armored Train Bridge1");
	rmAddObjectDefItem(stopperBridge1ID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperBridge1ID, true);
	rmSetObjectDefMinDistance(stopperBridge1ID, 0.0);
	rmSetObjectDefMaxDistance(stopperBridge1ID, 0.0);

	int stopperBridge2ID=rmCreateObjectDef("Armored Train Bridge2");
	rmAddObjectDefItem(stopperBridge2ID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperBridge2ID, true);
	rmSetObjectDefMinDistance(stopperBridge2ID, 0.0);
	rmSetObjectDefMaxDistance(stopperBridge2ID, 0.0);

    int tradeRouteID = rmCreateTradeRoute();
    rmSetObjectDefTradeRouteID(stopperID, tradeRouteID);
   
	rmAddTradeRouteWaypoint(tradeRouteID, 0.0, 0.75);
   	rmAddTradeRouteWaypoint(tradeRouteID, 0.27, 0.75);
	if (PlayerNum >=7)
		rmAddTradeRouteWaypoint(tradeRouteID, 0.42, 0.88);
	else
		rmAddTradeRouteWaypoint(tradeRouteID, 0.4, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.6, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID, 0.73, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID, 1.0, 0.75);
    rmBuildTradeRoute(tradeRouteID, "train");

	int tradeRouteID2 = rmCreateTradeRoute(); 
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.0, 0.75);
   	rmAddTradeRouteWaypoint(tradeRouteID2, 0.27, 0.75);
	if (PlayerNum >=7)
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.42, 0.88);
	else
		rmAddTradeRouteWaypoint(tradeRouteID2, 0.4, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.6, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID2, 0.73, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID2, 1.0, 0.75);
    rmBuildTradeRoute(tradeRouteID2, "armored_train");

	int tradeRouteID3 = rmCreateTradeRoute();
	rmAddTradeRouteWaypoint(tradeRouteID3, 1.0, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.73, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.6, 0.88);
	if (PlayerNum >=7)
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.42, 0.88);
	else
		rmAddTradeRouteWaypoint(tradeRouteID3, 0.4, 0.88);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.27, 0.75);
	rmAddTradeRouteWaypoint(tradeRouteID3, 0.0, 0.75);
    rmBuildTradeRoute(tradeRouteID3, "armored_train");

    // Place train stopper, because without it the islands son't spawn
	if (PlayerNum >=5)
		vector socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.5);
	else
    	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.47);
    rmPlaceObjectDefAtPoint(stopperID, 0, socketLoc);
	vector stoperLoc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperID, 0));

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.17);
    rmPlaceObjectDefAtPoint(stopper2ID, 0, socketLoc);
	vector stoperLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopper2ID, 0));

	if (PlayerNum >=5)
		socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.83);
	else
		socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.8);
    rmPlaceObjectDefAtPoint(stopper3ID, 0, socketLoc);
	vector stoperLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopper3ID, 0));

	if (PlayerNum >=7)
		socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.335);
	else
		socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.33);
    rmPlaceObjectDefAtPoint(stopperBridge1ID, 0, socketLoc);
	vector bridgeLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperBridge1ID, 0));

	if (PlayerNum ==5 || PlayerNum ==6)
		socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.67);
	else
		socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.6555);
    rmPlaceObjectDefAtPoint(stopperBridge2ID, 0, socketLoc);
	vector bridgeLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(stopperBridge2ID, 0));

	// >>>>>>>>>>>>>>>>>>>>>>>>>> Make Load bar move >>>>>>>>>>>>>>>>>>>>>>>>>
	rmSetStatusText("",0.20);

	//  ************************** River ******************************

    // River must be defined before the islands are placed
	if (PlayerNum >=7)
		int riverID = rmRiverCreate(-1, "ZP Mississippi River", 4, 4, 180, 180); //  (-1, "new england lake", 18, 14, 5, 5)
	else
		riverID = rmRiverCreate(-1, "ZP Mississippi River", 4, 4, 150, 150); //  (-1, "new england lake", 18, 14, 5, 5)
    rmRiverAddWaypoint(riverID, 0.5, 0.0);
    rmRiverAddWaypoint(riverID, 0.5, 1.0);
	rmRiverBuild(riverID);

	int stopper4ID=rmCreateObjectDef("Armored Train Stopper4");
	rmAddObjectDefItem(stopper4ID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopper4ID, true);
	rmSetObjectDefMinDistance(stopper4ID, 0.0);
	rmSetObjectDefMaxDistance(stopper4ID, 0.0);

	int stopper5ID=rmCreateObjectDef("Armored Train Stopper5");
	rmAddObjectDefItem(stopper5ID, "zpSPCWaterSpawnPoint", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopper5ID, true);
	rmSetObjectDefMinDistance(stopper5ID, 0.0);
	rmSetObjectDefMaxDistance(stopper5ID, 0.0);

	// River Trade Route
	int tradeRouteID4 = rmCreateTradeRoute();
	if (PlayerNum >=7) {
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.0);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.3);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.55, 0.4);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.45);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.45, 0.4);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.3);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.0);
	}
	else {
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.0);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.3);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.57, 0.4);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.45);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.43, 0.4);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.3);
		rmAddTradeRouteWaypoint(tradeRouteID4, 0.5, 0.0);
	}

	// *********************** INVENTOR GROUPINGS ***************************

	// Define and place Ports

	int harbour01ID=rmCreateObjectDef("harbour");
	rmAddObjectDefItem(harbour01ID, "zpTradingPostCaptureNaval", 1, 0.0);
	rmSetObjectDefAllowOverlap(harbour01ID, true);
	rmSetObjectDefMinDistance(harbour01ID, 0.0);
	rmSetObjectDefMaxDistance(harbour01ID, 0.0);
	rmSetObjectDefTradeRouteID(harbour01ID, tradeRouteID4);
	rmPlaceObjectDefAtLoc(harbour01ID, 0, 0.5-rmXTilesToFraction(30),0.5-rmXTilesToFraction(27));
	vector harbourLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(harbour01ID, 0));

	int harbour02ID=rmCreateObjectDef("harbour2");
	rmAddObjectDefItem(harbour02ID, "zpTradingPostCaptureNaval", 1, 0.0);
	rmSetObjectDefAllowOverlap(harbour02ID, true);
	rmSetObjectDefMinDistance(harbour02ID, 0.0);
	rmSetObjectDefMaxDistance(harbour02ID, 0.0);
	rmSetObjectDefTradeRouteID(harbour02ID, tradeRouteID4);
	rmPlaceObjectDefAtLoc(harbour02ID, 0, 0.5+rmXTilesToFraction(30),0.5-rmXTilesToFraction(27));
	vector harbourLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(harbour02ID, 0));

	// River groupings

	rmSetNuggetDifficulty(312, 312);

	// Inventors 1
	int inventorsBaseGrouping1 = rmCreateGrouping("inventorsBaseGrouping1", "City_State_Inventors_01");
    rmSetGroupingMinDistance(inventorsBaseGrouping1, 0.00);
    rmSetGroupingMaxDistance(inventorsBaseGrouping1, 0.00);
	rmAddGroupingToClass(inventorsBaseGrouping1, rmClassID("classPlateau"));

	int factoryInstanceID1 = rmPlaceGroupingInstanceAtLoc(inventorsBaseGrouping1, rmXMetersToFraction(xsVectorGetX(harbourLoc1))-rmXTilesToFraction(13), rmZMetersToFraction(xsVectorGetZ(harbourLoc1))+rmZTilesToFraction(4), 0);

	// Inventors 2
	int inventorsBaseGrouping2 = rmCreateGrouping("inventorsBaseGrouping2", "City_State_Inventors_02");
    rmSetGroupingMinDistance(inventorsBaseGrouping2, 0.00);
    rmSetGroupingMaxDistance(inventorsBaseGrouping2, 0.00);
	rmAddGroupingToClass(inventorsBaseGrouping2, rmClassID("classPlateau"));

	int factoryInstanceID2 = rmPlaceGroupingInstanceAtLoc(inventorsBaseGrouping2, rmXMetersToFraction(xsVectorGetX(harbourLoc2))+rmXTilesToFraction(12), rmZMetersToFraction(xsVectorGetZ(harbourLoc2))+rmZTilesToFraction(3), 0);

	rmBuildTradeRoute(tradeRouteID4, "native_water_trail");

	// water Areas

	int riverArea1 = rmCreateArea("riverArea1");
    rmSetAreaSize(riverArea1 , rmAreaTilesToFraction(6000), rmAreaTilesToFraction(6000));
	if (PlayerNum >=5)
		rmSetAreaSize(riverArea1 , rmAreaTilesToFraction(7000), rmAreaTilesToFraction(7000));
	if (PlayerNum >=7)
		rmSetAreaSize(riverArea1 , rmAreaTilesToFraction(8000), rmAreaTilesToFraction(8000));
    rmSetAreaLocation(riverArea1 , 0.5, 0.5);		
    rmSetAreaCoherence(riverArea1 , 0.6);
    rmSetAreaElevationVariation(riverArea1, 0.0);
	rmAddAreaToClass(riverArea1, classGreatLake);
	rmAddAreaInfluenceSegment(riverArea1, 0.5, 0.0, 0.5, 0.5);
	rmSetAreaObeyWorldCircleConstraint(riverArea1, false);
    rmBuildArea(riverArea1); 

	int riverArea2 = rmCreateArea("riverArea2");
    rmSetAreaSize(riverArea2, rmAreaTilesToFraction(2800), rmAreaTilesToFraction(2800));
	if (PlayerNum >=5)
		rmSetAreaSize(riverArea2, rmAreaTilesToFraction(3200), rmAreaTilesToFraction(3200));
	if (PlayerNum >=7)
		rmSetAreaSize(riverArea2, rmAreaTilesToFraction(3600), rmAreaTilesToFraction(3600));
    rmSetAreaLocation(riverArea2, 0.5, 0.5);			
    rmSetAreaCoherence(riverArea2, 0.8);
    rmSetAreaElevationVariation(riverArea2, 0.0);
	rmAddAreaToClass(riverArea2, classGreatLake);
	rmAddAreaInfluenceSegment(riverArea2, 0.5, 0.5, 0.0, 0.6);
	rmSetAreaObeyWorldCircleConstraint(riverArea2, false);
    rmBuildArea(riverArea2); 

	int riverArea3 = rmCreateArea("riverArea3");
    rmSetAreaSize(riverArea3 , rmAreaTilesToFraction(2800), rmAreaTilesToFraction(2800));
	if (PlayerNum >=5)
		rmSetAreaSize(riverArea3 , rmAreaTilesToFraction(3200), rmAreaTilesToFraction(3200));
	if (PlayerNum >=7)
		rmSetAreaSize(riverArea3 , rmAreaTilesToFraction(3600), rmAreaTilesToFraction(3600));
    rmSetAreaLocation(riverArea3 , 0.5, 0.5);	
    rmSetAreaCoherence(riverArea3 , 0.8);
    rmSetAreaElevationVariation(riverArea3, 0.0);
	rmAddAreaToClass(riverArea3, classGreatLake);
	rmAddAreaInfluenceSegment(riverArea3, 0.5, 0.5, 1.0, 0.6);
	rmSetAreaObeyWorldCircleConstraint(riverArea3, false);
    rmBuildArea(riverArea3);

	int riverArea4 = rmCreateArea("riverArea4");
    rmSetAreaSize(riverArea4 , rmAreaTilesToFraction(2600), rmAreaTilesToFraction(2600));
	if (PlayerNum >=5)
		rmSetAreaSize(riverArea4 , rmAreaTilesToFraction(3000), rmAreaTilesToFraction(3000));
	if (PlayerNum >=7)
		rmSetAreaSize(riverArea4 , rmAreaTilesToFraction(3100), rmAreaTilesToFraction(3100));
    rmSetAreaLocation(riverArea4 , 0.5, 0.5);	
    rmSetAreaCoherence(riverArea4 , 0.8);
    rmSetAreaElevationVariation(riverArea4, 0.0);
	rmAddAreaToClass(riverArea4, classGreatLake);
	rmAddAreaInfluenceSegment(riverArea4, 0.5, 0.5, 0.25, 1.0);
	rmSetAreaObeyWorldCircleConstraint(riverArea4, false);
    rmBuildArea(riverArea4);

	int riverArea5 = rmCreateArea("riverArea5");
    rmSetAreaSize(riverArea5 , rmAreaTilesToFraction(2600), rmAreaTilesToFraction(2600));
	if (PlayerNum >=5)
		rmSetAreaSize(riverArea5 , rmAreaTilesToFraction(3000), rmAreaTilesToFraction(3000));
	if (PlayerNum >=7)
		rmSetAreaSize(riverArea5 , rmAreaTilesToFraction(3100), rmAreaTilesToFraction(3100));
    rmSetAreaLocation(riverArea5 , 0.5, 0.5);	
    rmSetAreaCoherence(riverArea5 , 0.8);
    rmSetAreaElevationVariation(riverArea5, 0.0);
	rmAddAreaToClass(riverArea5, classGreatLake);
	rmAddAreaInfluenceSegment(riverArea5, 0.5, 0.5, 0.75, 1.0);
	rmSetAreaObeyWorldCircleConstraint(riverArea5, false);
    rmBuildArea(riverArea5);

	int centralLake = rmCreateArea("centralLake");
    rmSetAreaSize(centralLake , rmAreaTilesToFraction(5600), rmAreaTilesToFraction(5600));
	if (PlayerNum >=5)
		rmSetAreaSize(centralLake , rmAreaTilesToFraction(6500), rmAreaTilesToFraction(6500));
	if (PlayerNum >=7)
		rmSetAreaSize(centralLake , rmAreaTilesToFraction(7000), rmAreaTilesToFraction(7000));
    rmSetAreaLocation(centralLake , 0.5, 0.5);	
    rmSetAreaCoherence(centralLake , 0.8);
    rmSetAreaElevationVariation(centralLake, 0.0);
	rmAddAreaToClass(centralLake, classDeepWater);
    rmBuildArea(centralLake);

	// Bridges
	int bridgeGrouping1 = rmCreateGrouping("bridge1", "Bridge_universal_N");
    rmSetGroupingMinDistance(bridgeGrouping1, 0.00);
    rmSetGroupingMaxDistance(bridgeGrouping1, 0.00);
	rmAddGroupingToClass(bridgeGrouping1, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(bridgeGrouping1, 0, rmXMetersToFraction(xsVectorGetX(bridgeLoc1)-2), rmZMetersToFraction(xsVectorGetZ(bridgeLoc1)+2));

	int bridgeGrouping2 = rmCreateGrouping("bridge2", "Bridge_universal_E");
    rmSetGroupingMinDistance(bridgeGrouping2, 0.00);
    rmSetGroupingMaxDistance(bridgeGrouping2, 0.00);
	rmAddGroupingToClass(bridgeGrouping2, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(bridgeGrouping2, 0, rmXMetersToFraction(xsVectorGetX(bridgeLoc2)+4), rmZMetersToFraction(xsVectorGetZ(bridgeLoc2)+4));

	// Shallows
	int Shallow1ID = rmCreateArea("shallow1");
    rmSetAreaSize(Shallow1ID, rmAreaTilesToFraction(600), rmAreaTilesToFraction(600));
    rmSetAreaCoherence(Shallow1ID, 0.5);
    rmSetAreaHeightBlend(Shallow1ID, 1.5);
    rmSetAreaSmoothDistance(Shallow1ID, 5);
    rmSetAreaLocation(Shallow1ID, 0.1, 0.6);
	rmAddAreaInfluenceSegment(Shallow1ID, 0.1, 0.55, 0.1, 0.65);
	rmSetAreaBaseHeight(Shallow1ID, -1.5);
    rmBuildArea(Shallow1ID);

	int Shallow2ID = rmCreateArea("shallow2");
    rmSetAreaSize(Shallow2ID, rmAreaTilesToFraction(600), rmAreaTilesToFraction(600));
    rmSetAreaCoherence(Shallow2ID, 0.5);
    rmSetAreaHeightBlend(Shallow2ID, 1.5);
    rmSetAreaSmoothDistance(Shallow2ID, 5);
    rmSetAreaLocation(Shallow2ID, 0.9, 0.6);
	rmAddAreaInfluenceSegment(Shallow2ID, 0.9, 0.55, 0.9, 0.65);
	rmSetAreaBaseHeight(Shallow2ID, -1.5);
    rmBuildArea(Shallow2ID);

    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!! ISLANDS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	int nativeIsland1ID = rmCreateArea("native_island1");
    rmSetAreaSize(nativeIsland1ID, 0.2, 0.2);
    rmSetAreaCoherence(nativeIsland1ID, 1.0);
    rmSetAreaMix(nativeIsland1ID, "nwt_grass2");
    rmSetAreaHeightBlend(nativeIsland1ID, 1);
    rmSetAreaSmoothDistance(nativeIsland1ID, 10);
    rmSetAreaObeyWorldCircleConstraint(nativeIsland1ID, false);
	rmAddAreaConstraint(nativeIsland1ID, greatLakesConstraint);
    rmSetAreaLocation(nativeIsland1ID, 0.5, 1.0);
	rmSetAreaBaseHeight(nativeIsland1ID, 1);
    rmBuildArea(nativeIsland1ID);

	int nativeIsland2ID = rmCreateArea("native_island2");
    rmSetAreaSize(nativeIsland2ID, 0.2, 0.2);
    rmSetAreaCoherence(nativeIsland2ID, 1.0);
    rmSetAreaMix(nativeIsland2ID, "nwt_grass2");
    rmSetAreaHeightBlend(nativeIsland2ID, 1);
    rmSetAreaSmoothDistance(nativeIsland2ID, 10);
    rmSetAreaObeyWorldCircleConstraint(nativeIsland2ID, false);
	rmAddAreaConstraint(nativeIsland2ID, greatLakesConstraint);
    rmSetAreaLocation(nativeIsland2ID, 0.2, 0.8);
	rmSetAreaBaseHeight(nativeIsland2ID, 1);
    rmBuildArea(nativeIsland2ID);

	int nativeIsland3ID = rmCreateArea("native_island3");
    rmSetAreaSize(nativeIsland3ID, 0.2, 0.2);
    rmSetAreaCoherence(nativeIsland3ID, 1.0);
    rmSetAreaMix(nativeIsland3ID, "nwt_grass2");
    rmSetAreaHeightBlend(nativeIsland3ID, 1);
    rmSetAreaSmoothDistance(nativeIsland3ID, 10);
    rmSetAreaObeyWorldCircleConstraint(nativeIsland3ID, false);
	rmAddAreaConstraint(nativeIsland3ID, greatLakesConstraint);
    rmSetAreaLocation(nativeIsland3ID, 0.8, 0.8);
	rmSetAreaBaseHeight(nativeIsland3ID, 1);
    rmBuildArea(nativeIsland3ID);

	int playerIslandSouthID = rmCreateArea("playerIslandSouth");
    rmSetAreaSize(playerIslandSouthID, 0.3, 0.3);
    rmSetAreaCoherence(playerIslandSouthID, 1.0);
    rmSetAreaMix(playerIslandSouthID, "nwt_grass2");
    rmSetAreaBaseHeight(playerIslandSouthID, 1);
    rmSetAreaHeightBlend(playerIslandSouthID, 2);
    rmSetAreaSmoothDistance(playerIslandSouthID, 5);
    rmSetAreaObeyWorldCircleConstraint(playerIslandSouthID, false);
	rmAddAreaConstraint(playerIslandSouthID, greatLakesConstraint);
	rmAddAreaConstraint(playerIslandSouthID, avoidDeepWater);
	rmAddAreaConstraint(playerIslandSouthID, avoidTradeRoute);
	rmAddAreaConstraint(playerIslandSouthID, avoidPathBlock);
    rmSetAreaLocation(playerIslandSouthID, 0.2, 0.4);
	rmSetAreaElevationVariation(playerIslandSouthID, 4.0);
	rmSetAreaElevationType(playerIslandSouthID, cElevTurbulence);
	rmSetAreaElevationMinFrequency(playerIslandSouthID, 0.09);
	rmSetAreaElevationOctaves(playerIslandSouthID, 3);
	rmSetAreaElevationPersistence(playerIslandSouthID, 0.2);
	rmSetAreaElevationNoiseBias(playerIslandSouthID, 1);
    rmBuildArea(playerIslandSouthID);

	int playerIslandNorthID = rmCreateArea("playerIslandNorth");
	rmSetAreaSize(playerIslandNorthID, 0.3, 0.3);
	rmSetAreaCoherence(playerIslandNorthID, 1.0);
	rmSetAreaMix(playerIslandNorthID, "nwt_grass2");
	rmSetAreaBaseHeight(playerIslandNorthID, 1);
	rmSetAreaHeightBlend(playerIslandNorthID, 2);
	rmSetAreaSmoothDistance(playerIslandNorthID, 5);
	rmSetAreaObeyWorldCircleConstraint(playerIslandNorthID, false);
	rmAddAreaConstraint(playerIslandNorthID, greatLakesConstraint);
	rmAddAreaConstraint(playerIslandNorthID, avoidDeepWater);
	rmAddAreaConstraint(playerIslandNorthID, avoidTradeRoute);
	rmAddAreaConstraint(playerIslandNorthID, avoidPathBlock);
	rmSetAreaLocation(playerIslandNorthID, 0.8, 0.4);
	rmSetAreaElevationVariation(playerIslandNorthID, 4.0);
	rmSetAreaElevationType(playerIslandNorthID, cElevTurbulence);
	rmSetAreaElevationMinFrequency(playerIslandNorthID, 0.09);
	rmSetAreaElevationOctaves(playerIslandNorthID, 3);
	rmSetAreaElevationPersistence(playerIslandNorthID, 0.2);
	rmSetAreaElevationNoiseBias(playerIslandNorthID, 1);
	rmBuildArea(playerIslandNorthID);

	// ********************* City States ********************

	// Define stoppers

	int stopperCityState1ID=rmCreateObjectDef("Armored Train Stopper State 1");
	rmAddObjectDefItem(stopperCityState1ID, "zpTrainStopper", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperCityState1ID, true);
	rmSetObjectDefMinDistance(stopperCityState1ID, 0.0);
	rmSetObjectDefMaxDistance(stopperCityState1ID, 0.0);  

	int stopperCityState2ID=rmCreateObjectDef("Armored Train Stopper State 2");
	rmAddObjectDefItem(stopperCityState2ID, "zpTrainStopper", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperCityState2ID, true);
	rmSetObjectDefMinDistance(stopperCityState2ID, 0.0);
	rmSetObjectDefMaxDistance(stopperCityState2ID, 0.0);

	int stopperCityState3ID=rmCreateObjectDef("Armored Train Stopper State 3");
	rmAddObjectDefItem(stopperCityState3ID, "zpTrainStopper", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperCityState3ID, true);
	rmSetObjectDefMinDistance(stopperCityState3ID, 0.0);
	rmSetObjectDefMaxDistance(stopperCityState3ID, 0.0);

	int stopperCityStateFake1ID=rmCreateObjectDef("Armored Train Stopper State Fake 1");
	rmAddObjectDefItem(stopperCityStateFake1ID, "zpTrainStopper", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperCityStateFake1ID, true);
	rmSetObjectDefMinDistance(stopperCityStateFake1ID, 0.0);
	rmSetObjectDefMaxDistance(stopperCityStateFake1ID, 0.0);  

	int stopperCityStateFake2ID=rmCreateObjectDef("Armored Train Stopper State Fake 2");
	rmAddObjectDefItem(stopperCityStateFake2ID, "zpTrainStopper", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperCityStateFake2ID, true);
	rmSetObjectDefMinDistance(stopperCityStateFake2ID, 0.0);
	rmSetObjectDefMaxDistance(stopperCityStateFake2ID, 0.0);

	int stopperCityStateFake3ID=rmCreateObjectDef("Armored Train Stopper State Fake 3");
	rmAddObjectDefItem(stopperCityStateFake3ID, "zpTrainStopper", 1, 0.0);
	rmSetObjectDefAllowOverlap(stopperCityStateFake3ID, true);
	rmSetObjectDefMinDistance(stopperCityStateFake3ID, 0.0);
	rmSetObjectDefMaxDistance(stopperCityStateFake3ID, 0.0);

	int socket01 = rmCreateGrouping("socket01", "City_State_Western_Station");
    rmSetGroupingMinDistance(socket01, 0.00);
    rmSetGroupingMaxDistance(socket01, 0.00);
	rmAddGroupingToClass(socket01, rmClassID("classPlateau"));

	// Define and place stations

	int station01ID=rmCreateObjectDef("Station1");
	rmAddObjectDefItem(station01ID, "zpTrainStationA", 1, 0.0);
	rmSetObjectDefAllowOverlap(station01ID, true);
	rmSetObjectDefMinDistance(station01ID, 0.0);
	rmSetObjectDefMaxDistance(station01ID, 0.0);
	rmSetObjectDefTradeRouteID(station01ID, tradeRouteID);
	rmPlaceObjectDefAtLoc(station01ID, 0, rmXMetersToFraction(xsVectorGetX(stoperLoc)), rmZMetersToFraction(xsVectorGetZ(stoperLoc)+9));
	
	vector stationLoc1 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(station01ID, 0));
	rmPlaceGroupingAtLoc(socket01, 0, rmXMetersToFraction(xsVectorGetX(stationLoc1)), rmZMetersToFraction(xsVectorGetZ(stationLoc1)-3));
	rmPlaceObjectDefAtLoc(stopperCityStateFake1ID, 0, rmXMetersToFraction(xsVectorGetX(stationLoc1)), rmZMetersToFraction(xsVectorGetZ(stationLoc1)));
	
	int station02ID=rmCreateObjectDef("Station2");
	rmAddObjectDefItem(station02ID, "zpTrainStationA", 1, 0.0);
	rmSetObjectDefAllowOverlap(station02ID, true);
	rmSetObjectDefMinDistance(station02ID, 0.0);
	rmSetObjectDefMaxDistance(station02ID, 0.0);
	rmSetObjectDefTradeRouteID(station02ID, tradeRouteID);
	rmPlaceObjectDefAtLoc(station02ID, 0, rmXMetersToFraction(xsVectorGetX(stoperLoc2)), rmZMetersToFraction(xsVectorGetZ(stoperLoc2)+9));
	
	vector stationLoc2 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(station02ID, 0));
	rmPlaceGroupingAtLoc(socket01, 0, rmXMetersToFraction(xsVectorGetX(stationLoc2)), rmZMetersToFraction(xsVectorGetZ(stationLoc2)-3));
	rmPlaceObjectDefAtLoc(stopperCityStateFake2ID, 0, rmXMetersToFraction(xsVectorGetX(stationLoc2)), rmZMetersToFraction(xsVectorGetZ(stationLoc2)));

	int station03ID=rmCreateObjectDef("Station3");
	rmAddObjectDefItem(station03ID, "zpTrainStationA", 1, 0.0);
	rmSetObjectDefAllowOverlap(station03ID, true);
	rmSetObjectDefMinDistance(station03ID, 0.0);
	rmSetObjectDefMaxDistance(station03ID, 0.0);
	rmSetObjectDefTradeRouteID(station03ID, tradeRouteID);
	rmPlaceObjectDefAtLoc(station03ID, 0, rmXMetersToFraction(xsVectorGetX(stoperLoc3)), rmZMetersToFraction(xsVectorGetZ(stoperLoc3)+9));
	
	vector stationLoc3 = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(station03ID, 0));
	rmPlaceGroupingAtLoc(socket01, 0, rmXMetersToFraction(xsVectorGetX(stationLoc3)), rmZMetersToFraction(xsVectorGetZ(stationLoc3)-3));
	rmPlaceObjectDefAtLoc(stopperCityStateFake3ID, 0, rmXMetersToFraction(xsVectorGetX(stationLoc3)), rmZMetersToFraction(xsVectorGetZ(stationLoc3)));

	// Define and place city groupings
	
	rmSetNuggetDifficulty(313, 313);

	int cityState01 = rmCreateGrouping("citystate1", "City_State_Western_01");
    rmSetGroupingMinDistance(cityState01, 0.00);
    rmSetGroupingMaxDistance(cityState01, 0.00);
	rmAddGroupingToClass(cityState01, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(cityState01, 0, rmXMetersToFraction(xsVectorGetX(stationLoc1)), rmZMetersToFraction(xsVectorGetZ(stationLoc1)-3));

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.49);
    rmPlaceObjectDefAtPoint(stopperCityState1ID, 0, socketLoc);

	int cityState02 = rmCreateGrouping("citystate2", "City_State_Western_02");
    rmSetGroupingMinDistance(cityState02, 0.00);
    rmSetGroupingMaxDistance(cityState02, 0.00);
	rmAddGroupingToClass(cityState02, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(cityState02, 0, rmXMetersToFraction(xsVectorGetX(stationLoc2)), rmZMetersToFraction(xsVectorGetZ(stationLoc2)-2));

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.15);
    rmPlaceObjectDefAtPoint(stopperCityState2ID, 0, socketLoc);

	int cityState03 = rmCreateGrouping("citystate3", "City_State_Western_03");
    rmSetGroupingMinDistance(cityState03, 0.00);
    rmSetGroupingMaxDistance(cityState03, 0.00);
	rmAddGroupingToClass(cityState03, rmClassID("classPlateau"));
	rmPlaceGroupingAtLoc(cityState03, 0, rmXMetersToFraction(xsVectorGetX(stationLoc3)), rmZMetersToFraction(xsVectorGetZ(stationLoc3)-2));

	socketLoc = rmGetTradeRouteWayPoint(tradeRouteID, 0.81);
    rmPlaceObjectDefAtPoint(stopperCityState3ID, 0, socketLoc);

	// Nuggets

	int nugget1ID=rmCreateObjectDef("Nugget 1");
	rmAddObjectDefItem(nugget1ID, "Nugget", 1, 0.0);
	rmSetObjectDefAllowOverlap(nugget1ID, true);
	rmSetObjectDefMinDistance(nugget1ID, 0.0);
	rmSetObjectDefMaxDistance(nugget1ID, 5.0);  
	rmPlaceObjectDefAtLoc(nugget1ID, 0, rmXMetersToFraction(xsVectorGetX(stoperLoc)), rmZMetersToFraction(xsVectorGetZ(stoperLoc)-3));

	int nugget2ID=rmCreateObjectDef("Nugget 2");
	rmAddObjectDefItem(nugget2ID, "Nugget", 1, 0.0);
	rmSetObjectDefAllowOverlap(nugget2ID, true);
	rmSetObjectDefMinDistance(nugget2ID, 0.0);
	rmSetObjectDefMaxDistance(nugget2ID, 5.0);
	rmPlaceObjectDefAtLoc(nugget2ID, 0, rmXMetersToFraction(xsVectorGetX(stoperLoc2)), rmZMetersToFraction(xsVectorGetZ(stoperLoc2)-3));

	int nugget3ID=rmCreateObjectDef("Nugget 3");
	rmAddObjectDefItem(nugget3ID, "Nugget", 1, 0.0);
	rmSetObjectDefAllowOverlap(nugget3ID, true);
	rmSetObjectDefMinDistance(nugget3ID, 0.0);
	rmSetObjectDefMaxDistance(nugget3ID, 5.0);
	rmPlaceObjectDefAtLoc(nugget3ID, 0, rmXMetersToFraction(xsVectorGetX(stoperLoc3)), rmZMetersToFraction(xsVectorGetZ(stoperLoc3)-3));

	// terrain Elevation

	for (x=1; <= 3) {
		int nativeHillsID = rmCreateArea("native_hills1"+x);
		rmSetAreaSize(nativeHillsID, 0.04, 0.04);
		rmSetAreaCoherence(nativeHillsID, 1.0);
		rmSetAreaHeightBlend(nativeHillsID, 2);
		rmSetAreaSmoothDistance(nativeHillsID, 10);
		rmSetAreaObeyWorldCircleConstraint(nativeHillsID, false);
		rmSetAreaBaseHeight(nativeHillsID, 2);
		rmAddAreaConstraint(nativeHillsID, avoidPlateau);
		rmAddAreaConstraint(nativeHillsID, greatLakesConstraint);
		rmAddAreaConstraint(nativeHillsID, shortAvoidTradeRoute);
		rmSetAreaElevationVariation(nativeHillsID, 4.0);
		rmSetAreaElevationType(nativeHillsID, cElevTurbulence);
		rmSetAreaElevationMinFrequency(nativeHillsID, 0.09);
		rmSetAreaElevationOctaves(nativeHillsID, 3);
		rmSetAreaElevationPersistence(nativeHillsID, 0.2);
		rmSetAreaElevationNoiseBias(nativeHillsID, 1);
		//rmSetAreaMix(nativeHillsID, "italy_grass");
		if (x==1)
			rmSetAreaLocation(nativeHillsID, 0.5, 0.75);
		if (x==2)
			rmSetAreaLocation(nativeHillsID, 0.35, 0.65);
		if (x==3)
			rmSetAreaLocation(nativeHillsID, 0.65, 0.65);
		rmBuildArea(nativeHillsID);

		int nativeMountains=rmCreateArea("native mountains"+x); 
		rmSetAreaSize(nativeMountains, 0.02, 0.02);
		rmSetAreaCoherence(nativeMountains, 0.6);
		rmSetAreaSmoothDistance(nativeMountains, 5);
		rmSetAreaCliffType(nativeMountains, "Araucania Central Ozarks");
		rmSetAreaCliffEdge(nativeMountains, 4, 0.18, 0.0, 0.0, 0);
		rmSetAreaCliffHeight(nativeMountains, 6.0, 2.0, 0.3);
		rmSetAreaObeyWorldCircleConstraint(nativeMountains, false);
		rmAddAreaConstraint(nativeMountains, avoidPlateau);
		rmAddAreaConstraint(nativeMountains, avoidWater10);
		rmAddAreaConstraint(nativeMountains, avoidTradeRouteFar2);
		rmSetAreaCliffPainting(nativeMountains, false, true, true, 1.5, true);	
		if (x==1)
			rmSetAreaLocation(nativeMountains, 0.5, 1.0);
		if (x==2)
			rmSetAreaLocation(nativeMountains, 0.25, 0.9);
		if (x==3)
			rmSetAreaLocation(nativeMountains, 0.75, 0.9);
		rmBuildArea(nativeMountains);
	}


	// ******************* PLACE PLAYERS ******************

	// Text
	rmSetStatusText("",0.70);

	float teamStartLoc = rmRandFloat(0.0, 1.0);
	int weirdSpawn = 0;

    if(cNumberTeams == 2) {
		if (PlayerNum == 2) {
			if (teamStartLoc > 0.5) {
				rmPlacePlayer(1, 0.2, 0.25);
				rmPlacePlayer(2, 0.8, 0.25);
			}
			else {
				rmPlacePlayer(1, 0.8, 0.25);
				rmPlacePlayer(2, 0.2, 0.25);
			}	
		}
		else if (PlayerNum > 2&& PlayerNum <7) {
			if (teamStartLoc > 0.5) {
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.28, 0.4); 
				rmPlacePlayersCircular(0.4, 0.4, 0);
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.6, 0.72);
				rmPlacePlayersCircular(0.4, 0.4, 0);
			}
			else {
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.6, 0.72);
				rmPlacePlayersCircular(0.4, 0.4, 0);
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.28, 0.4); 
				rmPlacePlayersCircular(0.4, 0.4, 0);
			}
		}
		else {
			if (teamStartLoc > 0.5) {
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.26, 0.42); 
				rmPlacePlayersCircular(0.4, 0.4, 0);
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.58, 0.74);
				rmPlacePlayersCircular(0.4, 0.4, 0);
			}
			else {
				rmSetPlacementTeam(0);
				rmSetPlacementSection(0.58, 0.74);
				rmPlacePlayersCircular(0.4, 0.4, 0);
				rmSetPlacementTeam(1);
				rmSetPlacementSection(0.26, 0.42); 
				rmPlacePlayersCircular(0.4, 0.4, 0);
			}
		}
	}

	if ( rmGetNumberPlayersOnTeam(0)>4 ||  rmGetNumberPlayersOnTeam(1)>4)
	weirdSpawn = 1;

	// Town Centrer Start

	int playerStart = rmCreateStartingUnitsObjectDef(5.0);
	rmSetObjectDefMinDistance(playerStart, 7.0);
	rmSetObjectDefMaxDistance(playerStart, 12.0);

	// Player Resources

	int foodID = rmCreateObjectDef("starting hunt");
	rmAddObjectDefItem(foodID, "Turkey", 12, 6.0);
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

	int playerTreeID = rmCreateObjectDef("player trees");
	rmAddObjectDefItem(playerTreeID, "TreeCarolinaGrass", 15, 8.0);
    rmSetObjectDefMinDistance(playerTreeID, 15);
    rmSetObjectDefMaxDistance(playerTreeID, 25);
	rmAddObjectDefToClass(playerTreeID, classStartingResource);
	rmAddObjectDefToClass(playerTreeID, rmClassID("classForest"));
	rmAddObjectDefConstraint(playerTreeID, avoidStartingResources);
	rmAddObjectDefConstraint(playerTreeID, avoidImpassableLand);
	rmAddObjectDefConstraint(playerTreeID, avoidTradeRouteMin);

	int aiStartUrban = rmCreateObjectDef("is city map");
	rmAddObjectDefItem(aiStartUrban, "zpAIStartUrbanMap", 1, 0.0);

	// Water Flag
    int colonyShipID = 0;

	// Fake Frouping to fix the auto-grouping TC bug
	int fakeGroupingLock = rmCreateObjectDef("fake grouping lock"); 
	rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
	rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.65);

	//place tcs
    
    for(i=1; < cNumberNonGaiaPlayers + 1) {

		if (weirdSpawn==0){
			int playerID=rmCreateArea("player "+i);
			rmSetPlayerArea(i, playerID);
			rmSetAreaSize(playerID, rmAreaTilesToFraction(800));
			rmSetAreaLocPlayer(playerID, i);
			rmSetAreaWarnFailure(playerID, false);
			rmSetAreaCoherence(playerID, 1.0);
			rmSetAreaBaseHeight(playerID, 3.5);
			rmSetAreaSmoothDistance(playerID, 15);
			rmEchoInfo("Team area"+i);
			rmBuildArea(playerID); 

			int playerFortID = -1;
			playerFortID = rmCreateGrouping("player fort", "Player_Fort_CivilWar");
			rmAddGroupingToClass(playerFortID, rmClassID("classBlock"));  
			rmPlaceGroupingAtLoc(playerFortID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i), 1);
			rmPlaceObjectDefAtLoc(aiStartUrban, i, 0.5, 0.5);
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

			int commandPostID = rmCreateObjectDef("commandPostt"+i);
			rmAddObjectDefItem(commandPostID, "zpSPCCivilWarCommandery", 1, 2.0);
			rmSetObjectDefMinDistance(commandPostID, 0.0);
			rmSetObjectDefMaxDistance(commandPostID, 10.0);
			rmAddObjectDefConstraint(commandPostID, avoidTradeRouteMin);
			rmAddObjectDefConstraint(commandPostID, avoidWater20);
			rmAddObjectDefConstraint(commandPostID, avoidTownCenterShort);

			rmPlaceObjectDefAtLoc(startID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			rmPlaceObjectDefAtLoc(commandPostID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			rmPlaceObjectDefAtLoc(foodID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			rmPlaceObjectDefAtLoc(goldID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			rmPlaceObjectDefAtLoc(berryID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			rmPlaceObjectDefAtLoc(playerTreeID, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
			rmPlaceObjectDefAtLoc(aiStartUrban, i, 0.5, 0.5);

		}

		rmPlaceObjectDefAtLoc(playerStart, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));

		vector TCLocation=rmGetUnitPosition(rmGetUnitPlacedOfPlayer(playerStart, i));

		// Water Flag Placement
		colonyShipID=rmCreateObjectDef("colony ship "+i);
		rmAddObjectDefItem(colonyShipID, "HomeCityWaterSpawnFlag", 1, 1.0);
		if ( rmGetNomadStart())
		{
			if(rmGetPlayerCiv(i) == rmGetCivID("Ottomans"))
				rmAddObjectDefItem(colonyShipID, "Galley", 1, 10.0);
			else
				rmAddObjectDefItem(colonyShipID, "caravel", 1, 10.0);
		}
		if (PlayerNum==2){
			if (rmPlayerLocXFraction(i)<0.5) {
				rmPlaceObjectDefAtLoc(colonyShipID, i, 0.5-rmXMetersToFraction(30), rmPlayerLocZFraction(i)-rmZMetersToFraction(10));
			}
			else {
				rmPlaceObjectDefAtLoc(colonyShipID, i, 0.5+rmXMetersToFraction(30), rmPlayerLocZFraction(i)+rmZMetersToFraction(10));
			}
		}
		else{
			rmAddClosestPointConstraint(flagEdgeConstraint);
			rmAddClosestPointConstraint(flagVsFlag);
			rmAddClosestPointConstraint(avoidTradeRoute);
			rmAddClosestPointConstraint(flagLand);
			vector closestPoint = rmFindClosestPointVector(TCLocation, rmXFractionToMeters(1.0));
			rmPlaceObjectDefAtLoc(colonyShipID, i, rmXMetersToFraction(xsVectorGetX(closestPoint)), rmZMetersToFraction(xsVectorGetZ(closestPoint)));
		}

	}

	// ********************** RESOURCES **********************

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
	rmPlaceObjectDefInArea(randomGoldID, 0,  playerIslandSouthID, cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(randomGoldID, 0,  playerIslandNorthID, cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(randomGoldID, 0,  nativeIsland1ID, 2);
	rmPlaceObjectDefInArea(randomGoldID, 0,  nativeIsland2ID, 2);
	rmPlaceObjectDefInArea(randomGoldID, 0,  nativeIsland3ID, 2);


	// Forests

	int failCount = -1;
	int numTries = -1;

	// Define and place forests - north and south
	int forestTreeID = 0;

	numTries=42;
	if (cNumberNonGaiaPlayers >= 5)
		numTries = 56;
	if (cNumberNonGaiaPlayers >= 7)
		numTries = 70;
	failCount=0;
	for (i=0; <numTries)
		{   
		int northForest=rmCreateArea("northforest"+i);
		rmSetAreaWarnFailure(northForest, false);
		rmSetAreaSize(northForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));

		rmSetAreaForestType(northForest, "z68 North Carolinas");
		rmSetAreaForestDensity(northForest, 1.0);
		rmAddAreaToClass(northForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(northForest, 0.0);		//DAL more forest with more clumps
		rmSetAreaForestUnderbrush(northForest, 0.0);
		rmSetAreaCoherence(northForest, 0.4);
		rmAddAreaConstraint(northForest, avoidImportantItem); // DAL added, to try and make sure natives got on the map w/o override.
		rmAddAreaConstraint(northForest, shortAvoidCoin);
		rmAddAreaConstraint(northForest, avoidTownCenterFar);
		rmAddAreaConstraint(northForest, avoidSocketLong);
		rmAddAreaConstraint(northForest, avoidPlateau);
		rmAddAreaConstraint(northForest, avoidWater20);
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

	
	numTries=42;
	if (cNumberNonGaiaPlayers >= 5)
		numTries = 56;
	if (cNumberNonGaiaPlayers >= 7)
		numTries = 70;
	failCount=0;
	for (i = 0; i < numTries; i++)
	{   
		int southForest = rmCreateArea("southForest" + i);
		rmSetAreaWarnFailure(southForest, false);
		rmSetAreaSize(southForest, rmAreaTilesToFraction(100), rmAreaTilesToFraction(200));
		rmSetAreaForestType(southForest, "z68 North Carolinas");
		rmSetAreaForestDensity(southForest, 1.0);
		rmAddAreaToClass(southForest, rmClassID("classForest"));
		rmSetAreaForestClumpiness(southForest, 0.0);
		rmSetAreaForestUnderbrush(southForest, 0.0);
		rmSetAreaCoherence(southForest, 0.4);
		rmAddAreaConstraint(southForest, avoidImportantItem); // DAL added, to try and make sure natives got on the map w/o override.
		rmAddAreaConstraint(southForest, shortAvoidCoin);
		rmAddAreaConstraint(southForest, avoidTownCenterFar);
		rmAddAreaConstraint(southForest, avoidSocketLong);
		rmAddAreaConstraint(southForest, avoidPlateau);
		rmAddAreaConstraint(southForest, avoidWater20);
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

	// Moose Herds
	int mooseHerdID=rmCreateObjectDef("moose herd");
	rmAddObjectDefItem(mooseHerdID, "turkey", rmRandInt(8,14), 6.0);
	rmSetObjectDefCreateHerd(mooseHerdID, true);
	rmSetObjectDefMinDistance(mooseHerdID, rmXFractionToMeters(0.03));
	rmSetObjectDefMaxDistance(mooseHerdID, rmXFractionToMeters(0.5));
	rmAddObjectDefConstraint(mooseHerdID, shortAvoidCoin);
	rmAddObjectDefConstraint(mooseHerdID, avoidAll);
	rmAddObjectDefConstraint(mooseHerdID, avoidTownCenterFar);
	rmAddObjectDefConstraint(mooseHerdID, avoidImpassableLand);
	rmAddObjectDefConstraint(mooseHerdID, mooseConstraint);
	rmAddObjectDefConstraint(mooseHerdID, shortDeerConstraint);
	numTries=3*cNumberNonGaiaPlayers;
	for (i=0; <numTries)
	{
		rmPlaceObjectDefAtLoc(mooseHerdID, 0, 0.5, 0.5);
	}

	// ********* Nuggets ********

	int nugget1= rmCreateObjectDef("nugget easy"); 
	rmAddObjectDefItem(nugget1, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(1, 1);
	rmAddObjectDefToClass(nugget1, rmClassID("nuggets"));
	rmAddObjectDefConstraint(nugget1, shortPlayerConstraint);
	rmAddObjectDefConstraint(nugget1, avoidTownCenter);
	rmAddObjectDefConstraint(nugget1, avoidImpassableLand);
	rmAddObjectDefConstraint(nugget1, avoidNuggets);
	rmAddObjectDefConstraint(nugget1, avoidTradeSockets);
	rmAddObjectDefConstraint(nugget1, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget1, avoidAll);
	rmAddObjectDefConstraint(nugget1, circleConstraint);
	rmPlaceObjectDefInArea(nugget1, 0,  playerIslandSouthID, cNumberNonGaiaPlayers);
	rmPlaceObjectDefInArea(nugget1, 0,  playerIslandNorthID, cNumberNonGaiaPlayers);

	int nugget2= rmCreateObjectDef("nugget medium"); 
	rmAddObjectDefItem(nugget2, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(2, 2);
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

	int nugget3= rmCreateObjectDef("nugget hard"); 
	rmAddObjectDefItem(nugget3, "Nugget", 1, 0.0);
	rmSetNuggetDifficulty(3, 3);
	rmAddObjectDefToClass(nugget3, rmClassID("nuggets"));
	rmAddObjectDefConstraint(nugget3, avoidTownCenterFar);
	rmAddObjectDefConstraint(nugget3, avoidImpassableLand);
	rmAddObjectDefConstraint(nugget3, avoidNuggets);
	rmAddObjectDefConstraint(nugget3, avoidTradeRoute);
	rmAddObjectDefConstraint(nugget3, avoidSocketLong);
	rmAddObjectDefConstraint(nugget3, circleConstraint);
	rmAddObjectDefConstraint(nugget3, avoidAll);
	rmAddObjectDefConstraint(nugget3, avoidWater20);
	rmPlaceObjectDefInArea(nugget3, 0,  nativeIsland1ID, 2);
	rmPlaceObjectDefInArea(nugget3, 0,  nativeIsland2ID, 2);
	rmPlaceObjectDefInArea(nugget3, 0,  nativeIsland3ID, 2);

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
	rmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 60);

	// ____________________ LOCAL MERCENARIES ____________________
	rmDisableDefaultMercs(true);
	rmDisableCivTypeMercRestriction(true);
	rmEnableMerc("deSaloonGunslinger", -1);
	rmEnableMerc("deSaloonOwlhoot", -1);
	rmEnableMerc("deSaloonCowboy", -1);
	rmEnableMerc("deMercMountedRifleman", -1);
	rmEnableMerc("deMercBrigadier", -1);
	rmEnableMerc("MercJaeger", -1);

	rmForbidTradeMonopoly(true);

	// ____________________ MAP OBJECTIVES ____________________
    rmObjectiveScreenSetTitle(302544);
    rmObjectiveScreenSetGoal(302643);
    rmObjectiveAdd(302562, 302644, true, true, true);
	rmObjectiveSetTeam(1, 1);
	rmObjectiveAdd(302563, 302644, true, true, true);
	rmObjectiveSetTeam(2, 2);
	

	// ------Triggers--------//

	int westernATStoper1 = rmGetUnitPlaced(stopperCityState1ID, 0)+5;
	int westernATStoper2 = rmGetUnitPlaced(stopperCityState2ID, 0)+5;
	int westernATStoper3 = rmGetUnitPlaced(stopperCityState3ID, 0)+5;

	int westernSocket1 = rmGetUnitPlaced(stopperCityStateFake1ID, 0)+4;
	int westernSocket2 = rmGetUnitPlaced(stopperCityStateFake2ID, 0)+4;
	int westernSocket3 = rmGetUnitPlaced(stopperCityStateFake3ID, 0)+4;

	int westernNugget1 = rmGetUnitPlaced(nugget1ID, 0)+5;
	int westernNugget2 = rmGetUnitPlaced(nugget2ID, 0)+5;
	int westernNugget3 = rmGetUnitPlaced(nugget3ID, 0)+5;

	int tower11 = rmGetUnitPlaced(stopperCityState1ID, 0)+4;
	int tower12 = rmGetUnitPlaced(stopperCityState1ID, 0)+3;
	int tower13 = rmGetUnitPlaced(stopperCityState1ID, 0)+2;
	int tower14 = rmGetUnitPlaced(stopperCityState1ID, 0)+1;

	int tower21 = rmGetUnitPlaced(stopperCityState2ID, 0)+4;
	int tower22 = rmGetUnitPlaced(stopperCityState2ID, 0)+3;
	int tower23 = rmGetUnitPlaced(stopperCityState2ID, 0)+2;
	int tower24 = rmGetUnitPlaced(stopperCityState2ID, 0)+1;

	int tower31 = rmGetUnitPlaced(stopperCityState3ID, 0)+4;
	int tower32 = rmGetUnitPlaced(stopperCityState3ID, 0)+3;
	int tower33 = rmGetUnitPlaced(stopperCityState3ID, 0)+2;
	int tower34 = rmGetUnitPlaced(stopperCityState3ID, 0)+1;

	int InventorFlag1 = rmGetGroupingInstanceUnitByType(factoryInstanceID1, "zpNativeWaterSpawnFlag1")+5;
	int InventorFlag2 = rmGetGroupingInstanceUnitByType(factoryInstanceID2, "zpNativeWaterSpawnFlag2")+5;

	int InventorSocket1 = rmGetGroupingInstanceUnitByType(factoryInstanceID1, "zpSPCSocketInventorsCityState")+5;
	int InventorSocket2 = rmGetGroupingInstanceUnitByType(factoryInstanceID2, "zpSPCSocketInventorsCityState")+5;

	int InventorNugget1 = rmGetGroupingInstanceUnitByType(factoryInstanceID1, "zpNuggetInvisible")+5;
	int InventorNugget2 = rmGetGroupingInstanceUnitByType(factoryInstanceID2, "zpNuggetInvisible")+5;

	int fixedGun1 = rmGetGroupingInstanceUnitByType(factoryInstanceID1, "zpSPCFixedGunSocket")+5;
	int fixedGun2 = rmGetGroupingInstanceUnitByType(factoryInstanceID2, "zpSPCFixedGunSocket")+5;

	int revealer1 = rmGetUnitPlaced(stopperCityState1ID, 0);
	int revealer2 = rmGetUnitPlaced(stopperCityState2ID, 0);
	int revealer3 = rmGetUnitPlaced(stopperCityState3ID, 0);
	int revealer4 = rmGetGroupingInstanceUnitByType(factoryInstanceID1, "zpSPCRevealerAztec")+5;
	int revealer5 = rmGetGroupingInstanceUnitByType(factoryInstanceID2, "zpSPCRevealerAztec")+5;

	// Cooldowns
	int armoredTrainActive = 90;
	int armoredTrainCooldown = 300;
	int armoredTrainCooldown2 = 240;
	int socketMinimapFlareDuration = 300;
	int victoryCountDown = 120;

	// Guardians
	string guardianUnit = "zpJamesGang";
	string guardianUnit2 = "zpPhoenixMGunCarrier";
	string guardianUnit3 = "zpNatHoopThrower";

	// Vectors
	vector labLoc1 = rmGetUnitPosition(InventorSocket1-5);
	vector labLoc2 = rmGetUnitPosition(InventorSocket2-5);

	// Arrays

	// Outpost sockets array
	int outpostSockets = xsArrayCreateInt(12, -1, "Outpost Sockets");
	xsArraySetInt(outpostSockets, 0, tower11);
	xsArraySetInt(outpostSockets, 1, tower12);
	xsArraySetInt(outpostSockets, 2, tower13);
	xsArraySetInt(outpostSockets, 3, tower14);
	xsArraySetInt(outpostSockets, 4, tower21);
	xsArraySetInt(outpostSockets, 5, tower22);
	xsArraySetInt(outpostSockets, 6, tower23);
	xsArraySetInt(outpostSockets, 7, tower24);
	xsArraySetInt(outpostSockets, 8, tower31);
	xsArraySetInt(outpostSockets, 9, tower32);
	xsArraySetInt(outpostSockets, 10, tower33);
	xsArraySetInt(outpostSockets, 11, tower34);

	int outpostBuildID = -1;

	// Fixed Gun sockets array
	int fixedGunSockets = xsArrayCreateInt(2, -1, "Fixed Gun Sockets");
	xsArraySetInt(fixedGunSockets, 0, fixedGun1);
	xsArraySetInt(fixedGunSockets, 1, fixedGun2);

	int fixedGunBuildID = -1;

	// Stations Array
	int stationSockets = xsArrayCreateInt(3, -1, "Station Sockets");
	xsArraySetInt(stationSockets, 0, westernSocket1);
	xsArraySetInt(stationSockets, 1, westernSocket2);
	xsArraySetInt(stationSockets, 2, westernSocket3);

	int stationSocketID = -1;

	// Stations Revealer Array
	int stationRevealers = xsArrayCreateInt(3, -1, "Station Revealers");
	xsArraySetInt(stationRevealers, 0, revealer1);
	xsArraySetInt(stationRevealers, 1, revealer2);
	xsArraySetInt(stationRevealers, 2, revealer3);

	int stationRevealerID = -1;

	// Starting techs

    rmCreateTrigger("Starting Techs");
    rmSwitchToTrigger(rmTriggerID("Starting techs"));
	for(i=0; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpCivilWarGeneralStup");
		rmSetTriggerEffectParamInt("Status",2);
	}
    for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechzpIsAztecMap"); 
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",i);
		rmSetTriggerEffectParam("TechID","cTechdeTradeRouteCaptureableEuropean"); 
		rmSetTriggerEffectParamInt("Status",2);
		if (rmGetPlayerTeam(i) == 0) {
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("TechID","cTechzpCivilUnionSetup"); // Union Units and Politicians
			rmSetTriggerEffectParamInt("Status",2);
		}
		else {
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",i);
			rmSetTriggerEffectParam("TechID","cTechzpCivilConfederationSetup"); // Confederation units and politicians
			rmSetTriggerEffectParamInt("Status",2);
		}
	}
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",0);
    rmSetTriggerEffectParam("TechID","cTechzpConverGate"); 
    rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
    rmSetTriggerEffectParamInt("PlayerID",0);
    rmSetTriggerEffectParam("TechID","cTechzpCivilWarGaiaSetup");
    rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpUpdatePort2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
    rmSetTriggerPriority(4);
    rmSetTriggerActive(true);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);

	for(k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("AI Techs"+k);
		rmAddTriggerCondition("ZP PLAYER Human");
		rmSetTriggerConditionParamInt("Player",k);
		rmSetTriggerConditionParam("MyBool", "false");
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpSPCPirateCityStatesAI"); // Only for the AI to train the city state units from sockets
		rmSetTriggerEffectParamInt("Status",2);
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// AI Builds City states

	// AI Builds Pirate City States from Sockets
	for (k=1; <= cNumberNonGaiaPlayers) {
	for (s=1; <= 12) {
		rmCreateTrigger("BuildTower_"+s+"_ON"+k);
		rmCreateTrigger("BuildTower_"+s+"_OFF"+k);
		}

		for (s=1; <= 12) {
			outpostBuildID = xsArrayGetInt(outpostSockets, s-1);
			rmSwitchToTrigger(rmTriggerID("BuildTower_"+s+"_ON"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+outpostBuildID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","zpSPCWoodenTowerAIProxy");
			rmSetTriggerConditionParamInt("Dist",10);
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("Socket Build");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("Socket",""+outpostBuildID);
			rmSetTriggerEffectParam("Protounit","zpSPCCityTowerWooden");
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_"+s+"_OFF"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("BuildTower_"+s+"_OFF"+k));
			rmAddTriggerCondition("Timer ms");
			rmSetTriggerConditionParamFloat("Param1",1200);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_"+s+"_ON"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);
		}
		for (s=1; <= 2) {
		rmCreateTrigger("BuildFixedGun_"+s+"_ON"+k);
		rmCreateTrigger("BuildFixedGun_"+s+"_OFF"+k);
		}

		for (s=1; <= 2) {
			fixedGunBuildID = xsArrayGetInt(fixedGunSockets, s-1);
			rmSwitchToTrigger(rmTriggerID("BuildFixedGun_"+s+"_ON"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+fixedGunBuildID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParam("UnitType","zpSPCFixedGunAIProxy");
			rmSetTriggerConditionParamInt("Dist",10);
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);
			rmAddTriggerEffect("Socket Build");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("Socket",""+fixedGunBuildID);
			rmSetTriggerEffectParam("Protounit","zpSPCFixedGun");
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun_"+s+"_OFF"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("BuildFixedGun_"+s+"_OFF"+k));
			rmAddTriggerCondition("Timer ms");
			rmSetTriggerConditionParamFloat("Param1",1200);
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun_"+s+"_ON"+k));
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

		}
	}

	// *************** Socket Conversion ***************

	// Conversion Suspend
	rmCreateTrigger("Buildings Convert OFF");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+westernSocket1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+westernSocket2);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+westernSocket3);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "True");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Socket 1 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+westernSocket1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+westernSocket1, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+westernSocket1, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Socket 2 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+westernSocket2);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+westernSocket2, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+westernSocket2, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Socket 3 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+westernSocket3);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+westernSocket3, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+westernSocket3, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Socket 4 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit2);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit3);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+InventorSocket1, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+InventorSocket1, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmCreateTrigger("Socket 5 Convert ON");
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket2);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit2);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket2);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType",guardianUnit3);
	rmSetTriggerConditionParamInt("Dist",25);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Count",0);
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+InventorSocket2, false);
	rmSetTriggerEffectParam("ActionName", "AutoConvert", false);
	rmSetTriggerEffectParam("Suspend", "False", false);
	rmAddTriggerEffect("Flash Units");
	rmSetTriggerEffectParam("SrcObject", ""+InventorSocket2, false);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// ******************** Victory Conditions ***********************

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
		rmSetTriggerConditionParam("Protounit","zpSPCRevealerAztec");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",5);
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
		rmSetTriggerConditionParam("Protounit","zpSPCRevealerAztec");
		rmSetTriggerConditionParam("Op","<");
		rmSetTriggerConditionParamInt("Count",5);
		rmAddTriggerEffect("Counter Stop");
		rmSetTriggerEffectParam("Name","VictoryCounter"+i);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Victory_Counter"+i));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// ******************* NATIVE POLITICIANS ********************

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
	rmSetTriggerConditionParam("TechID","cTechzpPickScientist"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffScientistsLand"); //operator
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
	rmCreateTrigger("Activate Western"+k);
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpWesternAgeUp"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffWestern"); //operator
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
	rmCreateTrigger("Activate Warhut"+k);
	rmAddTriggerCondition("ZP Tech Researching (XS)");
	rmSetTriggerConditionParam("TechID","cTechzpPickNativeConsulateTechCivilWar"); //operator
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffWaterWarHut"); //operator
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
		if (rmGetPlayerTeam(k) == 0) {
			rmCreateTrigger("Activate_Rev_USA"+k);
			rmAddTriggerCondition("ZP Tech Researching (XS)");
			rmSetTriggerConditionParam("TechID","cTechzpSPCUsaCivilWarRevolution"); //operator
			rmSetTriggerConditionParamInt("PlayerID",k);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffRevUSA"); //operator
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
		if (rmGetPlayerTeam(k) == 1) {
			rmCreateTrigger("Activate_Rev_CSA"+k);
			rmAddTriggerCondition("ZP Tech Researching (XS)");
			rmSetTriggerConditionParam("TechID","cTechzpSPCCsaCivilWarRevolution"); //operator
			rmSetTriggerConditionParamInt("PlayerID",k);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpTurnConsulateOffRevCSA"); //operator
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
	}

	// Specific for human players

	for(k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Revolution_MusicEnd"+k);

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
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Western"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Warhut"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Rev_USA"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Activate_Rev_CSA"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}

	// Flag Change
	for(k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("Flag USA"+k);
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechzpRevolutionUSAShadow");
		rmSetTriggerConditionParamInt("Status",2);
		rmAddTriggerEffect("Player : Override Civilization for Flag");
		rmSetTriggerEffectParamInt("Player",k);
		rmSetTriggerEffectParam("Civilization","DEAmericans");
		rmAddTriggerEffect("Player : Override Civilization Name");
		rmSetTriggerEffectParamInt("Player",k);
		rmSetTriggerEffectParam("StringID","34139");
		rmAddTriggerEffect("Music Filename");
		rmSetTriggerEffectParam("Music","ypack\music\strategy\Revolootin.mp3"); // Music Filename
		rmSetTriggerEffectParamFloat("Duration",0.5);
		rmAddTriggerEffect("Sound Timer");
		rmSetTriggerEffectParamInt("Time", 61000);
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd"+k));
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset","UI_Strategywarning");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmCreateTrigger("Flag CSA"+k);
		rmAddTriggerCondition("ZP Tech Status Equals (XS)");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("TechID","cTechzpRevolutionCSAShadow");
		rmSetTriggerConditionParamInt("Status",2);
		rmAddTriggerEffect("Player : Override Civilization for Flag");
		rmSetTriggerEffectParamInt("Player",k);
		rmSetTriggerEffectParam("Civilization","zpRevCSA");
		rmAddTriggerEffect("Player : Override Civilization Name");
		rmSetTriggerEffectParamInt("Player",k);
		rmSetTriggerEffectParam("StringID","302606");
		rmAddTriggerEffect("Music Filename");
		rmSetTriggerEffectParam("Music","ypack\music\strategy\Revolootin.mp3"); // Music Filename
		rmSetTriggerEffectParamFloat("Duration",0.5);
		rmAddTriggerEffect("Sound Timer");
		rmSetTriggerEffectParamInt("Time", 61000);
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("Revolution_MusicEnd"+k));
		rmAddTriggerEffect("Play Soundset");
		rmSetTriggerEffectParam("Soundset","UI_Strategywarning");
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		rmSwitchToTrigger(rmTriggerID("Revolution_MusicEnd"+k));
		rmAddTriggerCondition("Timer");
		rmSetTriggerConditionParamInt("Param1",5);
		rmAddTriggerEffect("Music Play");
		rmSetTriggerPriority(1);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(false);
		rmSetTriggerLoop(false);

	}


	// ********************* TRADE ROUTE SETUP ***********************

	// Trade Route Setup

	rmCreateTrigger("AT_Initialize");
	rmAddTriggerEffect("Trade Route Set Level");
	rmSetTriggerEffectParamInt("TradeRoute",4);
	rmSetTriggerEffectParamInt("Level",2);
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",3);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",4);
	rmSetTriggerEffectParam("ShowUnit","true");
	
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain");
	rmSetTriggerEffectParamInt("Value",0);
	for(i=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+i);
		rmSetTriggerEffectParamInt("Value",0);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","TrainImprove_Plr"+i);
		rmSetTriggerEffectParamInt("Value",0);
		rmAddTriggerEffect("Quest Var Set");
		rmSetTriggerEffectParam("QVName","RenegadeControl_Plr"+i);
		rmSetTriggerEffectParamInt("Value",0);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Armored Train Upgrade

	for(k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AT_Cooldown_Upgrade"+k);
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpArmoredTrainImprove");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","TrainImprove_Plr"+k);
	rmSetTriggerEffectParamInt("Value",1);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	
	rmCreateTrigger("AT_Cooldown_On_Plr"+k);
	rmCreateTrigger("AT_Cooldown_Off_Plr"+k);
	}

	// Normalize Trade Routes

	rmCreateTrigger("AT1_Normalize_TR");
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1",1000);
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",3);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",4);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain");
	rmSetTriggerEffectParamInt("Value",0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// *********************** ARMORED TRAIN CONTROL MANAGEMENT *******************

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AT1_Send_Station1_Plr"+k);
	rmCreateTrigger("AT1_Send_Station2_Plr"+k);
	rmCreateTrigger("AT1_STOP_Station1_Plr"+k);
	rmCreateTrigger("AT1_STOP_Station2_Plr"+k);
	rmCreateTrigger("AT1_Break_Station1_Plr"+k);
	rmCreateTrigger("AT1_Break_Station2_Plr"+k);
	rmCreateTrigger("AT1_Send_Station3_Plr"+k);
	rmCreateTrigger("AT1_STOP_Station3_Plr"+k);
	rmCreateTrigger("AT1_Break_Station3_Plr"+k);

	rmCreateTrigger("AT_Destroy_Plr"+k);
	rmCreateTrigger("AT_Revert_Plr"+k);
	rmCreateTrigger("AT_Counter_Plr"+k);
	}

	for (k=1; <= cNumberNonGaiaPlayers) {

	// Station 1

	rmSwitchToTrigger(rmTriggerID("AT1_Send_Station1_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+westernATStoper1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
	rmSetTriggerConditionParamInt("Dist",40);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",3);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",4);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain");
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station1_Plr"+k));

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
	rmSetTriggerEffectParamInt("Status",2);

	rmAddTriggerEffect("FakeCounter Set Text");
	rmSetTriggerEffectParam("Text","Armored Train "+rmGetPlayerName(k)+": On the way"); // Get exact player name
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("AT1_Break_Station1_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+westernATStoper1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBreaks");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Train_Breaks");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station1_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station1_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+westernATStoper1);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);

	rmAddTriggerEffect("ZP Armored Train Stop");
	rmSetTriggerEffectParam("SrcObject",""+westernATStoper1);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",100);

	rmAddTriggerEffect("Unit Create from Source");
	rmSetTriggerEffectParam("SrcObject",""+westernATStoper1);
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("ProtoName","zpArmoredTrainKitchenWagonEmitter");

	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
	rmSetTriggerEffectParamInt("Start",armoredTrainActive);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg","Armored Train "+rmGetPlayerName(k)); // Get exact player name
	rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Destroy_Plr"+k));
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
	rmSetTriggerEffectParamInt("Status",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Revert_Plr"+k));

	rmAddTriggerEffect("FakeCounter Clear");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Station 2

	rmSwitchToTrigger(rmTriggerID("AT1_Send_Station2_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+westernATStoper2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
	rmSetTriggerConditionParamInt("Dist",40);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",3);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",4);
	rmSetTriggerEffectParam("ShowUnit","true");
		
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain");
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station2_Plr"+k));

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
	rmSetTriggerEffectParamInt("Status",2);

	rmAddTriggerEffect("FakeCounter Set Text");
	rmSetTriggerEffectParam("Text","Armored Train "+rmGetPlayerName(k)+": On the way"); // Get exact player name
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("AT1_Break_Station2_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+westernATStoper2);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBreaks");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Train_Breaks");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station2_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station2_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+westernATStoper2);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);

	rmAddTriggerEffect("ZP Armored Train Stop");
	rmSetTriggerEffectParam("SrcObject",""+westernATStoper2);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",100);

	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
	rmSetTriggerEffectParamInt("Start",armoredTrainActive);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg","Armored Train "+rmGetPlayerName(k)); // Get exact player name
	rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Destroy_Plr"+k));
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
	rmSetTriggerEffectParamInt("Status",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Revert_Plr"+k));

	rmAddTriggerEffect("FakeCounter Clear");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	// Station 3

	rmSwitchToTrigger(rmTriggerID("AT1_Send_Station3_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+westernATStoper3);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpInvisibleProjectileControler");
	rmSetTriggerConditionParamInt("Dist",40);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",1);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",2);
	rmSetTriggerEffectParam("ShowUnit","true");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",3);
	rmSetTriggerEffectParam("ShowUnit","false");
	rmAddTriggerEffect("Trade Route Toggle State");
	rmSetTriggerEffectParamInt("TradeRoute",4);
	rmSetTriggerEffectParam("ShowUnit","true");

	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain");
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Break_Station3_Plr"+k));

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));

	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainGoldBallanceShadow");
	rmSetTriggerEffectParamInt("Status",2);

	rmAddTriggerEffect("FakeCounter Set Text");
	rmSetTriggerEffectParam("Text","Armored Train "+rmGetPlayerName(k)+": On the way"); // Get exact player name
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("AT1_Break_Station3_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+westernATStoper3);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",15);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBreaks");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","Train_Breaks");
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_STOP_Station3_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	rmSwitchToTrigger(rmTriggerID("AT1_STOP_Station3_Plr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+westernATStoper3);
	rmSetTriggerConditionParamInt("Player",0);
	rmSetTriggerConditionParam("UnitType","zpArmoredTrainGunMove");
	rmSetTriggerConditionParamInt("Dist",10);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);

	rmAddTriggerEffect("ZP Armored Train Stop");
	rmSetTriggerEffectParam("SrcObject",""+westernATStoper3);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParamInt("Dist",100);

	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","ArmoredTrainPlr"+k);
	rmSetTriggerEffectParamInt("Start",armoredTrainActive);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg","Armored Train "+rmGetPlayerName(k)); // Get exact player name
	rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Destroy_Plr"+k));
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
	rmSetTriggerEffectParamInt("Status",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Revert_Plr"+k));

	rmAddTriggerEffect("FakeCounter Clear");
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);


	// Destroy Armored Train

	rmSwitchToTrigger(rmTriggerID("AT_Destroy_Plr"+k));
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpKillArmoredTrain");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Play Soundset");
	rmSetTriggerEffectParam("Soundset","AmbienceTrain");
	rmAddTriggerEffect("ZP Counter Visible for Player");
	rmSetTriggerEffectParam("Name","ArmoredTrainCooldownPlr"+k);
	rmSetTriggerEffectParamInt("Player",k);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Normalize_TR"));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Armored Train Revert Button

	rmSwitchToTrigger(rmTriggerID("AT_Revert_Plr"+k));
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpArmoredTrainBack");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Counter Stop");
	rmSetTriggerEffectParam("Name", "ArmoredTrainPlr"+k);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainBack");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Destroy_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Armored Train Revert Counter

	rmSwitchToTrigger(rmTriggerID("AT_Counter_Plr"+k));
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","ArmoredTrain_Plr"+k);
	rmSetTriggerEffectParamInt("Value",0);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// ******************** ARMORED TRAIN ABILITY MANAGEMENT ********************

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("AT_Unlock_Plr"+k);
	rmCreateTrigger("AT_Lock_Plr"+k);
	rmCreateTrigger("AT_NoResource_Plr"+k);
	rmCreateTrigger("AT_Resource_Plr"+k);

	// Train is available

	rmSwitchToTrigger(rmTriggerID("AT_Unlock_Plr"+k));
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpArmoredTrainTech");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","ArmoredTrain");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",0);
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","ArmoredTrain_Plr"+k);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",0);
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","RenegadeControl_Plr"+k);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);
	
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainLockShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainDisableShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Lock_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_NoResource_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Resource_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

		// Player has no resource to send the train
		rmSwitchToTrigger(rmTriggerID("AT_NoResource_Plr"+k));
		rmAddTriggerCondition("Player Resource Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("Resource","gold");
		rmSetTriggerConditionParam("Op","<");
		rmSetTriggerConditionParamInt("Count",500);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceShadow");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceEnableShadow");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainUnlockShadow");
		rmSetTriggerEffectParamInt("Status",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainEnableShadow");
		rmSetTriggerEffectParamInt("Status",0);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Resource_Plr"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		// Player has enough resource
		rmSwitchToTrigger(rmTriggerID("AT_Resource_Plr"+k));
		rmAddTriggerCondition("Player Resource Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("Resource","gold");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",500);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainUnlockShadow");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainEnableShadow");
		rmSetTriggerEffectParamInt("Status",2);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceShadow");
		rmSetTriggerEffectParamInt("Status",0);
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceEnableShadow");
		rmSetTriggerEffectParamInt("Status",0);
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_NoResource_Plr"+k));

		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station1_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station2_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station3_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station4_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station5_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station6_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station7_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station8_Plr"+k));
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station9_Plr"+k));
		
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	
	// Train is not available

	rmSwitchToTrigger(rmTriggerID("AT_Lock_Plr"+k));
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpArmoredTrainTech");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","ArmoredTrain");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);

	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainUnlockShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainEnableShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceEnableShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainLockShadow");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainDisableShadow");
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Unlock_Plr"+k));

	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station1_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station2_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station3_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station4_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station5_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station6_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station7_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station8_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station9_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Resource_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_NoResource_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// Armored Train Counter Upgrade

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmSwitchToTrigger(rmTriggerID("AT_Cooldown_Off_Plr"+k));
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","TrainImprove_Plr"+k);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",0);
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","ArmoredTrainCooldownPlr"+k);
	rmSetTriggerEffectParamInt("Start",armoredTrainCooldown);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg","Next Armored Train Available in");
	rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Counter_Plr"+k));
	rmAddTriggerEffect("Counter Visible");
	rmSetTriggerEffectParam("Name","ArmoredTrainCooldownPlr"+k);
	rmSetTriggerEffectParam("Visible", "false");
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_On_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("AT_Cooldown_On_Plr"+k));
	rmAddTriggerCondition("Quest Var Check");
	rmSetTriggerConditionParam("QuestVar","TrainImprove_Plr"+k);
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamInt("Value",1);
	rmAddTriggerEffect("Counter:Add Timer");
	rmSetTriggerEffectParam("Name","ArmoredTrainCooldownPlr"+k);
	rmSetTriggerEffectParamInt("Start",armoredTrainCooldown2);
	rmSetTriggerEffectParamInt("Stop",0);
	rmSetTriggerEffectParam("Msg","Next Armored Train Available in");
	rmSetTriggerEffectParamInt("Event", rmTriggerID("AT_Counter_Plr"+k));
	rmAddTriggerEffect("Counter Visible");
	rmSetTriggerEffectParam("Name","ArmoredTrainCooldownPlr"+k);
	rmSetTriggerEffectParam("Visible", "false");
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Cooldown_Off_Plr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// ***************** CONVERT STATIONS ********************

	// Station 1

	for (k=1; <= cNumberNonGaiaPlayers) {
		for (y=1; <= 3) {

			stationSocketID = xsArrayGetInt(stationSockets, y-1);
			stationRevealerID = xsArrayGetInt(stationRevealers, y-1);

			// Create triggers
			rmCreateTrigger("Station"+y+"_on_Plr"+k);
			rmCreateTrigger("Station"+y+"_off_Plr"+k);
			rmCreateTrigger("Station"+y+"_delayed_Plr"+k);

			rmSwitchToTrigger(rmTriggerID("Station"+y+"_on_Plr"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+stationSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParamInt("Dist",20);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamFloat("Count",1);

			rmAddTriggerEffect("ZP Convert Station Grouping");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpSPCWesternTavern");
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpSPCSafehouse");
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerWooden");
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpSPCCityTowerWooden");
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpSPCSawmill");
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",0);
			rmSetTriggerEffectParamInt("TrgPlayer",k);
			rmSetTriggerEffectParam("UnitType","zpSPCDestilery");
			rmSetTriggerEffectParamInt("Dist",60);	
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+stationRevealerID);
			rmSetTriggerEffectParamInt("PlayerID",k);
			for(x=1; <= cNumberNonGaiaPlayers) {
				rmAddTriggerEffect("Flare Minimap");
				rmSetTriggerEffectParamInt("PlayerID", x, false);
				rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
				if (y==1) {
					rmSetTriggerEffectParam("Position", ""+xsVectorGetX(stationLoc1)+","+xsVectorGetY(stationLoc1)+","+xsVectorGetZ(stationLoc1), false);
				}
				if (y==2) {
					rmSetTriggerEffectParam("Position", ""+xsVectorGetX(stationLoc2)+","+xsVectorGetY(stationLoc2)+","+xsVectorGetZ(stationLoc2), false);
				}
				if (y==3) {
					rmSetTriggerEffectParam("Position", ""+xsVectorGetX(stationLoc3)+","+xsVectorGetY(stationLoc3)+","+xsVectorGetZ(stationLoc3), false);
				}
				rmSetTriggerEffectParam("Flash", "True", false);
			}
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station"+y+"_off_Plr"+k));
			if (y==1) {
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_1_ON"+k));
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_2_ON"+k));
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_3_ON"+k));
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_4_ON"+k));
			}
			if (y==2) {
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_5_ON"+k));
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_6_ON"+k));
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_7_ON"+k));
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_8_ON"+k));
			}
			if (y==3) {
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_9_ON"+k));
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_10_ON"+k));
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_11_ON"+k));
				rmAddTriggerEffect("Fire Event");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_12_ON"+k));
			}
			rmSetTriggerPriority(4);
			rmSetTriggerActive(true);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);

			rmSwitchToTrigger(rmTriggerID("Station"+y+"_off_Plr"+k));
			rmAddTriggerCondition("Units in Area");
			rmSetTriggerConditionParam("DstObject",""+stationSocketID);
			rmSetTriggerConditionParamInt("Player",k);
			rmSetTriggerConditionParamInt("Dist",20);
			rmSetTriggerConditionParam("UnitType","TradingPost");
			rmSetTriggerConditionParam("Op","==");
			rmSetTriggerConditionParamFloat("Count",0);
			if (y==1) {
				rmAddTriggerEffect("Flare Minimap");
				rmSetTriggerEffectParamInt("PlayerID", k, false);
				rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
				rmSetTriggerEffectParam("Position", ""+xsVectorGetX(stationLoc1)+","+xsVectorGetY(stationLoc1)+","+xsVectorGetZ(stationLoc1), false);
				rmSetTriggerEffectParam("Flash", "True", false);
			}
			if (y==2) {
				rmAddTriggerEffect("Flare Minimap");
				rmSetTriggerEffectParamInt("PlayerID", k, false);
				rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
				rmSetTriggerEffectParam("Position", ""+xsVectorGetX(stationLoc2)+","+xsVectorGetY(stationLoc2)+","+xsVectorGetZ(stationLoc2), false);
				rmSetTriggerEffectParam("Flash", "True", false);
			}
			if (y==3) {
				rmAddTriggerEffect("Flare Minimap");
				rmSetTriggerEffectParamInt("PlayerID", k, false);
				rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
				rmSetTriggerEffectParam("Position", ""+xsVectorGetX(stationLoc3)+","+xsVectorGetY(stationLoc3)+","+xsVectorGetZ(stationLoc3), false);
				rmSetTriggerEffectParam("Flash", "True", false);
			}
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station"+y+"_on_Plr"+k));
			rmAddTriggerEffect("Fire Event");
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("Station"+y+"_delayed_Plr"+k));
			rmAddTriggerEffect("Disable Trigger");
			if (y==1) {
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_1_ON"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_2_ON"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_3_ON"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_4_ON"+k));
			}
			if (y==2) {
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_5_ON"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_6_ON"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_7_ON"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_8_ON"+k));
			}
			if (y==3) {
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_9_ON"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_10_ON"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_11_ON"+k));
				rmAddTriggerEffect("Disable Trigger");
				rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildTower_12_ON"+k));
			}
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpWesternLockCitystateTechs"); // Turn Off Western techs
			rmSetTriggerEffectParamInt("Status",2);
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);
			
			rmSwitchToTrigger(rmTriggerID("Station"+y+"_delayed_Plr"+k));
			rmAddTriggerEffect("ZP Convert Station Grouping");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpSPCWesternTavern");
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpSPCSafehouse");
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpSPCSawmill");
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpSPCDestilery");
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpSPCSocketCityTowerWooden");
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert Units in Area");
			rmSetTriggerEffectParam("SrcObject",""+stationSocketID);
			rmSetTriggerEffectParamInt("SrcPlayer",k);
			rmSetTriggerEffectParamInt("TrgPlayer",0);
			rmSetTriggerEffectParam("UnitType","zpSPCCityTowerWooden");
			rmSetTriggerEffectParamInt("Dist",60);
			rmAddTriggerEffect("Convert");
			rmSetTriggerEffectParam("SrcObject",""+stationRevealerID);
			rmSetTriggerEffectParamInt("PlayerID",0);
			rmAddTriggerEffect("ZP Set Tech Status (XS)");
			rmSetTriggerEffectParamInt("PlayerID",k);
			rmSetTriggerEffectParam("TechID","cTechzpWesternUnlockCitystateTechs"); // Turn On Western techs
			rmSetTriggerEffectParamInt("Status",2);
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);
		}
	}

	// ***************** DESTROYER TRAINING ********************

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("UniqueShip1TIMEPlr"+k);

	rmCreateTrigger("DestroyerTrain1ONPlr"+k);
	rmCreateTrigger("DestroyerTrain1OFFPlr"+k);

	rmCreateTrigger("UniqueShip2TIMEPlr"+k);

	rmCreateTrigger("DestroyerTrain2ONPlr"+k);
	rmCreateTrigger("DestroyerTrain2OFFPlr"+k);


	rmSwitchToTrigger(rmTriggerID("UniqueShip2TIMEPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamFloat("Param1",200);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpReduceSteamerBuildLimit"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Steamer 2

	rmSwitchToTrigger(rmTriggerID("DestroyerTrain1ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpWokouSteamerProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainWokouSteamer1"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip1TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain1OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("DestroyerTrain1OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain1ONPlr"+k));
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
	rmSetTriggerEffectParam("TechID","cTechzpReduceSteamerBuildLimit"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	// Steamer 1
	rmSwitchToTrigger(rmTriggerID("DestroyerTrain2ONPlr"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("UnitType","zpWokouSteamerProxy");
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamInt("Count",1);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpTrainWokouSteamer2"); //operator
	rmSetTriggerEffectParamInt("Status",2);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("UniqueShip2TIMEPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain2OFFPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("DestroyerTrain2OFFPlr"+k));
	rmAddTriggerCondition("Timer ms");
	rmSetTriggerConditionParamInt("Param1",1200);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain2ONPlr"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false); 

	}

	// ********************* INVENTORS SOCKET CONTROL *********************

	// Inventors tech available

	for(k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Control_Renegades_ON"+k);
	rmCreateTrigger("Control_Renegades_OFF"+k);

	rmSwitchToTrigger(rmTriggerID("Control_Renegades_ON"+k));
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpNativeScientists");
	rmSetTriggerConditionParamInt("Status",2);
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","RenegadeControl_Plr"+k);
	rmSetTriggerEffectParamInt("Value",1);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Control_Renegades_OFF"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	
	rmSwitchToTrigger(rmTriggerID("Control_Renegades_OFF"+k));
	rmAddTriggerCondition("ZP Tech Status Equals (XS)");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParam("TechID","cTechzpNativeScientists");
	rmSetTriggerConditionParamInt("Status",0);
	rmAddTriggerEffect("Quest Var Set");
	rmSetTriggerEffectParam("QVName","RenegadeControl_Plr"+k);
	rmSetTriggerEffectParamInt("Value",0);

	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainUnlockShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainEnableShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainNoResourceEnableShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainLockShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("ZP Set Tech Status (XS)");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParam("TechID","cTechzpArmoredTrainDisableShadow");
	rmSetTriggerEffectParamInt("Status",0);
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Unlock_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Lock_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station1_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station2_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station3_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station4_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station5_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station6_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station7_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT1_Send_Station8_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_Resource_Plr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("AT_NoResource_Plr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Control_Renegades_ON"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	}

	// Renegade Water trading post activation

	for (k=1; <= cNumberNonGaiaPlayers) {
	rmCreateTrigger("Pirates1on Player"+k);
	rmCreateTrigger("Pirates1off Player"+k);
	rmCreateTrigger("Pirates2on Player"+k);
	rmCreateTrigger("Pirates2off Player"+k);

	rmSwitchToTrigger(rmTriggerID("Pirates1on_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+InventorFlag1);
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCCapturableFactory");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCFixedGunBase");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCFixedGun");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCFixedGunSocket");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCGoldSmelter");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+revealer4);
	rmSetTriggerEffectParamInt("PlayerID",k);
	for(x=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Flare Minimap");
		rmSetTriggerEffectParamInt("PlayerID", x, false);
		rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
		rmSetTriggerEffectParam("Position", ""+xsVectorGetX(labLoc1)+","+xsVectorGetY(labLoc1)+","+xsVectorGetZ(labLoc1), false);
		rmSetTriggerEffectParam("Flash", "True", false);
	}

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain1ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun_1_ON"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates1off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket1);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+InventorFlag1);
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCCapturableFactory");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCFixedGunBase");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCFixedGun");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCFixedGunSocket");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket1);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCGoldSmelter");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+revealer4);
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmAddTriggerEffect("Flare Minimap");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParamInt("Duration",socketMinimapFlareDuration);
	rmSetTriggerEffectParam("Position",""+xsVectorGetX(labLoc1)+","+xsVectorGetY(labLoc1)+","+xsVectorGetZ(labLoc1));
	rmSetTriggerEffectParam("Flash","True");

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates1on_Player"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain1ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun_1_ON"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates2on_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op",">=");
	rmSetTriggerConditionParamFloat("Count",1);
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+InventorFlag2);
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCCapturableFactory");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCFixedGunBase");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCFixedGun");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCFixedGunSocket");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",0);
	rmSetTriggerEffectParamInt("TrgPlayer",k);
	rmSetTriggerEffectParam("UnitType","zpSPCGoldSmelter");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+revealer5);
	rmSetTriggerEffectParamInt("PlayerID",k);
	for(x=1; <= cNumberNonGaiaPlayers) {
		rmAddTriggerEffect("Flare Minimap");
		rmSetTriggerEffectParamInt("PlayerID", x, false);
		rmSetTriggerEffectParamInt("Duration", socketMinimapFlareDuration, false);
		rmSetTriggerEffectParam("Position", ""+xsVectorGetX(labLoc2)+","+xsVectorGetY(labLoc2)+","+xsVectorGetZ(labLoc2), false);
		rmSetTriggerEffectParam("Flash", "True", false);
	}

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2off_Player"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain2ONPlr"+k));
	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun_2_ON"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);

	rmSwitchToTrigger(rmTriggerID("Pirates2off_Player"+k));
	rmAddTriggerCondition("Units in Area");
	rmSetTriggerConditionParam("DstObject",""+InventorSocket2);
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParamInt("Dist",35);
	rmSetTriggerConditionParam("UnitType","TradingPost");
	rmSetTriggerConditionParam("Op","==");
	rmSetTriggerConditionParamFloat("Count",0);
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+InventorFlag2);
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCCapturableFactory");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpTradingPostCaptureNaval");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCFixedGunBase");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCFixedGun");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCFixedGunSocket");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpCityStateFlag");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert Units in Area");
	rmSetTriggerEffectParam("SrcObject",""+InventorSocket2);
	rmSetTriggerEffectParamInt("SrcPlayer",k);
	rmSetTriggerEffectParamInt("TrgPlayer",0);
	rmSetTriggerEffectParam("UnitType","zpSPCGoldSmelter");
	rmSetTriggerEffectParamInt("Dist",60);
	rmAddTriggerEffect("Convert");
	rmSetTriggerEffectParam("SrcObject",""+revealer5);
	rmSetTriggerEffectParamInt("PlayerID",0);
	rmAddTriggerEffect("Flare Minimap");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParamInt("Duration",socketMinimapFlareDuration);
	rmSetTriggerEffectParam("Position",""+xsVectorGetX(labLoc2)+","+xsVectorGetY(labLoc2)+","+xsVectorGetZ(labLoc2));
	rmSetTriggerEffectParam("Flash","True");

	rmAddTriggerEffect("Fire Event");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("Pirates2on_Player"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("DestroyerTrain2ONPlr"+k));
	rmAddTriggerEffect("Disable Trigger");
	rmSetTriggerEffectParamInt("EventID", rmTriggerID("BuildFixedGun_2_ON"+k));
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// AI Renegade Leaders

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
		rmSetTriggerEffectParam("TechID","cTechzpConsulateScientistGortz"); //operator
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

	// AI Western Leaders

	for (k=1; <= cNumberNonGaiaPlayers) {

	rmCreateTrigger("ZP Pick Western Leader"+k);
	rmAddTriggerCondition("ZP PLAYER Human");
	rmSetTriggerConditionParamInt("Player",k);
	rmSetTriggerConditionParam("MyBool", "false");
	rmAddTriggerCondition("Tech Status Equals");
	rmSetTriggerConditionParamInt("PlayerID",k);
	rmSetTriggerConditionParamInt("TechID",586);
	rmSetTriggerConditionParamInt("Status",2);

	int westernLeader=-1;
	westernLeader = rmRandInt(1,3);

	if (westernLeader==1)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateWesternWyatEarp"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (westernLeader==2)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateWesternPinkertons"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	if (westernLeader==3)
	{
		rmAddTriggerEffect("ZP Set Tech Status (XS)");
		rmSetTriggerEffectParamInt("PlayerID",k);
		rmSetTriggerEffectParam("TechID","cTechzpConsulateWesternJesseJames"); //operator
		rmSetTriggerEffectParamInt("Status",2);
	}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}

	// AI Revolutionary Fractions

	for (k=1; <= cNumberNonGaiaPlayers) {
		rmCreateTrigger("ZP_Iniciate_Revolution"+k);
		if (rmGetPlayerTeam(k) == 0)
		rmCreateTrigger("ZP_Execute_Revolution"+k);
		else
		rmCreateTrigger("ZP_Execute_Revolution_Con"+k);
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
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		if (rmGetPlayerTeam(k) == 0)
			rmSetTriggerConditionParam("Protounit","zpSPCCivilWarCommandery");
		else
			rmSetTriggerConditionParam("Protounit","zpSPCCivilWarCommanderyCon");
		rmSetTriggerConditionParam("Op",">=");
		rmSetTriggerConditionParamInt("Count",1);
		rmAddTriggerEffect("Fire Event");
		if (rmGetPlayerTeam(k) == 0)
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("ZP_Execute_Revolution"+k));
		else
			rmSetTriggerEffectParamInt("EventID", rmTriggerID("ZP_Execute_Revolution_Con"+k));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(false);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);

		if (rmGetPlayerTeam(k) == 0) {
		rmSwitchToTrigger(rmTriggerID("ZP_Execute_Revolution"+k));
		rmAddTriggerCondition("Player Unit Count");
		rmSetTriggerConditionParamInt("PlayerID",k);
		rmSetTriggerConditionParam("Protounit","zpSPCCivilWarCommandery");
		rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);

			int revFraction=-1;
			revFraction = rmRandInt(1,3);

			if (revFraction==1)
			{
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",k);
				rmSetTriggerEffectParam("TechID","cTechzpConsulateRevPresidentUnion"); //operator
				rmSetTriggerEffectParamInt("Status",2);
			}
			if (revFraction==2)
			{
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",k);
				rmSetTriggerEffectParam("TechID","cTechzpConsulateRevGeneralUnion"); //operator
				rmSetTriggerEffectParamInt("Status",2);
			}
			if (revFraction==3)
			{
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",k);
				rmSetTriggerEffectParam("TechID","cTechzpConsulateRevAdmiralUnion"); //operator
				rmSetTriggerEffectParamInt("Status",2);
			}
			rmSetTriggerPriority(4);
			rmSetTriggerActive(false);
			rmSetTriggerRunImmediately(true);
			rmSetTriggerLoop(false);
		}
		else {
			rmSwitchToTrigger(rmTriggerID("ZP_Execute_Revolution_Con"+k));
			rmAddTriggerCondition("Player Unit Count");
			rmSetTriggerConditionParamInt("PlayerID",k);
			rmSetTriggerConditionParam("Protounit","zpSPCCivilWarCommanderyCon");
			rmSetTriggerConditionParam("Op",">=");
			rmSetTriggerConditionParamInt("Count",1);

			if (revFraction==1)
			{
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",k);
				rmSetTriggerEffectParam("TechID","cTechzpConsulateRevPresidentConfederate"); //operator
				rmSetTriggerEffectParamInt("Status",2);
			}
			if (revFraction==2)
			{
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",k);
				rmSetTriggerEffectParam("TechID","cTechzpConsulateRevGeneralConfederate"); //operator
				rmSetTriggerEffectParamInt("Status",2);
			}
			if (revFraction==3)
			{
				rmAddTriggerEffect("ZP Set Tech Status (XS)");
				rmSetTriggerEffectParamInt("PlayerID",k);
				rmSetTriggerEffectParam("TechID","cTechzpConsulateRevAdmiralConfederate"); //operator
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
	rmAddTriggerEffect("Set Tech Status");
	rmSetTriggerEffectParamInt("PlayerID",k);
	rmSetTriggerEffectParamFloat("TechID",527);
	rmSetTriggerEffectParamInt("Status",2);
	rmSetTriggerPriority(4);
	rmSetTriggerActive(true);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
	}*/

    
	
} // END